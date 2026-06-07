extends Node2D
class_name Tower

# Gameplay tuning (base stats, tier increment, crit/multishot caps, upgrade cost
# ramp) lives in the GameConstants autoload. Presentation constants stay local.

const SPRITE_SCALE := 0.12  # fits a 48px tile

const LOADED_TEX := preload("res://assets/towers/arrow_box_loaded.png")
const UNLOADED_TEX := preload("res://assets/towers/arrow_box_unloaded.png")
const ProjectileScript := preload("res://scripts/projectile.gd")

# DESIGN color map: damage=red, range=green, attack_speed=blue,
# crit_chance=yellow, crit_damage=orange, multishot=purple.
# Each tier subtracts K from the complementary RGB channels.
const STAT_COLOR_SUB := {
	"damage":       Vector3(0.0,  0.7, 0.7),  # red
	"range":        Vector3(0.7,  0.0, 0.7),  # green
	"attack_speed": Vector3(0.7,  0.7, 0.0),  # blue
	"crit_chance":  Vector3(0.0,  0.0, 0.7),  # yellow
	"crit_damage":  Vector3(0.0,  0.35, 0.7), # orange
	"multishot":    Vector3(0.0,  0.7, 0.0),  # purple
}
const K_PER_TIER := 0.07

const RANGE_SEGMENTS := 48

var mobs: Array = []  # injected by build_controller / main
var board  # BoardState (round_manager) — for board-scoped zone lookup. Untyped.
var sprite: Sprite2D
var cooldown: float = 0.0
var _current_target: Node2D = null
var total_invested: int = 0  # base placement cost + all tier costs paid in
var grid_cell: Vector2i
var damage_done: float = 0.0  # cumulative credited damage this match
var kills: int = 0            # cumulative kills this match

# Cached sum of zone magnitudes per stat, computed at _ready (zones don't move).
var zone_bonus := {
	"damage": 0,
	"range": 0,
	"attack_speed": 0,
}

var tiers := {
	"damage": 0,
	"range": 0,
	"attack_speed": 0,
	"crit_chance": 0,
	"crit_damage": 0,
	"multishot": 0,
}

var _selected_range: Line2D
var _selected: bool = false

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = LOADED_TEX
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(sprite)

	_selected_range = Line2D.new()
	_selected_range.width = 3.0
	_selected_range.closed = true
	_selected_range.default_color = Color(1.0, 0.85, 0.35, 0.8)
	_selected_range.visible = false
	add_child(_selected_range)
	_compute_zone_bonuses()
	_refresh_range_circle()

func _compute_zone_bonuses() -> void:
	for stat in zone_bonus:
		zone_bonus[stat] = 0
	# Board-scoped: only this board's zones. Falls back to the global group if no
	# board was injected (e.g. a scene opened directly).
	var zones: Array = board.bonus_zones if board != null else get_tree().get_nodes_in_group("bonus_zones")
	for zone in zones:
		if not zone.touches_tower_cell(grid_cell):
			continue
		if zone.type in zone_bonus:
			zone_bonus[zone.type] += zone.magnitude

# Driven by BoardState.sim_step on the fixed sim tick (no longer self-_process'd).
# The single per-match RNG is threaded in so every crit roll lands in one defined
# draw order (towers step in placement order) — the re-sim reproduces the sequence.
func sim_step(delta: float, rng: RandomNumberGenerator) -> void:
	cooldown = maxf(0.0, cooldown - delta)

	var shot_count := 1 + get_multishot()
	var targets := _find_targets(shot_count)

	if targets.size() > 0:
		_current_target = targets[0]
		var to_target := _current_target.position - position
		sprite.rotation = to_target.angle() + PI / 2.0
	else:
		_current_target = null

	if cooldown > 0.0:
		return
	if targets.is_empty():
		return
	for t in targets:
		_fire_at(t, rng)
	cooldown = get_cooldown()

func get_damage() -> float:
	# DESIGN stacking: zone bonuses add together; here they also add to the tier
	# bonus rather than multiplying it. Working assumption.
	var mult: float = 1.0 + tiers["damage"] * GameConstants.TOWER_DAMAGE_INCREMENT + zone_bonus["damage"] / 100.0
	return GameConstants.TOWER_BASE_DAMAGE * mult

