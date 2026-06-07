extends Control

# Solo PVE map select (DESIGN_MODES "Navigation from PVE", solo path). Each time
# window — Daily / Weekly / Monthly — offers five curated seeded maps (Scale 1–5).
# Maps are seeded from the window's identity (today's date / this week / this
# month), so each set is stable for its window and rolls over when the window
# does, and the three windows never share a map. Local-only, no backend:
# leaderboards and group lobbies are still deferred; only a local best is shown.

const UiStyle := preload("res://scripts/ui_style.gd")
const StarRatingScript := preload("res://scripts/star_rating.gd")
const MapGen := preload("res://scripts/map_generator.gd")
const MapResourceScript := preload("res://resources/map_resource.gd")
const LeaderboardService := preload("res://scripts/leaderboard_service.gd")

# A distinct seed salt per window so Daily/Weekly/Monthly can never collide even
# if their identity hashes land near each other.
const WINDOW_SALT := {
	MapResourceScript.WindowType.DAILY: 0,
	MapResourceScript.WindowType.WEEKLY: 1_000_003,
	MapResourceScript.WindowType.MONTHLY: 2_000_003,
}
const WEEK_SECONDS := 604800.0  # 7 * 86400

var _windows: Dictionary = {}   # WindowType -> Array of 5 MapResources (Scale 1–5)
var _current: int = MapResourceScript.WindowType.DAILY

var _title: Label
var _subtitle: Label
var _list_box: VBoxContainer
var _tab_buttons: Dictionary = {}  # WindowType -> Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_generate_all_windows()
	_build_background()
	_build_header()
	_build_tabs()
	_build_list_container()
	_show_window(MapResourceScript.WindowType.DAILY)

# --- Window identity + generation ---

func _generate_all_windows() -> void:
	for wt in [MapResourceScript.WindowType.DAILY, MapResourceScript.WindowType.WEEKLY, MapResourceScript.WindowType.MONTHLY]:
		var meta: Dictionary = _window_meta(wt)
		var base: int = hash(meta.date) + int(WINDOW_SALT[wt])
		var maps: Array = []
		for tier in range(1, 6):
			var map_seed: int = base + tier * 1013
			maps.append(MapGen.generate(map_seed, tier, MapResourceScript.Mode.PVE, wt, meta.date))
		_windows[wt] = maps

# Returns {date, label, sub} for a window. `date` is the stable per-window key
# used for both seeding and local score storage, so the three never overlap.
func _window_meta(window_type: int) -> Dictionary:
	var d := Time.get_date_dict_from_system()
	match window_type:
		MapResourceScript.WindowType.WEEKLY:
			var week := int(Time.get_unix_time_from_system() / WEEK_SECONDS)
			return {"date": "%04d-W%03d" % [d.year, week % 1000], "label": "Weekly", "sub": "Five maps, Scale 1–5. New set each week."}
		MapResourceScript.WindowType.MONTHLY:
			return {"date": "%04d-%02d" % [d.year, d.month], "label": "Monthly", "sub": "Five maps, Scale 1–5. New set each month."}
		_:
			return {"date": "%04d-%02d-%02d" % [d.year, d.month, d.day], "label": "Daily", "sub": "Five maps, Scale 1–5. New set each day. Solo run for high score."}

# --- Layout ---

func _build_background() -> void:
	UiStyle.menu_backdrop(self)

