---
name: pwnhustcollege
description: Use only for authorized pwn/binary exploitation challenges on pwn.hust.college when the user explicitly wants help connecting to that platform, analyzing /challenge/solve, or generating an exploit for that platform's CTF environment.
---

# pwnhustcollege Skill

## Overview

Automates solving authorized binary exploitation challenges on pwn.hust.college. Connects via SSH after authorization and key-path confirmation, analyzes challenge binaries, identifies vulnerabilities, and generates pwntools exploits — pausing at key decision points for user confirmation.

## Platform Context

- SSH: `ssh -tt -i ~/.ssh/key hacker@pwn.cse.hust.edu.cn`
- Challenge binary: commonly `/challenge/solve`, but the actual path is whatever `/challenge/DESCRIPTION.md` says (e.g. the git dojo verifies with `/challenge/check`)
- Description: `/challenge/DESCRIPTION.md`
- Flag: `/flag`
- Home: `/home/hacker` (persistent across challenges)
- Pre-installed: pwntools, pwndbg, gdb, gef, radare2, ghidra, strace, checksec
- REST API: start challenges and submit flags without a browser — see `references/platform-api.md` and `scripts/platform_api.sh`

## When to Use

- User explicitly mentions an authorized pwn.hust.college challenge
- User needs binary exploitation help for `/challenge/solve` on pwn.hust.college
- User wants to SSH into pwn.hust.college and analyze its challenge binary

## Workflow

### Phase 0: Select and Start a Challenge via API

Skip this phase only if a challenge session is already running (check with `current_challenge`).

1. Ask the user for an API Token (created once at `https://pwn.cse.hust.edu.cn/settings#tokens`). Store it in a shell variable only — never in files or logs.
2. Discover dojos from the web page `https://pwn.cse.hust.edu.cn/dojos` (there is no list API). A dojo whose landing page shows no module links and mentions a prerequisite dojo is locked for this account; pick from the unlocked ones.
3. Fetch the solved list first (`list_solved`) so completed challenges can be filtered out, then list the challenges of the target dojo/module (`list_challenges <dojo> <module>`, e.g. `welcome welcome`) and pick one together with the user. Each entry has both a string `id` (used to start) and a numeric `challenge_id` (used to submit), plus the description.
3. Ensure an SSH key pair exists (`ssh-keygen -t ed25519 -N "" -f <path>`) and is uploaded (`upload_ssh_key`). The platform stores **one key per account**: if `upload_ssh_key` fails with "SSH Key already in use", the account already has a key — get the current public key value from the user (copyable from the web settings page), back it up, delete it with `remove_ssh_key`, then upload yours. Restore the user's key when done, and mind that SSH access is interrupted between the delete and the upload.
4. Start the challenge and wait for the container (`start_and_wait <dojo> <module> <challenge>`): the API returns within a second, SSH becomes connectable after ~20 s.

Full endpoint details and deployment quirks: `references/platform-api.md`.

### Phase 1: Connection & Reconnaissance

1. Confirm the user is authorized to access the pwn.hust.college challenge, confirm the SSH key path (default `~/.ssh/key`), and request approval before running `ssh` or `scp`.
2. SSH into the platform: `ssh -tt -i <key_path> hacker@pwn.cse.hust.edu.cn` (`-tt` is required: some challenges check `SSH_TTY`)
3. Read the challenge description: `cat /challenge/DESCRIPTION.md`
4. Run automated reconnaissance by executing `scripts/recon.sh` on the remote host via SSH
5. Present a structured analysis report to the user:
   - Binary type and architecture (from `file` and `readelf -h`)
   - Security protections (from `checksec`: canary, NX, PIE, RELRO)
   - Key functions (from `objdump -d` disassembly of main and notable functions)
   - Interesting strings (from `strings` output)

### Phase 2: Vulnerability Analysis

**Scripted or task challenges**: some dojos (e.g. git) verify the solution with a script instead of a binary — if DESCRIPTION.md describes plain tasks to perform, follow it directly and skip this phase and Phase 3.

Based on reconnaissance data, identify the vulnerability type by matching patterns from `references/pwn-patterns.md`:

First determine the target architecture from `file /challenge/solve`, `readelf -h /challenge/solve`, or `ELF('/challenge/solve').arch`. The platform may serve x86, x86_64, ARM, or AArch64 binaries. Do not assume amd64; select packing, calling convention, gadgets, shellcode, and pwntools `context` from the detected architecture.

