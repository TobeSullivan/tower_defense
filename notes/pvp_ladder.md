# PVP ladder (Ranked) — LP, MMR, tiers, season

Locked 2026-06-05 (design session 2). Supersedes the "Exact LP curve TBD" line in
`DESIGN_MODES.md`. The tier list (Stone → Bronze → Silver → Gold → Masters),
placement = elimination order (last standing = 1st), promote-at-threshold /
demote-at-zero, and "season reset drops one tier" are already locked in
`DESIGN_MODES.md`; this note fills in the numbers underneath them.

**Model chosen: MMR-anchored net-positive** (the TFT model), over pure zero-sum.
Net-positive *feel* low on the ladder (retention for a small pool), honest /
zero-sum *behavior* at the top (Masters integrity). Grounded in the two genre
reference systems: TFT (visible LP + hidden MMR) and Hearthstone Battlegrounds
(pure rating, asymmetric at the top). Everything here except the structural shape
is a playtest dial.

---

## Base LP table

Displayed LP when your hidden MMR ≈ the lobby average. Symmetric, sums to ~0 at
equilibrium (this is what keeps the top of the ladder from inflating forever).

| Place | LP  |
|-------|-----|
| 1st   | +45 |
| 2nd   | +30 |
| 3rd   | +18 |
| 4th   | +8  |
| 5th   | −8  |
| 6th   | −18 |
| 7th   | −30 |
| 8th   | −45 |

Shape: 1st pays ~5–6× what 4th does; the curve steepens at the extremes; 4th/5th
are the small "barely climbed / barely sank" hinge.

## The MMR engine (where net-positive comes from)

Each player carries a hidden MMR, updated every match Elo-style by placement.
Displayed LP = base-table value × an MMR factor (~0.5–1.5 range):

- **Below your true skill** → gains amplified, losses dampened. A truly-Gold player
  stuck in Bronze blitzes upward (≈ +40s, near-zero losses). This is the climb feel.
- **At your true skill** → factor ≈ 1.0, you hover. The ladder stops inflating exactly
  where it should.
- **Above your true skill** → gains dampened, losses amplified (the Battlegrounds
  "+70 for 1st, −130 for 8th" effect). This is the integrity layer.

The MMR engine also self-paces the climb: a player blitzes the tiers below their true
skill and crawls as they approach it, so each tier feels earned without hand-widening it.

### Stickiness rules (below Masters)

Lifted from current TFT, this is the net-positive polish:
- **Top 4 never nets an LP loss.**
- **Bottom 4 never nets an LP gain.**

So the bar only moves up when you place well. **These floors are OFF in Masters** — see
below — which is how you get net-positive-low, honest-high.

## Tier thresholds

Flat 100 LP per tier, **no sub-divisions** (fits the minimalism ethos; the MMR engine
handles pacing).

| Tier    | Band     | On reaching 100 |
|---------|----------|-----------------|
| Stone   | 0–99     | → Bronze        |
| Bronze  | 0–99     | → Silver        |
| Silver  | 0–99     | → Gold          |
| Gold    | 0–99     | → **Masters**   |
| Masters | uncapped | leaderboard-ranked |

- Promotion at 100 LP.
- **Demotion at 0 LP drops you to 75 LP of the lower tier** (buffer so you don't
  ping-pong on the boundary).
- Stone floors at 0 — you can't fall out of the game.

Shape this produces: a strong player rockets to their skill tier in ~15–20 games (fast,
good for a small pool), bounces off the tier above, then the *real* grind is inside
Masters — uncapped and leaderboard-ranked. **Fast to your floor, infinite at the ceiling.**

## Masters specifics

- Masters LP is **uncapped**; total LP ranks you on the season leaderboard (the number
  that becomes the permanent "162nd Masters Season 1" record).
- The top-4-no-loss / bottom-4-no-gain floors are **off** in Masters — fully honest /
  asymmetric. This is the zero-sum top end.
- **No demotion out of Masters mid-season** — once in, you're Masters for the season;
  only your rank *number* fluctuates. Protects the prestige.

## Season reset

Locked as "drop one tier." Land at **25 LP of the dropped tier** (Masters → Gold 25,
etc.) so there's immediate headroom. Stone stays Stone. History preserved (Nakama
tournaments / season boards viewable indefinitely).

---

## Playtest dials (NOT structural — tune later)

- Exact base-table numbers (the *shape* matters more than ±5).
- MMR factor range (the 0.5–1.5).
- The 100-LP tier width (could go 100/100/100/150 if Gold feels too easy on real data).

## Structural — locked now

- Curve shape (cheap-ish placement spread, steeper extremes).
- MMR-anchoring (hidden MMR + visible LP — the "two numbers" cost was accepted as
  worth it for getting the spine right; leans on Nakama's leaderboard/MMR handling).
- Two-phase climb/compete split (net-positive Stone→Gold, honest/uncapped Masters).
- The stickiness floors below Masters; off in Masters.

## Still open (small)

- **Inactivity decay** — TFT decays above Master after N days idle. Not specified here;
  defer (optional, add only if top-of-ladder squatting becomes a problem).
