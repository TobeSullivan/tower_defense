extends Node
class_name CosmeticsCatalog

# The cosmetics content model (design/COSMETICS.md, locked 2026-06-09) + the S1 season
# track (design/SEASON.md, numbers locked 2026-06-10). Pure static data + helpers — this
# file references NO other scripts (SaveData holds the player's raw cosmetics dict; the
# screens combine the two), so it can never join a class_name preload cycle.
#
# Cardinal rules (COSMETICS.md — do not bend):
#   1. 100% visual, zero competitive effect.
#   2. Skins NEVER enter the sim — equip state is client render-layer only, never routed
#      through the match record (it would break re-sim determinism).
#   3. Cosmetic FX match the default silhouette + duration.
#
# Catalog honesty: only items with a LOCKED acquisition source exist here — defaults,
# the 30 S1 track tiers, and the Ranked prestige bundle (Title + Frame + Rank Sticker,
# never on the track, never buyable). Reserve tower art (ballista, tesla, ...) stays out
# until a season/source assigns it. Items whose pack art isn't imported yet carry
# art = "" and render as placeholders tagged "import pending" (per the collection mock).

# ============================================================================
# Slots (8 + board sticker). group: "match" = changes the match view; "pro" = profile flair.
# ============================================================================

const SLOTS := [
	{"id": "tower", "name": "Tower", "group": "match"},
	{"id": "board", "name": "Board", "group": "match"},
	{"id": "zone", "name": "Zone", "group": "match"},
	{"id": "proj", "name": "Projectile", "group": "match"},
	{"id": "mob", "name": "Mob", "group": "match"},
	{"id": "sticker", "name": "Sticker", "group": "match"},
	{"id": "frame", "name": "Frame", "group": "pro"},
	{"id": "banner", "name": "Banner", "group": "pro"},
	{"id": "title", "name": "Title", "group": "pro"},
]

# Rarity = how you earned it, never luck (COSMETICS.md). Prestige is Ranked-exclusive.
const RARITY_LABEL := {"common": "common", "rare": "rare", "prestige": "prestige"}

# ============================================================================
# Items. Fields: id, slot, name, rarity, art (res:// path or "" = not imported yet),
# tint (swatch colour for recolor/shape items), hint (how to earn; "" once owned),
# default_owned (stock loadout).
# ============================================================================

