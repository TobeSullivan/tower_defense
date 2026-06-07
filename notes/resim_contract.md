# Re-sim contract — authoritative scoring

**DRAFT for review — not locked.** Open decisions flagged in §9.
Drafted 2026-06-06. Lands at `notes/resim_contract.md`.

This is the keystone spec: it defines how a match score becomes *trustworthy*. It is the
single source of truth for both **Trials leaderboard scores** and **Ranked placement/LP**.
CC executes against it; the determinism conversion (§5) is its hard prerequisite.

---

## 1. The model in one paragraph

The client runs the whole match locally (free to us). At the end, the authoritative
record of that match is just **a seed + the ordered list of what each player did**. The
server **replays that record headless** and derives the true result. The score the client
*reports* is advisory — UX only. **The number that gets written to a leaderboard or ladder
is always the one the server computed by replaying, never the one the client claimed.**

Why this is cheap (the cost answer): we send a recipe, not a video. A full match record is
kilobytes. Replaying it runs headless, as fast as the CPU allows — a 10-minute match
re-sims in a fraction of a second. Server load scales with concurrent *players*, not with
this choice. See `notes/multiplayer_architecture.md` for the hosting cost model.

---

## 2. The match record

The canonical artifact. Everything needed to reproduce one match, exactly.

| Field | Source | Notes |
|---|---|---|
| `seed` | **server** | Already exists (`match_server.gd:90`). Server issues it; client cannot choose it. |
| `map_ref` | server | Identifies the *exact* map to rebuild. Two forms — see §2.1. |
| `ruleset_version` | server | The build/tuning version the match ran under. Re-sim MUST use the matching ruleset. See §9. |
| `input_log` | see §3 | Ordered player actions, each tagged `(tick, player_id, action)`. The only client-authored part. |
| `players` | server | Player ids → identities (Steam id at launch). |
| `connection_timeline` | **server** | Who was connected when. Server-observed truth — not in the client log. Drives disconnect handling (§6). |

A match record is **one shared seed + N input streams** (one per player), because in
multiplayer the boards are coupled by pairwise life transfers — you cannot re-sim one
board in isolation.

### 2.1 `map_ref` — two cases
- **Generated map (Trials/Ranked):** `{ kind: "generated", seed, params_version }`.
  `map_generator.gd` is already fully deterministic from a seed — this half is done.
- **Authored map (Campaign):** `{ kind: "authored", mission_id, tres_version }`. The
  re-sim loads the same `.tres`. Needs a version tag so an edited mission doesn't
  silently invalidate old records.

---

## 3. What the client sends vs. what the server already knows

This is the trust boundary, and it differs by mode — the distinction matters:

**Ranked (multiplayer):** the server is already relaying every player's inputs between
clients in real time to keep them in lockstep. So **the server already holds the
authoritative input log as the match runs** — there is nothing to submit afterward and
nothing to forge. Re-sim at match end is just the server deriving the official placement
from the log it already captured.

**Solo Trials (no live relay):** the client runs alone, then **submits its input log** at
match end. This is the case re-sim is really guarding. The submitted log is the one
client-authored input — so it's the thing being verified.

**Always server-owned (never trusted from the client):** the seed, the ruleset version,
the player identities, and the connection timeline.

---

## 4. How a submitted (solo) log is verified

