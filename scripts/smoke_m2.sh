#!/usr/bin/env bash
# M2 fixture propose. No MiniMax. Prints ROGUE_M2_PROPOSE_OK.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/out"
echo "smoke: m2 fixture"
bash "$ROOT/scripts/run_soft.sh" /workspace/aura-rogue/soft/rogue/m2_propose_smoke.aura \
  >"$ROOT/out/m2_propose.txt" 2>"$ROOT/out/m2_propose.err"
cat "$ROOT/out/m2_propose.txt"
if [[ -s "$ROOT/out/m2_propose.err" ]]; then
  cat "$ROOT/out/m2_propose.err" >&2
fi
fail=0
grep -q 'PROPOSE tag=propose_reject' "$ROOT/out/m2_propose.txt" || fail=1
grep -q 'PROPOSE tag=propose_heal' "$ROOT/out/m2_propose.txt" || fail=1
grep -q 'PROPOSE tag=propose_drop' "$ROOT/out/m2_propose.txt" || fail=1
grep -q 'PROPOSE tag=propose_keep' "$ROOT/out/m2_propose.txt" || fail=1
grep -q 'KEEP reason=higher-score-stamp' "$ROOT/out/m2_propose.txt" || fail=1
grep -q 'DROP reason=lower-score-rollback' "$ROOT/out/m2_propose.txt" || fail=1
grep -q 'HEAL name=rg:law' "$ROOT/out/m2_propose.txt" || fail=1
grep -q 'ROGUE_M2_PROPOSE_OK' "$ROOT/out/m2_propose.txt" || fail=1
grep -E -q 'WORLD line=(host-sequential|fiber_live)' "$ROOT/out/m2_propose.txt" || fail=1
grep -q 'RACE base=' "$ROOT/out/m2_propose.txt" || fail=1
if grep -q 'ROGUE_M2_PROPOSE_FAIL' "$ROOT/out/m2_propose.txt"; then
  fail=1
fi
if grep -q 'WORLD line=fiber_live' "$ROOT/out/m2_propose.txt"; then
  python3 - "$ROOT/out/m2_propose.txt" << 'PY' || fail=1
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r"WORLD line=fiber_live backend=(\d+) joins=(\d+)/(\d+)", text)
if not m or m.group(2) != m.group(3) or int(m.group(1)) <= 0 or int(m.group(2)) <= 0:
    sys.exit(1)
PY
fi
if grep -qiE 'error:|unbound variable' "$ROOT/out/m2_propose.txt" "$ROOT/out/m2_propose.err"; then
  fail=1
fi
if [[ "$fail" -ne 0 ]]; then
  echo "smoke_m2: ROGUE_M2_PROPOSE_OK checks failed" >&2
  exit 1
fi
echo "smoke_m2: ROGUE_M2_PROPOSE_OK"
