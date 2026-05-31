extends AnimatedSprite2D
# One-shot death/explosion effect. Spawned at a mob's position when it's killed;
# plays once, then frees itself. Decoupled from the mob so the mob keeps moving.

const _DIE_FRAMES := 10

# One SpriteFrames shared by every death burst (built once). At high kill rates
# (one-shotting + respawns) this was allocating a fresh SpriteFrames per death.
static var _die_frames: SpriteFrames = null

func setup(world_pos: Vector2, rot: float) -> void:
	position = world_pos
	rotation = rot
	scale = Vector2(0.08, 0.08)
	z_index = 1  # above mobs so the burst reads on top
	sprite_frames = _shared_die_frames()
	animation_finished.connect(queue_free)
	play("die")

static func _shared_die_frames() -> SpriteFrames:
	if _die_frames != null:
		return _die_frames
	var frames := SpriteFrames.new()
	frames.add_animation("die")
	frames.set_animation_loop("die", false)
	frames.set_animation_speed("die", 24.0)  # fast burst
	for i in range(_DIE_FRAMES):
		var tex: Texture2D = load("res://assets/mobs/__zombie_01_die_%03d.png" % i)
		frames.add_frame("die", tex)
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_die_frames = frames
	return _die_frames
