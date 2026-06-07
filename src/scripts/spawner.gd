extends Node2D
class_name Spawner

const MobScript := preload("res://scripts/mob.gd")

var mobs_array: Array  # shared reference with tower(s) + round_manager
var board  # BoardState (round_manager) — injected into each mob it spawns

var _mob_count: int = 0
var _spawn_interval: float = 1.0
var _mob_hp: float = 100.0
var _wave_path: PackedVector2Array
var _spawned: int = 0
var _timer: float = 0.0
var _active: bool = false

func start_wave(mob_count: int, spawn_interval: float, mob_hp: float, wave_path: PackedVector2Array) -> void:
	_mob_count = mob_count
	_spawn_interval = spawn_interval
	_mob_hp = mob_hp
	_wave_path = wave_path
	_spawned = 0
	_timer = 0.0
	_active = true

func is_done() -> bool:
	return _spawned >= _mob_count and not _active

# Driven by BoardState.sim_step on the fixed sim tick (no longer self-_process'd),
# so spawn timing is framerate-independent and reproducible by the re-sim.
func sim_step(delta: float) -> void:
	if not _active:
		return
	if _spawned >= _mob_count:
		_active = false
		return
	_timer -= delta
	if _timer <= 0.0:
		_spawn_one()
		_timer = _spawn_interval

func _spawn_one() -> void:
	var mob := MobScript.new()
	mob.path = _wave_path
	mob.max_hp = _mob_hp
	mob.board = board
	mobs_array.append(mob)
	get_parent().add_child(mob)
	_spawned += 1
