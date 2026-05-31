extends CanvasLayer
class_name MatchEndPanel

var round_manager  # RoundManager — untyped to avoid class-name cycle

var _panel: PanelContainer
var _title_label: Label
var _damage_label: Label
var _medal_label: Label
var _thresholds_vbox: VBoxContainer

const MEDAL_COLORS := {
	"gold":   Color(1.0, 0.85, 0.2),
	"silver": Color(0.85, 0.85, 0.9),
	"bronze": Color(0.85, 0.55, 0.25),
	"none":   Color(0.7, 0.7, 0.7),
}

const MEDAL_LABELS := {
	"gold":   "GOLD",
	"silver": "SILVER",
	"bronze": "BRONZE",
	"none":   "No medal — try again",
}

func _ready() -> void:
	layer = 20
	_build_ui()
	_panel.visible = false
	if round_manager != null:
		round_manager.match_ended.connect(_on_match_ended)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -240
	_panel.offset_right = 240
	_panel.offset_top = -220
	_panel.offset_bottom = 220
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_title_label = _make_label(28, Color.WHITE)
	_title_label.text = "Match Complete"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_medal_label = _make_label(32, Color.WHITE)
	_medal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_medal_label)

	_damage_label = _make_label(20, Color.WHITE)
	_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_damage_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_thresholds_vbox = VBoxContainer.new()
	_thresholds_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_thresholds_vbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var home := Button.new()
	home.text = "Return Home"
	home.custom_minimum_size = Vector2(0, 48)
	home.add_theme_font_size_override("font_size", 18)
	home.pressed.connect(_on_return_home)
	vbox.add_child(home)

	var again := Button.new()
	again.text = "Play Again"
	again.custom_minimum_size = Vector2(0, 44)
	again.add_theme_font_size_override("font_size", 16)
	again.pressed.connect(_on_play_again)
	vbox.add_child(again)

func _on_match_ended() -> void:
	var damage: int = round_manager.total_damage_dealt
	var medal: String = round_manager.medal_for(damage)
	_medal_label.text = MEDAL_LABELS[medal]
	_medal_label.add_theme_color_override("font_color", MEDAL_COLORS[medal])
	_damage_label.text = "Total damage: %d  ·  Rounds: %d" % [damage, round_manager.max_rounds]
	_populate_thresholds(damage)
	_panel.visible = true
	# Persist the result (campaign medal / PVE score; no-op for PVP).
	SceneManager.report_match_result(damage)

func _populate_thresholds(damage: int) -> void:
	for child in _thresholds_vbox.get_children():
		child.queue_free()
	_add_threshold_row("Bronze", round_manager.bronze_threshold, damage, MEDAL_COLORS.bronze)
	_add_threshold_row("Silver", round_manager.silver_threshold, damage, MEDAL_COLORS.silver)
	_add_threshold_row("Gold",   round_manager.gold_threshold,   damage, MEDAL_COLORS.gold)

func _add_threshold_row(name: String, threshold: int, achieved: int, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dot := _make_label(18, color)
	dot.text = "●" if achieved >= threshold else "○"
	row.add_child(dot)
	var text := _make_label(16, Color.WHITE)
	text.text = "%s: %d" % [name, threshold]
	row.add_child(text)
	_thresholds_vbox.add_child(row)

func _on_return_home() -> void:
	SceneManager.goto_home()

func _on_play_again() -> void:
	SceneManager.restart_current_match()

func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l
