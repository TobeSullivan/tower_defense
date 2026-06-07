# In-Match HUD — Layout

Repo path: `design/INMATCH_HUD.md`
Status: **SIGNED OFF 2026-06-07** — right panel, board maximization, and tower overlay are locked. Board overlays (pop-out leaderboard, spectate banner, round-end overlay) are noted but not yet specced.

Visual tokens (palette, radii, bevel, shadow, Fredoka SemiBold + outline) are inherited from `design/VISUAL_SYSTEM.md` and not repeated here. This doc is **layout + content**, not styling.

---

## Layout model (locked)

- **One reserved panel** holds everything persistent. It sits **outside the board** on the **right edge** (rail). Full-bleed was tried and failed — UI over the board made towers hard to select/place and occluded the field even with click-through. Persistent UI gets its own space.
- **The board maximizes into the remainder.** Tile size is the readability floor; cell count fills the leftover area (see Board section — TBD, pending the maximization pass). The rail being width-bound is the board's tighter axis, so the rail's px cost comes out of width.
- **Contextual UI overlaps the board** and is dismissable on a deliberate click (select tower → inspector; click off / Esc → gone). Contextual = tower overlay, pop-out leaderboard, spectate banner, round-end overlay. None of these live in the rail.

---

## Right rail — three boxes, top to bottom

Fixed width. Every element justified (label left / value right). Fixed-width containers; text truncates with “…”, never runs on. All buttons share one footprint.

### 1. Status box — identical in both modes
| Row | Value |
|---|---|
| Round | `n / total` |
| Phase | `Build · m:ss` (timer folded into the phase row) / `Run` |
| Supply | `n / total` |
| Gold | `n` (gold-colored) |

### 2. Second box — content swaps by mode, frame fixed
The box never resizes; both modes fill the same fixed frame so the Buttons box anchors at the same Y.

**Trials → SCORE (a climbing display).** Hero row `Current n`, then up to three **rungs** = whatever targets remain *above* current score, ascending:
- Below 1★: `Current` · 1★ · 2★ · 3★
- Past 1★: `Current` · 2★ · 3★ · `‹ghost/leaderboard name›`
- Past 2★, nothing loaded above: `Current` · 3★ · *(blank)* · *(blank)*

Passed stars fall off the top; the next leaderboard ghost climbs in from the bottom. When nothing is ahead (or offline, no backend feed), rungs go blank **but hold their height**. This is the ghost-ladder concept (`notes/ghost_ladder.md`) bound to the rail frame — offline correctly falls to blanks, the named ghost lights up only when the leaderboard backend feeds it.

**Ranked → STANDING.** Hero row `Lives n` (lives is the survival currency, so it's the hero number, paralleling Current in Trials), then:
- `Kills n`
- `Rank n / 8`
- *(one blank slot to match Score-box height)*

**All three Standing values are frozen during the run and resolve together at round end.** Lives transfer resolves at round end, so rank is undefined mid-run — showing a live rank would assert information that doesn't exist yet. No mid-run flicker.

### 3. Buttons box — same footprint every button
Top to bottom; primary is the green slot.

| Slot | Trials | Ranked |
|---|---|---|
| Primary (green) | Start Round | Ready `N/8` (live vote count) |
| Secondary | Speed `3×` | Leaderboard (pop-out toggle) |
| — | Build `[B]` | Build `[B]` |
| — | Menu | Menu |

- **Speed** changes only in run phase (locked rule). During build it is present-but-disabled (greyed). *(Open: empty-until-run instead? — only loose end.)* In run, Start Round is gone (round already running) and Speed is active.
- **Leaderboard** (Ranked) takes Speed's slot and is active in all phases; it toggles the contextual 8-player pop-out.
- **Menu**, not “Pause.” Esc is the universal pause and everyone knows it; the button is a convenience that opens the pause/menu overlay (leave match, see elements). It's labeled Menu because **Ranked cannot be paused** — calling it Pause would be inaccurate.

---

## Kills — home depends on mode
Kills standalone does nothing in Trials (it drives gold but gold is its own indicator), so in **Trials it lives on the tower overlay** as per-tower contribution, not the rail. In **Ranked, kills are the lives-transfer engine** (pairwise zero-sum, Model B), so kills are persistent in the Standing box.

---

## Round-end overlay — one shared system
The round-end resolution beat already has a visual language in Trials (gold / score deltas popping on resolution). Ranked reuses the **same** overlay system to show the **lives swing (`+3 / −2`)** from the pairwise transfer. One overlay to build, not two: Trials shows gold/score gains, Ranked shows lives ±. It's an event over the board, not persistent rail state.

---

## Board maximization (locked)

Cell **size** is fixed (the current good on-screen size); cell **count** grows to fill the area left of the rail. Procedure:

1. Reserve the rail on the right (~280px at 1080p — holds the three boxes; adjustable).
2. The board area is the remainder, minus a small uniform margin.
3. At the **1080p reference**, fit the fixed tile size into that area: `cols = floor(area_w / tile)`, `rows = floor(area_h / tile)`. This yields **25 × 16** (the old 25×14 width was already full; the two extra rows fill what used to be the top/bottom letterbox gutter).
4. **The count is locked universal.** Every player runs 25×16 regardless of monitor — leaderboards and maze geometry must be identical for all. Other resolutions **scale the whole board and center it**; they do not get more or fewer cells. Fixed tile size is the design-time input that *picks* the count, not a per-machine guarantee.
5. If the grid doesn't divide the area evenly, **center the board** (even margins). At 1080p that remainder is tiny (~20px sides, ~28px top/bottom).

Why decide it now: changing the count is normally expensive (resets leaderboards, forces a full campaign remap). Right now leaderboards are empty and the campaign + editor don't exist yet, so this was the cheapest moment to set it. **25×16 is now the number the campaign editor authors against.**

## Tower overlay (locked)

Identical to the current in-game tower panel, with three changes: it's a **contextual overlay** over the board (not a reserved dock), the **hide button is removed**, and **Sell** reads just "Sell" (no refund amount — 30% refund still applies, just not shown).

- **Content:** header (TOWER / name / `Lv n · selected`), six stat rows as one shared 4-column grid — **Stat · Now · Cost · [+]** — aligned down the panel; then **Total damage · n kills**; then **Sell**. No column headers. This is where **Trials kills** live (per-tower contribution).
- **Behavior:** appears on tower-select, dismisses on click-off / Esc. **Fixed anchor** (top-right, hugging the board's right edge) — it does *not* follow the selected tower around the board (a jumping panel would occlude different cells and feel restless). Content updates to the selected tower; position holds.
- **Range ring** draws on the board on select (existing behavior; lives with the overlay, not inside it).
- **Live alternative (not locked, flagged for build time):** the overlay fits inside the rail's lower gap beneath the buttons. Tower-info *in the rail* (appearing on select) would mean zero board occlusion. Locked as an overlay, but in-rail is a close, fair alternative when implementing.

---

## Deferred / next in this area
- **Board overlays** — pop-out 8-player leaderboard (Ranked; no current capture, needs the PVP scene launched for reference) and the spectate banner / green inset frame (per `VISUAL_SYSTEM.md` PVP section).
- **Campaign map editor** — now unblocked by the 25×16 lock; hand-authoring grid (board / obstacle / tower-ghost / checkpoint cells + resizable zone circle). See `notes/polish_punchlist.md` item 9.
- Speed-during-build: present-but-disabled (current) vs empty-until-run — only open detail on the rail.
