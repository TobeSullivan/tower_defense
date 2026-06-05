extends CanvasLayer
class_name TowerDrawer

# Floating tower dock (mockup #dock) — top-right, collapsible, overlaid on the
# battlefield. Shows the selected tower's stats with green upgrade buttons, a red Sell,
# and a Supply footer. Slides in on tower_selected, out on selection_cleared / hide.
# Untyped refs avoid the class-name cycle pitfall.

const UiLayout := preload("res://scripts/ui_layout.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

const DOCK_W := 248.0
const STATS := ["damage", "range", "attack_speed", "crit_chance", "crit_damage", "multishot"]
const STAT_LABELS := {
	"damage": "Damage", "range": "Range", "attack_speed": "Attack speed",
	"crit_chance": "Crit", "crit_damage": "Crit dmg", "multishot": "Multishot",
}
const TILE_PX := 48.0

var round_manager       # RoundManager
var build_controller    # BuildController

var _panel: PanelContainer
var _name_lab: Label
var _sub_lab: Label
var _stat_val: Dictionary = {}
var _stat_btn: Dictionary = {}
var _stat_cost: Dictionary = {}
var _dmg_lab: Label

var _selected
var _open: bool = false
var _tween: Tween

func _ready() -> void:
	layer = 9
	_build_ui()
	if build_controller != null:
		build_controller.tower_selected.connect(_on_tower_selected)
		build_controller.selection_cleared.connect(_on_selection_cleared)
		build_controller.towers_changed.connect(func(_c, _cap): _refresh())
	if round_manager != null:
		round_manager.gold_changed.connect(func(_g): _refresh())
		round_manager.phase_changed.connect(func(_p): _refresh())

func is_open() -> bool:
	return _open

func _process(_delta: float) -> void:
	# Total damage climbs during the run phase; refresh just that field live while open.
	if _open and is_instance_valid(_selected):
		_update_damage()

func covers(pos: Vector2) -> bool:
	return _open and _panel != null and _panel.get_global_rect().has_point(pos)

func _build_ui() -> void:
	var s := UiLayout.scale_factor()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.dock_box())
	_panel.custom_minimum_size = Vector2(DOCK_W * s, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	root.add_child(_panel)

	var m := MarginContainer.new()
	var pad := int(12 * s)
	m.add_theme_constant_override("margin_left", pad)
	m.add_theme_constant_override("margin_right", pad)
	m.add_theme_constant_override("margin_top", pad)
	m.add_theme_constant_override("margin_bottom", pad)
	_panel.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(5 * s))
	m.add_child(v)

	# Header: "TOWER" + hide
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(_h3("TOWER", true))
	var hide := Button.new()
	hide.text = "‹ hide"
	hide.flat = true
	hide.add_theme_font_size_override("font_size", int(12 * s))
	hide.add_theme_color_override("font_color", UiStyle.LABEL_COL)
	hide.pressed.connect(_on_hide_pressed)
	head.add_child(hide)

	# Tower card
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", int(10 * s))
	var nameblock := VBoxContainer.new()
	_name_lab = Label.new()
	_name_lab.text = "Tower"
	_name_lab.add_theme_font_size_override("font_size", int(17 * s))
	_name_lab.add_theme_color_override("font_color", Color.WHITE)
	_sub_lab = Label.new()
	_sub_lab.text = ""
	_sub_lab.add_theme_font_size_override("font_size", int(11 * s))
	_sub_lab.add_theme_color_override("font_color", Color("9fb088"))
	nameblock.add_child(_name_lab)
	nameblock.add_child(_sub_lab)
	card.add_child(nameblock)
	v.add_child(card)

	# Stat rows
	for stat in STATS:
		var rowpanel := PanelContainer.new()
		rowpanel.add_theme_stylebox_override("panel", UiStyle.stat_box())
		var rm := MarginContainer.new()
		rm.add_theme_constant_override("margin_left", int(8 * s))
		rm.add_theme_constant_override("margin_right", int(8 * s))
		rm.add_theme_constant_override("margin_top", int(6 * s))
		rm.add_theme_constant_override("margin_bottom", int(6 * s))
		rowpanel.add_child(rm)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(6 * s))
		rm.add_child(row)
		var nm := Label.new()
		nm.text = STAT_LABELS[stat]
		nm.add_theme_font_size_override("font_size", int(13 * s))
		nm.add_theme_color_override("font_color", Color("dfe6d6"))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(nm)
		var val := Label.new()
		val.add_theme_font_size_override("font_size", int(13 * s))
		val.add_theme_color_override("font_color", Color.WHITE)
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_stat_val[stat] = val
		row.add_child(val)
		# cost: amount only (no coin icon); "MAX" replaces it when maxed
		var cost := Label.new()
		cost.add_theme_font_size_override("font_size", int(13 * s))
		cost.add_theme_color_override("font_color", Color("ffe98c"))
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost.custom_minimum_size = Vector2(30 * s, 0)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stat_cost[stat] = cost
		row.add_child(cost)
		var up := Button.new()
		up.text = "+"
		up.custom_minimum_size = Vector2(26, 26) * s
		up.add_theme_font_size_override("font_size", int(16 * s))
		UiStyle.style_flat_button(up, UiStyle.UP_BG, 8, UiStyle.UP_BG.darkened(0.3), 1, false, 4, 0)
		up.pressed.connect(_on_upgrade_pressed.bind(stat))
		_stat_btn[stat] = up
		row.add_child(up)
		v.add_child(rowpanel)

	# Total damage dealt this match (live). Restored — the UI rebuild dropped it.
	var dmgpanel := PanelContainer.new()
	dmgpanel.add_theme_stylebox_override("panel", UiStyle.stat_box())
	var dm := MarginContainer.new()
	dm.add_theme_constant_override("margin_left", int(8 * s))
	dm.add_theme_constant_override("margin_right", int(8 * s))
	dm.add_theme_constant_override("margin_top", int(6 * s))
	dm.add_theme_constant_override("margin_bottom", int(6 * s))
	dmgpanel.add_child(dm)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", int(6 * s))
	dm.add_child(drow)
	var dlab := Label.new()
	dlab.text = "Total damage"
	dlab.add_theme_font_size_override("font_size", int(13 * s))
	dlab.add_theme_color_override("font_color", Color("dfe6d6"))
	dlab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drow.add_child(dlab)
	_dmg_lab = Label.new()
	_dmg_lab.text = "0"
	_dmg_lab.add_theme_font_size_override("font_size", int(13 * s))
	_dmg_lab.add_theme_color_override("font_color", Color("ffd27a"))
	drow.add_child(_dmg_lab)
	v.add_child(dmgpanel)

	# Sell
	var sell := Button.new()
	sell.text = "Sell Tower"
	sell.custom_minimum_size = Vector2(0, 34 * s)
	sell.add_theme_font_size_override("font_size", int(13 * s))
	UiStyle.style_flat_button(sell, UiStyle.SELL_BG, 10, UiStyle.SELL_BG.darkened(0.3), 1, false)
	sell.pressed.connect(_on_sell_pressed)
	v.add_child(sell)

