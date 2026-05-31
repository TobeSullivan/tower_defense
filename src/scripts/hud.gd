extends CanvasLayer
class_name HUD

var round_manager  # RoundManager — untyped to avoid class-name cycle
var build_controller  # BuildController — untyped to avoid class-name cycle

var _gold_label: Label
var _round_label: Label
var _phase_label: Label
var _score_label: Label
var _kills_label: Label
var _towers_label: Label
var _start_button: Button
var _ff_button: Button
var _towers_count: int = 0
var _towers_cap: int = 0

# Fast-forward (single-player). Cycles 1x -> 2x -> 3x -> 1x. The selected
# multiplier only applies during the run phase; build phase always runs at 1x
# so the build timer isn't drained faster.
const FF_MULTS := [1.0, 2.0, 3.0]
var _ff_index: int = 0

func _ready() -> void:
	layer = 6

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -260
	panel.offset_right = -20
	panel.offset_top = 20
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	_round_label = _make_label(22)
	vbox.add_child(_round_label)
	_gold_label = _make_label(22)
	vbox.add_child(_gold_label)
	_score_label = _make_label(22)
	vbox.add_child(_score_label)
	_kills_label = _make_label(18)
	vbox.add_child(_kills_label)
	_towers_label = _make_label(18)
	vbox.add_child(_towers_label)
	_phase_label = _make_label(18)
	vbox.add_child(_phase_label)

	_start_button = Button.new()
	_start_button.text = "Start Round"
	_start_button.custom_minimum_size = Vector2(0, 38)
	_start_button.add_theme_font_size_override("font_size", 16)
	_start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(_start_button)

	_ff_button = Button.new()
	_ff_button.custom_minimum_size = Vector2(0, 34)
	_ff_button.add_theme_font_size_override("font_size", 16)
	_ff_button.pressed.connect(_on_ff_pressed)
	vbox.add_child(_ff_button)

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
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l

func _refresh() -> void:
	if round_manager == null:
		return
	_round_label.text = "Round %d / %d" % [round_manager.round_num, round_manager.max_rounds]
	_gold_label.text = "Gold: %d" % round_manager.gold
	_score_label.text = "Score: %d" % round_manager.total_damage_dealt
	_kills_label.text = "Kills: %d" % round_manager.total_kills
	_towers_label.text = "Towers: %d / %d" % [_towers_count, _towers_cap]
	if round_manager.match_over:
		_phase_label.text = "MATCH ENDED"
		_start_button.visible = false
	elif round_manager.phase == "build":
		_phase_label.text = "BUILD — %.0fs" % round_manager.build_time_left
		_start_button.visible = true
	else:
		_phase_label.text = "RUN"
		_start_button.visible = false

	_ff_button.text = "Speed: %dx" % int(FF_MULTS[_ff_index])
	_apply_time_scale()

func _on_start_pressed() -> void:
	if round_manager != null:
		round_manager.request_start_now()

func _on_ff_pressed() -> void:
	_ff_index = (_ff_index + 1) % FF_MULTS.size()
	_ff_button.text = "Speed: %dx" % int(FF_MULTS[_ff_index])
	_apply_time_scale()

# FF only speeds the run phase. Build phase and post-match run at 1x.
func _apply_time_scale() -> void:
	if round_manager != null and round_manager.phase == "run" and not round_manager.match_over:
		Engine.time_scale = FF_MULTS[_ff_index]
	else:
		Engine.time_scale = 1.0
