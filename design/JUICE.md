# JUICE — Wend game-feel & motion

Status: **foundation LOCKED 2026-06-08.** Lens + motion language + break-the-grid grammar are settled and validated against the victory surface. Per-surface specs build on this base.

Visual tokens (palette, radii, bevel, shadow, Fredoka SemiBold + outline) are inherited from `design/VISUAL_SYSTEM.md`. This doc is motion + grammar, not styling. References render the feel: `notes/mockups/juice_motion_reference.html` (the language) and `notes/mockups/victory_screen_mock.html` (it applied).

---

## The lens

Juice for Wend is **not audio.** TD players mute — shooting chatter and an EDM bed are exactly what gets turned off first. So our game-feel comes through **transitions, animations, impact events, staged set-pieces** (victory, rank climb, high-score / ghost climb), and **UI that overlaps the play surface** instead of sitting in boxes beside it.

The reference is Atlus (Persona / Metaphor), but the **principle, not the skin.** We steal the behavior — nothing teleports, UI moves with intent, UI is allowed to break its box and overlap the field — and wear Wend's own look. Fredoka is round and friendly, so the register is closer to a warm comic-poster attitude than Persona's gothic edge. **Not red and black.**

The guardrail that protects the game from the style: **the playfield stays legible and calm.** Angle, overlap, and motion live in the frame and in the moments between rounds. Nothing churns the board while it's being read to place a tower.

Optional and **undecided** (Tobe's call): a single restrained sting on impact-events only — victory, rank-up, a high-score beat. Consistent with the lens (those are the staged moments), but flagged, not built. Easy to omit entirely.

---

## Motion foundation

### Timing scale (ms)
`XS 90` taps / micro-feedback · `S 160` single element · `M 260` panels, transitions (the default) · `L 440` staged set-pieces only · `screen 320` full screen-to-screen. Exits run on the short end. **L is earned** — spent on a hero moment, never on routine UI.

### The three verbs
Nothing teleports. Everything arrives, settles, or leaves.
- **Arrive** (enter + settle): `cubic-bezier(.34, 1.32, .5, 1)` — fast in, ~10–12% overshoot, settle. The signature curve.
- **Settle** (reposition, no overshoot): `cubic-bezier(.22, 1, .36, 1)`.
- **Leave** (exit, always quicker than the arrival): `cubic-bezier(.4, 0, 1, 1)`.

### Emphasis pop
A value that just changed gets one quick scale pop `1.0 → 1.14 → 1.0` over `S`. That is the entire vocabulary for "a number moved" (gold spent, score climbed, LP gained).

### Stagger
Sibling sets cascade, never arrive all at once: `60ms` per item baseline; set-pieces may widen to `~130ms` for drama. Stars fill low → high; ladder rungs climb bottom → top. Cap the visible stagger so a long list doesn't crawl.

### Spatial grammar
Elements enter from the edge they belong to — rail from the right, toast from the top, a result rises from the play. **The board never moves while it's being read.**

### Reduced-motion
A toggle drops overshoot → plain ease and shortens durations. Cheap, do it.

### Arm before reveal
Set an element's (or a whole screen's) pre-entrance state **before** it becomes visible, then animate in. Never reveal a screen at its final state and then re-trigger the entrance — that flashes the end frame first and reads as a bug. This is a sequencing rule, not a design change (it was the one real glitch caught in the mocks).

