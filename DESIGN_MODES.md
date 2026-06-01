# Design — Modes, Maps, Progression, Seasons, UI

Locked design decisions for everything outside the core gameplay loop. Core gameplay (towers, mobs, economy, pathing, wave structure) lives in `DESIGN.md`.

---

## Game modes overview

There are three modes. They share the same core gameplay loop and the same map resource format. What differs is how the map is generated, how scoring works, and what the social context is.

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

Ten missions maximum. Static hand-authored maps. No randomization.

**Purpose is tutorial only.** The campaign teaches the game through a difficulty curve — each mission is designed to surface a specific mechanic or decision. This is not the product's selling point. Players should be through campaign in 1–2 hours and into PVE/PVP.

No expansion unless players demand it after launch. Do not get lost building campaign content.

Each mission has a per-mission leaderboard (total damage dealt). Bronze/Silver/Gold thresholds exist to give players a concrete target and feed season pass milestones. Gold should be achievable by a reasonably engaged player — the leaderboard is where real competition lives, not the threshold.

### Mission curriculum (locked 2026-05-31)

Mission 1 is the forgiving big-sandbox intro that exposes everything at once. Each later mission **isolates one decision** on a rising curve; mission 10 integrates all of it as a bridge into PVE Scale 5. Difficulty climbs mainly via round count (mob HP scales ×1.12/round after round 5) and mob count, with supply deliberately *tightened* on the missions whose lesson is investment efficiency. Crit and multishot are taught through the upgrade stats (there are no crit/multishot bonus zones — only DAMAGE/ATTACK_SPEED/RANGE/SLOW exist).

| # | Name | Teaches (the one decision) | Grid | CP | Zones | Obst. | Supply | Rounds | Mobs |
|---|------|------|------|----|-------|------|--------|--------|------|
| 1 | First Contact | Basics — maze, upgrade, use zones | 40×22 | 3 | 4 | 8 | 100 | 10 | 8 |
| 2 | The Long Way | Mazing — path length *is* damage | 26×16 | 1 | 0 | 0 | 35 | 9 | 8 |
| 3 | Switchback | Checkpoints force the route | 30×18 | 2 | 0 | 2 | 45 | 10 | 10 |
| 4 | Hot Spots | Tower-buff zones + color synergy | 32×18 | 2 | 3 (dmg/atk/rng) | 3 | 50 | 11 | 12 |
| 5 | Cold Feet | Slow zones — time-on-tower as a weapon | 34×20 | 2 | 3 (2 slow + dmg) | 4 | 60 | 12 | 14 |
| 6 | Sharp Shooters | Crit upgrades — go *tall*, not wide | 30×18 | 2 | 2 (dmg/atk) | 4 | 40 (tight) | 12 | 12 |
| 7 | Spread the Love | Multishot — punish a bunched train | 34×20 | 3 | 2 (atk/rng) | 4 | 60 | 13 | 16 |
| 8 | Tight Quarters | Maze around heavy obstacles, low supply | 32×20 | 2 | 2 | 12 | 45 (tight) | 13 | 14 |
| 9 | Compound Interest | Economy — save vs. spend, interest cap | 36×20 | 2 | 3 | 5 | 80 | 16 | 16 |
| 10 | The Gauntlet | Capstone — everything, incl. zone stacking | 40×22 | 3 | 6 (2 dmg stack + atk/rng + 2 slow) | 8 | 100 | 18 | 20 |

Thresholds for 2–10 follow mission 1's approved ratio (silver ≈ 1.875 × supply × rounds; bronze ≈ ⅔ silver; gold ≈ 4⁄3 silver), rounded clean. They are **soft and uncalibrated** — same status as the PVE thresholds, to be tuned once real campaign scores come in.

---

## PVE (Leaderboard mode)

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

A solo player posts to the Solo board. A duo posts to the Duo board. If four friends vote to play for individual scores instead of team score, each of their individual scores posts to the Solo board — the seed is the seed regardless of whether you brought friends.

### Team vs individual scoring

At lobby creation, the default is team score (sum of all players' damage). Before the match starts, players vote to switch to individual score. Squad default wins ties; host vote breaks ties if the group is split. Decision is locked at match start and applies for that match only. Groups can switch each match as they choose.

### Arena

All players play simultaneously on their own maze. The arena is a 2-column grid of boards, up to 8 slots. Only filled slots are shown — no empty gray placeholders.

Boards are **hidden during build phase**. Boards are **visible during run phase**. This is the same layout used in PVP.

---

## PVP (Ranked)

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

LP (league points) awarded per placement. Top placements gain LP, bottom placements lose LP, with the amount scaling by exact finish position. 1st gains the most; 8th loses the most. Exact LP curve TBD — playtest to determine.

**Rank tiers:** Bronze → Silver → Gold → Platinum → Masters.

LP accumulates within a tier. Reaching the threshold promotes to the next tier. Falling to zero in a tier demotes.

### Season resets

At the end of each season, every player's rank drops one tier. Masters → Platinum, Platinum → Gold, etc. Bronze stays Bronze.

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
- Bronze/Silver/Gold thresholds (Campaign and PVE only)

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
    ...                      # up to mission_10.tres

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
- **PVE** button
- **PVP** button

**Secondary (visible but not dominant):**
- Season progress bar + current tier badge — slim, top of screen
- Campaign — accessible as a smaller/tertiary button, not alongside PVE/PVP

**Utility (tucked away):**
- Settings

The hierarchy is honest: PVE and PVP are the game. Campaign is the tutorial you can revisit. Season progress is ambient context, not a call to action.

### Navigation from PVE

Click PVE → PVE lobby screen showing the 5 maps for the current window (Scale 1–5). Each shows your best posted score if any. Solo players go straight into the match on map select. Groups get a brief lobby (invite + team/individual vote + ready up) before loading.

### Navigation from PVP

Click PVP → queue immediately. Shows estimated wait time. Nothing to configure.

### Navigation from Campaign

Click Campaign → mission list showing missions 1–10 with best medal per mission. All missions unlocked from the start — difficulty curve is guidance, not a gate. Click any mission → straight in.

### Return to home screen

Win modal "Return Home", pause menu "Quit to Menu", and post-match screens all land on the home screen. There is no intermediate screen between any in-match exit and the home screen.

---

## Pause menu

### Trigger

Esc key. Uses a priority stack — deepest open UI layer closes first:

1. Upgrade panel open → Esc closes upgrade panel
2. Build mode active (no upgrade panel) → Esc exits build mode
3. Neither → Esc opens pause menu

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
