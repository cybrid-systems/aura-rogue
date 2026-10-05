#!/usr/bin/env bash
# Stack: M0 Soft race, M1 hot-strategy + worldline, M2 fixture propose,
# optional live MiniMax (SKIP when no key), fixture burn.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/out"

bash "$ROOT/scripts/smoke_soft.sh"
bash "$ROOT/scripts/smoke_m1.sh"
bash "$ROOT/scripts/smoke_m2.sh"

keyfile="/home/box/.config/aura-build/minimax_api_key"
if [[ ! -s "$keyfile" ]]; then
  echo "ROGUE_M2_PROPOSE_LIVE_SKIP"
else
  echo "smoke: live MiniMax propose"
  live="$ROOT/out/live_pack.lambda"
  if python3 "$ROOT/scripts/propose_minimax.py" "$live" 1 "smoke" \
      >/tmp/rogue-propose.stdout 2>"$ROOT/out/live_propose.stderr"; then
    cat "$ROOT/out/live_propose.stderr" >&2 || true
    test -s "$live"
    echo "LIVE_LAMBDA $(head -c 200 "$live")"
    echo
    export ROGUE_PROPOSE_FILE="/workspace/aura-rogue/out/live_pack.lambda"
    bash "$ROOT/scripts/run_soft.sh" /workspace/aura-rogue/soft/rogue/m2_live.aura \
      >"$ROOT/out/m2_live.txt" 2>"$ROOT/out/m2_live.err"
    cat "$ROOT/out/m2_live.txt"
    if [[ -s "$ROOT/out/m2_live.err" ]]; then
      cat "$ROOT/out/m2_live.err" >&2
    fi
    grep -q 'ROGUE_M2_PROPOSE_LIVE_OK' "$ROOT/out/m2_live.txt"
    if grep -qiE 'error:|unbound variable' "$ROOT/out/m2_live.txt" "$ROOT/out/m2_live.err"; then
      echo "ROGUE_M2_PROPOSE_LIVE_FAIL" >&2
      exit 1
    fi
    echo "ROGUE_M2_PROPOSE_LIVE_OK"
  else
    cat "$ROOT/out/live_propose.stderr" >&2 || true
    echo "ROGUE_M2_PROPOSE_LIVE_FAIL" >&2
    exit 1
  fi
fi

echo "smoke: fixture burn"
ROGUE_PROPOSE=0 bash "$ROOT/scripts/burn.sh"

echo "smoke: ROGUE_SMOKE_OK"
