# Leaderboard board-id schema + Nakama config

**Locked 2026-06-06 (session 3).** Lands at `notes/leaderboard_schema.md`.
Resolves the "Exact board-id schema / Nakama tournament config" item from
`notes/leaderboards.md`. Strategic decisions (board set, metric, group scoring, windows)
are locked there; this is the naming + config + retention layer CC builds against.

Scores are written from **re-sim output only** (`notes/resim_contract.md`), never from a
client-claimed number. Owner of every entry = the player's **Steam id** (identity model).

---

## 1. Nakama primitive per board type

- **Leaderboard** — persistent, no reset. → **Campaign** (all-time).
- **Tournament** — a leaderboard with a reset schedule (cron). → **Trials** daily/weekly/
  monthly boards, configured to **purge on reset** (see §3) — we do NOT retain past cycles.
- **Seasonal leaderboard** — one per Ranked season, all players, frozen at season end
  (see §4).

Metric for damage boards = **total damage**, sorted **descending**, operator `best`
(re-running a map only improves your entry).

---

## 2. Campaign — 10 persistent leaderboards

All-time (it's the tutorial; resetting is pointless). One per mission.
```
campaign_m01 … campaign_m10
```
Type: leaderboard (no reset). Sort desc, operator `best`. Metric: total damage.
**Exempt from the balance-patch reset** (§ re-sim contract 9.1) — all-time by design.

---

## 3. Trials — EPHEMERAL tournaments, window × scale × group-size

Dimensions (from `DESIGN_MODES.md`):
- **Window** (= reset schedule): `daily` · `weekly` · `monthly`
- **Scale tier** (= the 5 curated maps, named): `thread` `weave` `tangle` `snarl` `knot`
- **Group size** (= which board a run posts to): `solo` · `duo` · `trio` · `quad`

### Id convention
```
trials_<window>_<scale>_<group>
e.g.  trials_daily_tangle_solo
      trials_weekly_knot_quad
```
**Count:** 3 × 5 × 4 = **60 tournaments**, stable ids.

### EPHEMERAL — purge on reset (revised this session)
A Trials board exists **only while its window is live.** When the window resets, the old
board is **purged, not archived** — there is no historical browsing of past days/weeks/
months. Rationale: a daily board per player across seasons is enormous storage nobody ever
looks at. Storage stays **flat and constant** — you only ever hold the currently-active
boards (60 of them), regardless of how long the game has been live.

- The player's **personal best** is kept locally (`save_data.gd`), independent of the board.
- Board-browse for Trials therefore shows only the **three currently-live windows**; a
  **countdown** ("resets in 3h 41m") communicates the ephemerality (UI spec).
- Nakama config: tournament with the reset schedule, **minimal history retention** (active
  cycle only).

### Group-size posting rule (from `DESIGN_MODES.md:85–91`)
Locked at match start:
- **Team score (default):** group's summed damage → board matching group size.
- **Individual score (voted):** *each* player's own damage → the **`solo`** board.
- `solo` aggregates all individual-scored entries; `duo`/`trio`/`quad` only hold
  team-summed entries of that exact size.

### Per-window map seeds (server-owned) — links to re-sim
At each window reset the **server generates the 5 seeds** (one per scale) and stores them
keyed by `(window, window_date, scale)`, so everyone that window shares the same 5 maps.
A run's re-sim `map_ref` = `{ kind:"generated", seed:<that window/scale seed>,
params_version }`. Board → seed → re-sim, joined.

---

## 4. Ranked — ONE global tiered ladder per season (revised this session)

Supersedes the earlier "only Masters is a board" model. **Every ranked player is on one
continuous ladder, 1 → N.** Tiers are **named bands** of that single ladder, not separate
boards. This keeps the durable tier identity (does real work in a small pool) while making
sure nobody below the top is invisible.

### One leaderboard per season
```
ranked_s<season>     e.g. ranked_s1, ranked_s2
```
- Type: leaderboard, one per season. Sort **descending** by a **monotonic ladder value**,
  operator `set` (the player's current authoritative value, not a max).
- **Ladder value = tier_base + LP**, so the single sort key spans all tiers:
  - Stone 0–99 · Bronze 100–199 · Silver 200–299 · Gold 300–399 · **Masters 400+
    (uncapped)**.
  - Global rank = position in this sort. **Bands fall out of the value ranges.**
- The LP/MMR engine in `notes/pvp_ladder.md` is **unchanged** — this is purely how we
  store/sort/display. Hidden MMR remains per-account state.

### Display (UI spec)
Primary = the player's **tier · LP** (stable, only moves when they play). Secondary = their
**live global rank** (#34 of 100). Band headers (Masters→Bronze) divide the list.

### Seasons: current live · past frozen · no future
- **Current season:** the live `ranked_s<N>` leaderboard.
- **Past seasons:** at season end, snapshot a **frozen final top-N** plus **each player's
  own final record** ("162nd · Masters · S1"). Cheap — one frozen snapshot per past season,
  not a living board. History preserved indefinitely (`pvp_ladder.md`).
- **No future seasons** (they don't exist yet — nothing to show).
- Season reset behavior (drop one tier, land at 25 LP) per `pvp_ladder.md`.

---

## 5. Open config bits (small — not blockers)

1. **Reset anchors:** proposed **UTC** — daily 00:00, weekly Mon 00:00, monthly 1st 00:00.
2. **Season length** — `pvp_ladder.md` defines reset behavior, not duration. A number for
   the season-pass session.

---

## 6. CC handoff summary

- 10 `campaign_m*` leaderboards (all-time, balance-reset-exempt).
- 60 `trials_*` tournaments, **purge-on-reset** (active cycle only), names thread→knot.
- One `ranked_s*` leaderboard per season: all players, sort key = tier_base+LP, bands by
  range; past seasons frozen as top-N + per-player record; no future.
- Server generates + stores 5 per-window Trials seeds at each reset; feed into re-sim
  `map_ref`.
- UTC reset anchors (§5.1, pending confirm).
- All writes from re-sim output (`resim_contract.md` §8); owner = Steam id.
