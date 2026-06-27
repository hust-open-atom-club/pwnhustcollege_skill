# pwnhustcollege_skill

Codex skill for authorized pwn/binary exploitation challenges on pwn.hust.college.

## Description

`pwnhustcollege_skill` helps Codex work through authorized pwn.hust.college challenges end to end. It guides Codex to connect to the platform over SSH, read the challenge description, run binary reconnaissance, identify likely vulnerability patterns, and generate a pwntools exploit template for `/challenge/solve`.

The skill is designed for the pwn.hust.college environment, where analysis tools such as pwntools, gdb, pwndbg, gef, radare2, ghidra, strace, and checksec are available on the remote host. It also handles architecture-aware exploit generation, including x86, x86_64, ARM, and AArch64 binaries.

## What It Does

- Confirms authorization and SSH key path before connecting to the platform.
- Reads `/challenge/DESCRIPTION.md` and analyzes `/challenge/solve`.
- Runs reconnaissance with `file`, `checksec`, `readelf`, `objdump`, `strings`, and symbol inspection.
- Uses bundled pwn pattern references to classify common vulnerabilities.
- Generates architecture-aware pwntools exploit code using the detected ELF architecture and word size.

## Requirements

- Codex with local skills support.
- Node.js 18 or newer for `npx` installation.
- SSH access to `hacker@pwn.cse.hust.edu.cn`.
- Permission to work on the target pwn.hust.college challenge.

## Install

Install the published npm package with `npx`:

```bash
npx pwnhustcollege-skill install
```

The package is published on npm as [`pwnhustcollege-skill`](https://www.npmjs.com/package/pwnhustcollege-skill).

To install directly from the GitHub repository instead:

```bash
npx github:hust-open-atom-club/pwnhustcollege_skill install
```

This installs the skill into:

```text
${CODEX_HOME:-$HOME/.codex}/skills/pwnhustcollege
```

To install to a custom skill directory:

```bash
npx pwnhustcollege-skill install --path /path/to/skills/pwnhustcollege
```

Restart Codex after installation so the skill metadata is reloaded.

Running the package without `install` only prints usage and does not modify your skills directory.

```bash
npx pwnhustcollege-skill
```

## Manual Install

From this repository, install into the default Codex skills directory:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills/pwnhustcollege"
rsync -a --delete \
  --exclude '.git' \
  --exclude '.gitignore' \
  --exclude 'package.json' \
  --exclude 'bin' \
  --exclude 'README.md' \
  SKILL.md scripts references \
  "${CODEX_HOME:-$HOME/.codex}/skills/pwnhustcollege/"
```

## Update

Rerun the `npx pwnhustcollege-skill install` or manual install command after a new npm release, or after pulling or editing the skill locally.

## Repository Layout

- `SKILL.md`: skill metadata and workflow
- `bin/install.js`: `npx` installer
- `scripts/recon.sh`: remote reconnaissance script
- `scripts/exploit_template.py`: pwntools exploit template
- `references/pwn-patterns.md`: vulnerability pattern reference
