extends RefCounted
class_name ObstacleProps

# Registry of environmental props that can appear as map obstacles, organised into
# per-board SETS so a board only ever shows props that belong to it (a kids' slide on
# a beach board looks insane — notes/board_obstacle_model.md).
#
# The split that makes this safe for ranked:
#   • BLOCKING GEOMETRY (which cells, what footprint) is chosen by the generator and
#     baked into the seed — sim, shared by both players, resim-fed. See pick_footprint.
#   • Prop ART is resolved LOCALLY per equipped board over that fixed footprint — pure
#     cosmetic, costs the sim nothing, never enters the match record. See art_for.
#
# Each entry maps prop_id -> texture + footprint (cells it BLOCKS) + overhang (a width
# fudge; the sprite is base-anchored and may spill UPWARD, see obstacle.gd) + weight
# (relative odds among same-footprint props WITHIN its set).
#
# Curation follows design/INMATCH_FIXES.md §1: favour clean props; use big ruins
# SPARINGLY (low weight) so boards don't get busy. Art is drawn in elevation, so most
# props block 1x1 at the base and overhang upward; cars/ruins/pond are the genuine
# multi-cell blockers.

const P  := "res://assets/environment/props/"            # default (urban-decay) pool
const R  := "res://assets/environment/building_ruins/"
const SB := "res://assets/environment/suburbia/"

# --- DEFAULT pool: urban decay. Used by every board WITHOUT a bespoke set (Summer,
# Forest, Beach for S1 — they "keep seeding from owned props"). ---
const PROPS := {
	# --- 1x1 ground / small props (common) ---
	"dead_tree_01":     {"tex": preload(P + "dead_tree_01.png"),     "footprint": Vector2i(1, 1), "overhang": 1.05, "weight": 8},
	"dead_tree_02":     {"tex": preload(P + "dead_tree_02.png"),     "footprint": Vector2i(1, 1), "overhang": 1.05, "weight": 8},
	"oil_drum_fallen":  {"tex": preload(P + "oil_drum_fallen.png"),  "footprint": Vector2i(1, 1), "overhang": 1.0,  "weight": 8},
	"oil_drum_top":     {"tex": preload(P + "oil_drum_top.png"),     "footprint": Vector2i(1, 1), "overhang": 0.9,  "weight": 6},
	# NOTE: street_lamp_01/02 deliberately omitted — their art is ~7x taller than wide,
	# so a 1x1 base renders a 3-cell pole upward whose overhang cells stay buildable,
	# reading as a "bridge" with a non-blocking top. Removed from the pool (cars/ruins
	# cover large props). PNGs kept on disk, just unreferenced.
	"hydrant":          {"tex": preload(P + "hydrant.png"),          "footprint": Vector2i(1, 1), "overhang": 0.85, "weight": 6},
	"tire_01":          {"tex": preload(P + "tire_01.png"),          "footprint": Vector2i(1, 1), "overhang": 0.9,  "weight": 5},
	"tire_02":          {"tex": preload(P + "tire_02.png"),          "footprint": Vector2i(1, 1), "overhang": 0.9,  "weight": 5},
	"tire_03":          {"tex": preload(P + "tire_03.png"),          "footprint": Vector2i(1, 1), "overhang": 0.9,  "weight": 5},
	"trash_can":        {"tex": preload(P + "trash_can.png"),        "footprint": Vector2i(1, 1), "overhang": 0.95, "weight": 6},
	"trash_can_fallen": {"tex": preload(P + "trash_can_fallen.png"), "footprint": Vector2i(1, 1), "overhang": 0.95, "weight": 5},
	"wheelie_bin":      {"tex": preload(P + "wheelie_bin.png"),      "footprint": Vector2i(1, 1), "overhang": 1.0,  "weight": 6},
	"rubble_pile_01":   {"tex": preload(P + "rubble_pile_01.png"),   "footprint": Vector2i(1, 1), "overhang": 1.1,  "weight": 7},
	"rubble_pile_02":   {"tex": preload(P + "rubble_pile_02.png"),   "footprint": Vector2i(1, 1), "overhang": 1.1,  "weight": 7},
	"rubble_pile_03":   {"tex": preload(P + "rubble_pile_03.png"),   "footprint": Vector2i(1, 1), "overhang": 1.1,  "weight": 6},
	"rubbish_01":       {"tex": preload(P + "rubbish_01.png"),       "footprint": Vector2i(1, 1), "overhang": 0.85, "weight": 4},
	"rubbish_02":       {"tex": preload(P + "rubbish_02.png"),       "footprint": Vector2i(1, 1), "overhang": 0.8,  "weight": 4},
	"rubbish_03":       {"tex": preload(P + "rubbish_03.png"),       "footprint": Vector2i(1, 1), "overhang": 0.8,  "weight": 4},

	# --- multi-cell wrecks (uncommon) ---
	"car_02":           {"tex": preload(P + "car_02.png"),           "footprint": Vector2i(1, 2), "overhang": 1.05, "weight": 4},
	"car_reck":         {"tex": preload(P + "car_reck.png"),         "footprint": Vector2i(2, 2), "overhang": 1.0,  "weight": 3},
	"truck_on_side":    {"tex": preload(P + "truck_on_side.png"),    "footprint": Vector2i(2, 2), "overhang": 1.0,  "weight": 2},

	# --- building ruins (rare; sparingly per spec) ---
	"building_ruin_05": {"tex": preload(R + "building_ruin_05.png"), "footprint": Vector2i(1, 2), "overhang": 1.0,  "weight": 2},
	"building_ruin_11": {"tex": preload(R + "building_ruin_11.png"), "footprint": Vector2i(1, 2), "overhang": 1.0,  "weight": 2},
	"building_ruin_04": {"tex": preload(R + "building_ruin_04.png"), "footprint": Vector2i(2, 2), "overhang": 1.0,  "weight": 1},
	"building_ruin_06": {"tex": preload(R + "building_ruin_06.png"), "footprint": Vector2i(2, 2), "overhang": 1.0,  "weight": 1},
	"building_ruin_10": {"tex": preload(R + "building_ruin_10.png"), "footprint": Vector2i(2, 2), "overhang": 1.0,  "weight": 1},
}