const ITEMS := [
	# --- Stock loadout (in repo today; asset_catalog.md "Defaults") ---
	{"id": "tower_arrow", "slot": "tower", "name": "Arrow Box", "rarity": "common",
		"art": "res://assets/towers/arrow_box_loaded.png", "default_owned": true},
	{"id": "board_summer", "slot": "board", "name": "Summer", "rarity": "common",
		"art": "res://assets/maps/summer_grass_tile.png", "default_owned": true},
	{"id": "zone_classic", "slot": "zone", "name": "Classic", "rarity": "common",
		"tint": Color("7a5a8a"), "default_owned": true},
	{"id": "proj_arrow", "slot": "proj", "name": "Arrow", "rarity": "common",
		"art": "res://assets/towers/arrow.png", "default_owned": true},
	{"id": "mob_undead", "slot": "mob", "name": "Undead", "rarity": "common",
		"art": "res://assets/mobs/__zombie_01_walk_2_000.png", "default_owned": true},
	{"id": "frame_none", "slot": "frame", "name": "None", "rarity": "common",
		"tint": Color("23170d"), "default_owned": true},
	{"id": "banner_olive", "slot": "banner", "name": "Olive", "rarity": "common",
		"tint": Color("323d2c"), "default_owned": true},

	# --- S1 season track (design/SEASON.md S1 tier map; tier in TRACK below) ---
	{"id": "title_recruit", "slot": "title", "name": "Recruit", "rarity": "common", "hint": "Season 1 · Tier 1"},
	{"id": "mob_green", "slot": "mob", "name": "Green recolor", "rarity": "common", "tint": Color("5fbe38"), "hint": "Season 1 · Tier 2"},
	{"id": "zone_teal", "slot": "zone", "name": "Teal", "rarity": "common", "tint": Color("2fa7a0"), "hint": "Season 1 · Tier 3"},
	{"id": "fx_gold_bolt", "slot": "proj", "name": "Gold projectile", "rarity": "common", "tint": Color("d8af46"), "hint": "Season 1 · Tier 4"},
	{"id": "frame_wood", "slot": "frame", "name": "Wood frame", "rarity": "rare", "tint": Color("8a6a3a"), "hint": "Season 1 · Tier 5"},
	{"id": "mob_fish", "slot": "mob", "name": "Fish", "rarity": "rare", "hint": "Season 1 · Tier 6"},
	{"id": "title_pathfinder", "slot": "title", "name": "Pathfinder", "rarity": "common", "hint": "Season 1 · Tier 7"},
	{"id": "board_forest", "slot": "board", "name": "Forest", "rarity": "rare", "hint": "Season 1 · Tier 8"},
	{"id": "fx_blue_impact", "slot": "proj", "name": "Blue impact", "rarity": "common", "tint": Color("4a9fdf"), "hint": "Season 1 · Tier 9"},
	{"id": "tower_fire_crystal", "slot": "tower", "name": "Fire Crystal", "rarity": "rare",
		"art": "res://assets/towers/skins/fire_crystal.png", "hint": "Season 1 · Tier 10"},
	{"id": "fx_fireball", "slot": "proj", "name": "Fireball", "rarity": "rare", "tint": Color("d96a2a"), "hint": "Season 1 · Tier 10"},
	{"id": "mob_purple", "slot": "mob", "name": "Purple recolor", "rarity": "common", "tint": Color("8a5bbf"), "hint": "Season 1 · Tier 11"},
	{"id": "zone_magenta", "slot": "zone", "name": "Magenta", "rarity": "common", "tint": Color("b04a9a"), "hint": "Season 1 · Tier 12"},
	{"id": "title_maze_runner", "slot": "title", "name": "Maze Runner", "rarity": "common", "hint": "Season 1 · Tier 13"},
	{"id": "fx_fire_trail", "slot": "proj", "name": "Fireball trail", "rarity": "rare", "tint": Color("e08a3a"), "hint": "Season 1 · Tier 14"},
	{"id": "banner_mint_choco", "slot": "banner", "name": "Mint Choco", "rarity": "rare", "tint": Color("2a4a3a"), "hint": "Season 1 · Tier 15"},
	{"id": "mob_starfish", "slot": "mob", "name": "Starfish", "rarity": "rare", "hint": "Season 1 · Tier 16"},
	{"id": "board_beach", "slot": "board", "name": "Beach", "rarity": "rare", "hint": "Season 1 · Tier 17"},
	{"id": "fx_smoke_ring", "slot": "proj", "name": "Smoke ring", "rarity": "rare", "tint": Color("9a9282"), "hint": "Season 1 · Tier 18"},
	{"id": "title_overclocked", "slot": "title", "name": "Overclocked", "rarity": "common", "hint": "Season 1 · Tier 19"},
	{"id": "tower_ice_crystal", "slot": "tower", "name": "Ice Crystal", "rarity": "rare",
		"art": "res://assets/towers/skins/ice_crystal.png", "hint": "Season 1 · Tier 20"},
	{"id": "fx_ice_spell", "slot": "proj", "name": "Ice spell", "rarity": "rare", "tint": Color("7fd0ff"), "hint": "Season 1 · Tier 20"},
	{"id": "mob_cyan", "slot": "mob", "name": "Cyan recolor", "rarity": "common", "tint": Color("4ac0c0"), "hint": "Season 1 · Tier 21"},
	{"id": "zone_amber", "slot": "zone", "name": "Amber", "rarity": "common", "tint": Color("d79a52"), "hint": "Season 1 · Tier 22"},
	{"id": "frame_parchment", "slot": "frame", "name": "Parchment", "rarity": "rare", "tint": Color("d8c89a"), "hint": "Season 1 · Tier 23"},
	{"id": "fx_lightning", "slot": "proj", "name": "Lightning ball", "rarity": "rare", "tint": Color("ffe98a"), "hint": "Season 1 · Tier 24"},
	{"id": "title_gauntlet_vet", "slot": "title", "name": "Gauntlet Veteran", "rarity": "common", "hint": "Season 1 · Tier 25"},
	{"id": "board_toybrick", "slot": "board", "name": "Toy-brick", "rarity": "rare", "hint": "Season 1 · Tier 26"},
	{"id": "mob_hammerhead", "slot": "mob", "name": "Hammerhead", "rarity": "rare", "hint": "Season 1 · Tier 27"},
	{"id": "sticker_speech", "slot": "sticker", "name": "Speech bubble", "rarity": "rare", "tint": Color("b9c7a4"), "hint": "Season 1 · Tier 28"},
	{"id": "fx_explosion", "slot": "proj", "name": "Explosion recolor", "rarity": "common", "tint": Color("b04a2a"), "hint": "Season 1 · Tier 29"},
	{"id": "tower_dark_crystal", "slot": "tower", "name": "Dark Crystal", "rarity": "rare",
		"art": "res://assets/towers/skins/dark_crystal.png", "hint": "Season 1 · Tier 30"},
	{"id": "fx_dark", "slot": "proj", "name": "Dark spell", "rarity": "rare", "tint": Color("6a3a8a"), "hint": "Season 1 · Tier 30"},

	# --- Ranked prestige bundle (COSMETICS.md): Title + Frame + Rank Sticker per season
	#     placement, scaled by tier. Ranked-exclusive — never on the track, never buyable. ---
	{"id": "title_bronze", "slot": "title", "name": "Bronze", "rarity": "prestige", "hint": "Ranked · Bronze placement"},
	{"id": "title_silver", "slot": "title", "name": "Silver", "rarity": "prestige", "hint": "Ranked · Silver placement"},
	{"id": "title_gold", "slot": "title", "name": "Gold", "rarity": "prestige", "hint": "Ranked · Gold placement"},
	{"id": "title_platinum", "slot": "title", "name": "Platinum", "rarity": "prestige", "hint": "Ranked · Platinum placement"},
	{"id": "title_masters", "slot": "title", "name": "Masters", "rarity": "prestige", "hint": "Ranked · Masters placement"},
	{"id": "frame_bronze", "slot": "frame", "name": "Bronze frame", "rarity": "prestige", "tint": Color("d79a52"), "hint": "Ranked · Bronze placement"},
	{"id": "frame_silver", "slot": "frame", "name": "Silver frame", "rarity": "prestige", "tint": Color("c0c8d0"), "hint": "Ranked · Silver placement"},
	{"id": "frame_gold", "slot": "frame", "name": "Gold frame", "rarity": "prestige", "tint": Color("b38e2c"), "hint": "Ranked · Gold placement"},
	{"id": "frame_platinum", "slot": "frame", "name": "Platinum frame", "rarity": "prestige", "tint": Color("8ad0d0"), "hint": "Ranked · Platinum placement"},
	{"id": "frame_masters", "slot": "frame", "name": "Masters frame", "rarity": "prestige", "tint": Color("e0c060"), "hint": "Ranked · Masters placement"},
	{"id": "sticker_rect_s1", "slot": "sticker", "name": "Rectangle (S1)", "rarity": "prestige", "tint": Color("b38e2c"), "hint": "Ranked · season placement"},
]

