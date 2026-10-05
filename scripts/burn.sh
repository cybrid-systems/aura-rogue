#!/usr/bin/env bash
# Multi-round propose → gate → play. Default 3 rounds, 4 rooms.
# ROGUE_PROPOSE=1 calls MiniMax when a key file exists; otherwise fixtures.
# ROGUE_PROPOSE=0 always uses soft/rogue/fixtures/burn (offline).
# Run: bash scripts/burn.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ROGUE_BURN_ROUNDS="${ROGUE_BURN_ROUNDS:-3}"
export ROGUE_ROOMS="${ROGUE_ROOMS:-4}"
export ROGUE_PROPOSE="${ROGUE_PROPOSE:-1}"
mkdir -p "$ROOT/out"
keyfile="/home/box/.config/aura-build/minimax_api_key"

if [[ "$ROGUE_PROPOSE" == "1" && -s "$keyfile" ]]; then
  dir="$ROOT/out/burn-rounds"
  rm -rf "$dir"
  mkdir -p "$dir"
  prev=""
  note="none"
  for ((r=1; r<=ROGUE_BURN_ROUNDS; r++)); do
    out="$dir/${r}.lambda"
    echo "burn: propose round ${r}"
    if [[ -n "$prev" ]]; then
      python3 "$ROOT/scripts/propose_minimax.py" "$out" "$r" "$note" "$prev" \
        >/tmp/rogue-burn-propose.stdout 2>"$ROOT/out/burn_propose_${r}.stderr"
    else
      python3 "$ROOT/scripts/propose_minimax.py" "$out" "$r" "$note" \
        >/tmp/rogue-burn-propose.stdout 2>"$ROOT/out/burn_propose_${r}.stderr"
    fi
    cat "$ROOT/out/burn_propose_${r}.stderr" >&2 || true
    test -s "$out"
    echo "burn: round ${r} $(tr -d '\n' < "$out")"
    prev="$out"
    note="round ${r} wrote a lambda"
  done
  export ROGUE_ROUND_DIR="/workspace/aura-rogue/out/burn-rounds"
else
  if [[ "$ROGUE_PROPOSE" == "1" ]]; then
    echo "burn: no MiniMax key; fixture rounds" >&2
  else
    echo "burn: fixture rounds"
  fi
  export ROGUE_ROUND_DIR="/workspace/aura-rogue/soft/rogue/fixtures/burn"
fi

echo "burn: rounds=${ROGUE_BURN_ROUNDS} rooms=${ROGUE_ROOMS} dir=${ROGUE_ROUND_DIR}"
bash "$ROOT/scripts/run_soft.sh" /workspace/aura-rogue/soft/rogue/burn.aura \
  | tee "$ROOT/out/burn.txt"
grep -q 'ROGUE_BURN_OK' "$ROOT/out/burn.txt"
grep -q 'KEEP reason=higher-score-stamp' "$ROOT/out/burn.txt"
grep -q 'DROP reason=lower-score-rollback' "$ROOT/out/burn.txt"
grep -E -q 'WORLD line=(host-sequential|fiber_live)' "$ROOT/out/burn.txt"
echo "burn: ROGUE_BURN_OK"
