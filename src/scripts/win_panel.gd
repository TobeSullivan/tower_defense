extends CanvasLayer
class_name WinPanel

# Shown once when total damage crosses the Gold threshold mid-match. Pauses the
# game and lets the player either stop here (they've "won" the level) or keep
# playing for a higher leaderboard score.

var round_manager  # RoundManager — untyped to avoid class-name cycle

var _panel: PanelContainer
var _damage_label: Label

func _ready() -> void:
	layer = 21
	# Must keep processing (and let its buttons work) while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false
	if round_manager != null:
		round_manager.gold_goal_reached.connect(_on_gold_goal_reached)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -260
	_panel.offset_right = 260
	_panel.offset_top = -160
	_panel.offset_bottom = 160
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := _make_label(30, Color(1.0, 0.85, 0.2))
	title.text = "GOLD REACHED — You won!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_damage_label = _make_label(20, Color.WHITE)
	_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_damage_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	var keep := Button.new()
	keep.text = "Keep Playing"
	keep.custom_minimum_size = Vector2(0, 48)
	keep.add_theme_font_size_override("font_size", 18)
	keep.pressed.connect(_on_keep_playing)
	vbox.add_child(keep)

	var home := Button.new()
	home.text = "Return Home"
	home.custom_minimum_size = Vector2(0, 48)
	home.add_theme_font_size_override("font_size", 18)
	home.pressed.connect(_on_return_home)
	vbox.add_child(home)

func _on_gold_goal_reached() -> void:
	var dmg: int = round_manager.total_damage_dealt if round_manager != null else 0
	var goal: int = round_manager.gold_threshold if round_manager != null else 0
	_damage_label.text = "Total damage: %d  (Gold: %d)" % [dmg, goal]
	_panel.visible = true
	get_tree().paused = true

func _on_keep_playing() -> void:
	_panel.visible = false
	get_tree().paused = false

func _on_return_home() -> void:
	# Bowing out after Gold keeps your score (partial scores count).
	get_tree().paused = false
	var dmg: int = round_manager.total_damage_dealt if round_manager != null else 0
	SceneManager.leave_match_to_home(dmg)

func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l
