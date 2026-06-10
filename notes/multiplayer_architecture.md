**STATUS (2026-06-10):** This is the 2026-06-02 topology analysis. The staged Steam-relay-beta
rollout described in §1 (verdict column) and §5 (steps 3→4) was superseded by the
no-disposable-intermediates decision: **dedicated-authoritative + Nakama deployed directly for
the beta** (Hetzner CPX31, Hillsboro, live). The analysis and rejected-alternative trail are
preserved; the sequencing is historical record, not current plan. Current ops state in `STATE.md`.

---

# Multiplayer architecture, cost & sales projections

Captured 2026-06-02 (Claude Code research session). This is the reference for the
multiplayer rollout — transport, backend, costs, and the locked direction.

**STATUS (2026-06-05): the §5 rollout steps 1–2 are BUILT (host-authoritative ENet,
trust-client) + the Android client APK.** Implemented in `src/net/` (MatchTransport
seam + Local/Enet transports + NetMatch driver), the lobby (`scenes/lobby.tscn`),
seed-synced maps, build-input relay + lockstep clock, barrier lives resolution, and
disconnect forfeit — all headless-verified, not yet live-tested. Steps 3–4 (Steam relay,
dedicated server + Nakama) and the determinism hardening (fixed timestep) are still
ahead. See STATE.md session log for the per-phase detail.

Related: `DESIGN_MODES.md` (mode *rules* — 8-player PVP, pairwise lives transfers,
LP/seasons), `notes/leaderboards.md` (older backend sketch — superseded by this).

---

## 0. The one insight that shapes everything

The match is **round-barrier synchronized, not real-time.** Within a round, every
player's board is a fully independent sim. The *only* data that crosses players is
each player's kill count at the round boundary, which feeds the zero-sum pairwise
lives-transfer math. The mob-HP curve is deterministic from `round_number` + a
shared map seed.

Consequences:
1. **In-match netcode is trivial and latency-forgiving.** No rollback, no frame
   lockstep, no prediction. A match exchanges *kilobytes per round*, not MB/s.
2. **Compute scaling is a non-issue** even at 10,000+ players — one modest box
   coordinates hundreds of concurrent light matches.
3. **The hard/expensive parts are NOT networking** — they're cross-platform
   identity, matchmaking quality, anti-cheat, and ops. Backend, not transport.

The existing `MatchCoordinator` (owns the clock + transfer math, drives N boards in
lockstep) is already the authoritative object. "Runs on the host" vs "runs on a
dedicated server" is the *same code* with a different `MultiplayerPeer` underneath.

---

## 1. Two layers, decided independently

### Layer 1 — In-match transport & authority

| Topology | What it is | Pros | Cons | Verdict |
|---|---|---|---|---|
| P2P host-authoritative | One client runs the coordinator; others thin. Steam-overlay invites (no room codes). | No servers, ~free, fastest to a friends test | Host = the match (leaves → dies); host can cheat; **consoles forbid raw P2P** | Analyzed, not taken |
| Relay-assisted host-auth | Same, packets via a relay that hides IPs + punches NAT (e.g. Steam relay) | NAT "just works", no exposed IPs | Relay is usually platform-specific (Steam = PC/Mac only) | Analyzed; skipped (no disposable intermediates) |
| Dedicated authoritative | Headless Godot (`--headless`) runs the coordinator; clients thin | No host-migration, cheat-resistant, console-legal, crossplay-ready | You run/monitor servers (cheap here) | ✅ Deployed (beta + launch) |

### Layer 2 — Meta backend (accounts, matchmaking, leaderboards, LP, seasons)

