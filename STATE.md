# State — Maze Battle TD
Last updated: 2026-06-05

> **Read order:** `claude-rules.md` → `RULES.md` → this file → `notes/open_items.md` (full backlog) → only the specific file the task needs.
> **History:** older session logs were moved to `STATE_ARCHIVE.md` — reference only, don't load unless you're digging into a past decision.

---

## ⚠️ Recent reversals — do NOT act on stale instructions
The archive (and older memory) describe a **mobile-first** direction. That is **DEAD as of 2026-06-05.**

- **Platform: PC/Mac-first. Mobile NEVER** (console if the game succeeds; mobile only revisited on viral success). A mobile build would be a *fork* — different board, different leaderboard, different game — not a port, because you can't resize the board and keep crossplay.
- **Board is going UP to ~23×14** (~+50%, ~66px tiles), **reversing the 20×11 mobile shrink.** The old "design for the smallest screen / rescale campaign to 20×11" plan is superseded: the board **grows**, and campaign `.tres` rescales to the **new** size, not 20×11. Final tile count pending the user's feel-check of `notes/mockups/inmatch_board_fullsize_1920.html`.
- **In-match UI:** current spec is the **2026-06-05 mockups** — recessed dark-grass surround + bright bounded board arena, flex layout, right inspector dock, redesigned victory panel. This **supersedes the earlier full-bleed-grass mockup**. See `notes/mockups/`.
- **Pricing: $10–15 (PC band)** — the old $5 was the mobile number. Saves = **Steam Cloud**.

---

## Current focus
**Dedicated-server deploy (active CC track).** M1 headless netcode is committed (`d884368`); next concrete step is deploying the headless Godot server to the **Hetzner VPS** (CPX11, Ashburn) — user provisioning the box. One match per server for now (Option A); concurrency is the later Option-B step. See `notes/server_decision.md`, `notes/remote_beta_plan.md`, `notes/multiplayer_architecture.md`.

The 2026-06-05 design direction (reversals above) governs the next UI/board work.

## Last session (2026-06-05 — design, no code)
Locked PC-first; resized board to ~23×14; redesigned in-match UI + victory (mockups); set revenue ($10–15 premium, free cosmetics, cosmetic-DLC-pack fork still open), leaderboard backend (Nakama) + contextual frontend, Hetzner for the beta, and a tiered anti-cheat *direction*; accepted PVE-as-the-spine and **single-tower mazing as a locked pillar** (randomness lives in points/zones/supply — don't re-litigate). Full open ledger with per-item status: `notes/open_items.md`.

## Next step
- **CC:** finish the Hetzner deploy. Then rebuild in-match UI from `notes/mockups/`, and re-rescale board + campaign `.tres` to the confirmed ~23×14 (**not** 20×11).
- **Design (mostly their own sessions):** game NAME (blocks the Steam page) · juice/game-feel pass · full GTM + Steam page · anti-cheat system · season-pass numbers · the 3 pending recommendations (PVE window cadence, vertical slice, leaderboard group scoring).

## Recently touched files
- `notes/open_items.md` — full backlog ledger, **start here for what's open**
- `notes/leaderboards.md`, `notes/season_pass.md`, `notes/pvp_lobby.md`, `notes/server_decision.md`, `notes/gtm.md`
- `notes/mockups/inmatch_ui_layout_v3.html`, `inmatch_board_fullsize_1920.html`, `inmatch_juice_taste.html`

## Open questions / blocked on
Full per-item status lives in **`notes/open_items.md`**. Active right now: board final tile count (feel-check pending) · game NAME (blocks Steam page) · 3 recommendations awaiting a call (PVE window cadence, vertical slice, leaderboard group scoring).
