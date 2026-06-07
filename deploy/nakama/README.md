# Wend meta backend — self-hosted Nakama

Nakama (identity, leaderboards, LP/seasons, matchmaking) + Postgres, in Docker, on the same
Hetzner box as the headless Godot match server (`deploy/README.md`). **Nakama is the meta
layer, not the match authority** — the Godot server runs matches; Nakama matchmakes and hands
clients a `match_id`/address (`notes/remote_beta_plan.md`, `notes/multiplayer_architecture.md`).

Decisions (2026-06-08): self-host on a dedicated ~8 GB box; device-auth first (Steam later);
first milestone = leaderboards + matchmaking. Heroic Cloud rejected on cost.

**Box (2026-06-08):** `5.78.110.182` — **CPX31** (4 vCPU AMD / 8 GB / 160 GB), Hetzner
**Hillsboro (us-west, `hil`)**, Ubuntu. This replaced the old CPX11 at `ash`. We did **not**
rescale: CPX11 is a deprecated Gen1 type and `ash` had no CPX31 capacity to rescale into, and
since nothing was wired to the box yet, a fresh create at `hil` was cleaner than a snapshot
restore. Old box deleted (billing stopped). Latency: ~30–45 ms higher for US-East testers than
`ash` — irrelevant for tower placement during build phases.

---

## STATUS — DEPLOYED & LIVE 2026-06-07 (CC, over SSH)

Stack is up on `5.78.110.182` and verified: Nakama healthy, external `:7350` → HTTP 200,
66 boards present (5 campaign + `ranked_s1` + 60 Trials), `submit_score` RPC registered,
console/gRPC loopback-bound. Box is **Ubuntu 26.04 LTS**. Console login → `console_login.local.txt`
(gitignored). Two fixes were needed during deploy:
- **Docker wasn't actually installed** (this README's §0 was marked done prematurely) — CC ran
  `get.docker.com` → Docker 29.5.3 + Compose v5.1.4.
- **compose entrypoint bug** — the DB address was passed via a YAML *folded scalar* (`>`) with
  more-indented continuation lines, so `migrate up` ran with no `--database.address` and Nakama
  crash-looped against its CockroachDB default (`127.0.0.1:26257`). Fixed to a literal block (`|`)
  with backslash-continuations; see the comment in `docker-compose.yml`. Drop-in lesson: never
  put Nakama flags on more-indented `>` lines.

## 0. One-time: provision the box + install Docker  (USER + CC)

The box is created and firewalled (USER). Docker was installed by CC during the deploy above.
Recorded here for reproducibility / future moves.

1. **Create the server (Hetzner Console):** New server → location **Hillsboro (`hil`)** →
   image **Ubuntu** → type **CPX31** (4 vCPU / 8 GB) → your SSH key → create. (Note: the old
   Gen1 CPX line is deprecated for *new rescale targets* in some DCs; creating fresh sidesteps
   the rescale-capacity problem entirely and lets you pick the exact size up front. If you ever
   move again, create fresh + redeploy rather than rescale.)
2. **Install Docker** (Ubuntu):
   ```bash
   ssh root@5.78.110.182
   curl -fsSL https://get.docker.com | sh
   docker compose version   # confirm the compose plugin is present
   ```
3. **Firewall (Hetzner Cloud Firewall — `firewall-1`, 3 inbound rules):**
   - TCP **22** (SSH) — any IP
   - TCP **7350** (client API) — any IP (players need it)
   - UDP **8771** (Godot match server) — any IP
   - Do **NOT** add a public rule for 7351 (console) or 5432 (Postgres). The console is reached
     via SSH tunnel (below); Postgres stays on the private compose network.

   **Console access = SSH tunnel** (chosen over an allow-my-IP rule because the residential IP
   is dynamic — no per-rotation maintenance, and the admin panel is never publicly exposed):
   ```bash
   ssh -L 7351:localhost:7351 root@5.78.110.182   # leave open
   # then browse http://localhost:7351
   ```
   Same pattern for Postgres if ever needed: `-L 5432:localhost:5432`.

> **DONE (CC, 2026-06-08):** `docker-compose.yml` binds the console **and** the gRPC API to
> loopback — `127.0.0.1:7351:7351` and `127.0.0.1:7349:7349` — so both are tunnel-only even if
> the cloud firewall is ever misconfigured. The SSH tunnel still works (it targets the server's
> 127.0.0.1). Only **7350** stays on `0.0.0.0` (players need the client API public).

> TLS: for the beta the Godot client talks plaintext to `:7350`. Before a public launch, put
> Caddy/nginx + Let's Encrypt in front (a domain) and switch the client to `wss`/`https`.

## 1. Deploy the stack — DONE 2026-06-07 (re-run any time; idempotent)

```bash
# From the dev machine — upload this folder (excludes .env/pgdata via .gitignore):
rsync -av --exclude pgdata --exclude .env deploy/nakama/ root@5.78.110.182:/opt/wend-nakama/

ssh root@5.78.110.182
cd /opt/wend-nakama
cp .env.example .env && nano .env      # set strong secrets (openssl rand -hex 24)
docker compose up -d
docker compose logs -f nakama          # expect: "Wend runtime loaded: campaign + ranked + 60 Trials tournaments…"
```

## 2. Verify

- **Console (via tunnel):** open the SSH tunnel (§0.3), then browse `http://localhost:7351`,
  log in with `NAKAMA_CONSOLE_*`.
  - *Leaderboards* tab → `campaign_m01..05`, `ranked_s1`, and `trials_*` (60) all present.
  - *Runtime modules* → `index.js` loaded, RPC `submit_score` registered.
- **Health:** `docker compose exec nakama /nakama/nakama healthcheck` → ok.

## 3. Operating notes

- **Change the runtime module** (`data/modules/index.js`): `data/` is a volume mount loaded at
  startup, so editing it is NOT picked up by `docker compose up -d` (no compose change → no
  recreate). After `scp`-ing the new `index.js`, run **`docker compose restart nakama`** to reload
  it; confirm via `docker compose logs nakama | grep "runtime loaded"`. Board creates are idempotent.
- **Restart / change compose or .env:** `docker compose up -d` (recreates, re-runs migrate).
  **Upgrade Nakama:** bump the image tag, `docker compose pull`, `up -d`.
- **Backups:** `docker compose exec postgres pg_dump -U postgres nakama > backup.sql`.
- **Season roll:** bump `CURRENT_SEASON` in `data/modules/index.js`, redeploy → a new
  `ranked_s<N>` board is created; the old one stays as the frozen past season.
- **Logs:** `docker compose logs -f nakama` / `… postgres`.

## What the runtime module owns (`data/modules/index.js`)

- Creates the board topology on startup (idempotent): 5 campaign leaderboards (all-time),
  `ranked_s1` (sort key = tier_base+LP, op `set`), 60 Trials tournaments (window×scale×group,
  UTC reset crons, op `best`).
- `submit_score` RPC — authoritative write (boards reject direct client writes) + stores the
  match record blob in the `match_records` storage collection for the later re-sim worker.
