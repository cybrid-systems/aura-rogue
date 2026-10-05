# aura-rogue — design (Aura-native)

The product is a live Soft FlatAST dungeon: rooms are AST, player HP/ATK
are integers, and two drop/AI rule packs race the same seed. A thin C
program would only blit a tape later. It is not the simulator. M0 does
not ship that viewport.

This is the same loop aura-arena and aura-evolve already play. Soft owns
the state. Rule packs are what a later hot-strategy swap would replace.
Worldlines race. A bad line is dropped. The surviving pack is stamped
into the main world. The tape says why.

## One sentence

Two loot/AI laws clear the same seeded rooms. The one that survives more
rooms is KEEP. The one that dies earlier is DROP. `fiber_live` is printed
only when both joins land.

## North star

1. **FlatAST owns the world.** Rooms, HP, ATK, loot params, AI divisor,
   and the main rule slot are workspace data.
2. **Bad pack: DROP.** Its score is recorded. Its final HP is not the
   main world. The slot is not updated to it.
3. **Surviving pack: KEEP.** The winning parameters are the main slot,
   then that pack is run again from the same seed so the live world is
   the kept tape.
4. **Replayable tape.** `TAPE`, `RACE`, `KEEP`, `DROP`, `WORLD` are the
   audit. A later C blit may draw them. It does not choose the winner.
5. **Honest fibers.** The race tries `fiber:spawn` / `fiber:join`. The
   stamp is `fiber_live` only when both fiber ids are distinct, both
   joins return a number, the join count equals the spawn count, and
   `fiber:spawn-backend` is greater than 0. Otherwise the same thunks
   run host-sequential and the line is `host-sequential`. A label with
   no join is not a worldline. `backend=2` is the CLI thread fallback,
   not serve-async.

M0 does not call `hot-strategy:swap!`, `hot-strategy:heal!`,
`mutate:rebind`, or `eval-current`. aura-go already saw `eval-current`
wipe a live board.

## What M0 actually does

```
m0_smoke.aura
    │  load world + rules
    ▼
same seed, two packs
    │  rules-greedy (mid 1)  loot +1/+2, ai-div=1 (aggressive)
    │  rules-safe   (mid 2)  loot +4/+0, ai-div=2 (timid)
    ▼
compare integer scores
    │  score = alive * 1000000 + clarity
    │  alive   = rooms cleared before death
    │  clarity = remaining HP (tie break)
    │  KEEP longer survival (clarity breaks a survival tie)
    │  DROP the shorter life
    ▼
replay winner into the main world
    │  TAPE after each cleared room
    ▼
ROGUE_M0_OK
```

The killing room is not committed. That is the rollback of the death
room.

## Soft vs C

| Soft owns | C may do (later) |
|-----------|------------------|
| dungeon, HP/ATK, rule slot, score | blit of the tape |
| which pack is main | nothing about KEEP/DROP |
| the fiber stamp | nothing about joins |

C must not keep a second dungeon.

## Soft ≠ Restricted

| | This product | Not this product |
|--|----------------|------------------|
| World | FlatAST workspace defines | A native plugin / `.so` region |
| Sandbox | **off** (same as aura-arena / aura-evolve smoke) | Restricted mode as the play loop |
| Fibers | honest `fiber_live` or `host-sequential` | a label with no join |

## Score

`alive * 1000000 + clarity`.

- Start HP/ATK come from one LCG step of seed `20261005`
  (`(seed * 75 + 74) mod 65537`): HP = `10 + rng mod 3`, ATK = `2 + rng mod 2`.
- Four rooms. Enemy table is fixed: `(5,2) (7,3) (10,4) (14,5)`.
- Each exchange: player strikes first; if the enemy lives, it strikes
  back with `max(1, qdiv(raw-atk, ai-div))`.
- After a clear, apply loot `(loot-hp, loot-atk)`.
- Death does not increment `alive`. Clarity is the final HP (0 if dead).

KEEP uses the greater score. On this seed the lives differ, so the reason
is `longer-survival-stamp` / `shorter-survival-rollback`. A survival tie
would use `higher-clarity-stamp`. A full tie keeps greedy.

## Non-goals (M0)

- No C viewport, no OpenGL, no SDL.
- No `hot-strategy`, no propose burn, no MiniMax.
- No invented Soft APIs. Dialect matches aura-arena fiber race.
- No secrets in the tree.

## M1 / M2

M1 registers `rg:law` as a real `std/hot-strategy` slot, swaps and heals
mid-dungeon, prints `MUTATE room=2 loot-boost=1`, then races greedy vs safe
with the same honest `fiber_live` rule as M0. Detail: `docs/m1.md`.

M2 gates a host-written `(lambda () (list loot-hp loot-atk ai-div))` from
MiniMax (`api.minimax.cn` only), KEEPs only on a strict score improvement,
else DROP + `heal!`. Detail: `docs/m2.md`. No keys in the tree.
