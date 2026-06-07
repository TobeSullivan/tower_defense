extends Node2D
class_name Projectile

const SPEED := 900.0  # pixels/sec
const ARROW_TEX := preload("res://assets/towers/arrow.png")

var target  # the Mob this is chasing — untyped (duck-typed .alive/.position/.take_hit)
var damage: float = 0.0
var is_crit: bool = false
var source_tower: Node2D = null  # who fired this — credited with damage/kills on hit

var sprite: Sprite2D

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = ARROW_TEX
	if is_crit:
		sprite.scale = Vector2(0.32, 0.32)
		sprite.modulate = Color(1.6, 1.3, 0.4, 1.0)  # gold tint
	else:
		sprite.scale = Vector2(0.22, 0.22)
	add_child(sprite)

# Driven by BoardState.sim_step on the fixed sim tick (no longer self-_process'd).
# Returns true when finished (landed a hit, or the target left/was freed) — the
# board then removes it from the projectiles array and frees the node. The target's
# `alive` flag is set SYNCHRONOUSLY when a mob exits, so a multi-tick frame never
# resolves a hit on a mob that already despawned (queue_free defers to frame end).
func sim_step(delta: float) -> bool:
	if target == null or not is_instance_valid(target) or not target.alive:
		return true

	var to_target: Vector2 = target.position - position
	var dist: float = to_target.length()
	var step := SPEED * delta

	# Arrow native facing is west (head points -X); add PI so head leads.
	sprite.rotation = to_target.angle() + PI

	if step >= dist:
		if target.has_method("take_hit"):
			target.take_hit(damage, is_crit, source_tower)
		return true
	position += to_target.normalized() * step
	return false
