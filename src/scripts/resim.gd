extends Node

# Authoritative re-sim runner (resim_contract.md §1, §3, §4, §7).
#
# Replays a match record headlessly and derives the TRUE result by re-running the
# exact same deterministic sim from the same seed. This is the number that gets
# written to a leaderboard / ladder — never the client-claimed one. Because the sim
# is deterministic (fixed tick + seeded RNG, see match_coordinator.gd) and build
# actions are build-phase-only, replaying the seed + tick-tagged input log
# reproduces the match exactly.
#
# Stateless: call Resim.run(host, record). `host` is a Node already in the tree to
# build the throwaway match under (free it after reading the result).

const MapLoaderScript := preload("res://scripts/map_loader.gd")
const MapGen := preload("res://scripts/map_generator.gd")
const MapResourceScript := preload("res://resources/map_resource.gd")

# Replay `record` under `host` and return the derived result:
#   { over, final_round, sim_tick, applied, log_size, boards:[{damage,kills}, ...] }
static func run(host: Node2D, record: Dictionary) -> Dictionary:
	var map = _rebuild_map(record["map_ref"])
	var num_boards: int = int(record.get("players", 1))
	var boards: Array = MapLoaderScript.build_match(host, map, num_boards, -1, false)
	var coord = boards[0].coordinator
	coord.record_enabled = false   # replay must not re-log
	coord.set_process(false)       # we drive ticks here, not the frame accumulator
	coord.sim_seed = int(record["seed"])
	coord.rng.seed = int(record["seed"])
	host.visible = false           # skip cosmetic FX during the headless replay

	var log: Array = record["input_log"]
	var idx := 0
	# Pre-run actions (tick 0): applied before the first tick advances.
	while idx < log.size() and int(log[idx]["tick"]) <= 0:
		_apply(boards, log[idx])
		idx += 1
	var cap := 2000000
	while not coord.match_over and coord.sim_tick < cap:
		coord._sim_tick_once()
		# Apply every action stamped for the tick we just completed, in log order.
		while idx < log.size() and int(log[idx]["tick"]) == coord.sim_tick:
			_apply(boards, log[idx])
			idx += 1

	var per_board: Array = []
	for b in boards:
		per_board.append({"damage": b.total_damage_dealt, "kills": b.total_kills})
	return {
		"over": coord.match_over,
		"final_round": coord.round_num,
		"sim_tick": coord.sim_tick,
		"applied": idx,
		"log_size": log.size(),
		"boards": per_board,
	}

static func _rebuild_map(mr: Dictionary):
	if String(mr.get("kind", "")) == "authored":
		# Authored campaign map: reload the same mission .tres (version-tagged in the record).
		return load("res://campaign/mission_%02d.tres" % int(mr["mission_index"]))
	# Generated map: map_generator is fully deterministic from the seed (§2.1).
	return MapGen.generate(int(mr["seed"]), int(mr["scale_tier"]), int(mr["mode"]),
		int(mr.get("window_type", 0)), String(mr.get("window_date", "")))

# Apply one logged action through the SAME board entry points the live match used, so
# the economy (cost/refund) and placement validation replay identically.
static func _apply(boards: Array, entry: Dictionary) -> void:
	var seat: int = int(entry["seat"])
	if seat < 0 or seat >= boards.size():
		return
	var board = boards[seat]
	var bc = board.build_controller
	var a: Dictionary = entry["action"]
	match String(a["type"]):
		"place":
			bc.bot_place_tower(a["cell"])
		"sell":
			bc._sell_tower_at_cell(a["cell"])
		"upgrade":
			var t = bc._tower_at_cell(a["cell"])
			if t != null:
				board.spend(t.upgrade_cost(a["stat"]))
				t.upgrade(a["stat"])
		"start":
			board.coordinator.request_start_now()
		"vote_start":
			board.coordinator.set_board_ready(board, bool(a["value"]))
