extends Control

# Home screen (design/VISUAL_SYSTEM.md "Home"). Hierarchy by SIZE, not colour: PVE and
# PVP are two equal large hero buttons, centre; Campaign is a smaller, lower-contrast
# tertiary button below (it's the tutorial). A slim ambient season strip sits top-centre;
# Settings is top-right, Quit bottom-left. Everything floats on the inert grass backdrop.

const UiStyle := preload("res://scripts/ui_style.gd")
const Motion := preload("res://scripts/motion.gd")

var _settings
const SettingsPanelScript := preload("res://scripts/settings_panel.gd")

# Break-the-grid attitude (design/JUICE.md + meta_menu_mock): the two heroes tilt and offset
# off-axis. Each hero lives in a plain Control "slot" the HBox manages, positioned freely
# inside so it can offset + animate (a container would stomp a child's position).
const HERO_TILT := -2.5
const HERO_OFFSET_Y := 12.0

# Entrance refs (armed transparent, then arrive on match-the-mock staggered delays).
var _season_pill: Control
var _title: Label
var _subtitle: Label
var _hero_trials: Button
var _hero_ranked: Button
var _campaign_btn: Button
var _corner_buttons: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.menu_backdrop(self)
	_build_season_strip()
	_build_center()
	_settings = SettingsPanelScript.new()
	add_child(_settings)
	_build_corner_settings()
	_build_corner_leaderboards()
	_build_corner_quit()

	# JUICE entrance (meta_menu_mock): arm everything transparent BEFORE the first frame, then
	# arrive staggered — season drops in, heroes arrive off-axis, campaign rises, corners fade.
	for n in [_season_pill, _title, _subtitle, _hero_trials, _hero_ranked, _campaign_btn] + _corner_buttons:
		if n != null:
			n.modulate.a = 0.0
	_play_home_arrival.call_deferred()

func _play_home_arrival() -> void:
	_seat_heroes()  # set the heroes' resting off-axis positions BEFORE slide_in caches them
	# Title/subtitle + season ease in first; the heroes earn the long arrive (they're the focus),
	# dropping into their off-axis resting offsets; campaign rises; corners fade in last.
	Motion.fade_in(_season_pill, Motion.M)
	Motion.fade_in(_title, Motion.M, Motion.dur(0.05))
	Motion.fade_in(_subtitle, Motion.M, Motion.dur(0.10))
	# Heroes drop into their off-axis offsets — they live in plain Control slots (not a
	# container), so a position slide holds. The campaign button is in the centre VBox, so it
	# rides scale+fade (a container would stomp a position tween).
	if _hero_trials != null:
		Motion.slide_in(_hero_trials, Vector2(0, 34), Motion.L, Motion.dur(0.16))
	if _hero_ranked != null:
		Motion.slide_in(_hero_ranked, Vector2(0, 34), Motion.L, Motion.dur(0.28))
	if _campaign_btn != null:
		_campaign_btn.pivot_offset = _campaign_btn.size * 0.5
		Motion.arrive_property(_campaign_btn, "scale", Vector2.ONE * 0.92, Vector2.ONE, Motion.M, Motion.dur(0.48))
		Motion.fade_in(_campaign_btn, Motion.S, Motion.dur(0.48))
	for b in _corner_buttons:
		Motion.fade_in(b, Motion.M, Motion.dur(0.60))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _settings != null and _settings.is_open():
			_settings.close()
			get_viewport().set_input_as_handled()

func _build_season_strip() -> void:
	# Ambient context AND the home's door into the Season track (the "home widget" surface,
	# design/COSMETICS.md): a slim pill with live tier + progress; click opens the Season screen.
	var pill := PanelContainer.new()
	_season_pill = pill
	pill.add_theme_stylebox_override("panel", UiStyle.pill_box())
	pill.anchor_left = 0.5
	pill.anchor_right = 0.5
	pill.anchor_top = 0.0
	pill.offset_top = 16
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pill.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			SceneManager.goto_season())
	add_child(pill)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	pill.add_child(margin)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 12)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(strip)

	var points: int = SaveData.season_points()
	var CatalogScript := preload("res://scripts/cosmetics_catalog.gd")
	strip.add_child(_label("Season %d" % CatalogScript.SEASON, 15, UiStyle.LABEL_COL))

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(200, 8)
	bar.max_value = CatalogScript.POINTS_PER_TIER
	bar.value = points % CatalogScript.POINTS_PER_TIER
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(bar)

	strip.add_child(_label("Tier %d" % CatalogScript.unlocked_tier(points), 15, Color("d79a52")))

