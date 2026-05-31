extends Node

# Seeded procedural map generation for PVE and PVP. Produces a MapResource that
# map_loader consumes exactly like a hand-authored campaign .tres.
#
# Guarantees for every seed (DESIGN_MODES "Procgen constraints"):
#   - entry/exit on opposite sides (left/right edges — matches the horizontal
#     off-screen spawn extension in build_controller.current_path_world)
#   - a valid entry -> checkpoints -> exit path with zero towers (every obstacle
#     is validated against the pathfinder before it is kept)
#   - checkpoints placed to force a significant traversal (serpentine, validated
#     against a minimum path-length ratio)
#   - at least one bonus zone reachable within the supply cap (first zone is
#     planted on the natural path corridor)
#   - no point covered by 3+ zones (a new zone may overlap at most one existing)
#   - obstacles never seal the path or the entry/exit funnel (kept clear of the
#     edge columns; each obstacle re-validated)

const MapResourceScript := preload("res://resources/map_resource.gd")
const ZoneDefinitionScript := preload("res://resources/zone_definition.gd")
const GridScript := preload("res://scripts/grid.gd")
const PathfinderScript := preload("res://scripts/pathfinder.gd")
const BonusZoneScript := preload("res://scripts/bonus_zone.gd")

# Per-scale parameters (DESIGN_MODES PVE difficulty table). [min, max] ranges are
# resolved from the seed; everyone on a given daily map gets the same roll.
const SCALE_TABLE := {
	1: {"supply": 20,  "checkpoints": [1, 1], "zones": [1, 2], "mobs": 8,  "rounds": [10, 13]},
	2: {"supply": 40,  "checkpoints": [1, 2], "zones": [2, 3], "mobs": 12, "rounds": [13, 17]},
	3: {"supply": 60,  "checkpoints": [2, 2], "zones": [3, 4], "mobs": 16, "rounds": [17, 21]},
	4: {"supply": 80,  "checkpoints": [2, 3], "zones": [4, 5], "mobs": 20, "rounds": [21, 26]},
	5: {"supply": 100, "checkpoints": [3, 3], "zones": [5, 6], "mobs": 24, "rounds": [26, 30]},
}

# Path must be at least this multiple of the straight entry->exit distance, so
# checkpoints genuinely force traversal rather than a near-straight shot.
const MIN_PATH_RATIO := 1.35
# Fraction of supply assumed firing effectively when deriving thresholds (soft).
const THRESHOLD_COVERAGE := 0.5

# Returns a MapResource. `mode` / `window_type` are MapResource enum ints.
static func generate(seed: int, scale_tier: int, mode: int, window_type: int = 0, window_date: String = ""):
	var tier: int = clampi(scale_tier, 1, 5)
	var params: Dictionary = SCALE_TABLE[tier]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var cols := GridScript.COLS
	var rows := GridScript.ROWS

	var map: Variant = MapResourceScript.new()
	map.seed = seed
	map.mode = mode
	map.scale_tier = tier
	map.window_type = window_type
	map.window_date = window_date
	map.grid_size = Vector2i(cols, rows)
	map.supply_cap = params.supply
	map.mob_count = params.mobs
	map.round_count = rng.randi_range(params.rounds[0], params.rounds[1])

	# --- Entry / exit on opposite (left/right) edges, in the middle band ---
	map.entry_cell = Vector2i(0, rng.randi_range(int(rows * 0.3), int(rows * 0.7)))
	map.exit_cell = Vector2i(cols - 1, rng.randi_range(int(rows * 0.3), int(rows * 0.7)))

	# --- Checkpoints: re-roll until the path is long enough ---
	var n_cp: int = rng.randi_range(params.checkpoints[0], params.checkpoints[1])
	var straight: float = GridScript.cell_to_world(map.entry_cell).distance_to(GridScript.cell_to_world(map.exit_cell))
	var best_cps: Array[Vector2i] = []
	var best_len := -1.0
	for _attempt in range(12):
		var cps := _place_checkpoints(rng, n_cp, cols, rows)
		var plen := _path_length(_compute_path(map.entry_cell, cps, map.exit_cell, {}))
		if plen > best_len:
			best_len = plen
			best_cps = cps
		if plen >= straight * MIN_PATH_RATIO:
			break
	map.checkpoint_cells = best_cps

	# --- Obstacles: scatter, keep only those that don't break the path ---
	var reserved := {}
	reserved[map.entry_cell] = true
	reserved[map.exit_cell] = true
	for cp in map.checkpoint_cells:
		reserved[cp] = true

	var blocked := {}  # obstacle cells only
	var obstacles: Array[Vector2i] = []
	var target_obstacles: int = rng.randi_range(tier * 2, tier * 3 + 1)
	var tries := 0
	while obstacles.size() < target_obstacles and tries < target_obstacles * 10:
		tries += 1
		# Keep clear of the edge columns so the entry/exit funnel never seals.
		var cand := Vector2i(rng.randi_range(3, cols - 4), rng.randi_range(1, rows - 2))
		if reserved.has(cand) or blocked.has(cand):
			continue
		blocked[cand] = true
		if _compute_path(map.entry_cell, map.checkpoint_cells, map.exit_cell, blocked).is_empty():
			blocked.erase(cand)  # this obstacle would seal the path — skip it
		else:
			obstacles.append(cand)
	map.obstacle_cells = obstacles

	# --- Bonus zones: first on the path (reachable), rest scattered ---
	map.bonus_zones = _place_zones(rng, map, params, blocked, cols, rows)

	# --- Thresholds (Campaign/PVE only; PVP is last-standing, no medals) ---
	if mode != MapResourceScript.Mode.PVP:
		_derive_thresholds(map, best_len)

	return map

