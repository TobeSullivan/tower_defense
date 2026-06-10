# Design — Modes, Maps, Progression, Seasons, UI

Locked design decisions for everything outside the core gameplay loop. Core gameplay (towers, mobs, economy, pathing, wave structure) lives in `DESIGN.md`.

---

## Game modes overview

There are three modes. They share the same core gameplay loop and the same map resource format. What differs is how the map is generated, how scoring works, and what the social context is.

**Player-facing names (locked 2026-06-05):** PVE is shown to players as **"Trials"**, PVP as **"Ranked"**. "PVE"/"PVP" stay as the internal/technical mode identifiers in this doc and in code (enums, file names, mode flags); only the displayed strings use Trials/Ranked.

| | Campaign | PVE | PVP |
|---|---|---|---|
| Map source | Hand-authored | Seeded, curated | Seeded, generated |
| Players | 1 | 1–4 | 8 |
| Lives system | No | No | Yes |
| Win condition | Damage thresholds | High score | Last standing |
| Matchmaking | None | Invite only | Solo queue |
| Leaderboard | Per mission | Per map × group size × window | Season rank |

---

## Campaign

Five missions. Static hand-authored maps. No randomization.

**Purpose is tutorial only.** The campaign teaches the game through a difficulty curve — each mission is designed to surface a specific mechanic or decision. This is not the product's selling point. Players should be through campaign in 1–2 hours and into PVE/PVP.

No expansion unless players demand it after launch. Do not get lost building campaign content.

Each mission has a per-mission leaderboard (total damage dealt). 1/2/3-star thresholds exist to give players a concrete target and feed season pass milestones. The 3-star tier should be achievable by a reasonably engaged player — the leaderboard is where real competition lives, not the threshold.

### Mission curriculum

**Full curriculum, tutorial-beat scripts, and the ghost-outline build-guidance spec live in `design/CAMPAIGN.md`.**

Philosophy (reworked 2026-06-06, replacing the 2026-05-31 lock): complexity **ramps from zero**, one concept per mission. The old curriculum was inverted — mission 1 exposed everything at once (3 CP, 4 zones, 100 supply) and mission 2 *stripped back* to basics, so a first-timer's literal first match was the most complex one in the early game. The five-mission arc fixes that: M1 dead-simple (the core twist + place a tower + a basic guided maze), M2 introduces checkpoints (2), M3 extends them (3), M4 isolates bonus zones (back to 1 CP so zones are the only new thing), M5 integrates everything in a contained, non-random "almost a real match." Crit and multishot are taught through the upgrade stats and the M5 integration map, not dedicated missions (there are no crit/multishot bonus zones — only DAMAGE/ATTACK_SPEED/RANGE/SLOW exist).

> **Board size:** the board is locked at **25×16** (universal; derived once at the 1080p reference with a 280px right rail, scale-and-center elsewhere). The curriculum's tuning integers (supply/rounds/mobs) are uncalibrated regardless and wait on playtest data + the 25×16 retune; only the *shape* of the ramp is locked. `CAMPAIGN.md` is authored against 25×16. (Historical: earlier text cited 40×22, then 25×14 — both dead.)

> **Old mission files deprecated:** the previous ten `.tres` files in `levels/campaign/` (`First Contact` through `The Gauntlet`) are superseded by the five-mission arc. CC decides what to cut or repurpose against the repo; the design now describes five.

---

## PVE — "Trials" (Leaderboard mode)

### Structure

1–4 players, invite-only lobby. No random matchmaking. Players bring friends or play solo.

Five curated seeded maps are available per time window. Time windows: daily, weekly, monthly. Maps are distinct per window — today's daily maps are different from yesterday's.

Players can run any of the five maps as many times as they want within the window. Only completed runs post a score (all rounds played). Best score per player per map is what counts.

### The five maps scale in difficulty (1–5)

Maps are generated at the start of each window and held fixed for its duration. Scale parameters:

| Scale | Supply cap | Checkpoints | Zones | Mob count | Round range |
|-------|-----------|-------------|-------|-----------|-------------|
| 1 | 10 | 1 | 1–2 | ~8 | 10–13 |
| 2 | 20 | 1–2 | 2–3 | ~12 | 13–17 |
| 3 | 30 | 2 | 3–4 | ~16 | 17–21 |
| 4 | 40 | 2–3 | 4–5 | ~20 | 21–26 |
| 5 | 50 | 3 | 5–6 | ~24 | 26–30 |

