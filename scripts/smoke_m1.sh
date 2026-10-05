#!/usr/bin/env bash
# Soft M1 smoke: mid-run SWAP/HEAL/MUTATE + honest fiber race → ROGUE_M1_OK.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/out"
echo "smoke: m1 hot-strategy"
bash "$ROOT/scripts/run_soft.sh" /workspace/aura-rogue/soft/rogue/m1_smoke.aura \
  >"$ROOT/out/m1_smoke.txt" 2>"$ROOT/out/m1_smoke.err"
cat "$ROOT/out/m1_smoke.txt"
if [[ -s "$ROOT/out/m1_smoke.err" ]]; then
  cat "$ROOT/out/m1_smoke.err" >&2
fi
fail=0
grep -q 'MUTATE room=2 loot-boost=1' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'SWAP name=rg:law room=2 reason=mid-swap' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'HEAL name=rg:law room=3 reason=probe' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'GATE reject reason=gate' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'RACE greedy=' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'KEEP mid=' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'DROP mid=' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'ROGUE_M1_OK' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'WORLD line=' "$ROOT/out/m1_smoke.txt" || fail=1
if grep -q 'WORLD line=fiber_live' "$ROOT/out/m1_smoke.txt"; then
  grep -q 'WORLD line=fiber_live backend=[1-9][0-9]* joins=2/2' "$ROOT/out/m1_smoke.txt" || fail=1
elif grep -q 'WORLD line=host-sequential' "$ROOT/out/m1_smoke.txt"; then
  :
else
  fail=1
fi
if grep -q 'ROGUE_M1_FAIL' "$ROOT/out/m1_smoke.txt"; then
  fail=1
fi
if grep -q 'WORLD_FAIL\|GATE_FAIL\|SWAP_FAIL\|HEAL_FAIL\|SLOT_FAIL' "$ROOT/out/m1_smoke.txt"; then
  fail=1
fi
if grep -qiE 'error:|unbound variable' "$ROOT/out/m1_smoke.txt" "$ROOT/out/m1_smoke.err"; then
  fail=1
fi
if [[ "$fail" -ne 0 ]]; then
  echo "smoke_m1: ROGUE_M1_OK checks failed" >&2
  exit 1
fi
echo "smoke_m1: ROGUE_M1_OK"
