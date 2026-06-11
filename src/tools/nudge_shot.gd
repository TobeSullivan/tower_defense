extends Control
# Throwaway: render the season-XP nudge chip on the match-end panel.
const DIR := "C:/dev/Maze Battle TD/"
const PanelScript := preload("res://scripts/match_end_panel.gd")
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneManager.last_task_award = {"points": 360, "completed": [
		{"cadence": "daily", "shape": "kills"},
		{"cadence": "daily", "shape": "games"},
		{"cadence": "weekly", "shape": "towers"},
	]}
	var p = PanelScript.new()
	add_child(p)
	_shot.call_deferred(p)
func _shot(p) -> void:
	await get_tree().process_frame
	p._title_label.text = "Match Complete"
	p._result_label.text = "Two stars"
	p._detail_label.text = "Total damage: 67,903"
	p._scrim.visible = true
	p._show_season_award()
	p._set_buttons([{"text": "Play Again", "cb": Callable(), "role": "go"}, {"text": "Return Home", "cb": Callable()}])
	p._panel.visible = true
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "nudge_shot.png")
	print("SHOT nudge_shot.png")
	get_tree().quit()
