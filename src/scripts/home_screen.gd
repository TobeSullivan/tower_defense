extends Control

# Home screen for returning players (DESIGN_MODES "Home screen"). PVE and PVP are
# the two primary buttons; Campaign is a deliberately secondary tertiary button;
# a slim season strip sits at the top; Settings is tucked in a corner.
#
# PVE/PVP/Settings are disabled for now: PVE/PVP need the generator + matchmaking
# (multiplayer is deferred per RULES), and Settings lands in a later UI phase.
# Campaign is the live, fully wired path.

const BG_COLOR := Color(0.07, 0.09, 0.13)
const SettingsPanelScript := preload("res://scripts/settings_panel.gd")

var _settings

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_season_strip()
	_build_center()
	_settings = SettingsPanelScript.new()
	add_child(_settings)
	_build_corner_settings()
	_build_corner_quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _settings != null and _settings.is_open():
			_settings.close()
			get_viewport().set_input_as_handled()

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _build_season_strip() -> void:
	# Ambient context, not a call to action: tier badge + a slim progress bar.
	var strip := HBoxContainer.new()
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	strip.offset_left = 24
	strip.offset_right = -24
	strip.offset_top = 16
	strip.add_theme_constant_override("separation", 12)
	add_child(strip)

	var tier := _label("Bronze", 16, Color(0.85, 0.55, 0.25))
	strip.add_child(tier)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 10)
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	strip.add_child(bar)

	var season := _label("Season 1", 16, Color(0.7, 0.75, 0.85))
	strip.add_child(season)

func _build_center() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := _label("MAZE BATTLE TD", 44, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := _label("Build the maze. Milk the horde.", 18, Color(0.6, 0.65, 0.75))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(18))

	var pve := _primary_button("PVE")
	pve.pressed.connect(func(): SceneManager.goto_pve_select())
	vbox.add_child(pve)

	var pvp := _primary_button("PVP")
	pvp.disabled = true
	pvp.tooltip_text = "Coming soon"
	vbox.add_child(pvp)

	var soon := _label("PVP coming soon", 14, Color(0.5, 0.55, 0.65))
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(soon)

	vbox.add_child(_spacer(10))

	# Campaign — clearly tertiary: smaller, muted, set apart from PVE/PVP.
	var campaign := Button.new()
	campaign.text = "Campaign"
	campaign.custom_minimum_size = Vector2(180, 40)
	campaign.add_theme_font_size_override("font_size", 16)
	campaign.pressed.connect(func(): SceneManager.goto_campaign_select())
	vbox.add_child(campaign)

func _build_corner_settings() -> void:
	var settings := Button.new()
	settings.text = "Settings"
	settings.add_theme_font_size_override("font_size", 14)
	settings.pressed.connect(func(): _settings.open())
	settings.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	settings.offset_left = -150
	settings.offset_top = -52
	settings.offset_right = -20
	settings.offset_bottom = -16
	add_child(settings)

func _build_corner_quit() -> void:
	var quit := Button.new()
	quit.text = "Quit Game"
	quit.add_theme_font_size_override("font_size", 14)
	quit.pressed.connect(func(): get_tree().quit())
	quit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	quit.offset_left = 20
	quit.offset_top = -52
	quit.offset_right = 150
	quit.offset_bottom = -16
	add_child(quit)

func _primary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 60)
	b.add_theme_font_size_override("font_size", 24)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
