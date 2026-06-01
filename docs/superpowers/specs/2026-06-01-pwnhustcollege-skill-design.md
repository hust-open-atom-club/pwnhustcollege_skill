# pwnhustcollege Skill Design

## Overview

A Claude Code skill that helps students solve binary exploitation challenges on the pwn.hust.college platform. The skill automates SSH connection, binary analysis, and exploit generation, only pausing at key decision points for user input.

## Platform Context

- **Platform**: pwn.hust.college (HUST cybersecurity education platform, built on CTFd)
- **SSH**: `ssh -i ~/.ssh/key hacker@pwn.cse.hust.edu.cn`
- **Challenge directory**: `/challenge/` (contains binary + `DESCRIPTION` file)
- **Flag location**: `/flag`
- **Persistent home**: `/home/hacker` (survives across challenge sessions)
- **Pre-installed tools**: pwntools, pwndbg, gdb, gef, radare2, ghidra, strace, etc.
- **Practice mode**: available with sudo/root access, uses placeholder flags

## Skill Trigger

User provides a challenge identifier (number, name, or module reference). The skill:
1. Parses the challenge reference
2. SSHes into the platform
3. Navigates to `/challenge`
4. Begins automated analysis

## Architecture: 4 Phases

### Phase 1: Connection & Reconnaissance

Automated via SSH command execution on the remote host:
- `cat /challenge/DESCRIPTION` — read challenge description
- `file /challenge/solve` — identify binary type
- `checksec /challenge/solve` — check binary protections (canary, NX, PIE, RELRO)
- `objdump -d /challenge/solve` or `r2 -q -c 'pdf @main' /challenge/solve` — disassemble key functions
- `strings /challenge/solve` — extract embedded strings

Output: a structured analysis report showing protections, binary type, and potential vulnerability surface.

### Phase 2: Vulnerability Analysis & Decision

Based on reconnaissance data, the skill:
- Identifies the likely vulnerability type (stack overflow, format string, ret2win, ROP, heap, etc.)
- Presents the finding with supporting evidence (disassembly snippet, offset calculations)
- Proposes an exploit strategy
- Asks the user to confirm before proceeding

This is the key decision point — the user approves or redirects the exploit approach.

### Phase 3: Exploit Generation & Execution

The skill generates a pwntools exploit script targeting the identified vulnerability:
- For ret2win: calculate offset → overwrite return address with win function
- For ROP: build ROP chain using available gadgets
- For format string: craft format string payload
- For shellcode: generate and inject shellcode (if NX disabled)

The script is written to `/home/hacker/exploit.py` on the remote host via `scp` or heredoc, then executed to retrieve the flag.

### Phase 4: Flag Output

- Display the captured flag
- Remind the user to submit it via the platform web UI
- Optionally save the solution notes locally

## File Structure

```
pwnhustcollege_skill/
├── skill.md                    # Skill definition and workflow
├── scripts/
│   ├── connect.sh              # SSH connection helper
│   ├── recon.sh                # Automated reconnaissance commands
│   └── exploit_template.py     # Base pwntools exploit template
└── references/
    └── pwn-patterns.md         # Common vulnerability patterns and exploit strategies
```

## Key Design Decisions

1. **Remote execution, not local**: All analysis and exploit tools run on the remote host where they're pre-installed. The skill issues SSH commands, it doesn't download binaries locally.
2. **pwntools for exploit generation**: Since pwntools is pre-installed on the platform, exploits are generated as pwntools Python scripts and executed remotely.
3. **One decision gate**: The skill only pauses once — at the vulnerability analysis → exploit strategy transition. Everything else is automated.
4. **No web UI automation**: Flag submission remains manual via the platform's web interface. The skill focuses on the SSH-based solve workflow.

## Scope

This skill covers binary exploitation (pwn) challenges on pwn.hust.college. It does not handle:
- Reverse engineering challenges (different workflow)
- Web/crypto/misc challenges
- Challenges requiring GUI interaction