Round count is seeded-random within the range for that scale tier. Everyone playing a given daily map plays the same round count — it's baked into the seed.

Scale 5 with 3 checkpoints, 50 supply, and overlapping zones cannot produce comparable scores to Scale 1. Leaderboards are per-map, never cross-map.

### Leaderboards

Boards are organized as: **Daily / Weekly / Monthly** × **Solo / Duo / Trio / Quad**.

Group size determines the board, with no vote: a solo player posts to the Solo board, a duo to the Duo board, a trio to Trio, a quad to Quad. The only way to a Solo score is to play solo. The seed is the seed regardless of how many friends you bring.

### Scoring

A group always posts **team score** (sum of all players' damage) to its group-size board. There is no individual-while-grouped option — group size *is* the board, settled at lobby composition, nothing to vote on.

> **Deferred:** a future "vote for individual scoring while grouped" (each player posts to Solo despite being in a group) is parked, not in the near-term design. See `notes/open_items.md`.

### Arena

All players play simultaneously on their own maze. The arena is a 2-column grid of boards, up to 8 slots. Only filled slots are shown — no empty gray placeholders.

Boards are **hidden during build phase**. Boards are **visible during run phase**. This is the same layout used in PVP.

---

## PVP — "Ranked"

### Structure

8 players, solo queue only. No group queue, no invites. Every person for themselves.

Maps are seeded and fully randomized — supply, mob count, checkpoints, zones, obstacles, all of it. No two ranked matches are on the same map.

### Lives system

Each player starts with 100 lives. Total pool = 800. Lives are zero-sum throughout the match.

After each run phase, lives transfer using **Model B pairwise transfers**: for each opponent, the kill difference that round transfers as lives. A player who out-killed every opponent by 5 gains 35 lives (5 × 7 opponents); each opponent loses 5.

Transfers start at full strength from round 1. No dampening. A player who fails to build round 1 loses lives immediately — this prevents a no-build savings meta.

### Elimination

A player at 0 lives is eliminated. They can leave immediately with no penalty and requeue, or stay and spectate. The match continues until one player remains.

Eliminated player's remaining lives simply leave the pool — they are not redistributed. The remaining players continue zero-sum pairwise transfers among themselves.

### Ranking system

Placement = elimination order. Last standing = 1st.

LP (league points) awarded per placement. Top placements gain LP, bottom placements lose LP, with the amount scaling by exact finish position. 1st gains the most; 8th loses the most. **Full LP/MMR/tier/season spec: `notes/pvp_ladder.md`** (MMR-anchored net-positive ladder, base LP table, demotion buffer, season reset). Numbers there are playtest dials; the shape is locked.

**Rank tiers:** Stone → Bronze → Silver → Gold → Masters.

LP accumulates within a tier. Reaching the threshold promotes to the next tier. Falling to zero in a tier demotes.

### Season resets

At the end of each season, every player's rank drops one tier. Masters → Gold, Gold → Silver, etc. Stone stays Stone.

History is preserved. Season leaderboards are viewable indefinitely after the season ends.

---

## Seasons

Seasons apply to both PVE and PVP. They reset on the same cadence.

### PVP season

Rank tier at season end determines the season reward. Masters reward includes the player's final numeric rank (e.g. "162nd Masters Season 1") permanently on the cosmetic. This number never changes — it's a historical record.

### PVE season pass

Progress via milestone chain. Actions that generate season pass points:

- Playing matches ("play 2 matches today")
- Hitting in-game milestones ("get 100 kills")
- Posting to any leaderboard for any of the 5 qualifying maps
- Placing in specific leaderboard positions

Points accumulate and unlock rewards at milestones — identical structure to a battle pass. No premium tier. All rewards are free.

### Rewards (both modes)

Cosmetic only. No power differential. Examples:

- Tower skins
- Projectile skins
- Profile cosmetic / flair
- Season board (displayed in lobbies — shows your tier and season number)

Masters-tier players display their final rank number on their season board. "162nd Masters Season 1" displayed in a lobby signals prestige without explanation.

Rewards are designed to be visible to other players in lobbies and during spectate. Prestige should be legible at a glance.

---

## Map resource architecture

All three modes use the same `MapResource` format. The generator produces `MapResource` objects for PVE and PVP. Campaign missions are hand-authored `MapResource` files (`.tres`) committed to the repo.

`main.gd` does not own map configuration. It calls `map_loader.load(resource)` and the loader configures everything from the resource. Campaign passes a `.tres` file. PVE/PVP passes a generated `MapResource` object in memory. The loader does not know or care which.

### MapResource schema

```
MapResource (extends Resource)
  seed: int
  mode: int  # enum: CAMPAIGN, PVE, PVP

  # Layout
  grid_size: Vector2i
  entry_cell: Vector2i
  exit_cell: Vector2i
  checkpoint_cells: Array[Vector2i]   # 1–3 entries
  obstacle_cells: Array[Vector2i]
  bonus_zones: Array[ZoneDefinition]  # sub-resource

  # Match parameters
  supply_cap: int
  round_count: int
  mob_count: int                      # enemy supply, constant per match

  # Scoring — Campaign and PVE only; omitted for PVP
  bronze_threshold: int
  silver_threshold: int
  gold_threshold: int

  # Campaign-only fields (null/empty for generated maps)
  mission_index: int
  mission_name: String
  mission_description: String

  # PVE-only fields (null/empty for campaign and PVP)
  scale_tier: int                     # 1–5
  window_type: int                    # enum: DAILY, WEEKLY, MONTHLY
  window_date: String                 # ISO date, e.g. "2026-05-30"
```

### ZoneDefinition schema

```
ZoneDefinition (extends Resource)
  type: int        # enum: DAMAGE, ATTACK_SPEED, RANGE, SLOW, ...
  cell: Vector2i   # center cell on the grid
  magnitude: int   # 10–100, stepped in 10s
```

### Threshold derivation

Thresholds for PVE and Campaign maps are derived algorithmically, not authored by hand. Formula basis:

```
base_dps_estimate = average tower damage per second at mid-upgrade
base_damage_per_round = base_dps_estimate × average run phase duration
total_base = base_damage_per_round × supply_cap × round_count

silver_threshold = total_base × 1.0   # place all towers, no upgrades
gold_threshold   = total_base × 1.5   # reasonable upgrade investment
bronze_threshold = total_base × 0.6   # minimal engagement
```

Gold should be attainable by an engaged player. The leaderboard top scores will sit well above Gold. Thresholds are tuned upward over time as real player scores come in — they're soft targets for season pass milestones, not hard gates.

### Global constants (GameConstants autoload)

Values that apply universally across all maps and modes live in a `GameConstants` singleton autoload. Per-map values live in the resource. Nothing is hardcoded in scene files or magic-numbered in scripts.

**Global constants (not per-map):**

- Mob HP base and HP scale factor (×1.12/round after round 5)
- Build phase timings (30s / 25s / 5–10s compressed)
- Gold economy: round bonus formula (25 + round#), interest rate (1/10), interest cap (50/round)
- Tower cost (10g), sell refund rate (30%)
- Upgrade cost ramp per stat
- Crit hard caps (75% chance, ~500% damage)
- Multishot hard cap (+3 additional)
- Life starting value (100), total pool per player count

**Per-map (in MapResource):**

- Grid dimensions, entry/exit/checkpoint cells, obstacles, zones
- Supply cap, round count, mob count
- 1/2/3-star thresholds (Campaign and PVE only) — the `*_threshold` fields below are the star cutoffs

### Repo file structure

```
src/
  resources/
    map_resource.gd          # MapResource schema
    zone_definition.gd       # ZoneDefinition sub-resource
    game_constants.gd        # Autoload singleton — all global constants

  campaign/
    mission_01.tres
    mission_02.tres
    ...                      # five missions, up to mission_05.tres

  scripts/
    map_generator.gd         # Produces MapResource from seed + scale tier + mode
    map_loader.gd            # Reads MapResource, configures the scene
```

Campaign `.tres` files are hand-edited in the Godot editor or a text editor. They use the same schema as generated maps — no special-case code path.

---

## Procgen constraints

The map generator must guarantee for every seed:

- At least one bonus zone is reachable given the tower supply cap
- No more than two zones overlap at any point
- A valid path from entry through all checkpoints to exit exists with zero towers placed
- Entry and exit cells are on opposite sides of the map
- Checkpoints are placed to force mobs to traverse a significant portion of the map
- Obstacles do not block the initial path or seal the entry/exit funnel

Procgen algorithm details are an implementation concern for Claude Code, not a design concern. These constraints are the spec.

---

## Home screen and navigation

### First-launch flow

On first launch, a single boolean (`first_launch`) is written to save data and never reset. Before writing it, the game loads mission 1 directly — no home screen, no mode select, straight in.

The player can quit at any time via the pause menu (Esc → Quit to Menu). Quitting during the forced mission 1 lands on the home screen. There is no requirement to complete mission 1. The flag is set on first launch, not on mission completion.

After first launch, the game always opens to the home screen.

### Home screen (returning players)

Simple. Two primary options, nothing else competing for attention.

**Center of screen:**
- **Trials** button (PVE)
- **Ranked** button (PVP)

**Secondary (visible but not dominant):**
- Season progress bar + current tier badge — slim, top of screen
- Campaign — accessible as a smaller/tertiary button, not alongside PVE/PVP

**Utility (tucked away):**
- Settings

The hierarchy is honest: PVE and PVP are the game. Campaign is the tutorial you can revisit. Season progress is ambient context, not a call to action.

### Navigation from PVE

Click PVE → PVE lobby screen showing the 5 maps for the current window (Scale 1–5). Each shows your best posted score if any. Solo players go straight into the match on map select. Groups get a brief lobby: the host invites friends (invite-only, no random matchmaking) and launches when they want — the host hits play unilaterally, no ready-up gate. If you're in the lobby when the host launches, you're in.

### Navigation from PVP

Click PVP → queue immediately. Shows estimated wait time. Nothing to configure. Behind that press is a forming lobby (fills X/8; unanimous vote launches at 4–7, auto-launch at 8) — **full flow in `notes/matchmaking_orchestration.md`.**

### Navigation from Campaign

Click Campaign → mission list showing missions 1–5 with best star rating per mission. All missions unlocked from the start — difficulty curve is guidance, not a gate. Click any mission → straight in.

### Return to home screen

Win modal "Return Home", pause menu "Quit to Menu", and post-match screens all land on the home screen. There is no intermediate screen between any in-match exit and the home screen.

---

## In-match UI frame (added 2026-06-01)

## In-match UI frame

**Authoritative layout lives in `design/INMATCH_HUD.md`** (locked 2026-06-07, implemented). Summary: a single reserved **right rail** (Status / Score-or-Standing / Buttons), a **maximized 25×16 board** centred in the remainder, and tower info that docks in the rail's lower gap (with an over-board overlay fallback on short windows). The score box shows the map's 1/2/3-star thresholds + score in Campaign/Trials, or the standing in Ranked. Clicks outside the board rect are ignored.

(Superseded: the 2026-06-01 three-zone layout — top bar + left-dock minimap + camera-fit play rect, files `hud.gd`/`action_rail.gd`/`minimap_panel.gd` — is gone. See INMATCH_HUD.md.)

## Pause menu

### Trigger

Esc key. Uses a priority stack — deepest open UI layer closes first:

1. Upgrade panel open → Esc closes upgrade panel
2. Build mode active (no upgrade panel) → Esc exits build mode
3. Neither → Esc opens pause menu

### Objectives readout (added 2026-06-01)

In Campaign and PVE (any window, solo or group), the pause menu shows the map's medal targets — Bronze / Silver / Gold — alongside the player's current score, with reached targets highlighted. PVP carries no medals, so it shows no objectives block. Gated on the map having a Gold threshold.

### Single player (Campaign + solo PVE)

Pauses the scene tree while open (same mechanism as win panel).

Menu items:
- **Resume** (or press Esc again)
- **Settings**
- **Restart** — confirm dialog: "Restart this mission? Your progress will be lost."
- **Quit to Menu** — confirm dialog: "Quit to the main menu? Your progress will be lost."

### Multiplayer (PVP + group PVE)

Does NOT pause the scene tree. Game continues while the menu is open.

Menu items:
- **Resume** (or press Esc again)
- **Settings**
- **Quit Match** — confirm dialog, context-aware message:
  - PVP: "Quit the match? You will be eliminated and your lives will leave the pool."
  - PVE: "Quit the match? Your score will not be posted."

No Restart in multiplayer — you cannot restart a live match other players are in.

### Settings contents

Available from both pause menu and home screen:

- Master volume
- Music volume
- SFX volume
- Default game speed (1× / 2× / 3×)
- Fullscreen toggle
- Resolution select
- Damage numbers toggle
