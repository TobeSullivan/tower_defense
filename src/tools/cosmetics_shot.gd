extends Control

# Throwaway capture harness for the Collection + Season screens. Seeds a believable
# mid-season save (tier 12, tiers 1-9 claimed, flair equipped), instances each real
# screen, and saves a settled frame of both. Restores the save after. Run WINDOWED
# (headless saves blank images):
#   Godot.exe --path . res://tools/cosmetics_shot.tscn

const Catalog := preload("res://scripts/cosmetics_catalog.gd")
const DIR := "C:/dev/Maze Battle TD/"

var _saved

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_saved = SaveData.data.get("cosmetics", {}).duplicate(true)
	var owned: Array = []
	for t in range(1, 10):
		for id in Catalog.tier_items(t):
			owned.append(id)
	SaveData.data["cosmetics"] = {
		"owned": owned,
		"equipped": {"title": "title_pathfinder", "frame": "frame_wood", "zone": "zone_teal"},
		"season_points": 12250,
		"claimed_tiers": range(1, 10),
	}
	_capture.call_deferred()

func _capture() -> void:
	var collection = load("res://scenes/collection.tscn").instantiate()
	add_child(collection)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "collection_shot.png")
	collection.queue_free()
	await get_tree().process_frame

	var season = load("res://scenes/season.tscn").instantiate()
	add_child(season)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "season_shot.png")
	print("SHOT collection_shot.png + season_shot.png")

	SaveData.data["cosmetics"] = _saved
	SaveData.save()
	get_tree().quit()
