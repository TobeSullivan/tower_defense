# Open items — backlog ledger

Living backlog. Status as of 2026-06-05 (design session 2). STATE.md's "Open questions"
points here; this is the full picture so STATE itself stays small.

Status key: **RESOLVED** · **NEAR (in progress, almost there)** · **REC-PENDING**
(assistant recommended, your reaction outstanding) · **DIRECTION-SET** (approach chosen,
system still undesigned) · **UNTOUCHED** (never actually discussed) · **BLOCKED-DATA**
(needs real playtest data) · **OWN-SESSION** (large enough to be its own session)

---

## Resolved 2026-06-05 (session 2 — design wrap)
- **Game NAME → "Wend"** (locked; confirmed clear on Steam as a game title — only collisions are a user profile + the unrelated *Wendigo*). "Maze Battle TD" was the placeholder. "Wend" = to make one's winding way (fits the maze). It's a dictionary word → weak trademark + zero genre signal in search, so genre lives in a **subtitle/tagline** (e.g. "Wend — a maze battle TD"), not the name. **Unblocks the Steam page.**
- **PVE/PVP player-facing names → "Trials" (PVE) and "Ranked" (PVP).** Trials maps onto the daily/weekly/monthly windows (not endless, which killed "Survival"); Ranked is sharper than "Versus" since the mode *is* the LP ladder. Co-op was dropped (undersells solo Trials). Home hierarchy unchanged: Trials + Ranked heroes, Campaign tertiary, season ambient. **Code-side string rename for CC** + a doc label-pass in `DESIGN_MODES.md`.
- **PVE window cadence → keep daily/weekly/monthly (5 maps each), as built.** The weekly/monthly-lead recommendation was overridden.
- **Vertical slice → not happening as a formal vertical slice.** The beta/demo plays that role instead (game is near scope-complete; we're knocking out items, not adding much).
- **Leaderboard group scoring → per-team, separate boards by size** (solo/duo/trio/quad). Per-player rejected (co-op is a shared effort; per-head attribution is arbitrary + nudges kill-hogging). Matches the board split already in `notes/leaderboards.md`.
- **PVP LP curve + most season specifics → designed.** Full spec in `notes/pvp_ladder.md` (MMR-anchored net-positive: base LP table, hidden-MMR engine, Bronze→Masters at 100 LP/tier, demotion buffer, Masters uncapped/honest, season reset lands at 25 LP of dropped tier). Numbers are playtest dials; shape is locked. Only sub-item left: inactivity decay (deferred, optional).
- **Soft caps (damage/range/attack-speed) → governed-by-economy, no change now.** The cost ramp is already quadratic-cumulative and a new tower is ~20× more gold-efficient than deep upgrades, so breadth beats depth and the economy (gold scarcity + round cap) is the natural cap. The user's playtests confirm single-tower carries don't happen in practice. **Revisit trigger (CC-side, against the live log):** more starting gold, longer runs, higher supply caps, or the ~23×14 board rescale changing match gold output. Do NOT add a cost bend before that.
- **Accessibility / colorblind (zones) → label + color + uniform shape baseline, plus icons where verified.** Zones are already text-labeled, so nobody's locked out; color is reinforcement. Shape stays uniform (varied shapes read as clutter). Verified icons from the pack: attack-speed → `fast_forward`, slow → `waiting` (hourglass, beats a stopwatch), damage → `energy` (lightning bolt). **Range → label-only** — confirmed there is NO target/crosshair/reticle/clean-radius glyph anywhere in `art.zip` (only magnifying-glass/zoom, which misread as "search"). CC copies `energy.png` + `waiting.png` from `art.zip` into `src/assets/ui/icons/` and imports (currently only a 15-icon subset is committed). A range glyph would be a one-off asset to add later, not a blocker.

## Resolved 2026-06-05 (session 1)
- **Platform fork** → PC/Mac-first; mobile *never* (revisit only on viral success); console if successful. LOCKED.
- **Pricing band** → $10–15 PC (the $5 was the mobile number). One-time premium, no microtransactions, no premium pass.
- **Progression persistence** → Steam Cloud on PC (Nakama still holds MP/leaderboard profiles).
- **Leaderboard backend** → Nakama. **Frontend placement** → contextual (Trials select + post-match; Ranked ladder; campaign card). See `notes/leaderboards.md`.
- **In-match UI layout** → approved in mockup (recessed surround + bounded arena, flex, right inspector dock). CC to implement from `notes/mockups/`.
- **Victory screen** → redesigned (no em dash, tier strip, comma score).
- **Steelman A** (PVE is the spine, PVP optional) → accepted.
- **Steelman B** (single-tower mazing is a PILLAR; randomness lives in points/zones/supply) → LOCKED. Not to be re-litigated.
- **Ranked PVP is a real shipping ambition** (not just friends-testing) → confirmed; anti-cheat + queue population are on the launch critical path.

## Resolved 2026-06-06
- **Board final tile count → 25×14. LOCKED + IMPLEMENTED.** Feel-check passed at 23×14, then widened 1 tile each side (→25) so the board fills more of the frame. `Grid.COLS/ROWS` + `MapResource` default bumped; all 10 campaign `.tres` rescaled from the 20×11 originals (`src/tools/rescale_campaign.gd`, run 20→25) + thresholds path-scaled; generated PVE/PVP maps auto-grow. **Iconography note:** use the existing committed UI assets as-is — do NOT chase the mockup's placeholder glyphs.
- **In-match UI rebuild → DONE (v3 bounded layout).** Reversed the full-bleed `play_rect`: reserved top bar + bottom strip + a permanent right inspector dock; recessed dark surround + bright bordered board (`map_loader`); floating tower-drawer → docked content-height inspector (`tower_drawer`); board floats clear of the bars with balanced top/bottom gaps; path/road clamped to the board edge (no off-board spill); drop shadows halved. **Victory screen → redesigned** (stars + "You won!", comma score, tier strip with ✓). Remaining UI polish (minor, user's call): inspector dark-on-dark when empty; road rounded end-cap slight overhang.
- **Soft-caps revisit trigger note:** the board-rescale lever fired (now 25×14, more match gold output) — economy/supply re-tune is still deferred (BLOCKED-DATA) but CC should check the live log against the new board before any cost bend.

## Direction set — system still undesigned
- **Anti-cheat** — tiered: PVE trusts client; ranked uses authoritative deterministic re-sim (server re-derives true kills from seed+build inputs). Real work, on critical path. Design in its own session. See `notes/server_decision.md`.
- **Cosmetic DLC packs** — fork presented (one-time, upfront, no gacha) as the recurring-revenue lever to fund perpetual seasons. Undecided. Values boundary: paid items never overlap earnable/prestige rewards.
- **Campaign-as-paid-DLC** — demand-driven posture set (ship the 10, build a paid chapter only if players ask; campaign may be a product pillar, not just tutorial). Not built.

## Untouched — never actually discussed
- **Group PVE (Trials) lobby mechanics** — team/individual scoring vote, ready-up flow. (Scoring itself is now locked per-team; the *lobby flow* is still undesigned.)
- **Onboarding for non-SC2 players** — does a newcomer grok mazing without the (now-optional) campaign?
- **Community hub** — Discord/subreddit; feedback loop + where wishlisters/friend-testers gather. See `notes/gtm.md`.
- **IP/legal** — Random TD "spiritual successor" (Blizzard). Confirm clearance/safe framing; may be handled earlier — don't assume.
- **Localization** — never raised; fine to defer (English-first niche revival).

## Blocked on playtest data
- **Bronze/Silver/Gold threshold calibration.**
- **PVP seed-convergence** — shared-seed ranked could converge to identical optimal mazes; eyeball in playtest. Not a design change.

## Own session (large)
- **Juice / game-feel pass** — reference here (Persona/Atlus organic UI overlap), then CC (tweens, particles, hit-pause, screen shake, road shader). Light taste mockup exists.
- **Full GTM / marketing plan** — Steam page (now unblocked by the name), capsule/tags/trailer spec, Next Fest/demo, where the SC2 crowd gathers, streamer outreach. See `notes/gtm.md`.
