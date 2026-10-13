# pwn.hust.college Platform API Reference

Everything an agent needs to start challenges and submit flags through the
platform REST API, verified end to end (2026-10-13). The web UI calls the
same endpoints, so results are identical.

## Authentication

Generate an API Token once in the web UI: log in, open
`https://pwn.cse.hust.edu.cn/settings#tokens` ("访问令牌" tab), and create a
token. Then send it on every request:

```
Authorization: Token <TOKEN>
Content-Type: application/json
```

**Both headers are required on every request, including GETs with no body.**
Without `Content-Type: application/json` the token is ignored and the request
is treated as anonymous (401/redirect to login).

Keep the token in a shell variable only. Never write it into files, scripts,
or logs.

## Endpoints

| Purpose | Method & Path | Body / Notes |
|---|---|---|
| Current user | `GET /api/v1/users/me` | Quick token validity check |
| Solved challenges | `GET /api/v1/users/me/solves` | Challenge ids already solved by the account — filter these out before picking a challenge |
| List challenges | `GET /pwncollege_api/v1/dojo/<dojo>/<module>/challenges` | Returns `{"success": true, "challenges": [...]}` — note the list sits at the **top level**, not under `data` like the CTFd endpoints; each entry has `id` (string, used to start) and `challenge_id` (number, used to submit), plus the description |
| Start challenge | `POST /pwncollege_api/v1/docker` | `{"dojo": "...", "module": "...", "challenge": "..."}` — string ids; replaces the user's current container |
| Current challenge | `GET /pwncollege_api/v1/docker` | Which dojo/module/challenge is running |
| Upload SSH key | `POST /pwncollege_api/v1/ssh_key` | `{"ssh_key": "<public key>"}` — see key lifecycle below |
| Remove SSH key | `DELETE /pwncollege_api/v1/ssh_key` | `{"ssh_key": "<stored key value>"}` — stored value has no comment |
| Submit flag | `POST /api/v1/challenges/attempt` | `{"challenge_id": <number>, "submission": "<flag>"}` |

Platform quirks (verified 2026-10-13):

- `GET /pwncollege_api/v1/dojo/<dojo>/modules` returns HTTP 500 on this
  deployment. To discover modules, fetch the dojo landing page
  (`https://pwn.cse.hust.edu.cn/<dojo>/`) and extract the module links, or
  use known module ids (e.g. `welcome/welcome`).
- There is no `GET /pwncollege_api/v1/dojos` list endpoint. The web page
  `https://pwn.cse.hust.edu.cn/dojos` links every dojo instead.
- Some dojos require completing a prerequisite dojo first. Their landing
  page renders no module links and mentions the prerequisite — treat such a
  dojo as locked for the account and pick another one.
- The verification program is not always `/challenge/solve`: its path comes
  from the challenge's DESCRIPTION.md (the git dojo uses `/challenge/check`).
- There is no API to read back the stored SSH key (`GET /ssh_key` does not
  exist). To verify a key restore, fetch `/settings` with the token — the
  page renders the stored value and accepts token authentication.
- Filter solved challenges by numeric `challenge_id` from a fresh `solves`
  call; module organization can change over time (challenges get reorganized
  and their ids change), so stale lists cannot be trusted.

## SSH key lifecycle (important)

The platform keeps **exactly one SSH public key per account**. Consequences:

- `POST /ssh_key` fails with `"SSH Key already in use"` when the account
  already has a key — even if you are uploading a brand new one. The message
  means "this account already has a key", not that your key collides with
  someone else's.
- To replace a key: `DELETE` the existing one, then `POST` the new one.
- Upload stores the key without its trailing comment, so `DELETE` must send
  the **comment-less value**: `cut -d' ' -f1,2` of the public key line.
- Keys can also be managed in the web UI (Settings → SSH 公钥), which shows
  the stored value and offers a delete button per key. If you are working on
  a shared account, note the existing key there before replacing it, and
  restore it when done.

## Starting a challenge and connecting

1. `POST /pwncollege_api/v1/docker` returns `{"success": true}` in about a
   second, but the container is still initializing.
2. Wait ~20 seconds, then connect:
   ```
   ssh -tt -i <key> -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       hacker@pwn.cse.hust.edu.cn '<command>'
   ```
   Keep a retry loop (15 s interval, ~2 min cap) in case of
   "No active challenge session" or connection refused.
3. **Always pass `-tt`** (force TTY allocation). Some challenges check
   `SSH_TTY` and fail in non-interactive sessions.
4. Each user has at most one container; starting the next challenge destroys
   the previous one automatically. `/home/hacker` persists across challenges.

## Solving and submitting

- Read the brief first: `cat /challenge/DESCRIPTION.md` (identical to the
  description from the challenges list endpoint, which allows picking a
  challenge before starting it).
- Flags look like `pwn.college{...}` with no whitespace; extract with
  `pwn\.college\{[^}]*\}` from the challenge output.
- Submit with the **numeric `challenge_id`** from the list endpoint (the
  docker start endpoint uses the string `id` instead — do not mix them up).
- Response `data.status == "correct"` means solved; `already_solved` means
  it was solved before (also a success). `users/me` score is not a reliable
  completion signal.
