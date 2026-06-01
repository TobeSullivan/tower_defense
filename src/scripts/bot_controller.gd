extends Node
class_name BotController

# A baseline opponent AI for one (non-local) board. Acts only during the build
# phase, one small action per tick (so it spreads out and reads naturally when
# spectated). Two behaviours:
#   1. Maze building — greedily place towers that maximize the mob path length
#      (bounded candidate sampling near the existing maze/path), up to a target
#      tower count that grows with the round and the bot's skill.
#   2. Upgrading — once at the tower target (or when it can't usefully place),
#      spend remaining gold upgrading towers in a preferred-stat order.
#
# Solves the cold-start problem (DESIGN: "bot multiplayer"). Difficulty tiers come
# later; `difficulty` already scales how aggressively the bot expands its maze.
# References are untyped to avoid class-name cycles.

const PathfinderScript := preload("res://scripts/pathfinder.gd")

const ACTION_INTERVAL := 0.2   # seconds between actions (run-phase FF speeds this up)
const SAMPLE_K := 12           # candidate cells evaluated per placement (bounds cost)
# Upgrade preference order (repeats bias the spend toward damage/attack speed).
const UPGRADE_PREF := ["damage", "attack_speed", "damage", "range", "crit_chance",
	"attack_speed", "crit_damage", "damage", "multishot"]

var board        # BoardState (round_manager)
var ctrl         # BuildController for this board
var coordinator  # MatchCoordinator
var difficulty: float = 1.0  # 0..1+ skill; scales maze size

var _accum := 0.0

func _process(delta: float) -> void:
	if coordinator == null or board == null or ctrl == null:
		return
	if coordinator.phase != "build" or coordinator.match_over:
		return
	if not board.is_active():  # eliminated (PVP) — stop playing
		return
	_accum += delta
	if _accum < ACTION_INTERVAL:
		return
	_accum = 0.0
	_take_one_action()

func _take_one_action() -> void:
	if ctrl.towers.size() < _target_towers() and board.can_afford(GameConstants.TOWER_COST):
		var cell = _best_maze_cell()
		if cell != null and ctrl.bot_place_tower(cell):
			return
	# At target, or no useful placement, or out of tower money: invest in upgrades.
	_try_upgrade()

func _target_towers() -> int:
	var t := int((6 + coordinator.round_num * 3) * difficulty)
	return mini(t, ctrl.max_towers)

# --- Maze placement ---

# Returns the placeable cell that most lengthens the path, or (if none lengthens
# it) any placeable scaffold cell near the maze, or null.
func _best_maze_cell():
	var cands := _candidate_cells()
	if cands.is_empty():
		return null
	cands.shuffle()
	var sample: Array = cands.slice(0, mini(SAMPLE_K, cands.size()))
	var base_len := _current_path_len()
	var best = null
	var best_len := base_len
	var first_valid = null
	for c in sample:
		var l := _trial_len(c)
		if l < 0.0:
			continue  # would block the path — never allowed
		if first_valid == null:
			first_valid = c
		if l > best_len:
			best_len = l
			best = c
	# Prefer a lengthening cell; otherwise lay scaffold so future towers can wall.
	return best if best != null else first_valid

# Placeable empty cells orthogonally adjacent to the existing maze (towers +
# obstacles); on an empty board, seed from the entry/exit/checkpoint cells so the
# maze grows along the corridor the mobs actually walk.
func _candidate_cells() -> Array:
	var sources: Array = ctrl.blocked.keys()
	if sources.is_empty():
		sources = [ctrl.entry_cell, ctrl.exit_cell]
		sources.append_array(ctrl.checkpoint_cells)
	var seen := {}
	var out: Array = []
	for s in sources:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = s + d
			if seen.has(n):
				continue
			seen[n] = true
			if _cell_placeable(n):
				out.append(n)
	return out

func _cell_placeable(cell: Vector2i) -> bool:
	if ctrl.towers.size() >= ctrl.max_towers:
		return false
	if cell.x < 0 or cell.y < 0 or cell.x >= ctrl.grid_size.x or cell.y >= ctrl.grid_size.y:
		return false
	if ctrl.blocked.has(cell):
		return false
	if cell == ctrl.entry_cell or cell == ctrl.exit_cell:
		return false
	for cp in ctrl.checkpoint_cells:
		if cell == cp:
			return false
	return true

func _current_path_len() -> float:
	var path: PackedVector2Array = PathfinderScript.compute_full_path(
		ctrl.entry_cell, ctrl.checkpoint_cells, ctrl.exit_cell, ctrl.blocked)
	return _polyline_len(path)

# Path length if a tower were placed at `cell`; -1 if that would block the path.
func _trial_len(cell: Vector2i) -> float:
	if not _cell_placeable(cell):
		return -1.0
	var trial: Dictionary = ctrl.blocked.duplicate()
	trial[cell] = true
	var path: PackedVector2Array = PathfinderScript.compute_full_path(
		ctrl.entry_cell, ctrl.checkpoint_cells, ctrl.exit_cell, trial)
	if path.is_empty():
		return -1.0
	return _polyline_len(path)

func _polyline_len(path: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, path.size()):
		l += path[i - 1].distance_to(path[i])
	return l

# --- Upgrades ---

func _try_upgrade() -> bool:
	if ctrl.towers.is_empty():
		return false
	var tower = ctrl.towers[randi() % ctrl.towers.size()]
	if not is_instance_valid(tower):
		return false
	for stat in UPGRADE_PREF:
		var cost: int = tower.upgrade_cost(stat)
		if cost > 0 and board.can_afford(cost):
			board.spend(cost)
			tower.upgrade(stat)
			return true
	return false