func _build_center() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	_title = _label("WEND", 48, Color.WHITE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	_subtitle = _label("Build the maze. Milk the horde.", 18, UiStyle.LABEL_COL)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_subtitle)

	vbox.add_child(_spacer(20))

	# PVE and PVP: two equal hero buttons, off-axis (break-the-grid attitude). Each sits in a
	# plain Control slot so it can offset + animate freely (the HBox manages only the slots).
	var heroes := HBoxContainer.new()
	heroes.add_theme_constant_override("separation", 18)
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(heroes)

	_hero_trials = _hero_button("Trials", "1–4 player score runs", func(): SceneManager.goto_pve_select())
	_hero_ranked = _hero_button("Ranked", "8-player last-standing", func(): SceneManager.goto_lobby())
	heroes.add_child(_hero_slot(_hero_trials))
	heroes.add_child(_hero_slot(_hero_ranked))

	vbox.add_child(_spacer(8))

	# Campaign — clearly tertiary: smaller, lower contrast, set apart from PVE/PVP.
	_campaign_btn = Button.new()
	_campaign_btn.text = "Campaign  ·  Tutorial"
	_campaign_btn.custom_minimum_size = Vector2(240, 0)
	_campaign_btn.add_theme_font_size_override("font_size", 16)
	_campaign_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_menu_button(_campaign_btn)
	_campaign_btn.pressed.connect(func(): SceneManager.goto_campaign_select())
	vbox.add_child(_campaign_btn)

# A plain Control slot the HBox manages; the hero is positioned + tilted freely inside it
# (a container would stomp a child's position, so the off-axis offset + the drop-in need this).
func _hero_slot(hero: Button) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(300, 120 + 2.0 * HERO_OFFSET_Y)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(hero)
	return slot

# Seat each hero at its resting off-axis position + tilt (after layout, so sizes are real).
# Trials rides high, Ranked rides low; both tilt the same few degrees off-grid.
func _seat_heroes() -> void:
	_seat_hero(_hero_trials, -HERO_OFFSET_Y)
	_seat_hero(_hero_ranked, HERO_OFFSET_Y)

func _seat_hero(h: Button, dy: float) -> void:
	if h == null:
		return
	var slot: Control = h.get_parent()
	h.position = Vector2((slot.size.x - h.size.x) * 0.5, (slot.size.y - h.size.y) * 0.5 + dy)
	h.pivot_offset = h.size * 0.5
	h.rotation_degrees = HERO_TILT

func _hero_button(title: String, sub: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 120)
	b.add_theme_font_size_override("font_size", 30)
	UiStyle.style_hero_button(b)
	# Two-line label: big title over a small subtitle.
	b.text = title
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.pressed.connect(on_pressed)
	# Subtitle as a child label pinned under the title text.
	var sub_lbl := _label(sub, 14, UiStyle.LABEL_COL)
	sub_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sub_lbl.offset_bottom = -14
	sub_lbl.offset_top = -34
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sub_lbl)
	return b

func _build_corner_settings() -> void:
	var settings := Button.new()
	settings.text = "Settings"
	settings.add_theme_font_size_override("font_size", 15)
	UiStyle.style_menu_button(settings)
	settings.pressed.connect(func(): _settings.open())
	settings.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings.offset_left = -150
	settings.offset_top = 16
	settings.offset_right = -20
	settings.offset_bottom = 56
	add_child(settings)
	_corner_buttons.append(settings)

func _build_corner_leaderboards() -> void:
	var lb := Button.new()
	lb.text = "Leaderboards"
	lb.add_theme_font_size_override("font_size", 15)
	var ic := UiStyle.icon_texture("trophy")
	if ic != null:
		lb.icon = ic
		lb.add_theme_constant_override("icon_max_width", 18)
	UiStyle.style_menu_button(lb)
	lb.pressed.connect(func(): SceneManager.goto_leaderboards())
	lb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	lb.offset_left = -190
	lb.offset_top = -56
	lb.offset_right = -20
	lb.offset_bottom = -16
	add_child(lb)
	_corner_buttons.append(lb)

	# Collection sits above Leaderboards — same corner stack, same weight.
	var col := Button.new()
	col.text = "Collection"
	col.add_theme_font_size_override("font_size", 15)
	UiStyle.style_menu_button(col)
	col.pressed.connect(func(): SceneManager.goto_collection())
	col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	col.offset_left = -190
	col.offset_top = -106
	col.offset_right = -20
	col.offset_bottom = -66
	add_child(col)
	_corner_buttons.append(col)

func _build_corner_quit() -> void:
	var quit := Button.new()
	quit.text = "Quit"
	quit.add_theme_font_size_override("font_size", 15)
	var ic := UiStyle.icon_texture("cross")
	if ic != null:
		quit.icon = ic
		quit.add_theme_constant_override("icon_max_width", 18)
	UiStyle.style_menu_button(quit)
	quit.pressed.connect(func(): get_tree().quit())
	quit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	quit.offset_left = 20
	quit.offset_top = -56
	quit.offset_right = 140
	quit.offset_bottom = -16
	add_child(quit)
	_corner_buttons.append(quit)

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	return l