# ============================================================================
# S1 track: 30 tiers x 1,000 pts (8 weeks; notes/season_pass.md). Milestones 10/20/30.
# Each tier grants the listed item ids (milestone tiers grant tower + its themed FX).
# ============================================================================

const SEASON := 1
const TIER_COUNT := 30
const POINTS_PER_TIER := 1000
const MILESTONES := [10, 20, 30]

const TRACK := [
	{"tier": 1, "items": ["title_recruit"]},
	{"tier": 2, "items": ["mob_green"]},
	{"tier": 3, "items": ["zone_teal"]},
	{"tier": 4, "items": ["fx_gold_bolt"]},
	{"tier": 5, "items": ["frame_wood"]},
	{"tier": 6, "items": ["mob_fish"]},
	{"tier": 7, "items": ["title_pathfinder"]},
	{"tier": 8, "items": ["board_forest"]},
	{"tier": 9, "items": ["fx_blue_impact"]},
	{"tier": 10, "items": ["tower_fire_crystal", "fx_fireball"]},
	{"tier": 11, "items": ["mob_purple"]},
	{"tier": 12, "items": ["zone_magenta"]},
	{"tier": 13, "items": ["title_maze_runner"]},
	{"tier": 14, "items": ["fx_fire_trail"]},
	{"tier": 15, "items": ["banner_mint_choco"]},
	{"tier": 16, "items": ["mob_starfish"]},
	{"tier": 17, "items": ["board_beach"]},
	{"tier": 18, "items": ["fx_smoke_ring"]},
	{"tier": 19, "items": ["title_overclocked"]},
	{"tier": 20, "items": ["tower_ice_crystal", "fx_ice_spell"]},
	{"tier": 21, "items": ["mob_cyan"]},
	{"tier": 22, "items": ["zone_amber"]},
	{"tier": 23, "items": ["frame_parchment"]},
	{"tier": 24, "items": ["fx_lightning"]},
	{"tier": 25, "items": ["title_gauntlet_vet"]},
	{"tier": 26, "items": ["board_toybrick"]},
	{"tier": 27, "items": ["mob_hammerhead"]},
	{"tier": 28, "items": ["sticker_speech"]},
	{"tier": 29, "items": ["fx_explosion"]},
	{"tier": 30, "items": ["tower_dark_crystal", "fx_dark"]},
]

