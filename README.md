# aura-rogue

Aura Rogue is a Soft self-mutating roguelike. Rooms are Soft FlatAST.
After a room, drop tables and enemy AI are the rule packs that race.
A bad pack is DROP plus rollback. A good pack is KEEP plus stamp. A thin
C viewport, later, only blits frames. There is no C binary in this tree.

Design: [`docs/DESIGN.md`](docs/DESIGN.md).
Milestones: [`docs/m0.md`](docs/m0.md), [`docs/m1.md`](docs/m1.md), [`docs/m2.md`](docs/m2.md).
Repo: https://github.com/cybrid-systems/aura-rogue

This is not a traditional roguelike engine. The product is the Aura loop:
two loot/AI laws race the same seed, the surviving pack is stamped into
main, the loser is dropped.

- **M0** races `rules-greedy` and `rules-safe` on one tiny dungeon. Score
  is rooms cleared, with remaining HP as the clarity tie break.
  `fiber_live` only when both fiber joins return scores (`joins` equals
  spawned, backend > 0). Otherwise `host-sequential`. No C viewport.
  No `hot-strategy`.
- **M1** swaps and heals the `rg:law` slot mid-dungeon, then races the same
  two packs. `fiber_live` only when both fiber joins return scores.
  Otherwise `host-sequential`. See `docs/m1.md`.
- **M2** gates a proposed `(lambda () (list loot-hp loot-atk ai-div))` and
  KEEPs it only when its score is strictly greater than the current main.
  A tie or a loss is DROP plus `hot-strategy:heal!`. HTTP is host-side only.

## Soft smoke

Image `ghcr.io/cybrid-systems/dev:v1.0.9`, Soft tip binary
`/workspace/aura-grok/build/aura` (host GLIBC is often too old — smoke always
runs Soft inside Docker with `--entrypoint /usr/local/bin/gosu`). Soft runs
natively in that container (no nested docker). Never `build_soft4132`.
Needs `AURA_SANDBOX=off`. `python3` is the host interpreter for
`scripts/propose_minimax.py` and `scripts/burn.sh`.

```bash
bash scripts/smoke_soft.sh    # M0 → ROGUE_M0_OK
bash scripts/smoke_m1.sh      # SWAP / HEAL / MUTATE / KEEP / DROP → ROGUE_M1_OK
bash scripts/smoke_m2.sh      # fixture propose → ROGUE_M2_PROPOSE_OK
bash scripts/smoke.sh         # the stack, plus live MiniMax or LIVE_SKIP + burn
bash scripts/burn.sh          # 3 rounds, 4 rooms; fixtures if ROGUE_PROPOSE=0
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
It forwards `ROGUE_ROOMS`, `ROGUE_BURN_ROUNDS`, `ROGUE_ROUND_DIR`,
and `ROGUE_PROPOSE_FILE` into the container.

On seed `20261005`, four rooms, M0 keeps `rules-safe` (mid 2, 4 rooms,
score `4000010`) and drops `rules-greedy` (mid 1, 3 rooms, score
`3000000`). On the tip binary that race is
`WORLD line=fiber_live backend=2 joins=2/2` (`backend=2` is CLI thread
fallback, not serve-async). If the joins do not land, the line is
`host-sequential` and `fiber_live` is not printed.

M1's mid-run swap prints `SWAP` / `HEAL` / `MUTATE room=2 loot-boost=1`,
then the same greedy/safe scores. M2's better fixture (`loot-hp=5`) scores
`4000014` and is KEEP. The greedy fixture is DROP. Fixture burn (4 rooms)
KEEPs round 1 (`4000014` vs safe `4000010`) and DROPs a tie and a worse
body. Detail in `docs/m1.md` and `docs/m2.md`.

## Engine

| Path | Role |
|------|------|
| `soft/rogue/world.aura` | integer dungeon, fight, loot, score, `TAPE` |
| `soft/rogue/rules.aura` | greedy vs safe, honest race, KEEP/DROP |
| `soft/rogue/hot.aura` | `rg:law` hot-strategy seed / swap / heal |
| `soft/rogue/propose.aura` | gate → race vs shadow → KEEP / DROP |
| `soft/rogue/m0_smoke.aura` | `ROGUE_M0_OK` |
| `soft/rogue/m1_smoke.aura` | `ROGUE_M1_OK` |
| `soft/rogue/m2_propose_smoke.aura` | `ROGUE_M2_PROPOSE_OK` |
| `soft/rogue/burn.aura` | multi-round propose burn |
| `scripts/run_soft.sh` | docker tip binary |
| `scripts/smoke_soft.sh` | M0 evidence |
| `scripts/smoke_m1.sh` | M1 evidence |
| `scripts/smoke_m2.sh` | M2 fixture evidence |
| `scripts/burn.sh` | burn rounds |
| `scripts/propose_minimax.py` | host MiniMax → lambda file |
| `scripts/smoke.sh` | stack entry |

Rules, short form (detail in `docs/m0.md`):

- Start is `hp=11 atk=3` from one LCG step of seed `20261005`.
- Greedy is loot `+1/+2`, `ai-div=1`. Safe is loot `+4/+0`, `ai-div=2`.
- Death is out of play for that room. That room is not kept.
- Score is `alive * 1000000 + clarity` (integers).
- KEEP requires the greater score. This seed is `longer-survival-stamp`.

## How to burn

```bash
# Offline fixtures (no key, no network):
ROGUE_PROPOSE=0 bash scripts/burn.sh
# → ROGUE_BURN_OK, MAIN score=4000014, joins=6/6

# Live MiniMax when ~/.config/aura-build/minimax_api_key exists:
bash scripts/burn.sh
# Uses api.minimax.cn only (never api.minimaxi.com)
```

## Soft tip

Soft dialect is copied from aura-arena / aura-evolve. No invented APIs.
No secrets in the tree. Apache-2.0.

- Binary: `/workspace/aura-grok/build/aura`
- Image: `ghcr.io/cybrid-systems/dev:v1.0.9`
- Env: `AURA_SANDBOX=off AURA_PIPELINE_STRICT=0 AURA_PATH=/workspace/aura-grok/lib`

Soft is not Restricted mode. `fiber_live` is not printed unless the joins
landed. M0 does not register a hot-strategy.

---

# aura-rogue（中文）

活世界在 Soft：整数地牢、掉落和敌人 AI 规则包赛同一颗种子。活得更久的
KEEP 进主世界，先死的 DROP。没有 C 视口。只有两条 fiber 都 join 到分数时
才印 `fiber_live`（这次是 `backend=2 joins=2/2`，线程回退，不是假装的
调度器）。没有 join 就印 `host-sequential`。

M1 中途 `swap!` / `heal!` 换 `rg:law` 规则包，第 2 房印 `MUTATE`。
M2 由宿主脚本向 MiniMax 要一条 `(lambda () (list loot-hp loot-atk ai-div))`，
Soft 做门禁，分数不比当前主包高就 DROP 并 heal。密钥不进仓库，也不调用
`api.minimaxi.com`。

```bash
bash scripts/smoke.sh          # M0 + M1 + M2 + 实况或 SKIP + burn
ROGUE_PROPOSE=0 bash scripts/burn.sh
```

种子 `20261005`、四间房：M0 `rules-safe` 分数 4000010 KEEP，`rules-greedy`
3000000 DROP。M2 更好包（loot-hp=5）4000014 KEEP，greedy DROP。
镜像 `ghcr.io/cybrid-systems/dev:v1.0.9`，Soft 二进制
`/workspace/aura-grok/build/aura`。仓库里没有密钥。
