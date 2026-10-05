# aura-rogue

Aura Rogue is a Soft self-mutating roguelike. Rooms are Soft FlatAST.
After a room, drop tables and enemy AI are the rule packs that race.
A bad pack is DROP plus rollback. A good pack is KEEP plus stamp. A thin
C viewport, later, only blits frames. There is no C binary in this tree.

Design: [`docs/DESIGN.md`](docs/DESIGN.md).
Milestone: [`docs/m0.md`](docs/m0.md).
Repo: https://github.com/cybrid-systems/aura-rogue

This is not a traditional roguelike engine. The product is the Aura loop:
two loot/AI laws race the same seed, the surviving pack is stamped into
main, the loser is dropped.

- **M0** races `rules-greedy` and `rules-safe` on one tiny dungeon. Score
  is rooms cleared, with remaining HP as the clarity tie break.
  `fiber_live` only when both fiber joins return scores (`joins` equals
  spawned, backend > 0). Otherwise `host-sequential`. No C viewport.
  No `hot-strategy`.

## Soft smoke

Image `ghcr.io/cybrid-systems/dev:v1.0.9`, Soft tip binary
`/workspace/aura-grok/build/aura` (host GLIBC is often too old — smoke always
runs Soft inside Docker with `--entrypoint /usr/local/bin/gosu`). Soft runs
natively in that container (no nested docker). Never `build_soft4132`.
Needs `AURA_SANDBOX=off`.

```bash
bash scripts/smoke_soft.sh    # M0 → ROGUE_M0_OK
bash scripts/smoke.sh         # stack entry (M0 today)
```

Scripts may be mode `100644` in git. Always invoke them with `bash`.

Manual Soft run:

```bash
sudo docker run --rm --entrypoint /usr/local/bin/gosu \
  -v /workspace/aura-grok:/workspace/aura-grok \
  -v "$PWD":/workspace/aura-rogue \
  -w /workspace/aura-rogue \
  -e AURA_PATH=/workspace/aura-grok/lib \
  -e AURA_PIPELINE_STRICT=0 \
  -e AURA_SANDBOX=off \
  -e AURA_BIN=/workspace/aura-grok/build/aura \
  ghcr.io/cybrid-systems/dev:v1.0.9 \
  dev /workspace/aura-grok/build/aura /workspace/aura-rogue/soft/rogue/m0_smoke.aura
```

`scripts/run_soft.sh` is the same invocation. The source path is `$1`.

On seed `20261005`, four rooms, M0 keeps `rules-safe` (mid 2, 4 rooms,
score `4000010`) and drops `rules-greedy` (mid 1, 3 rooms, score
`3000000`). On the tip binary that race is
`WORLD line=fiber_live backend=2 joins=2/2` (`backend=2` is CLI thread
fallback, not serve-async). If the joins do not land, the line is
`host-sequential` and `fiber_live` is not printed.

## Engine

| Path | Role |
|------|------|
| `soft/rogue/world.aura` | integer dungeon, fight, loot, score, `TAPE` |
| `soft/rogue/rules.aura` | greedy vs safe, honest race, KEEP/DROP |
| `soft/rogue/m0_smoke.aura` | `ROGUE_M0_OK` |
| `scripts/run_soft.sh` | docker tip binary |
| `scripts/smoke_soft.sh` | M0 evidence |
| `scripts/smoke.sh` | stack entry |

Rules, short form (detail in `docs/m0.md`):

- Start is `hp=11 atk=3` from one LCG step of seed `20261005`.
- Greedy is loot `+1/+2`, `ai-div=1`. Safe is loot `+4/+0`, `ai-div=2`.
- Death is out of play for that room. That room is not kept.
- Score is `alive * 1000000 + clarity` (integers).
- KEEP requires the greater score. This seed is `longer-survival-stamp`.

## Soft tip

Soft dialect is copied from aura-arena / aura-evolve. No invented APIs.
No secrets in the tree. Apache-2.0.
