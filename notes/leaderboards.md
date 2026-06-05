# Leaderboards — design note

Rewritten 2026-06-05. Supersedes the old "with-bots / without-bots" matrix, which is
**dead**: ranked has **no bots, ever** (locked 2026-06-02), so the bot/no-bot split no
longer exists.

## Backend

**Nakama handles this.** It ships leaderboards + tournaments (seasonal, auto-reset,
history-preserving) as first-class features. We are not building a ranking service — we
define board IDs, write a score on match-end, and configure season rollover as Nakama
tournaments. Self-hosted on the same box.

### Board set
- **Campaign:** 10 boards, one per mission. Metric = total damage. **All-time, not
  seasonal** (it's a tutorial; resetting it is pointless).
- **PVE:** split by `(map, window, group size)`. Combined damage isn't comparable across
  group sizes, so solo / duo / trio / quad get **separate boards**. Empty boards cost
  nothing at beta scale. Metric = total damage.
- **PVP:** one **season rank ladder** (LP-based), not a damage board. This is "the season
  leaderboard."

### Group scoring (PVE)
Recommendation: rank groups **per-team** (the group's combined score vs other groups of the
same size), since PVE co-op is a shared effort. Per-player is the alternative — **still open**.

## Frontend — leaderboards are contextual, not a destination

Decided 2026-06-05. Leaderboards are **not** a home-screen hero (the home hierarchy is
locked: PVE/PVP heroes, Campaign tertiary, season ambient). At most a tucked-away tertiary
entry beside Settings for browsing. Primary surfacing:

- **PVE select = the home.** That screen already shows the 5 maps + your best score and has
  daily/weekly/monthly tabs. Tap a map → its board for the selected window.
- **Post-match = the highest-value surface.** On run end: "You placed #14 this week" + the
  rows around you + "View full board." Cheap, big retention lever.
- **PVP ladder** behind the PVP area ("Ranked" view) and, more importantly, post-match as
  LP delta + ladder position.
- **Campaign** board reachable from the mission card and post-match.

## Open
- Group scoring: per-team (recommended) vs per-player — confirm.
- Exact board-id schema / Nakama tournament config.
- PVE window cadence: for a small pool, foreground **weekly/monthly** over daily (a daily
  board barely populates before it resets). Daily becomes a bonus sprint. (Recommendation,
  not yet locked.)
- PVP season specifics (decay, LP→reward) — see season pass + a future PVP-season note.
