#!/bin/bash
# pwn.hust.college platform API helpers.
# Usage: source this file, then export credentials:
#   export PWNHUST_TOKEN="ctfd_..."        # from https://pwn.cse.hust.edu.cn/settings#tokens
#   export PWNHUST_KEY=/path/to/id_ed25519 # SSH private key whose public key is uploaded
# Every helper returns non-zero on transport errors and on non-2xx HTTP
# responses; response bodies go to stdout on success and to stderr on failure.
# Verified end to end (2026-11-14).

PWNHUST_HOST="${PWNHUST_HOST:-pwn.cse.hust.edu.cn}"
PWNHUST_BASE="${PWNHUST_BASE:-https://$PWNHUST_HOST}"

# Headers are fed to curl via a process-substitution config file so the
# token never appears in `ps` output (argv).
_api_config() {
    printf 'header = "Authorization: Token %s"\nheader = "Content-Type: application/json"\n' "$PWNHUST_TOKEN"
}

api() {
    if [ -z "${PWNHUST_TOKEN:-}" ]; then
        echo "PWNHUST_TOKEN is not set (see usage in the script header)" >&2
        return 1
    fi
    local body status rc
    body="$(mktemp)" || return 1
    status="$(curl -sS -o "$body" -w '%{http_code}' -K <(_api_config) "$@")"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "curl failed with exit $rc" >&2
        rm -f "$body"
        return 1
    fi
    case "$status" in
        2*)
            cat "$body"
            ;;
        3*)
            echo "HTTP $status (redirect; some endpoints redirect despite a valid token on this deployment)" >&2
            cat "$body" >&2
            ;;
        *)
            echo "HTTP $status" >&2
            cat "$body" >&2
            ;;
    esac
    rm -f "$body"
    case "$status" in 2*) return 0 ;; *) return 1 ;; esac
}

_require_id() { # _require_id <label> <value>: platform ids are [a-z0-9~-]
    [[ "${2:-}" =~ ^[a-z0-9][a-z0-9~-]{0,63}$ ]] || { echo "invalid $1 id: ${2:-<empty>}" >&2; return 1; }
}

list_challenges() { # list_challenges <dojo> <module>
    _require_id dojo "$1" && _require_id module "$2" || return 1
    api "$PWNHUST_BASE/pwncollege_api/v1/dojo/$1/$2/challenges"
}

start_challenge() { # start_challenge <dojo> <module> <challenge-string-id>
    _require_id dojo "$1" && _require_id module "$2" && _require_id challenge "$3" || return 1
    local body
    body="$(python3 -c 'import json,sys; print(json.dumps({"dojo": sys.argv[1], "module": sys.argv[2], "challenge": sys.argv[3]}))' "$1" "$2" "$3")" || return 1
    api -X POST -d "$body" "$PWNHUST_BASE/pwncollege_api/v1/docker"
}

current_challenge() {
    api "$PWNHUST_BASE/pwncollege_api/v1/docker"
}

list_solved() { # challenge ids already solved by the account
    api "$PWNHUST_BASE/api/v1/users/me/solves"
}

submit_flag() { # submit_flag <challenge-number-id> <flag>
    [[ "${1:-}" =~ ^[0-9]+$ ]] || { echo "usage: submit_flag <numeric-challenge-id> <flag>" >&2; return 1; }
    local body
    body="$(python3 -c 'import json,sys; print(json.dumps({"challenge_id": int(sys.argv[1]), "submission": sys.argv[2]}))' "$1" "$2")" || return 1
    api -X POST -d "$body" "$PWNHUST_BASE/api/v1/challenges/attempt"
}

# Print the "type material" pair of a public key, comment stripped: the
# platform stores keys without comments, and delete matching requires the
# same stripped form. Accepts a file path or the bare key value.
_read_key() {
    local input
    if [ -f "${1:-}" ]; then
        input="$(tr -d '\r' < "$1")"
    elif [[ "${1:-}" == ssh-* ]]; then
        input="$1"
    else
        echo "key file not found or not a key value: ${1:-<empty>}" >&2
        return 1
    fi
    printf '%s\n' "$input" \
        | awk '$1 ~ /^ssh-/ && NF >= 2 { print $1" "$2; found = 1; exit } END { exit !found }' \
        || { echo "not a valid ssh public key" >&2; return 1; }
}

upload_ssh_key() { # upload_ssh_key <public-key-file-or-value>
    local value body
    value="$(_read_key "${1:-}")" || return 1
    body="$(python3 -c 'import json,sys; print(json.dumps({"ssh_key": sys.argv[1]}))' "$value")" || return 1
    api -X POST -d "$body" "$PWNHUST_BASE/pwncollege_api/v1/ssh_key"
}

remove_ssh_key() { # remove_ssh_key <public-key-file-or-value>
    local value body
    value="$(_read_key "${1:-}")" || return 1
    body="$(python3 -c 'import json,sys; print(json.dumps({"ssh_key": sys.argv[1]}))' "$value")" || return 1
    api -X DELETE -d "$body" "$PWNHUST_BASE/pwncollege_api/v1/ssh_key"
}

# Run a command inside the current challenge container.
# -tt is required: some challenges verify that SSH_TTY is set.
# Host-key checking is disabled on purpose: challenge containers are
# throwaway; do not copy this to production hosts.
challenge_ssh() {
    if [ -z "${PWNHUST_KEY:-}" ] || [ ! -f "$PWNHUST_KEY" ]; then
        echo "PWNHUST_KEY must point to an existing private key file" >&2
        return 1
    fi
    ssh -tt -i "$PWNHUST_KEY" \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "hacker@$PWNHUST_HOST" "$@"
}

# Start a challenge and wait for SSH to become connectable.
start_and_wait() { # start_and_wait <dojo> <module> <challenge> [timeout_sec]
    if [ -z "${PWNHUST_KEY:-}" ] || [ ! -f "$PWNHUST_KEY" ]; then
        echo "PWNHUST_KEY must point to an existing private key file before starting" >&2
        return 1
    fi
    local timeout="${4:-120}" waited=0 resp err
    [[ "$timeout" =~ ^[0-9]+$ ]] || timeout=120
    resp="$(start_challenge "$1" "$2" "$3")" || return 1
    echo "$resp" | grep -q '"success": *true' || { echo "$resp" >&2; return 1; }
    local initial=$(( timeout < 20 ? timeout : 20 ))
    sleep "$initial"; waited=$initial
    while :; do
        if err="$(challenge_ssh true 2>&1 >/dev/null)"; then
            echo "challenge container is reachable (waited ${waited}s)"
            return 0
        fi
        [ "$waited" -ge "$timeout" ] && break
        local step=$(( timeout - waited < 15 ? timeout - waited : 15 ))
        sleep "$step"; waited=$((waited + step))
    done
    echo "challenge container not reachable after ${timeout}s; last ssh output:" >&2
    printf '%s\n' "$err" >&2
    return 1
}