func _build_header() -> void:
	_title = _label("Trials — Daily", 36, Color.WHITE)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_left = 40
	_title.offset_top = 28
	add_child(_title)

	_subtitle = _label("", 16, UiStyle.LABEL_COL)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_subtitle.offset_left = 40
	_subtitle.offset_top = 74
	add_child(_subtitle)

	var back := Button.new()
	back.text = "← Back"
	back.add_theme_font_size_override("font_size", 16)
	UiStyle.style_menu_button(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -150
	back.offset_top = 28
	back.offset_right = -40
	back.offset_bottom = 68
	back.pressed.connect(func(): SceneManager.goto_home())
	add_child(back)

func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = 40
	row.offset_top = 108
	add_child(row)

	for wt in [MapResourceScript.WindowType.DAILY, MapResourceScript.WindowType.WEEKLY, MapResourceScript.WindowType.MONTHLY]:
		var b := Button.new()
		b.toggle_mode = true
		b.text = _window_meta(wt).label
		b.custom_minimum_size = Vector2(130, 40)
		b.add_theme_font_size_override("font_size", 16)
		UiStyle.style_tab_button(b)
		b.pressed.connect(func(): _show_window(wt))
		row.add_child(b)
		_tab_buttons[wt] = b

func _build_list_container() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 60  # nudge below the tab bar
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 12)
	center.add_child(_list_box)

# --- Window switching ---

func _show_window(window_type: int) -> void:
	_current = window_type
	var meta: Dictionary = _window_meta(window_type)
	_title.text = "Trials — %s" % meta.label
	_subtitle.text = meta.sub
	for wt in _tab_buttons:
		_tab_buttons[wt].button_pressed = (wt == window_type)

	for child in _list_box.get_children():
		child.queue_free()
	for map in _windows[window_type]:
		_list_box.add_child(await _map_card(map))

func _map_card(map) -> Control:
	var tier: int = map.scale_tier
	# Best + live rank for this map's board (rank 0 = unplayed). Offline the LocalBackend
	# reports rank 1 once you've posted a score; Nakama returns the real global rank later.
	var rinfo: Dictionary = await LeaderboardService.trials_rank(_current, tier)
	var best: int = int(rinfo.get("best", 0))
	var rank: int = int(rinfo.get("rank", 0))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	UiStyle.apply_card(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	info.add_child(_label(LeaderboardService.scale_name(tier), 22, _tier_color(tier)))
	info.add_child(_label("Rounds %d   ·   Supply %d   ·   Checkpoints %d   ·   Zones %d   ·   Mobs %d" % [
		map.round_count, map.supply_cap, map.checkpoint_cells.size(), map.bonus_zones.size(), map.mob_count], 14, UiStyle.LABEL_COL))

	# Best score with a gold star (em-dash + no star if unplayed).
	var best_row := HBoxContainer.new()
	best_row.add_theme_constant_override("separation", 6)
	if best > 0:
		var star = StarRatingScript.new()
		star.configure(1, 1, 16.0)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		best_row.add_child(star)
	best_row.add_child(_label("Best: %d" % best if best > 0 else "Best: —", 14, Color(1.0, 0.9, 0.5)))
	info.add_child(best_row)

	# Inline live rank — both informs and is the tap target into the board for this scale +
	# window (notes/leaderboard_ui_spec.md Surface 4). Em-dash text when unplayed.
	if rank > 0:
		var rank_btn := Button.new()
		rank_btn.text = "#%d  ›" % rank
		rank_btn.add_theme_font_size_override("font_size", 14)
		rank_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		UiStyle.style_flat_button(rank_btn, UiStyle.CHIP_BG, 12, UiStyle.CHIP_BORDER, 2, false, 12, 5)
		rank_btn.add_theme_color_override("font_color", Color("bfe6a3"))
		rank_btn.pressed.connect(func(): SceneManager.goto_leaderboards(
			{"category": 0, "window": _current, "tier": tier, "group": "solo"}))
		info.add_child(rank_btn)
	else:
		info.add_child(_label("unplayed", 12, UiStyle.LABEL_COL))

	var play := Button.new()
	play.text = "Play"
	play.custom_minimum_size = Vector2(120, 52)
	play.add_theme_font_size_override("font_size", 18)
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.style_go_button(play)
	play.pressed.connect(func(): SceneManager.start_pve_map(map))
	row.add_child(play)

	return panel

func _tier_color(tier: int) -> Color:
	# Cool (easy) to warm (hard) across Scale 1–5.
	return Color(0.45, 0.85, 0.5).lerp(Color(1.0, 0.45, 0.35), (tier - 1) / 4.0)

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
