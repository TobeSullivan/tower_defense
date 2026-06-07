extends Node2D
class_name Mob

const DamageNumberScript := preload("res://scripts/damage_number.gd")
const DeathFxScript := preload("res://scripts/death_fx.gd")

# Base HP, speed, and slow floor live in the GameConstants autoload. Per-round HP
# is injected via max_hp by the spawner.

var path: PackedVector2Array
var path_index: int = 0
var max_hp: float = GameConstants.MOB_BASE_HP
var hp: float = GameConstants.MOB_BASE_HP
# Set false SYNCHRONOUSLY by BoardState when this mob reaches the exit (before the
# deferred queue_free), so towers/projectiles stop targeting it the same tick. A
# kill only RESPAWNS the mob (see _explode_and_respawn) — alive stays true there.
var alive: bool = true

# The BoardState this mob belongs to (injected by its spawner). Damage and kills
# credit only this board — NOT a global group, which would cross-contaminate every
# board's score in a multiplayer match. Untyped to avoid the class-name cycle.
var board

var anim: AnimatedSprite2D

# One SpriteFrames shared by every mob (built once). Rebuilding it per spawn was
# needless allocation churn — brutal at high spawn/respawn rates.
static var _walk_frames: SpriteFrames = null

func _ready() -> void:
	hp = max_hp
	anim = AnimatedSprite2D.new()
	anim.sprite_frames = _shared_walk_frames()
	anim.scale = Vector2(0.08, 0.08)
	add_child(anim)
	anim.play("walk")

	if path.size() > 0:
		position = path[0]
		path_index = 1

static func _shared_walk_frames() -> SpriteFrames:
	if _walk_frames != null:
		return _walk_frames
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 12.0)
	for i in range(10):
		var tex: Texture2D = load("res://assets/mobs/__zombie_01_walk_2_%03d.png" % i)
		frames.add_frame("walk", tex)
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_walk_frames = frames
	return _walk_frames

# Driven by BoardState.sim_step on the fixed sim tick (no longer self-_physics_process'd).
# Returns true when it reaches the exit; the board then marks it not-alive, drops it
# from the mob array, and frees the node.
func sim_step(delta: float) -> bool:
	if path.size() < 2:
		return false

	if path_index >= path.size():
		return true  # reached exit — board despawns

	var target := path[path_index]
	var to_target := target - position
	var step := _current_speed() * delta

	if step >= to_target.length():
		position = target
		path_index += 1
	else:
		position += to_target.normalized() * step

	# Sprite's native facing is north (head at top of sprite, -Y axis).
	# Rotate +PI/2 offset so head leads the movement direction.
	if to_target.length_squared() > 0.01:
		anim.rotation = to_target.angle() + PI / 2.0
	return false

func _current_speed() -> float:
	# Sum magnitudes of all slow zones the mob currently overlaps.
	# Same-type additive per DESIGN stacking rule; speed capped at SLOW_FLOOR.
	var slow_total := 0
	# Board-scoped: only this board's zones (falls back to the global group if no
	# board was injected). Prevents a mob from being slowed by another board's zone.
	var zones: Array = board.bonus_zones if board != null else get_tree().get_nodes_in_group("bonus_zones")
	for zone in zones:
		if zone.type != "slow":
			continue
		if zone.contains_world(position):
			slow_total += zone.magnitude
	var mult: float = maxf(GameConstants.MOB_SLOW_FLOOR, 1.0 - float(slow_total) / 100.0)
	return GameConstants.MOB_SPEED * mult

func take_hit(damage: float, is_crit: bool = false, source: Node2D = null) -> void:
	# Overkill doesn't count toward score: a 100-dmg hit on a 10-HP mob = 10.
	var credited := minf(damage, hp)
	hp -= damage
	_spawn_damage_number(damage, is_crit)
	if board != null:
		board._on_damage_dealt(credited)
	var killed := hp <= 0.0
	if source != null and is_instance_valid(source):
		source.register_damage(credited, killed)
	if killed:
		_explode_and_respawn()

func _spawn_damage_number(amount: float, is_crit: bool) -> void:
	if not bool(SaveData.get_setting("damage_numbers")):
		return
	# Only the board currently on screen spawns cosmetic FX. In PVP the other 7
	# boards sim invisibly; spawning their damage numbers / death poofs was pure
	# waste and the main FX load behind the fast-forward stalls.
	if not is_visible_in_tree():
		return
	var dn := DamageNumberScript.new()
	get_parent().add_child(dn)
	dn.setup(amount, is_crit, position)

# Per DESIGN: the mob never stops. It "explodes" (visual only) and instantly
# resets HP, continuing along the path without any pause in movement.
func _explode_and_respawn() -> void:
	# Cosmetic only — skip the death poof on off-screen boards (kept the gameplay
	# reset + kill credit below, which must run on every board regardless).
	if is_visible_in_tree():
		var fx := DeathFxScript.new()
		get_parent().add_child(fx)
		fx.setup(position, anim.rotation)
	hp = max_hp
	if board != null:
		board._on_mob_killed()
