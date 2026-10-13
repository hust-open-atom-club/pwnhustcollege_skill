#!/bin/bash
# pwn.hust.college platform API helpers.
# Usage: source this file, export PWNHUST_TOKEN and optionally PWNHUST_KEY.
#   export PWNHUST_TOKEN="ctfd_..."        # from https://pwn.cse.hust.edu.cn/settings#tokens
#   export PWNHUST_KEY=/path/to/id_ed25519 # SSH private key uploaded to the platform
# Verified end to end (2026-10-13).

PWNHUST_HOST="${PWNHUST_HOST:-pwn.cse.hust.edu.cn}"
PWNHUST_BASE="${PWNHUST_BASE:-https://$PWNHUST_HOST}"

# Every request must carry BOTH headers, including GETs with no body,
# otherwise the token is ignored.
api() {
    curl -sS -H "Authorization: Token $PWNHUST_TOKEN" \
         -H "Content-Type: application/json" "$@"
}

list_challenges() { # list_challenges <dojo> <module>
    api "$PWNHUST_BASE/pwncollege_api/v1/dojo/$1/$2/challenges"
}

start_challenge() { # start_challenge <dojo> <module> <challenge-string-id>
    api -X POST -d "{\"dojo\":\"$1\",\"module\":\"$2\",\"challenge\":\"$3\"}" \
        "$PWNHUST_BASE/pwncollege_api/v1/docker"
}

current_challenge() {
    api "$PWNHUST_BASE/pwncollege_api/v1/docker"
}

list_solved() { # challenge ids already solved by the account
    api "$PWNHUST_BASE/api/v1/users/me/solves"
}

submit_flag() { # submit_flag <challenge-number-id> <flag>
    local body
    body="$(python3 -c 'import json,sys; print(json.dumps({"challenge_id": int(sys.argv[1]), "submission": sys.argv[2]}))' "$1" "$2")"
    api -X POST -d "$body" "$PWNHUST_BASE/api/v1/challenges/attempt"
}

upload_ssh_key() { # upload_ssh_key <public-key-file>
    local body
    body="$(python3 -c 'import json,sys; print(json.dumps({"ssh_key": sys.argv[1].strip()}))' "$(tr -d '\r' < "$1")")"
    api -X POST -d "$body" "$PWNHUST_BASE/pwncollege_api/v1/ssh_key"
}

remove_ssh_key() { # remove_ssh_key <public-key-file>  (comment is stripped, see reference)
    local body
    body="$(python3 -c 'import json,sys; print(json.dumps({"ssh_key": sys.argv[1].strip()}))' "$(tr -d '\r' < "$1" | cut -d' ' -f1,2)")"
    api -X DELETE -d "$body" "$PWNHUST_BASE/pwncollege_api/v1/ssh_key"
}

# Run a command inside the current challenge container.
# -tt is required: some challenges verify that SSH_TTY is set.
challenge_ssh() {
    ssh -tt -i "${PWNHUST_KEY:?export PWNHUST_KEY first}" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "hacker@$PWNHUST_HOST" "$@"
}

# Start a challenge and wait for SSH to become connectable.
start_and_wait() { # start_and_wait <dojo> <module> <challenge> [timeout_sec]
    local timeout="${4:-120}" waited=0 resp
    resp="$(start_challenge "$1" "$2" "$3")" || return 1
    echo "$resp" | grep -q '"success": *true' || { echo "$resp" >&2; return 1; }
    sleep 20; waited=20
    while [ "$waited" -lt "$timeout" ]; do
        if challenge_ssh true 2>/dev/null; then return 0; fi
        sleep 15; waited=$((waited + 15))
    done
    echo "challenge container not reachable after ${timeout}s" >&2
    return 1
}
