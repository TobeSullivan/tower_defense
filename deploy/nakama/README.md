# Wend meta backend — self-hosted Nakama

Nakama (identity, leaderboards, LP/seasons, matchmaking) + Postgres, in Docker, on the same
Hetzner box as the headless Godot match server (`deploy/README.md`). **Nakama is the meta
layer, not the match authority** — the Godot server runs matches; Nakama matchmakes and hands
clients a `match_id`/address (`notes/remote_beta_plan.md`, `notes/multiplayer_architecture.md`).

Decisions (2026-06-08): self-host on the existing box resized to ~8 GB; device-auth first
(Steam later); first milestone = leaderboards + matchmaking. Heroic Cloud rejected on cost.

---

## 0. One-time: resize the box + install Docker  (USER)

The current CPX11 has **2 GB** — too tight for Nakama + Postgres next to a match sim. Resize up
first.

1. **Resize (Hetzner Console):** Server → `178.156.171.215` → Power off → **Rescale** →
   pick **CPX31** (4 vCPU / 8 GB) or **CCX13** (dedicated 2 vCPU / 8 GB) → keep the disk →
   power on. (Rescaling up is non-destructive; disk can't shrink.)
2. **Install Docker** (Ubuntu):
   ```bash
   ssh root@178.156.171.215
   curl -fsSL https://get.docker.com | sh
   docker compose version   # confirm the compose plugin is present
   ```
3. **Firewall (Hetzner Cloud Firewall):** add inbound TCP **7350** (client API, any IP) and
   TCP **7351** (console — restrict to *your* IP). Leave UDP 8771 (match server) + TCP 22 as-is.
   Do NOT expose 5432 (Postgres stays on the private compose network).

> TLS: for the beta the Godot client talks plaintext to `:7350`. Before a public launch, put
> Caddy/nginx + Let's Encrypt in front (a domain) and switch the client to `wss`/`https`.

## 1. Deploy the stack

```bash
# From the dev machine — upload this folder (excludes .env/pgdata via .gitignore):
rsync -av --exclude pgdata --exclude .env deploy/nakama/ root@178.156.171.215:/opt/wend-nakama/

ssh root@178.156.171.215
cd /opt/wend-nakama
cp .env.example .env && nano .env      # set strong secrets (openssl rand -hex 24)
docker compose up -d
docker compose logs -f nakama          # expect: "Wend runtime loaded: campaign + ranked + 60 Trials tournaments…"
```

## 2. Verify

- **Console:** browse `http://178.156.171.215:7351`, log in with `NAKAMA_CONSOLE_*`.
  - *Leaderboards* tab → `campaign_m01..05`, `ranked_s1`, and `trials_*` (60) all present.
  - *Runtime modules* → `index.js` loaded, RPC `submit_score` registered.
- **Health:** `docker compose exec nakama /nakama/nakama healthcheck` → ok.

## 3. Operating notes

- **Restart / update config:** `docker compose up -d` (re-runs migrate, reloads the module —
  board creates are idempotent). **Upgrade Nakama:** bump the image tag, `docker compose pull`,
  `up -d`.
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
