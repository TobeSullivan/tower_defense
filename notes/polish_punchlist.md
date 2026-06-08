# Polish / Bug Punch-list

Repo path: `notes/polish_punchlist.md`
Source: 2026-06-07 in-game review (Tobe). These are CC tasks unless noted. Items 5 and 6 are resolved by the in-match HUD design; the rest are open.

---

1. **White corner artifacts (home / main menu).** Bottom corners show a few px of white, reads like the screen has rounded corners. Tiny but wrong — track down and remove. Also present on the in-game board's bottom-left/right corners (item within #6's surface).

2. **Text too thin.** Fredoka's variable-font default weight is Light (300), and "set bold" silently no-ops in Godot. Fix per `design/VISUAL_SYSTEM.md`: ship a static **Fredoka-SemiBold.ttf** and point the project default font at it (most reliable), or `variation_embolden`. Promote weight + outline to a shared `Theme` so it can't regress screen-by-screen.

3. **Em-dashes in strings.** Literal "—" appears in UI strings (e.g. "Trials — daily/weekly"), reads unnatural. Sweep all user-facing strings and remove/replace.

4. **Speed bug + speed rules.** If default speed is set to 3×, the round starts at 3× but the speed **button doesn't reflect it** (state desync). Also: speed must **never change during build phase** — run phase only. To speed up build, the player just hits Start Round. (Matches the rail spec: Speed is disabled in build.)

5. **Remove the "hide" button on tower info.** ✅ Resolved in design — tower overlay has no hide button (`design/INMATCH_HUD.md`).

6. **In-game layout rework.** ✅ Resolved in design — reserved right rail + maximized 25×16 board + contextual tower overlay (`design/INMATCH_HUD.md`, reference mock `notes/mockups/inmatch_assembly.html`). CC implements against that spec. (The board white-corner artifact from #1 is part of this surface.)

7. **Victory screen star tiles.** The 1/2/3-star tiles have a white outline on the corners only — looks flat/inverted and awkward next to the bottom buttons. Either a full outline or none; the corner-only outline reads as a bug, not a choice.

8. **Build mode — out of supply.** When the player runs out of supply, automatically **stop the tower hover/placement cursor** (don't leave a placement ghost you can't afford to place).

9. **Campaign rework + hand-authoring editor.**
   - ✅ **Grid editor BUILT** (`notes/tools/map_editor.html`, 2026-06-08) — 25×16, paints board / obstacle / tower-ghost / ordered checkpoints + entry/exit + resizable bonus-zone circles (radius from the locked formula), validates a legal entry→checkpoints→exit path, imports an existing `.tres` losslessly (beats preserved), saves real `mission_NN.tres`.
   - ✅ **M1–M5 re-authored + tutorial copy reviewed** (2026-06-08) — new hand-built mazes, reviewed beat copy (undead framing, no em-dashes, 1/2/3-star not medals, several beats cut), correct names. Mission 1 now has its 1 checkpoint (the old 0-checkpoint bug is moot).
   - ⏳ **CC follow-ups** (see `STATE.md` → Next step): ghost outline clears when the player builds off-suggestion; M3 outline rides its single load beat; keep threshold fields (1/2/3-star, not bronze/silver/gold); M1 win flow = leave-only → next map / Trials / Ranked; `grid_size` default → 25×16; anchor resolve check in the new HUD.
   - ⏳ **Tooltips/tips dismissable-only** — still open (CC): make tutorial callouts user-dismissable, not auto-dismiss toasts.
