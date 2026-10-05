#!/usr/bin/env bash
# Stack: M0 Soft race (headless). Later milestones add hot-strategy / propose.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/out"

bash "$ROOT/scripts/smoke_soft.sh"

echo "smoke: ROGUE_SMOKE_OK"
