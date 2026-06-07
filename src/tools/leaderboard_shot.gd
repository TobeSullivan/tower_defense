extends Control

# Throwaway capture harness for the leaderboard browse screen. Sets a SAMPLE backend (so the
# board looks populated, like Nakama would) and screenshots each category. Run WINDOWED (not
# headless — headless renders blank): point run/main_scene here, or
#   Godot.exe --path src res://tools/leaderboard_shot.tscn
# Root is a Control filling the viewport so the Browse child's full-rect anchors + grass
# backdrop resolve against the screen (a Node2D root left them unsized).

const BrowseScript := preload("res://scripts/leaderboard_browse.gd")
const LeaderboardService := preload("res://scripts/leaderboard_service.gd")
const PveSelectScript := preload("res://scripts/pve_select.gd")
const MapResourceScript := preload("res://resources/map_resource.gd")

const OUT_DIR := "C:/dev/Maze Battle TD/"

var _browse

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	LeaderboardService.set_backend(SampleBackend.new())
	_browse = BrowseScript.new()
	add_child(_browse)
	_run.call_deferred()

func _run() -> void:
	await _settle()
	await _shot("leaderboard_trials.png")
	_browse._set_category(_browse.Cat.RANKED)
	await _settle()
	await _shot("leaderboard_ranked.png")
	_browse._set_category(_browse.Cat.CAMPAIGN)
	await _settle()
	await _shot("leaderboard_campaign.png")

	# Surface 4: the Trials-select cards (renamed Thread→Knot + inline rank). Seed a couple of
	# best scores IN MEMORY (no save() — never touches disk) so the rank chips show.
	_browse.queue_free()
	var today := LeaderboardService.window_date(MapResourceScript.WindowType.DAILY)
	SaveData.data.pve_best_scores["%s|1" % today] = 940100
	SaveData.data.pve_best_scores["%s|2" % today] = 1110400
	SaveData.data.pve_best_scores["%s|3" % today] = 1284500
	var select := PveSelectScript.new()
	add_child(select)
	await _settle()
	await _shot("leaderboard_select.png")
	get_tree().quit()

func _settle() -> void:
	for i in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR + name)
	print("SHOT ", name)

class SampleBackend extends RefCounted:
	func fetch_trials(_board_id: String, _my_score: int) -> Dictionary:
		return {"my_rank": 14, "entries": [
			{"rank": 1, "name": "apex_builder", "score": 2104900, "is_me": false},
			{"rank": 2, "name": "mazewright", "score": 1902330, "is_me": false},
			{"rank": 3, "name": "a_very_long_handle_that_truncates_here_indeed", "score": 1766010, "is_me": false},
			{"rank": 13, "name": "tower_of_pwr", "score": 1301880, "is_me": false},
			{"rank": 14, "name": "you", "score": 1284500, "is_me": true},
			{"rank": 15, "name": "creepkiller_99", "score": 1260140, "is_me": false},
		]}
	func fetch_trials_neighborhood(_board_id: String, _my_score: int, _radius: int) -> Dictionary:
		return {"rank": 14, "rows": []}
	func fetch_trials_rank(_board_id: String, _my_score: int) -> Dictionary:
		return {"rank": 14}
	func fetch_ranked(_season: int) -> Dictionary:
		return {
			"season_label": "Season 2 · live", "reset_text": "18 days left",
			"seasons": ["Season 2 · live", "Season 1"],
			"you": {"tier": "Gold", "lp": 77, "rank": 34, "total": 100, "to_next": 23, "next_tier": "Platinum"},
			"bands": [
				{"name": "Masters", "tag": "mas", "rows": [
					{"rank": 1, "name": "apex_builder", "tier": "Masters", "lp": 1840, "is_me": false},
					{"rank": 2, "name": "grid_goblin", "tier": "Masters", "lp": 1612, "is_me": false}]},
				{"name": "Platinum", "tag": "plat", "rows": [
					{"rank": 4, "name": "knotzero", "tier": "Platinum", "lp": 92, "is_me": false}]},
				{"name": "Gold", "tag": "gold", "rows": [
					{"rank": 33, "name": "mazewright", "tier": "Gold", "lp": 80, "is_me": false},
					{"rank": 34, "name": "you", "tier": "Gold", "lp": 77, "is_me": true},
					{"rank": 35, "name": "creepkiller_99", "tier": "Gold", "lp": 71, "is_me": false}]},
				{"name": "Silver", "tag": "sil", "rows": [
					{"rank": 47, "name": "weaver_jr", "tier": "Silver", "lp": 83, "is_me": false}]},
				{"name": "Bronze", "tag": "brz", "rows": [
					{"rank": 79, "name": "fresh_thread", "tier": "Bronze", "lp": 40, "is_me": false}]},
			]}
	func fetch_campaign(_mission: int) -> Dictionary:
		return {"my_score": 88000, "entries": [
			{"rank": 1, "name": "apex_builder", "score": 142000, "is_me": false},
			{"rank": 2, "name": "you", "score": 88000, "is_me": true},
			{"rank": 3, "name": "mazewright", "score": 71500, "is_me": false},
		]}