### Godot map for CC
`arrive → TRANS_BACK, EASE_OUT` (tune the overshoot constant *down* to ~10–12%; Godot's default back is stronger) · `settle → TRANS_QUINT, EASE_OUT` · `leave → TRANS_CUBIC, EASE_IN` · `pop → quick scale tween on TRANS_BACK, EASE_OUT`. **Promote the durations + curves to one shared helper** so no surface re-invents them — that single source is what makes it read as one authored hand.

---

## Break-the-grid grammar

- A styled box is **one tidy unit**: text contained, sitting on the box's own angle. Text never escapes its container.
- **Overlap happens between elements** — box over playfield, box over a neighboring panel — *not* text over its own box. Text breaking out reads as a bug.
- **Depth is the box's own bevel** (the +2/+3 bottom border) **plus its shadow.** Never a stacked duplicate shape behind it — that move is rejected, it reads awkward.
- **Tilt is subtle** — ~3–4° off-axis, on frames, heroes, and set-pieces only.
- **Precision / interactive targets stay axis-aligned**: buttons, the build cursor, the board itself, and any panel of numbers you read or act on (the tower inspector's stat grid). Style lives on the frame around them, not on the thing you're aiming at.
- **No invented assets.** The attitude — angled boxes overlapping the surface, contained outlined Fredoka, bold color blocks — comes from transforms + type + palette only. The reference art's pointing hand, dice, and character cut-ins are bespoke assets we do not have.

---

## Surface backlog

All distinct surfaces are mocked and validated this session. Mocks live in `notes/mockups/`.

- ✅ **Motion foundation** — locked (this doc). Ref: `juice_motion_reference.html`.
- ✅ **Victory / result screen** — staged choreography + break-the-grid hero. Ref: `victory_screen_mock.html`. Folds in **polish #7**: star tiles get a full clean outline (the corner-only outline that read as a bug is gone). Leave-only flow.
- ✅ **In-match HUD** — rail arrival (stagger from the right), the contextual tower overlay overlapping the live board (deliberately **low-overlap** — only the header tab angles; the stat grid stays square because it is read and aimed at), and the build→run phase flip. Ref: `inmatch_hud_mock.html`. The in-rail overlay alternative stays unused unless a real playtest shows the corner panel occludes needed cells.
- ✅ **Meta menu** (home / Thread-Weave-Tangle select) — the attitude surface, where overlap + angle flex (tilted, offset hero buttons; angled name tabs). Includes the home→select **screen transition** (the connective-tissue layer). Ref: `meta_menu_mock.html`.
- ✅ **Staged climbs** — Ranked Surface 2 (placement, LP bar fill on the settle curve, tier-up promotion as a staged L-duration set-piece) and the in-match ghost-ladder (passed rung leaves the top, next ghost arrives from the bottom; never asserts a live mid-match rank). Ref: `staged_climbs_mock.html`.
- ✅ **Round-end overlay** — one transient over-board system, two payloads: Trials gold/score deltas pop, Ranked pairwise lives swing. Ref: `round_end_overlay_mock.html`.

### In-match beats
- **Tower color deepen on upgrade:** the pale→vivid→near-black ramp is **existing, locked game identity, unchanged.** The juice contribution is *only* the emphasis-pop on the tower at the instant it deepens, so an existing-but-silent state change lands as a felt beat. (Shown in `inmatch_hud_mock.html`; the mock's indigo colors are an illustrative placeholder, not a proposed recolor.)
- **Wave clear** (toast drops from the top), **build→run phase flip**, **supply-out cursor stop** (= polish #8: auto-stop the placement ghost when it can't be afforded). All reuse the arrive/leave/pop vocabulary; no separate mock.

### Inherits the grammar (no separate spec needed)
Pause overlay, Settings overlay, Campaign select, and generic menu transitions inherit the established grammar: panels arrive/leave on the foundation curves, headers may tab-angle, content that is read or acted on stays square. Build them against this doc + the meta-menu mock.

## Open dials (numbers, not shape)
Hero tilt −3.5° and the 130ms set-piece stagger are provisional — tune in playtest. The impact-event audio sting is flagged and undecided.
- **Arrive overshoot = ~11%** (`Motion.ARRIVE_OVERSHOOT_S = 1.8`, easeOutBack, distance-independent). **Discrepancy flagged:** the motion-reference mock's literal `cubic-bezier(.34,1.32,.5,1)` only overshoots **~3.4%** — gentler than this doc's prose ("~10–12%") + the CC Godot-map both call for. CC honored the stated 10–12% (the shape — overshoot-then-settle — is what's locked; magnitude is a dial). If playtest wants the mock's gentler settle, drop `ARRIVE_OVERSHOOT_S` toward ~1.0 (≈3–4%).

## Implementation status (CC)
- ✅ **Shared motion helper** — `src/scripts/motion.gd` (preload-static, mirrors `UiStyle`). The single source: timing tokens (XS/S/M/L/SCREEN), the three verbs (`arrive`/`settle`/`leave`, usable on a whole Tween or one tweener), faithful distance-independent `arrive_ease`, `pop`/`fade_in`/`fade_out`/`slide_in`/`arrive_property`, `cascade`/`stagger_delay` (capped), and a `reduced` flag + `dur()` scaler wired through everything (Settings toggle pending). Pure math verified headless: `src/tools/motion_test.{gd,tscn}` (arrive curve · reduced-motion · stagger cap · tokens, all ✅).
- ✅ **First adoptions** — the two surfaces that hand-rolled tweens now route through `Motion`: the round-end **wave-clear toast** (`round_toast.gd` — drops from the top on the arrive curve, holds, leaves faster; a named JUICE beat) and the in-match PVP **leaderboard drawer** (`leaderboard_panel.gd` — arrive in / leave out). Parse + match-build verified headless; **feel is a playtest item** (tween motion isn't headless-testable).
- ✅ **Victory / result choreography** (2026-06-08, CC) — `match_end_panel.gd` campaign victory now stages per the mock: scrim **dims** (M) → gold **hero drops in** tilted, earning the L duration → 3 **star tiles cascade low→high** (set-piece 130ms stagger), each earned tile **pops on land** → **DAMAGE fades + ticks 0→value + pops** → leave-only **buttons settle in** staggered. Armed-before-reveal (all alpha 0 before show); stars/buttons animate on scale (not position) so the score-tick's text re-layout can't stomp them; only the hero (settled well before the tick) uses a positional drop. Reduced-motion compresses the whole sequence via `Motion.dur()`. Verified by mid + settled windowed captures (`tools/victory_shot.{gd,tscn}`); composition + staging correct, **tween feel is a playtest item**. (Pre-existing, not from this pass: the in-match rail HUD stays visible above the scrim at match-end — a layering decision from the rebuild, separate from motion.)
- ✅ **In-match HUD rail + tower-deepen pop** (2026-06-08, CC) — `rail.gd`: the three rail boxes (Status / Score / Buttons) **cascade in** on match start, staggered top→bottom (delays 0.20/0.29/0.38), armed-before-reveal. Implementation note: the boxes live in a VBoxContainer that re-sorts as the status text refreshes (the build timer ticks), which **stomps animated `position`** — so the arrival rides **scale (0.9→1, arrive overshoot) + fade**, not a literal slide (render transforms the container never touches). `tower.gd`: on `upgrade()`, an **emphasis-pop** on the tower sprite at the instant it deepens (the colour ramp itself stays the existing locked identity, unchanged/instant — the pop is the only juice); scoped to an in-tree sprite so the headless re-sim replay doesn't spawn tweens. Also generalized `Motion.pop` to pop about the node's **current** scale (so the 0.12-scaled tower sprite works) and **fixed a `Motion.slide_in` delay bug** (a `set_parallel` before the move made staggered slides ignore their delay). Verified by mid-cascade capture (box3 still arriving while box1 settled) + regression (sim_harness/ghost_ladder/campaign_verify/motion_test green); **feel is a playtest item**.
- ✅ **Meta menu** (2026-06-08, CC) — three parts, all landed:
  - **Home attitude + entrance** (`home_screen.gd`): break-the-grid look (Trials high, Ranked low, both tilted −2.5° off-axis) + staggered arrival (season/title ease in → heroes drop into their off-axis offsets, L → Campaign rises → corners fade last). Each hero sits in a plain Control **slot** so it offsets + animates freely inside the HBox.
  - **Select-card cascade** (`pve_select.gd`, `campaign_select.gd`): cards arrive staggered (scale+fade, container-safe) on load; Trials re-cascades per tab switch.
  - **Cross-scene transition** (`scene_manager.gd`, the connective tissue): SceneManager swaps scenes hard, so it **snapshots the outgoing screen into a cover** on a top CanvasLayer (layer 128), swaps underneath, then **slides the cover off** (forward wipes left, back/home wipes right) revealing the new screen mid-entrance. Scoped to the 5 menu navigations — entering a MATCH stays a hard cut. First-nav guard (boot→home), empty-snapshot guard (headless), and a 1s safety free so a stuck cover can't soft-lock nav. **Feel/verify is a playtest item** (live-checked by Tobe).
- ▶ **Remaining surfaces** inherit the helper: staged climbs (Surface 2 + ghost ladder), and the generic pause/settings arrivals.

## Note for CC
Every spec here is **motion + layout + type + color — no new art.** When implementing, route through `Motion` (don't re-invent durations/curves), match the mocks' feel, and **arm entrance state before revealing a screen** (see Arm before reveal — baked into `slide_in`/`arrive_property`).
