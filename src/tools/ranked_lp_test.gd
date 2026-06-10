extends Node

# Ranked LP / MMR engine + Surface 2 verification (notes/pvp_ladder.md + leaderboard_ui_spec.md §2).
# PASS 1: RankedLadder.resolve — base table (count 8 + percentile N<8), MMR factor amplify/dampen,
#         promotion, demotion buffer, Bronze floor, Masters no-demote-out + uncapped, MMR direction.
# PASS 2: Surface 2 builds against a fake match (LP block + final-order rows) and persists the value.
# Drive headlessly: godot --headless --path src res://tools/ranked_lp_test.tscn
# (Screenshots are a separate windowed harness, res://tools/ranked_shot.tscn — headless renders blank.)

const RankedLadder := preload("res://scripts/ranked_ladder.gd")
const LeaderboardService := preload("res://scripts/leaderboard_service.gd")
const MatchEndPanelScript := preload("res://scripts/match_end_panel.gd")

var _fails := 0

func _ready() -> void:
	_test_base_table()
	_test_percentile()
	_test_mmr_factor()
	_test_boundaries()
	_test_mmr_update()
	await _test_surface2()
	if _fails == 0:
		print("RESULT ✅ RANKED LP OK (engine + Surface 2)")
	else:
		print("RESULT ❌ RANKED LP FAILED — ", _fails, " check(s) above")
	get_tree().quit(_fails)

func _check(label: String, got, want) -> void:
	if got != want:
		_fails += 1
		print("  ❌ %s — got %s, want %s" % [label, str(got), str(want)])

func _check_true(label: String, cond: bool) -> void:
	_check(label, cond, true)

# --- PASS 1: engine -----------------------------------------------------------

# At equilibrium (mmr == lobby avg → factor 1.0) the earned LP is exactly the base table.
func _test_base_table() -> void:
	var v := 250  # Gold 50 (not Masters): clear of every boundary so earned == value change
	for row in [[1, 45], [2, 30], [3, 18], [4, 8], [5, -8], [6, -18], [7, -30], [8, -45]]:
		var r := RankedLadder.resolve(int(row[0]), 8, v, 200.0, 200.0)
		_check("base LP place %d of 8" % int(row[0]), int(r["earned"]), int(row[1]))
		_check("net move place %d of 8" % int(row[0]), int(r["lp_delta"]), int(row[1]))

# A smaller lobby percentile-maps onto the curve: 1st always +45, last always −45.
func _test_percentile() -> void:
	for n in [4, 6, 2]:
		_check("1st of %d = +45" % n, RankedLadder.base_lp(1, n), 45)
		_check("last of %d = −45" % n, RankedLadder.base_lp(n, n), -45)
	# 2nd of 4 lands between the 3rd/4th rungs of the 8-curve (≈ +15), still positive.
	_check_true("2nd of 4 is a modest gain", RankedLadder.base_lp(2, 4) > 0 and RankedLadder.base_lp(2, 4) < 45)

func _test_mmr_factor() -> void:
	# Below your skill (lobby avg well above you): gains amplified, losses dampened.
	var below_win := RankedLadder.resolve(1, 8, 50, 100.0, 300.0)  # deficit +200 → factor 1.5
	_check("below-skill 1st amplified (45→68)", int(below_win["earned"]), 68)
	var below_loss := RankedLadder.resolve(8, 8, 250, 100.0, 300.0)  # loss dampened → factor 0.5
	_check("below-skill 8th dampened (−45→−23)", int(below_loss["earned"]), -23)
	# Above your skill (you above the lobby): gains dampened, losses amplified (Masters integrity).
	var above_win := RankedLadder.resolve(1, 8, 250, 300.0, 100.0)  # factor 0.5
	_check("above-skill 1st dampened (45→23)", int(above_win["earned"]), 23)
	var above_loss := RankedLadder.resolve(8, 8, 250, 300.0, 100.0)  # factor 1.5
	_check("above-skill 8th amplified (−45→−68)", int(above_loss["earned"]), -68)

