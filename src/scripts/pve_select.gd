extends Control

# Solo PVE map select (DESIGN_MODES "Navigation from PVE", solo path). Shows the
# five maps for the current daily window (Scale 1–5); solo players go straight
# into a match on select. Maps are seeded from the date, so the set is stable for
# the day and changes daily — locally, with no backend. Leaderboards, time-window
# variants, and group lobbies are deferred; only a local best score is shown.

const BG_COLOR := Color(0.07, 0.09, 0.13)
const MapGen := preload("res://scripts/map_generator.gd")
const MapResourceScript := preload("res://resources/map_resource.gd")

var _maps: Array = []        # 5 generated MapResources, index 0 = Scale 1
var _window_date := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window_date = _today()
	_generate_window()
	_build_background()
	_build_header()
	_build_list()

func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _generate_window() -> void:
	# One stable base seed per day; each tier gets a distinct derived seed.
	var base: int = hash(_window_date)
	for tier in range(1, 6):
		var map_seed: int = base + tier * 1013
		_maps.append(MapGen.generate(map_seed, tier, MapResourceScript.Mode.PVE, MapResourceScript.WindowType.DAILY, _window_date))

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _build_header() -> void:
	var title := _label("PVE — Daily", 36, Color.WHITE)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 40
	title.offset_top = 28
	add_child(title)

	var subtitle := _label("Five maps, Scale 1–5. New set each day. Solo run for high score.", 16, Color(0.6, 0.65, 0.75))
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_left = 40
	subtitle.offset_top = 74
	add_child(subtitle)

	var back := Button.new()
	back.text = "← Back"
	back.add_theme_font_size_override("font_size", 16)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -150
	back.offset_top = 28
	back.offset_right = -40
	back.offset_bottom = 68
	back.pressed.connect(func(): SceneManager.goto_home())
	add_child(back)

func _build_list() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	for i in range(_maps.size()):
		vbox.add_child(_map_card(i))

func _map_card(index: int) -> Control:
	var map: Variant = _maps[index]
	var tier: int = map.scale_tier
	var best: int = SaveData.best_pve_score(_window_date, tier)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	info.add_child(_label("Scale %d" % tier, 22, _tier_color(tier)))
	info.add_child(_label("Rounds %d   ·   Supply %d   ·   Checkpoints %d   ·   Zones %d   ·   Mobs %d" % [
		map.round_count, map.supply_cap, map.checkpoint_cells.size(), map.bonus_zones.size(), map.mob_count], 14, Color(0.7, 0.75, 0.85)))
	var best_text := "Best: %d" % best if best > 0 else "Best: —"
	info.add_child(_label(best_text, 14, Color(1.0, 0.9, 0.5)))

	var play := Button.new()
	play.text = "Play"
	play.custom_minimum_size = Vector2(120, 52)
	play.add_theme_font_size_override("font_size", 18)
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
