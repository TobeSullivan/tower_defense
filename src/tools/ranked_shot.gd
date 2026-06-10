extends Control

# Windowed capture harness for Surface 2 (the Ranked post-match result screen). Reproduces the
# mockup case: 2nd of 8, Silver 47 → 77, +30 LP, 23 LP to Gold. Run WINDOWED (headless renders
# blank):  Godot.exe --path src res://tools/ranked_shot.tscn
# Sets the ranked state IN MEMORY only (no save()).

const UiStyle := preload("res://scripts/ui_style.gd")
const MatchEndPanelScript := preload("res://scripts/match_end_panel.gd")

const OUT_DIR := "C:/dev/Maze Battle TD/"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.menu_backdrop(self)
	# Silver 47 going in → +30 for 2nd → Silver 77, 23 LP to Gold (factor 1.0: mmr == lobby avg).
	SaveData.data["ranked"] = {"season": 1, "value": 247, "mmr": 200.0}
	SceneManager.pending_ranked_avg_mmr = 200.0

	var coord := FakeCoord.new()
	add_child(coord)
	var local = coord.setup(8, 2)
	var panel = MatchEndPanelScript.new()
	panel.round_manager = local
	panel.ranked = true
	add_child(panel)
	local.emit_signal("match_ended")
	_run.call_deferred()

func _run() -> void:
	# Mid-climb: the LP bar is filling, order rows arriving (~0.35s).
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "ranked_mid.png")
	# Settled: bar at the final LP, rows in.
	await get_tree().create_timer(1.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "ranked_settled.png")
	print("SHOT ranked_mid.png + ranked_settled.png")
	get_tree().quit()

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
	var finish_order: Array = []
	const NAMES := ["apex_builder", "you", "a_very_long_handle_that_truncates", "knotzero",
		"mazewright", "grid_goblin", "weaver_jr", "earlyquit"]

	func setup(count: int, local_place: int):
		var local = null
		for i in range(count):
			var b := FakeBoard.new()
			b.coordinator = self
			b.eliminated = (i + 1) > int(ceil(count / 2.0))
			boards.append(b)
			board_names.append(NAMES[i] if i < NAMES.size() else "rival_%d" % (i + 1))
			add_child(b)
			if (i + 1) == local_place:
				local = b
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