# --- SUBURBIA pool: trees / bushes / yard clutter + slide (1x2) + pond (2x2). Scoped
# to board_suburbia only. Bushes are the green filler (high weight); clutter is the
# variety; slide and pond are the lone multi-cell options for their footprint. ---
const SUBURBIA := {
	# --- 1x1 greenery (common — suburban lawns read green) ---
	"sub_tree_01":   {"tex": preload(SB + "tree_01.png"),   "footprint": Vector2i(1, 1), "overhang": 1.1, "weight": 5},
	"sub_tree_02":   {"tex": preload(SB + "tree_02.png"),   "footprint": Vector2i(1, 1), "overhang": 1.1, "weight": 5},
	"sub_tree_03":   {"tex": preload(SB + "tree_03.png"),   "footprint": Vector2i(1, 1), "overhang": 1.1, "weight": 5},
	"sub_bush_01":   {"tex": preload(SB + "bush_01.png"),   "footprint": Vector2i(1, 1), "overhang": 1.0, "weight": 8},
	"sub_bush_02":   {"tex": preload(SB + "bush_02.png"),   "footprint": Vector2i(1, 1), "overhang": 1.0, "weight": 8},
	"sub_bush_03":   {"tex": preload(SB + "bush_03.png"),   "footprint": Vector2i(1, 1), "overhang": 1.0, "weight": 8},
	"sub_bush_04":   {"tex": preload(SB + "bush_04.png"),   "footprint": Vector2i(1, 1), "overhang": 1.0, "weight": 8},
	"sub_bush_05":   {"tex": preload(SB + "bush_05.png"),   "footprint": Vector2i(1, 1), "overhang": 1.0, "weight": 7},
	# --- 1x1 yard clutter (variety; lower weight so greenery dominates) ---
	"sub_bbq":          {"tex": preload(SB + "bbq.png"),                 "footprint": Vector2i(1, 1), "overhang": 0.95, "weight": 4},
	"sub_mailbox":      {"tex": preload(SB + "mail_box.png"),            "footprint": Vector2i(1, 1), "overhang": 0.85, "weight": 4},
	"sub_bird_house":   {"tex": preload(SB + "bird_house.png"),          "footprint": Vector2i(1, 1), "overhang": 0.85, "weight": 3},
	"sub_bin_black":    {"tex": preload(SB + "wheelie_bin_black.png"),   "footprint": Vector2i(1, 1), "overhang": 1.0,  "weight": 4},
	"sub_bin_green":    {"tex": preload(SB + "wheelie_bin_green.png"),   "footprint": Vector2i(1, 1), "overhang": 1.0,  "weight": 4},
	"sub_chair_blue":   {"tex": preload(SB + "garden_chair_blue.png"),   "footprint": Vector2i(1, 1), "overhang": 0.9,  "weight": 3},
	"sub_chair_red":    {"tex": preload(SB + "garden_chair_red.png"),    "footprint": Vector2i(1, 1), "overhang": 0.9,  "weight": 3},
	"sub_chair_yellow": {"tex": preload(SB + "garden_chair_yellow.png"), "footprint": Vector2i(1, 1), "overhang": 0.9,  "weight": 3},
	"sub_pot_large":    {"tex": preload(SB + "plant_pot_large.png"),     "footprint": Vector2i(1, 1), "overhang": 0.9,  "weight": 4},
	"sub_pot_small":    {"tex": preload(SB + "plant_pot_small.png"),     "footprint": Vector2i(1, 1), "overhang": 0.85, "weight": 4},
	# --- multi-cell (lone option per footprint) ---
	"sub_slide":        {"tex": preload(SB + "slide.png"),               "footprint": Vector2i(1, 2), "overhang": 1.0,  "weight": 1},
	"sub_pond":         {"tex": preload(SB + "pond.png"),                "footprint": Vector2i(2, 2), "overhang": 1.0,  "weight": 1},
}