func _test_boundaries() -> void:
	# Promotion: Bronze 95 + 45 → Silver 40.
	var promo := RankedLadder.resolve(1, 8, 95, 200.0, 200.0)
	_check("promo value", int(promo["value_after"]), 140)
	_check("promo tier", String(promo["tier_after"]), "Silver")
	_check("promo lp_after", int(promo["lp_after"]), 40)
	_check_true("promoted flag", bool(promo["promoted"]))
	# Demotion buffer: Silver 0 (100) loses → lands at Bronze 75 (75), not the raw value.
	var demo := RankedLadder.resolve(8, 8, 100, 200.0, 200.0)
	_check("demote landing = Bronze 75", int(demo["value_after"]), 75)
	_check("demote tier", String(demo["tier_after"]), "Bronze")
	_check("demote lp_after", int(demo["lp_after"]), 75)
	_check_true("demoted flag", bool(demo["demoted"]))
	# Bronze floor: can't fall below 0.
	var floor_r := RankedLadder.resolve(8, 8, 10, 200.0, 200.0)
	_check("Bronze floors at 0", int(floor_r["value_after"]), 0)
	_check_true("Bronze floor not flagged a demotion", not bool(floor_r["demoted"]))
	# Masters: no demotion out mid-season (floors at 400), gains uncapped.
	var mas_loss := RankedLadder.resolve(8, 8, 410, 300.0, 300.0)
	_check("Masters no demote out (floor 400)", int(mas_loss["value_after"]), 400)
	_check_true("still Masters after a loss", bool(mas_loss["is_masters"]))
	var mas_win := RankedLadder.resolve(1, 8, 410, 300.0, 300.0)
	_check("Masters uncapped gain", int(mas_win["value_after"]), 455)
	_check("Masters lp_after over base", int(mas_win["lp_after"]), 55)

func _test_mmr_update() -> void:
	# 1st climbs hidden MMR; last drops it (Elo by placement vs the field).
	var win := RankedLadder.resolve(1, 8, 250, 200.0, 200.0)
	_check_true("1st raises MMR", float(win["mmr_after"]) > 200.0)
	var lose := RankedLadder.resolve(8, 8, 250, 200.0, 200.0)
	_check_true("8th lowers MMR", float(lose["mmr_after"]) < 200.0)

# --- PASS 2: Surface 2 render + persistence -----------------------------------

func _test_surface2() -> void:
	LeaderboardService.set_backend(LeaderboardService.LocalBackend.new())  # offline: submit is a no-op
	# Known pre-match state: Gold 50, MMR == lobby avg (factor 1.0).
	var saved = SaveData.data.get("ranked", {}).duplicate(true)
	# Seed on the build's season — any other season is (correctly) reset to fresh by _ranked().
	SaveData.data["ranked"] = {"season": SaveData.BUILD_SEASON, "value": 250, "mmr": 200.0}
	SceneManager.pending_ranked_avg_mmr = 200.0

	var coord := FakeCoord.new()
	add_child(coord)
	var local = coord.setup(8, 2)  # 8 boards, local finishes 2nd
	var panel = MatchEndPanelScript.new()
	panel.round_manager = local
	panel.ranked = true
	add_child(panel)   # _ready connects signals
	local.emit_signal("match_ended")
	await get_tree().process_frame

	_check_true("Surface 2 panel visible", panel._panel.visible)
	_check_true("LP block + final order populated", panel._lb_vbox.get_child_count() >= 10)
	# Persisted the new authoritative ladder value (Gold 50 + 30 for 2nd = Gold 80 = 280).
	_check("ranked value persisted (2nd of 8)", SaveData.ranked_value(), 280)

	panel.queue_free()
	coord.queue_free()
	SaveData.data["ranked"] = saved  # restore (avoid leaking test state into the save file)
	SaveData.save()

# --- Minimal match fakes (the panel only needs placement + names + elimination) ---

class FakeBoard extends Node:
	signal match_ended
	var coordinator
	var eliminated := false

class FakeCoord extends Node:
	signal board_eliminated(board)
	var is_pvp := true
	var match_over := true
	var boards: Array = []
	var board_names: Array = []
	var finish_order: Array = []  # worst-first (placement_of = boards.size() - index)

	# Build `count` boards; board at seat (local_place-1) becomes the local board finishing
	# `local_place`. Bottom-half boards are flagged eliminated. Returns the local board.
	func setup(count: int, local_place: int):
		var local = null
		for i in range(count):
			var b := FakeBoard.new()
			b.coordinator = self
			b.eliminated = (i + 1) > int(ceil(count / 2.0))  # places 5–8 of 8 were knocked out
			boards.append(b)
			board_names.append("you" if (i + 1) == local_place else "rival_%d" % (i + 1))
			add_child(b)
			if (i + 1) == local_place:
				local = b
		# finish_order worst-first: seat i has placement i+1, so index = count-(i+1).
		finish_order.resize(count)
		for i in range(count):
			finish_order[count - (i + 1)] = boards[i]
		return local

	func placement_of(board) -> int:
		var idx := finish_order.find(board)
		return boards.size() - idx if idx >= 0 else 0

	func name_for(board) -> String:
		var i := boards.find(board)
		return String(board_names[i]) if i >= 0 and i < board_names.size() else "—"
