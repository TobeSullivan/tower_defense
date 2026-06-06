extends CanvasLayer
class_name WinPanel

# Shown once when total damage crosses the Gold threshold mid-match. Pauses the
# game and lets the player either stop here (they've "won" the level) or keep
# playing for a higher leaderboard score.

const UiStyle := preload("res://scripts/ui_style.gd")

const TIER_LABELS := ["1 star", "2 stars", "3 stars"]
const CLEARED := Color("7fcf5a")
const GOLD := Color("f2c14e")

var round_manager  # RoundManager — untyped to avoid class-name cycle

var _panel: PanelContainer
var _score_label: Label
var _tier_val: Array = []     # the three value Labels (bronze/silver/gold)
var _tier_chk: Array = []     # the three checkmark Labels

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
	UiStyle.apply_card(_panel, 18)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(540, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Stars (they say "three stars" on their own — no redundant text line).
	var stars := _make_label(40, GOLD)
	stars.text = "★★★"
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stars)

	# Heading — no em dash.
	var title := _make_label(30, GOLD)
	title.text = "You won!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Comma-formatted score.
	_score_label = _make_label(18, Color("f4eedb"))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_score_label)

	# Tier strip — the three thresholds, ticked when cleared.
	var tiers := HBoxContainer.new()
	tiers.add_theme_constant_override("separation", 10)
	tiers.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(3):
		tiers.add_child(_tier_card(i))
	vbox.add_child(tiers)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var keep := Button.new()
	keep.text = "Keep playing"
	keep.custom_minimum_size = Vector2(0, 48)
	keep.add_theme_font_size_override("font_size", 18)
	UiStyle.style_go_button(keep)
	keep.pressed.connect(_on_keep_playing)
	vbox.add_child(keep)

	var home := Button.new()
	home.text = "Return home"
	home.custom_minimum_size = Vector2(0, 48)
	home.add_theme_font_size_override("font_size", 18)
	UiStyle.style_menu_button(home)
	home.pressed.connect(_on_return_home)
	vbox.add_child(home)

# One tier card: "N star(s)" over the threshold value + a checkmark slot.
func _tier_card(i: int) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _tier_box())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 7)
	m.add_theme_constant_override("margin_bottom", 7)
	card.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	m.add_child(v)
	var name_lab := _make_label(12, Color("bdb89f"))
	name_lab.text = TIER_LABELS[i]
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_lab)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	var val := _make_label(14, Color("f4eedb"))
	row.add_child(val)
	_tier_val.append(val)
	var chk := _make_label(13, CLEARED)
	chk.text = ""
	row.add_child(chk)
	_tier_chk.append(chk)
	v.add_child(row)
	return card

func _tier_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("41492d")
	sb.set_corner_radius_all(9)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	return sb

func _on_gold_goal_reached() -> void:
	var dmg: int = round_manager.total_damage_dealt if round_manager != null else 0
	_score_label.text = "Total damage  %s" % _commas(dmg)
	var thresholds := [
		int(round_manager.bronze_threshold) if round_manager != null else 0,
		int(round_manager.silver_threshold) if round_manager != null else 0,
		int(round_manager.gold_threshold) if round_manager != null else 0,
	]
	for i in range(3):
		_tier_val[i].text = _commas(thresholds[i])
		_tier_chk[i].text = "✓" if dmg >= thresholds[i] else ""
	_panel.visible = true
	get_tree().paused = true

func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out

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
