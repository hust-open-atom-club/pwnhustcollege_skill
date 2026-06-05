---
name: pwnhustcollege
description: Use when solving pwn/binary exploitation challenges on pwn.hust.college — the user wants to SSH into the platform, needs binary analysis or exploit generation for CTF challenges
---

# pwnhustcollege Skill

## Overview

Automates solving binary exploitation challenges on pwn.hust.college. Connects via SSH, analyzes challenge binaries, identifies vulnerabilities, and generates pwntools exploits — pausing only at key decision points for user confirmation.

## Platform Context

- SSH: `ssh -i ~/.ssh/key hacker@pwn.cse.hust.edu.cn`
- Challenge binary: `/challenge/solve`
- Description: `/challenge/DESCRIPTION.md`
- Flag: `/flag`
- Home: `/home/hacker` (persistent across sessions)
- Pre-installed: pwntools, pwndbg, gdb, gef, radare2, ghidra, strace, checksec

## When to Use

- User mentions pwn.hust.college challenges
- User needs binary exploitation help on the platform
- User wants to SSH into the platform and analyze a binary

## Workflow

### Phase 1: Connection & Reconnaissance

1. SSH into the platform: `ssh -i ~/.ssh/key hacker@pwn.cse.hust.edu.cn`
2. Read the challenge description: `cat /challenge/DESCRIPTION.md`
3. Run automated reconnaissance by executing `scripts/recon.sh` on the remote host via SSH
4. Present a structured analysis report to the user:
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

- **Not reading DESCRIPTION first**: Always read `/challenge/DESCRIPTION` before analyzing — it often contains critical hints
- **Wrong SSH key path**: Default is `~/.ssh/key`, but check user's actual key location
- **Assuming local tools**: All analysis runs on the remote host where tools are pre-installed — don't try to run checksec/pwntools locally
- **Skipping the decision gate**: Always confirm exploit strategy with user before generating code
- **Forgetting to submit**: Flag is captured but must be manually submitted via the web UI
