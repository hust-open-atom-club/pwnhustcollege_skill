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