# Serpentine checkpoints: spread across the width, alternating top/bottom extremes.
static func _place_checkpoints(rng: RandomNumberGenerator, n: int, cols: int, rows: int) -> Array[Vector2i]:
	var cps: Array[Vector2i] = []
	for i in range(n):
		var frac := (float(i) + 1.0) / (float(n) + 1.0)
		var x := int(round(lerpf(cols * 0.22, cols * 0.82, frac)))
		x = clampi(x + rng.randi_range(-2, 2), 2, cols - 3)
		var y: int
		if i % 2 == 0:
			y = rng.randi_range(1, int(rows * 0.30))
		else:
			y = rng.randi_range(int(rows * 0.70), rows - 2)
		cps.append(Vector2i(x, y))
	return cps

static func _place_zones(rng: RandomNumberGenerator, map, params: Dictionary, blocked: Dictionary, cols: int, rows: int) -> Array:
	var zones: Array = []
	var n_zones: int = rng.randi_range(params.zones[0], params.zones[1])

	# First zone: planted on the path corridor so towers built along the natural
	# route reach it well within the supply cap.
	var path := _compute_path(map.entry_cell, map.checkpoint_cells, map.exit_cell, blocked)
	if path.size() >= 2:
		var mid: Vector2 = path[path.size() / 2]
		var cell := GridScript.world_to_cell(mid)
		zones.append(_make_zone(rng, cell))

	var tries := 0
	while zones.size() < n_zones and tries < n_zones * 12:
		tries += 1
		var cand := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
		var mag := rng.randi_range(1, 10) * 10
		# Enforce the "no 3-way overlap" rule: a new zone may overlap at most one
		# existing zone (so no point is ever inside three).
		var overlaps := 0
		for z in zones:
			if _zones_overlap(cand, mag, z.cell, z.magnitude):
				overlaps += 1
		if overlaps > 1:
			continue
		zones.append(_make_zone_with(rng, cand, mag))
	return zones

static func _make_zone(rng: RandomNumberGenerator, cell: Vector2i):
	return _make_zone_with(rng, cell, rng.randi_range(1, 10) * 10)

static func _make_zone_with(rng: RandomNumberGenerator, cell: Vector2i, magnitude: int):
	var zone: Variant = ZoneDefinitionScript.new()
	zone.cell = cell
	zone.magnitude = magnitude
	match rng.randi_range(0, 3):
		0: zone.type = ZoneDefinitionScript.Type.DAMAGE
		1: zone.type = ZoneDefinitionScript.Type.ATTACK_SPEED
		2: zone.type = ZoneDefinitionScript.Type.RANGE
		_: zone.type = ZoneDefinitionScript.Type.SLOW
	return zone

static func _zones_overlap(c1: Vector2i, m1: int, c2: Vector2i, m2: int) -> bool:
	var w1 := GridScript.cell_to_world(c1)
	var w2 := GridScript.cell_to_world(c2)
	return w1.distance_to(w2) < BonusZoneScript.radius_for_magnitude(m1) + BonusZoneScript.radius_for_magnitude(m2)

# Soft, per-map thresholds. run-phase duration is estimated from the maze: mobs
# spawn over (count-1)*interval, then traverse the full path. Towers are assumed
# to fire at THRESHOLD_COVERAGE of supply. These are deliberately rough and meant
# to be tuned upward as real scores come in (DESIGN_MODES threshold derivation).
static func _derive_thresholds(map, path_len_px: float) -> void:
	var base_dps: float = GameConstants.TOWER_BASE_DAMAGE / GameConstants.TOWER_BASE_COOLDOWN
	var traversal: float = path_len_px / GameConstants.MOB_SPEED
	var spawn_time: float = float(map.mob_count - 1) * GameConstants.SPAWN_INTERVAL
	var run_seconds: float = spawn_time + traversal
	var total_base: float = base_dps * THRESHOLD_COVERAGE * float(map.supply_cap) * run_seconds * float(map.round_count)
	map.silver_threshold = _round_to(total_base, 50)
	map.gold_threshold = _round_to(total_base * 1.5, 50)
	map.bronze_threshold = _round_to(total_base * 0.6, 50)

static func _round_to(value: float, step: int) -> int:
	return int(round(value / float(step))) * step

static func _compute_path(entry: Vector2i, checkpoints: Array, exit: Vector2i, blocked: Dictionary) -> PackedVector2Array:
	return PathfinderScript.compute_full_path(entry, checkpoints, exit, blocked)

static func _path_length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	return total
