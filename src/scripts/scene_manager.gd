extends Node

# SceneManager autoload — owns navigation between screens and carries the chosen
# MapResource into the match scene. The match scene reads `pending_map` in its
# _ready; the loader does the rest. All in-match exits route back to the home
# screen through here (DESIGN_MODES: "no intermediate screen between any in-match
# exit and the home screen").

const MapResourceScript := preload("res://resources/map_resource.gd")

const HOME_SCENE := "res://scenes/home_screen.tscn"
const CAMPAIGN_SELECT_SCENE := "res://scenes/campaign_select.tscn"
const PVE_SELECT_SCENE := "res://scenes/pve_select.tscn"
const MATCH_SCENE := "res://scenes/prototype.tscn"

# Authored campaign missions, by mission index. All 10 are authored — a tutorial
# curriculum where each mission isolates one decision on a rising curve (see the
# Campaign curriculum table in DESIGN_MODES.md).
const CAMPAIGN_MISSIONS := {
	1: "res://campaign/mission_01.tres",
	2: "res://campaign/mission_02.tres",
	3: "res://campaign/mission_03.tres",
	4: "res://campaign/mission_04.tres",
	5: "res://campaign/mission_05.tres",
	6: "res://campaign/mission_06.tres",
	7: "res://campaign/mission_07.tres",
	8: "res://campaign/mission_08.tres",
	9: "res://campaign/mission_09.tres",
	10: "res://campaign/mission_10.tres",
}
const CAMPAIGN_MISSION_COUNT := 10  # design cap; only authored entries are playable

# Set before a scene change; consumed by the match scene.
var pending_map = null
# Drives the pause-menu variant (single-player pauses the tree; multiplayer does
# not). Campaign and solo PVE are single-player.
var current_is_multiplayer := false

func goto_home() -> void:
	pending_map = null
	get_tree().paused = false
	Engine.time_scale = 1.0  # menus always run at normal speed
	get_tree().change_scene_to_file(HOME_SCENE)

func goto_campaign_select() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(CAMPAIGN_SELECT_SCENE)

func goto_pve_select() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(PVE_SELECT_SCENE)

# Solo PVE: a generated map played for score. Single-player for pause purposes.
func start_pve_map(map) -> void:
	pending_map = map
	current_is_multiplayer = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MATCH_SCENE)

func has_campaign_mission(index: int) -> bool:
	return CAMPAIGN_MISSIONS.has(index)

func start_campaign_mission(index: int) -> void:
	if not CAMPAIGN_MISSIONS.has(index):
		push_warning("SceneManager: campaign mission %d is not authored" % index)
		return
	pending_map = load(CAMPAIGN_MISSIONS[index])
	current_is_multiplayer = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MATCH_SCENE)

func restart_current_match() -> void:
	# pending_map is still set; reloading the match scene re-runs the loader on it.
	get_tree().paused = false
	get_tree().reload_current_scene()

# Records the result for the current map (campaign medal or PVE score). Storage is
# best-kept, so calling this with a partial score is always safe — a partial can
# never beat a full run. PVP records nothing (last-standing, no medals/score).
func report_match_result(damage: int) -> void:
	if pending_map == null:
		return
	if pending_map.mode == MapResourceScript.Mode.CAMPAIGN and pending_map.mission_index > 0:
		SaveData.record_campaign_medal(pending_map.mission_index, _medal_for(damage))
	elif pending_map.mode == MapResourceScript.Mode.PVE:
		SaveData.record_pve_score(pending_map.window_date, pending_map.scale_tier, damage)

func _medal_for(damage: int) -> String:
	if pending_map == null:
		return "none"
	if damage >= pending_map.gold_threshold:
		return "gold"
	if damage >= pending_map.silver_threshold:
		return "silver"
	if damage >= pending_map.bronze_threshold:
		return "bronze"
	return "none"

# Bow out mid-match: record the (possibly partial) result, then go home. Used by
# the gold-reached popup and the pause-menu quit. Partial scores count by design.
func leave_match_to_home(damage: int) -> void:
	report_match_result(damage)
	goto_home()
