# Beta design brief — what to resolve before the build push

Captured 2026-06-06. Goal: get a playable desktop beta into two friends' hands
(one Mac, one PC) to validate **multiplayer** and (if pulled forward) **leaderboards**.

Three items are both **undesigned and beta-relevant** — resolving them unblocks the
whole beta build (distribution + leaderboard slice + group/onboarding flow) in one
coordinated push. Everything else in `notes/open_items.md` is either already locked,
not beta-relevant, or blocked on playtest data. Per the design-before-code rule, CC
should not build the UI here without an agreed design.

Context that's already settled (don't re-litigate):
- Platform: PC/Mac-first, mobile dead. Distribution leaning **itch.io draft** (free,
  Win+Mac, itch app auto-updates + strips macOS quarantine). Steam is the eventual
  launch home but **not** for a 2-friend beta (Steamworks $100 + multi-day Valve review).
- Connection plumbing is DONE: clients connect outbound to the live Hetzner match
  server (`5.78.110.182`, UDP 8771) — no port-forwarding, no NAT punching.
- Leaderboard *system/data* design is locked in `notes/leaderboards.md` (Nakama backend;
  board set; metric = total damage; group scoring per-team; window cadence). What's
  missing is the **UI** and the **identity model** below.

---

## 1. Leaderboard UI + player identity

The strategic layer is locked (`notes/leaderboards.md`); the UI and identity layers are not.
Leaderboards = Nakama = M3, so doing this pulls M3 forward ahead of its "toward launch" slot.
Good news: leaderboards are Nakama's easiest feature (define board → write score → read
board); the heavy Nakama parts (matchmaking) stay deferred — the fixed match server already
handles connections.

### Open questions — identity (underpins everything)
- **How does a player get a persistent name?** Today names are local display handles only
  ("You" / opponent handles, `match_coordinator.gd:54`) — no account system exists.
  Options: device-auth + a one-time entered handle (simplest for beta) · email/Google ·
  defer to Steam name at launch. A leaderboard score is meaningless without a stable name
  attached across sessions.
- **Is the beta identity throwaway or forward-compatible?** i.e. do we want these beta
  accounts/handles to survive into the real Nakama identity at launch, or is beta auth
  disposable?
- **One handle, or per-mode?** (Almost certainly one. Confirm.)

### Open questions — UI surfaces (need a design/mockup for each)
- **Post-match placement panel** (the highest-value surface): "You placed #14 this week"
  + the rows around you + "View full board." What does it look like, where does it sit
  relative to the redesigned victory panel? Trials and Ranked variants differ (Ranked = LP
  delta + ladder position; Trials = damage rank).
- **Full board-browse screen:** the tucked-away tertiary destination. Row layout, how you
  switch board (map × window × group-size for Trials; the single ladder for Ranked; the 10
  campaign boards). How deep does browsing go — top N + your neighborhood, or full scroll?
- **Trials-select entry point:** that screen already shows 5 maps + your best score with
  daily/weekly/monthly tabs. How does "your best score" become a tappable board entry?

### Technical (we can derive, but confirm the convention)
- **Board-id schema / Nakama tournament config** — the naming convention for
  `(map, window, group-size)` Trials boards, the 10 campaign boards, the Ranked season
  ladder. Listed "Open" in `notes/leaderboards.md:49`.

---

## 2. Trials group-lobby flow (co-op PVE)

*Untouched* in `open_items.md`. The group *scoring* is locked (per-team, separate boards by
size) but the *lobby flow* is undesigned. Only matters for the beta if you want the friends
to test **co-op Trials**, not just head-to-head Ranked.

### Open questions
- **How do 2–3 friends get into the same Trials match?** Reuse the existing lobby/join-by-
  server flow, or a match/room code? (Server is single-match Option A today — fine for one
  group.)
- **Ready-up flow:** who picks the map/window, how does everyone signal ready, what's the
  countdown/start gate?
- **Shared vs individual within the run:** lives are pooled (locked). Anything else shared —
  vision, build budget? (Likely nothing else; confirm.)
- **Is co-op in beta scope at all,** or is beta head-to-head Ranked only? (Cheapest beta =
  Ranked only; co-op adds the lobby-flow design + build.)

---

## 3. Onboarding for non-SC2 players

*Untouched*. Both friends may not intuitively grok single-tower mazing. With the campaign now
*optional* (not the forced tutorial), a newcomer might bounce. Directly affects whether the
beta is *usable* — a confused tester gives you noise, not signal.

### Open questions
- **Do your two specific friends already know mazing** (SC2 Random TD background)? If yes,
  beta onboarding can be a one-paragraph "how to play" and this de-prioritizes — the real
  onboarding design becomes a launch concern, not a beta blocker.
- **If not:** minimum viable teach for the beta — a first-run tooltip pass? a "play mission 1
  first" nudge? a single explainer card? (Not the full onboarding system — just enough that
  the beta produces clean feedback.)
- **What's the one concept that must land?** Probably: *you build the maze; longer path = more
  time on target.* Everything else is secondary.

---

## After this brief is answered → the build push

Once these are decided, the beta build is roughly:
1. **Win + Mac client export presets** (don't exist yet — only Android-dead + Linux-server).
2. **Real 2-client cross-network match** (never done with full clients — the core MP validation).
3. **itch.io draft** + `butler` push pipeline; secret link to each friend.
4. **(If leaderboards in scope)** thin Nakama slice: deploy Nakama (Docker+Postgres on the
   Hetzner box) → auth/identity → score write on match end → the post-match + browse UI.
5. **(If co-op in scope)** Trials group-lobby flow.
6. **(If needed)** minimal onboarding teach.
