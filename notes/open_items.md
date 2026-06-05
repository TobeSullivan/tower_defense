# Open items — backlog ledger

Living backlog. Status as of 2026-06-05 (design session). STATE.md's "Open questions"
points here; this is the full picture so STATE itself stays small.

Status key: **RESOLVED** · **NEAR (in progress, almost there)** · **REC-PENDING**
(assistant recommended, your reaction outstanding) · **DIRECTION-SET** (approach chosen,
system still undesigned) · **UNTOUCHED** (never actually discussed) · **BLOCKED-DATA**
(needs real playtest data) · **OWN-SESSION** (large enough to be its own session)

---

## Resolved 2026-06-05
- **Platform fork** → PC/Mac-first; mobile *never* (revisit only on viral success); console if successful. LOCKED.
- **Pricing band** → $10–15 PC (the $5 was the mobile number). One-time premium, no microtransactions, no premium pass.
- **Progression persistence** → Steam Cloud on PC (Nakama still holds MP/leaderboard profiles).
- **Leaderboard backend** → Nakama. **Frontend placement** → contextual (PVE select + post-match; PVP ladder; campaign card). See `notes/leaderboards.md`.
- **In-match UI layout** → approved in mockup (recessed surround + bounded arena, flex, right inspector dock). CC to implement from `notes/mockups/`.
- **Victory screen** → redesigned (no em dash, tier strip, comma score).
- **Steelman A** (PVE is the spine, PVP optional) → accepted.
- **Steelman B** (single-tower mazing is a PILLAR; randomness lives in points/zones/supply) → LOCKED. Not to be re-litigated.
- **Ranked PVP is a real shipping ambition** (not just friends-testing) → confirmed; anti-cheat + queue population are on the launch critical path.

## Near (in progress)
- **Board final tile count** — direction is ~23×14 (~+50%, ~66px tiles); **pending your tile-feel check** of `inmatch_board_fullsize_1920.html`. Lever if cramped = *fewer* cells (e.g. 21×13 ≈72px), never bigger+denser. Reverses the 20×11 mobile shrink; campaign `.tres` re-rescale follows.

## Recommendation made — your reaction outstanding
- **PVE window cadence** — recommended weekly/monthly lead over daily for a small pool (daily barely populates before reset). You haven't weighed in.
- **Vertical slice as the next big deliverable** — recommended (one mode/map at final quality; doubles as Steam trailer/demo + quality bar + home for the juice pass). No reaction yet.
- **Leaderboard group scoring** — per-team recommended; per-player the alternative. Confirm. (Also: board-id schema unspecified.)

## Direction set — system still undesigned
- **Anti-cheat** — tiered: PVE trusts client; ranked uses authoritative deterministic re-sim (server re-derives true kills from seed+build inputs). Real work, on critical path. Design in its own session. See `notes/server_decision.md`.
- **Cosmetic DLC packs** — fork presented (one-time, upfront, no gacha) as the recurring-revenue lever to fund perpetual seasons. Undecided. Values boundary: paid items never overlap earnable/prestige rewards.
- **Campaign-as-paid-DLC** — demand-driven posture set (ship the 10, build a paid chapter only if players ask; campaign may be a product pillar, not just tutorial). Not built.

## Untouched — never actually discussed
- **Game's actual NAME** — RULES.md says TBD; memory says "Maze Battle TD." Placeholder or locked? **Blocks the Steam page.** Highest-leverage tiny decision.
- **PVP LP curve** — exact points per placement.
- **Soft caps** — damage / range / attack-speed upgrade ceilings.
- **PVE/PVP player-facing naming** — Co-op / Versus? (Standing STATE open question.)
- **Group PVE lobby mechanics** — team/individual scoring vote, ready-up flow.
- **PVP season specifics** — rank decay, LP→reward mapping, how the permanent Masters-number works in practice.
- **Accessibility / colorblind** — zone types need shape/icon, not color alone. Cheap now, expensive to retrofit.
- **Onboarding for non-SC2 players** — does a newcomer grok mazing without the (now-optional) campaign?
- **Community hub** — Discord/subreddit; feedback loop + where wishlisters/friend-testers gather. See `notes/gtm.md`.
- **IP/legal** — Random TD "spiritual successor" (Blizzard). Confirm clearance/safe framing; may be handled earlier — don't assume.
- **Localization** — never raised; fine to defer (English-first niche revival).

## Blocked on playtest data
- **Bronze/Silver/Gold threshold calibration.**
- **PVP seed-convergence** — shared-seed ranked could converge to identical optimal mazes; eyeball in playtest. Not a design change.

## Own session (large)
- **Juice / game-feel pass** — reference here (Persona/Atlus organic UI overlap), then CC (tweens, particles, hit-pause, screen shake, road shader). Light taste mockup exists.
- **Full GTM / marketing plan** — Steam page, capsule/tags/trailer spec, Next Fest/demo, where the SC2 crowd gathers, streamer outreach. See `notes/gtm.md`.
