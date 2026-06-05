# Server / hosting — decision note

Captured 2026-06-05 (current pricing; verify before committing real spend).

## Decision
**Hetzner Cloud CPX11, Ashburn US-East, for the beta.** Don't shop further for now.

- **What Hetzner is:** German cloud provider, best-in-class price-to-performance, AMD EPYC,
  all-inclusive pricing (traffic, IPv4/6, DDoS, firewall). DCs in Germany, Finland, US
  (Ashburn VA, Hillsboro OR), Singapore. No free tier.
- **CPX11** (2 vCPU / 2GB / 40GB) ≈ **$5–7/mo** capped. Hetzner raised prices ~30–37% in
  April 2026 (DRAM costs) — still the cheapest serious option. CPX22 (2 vCPU/4GB) ≈ $9.50/mo.
- **Ashburn is correct even now that we're PC-first** — testers are US (user in Michigan);
  EU boxes would add latency.

## Is the old "$5–10/mo, it's light" estimate still true?
**For the beta, yes.** For scale, it depends entirely on architecture, not the host.

- The cheap estimate assumed the **round-barrier model** (server relays kill counts, doesn't
  simulate). The current **Option A** does the opposite — the server **simulates the whole
  match** → CPU-heavy, **one match per box**. Under Option A, cost scales linearly with
  concurrent matches.
- **Option B** (lightweight relay; clients report kills; many matches per box) restores the
  cheap-scaling story. With Option B + Nakama on one Hetzner box, hosting stays well under
  1% of revenue into the thousands of concurrent users.
- **Provider choice is a rounding error. The scaling lever is Option A → B**, already on the
  roadmap. "We have a dedicated server" ≠ "we can scale" — different claims.

## Alternatives (for the record)
- **Vultr** — 32 DCs, best global reach if latency to far regions ever matters.
- **Oracle Cloud Always Free** — 4 ARM cores / 24GB free forever, but ARM-compat + idle-
  reclaim + account-recovery risk; fine for labs, not guaranteed production. ~$6/mo Hetzner
  beats fighting Oracle's setup for a beta.
- DigitalOcean/Linode — pricier per spec; better managed-services ecosystem we don't need.

## Anti-cheat coupling (important)
The deterministic round-barrier design means the server can **re-simulate any round from
(seed + each player's build inputs + round#) and compute the true kill count** — it never
has to trust the client. But re-sim = CPU = basically Option A's cost. Resolution: **tier
it** — PVE/casual trust the client (low stakes; spot-check anomalies); **ranked uses
authoritative re-sim** (smaller population; prestige cosmetics are the cheat incentive), or
re-sim only leaderboard-top/flagged submissions. So "no cheaters in ranked" is achievable
without trusting clients — but it's real work, on the launch critical path since ranked
ships. Design it in its own session.
