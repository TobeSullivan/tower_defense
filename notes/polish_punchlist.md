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
   - Tooltips/tips currently behave as **toasts that auto-dismiss** before they can be read. Make them **user-dismissable only** (stay until the player closes them).
   - The **tower ghosts teach a poor maze** — the example build is bad mazing. Needs re-authored example mazes.
   - **Mission 1 has 0 checkpoints; it must have 1.** (Bug in the current `mission_01.tres`.)
   - Build an **interactive grid editor** (HTML) at the locked **25×16** size so Tobe can hand-author each campaign map by coloring cells: board / obstacle / tower-ghost / checkpoint (ordered), plus one **resizable circle** for bonus zones (type + magnitude; radius follows the locked inverse-size formula). Exports a spec CC turns into `MapResource` `.tres`. Should validate: a legal entry→checkpoints→exit path exists, checkpoint count > 0, entry + exit present. **Unblocked now that the board is 25×16.**