# ============================================================================
# Lookups + state math. `owned`/`claimed` come from SaveData's cosmetics dict; this file
# stays pure so it never references the autoload.
# ============================================================================

static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if it["id"] == id:
			return it
	return {}

static func slot_items(slot: String) -> Array:
	var out: Array = []
	for it in ITEMS:
		if it["slot"] == slot:
			out.append(it)
	return out

static func slot_name(slot: String) -> String:
	for s in SLOTS:
		if s["id"] == slot:
			return s["name"]
	return slot

static func default_equipped() -> Dictionary:
	var out := {}
	for it in ITEMS:
		if it.get("default_owned", false) and not out.has(it["slot"]):
			out[it["slot"]] = it["id"]
	return out

# True if `id` is owned given the save's owned list (stock items are always owned).
static func is_owned(id: String, owned: Array) -> bool:
	var it := item(id)
	return not it.is_empty() and (it.get("default_owned", false) or owned.has(id))

# Per-slot (owned, total) for the rack completion counts.
static func slot_completion(slot: String, owned: Array) -> Vector2i:
	var have := 0
	var items := slot_items(slot)
	for it in items:
		if is_owned(it["id"], owned):
			have += 1
	return Vector2i(have, items.size())

# Overall collection completion in [0, 1].
static func overall_completion(owned: Array) -> float:
	var have := 0
	for it in ITEMS:
		if is_owned(it["id"], owned):
			have += 1
	return float(have) / float(ITEMS.size()) if ITEMS.size() > 0 else 0.0

# --- Season track math (points -> tiers). Tier N unlocks at N * POINTS_PER_TIER. ---

static func unlocked_tier(points: int) -> int:
	return clampi(points / POINTS_PER_TIER, 0, TIER_COUNT)

# State for a tier given the save's points + claimed list:
# "claimed" | "claimable" (reached, unclaimed) | "current" (the tier being earned) | "locked".
static func tier_state(tier: int, points: int, claimed: Array) -> String:
	if claimed.has(tier):
		return "claimed"
	var unlocked := unlocked_tier(points)
	if tier <= unlocked:
		return "claimable"
	if tier == unlocked + 1:
		return "current"
	return "locked"

static func tier_items(tier: int) -> Array:
	for t in TRACK:
		if t["tier"] == tier:
			return t["items"]
	return []

# The first unclaimed-tier reward at or after the current position (the "next reward" chip).
static func next_reward_tier(points: int, claimed: Array) -> int:
	for t in TRACK:
		if not claimed.has(t["tier"]):
			return t["tier"]
	return 0