func get_range() -> float:
	var mult: float = 1.0 + tiers["range"] * GameConstants.TOWER_RANGE_INCREMENT + zone_bonus["range"] / 100.0
	return GameConstants.TOWER_BASE_RANGE * mult

func get_cooldown() -> float:
	var mult: float = 1.0 + tiers["attack_speed"] * GameConstants.TOWER_ATTACK_SPEED_INCREMENT + zone_bonus["attack_speed"] / 100.0
	return GameConstants.TOWER_BASE_COOLDOWN / mult

func get_crit_chance() -> float:
	return minf(tiers["crit_chance"] * GameConstants.CRIT_CHANCE_PER_TIER, GameConstants.CRIT_CHANCE_HARD_CAP)

func get_crit_damage_mult() -> float:
	return GameConstants.CRIT_DAMAGE_BASE + tiers["crit_damage"] * GameConstants.CRIT_DAMAGE_PER_TIER

func get_multishot() -> int:
	return mini(tiers["multishot"], GameConstants.MULTISHOT_HARD_CAP)

func upgrade_cost(stat: String) -> int:
	if not (stat in tiers):
		return 0
	if stat == "multishot" and tiers[stat] >= GameConstants.MULTISHOT_HARD_CAP:
		return 0
	if stat == "crit_chance" and get_crit_chance() >= GameConstants.CRIT_CHANCE_HARD_CAP:
		return 0
	var tier_after: int = tiers[stat] + 1
	return GameConstants.UPGRADE_COST_BASE[stat] * tier_after

func can_upgrade(stat: String) -> bool:
	return upgrade_cost(stat) > 0

func upgrade(stat: String) -> void:
	if not (stat in tiers):
		return
	tiers[stat] += 1
	total_invested += GameConstants.UPGRADE_COST_BASE[stat] * tiers[stat]
	_update_modulate()
	if stat == "range":
		_refresh_range_circle()
	# Record for the re-sim contract (no-op unless recording). board is the BoardState;
	# seat lives on its build_controller. Logged with the coordinator's current sim_tick.
	if board != null and board.coordinator != null:
		var seat: int = board.build_controller.seat if board.build_controller != null else 0
		board.coordinator.log_input(seat, {"type": "upgrade", "cell": grid_cell, "stat": stat})

func set_selected(value: bool) -> void:
	_selected = value
	_selected_range.visible = value

# Credited by a mob when one of this tower's projectiles lands.
func register_damage(amount: float, killed: bool) -> void:
	damage_done += amount
	if killed:
		kills += 1

func _find_targets(count: int) -> Array:
	var in_range: Array = []
	var r := get_range()
	for m in mobs:
		if not is_instance_valid(m):
			continue
		if position.distance_to(m.position) > r:
			continue
		in_range.append(m)
	in_range.sort_custom(func(a, b): return a.path_index > b.path_index)
	if in_range.size() <= count:
		return in_range
	return in_range.slice(0, count)

func _fire_at(target: Node2D, rng: RandomNumberGenerator) -> void:
	var is_crit := rng.randf() < get_crit_chance()
	var dmg := get_damage()
	if is_crit:
		dmg *= get_crit_damage_mult()

	var p := ProjectileScript.new()
	p.target = target
	p.damage = dmg
	p.is_crit = is_crit
	p.source_tower = self
	p.position = position
	get_parent().add_child(p)
	# Track on this board so BoardState.sim_step advances it on the fixed tick
	# (projectiles no longer self-_process). board is the BoardState (round_manager).
	if board != null:
		board.projectiles.append(p)

	sprite.texture = UNLOADED_TEX
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(func(): sprite.texture = LOADED_TEX)

func _update_modulate() -> void:
	var r := 1.0
	var g := 1.0
	var b := 1.0
	for stat in tiers:
		var t: int = tiers[stat]
		if t == 0:
			continue
		var sub: Vector3 = STAT_COLOR_SUB[stat]
		r -= sub.x * t * K_PER_TIER
		g -= sub.y * t * K_PER_TIER
		b -= sub.z * t * K_PER_TIER
	sprite.modulate = Color(maxf(0.0, r), maxf(0.0, g), maxf(0.0, b), 1.0)

func _refresh_range_circle() -> void:
	var r := get_range()
	var pts := PackedVector2Array()
	for i in range(RANGE_SEGMENTS):
		var a := i * TAU / RANGE_SEGMENTS
		pts.append(Vector2(cos(a), sin(a)) * r)
	_selected_range.points = pts
