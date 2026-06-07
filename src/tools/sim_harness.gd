extends Node2D

# Determinism / smoke regression harness for the fixed-tick sim (resim_contract.md §5).
# Builds a real headless match (no UI, no bot), places towers hugging the path,
# then drives the sim by TICKS directly — set_process(false) on the coordinator and
# manual _sim_tick_once() calls — so a run is exactly N ticks and fully reproducible.
# Run it twice and diff the output: identical => fixed tick + seeded RNG are
# deterministic. Drive via a temporary run/main_scene = tools/sim_harness.tscn (revert after).
# Autoloads (GameConstants/SaveData) ARE available in main_scene mode.
# Last verified 2026-06-07: 2 runs byte-identical, 0 errors, match completes 13 rounds.

const MapLoaderScript := preload("res://scripts/map_loader.gd")
const MapGen := preload("res://scripts/map_generator.gd")
const MapResourceScript := preload("res://resources/map_resource.gd")
const GridScript := preload("res://scripts/grid.gd")

const MAP_SEED := 777
const SIM_SEED := 777
const MAX_TOWERS := 30
const TICK_CAP := 200000

func _ready() -> void:
	var map = MapGen.generate(MAP_SEED, 1, MapResourceScript.Mode.PVE)
	# local_index = -1, use_bots = false → headless board with no UI and no AI; I own it.
	var boards: Array = MapLoaderScript.build_match(self, map, 1, -1, false)
	var board = boards[0]
	var coord = board.coordinator
	coord.set_process(false)           # I drive ticks here, not the frame accumulator
	coord.rng.seed = SIM_SEED          # deterministic crit stream
	board.get_parent().visible = false # hide the board so cosmetic FX (damage numbers / death poofs) skip — pure sim

	var ctrl = board.build_controller
	var placed := _place_towers(ctrl)
	_upgrade_some(ctrl)
	print("HARNESS seed=", map.seed, " grid=", map.grid_size,
		" rounds=", map.round_count, " mob_count=", map.mob_count, " towers=", placed)

	# Drive raw ticks and let the build timer EXPIRE NATURALLY (no request_start_now),
	# so the build→run auto-transition (build_ticks_left countdown) is exercised too.
	var ticks := 0
	var last_round: int = coord.round_num
	var saw_run := false
	while ticks < TICK_CAP and not coord.match_over:
		coord._sim_tick_once()
		ticks += 1
		if coord.phase == "run":
			saw_run = true
		if coord.round_num != last_round:
			last_round = coord.round_num
			print("  round ", last_round, " dmg=", board.total_damage_dealt,
				" kills=", board.total_kills, " tick=", coord.sim_tick)

	print("HARNESS DONE over=", coord.match_over, " final_round=", coord.round_num,
		" dmg=", board.total_damage_dealt, " kills=", board.total_kills,
		" ticks=", ticks, " sim_tick=", coord.sim_tick, " saw_run=", saw_run)
	get_tree().quit()

# Place towers on the cells immediately flanking the mob path, so they're guaranteed
# in range and actually fire. Deterministic (fixed path order, fixed offset order).
func _place_towers(ctrl) -> int:
	var path: PackedVector2Array = ctrl.current_path_world()
	var offsets := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var placed := 0
	for i in range(path.size()):
		var cell := GridScript.world_to_cell(path[i])
		for off in offsets:
			if placed >= MAX_TOWERS:
				return placed
			if ctrl.bot_place_tower(cell + off):
				placed += 1
	return placed

# Give the first few towers crit + damage tiers so the seeded crit RNG is exercised.
func _upgrade_some(ctrl) -> void:
	for i in range(mini(6, ctrl.towers.size())):
		var t = ctrl.towers[i]
		for _k in range(3):
			t.upgrade("crit_chance")
		for _k in range(2):
			t.upgrade("damage")
