extends CanvasLayer
class_name HUD

# Top status bar (part of the reserved UI frame). Full-width strip across the top
# showing match state: round / phase / timer on the left, resources on the right.
# The Start-Round and Speed controls live here for now; Phase 3 moves them into the
# right action rail and slims this bar to pure status.

const UiLayout := preload("res://scripts/ui_layout.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

var round_manager  # RoundManager — untyped to avoid class-name cycle
var build_controller  # BuildController — untyped to avoid class-name cycle

var _round_label: Label
var _phase_label: Label
var _gold_label: Label
var _score_label: Label
var _kills_label: Label
var _towers_label: Label
var _lives_label: Label  # PVP only
var _towers_count: int = 0
var _towers_cap: int = 0

func _ready() -> void:
	layer = 6

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = UiLayout.top_bar_h()
	UiStyle.apply_bar(panel)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	_round_label = _make_label(20)
	row.add_child(_round_label)
	_phase_label = _make_label(20)
	row.add_child(_phase_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_lives_label = _make_label(20)  # PVP only
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	_lives_label.visible = false
	row.add_child(_lives_label)
	_gold_label = _make_label(20)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	row.add_child(_gold_label)
	_score_label = _make_label(20)
	row.add_child(_score_label)
	_kills_label = _make_label(20)
	row.add_child(_kills_label)
	_towers_label = _make_label(20)
	row.add_child(_towers_label)

	if round_manager != null:
		round_manager.gold_changed.connect(func(_g): _refresh())
		round_manager.round_changed.connect(func(_r): _refresh())
		round_manager.phase_changed.connect(func(_p): _refresh())
		round_manager.build_timer_changed.connect(func(_t): _refresh())
		round_manager.damage_dealt_changed.connect(func(_d): _refresh())
		round_manager.kills_changed.connect(func(_k): _refresh())
	if build_controller != null:
		build_controller.towers_changed.connect(_on_towers_changed)
		# The controller emits towers_changed in its own _ready, before the HUD is
		# in the tree — so seed the initial count/cap here or it reads "0 / 0".
		_towers_count = build_controller.towers.size()
		_towers_cap = build_controller.max_towers
	_refresh()

func _on_towers_changed(count: int, cap: int) -> void:
	_towers_count = count
	_towers_cap = cap
	_refresh()

func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", int(font_size * UiLayout.scale_factor()))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _is_pvp() -> bool:
	return round_manager != null and round_manager.coordinator != null and round_manager.coordinator.is_pvp

func _refresh() -> void:
	if round_manager == null:
		return
	if _is_pvp():
		_round_label.text = "Round %d" % round_manager.round_num  # last-standing: no cap
		_lives_label.visible = true
		_lives_label.text = "Lives: %d" % round_manager.lives
	else:
		_round_label.text = "Round %d / %d" % [round_manager.round_num, round_manager.max_rounds]
		_lives_label.visible = false
	_gold_label.text = "Gold: %d" % round_manager.gold
	_score_label.text = "Score: %d" % round_manager.total_damage_dealt
	_kills_label.text = "Kills: %d" % round_manager.total_kills
	_towers_label.text = "Towers: %d / %d" % [_towers_count, _towers_cap]
	if round_manager.match_over:
		_phase_label.text = "MATCH ENDED"
	elif round_manager.phase == "build":
		_phase_label.text = "BUILD — %.0fs" % round_manager.build_time_left
	else:
		_phase_label.text = "RUN"
