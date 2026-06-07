extends Control

# Home screen (design/VISUAL_SYSTEM.md "Home"). Hierarchy by SIZE, not colour: PVE and
# PVP are two equal large hero buttons, centre; Campaign is a smaller, lower-contrast
# tertiary button below (it's the tutorial). A slim ambient season strip sits top-centre;
# Settings is top-right, Quit bottom-left. Everything floats on the inert grass backdrop.

const UiStyle := preload("res://scripts/ui_style.gd")

var _settings
const SettingsPanelScript := preload("res://scripts/settings_panel.gd")

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

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _settings != null and _settings.is_open():
			_settings.close()
			get_viewport().set_input_as_handled()

func _build_season_strip() -> void:
	# Ambient context, not a call to action: a slim pill with tier + season progress.
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiStyle.pill_box())
	pill.anchor_left = 0.5
	pill.anchor_right = 0.5
	pill.anchor_top = 0.0
	pill.offset_top = 16
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
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
	margin.add_child(strip)

	strip.add_child(_label("Season 1", 15, UiStyle.LABEL_COL))

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(200, 8)
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(bar)

	strip.add_child(_label("Bronze", 15, Color("d79a52")))

func _build_center() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := _label("MAZE BATTLE TD", 48, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := _label("Build the maze. Milk the horde.", 18, UiStyle.LABEL_COL)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(20))

	# PVE and PVP: two equal hero buttons side by side. Size is the hierarchy.
	var heroes := HBoxContainer.new()
	heroes.add_theme_constant_override("separation", 18)
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(heroes)

	heroes.add_child(_hero_button("Trials", "1–4 player score runs", func(): SceneManager.goto_pve_select()))
	heroes.add_child(_hero_button("Ranked", "8-player last-standing", func(): SceneManager.goto_lobby()))

	vbox.add_child(_spacer(8))

	# Campaign — clearly tertiary: smaller, lower contrast, set apart from PVE/PVP.
	var campaign := Button.new()
	campaign.text = "Campaign  ·  Tutorial"
	campaign.custom_minimum_size = Vector2(240, 0)
	campaign.add_theme_font_size_override("font_size", 16)
	campaign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_menu_button(campaign)
	campaign.pressed.connect(func(): SceneManager.goto_campaign_select())
	vbox.add_child(campaign)

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