| Option | Covers | Ops | Portability | Lock-in |
|---|---|---|---|---|
| None / join-codes | Nothing persistent | Zero | — | None (beta only) |
| Steam-only (Steamworks) | Leaderboards/lobbies on Steam | Zero | ❌ PC/Mac-Steam only | High (throwaway) |
| **Nakama** (open source) | Matchmaking, leaderboards, storage, auth (device/Steam/Apple/Google/custom), realtime, *can host the coordinator* | Medium (Docker + Postgres) | ✅ Full, console-friendly | Low (it's yours) |
| PlayFab (managed, MS) | Matchmaking, leaderboards, economy, live-ops | Low (managed) | ✅ | Medium (vendor) |
| Roll-your-own (Supabase/Postgres + svc) | Whatever you build | High | ✅ | None |

**Leading pick: self-hosted Nakama** — its auth solves the cross-platform identity
problem (the genuinely hard part of consoles + crossplay), its matchmaker expresses
"widen rank bands under load" natively, and its server-side match handler can *be*
the authoritative coordinator later. Decide for real when we commit to mobile/scale.

---

## 2. The platform pivot trap (the "don't tie ourselves down" rule)

- **Steam networking/relay is PC-Mac-via-Steam only.** Mobile + console players are
  not on Steam. Building *on* Steamworks networking = a rewrite for mobile/console.
- **Consoles legally forbid raw P2P** and require their own online services
  (PSN/Xbox Live/Nintendo) + cert + a backend to bridge crossplay identity.

**Pivot insurance (Godot gives it nearly free):** everything goes through Godot's
`MultiplayerPeer` interface — ENet (UDP), WebSocket, WebRTC, and Steam-relay all
implement the *same* interface. Wrap that + a thin `MetaBackend` interface (login /
queue / submit-score / leaderboard) and "Steam beta now, dedicated + Nakama later"
is **swapping an adapter, not rebuilding.** Steam is a beta convenience, never the
foundation.

---

## 3. Scaling: 10 vs 100 vs 10,000

| Players | What works | What actually gets hard |
|---|---|---|
| ~10 (beta) | Dedicated authoritative (deployed) + Steam-overlay invites. Nakama meta. | Nothing. |
| ~100 | + accounts + persistent leaderboards/LP + a queue (small Nakama, one box). | **Thin queues** — finding 8 similar-rank players online at once. Small pop is the *harder* matchmaking case. |
| 1,000–10,000 | Dedicated authoritative coordinators + managed/clustered backend. | Anti-cheat, crossplay identity, ops/monitoring. **Not compute** — matches stay cheap. |

**Spectating can be near-free.** An opponent's maze is frozen during the run and
mobs follow deterministic paths, so a spectator client can *re-simulate* their board
locally from (tower layout sent once + spawn seed), needing only a trickle of "mob X
died at T" events to stay in sync. No video/position streaming.

---

## 4. Matchmaking — LOCKED DECISION: no bots in ranked, ever

Bot-fill in ranked poisons the ladder (climbing vs bots is illegitimate and players
rightly resent it). Thin queues are solved instead by:

- **Shrink the lobby (8 → 6 → 4).** The coordinator already runs variable board
  counts (`pending_board_count`), so a 6- or 4-player match is the same code with a
  smaller number. Essentially free.
- **Widen rank bands under load (stone vs gold).** A matchmaking *rule*: after N
  seconds queued, expand the acceptable LP range. Nakama's matchmaker does this
  natively. Also free.

This is both more legitimate *and* less code than a bot-injection path. Bots survive
only in unranked/practice, which never touches a leaderboard.

---

## 5. Recommended staged rollout (each step reuses the last)

1. **Define the interfaces** — `MatchTransport` (over Godot `MultiplayerPeer`) +
   `MetaBackend`. The insurance policy; a day of design, not a framework.
2. **Loopback → LAN** — host-authoritative coordinator, trust-client. Same code,
   different peer. Proves the protocol cheaply.
3. **Steam beta** — add a Steam-relay peer adapter + join-code/invite flow. The
   "few friends on Steam" test. Additive because of step 1.
4. **Mobile/scale** — move the coordinator to dedicated headless Godot servers +
   stand up the real backend (Nakama) for cross-platform auth, matchmaking,
   leaderboards, LP, seasons. Add authoritative validation here, before ranked.

> **Pre-empted by user decision (2026-06-02):** do a **mobile-ready foundation pass
> BEFORE multiplayer** (touch input + orientation/aspect + finger-sized tap targets
> + an Android test export) so we never do "PC-first then refactor for mobile."
> See STATE.md. The renderer (`gl_compatibility`, incl. `.mobile`) and stretch mode
> (`canvas_items`) are already mobile-appropriate — the real work is a touch-input
> layer, not a rewrite.

**Trust model for the beta: trust-client** (clients report their own kills; authority
just tallies). Far less work, nobody cheats a friends test. Authoritative validation
is added at step 4, before any ranked launch.

---

## 6. Costs

### Store & developer-program fees (to publish)

| Platform | Fee | Type | Notes |
|---|---|---|---|
| Steam | **$100 / title** | One-time, *recoupable* | Credited back after $1,000 revenue. Beta lives here. |
| Apple (iOS / Mac App Store) | **$99 / year** | Recurring | Needed for iOS + Mac App Store (plain Mac builds outside store don't need it). |
| Google Play | **$25** | One-time | Pay once ever. |
| Xbox (ID@Xbox) | **$19** indiv / $99 corp | One-time | Program itself free to approved devs. |
| PlayStation | Free to register | — | Real cost = devkits + NDA approval. |
| Nintendo | Free to register | — | Pay for test hardware only. |

Console devkits (only after approval, later): ~$450–500 Switch, ~$2,000–2,500
PS/Xbox, + per-title cert *effort* (engineering time, not a sticker fee).

**Near-term: the Steam friends beta costs $100, recoupable. That's the whole bill.**

### Hosting (scales with *concurrent*, not lifetime sales)

Self-hosted Nakama on Hetzner CCX (dedicated vCPU):

| Population | Box | ~Cost/mo |
|---|---|---|
| Beta → hundreds | CCX13 (2 vCPU/8GB) | ~$16 |
| ~1,000s | CCX23 (4 vCPU/16GB) | ~$32 |
| ~10,000+ | CCX33–43 (8–16 vCPU) | ~$65–130 |

Managed Nakama (Heroic Cloud): usage-based, cheap dev tier, production in the
low-hundreds/mo — ~3–5× self-host to skip ops. PlayFab: generous free tier, MP
servers per core-hour. **Hosting is <0.5% of revenue at every tier — negligible.**

### The big invisible fee: the platform cut

Default **30%** everywhere (Steam, Apple, Google, all consoles). Reductions:
- Steam → 25% past $10M, 20% past $50M lifetime.
- Apple & Google → **15%** under ~$1M/yr (small-business programs) — applies to us
  for a long time.

End-customer **sales tax / VAT is handled by the store** (merchant of record) — not
our line item. Model income as 70% (Steam) / 85% (mobile) of list price.

---

## 7. Sales projections (illustrative)

**Tax answer:** you're paid the **net** (70% Steam / 85% mobile) — the platform cut
never reaches you, so it's never taxed as your income. You're then taxed on **net
revenue minus business expenses** (= profit), not on the full list price.

### Scenario A — Steam, $5, 30% cut (net $3.50/unit)

| Units (lifetime) | List | Cut | Net | Hosting/yr | Pre-tax | Income tax* | Take-home |
|---|---|---|---|---|---|---|---|
| 1,000 | $5,000 | $1,500 | $3,500 | ~$200 | $3,300 | ~15% | ~$2,800 |
| 10,000 | $50,000 | $15,000 | $35,000 | ~$400 | $34,600 | ~30% | ~$24,200 |
| 50,000 | $250,000 | $75,000 | $175,000 | ~$1,000 | $174,000 | ~30% | ~$122,000 |
| 100,000 | $500,000 | $150,000 | $350,000 | ~$1,500 | $348,500 | ~32% | ~$237,000 |

### Scenario B — Mobile premium, $8, 15% cut (net $6.80/unit)

| Units (lifetime) | List | Cut | Net | Hosting/yr | Pre-tax | Income tax* | Take-home |
|---|---|---|---|---|---|---|---|
| 1,000 | $8,000 | $1,200 | $6,800 | ~$200 | $6,600 | ~20% | ~$5,300 |
| 10,000 | $80,000 | $12,000 | $68,000 | ~$400 | $67,600 | ~30% | ~$47,300 |
| 50,000 | $400,000 | $60,000 | $340,000 | ~$1,000 | $339,000 | ~32% | ~$230,500 |
| 100,000 | $800,000 | $120,000 | $680,000 | ~$1,500 | $678,500 | ~33% | ~$454,500 |

`*` **Income tax is illustrative, NOT advice.** US sole-prop ≈ 15.3% self-employment
+ federal bracket + state → ~25–35% effective on meaningful profit. At low tiers,
deducting dev expenses can wipe taxable profit. Entity choice (sole prop/LLC/S-corp)
changes it a lot. Talk to an accountant. Tables also assume **$0 marketing** (mobile
premium especially may need UA spend) and exclude it.

**Net read:** hosting never threatens these numbers; **list price and platform mix
(mobile 15% vs Steam 30%) are the only levers that matter.**

---

## Sources (fees/pricing, fetched 2026-06-02)

- Apple Developer Program $99/yr; small-business 15% — developer.apple.com, revenuecat.com
- Google Play $25 one-time — iconikai.com
- Steam Direct $100 recoupable — partner.steamgames.com
- Heroic Cloud (usage-based) — heroiclabs.com/pricing
- ID@Xbox $19 / console fees — 1d3.com/blog/platform-fees
- Hetzner Cloud CCX pricing — costgoat.com/pricing/hetzner
