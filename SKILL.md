---
name: pwnhustcollege
description: Use only for authorized pwn/binary exploitation challenges on pwn.hust.college when the user explicitly wants help connecting to that platform, analyzing /challenge/solve, or generating an exploit for that platform's CTF environment.
---

# pwnhustcollege Skill

## Overview

Automates solving authorized binary exploitation challenges on pwn.hust.college. Connects via SSH after authorization and key-path confirmation, analyzes challenge binaries, identifies vulnerabilities, and generates pwntools exploits — pausing at key decision points for user confirmation.

## Platform Context

- SSH: `ssh -i ~/.ssh/key hacker@pwn.cse.hust.edu.cn`
- Challenge binary: `/challenge/solve`
- Description: `/challenge/DESCRIPTION.md`
- Flag: `/flag`
- Home: `/home/hacker` (persistent across sessions)
- Pre-installed: pwntools, pwndbg, gdb, gef, radare2, ghidra, strace, checksec

## When to Use

- User explicitly mentions an authorized pwn.hust.college challenge
- User needs binary exploitation help for `/challenge/solve` on pwn.hust.college
- User wants to SSH into pwn.hust.college and analyze its challenge binary

## Workflow

### Phase 1: Connection & Reconnaissance

1. Confirm the user is authorized to access the pwn.hust.college challenge, confirm the SSH key path (default `~/.ssh/key`), and request approval before running `ssh` or `scp`.
2. SSH into the platform: `ssh -i <key_path> hacker@pwn.cse.hust.edu.cn`
3. Read the challenge description: `cat /challenge/DESCRIPTION.md`
4. Run automated reconnaissance by executing `scripts/recon.sh` on the remote host via SSH
5. Present a structured analysis report to the user:
   - Binary type (from `file`)
   - Security protections (from `checksec`: canary, NX, PIE, RELRO)
   - Key functions (from `objdump -d` disassembly of main and notable functions)
   - Interesting strings (from `strings` output)

### Phase 2: Vulnerability Analysis

Based on reconnaissance data, identify the vulnerability type by matching patterns from `references/pwn-patterns.md`:

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
- Adapt for the specific vulnerability:
  - **ret2win**: Calculate padding offset → pack win function address
  - **ROP**: Find gadgets with `ROPgadget` or `ropper` → build ROP chain
  - **Format string**: Determine offset on stack → craft `%n` write payload
  - **Shellcode**: Generate shellcode with pwntools `shellcraft` → inject
- Write the exploit script to `/home/hacker/exploit.py` on the remote host
- Execute with `python3 /home/hacker/exploit.py`
- Capture the flag from output

### Phase 4: Flag Output

- Display the captured flag clearly
- Remind user to submit via the platform web UI: paste into the light-green input box on the challenge page

## Using the Recon Script

The `scripts/recon.sh` script runs automated reconnaissance commands on the remote host:

```bash
# Copy and run on the remote host
scp -i ~/.ssh/key scripts/recon.sh hacker@pwn.cse.hust.edu.cn:/home/hacker/
ssh -i ~/.ssh/key hacker@pwn.cse.hust.edu.cn 'bash /home/hacker/recon.sh'
```

The script executes: `file`, `checksec`, `objdump -d` (main + notable functions), `strings` (filtered), and `readelf` (sections/symbols if available).

## Common Mistakes

- **Not reading DESCRIPTION first**: Always read `/challenge/DESCRIPTION.md` before analyzing — it often contains critical hints
- **Wrong SSH key path**: Default is `~/.ssh/key`, but check user's actual key location
- **Connecting without authorization**: Confirm the user is authorized and get approval before running remote `ssh` or `scp` commands
- **Assuming local tools**: All analysis runs on the remote host where tools are pre-installed — don't try to run checksec/pwntools locally
- **Skipping the decision gate**: Always confirm exploit strategy with user before generating code
- **Forgetting to submit**: Flag is captured but must be manually submitted via the web UI