Not by comparing to a server copy (there isn't one for solo). Verification is two checks:

1. **Legality.** Every action must be legal at the tick it claims — enough gold, valid
   empty cell to build on, a real tower to upgrade/sell, within supply caps. An illegal
   log is rejected outright.
2. **Recompute.** The server re-sims the legal log and **derives the score from the
   simulated outcome.** The leaderboard is written with *that* number.

**Why you can't forge a high score:** you can't write "score = 9,999,999" — the score
isn't a field in the record, it's an *output* of replaying your actions. Editing your
actions changes what the re-sim computes; you can't decouple the two.

**Honest boundary:** re-sim closes *score injection*. It does **not** close *botting* —
a log of legal-but-superhuman play (perfect automated micro) still re-sims to a real
score. That's an anomaly/automation problem handled separately, not by re-sim. Stating
this so we don't over-claim what this buys.

---

## 5. Determinism prerequisite (CC's first job)

Re-sim only works if the same record always produces the same result. From the current
code, **the sim is not deterministic yet.** Three fixes:

1. **Single fixed logical tick.** Today tower fire / spawning / projectiles run in
   `_process(delta)` — tied to render framerate, so different machines compute different
   matches. Move all sim subsystems onto one fixed tick; the tick number is the only
   clock inside the sim (no wall-clock, no frame delta).
2. **One seeded RNG, ordered draws.** Today crit rolls use the global `randf()`
   (`tower.gd:175`), unseeded — the server can't reproduce them. Route *all* combat rolls
   through one per-match seeded generator, with a **defined draw order** (e.g. towers
   resolve in a fixed spatial order each tick) so the sequence of dice is reproducible.
3. **Disciplined sim math.** Same code path, same order of operations, every time.
4. **The build timer is measured in ticks, not wall-clock seconds.** Otherwise the
   round-start moment (§9.2) drifts between machines and breaks the re-sim.

### 5.1 The one real risk: cross-platform float — TEST THIS FIRST
Clients are Win/Mac; the verifying server is Linux. Floating-point math *can* differ
across platforms, which would make the server's re-sim disagree with a legit client and
falsely flag honest players. **Before building anything else, CC should run the cheapest
possible test:** same seed + same scripted inputs on Win, Mac, and the Linux server →
diff the final state. 
- If they match: proceed on floats, keep a determinism regression test.
- If they diverge: move sim-critical accumulation (damage, positions, cooldowns, gold) to
  **fixed-point integer math**. More work, but it's the robust answer and it's better to
  know now than after the contract is built on a bad assumption.

This is the `log-don't-guess` rule applied: don't design around "floats are probably fine,"
measure it.

### 5.2 Bonus: this is also what clean 8-player multiplayer wants
A fixed-tick deterministic sim is the foundation for lockstep MP, not just anti-cheat. The
determinism work pays for both pulled-forward goals at once.

---

## 6. Disconnect / reconnect (locked by Tobe 2026-06-06)

**Model:** a disconnected player's board does **not** disappear — it keeps simulating
exactly as they left it, with no further inputs, and keeps participating in cross-board
life transfers. A "disconnected" badge shows on their board to everyone. If they reconnect,
they resume control of the board as it now stands. If the board is eliminated before they
return, they're eliminated and simply see their final placement on return.

**Why this is the cleanest case for re-sim:** "keeps playing as if they were there" =
*their input stream simply ends at the disconnect tick.* No special simulation rule — the
absence of inputs **is** the behavior. The re-sim replays everyone's inputs in tick order;
a disconnect is just a gap with no actions in it; a reconnect is the log resuming.

**Trust:** disconnect/reconnect timing is **server-observed** (the `connection_timeline`),
never client-claimed — so it adds nothing to the attack surface. And because the board
keeps playing (no freeze, no protection), **there is zero advantage to disconnecting**,
which removes the rage-quit-for-advantage incentive entirely. The badge is pure
presentation, driven by the connection timeline; it does not touch the sim or the score.

---

## 7. What the authoritative re-sim outputs

- **Trials (solo):** total damage → score for the `(map, window, group-size)` board.
- **Trials (group):** combined team damage → per-team board (`notes/leaderboards.md`).
- **Ranked:** true **elimination order** derived from the life-transfer math → placement →
  LP/MMR per `notes/pvp_ladder.md`. The server derives placement; clients can't claim it.

---

## 8. When re-sim runs

- **Ranked:** server already holds the live log → re-sims at match end to derive official
  placement. Sub-second, headless.
- **Solo Trials:** client submits record at match end → server re-sims to derive the score
  *before* writing it to the board. **A leaderboard write never uses a client-claimed
  number.**
- **Storage:** keep records for audit/replay if wanted — kilobytes each, cheapest thing on
  the box. (Also unlocks a future "watch replay" feature for free.)

---

## 9. Decisions — RESOLVED 2026-06-06 (Tobe)

### 9.1 Ruleset versioning → grandfather + reset on patch
Old leaderboard entries stand as-is and are **never re-verified** against a newer sim. The
server only ever re-sims **current-version** records. Any balance/sim patch that moves
scores triggers a **leaderboard/season reset** (clean, matches the seasonal model). No need
to keep old sim versions runnable forever.

### 9.2 Action vocabulary → LOCKED
Tick-tagged player actions in the input log:
- `place_tower(cell)`
- `sell_tower(cell)`
- `upgrade(cell, stat)` — one of the 6 stats

**Round start.** Each round opens with a build phase governed by a fixed-duration **build
timer** (in ticks — see §5.4). The run begins at whichever comes first:
- **Timer expiry** — an engine event, **not** a logged action. Deterministic by
  construction; the re-sim reproduces it from the fixed timer.
- **Early start:**
  - Solo: `start_round` action (the button press), tick-tagged.
  - Trials/Ranked: `vote_start` action per player. The run begins at the tick the **last
    yes-vote** lands (unanimous yes).

So the **authoritative round-start tick = min(timer-expiry, early-start-condition-met)**,
and it is **fully derivable from the log** — the votes/button are logged, the timer is
fixed, so the re-sim computes the exact start tick itself. Nothing extra to claim, nothing
extra to trust. In Ranked this also stays consistent across clients for free: votes are
relayed inputs, so every machine sees the same last-yes tick.

*Assumption to confirm (§ below): the build phase recurs each round and early-start applies
per build window. Micro-open, deferred: can a `vote_start` be retracted? (edge case.)*

### 9.3 Map version tags → yes
Record carries `params_version` (generated maps) and `tres_version` (authored campaign
maps) so map edits don't silently invalidate old scores.

### 9.4 Build-phase recurrence → per round (confirmed)
A build timer + early-start window opens before **every** round, not just the first.

**Contract is locked as of 2026-06-06.** CC handoff in §10.

---

## 10. CC handoff summary (what falls out of this)

1. **Determinism conversion** — fixed tick; seeded combat RNG with ordered draws; the
   cross-platform float test in §5.1 *first*; a determinism regression test.
   **→ DONE 2026-06-07.** §5.1 passed (floats safe, CI guard live). Fixed-step clock in
   `match_coordinator.gd`; subsystems driven via `BoardState.sim_step` (spawn→towers→
   projectiles→mobs); seeded `coordinator.rng` for crit; tick-based build timer. Regression
   harness `src/tools/sim_harness.gd` — full match byte-identical across runs, 0 errors.
   Open: wire server seed into `coordinator.sim_seed` (default 0 today). See STATE "Next step".
2. **Record capture** — emit the §2 record with the tick-tagged input log.
   **→ DONE 2026-06-07.** Lives on `match_coordinator.gd` (`log_input`/`make_record`,
   `record_enabled`, `map_ref`); capture sites in `build_controller`/`tower`; map_loader
   wires seed + map_ref. (Built on the coordinator, not `playtest_log.gd` — the coordinator
   owns `sim_tick`.)
3. **Re-sim runner** — headless replay of a record → authoritative result; legality check
   for submitted solo logs.
   **→ PARTIAL 2026-06-07.** `src/scripts/resim.gd` replays a record → per-board score,
   round-trip verified (live score == re-sim score, `src/tools/sim_harness.gd`). **Still
   open: the §4.1 legality check** (validate a *submitted* solo log — gold/empty-cell/valid-
   target/supply — before trusting it) and record serialization for the submit path.
4. **Wire outputs** — Trials score-write and Ranked placement both read from re-sim output,
   never from client claims. **(Not started.)**