func _h3(text: String, label_col: bool) -> Label:
	var s := UiLayout.scale_factor()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(13 * s))
	l.add_theme_color_override("font_color", UiStyle.LABEL_COL if label_col else Color.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL if label_col else Control.SIZE_FILL
	return l

# --- open / close ---

func _on_tower_selected(tower) -> void:
	_selected = tower
	_open_dock()

func _on_selection_cleared() -> void:
	_selected = null
	_close_dock()

func _on_hide_pressed() -> void:
	if build_controller != null:
		build_controller.close_upgrade_panel()
	else:
		_close_dock()

func _dock_x_open(vp: Vector2) -> float:
	return vp.x - _panel.size.x - 16.0 * UiLayout.scale_factor()

func _open_dock() -> void:
	if not is_instance_valid(_selected):
		return
	var vp := get_viewport().get_visible_rect().size
	_panel.position.y = 74.0 * UiLayout.scale_factor()
	_panel.visible = true
	_refresh()
	await get_tree().process_frame  # let the panel size to content before placing
	if not is_instance_valid(_selected):
		return
	if not _open:
		_panel.position.x = vp.x + 20.0
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "position:x", _dock_x_open(vp), 0.18)
	_open = true

func _close_dock() -> void:
	if not _panel.visible:
		_open = false
		return
	var vp := get_viewport().get_visible_rect().size
	_open = false
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_panel, "position:x", vp.x + 20.0, 0.16)
	_tween.tween_callback(func(): _panel.visible = false)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

# --- content ---

func _refresh() -> void:
	if not _open and not _panel.visible:
		return
	if not is_instance_valid(_selected):
		return
	var in_build: bool = round_manager == null or round_manager.phase == "build"
	var gold: int = round_manager.gold if round_manager != null else 99999
	_name_lab.text = "Arrow Tower"
	var lv: int = 1
	for stat in STATS:
		lv += _selected.tiers[stat]
	_sub_lab.text = "Lv %d · selected" % lv
	for stat in STATS:
		_stat_val[stat].text = _effective_value(stat)
		var b: Button = _stat_btn[stat]
		var cost: int = _selected.upgrade_cost(stat)
		var cost_lab: Label = _stat_cost[stat]
		if cost <= 0:
			cost_lab.text = "MAX"
			cost_lab.add_theme_color_override("font_color", Color("9fb088"))
			b.disabled = true
			b.visible = false
		else:
			b.visible = true
			cost_lab.text = str(cost)
			var afford: bool = in_build and gold >= cost
			cost_lab.add_theme_color_override("font_color", Color("ffe98c") if afford else Color(1, 0.92, 0.55, 0.4))
			b.disabled = not afford
	_update_damage()

func _update_damage() -> void:
	if _dmg_lab == null or not is_instance_valid(_selected):
		return
	_dmg_lab.text = "%s  ·  %d kills" % [_fmt_num(_selected.damage_done), _selected.kills]

static func _fmt_num(v: float) -> String:
	var n := int(round(v))
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)

func _effective_value(stat: String) -> String:
	var t = _selected
	match stat:
		"damage":       return "%.0f" % t.get_damage()
		"range":        return "%.1f" % (t.get_range() / TILE_PX)
		"attack_speed": return "%.1f/s" % (1.0 / t.get_cooldown())
		"crit_chance":  return "%d%%" % int(round(t.get_crit_chance() * 100.0))
		"crit_damage":  return "x%.2f" % t.get_crit_damage_mult()
		"multishot":    return "%d" % (1 + t.get_multishot())
	return "—"

func _on_upgrade_pressed(stat: String) -> void:
	if not is_instance_valid(_selected):
		return
	if round_manager != null and round_manager.phase != "build":
		return
	var cost: int = _selected.upgrade_cost(stat)
	if cost <= 0:
		return
	if round_manager != null and not round_manager.spend(cost):
		return
	_selected.upgrade(stat)
	_refresh()

func _on_sell_pressed() -> void:
	if build_controller != null:
		build_controller.sell_selected_tower()
