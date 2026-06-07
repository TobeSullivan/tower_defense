extends Node2D

# Determinism + re-sim round-trip regression harness (resim_contract.md §4/§5).
# Plays a real headless match while RECORDING the tick-tagged input log (towers
# placed across multiple rounds), then RE-SIMS the captured record from the seed and
# asserts the re-sim's score equals the live score — the keystone property of the
# contract (the leaderboard number is the re-sim's, and it must match honest play).
# Drive via a temporary run/main_scene = tools/sim_harness.tscn (revert after).
# Autoloads (GameConstants/SaveData) ARE available in main_scene mode.
# Last verified 2026-06-07: live score == re-sim score, 0 errors, 13-round match.

const MapLoaderScript := preload("res://scripts/map_loader.gd")
const MapGen := preload("res://scripts/map_generator.gd")
const MapResourceScript := preload("res://resources/map_resource.gd")
const GridScript := preload("res://scripts/grid.gd")
const ResimScript := preload("res://scripts/resim.gd")

const MAP_SEED := 777
const TICK_CAP := 200000

func _ready() -> void:
	# ---- LIVE match (records its own input log) ----
	var map = MapGen.generate(MAP_SEED, 1, MapResourceScript.Mode.PVE)
	var live_host := Node2D.new()
	add_child(live_host)
	var boards: Array = MapLoaderScript.build_match(live_host, map, 1, -1, false)
	var board = boards[0]
	var coord = board.coordinator
	coord.set_process(false)        # drive ticks here, not the frame accumulator
	live_host.visible = false       # skip cosmetic FX

	var ctrl = board.build_controller
	# Round-1 build (tick 0): place a batch + upgrade some for crit.
	var placed := _place_flanking(ctrl, 10, [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)])
	for i in range(mini(6, ctrl.towers.size())):
		var t = ctrl.towers[i]
		for _k in range(3):
			t.upgrade("crit_chance")
		for _k in range(2):
			t.upgrade("damage")
	print("HARNESS LIVE seed=", map.seed, " grid=", map.grid_size,
		" rounds=", map.round_count, " mob_count=", map.mob_count, " towers=", placed)

	# Natural build-timer expiry (no request_start_now) so the build→run auto-transition
	# is exercised. During round 2's build phase, place 2 MORE towers — proves the record
	# captures actions across rounds at non-zero ticks, not just the opening batch.
	var ticks := 0
	var added_r2 := false
	while ticks < TICK_CAP and not coord.match_over:
		coord._sim_tick_once()
		ticks += 1
		if not added_r2 and coord.round_num == 2 and coord.phase == "build":
			var extra := _place_flanking(ctrl, 2, [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)])
			added_r2 = true
			print("  round 2 build @tick ", coord.sim_tick, ": placed ", extra, " more")

	var live_dmg: int = board.total_damage_dealt
	var live_kills: int = board.total_kills
	var record: Dictionary = coord.make_record()
	print("HARNESS LIVE DONE round=", coord.round_num, " dmg=", live_dmg,
		" kills=", live_kills, " ticks=", ticks, " log_actions=", record["input_log"].size())

	# ---- RE-SIM the captured record from scratch ----
	var resim_host := Node2D.new()
	add_child(resim_host)
	var res: Dictionary = ResimScript.run(resim_host, record)
	var rb: Dictionary = res["boards"][0]
	print("HARNESS RESIM over=", res["over"], " round=", res["final_round"],
		" dmg=", rb["damage"], " kills=", rb["kills"],
		" applied=", res["applied"], "/", res["log_size"], " sim_tick=", res["sim_tick"])

	# ---- VERDICT ----
	var ok: bool = res["over"] and rb["damage"] == live_dmg and rb["kills"] == live_kills \
		and res["applied"] == record["input_log"].size()
	if ok:
		print("RESULT ✅ ROUND-TRIP OK — re-sim score == live score (dmg=", live_dmg, " kills=", live_kills, ")")
	else:
		print("RESULT ❌ MISMATCH — live(dmg=", live_dmg, " kills=", live_kills,
			") vs resim(dmg=", rb["damage"], " kills=", rb["kills"], ")")
	get_tree().quit()

# Place up to max_n towers on cells flanking the mob path (guaranteed in range so they
# fire). Deterministic: fixed path order, fixed offset order. Returns count placed.
func _place_flanking(ctrl, max_n: int, offsets: Array) -> int:
	var path: PackedVector2Array = ctrl.current_path_world()
	var placed := 0
	for i in range(path.size()):
		var cell := GridScript.world_to_cell(path[i])
		for off in offsets:
			if placed >= max_n:
				return placed
			if ctrl.bot_place_tower(cell + off):
				placed += 1
	return placed