# Fallback for any unknown prop_id (e.g. a stale .tres) so the loader never crashes.
const FALLBACK_ID := "rubble_pile_01"

# board cosmetic id -> prop set. Anything not listed uses the default pool (PROPS).
# Kept as a function (not a const dict) because GDScript const initialisers can't
# safely cross-reference other consts in the same file.
static func _set_for(board_id: String) -> Dictionary:
	match board_id:
		"board_suburbia": return SUBURBIA
		_:                return PROPS

static func has_prop(prop_id: String) -> bool:
	return PROPS.has(prop_id) or SUBURBIA.has(prop_id)

# Entry lookup across all sets — used by the AUTHORED prop_id path (campaign .tres that
# stamp a concrete prop). Generated maps leave prop_id empty and go through art_for.
static func _entry(prop_id: String) -> Dictionary:
	if PROPS.has(prop_id):
		return PROPS[prop_id]
	if SUBURBIA.has(prop_id):
		return SUBURBIA[prop_id]
	return PROPS[FALLBACK_ID]

static func tex_for(prop_id: String) -> Texture2D:
	return _entry(prop_id)["tex"]

static func footprint_for(prop_id: String) -> Vector2i:
	return _entry(prop_id)["footprint"]

static func overhang_for(prop_id: String) -> float:
	return _entry(prop_id)["overhang"]

# Footprint the generator bakes into the seed. Board-AGNOSTIC on purpose: the seed
# decides the blocking shape; the per-board art is resolved later over it. Mostly 1x1,
# occasional 1x2, rare 2x2 — mirrors the old prop-weight feel. max_dim caps the shape
# to the remaining cell budget (max_dim < 2 => only 1x1 fits).
static func pick_footprint(rng: RandomNumberGenerator, max_dim: int) -> Vector2i:
	if max_dim < 2:
		return Vector2i.ONE
	var roll := rng.randi_range(1, 100)
	if roll <= 70:
		return Vector2i(1, 1)
	if roll <= 90:
		return Vector2i(1, 2)
	return Vector2i(2, 2)

# Resolve the prop ART for a baked footprint on a given board. `key` is a stable int
# (derive it from the obstacle origin) so the same cell always draws the same prop while
# different cells vary — deterministic, no rng, board-scoped. Falls back to the default
# pool (then FALLBACK_ID) if a board lacks a same-footprint prop. Returns the full entry
# dict ({tex, footprint, overhang, weight}); callers read tex/overhang.
static func art_for(board_id: String, footprint: Vector2i, key: int) -> Dictionary:
	var id := _pick_in_pool(_set_for(board_id), footprint, key)
	if id == "":
		id = _pick_in_pool(PROPS, footprint, key)   # default-pool fallback
	if id == "":
		id = FALLBACK_ID
	return _entry(id)

# Weighted pick among a pool's props whose footprint == the target, driven by `key`
# (not rng) so it's a pure function of the cell. Returns "" if the pool has none.
static func _pick_in_pool(pool: Dictionary, footprint: Vector2i, key: int) -> String:
	var eligible: Array = []
	var total := 0
	for id in pool:
		if pool[id]["footprint"] == footprint:
			var w: int = pool[id]["weight"]
			eligible.append([id, w])
			total += w
	if total <= 0:
		return ""
	var roll: int = (absi(key) % total) + 1
	for pair in eligible:
		roll -= pair[1]
		if roll <= 0:
			return pair[0]
	return eligible[-1][0]
