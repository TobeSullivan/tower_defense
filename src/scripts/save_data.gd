extends Node

# SaveData autoload — persistent player state in a single JSON file under user://.
# Holds the first-launch flag and campaign medal records now; settings join in a
# later phase. Loaded once at startup; written through on every change.

const SAVE_PATH := "user://save.json"

# Windowed resolution presets (index stored in settings). Fullscreen ignores these.
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

const DEFAULT_SETTINGS := {
	"master_volume": 1.0,   # 0..1 linear
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"default_game_speed": 1,  # 1 / 2 / 3 — speed a match starts at
	"fullscreen": false,
	"resolution_index": 2,    # index into RESOLUTIONS
	"damage_numbers": true,
}

var data := {
	"first_launch_done": false,
	"campaign_medals": {},  # mission_index (as String) -> "bronze"/"silver"/"gold"
	"pve_best_scores": {},   # "window_date|tier" -> best score (local; no backend yet)
	"settings": {},          # backfilled from DEFAULT_SETTINGS on load
}

func _ready() -> void:
	_load()
	_ensure_setting_defaults()
	apply_audio()
	apply_display()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		# Merge so new default keys survive an old save file.
		for key in parsed:
			data[key] = parsed[key]

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveData: could not open %s for writing" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

# === First launch ===

func is_first_launch() -> bool:
	return not data.first_launch_done

func mark_first_launch_done() -> void:
	data.first_launch_done = true
	save()

# === Campaign medals ===

const _MEDAL_RANK := {"none": 0, "bronze": 1, "silver": 2, "gold": 3}

func best_medal(mission_index: int) -> String:
	return data.campaign_medals.get(str(mission_index), "none")

# Records a medal only if it beats the existing best for that mission.
func record_campaign_medal(mission_index: int, medal: String) -> void:
	if not _MEDAL_RANK.has(medal):
		return
	var key := str(mission_index)
	var current: String = data.campaign_medals.get(key, "none")
	if _MEDAL_RANK[medal] > _MEDAL_RANK[current]:
		data.campaign_medals[key] = medal
		save()

# === PVE local best scores (no leaderboard backend yet — personal best only) ===

func best_pve_score(window_date: String, tier: int) -> int:
	return int(data.pve_best_scores.get(_pve_key(window_date, tier), 0))

func record_pve_score(window_date: String, tier: int, score: int) -> void:
	var key := _pve_key(window_date, tier)
	if score > int(data.pve_best_scores.get(key, 0)):
		data.pve_best_scores[key] = score
		save()

func _pve_key(window_date: String, tier: int) -> String:
	return "%s|%d" % [window_date, tier]

# === Settings ===

func _ensure_setting_defaults() -> void:
	if typeof(data.get("settings")) != TYPE_DICTIONARY:
		data["settings"] = {}
	for key in DEFAULT_SETTINGS:
		if not data["settings"].has(key):
			data["settings"][key] = DEFAULT_SETTINGS[key]

func get_setting(key: String) -> Variant:
	return data["settings"].get(key, DEFAULT_SETTINGS.get(key))

# Updates the in-memory value and applies it live. Does NOT write to disk — call
# save() when the settings UI closes (avoids hammering disk during slider drags).
func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value

func resolution_labels() -> PackedStringArray:
	var out := PackedStringArray()
	for r in RESOLUTIONS:
		out.append("%d × %d" % [r.x, r.y])
	return out

func apply_audio() -> void:
	_set_bus_volume("Master", float(get_setting("master_volume")))
	_set_bus_volume("Music", float(get_setting("music_volume")))
	_set_bus_volume("SFX", float(get_setting("sfx_volume")))

# Only acts on buses that exist. No Music/SFX buses are defined yet (no audio in
# the prototype) — those calls are inert until an audio bus layout is added.
func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))

func apply_display() -> void:
	var fullscreen: bool = bool(get_setting("fullscreen"))
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var idx: int = clampi(int(get_setting("resolution_index")), 0, RESOLUTIONS.size() - 1)
		DisplayServer.window_set_size(RESOLUTIONS[idx])
