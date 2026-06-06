extends CanvasLayer
class_name TowerDrawer

# Tower inspector — a PERMANENT panel docked in the reserved right zone (v3 bounded
# layout). Shows the selected tower's stats with green upgrade buttons, a red Sell, and a
# live total-damage line; when nothing is selected it shows a muted placeholder. The
# "‹ hide" header button collapses the dock to a thin tab, which hands its reserved width
# back to the board (play_rect reads UiLayout._inspector_hidden and game_view re-fits).
# Class name kept as TowerDrawer for back-compat with existing references. Untyped refs
# avoid the class-name cycle pitfall.

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
var game_view           # GameView — collapsing the dock asks it to re-fit the board

var _panel: PanelContainer
var _content: VBoxContainer   # name + stats + sell (hidden when nothing selected)
var _placeholder: Label       # shown when nothing is selected
var _show_tab: Button         # thin re-open tab shown while the dock is collapsed
var _name_lab: Label
var _sub_lab: Label
var _stat_val: Dictionary = {}
var _stat_btn: Dictionary = {}
var _stat_cost: Dictionary = {}
var _dmg_lab: Label

var _selected
var _hidden: bool = false

func _ready() -> void:
	layer = 9
	UiLayout.set_inspector_hidden(false)  # every match starts with the dock shown
	_build_ui()
	_show_placeholder()
	_relayout()
	_relayout.call_deferred()  # re-snap once container min sizes have settled
	get_viewport().size_changed.connect(_relayout)
	if build_controller != null:
		build_controller.tower_selected.connect(_on_tower_selected)
		build_controller.selection_cleared.connect(_on_selection_cleared)
		build_controller.towers_changed.connect(func(_c, _cap): _refresh())
	if round_manager != null:
		round_manager.gold_changed.connect(func(_g): _refresh())
		round_manager.phase_changed.connect(func(_p): _refresh())

func _process(_delta: float) -> void:
	# Total damage climbs during the run; refresh just that field live while a tower shows.
	if not _hidden and is_instance_valid(_selected) and _content.visible:
		_update_damage()

# A tap is "over" the inspector if it lands on the docked panel or the collapsed tab —
# the click gate skips the board there (belt-and-braces; the dock is outside play_rect).
func covers(pos: Vector2) -> bool:
	if _panel != null and _panel.visible and _panel.get_global_rect().has_point(pos):
		return true
	if _show_tab != null and _show_tab.visible and _show_tab.get_global_rect().has_point(pos):
		return true
	return false

func _build_ui() -> void:
	var s := UiLayout.scale_factor()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.dock_box())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
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

	# Header: "TOWER" + collapse
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(_h3("TOWER", true))
	var hide := Button.new()
	hide.text = "‹ hide"
	hide.flat = true
	hide.add_theme_font_size_override("font_size", int(12 * s))
	hide.add_theme_color_override("font_color", UiStyle.LABEL_COL)
	hide.pressed.connect(func(): _set_hidden(true))
	head.add_child(hide)

	# Placeholder shown when nothing is selected.
	_placeholder = Label.new()
	_placeholder.text = "Select a tower to inspect."
	_placeholder.add_theme_font_size_override("font_size", int(13 * s))
	_placeholder.add_theme_color_override("font_color", Color("8f9a76"))
	_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placeholder.custom_minimum_size = Vector2(0, 44 * s)
	v.add_child(_placeholder)

	# Content (name + stats + sell), hidden until a tower is selected.
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", int(5 * s))
	v.add_child(_content)

	# Tower card
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
	_content.add_child(nameblock)

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
		_content.add_child(rowpanel)

	# Total damage dealt this match (live).
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
	_content.add_child(dmgpanel)

	# Sell
	var sell := Button.new()
	sell.text = "Sell Tower"
	sell.custom_minimum_size = Vector2(0, 34 * s)
	sell.add_theme_font_size_override("font_size", int(13 * s))
	UiStyle.style_flat_button(sell, UiStyle.SELL_BG, 10, UiStyle.SELL_BG.darkened(0.3), 1, false)
	sell.pressed.connect(_on_sell_pressed)
	_content.add_child(sell)

	# Thin re-open tab, shown only while collapsed.
	_show_tab = Button.new()
	_show_tab.text = "›"
	_show_tab.add_theme_font_size_override("font_size", int(20 * s))
	UiStyle.style_flat_button(_show_tab, UiStyle.CHIP_BG, 10, UiStyle.CHIP_BORDER, 2, true, 0, 0)
	_show_tab.pressed.connect(func(): _set_hidden(false))
	_show_tab.visible = false
	root.add_child(_show_tab)

func _h3(text: String, label_col: bool) -> Label:
	var s := UiLayout.scale_factor()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(13 * s))
	l.add_theme_color_override("font_color", UiStyle.LABEL_COL if label_col else Color.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL if label_col else Control.SIZE_FILL
	return l

# --- layout / collapse ---

# Dock the panel at the TOP of the reserved zone, sized to its CONTENT height (top-aligned,
# like the mockup) — NOT stretched to fill the column. reset_size() snaps it to its
# combined minimum, so it shrinks back when the content shrinks (e.g. selection cleared).
func _relayout() -> void:
	if _panel == null:
		return
	var s := UiLayout.scale_factor()
	var vp := get_viewport().get_visible_rect().size
	var reg := UiLayout.inspector_region(vp)
	_panel.custom_minimum_size = Vector2(reg.size.x - UiLayout.board_margin(), 0)
	_panel.position = reg.position
	_panel.reset_size()
	var tab_w := 30.0 * s
	_show_tab.custom_minimum_size = Vector2(tab_w, 64 * s)
	_show_tab.position = Vector2(vp.x - tab_w - UiLayout.board_margin(), reg.position.y)
	_show_tab.reset_size()

func _set_hidden(h: bool) -> void:
	if _hidden == h:
		return
	_hidden = h
	UiLayout.set_inspector_hidden(h)
	_panel.visible = not h
	_show_tab.visible = h
	if game_view != null:
		game_view.refit()  # board reclaims / yields the dock's width
	_relayout()

func _show_placeholder() -> void:
	_placeholder.visible = true
	_content.visible = false

# --- selection ---

func _on_tower_selected(tower) -> void:
	_selected = tower
	if _hidden:
		_set_hidden(false)  # selecting a tower always reveals the dock
	_placeholder.visible = false
	_content.visible = true
	_refresh()
	_relayout.call_deferred()  # grow to fit the stats

func _on_selection_cleared() -> void:
	_selected = null
	_show_placeholder()
	_relayout.call_deferred()  # shrink back to the placeholder height

# --- content ---

func _refresh() -> void:
	if not is_instance_valid(_selected) or not _content.visible:
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
	var ucell: Vector2i = _selected.grid_cell
	_selected.upgrade(stat)
	if build_controller != null:
		build_controller.on_local_upgrade(ucell, stat)  # relay to other players (networked)
	_refresh()

func _on_sell_pressed() -> void:
	if build_controller != null:
		build_controller.sell_selected_tower()
