extends Node2D

# Throwaway capture harness for the IN-MATCH render (verifies equipped skins land in a real
# match, not just the Collection preview). Equips a board, boots the real match scene
# (prototype.tscn → main.gd → MapLoader.build_match), and saves a settled frame. Restores the
# save after. Run WINDOWED (headless renders blank):
#   Godot.exe --path src res://tools/match_shot.tscn
# Override the board via the env var WEND_SHOT_BOARD (defaults to board_suburbia).

const DIR := "C:/dev/Maze Battle TD/"

var _saved

func _ready() -> void:
	var board_id := "board_suburbia"
	if OS.has_environment("WEND_SHOT_BOARD"):
		board_id = OS.get_environment("WEND_SHOT_BOARD")
	_saved = SaveData.data.get("cosmetics", {}).duplicate(true)
	SaveData.data["cosmetics"] = {
		"owned": [board_id, "tower_fire_crystal", "fx_gold_bolt"],
		"equipped": {"board": board_id, "tower": "tower_fire_crystal", "proj": "fx_gold_bolt"},
		"season_points": 0, "claimed_tiers": [],
	}
	# Boot the real match scene as a child so its camera frames the board for us.
	SceneManager.pending_map = load("res://campaign/mission_01.tres")
	SceneManager.pending_board_count = 1
	var proto = load("res://scenes/prototype.tscn").instantiate()
	add_child(proto)
	_capture.call_deferred()

func _capture() -> void:
	# Let the match build, then place a few towers on the local board so the body skin shows.
	await get_tree().create_timer(0.6).timeout
	var coord = SceneManager.active_coordinator
	if coord != null and not coord.boards.is_empty():
		var ctrl = coord.boards[0].build_controller
		for cell in [Vector2i(5, 3), Vector2i(7, 3), Vector2i(9, 3), Vector2i(6, 12), Vector2i(8, 12)]:
			ctrl._place_tower(cell)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "match_board_shot.png")
	print("SHOT match_board_shot.png")
	Engine.time_scale = 1.0
	SaveData.data["cosmetics"] = _saved
	SaveData.save()
	get_tree().quit()