Common patterns to check:
- **ret2win**: A win function exists (e.g., `win`, `flag`, `shell`, `cat_flag`) + stack overflow
- **ROP**: No win function, NX enabled, need to chain gadgets
- **Format string**: `printf(user_input)` pattern (no format string argument)
- **Shellcode**: NX disabled + writable + executable memory region
- **Bypass canary**: Canary present + leak primitive available

Present the finding with:
- Vulnerability type and confidence
- Supporting evidence (disassembly snippet, offset calculation)
- Proposed exploit strategy

**This is the key decision gate.** Ask the user to confirm the strategy before proceeding.

### Phase 3: Exploit Generation

Generate a pwntools exploit script based on the confirmed vulnerability type:

- Start from `scripts/exploit_template.py` base
- Keep `context.binary = ELF('/challenge/solve')` so pwntools selects the detected architecture and word size
- Adapt for the specific vulnerability:
  - **ret2win**: Calculate padding offset → pack win function address with `p32` or `p64` according to `elf.bits`
  - **ROP**: Find architecture-appropriate gadgets with pwntools `ROP(elf)`, `ROPgadget`, or `ropper`; do not reuse amd64-only gadgets such as `pop rdi; ret` on ARM
  - **Format string**: Determine offset on stack → craft `%n` write payload with address sizes matching `elf.bits`
  - **Shellcode**: Generate shellcode with pwntools `shellcraft` for the detected `context.arch`
- Write the exploit script to `/home/hacker/exploit.py` on the remote host
- Execute with `python3 /home/hacker/exploit.py`
- Capture the flag from output

### Phase 4: Flag Submission

1. Display the captured flag clearly.
2. Submit it through the API (`submit_flag <challenge_id> "<flag>"`), using the **numeric** `challenge_id` from the challenges list.
3. Check the response: `data.status == "correct"` means solved; `already_solved` also counts as solved (it was completed earlier). Report the status to the user.
4. Moving to another challenge automatically destroys the current container (one container per user); `/home/hacker` persists.

## Using the Recon Script

The `scripts/recon.sh` script runs automated reconnaissance commands on the remote host:

```bash
# Copy and run on the remote host
scp -i ~/.ssh/key scripts/recon.sh hacker@pwn.cse.hust.edu.cn:/home/hacker/
ssh -i ~/.ssh/key hacker@pwn.cse.hust.edu.cn 'bash /home/hacker/recon.sh'
```

The script executes: `file`, `checksec`, `readelf -h`, `objdump -d` (main + notable functions), `strings` (filtered), and `readelf` (sections/symbols if available).

## Common Mistakes

- **Not reading DESCRIPTION first**: Always read `/challenge/DESCRIPTION.md` before analyzing — it often contains critical hints
- **Wrong SSH key path**: Default is `~/.ssh/key`, but check user's actual key location
- **Connecting without authorization**: Confirm the user is authorized and get approval before running remote `ssh` or `scp` commands
- **Assuming amd64**: Always detect the binary architecture first; pwn.hust.college can use ARM/AArch64 as well as x86/x86_64
- **Assuming local tools**: All analysis runs on the remote host where tools are pre-installed — don't try to run checksec/pwntools locally
- **Skipping the decision gate**: Always confirm exploit strategy with user before generating code
- **Missing Content-Type on GETs**: every API request must send both `Authorization: Token <TOKEN>` and `Content-Type: application/json`, or the token is silently ignored
- **Trusting "SSH Key already in use"**: the platform stores one key per user; that error means the account already has a key (delete first, then upload)
- **Dropping `-tt` from ssh**: non-interactive sessions have no `SSH_TTY` and some challenges refuse to run
- **Mixing up the two challenge ids**: docker start takes the string `id`, flag submission takes the numeric `challenge_id`
- **Connecting immediately after start**: the container needs ~20 s to initialize; retry instead of assuming failure
- **Assuming `/challenge/solve`**: the verification program path comes from DESCRIPTION.md (the git dojo uses `/challenge/check`)
- **Re-solving finished challenges**: fetch `/api/v1/users/me/solves` first to filter out what the account already completed
- **Overlooking locked dojos**: a landing page without module links means the dojo has a prerequisite; pick another dojo
- **Trusting a stale solved list**: query `/api/v1/users/me/solves` at selection time and match by numeric id; challenge organization changes over time
