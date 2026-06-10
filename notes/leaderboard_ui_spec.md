# Leaderboard UI surfaces — CC spec

**Locked 2026-06-06 (session 3).** Lands at `notes/leaderboard_ui_spec.md`.
Build against the locked visual system (`design/VISUAL_SYSTEM.md`) — palette, Fredoka 600 +
outline, radius 16/18, 2px border with +2 bottom bevel, shadow `rgba(0,0,0,.42)` y+5 blur7,
flat fills. **Confirmed icons only** (trophy, arrow_left, stars); no eye icon → use text.
Band tags use palette colors only — nothing invented.

Mockups (the source of truth for layout):
- `notes/mockups/leaderboard_surfaces_mockup.html` — pass 1: post-match panels (1, 2),
  board-browse v1, Trials-select.
- `notes/mockups/leaderboard_ui_pass2.html` — pass 2: ghost ladder, revised board-browse,
  renamed cards. **Supersedes pass-1 board-browse + cards.**
- `notes/mockups/ranked_ladder_bands.html` — final Ranked ladder (global, tiered bands).
  **Supersedes the Ranked view in both above.**

All data comes from re-sim output / Nakama reads (`resim_contract.md`,
`leaderboard_schema.md`). In-match target element is its own doc (`ghost_ladder.md`).

---

## Surface 1 — Trials post-match placement
Sits **inside** the v3 victory panel, below the tier strip — one result screen, one scroll.
- Board context line: `<WINDOW> · <SCALE NAME> · <GROUP>` (e.g. "DAILY · TANGLE · SOLO").
- "You placed **#14** <window-word>" — window-aware: daily→"today", weekly→"this week",
  monthly→"this month".
- **Neighborhood ±2** rows around you (your row green-highlighted), not the whole board.
- Buttons: `View full board` (neutral) · existing Restart / Next.
- Data: re-sim score → board write → read rank + neighborhood.

## Surface 2 — Ranked post-match placement
The result screen itself; **no stars / tier strip** (PVP has no medals).
- "You finished **2nd** of 8" (placement from re-sim elimination order).
- LP block: tier + `47 → 77` + `+30 LP` chip + progress bar + "23 LP to Gold".
- **Global rank delta:** `#41 → #34` (the climbed-places number — the satisfying one).
- **Final order** rows (1–8), reusing the arena row style; eliminated/disconnected show
  `OUT`. Your row highlighted.
- Buttons: `View season ladder` · `Queue again`. (MP uses **Quit Match**, not Restart.)

## Surface 3 — Board-browse (tertiary destination + "view board" target)
Top: category segmented `Trials · Ranked · Campaign`.

**Trials** (`leaderboard_ui_pass2.html` §B):
- Window tabs `Daily/Weekly/Monthly` + a **countdown** ("resets in 3h 41m") = the
  ephemerality signal. **No historical navigation** — only the live windows exist.
- Group-size segmented `Solo/Duo/Trio/Quad`.
- Scale pill row: `Thread · Weave · Tangle · Snarl · Knot`.
- Rows: global rank + name (ellipsis-truncate, fixed height) + score (gold). **Top 100 +
  your neighborhood pinned**, with a "jump to your position" divider. Not infinite scroll.

**Ranked** (`ranked_ladder_bands.html` — the canonical layout):
- Season selector: current `Season N · live` + past frozen seasons. **No future.**
- "Your standing" header: tier · LP (primary) + `#34 of 100` (secondary) + tier-progress
  bar.
- **One continuous ladder, 1→N**, with **band headers** (Masters/Gold/Silver/Bronze/
  Stone) dividing it. Row: global rank + name + `<tier> · <LP>` (Masters shows raw LP).
  Your row green-highlighted. Top + neighborhood, jump divider.
- Past season view = frozen final top-N + your recorded result.

**Campaign:** the 10 all-time mission boards (rank + name + damage).

## Surface 4 — Trials-select entry point (`leaderboard_ui_pass2.html` §C)
The existing select screen, scale cards **renamed** Thread→Knot (was Scale 1–5).
- Each card's best-score row shows your **live rank inline** ("#14 ›") — both informs and
  is the **tap target** → board-browse for that scale + active window. Em-dash if unplayed.
- Small new data need: cards fetch each map's rank, not just local best.

---

## CC handoff
- Four surfaces above + the in-match ghost ladder (`ghost_ladder.md`).
- All reads from Nakama boards written by re-sim; owner = Steam id.
- Icons: confirmed PNGs only; no eye → "Spectating"/text; stars for tiers.
- Ranked display reads the single `ranked_s<N>` ladder; bands derived from the ladder-value
  ranges in `leaderboard_schema.md` §4 — no separate per-tier boards.
EOF
echo done