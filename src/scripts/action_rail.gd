extends CanvasLayer
class_name ActionRail

# Right-side action rail (part of the reserved UI frame). Docked to the right edge,
# never overlapping the play area. Holds:
#   - Actions: Build toggle, Start Round, Speed (fast-forward).
#   - Tower inspector: shown when a tower is selected (build_controller emits
#     tower_selected / selection_cleared) — the 6-stat upgrade UI that used to float
#     over the board (upgrade_panel.gd), now docked here so it can't cover towers.
#   - Objectives: Bronze/Silver/Gold + current score when nothing is selected
#     (Campaign/PVE only), else a short controls hint.
#
# Owns the run-phase fast-forward (moved off the HUD). Untyped refs avoid the
# class-name cycle pitfall noted in project memory.

const UiLayout := preload("res://scripts/ui_layout.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

const STATS := ["damage", "range", "attack_speed", "crit_chance", "crit_damage", "multishot"]
const STAT_LABELS := {
	"damage": "Damage", "range": "Range", "attack_speed": "Atk Speed",
	"crit_chance": "Crit Chance", "crit_damage": "Crit Damage", "multishot": "Multishot",
}
const TILE_PX := 48.0

const FF_MULTS := [1.0, 2.0, 3.0]

var round_manager       # RoundManager
var build_controller    # BuildController
var pause_menu          # PauseMenu — drives the on-screen Pause button (no Esc on mobile)

var _ff_index: int = 0
var _selected_tower
var _last_build_mode: bool = false

var _build_button: Button
var _start_button: Button
var _ff_button: Button

var _inspector: VBoxContainer
var _insp_title: Label
var _insp_stats: Label
var _stat_tier_labels: Dictionary = {}
var _stat_value_labels: Dictionary = {}
var _stat_buttons: Dictionary = {}

var _objectives: VBoxContainer
var _obj_score: Label
var _obj_rows: Array = []

# Touch build-confirm prompt (shown when build_controller parks a preview).
var _build_prompt: VBoxContainer
var _build_prompt_label: Label
var _build_confirm_button: Button

func _ready() -> void:
	layer = 10
	_build_ui()
	if build_controller != null:
		build_controller.tower_selected.connect(_on_tower_selected)
		build_controller.selection_cleared.connect(_on_selection_cleared)
		build_controller.build_pending.connect(_on_build_pending)
		build_controller.build_pending_cleared.connect(_on_build_pending_cleared)
	if round_manager != null:
		round_manager.gold_changed.connect(func(_g): _refresh_inspector(); _refresh_objectives())
		round_manager.phase_changed.connect(func(_p): _refresh_actions(); _refresh_inspector(); _apply_time_scale())
		round_manager.damage_dealt_changed.connect(func(_d): _refresh_objectives())
		if _is_pvp() and round_manager.coordinator != null:
			round_manager.coordinator.ready_changed.connect(_refresh_actions)
	_show_selection(null)
	_refresh_actions()
	_refresh_objectives()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -UiLayout.right_rail_w()
	panel.offset_right = 0.0
	panel.offset_top = UiLayout.top_bar_h()
	panel.offset_bottom = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyle.apply_panel(panel, 0)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# --- Actions ---
	var pause_button := _action_button("Pause", _on_pause_pressed)
	vbox.add_child(pause_button)

	_build_button = _action_button("Build  [B]", _on_build_pressed)
	UiStyle.style_primary_button(_build_button)
	# On touch you build by tapping the map directly (no mode toggle), so the Build
	# button is desktop-only. The mouse path still uses it.
	_build_button.visible = not DisplayServer.is_touchscreen_available()
	vbox.add_child(_build_button)
	_start_button = _action_button("Start Round", _on_start_pressed)
	UiStyle.style_primary_button(_start_button)
	vbox.add_child(_start_button)
	# No fast-forward in PVP — it's a lockstep multiplayer match.
	if not _is_pvp():
		_ff_button = _action_button("Speed: 1x", _on_ff_pressed)
		vbox.add_child(_ff_button)

	vbox.add_child(HSeparator.new())

	# --- Touch build-confirm prompt (hidden until a preview is parked) ---
	_build_prompt = VBoxContainer.new()
	_build_prompt.add_theme_constant_override("separation", 6)
	_build_prompt.visible = false
	vbox.add_child(_build_prompt)
	_build_prompt_label = _label("Build here", 16, Color(0.8, 1.0, 0.85))
	_build_prompt.add_child(_build_prompt_label)
	var bp_row := HBoxContainer.new()
	bp_row.add_theme_constant_override("separation", 6)
	_build_confirm_button = _action_button("Build", _on_confirm_build)
	UiStyle.style_primary_button(_build_confirm_button)
	_build_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp_row.add_child(_build_confirm_button)
	var cancel_button := _action_button("Cancel", _on_cancel_build)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp_row.add_child(cancel_button)
	_build_prompt.add_child(bp_row)

	# --- Tower inspector (hidden until a tower is selected) ---
	_inspector = VBoxContainer.new()
	_inspector.add_theme_constant_override("separation", 5)
	vbox.add_child(_inspector)

	_insp_title = _label("Tower", 18, Color.WHITE)
	_inspector.add_child(_insp_title)
	_insp_stats = _label("", 14, Color(1.0, 0.9, 0.5))
	_inspector.add_child(_insp_stats)
	_inspector.add_child(HSeparator.new())

	for stat in STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var s := UiLayout.scale_factor()
		var name_label := _label(STAT_LABELS[stat], 14, Color(0.85, 0.9, 1.0))
		name_label.custom_minimum_size = Vector2(96, 44) * s
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)

		var tier_label := _label("T0", 14, Color.WHITE)
		tier_label.custom_minimum_size = Vector2(28, 44) * s
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_stat_tier_labels[stat] = tier_label
		row.add_child(tier_label)

		var value_label := _label("—", 14, Color(0.7, 0.9, 1.0))
		value_label.custom_minimum_size = Vector2(58, 44) * s
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_stat_value_labels[stat] = value_label
		row.add_child(value_label)

		var button := Button.new()
		button.text = "+"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44) * s
		button.pressed.connect(_on_upgrade_pressed.bind(stat))
		_stat_buttons[stat] = button
		row.add_child(button)

		_inspector.add_child(row)

	var sell_button := _action_button("Sell Tower", _on_sell_pressed)
	_inspector.add_child(sell_button)

	# --- Objectives (shown when nothing is selected) ---
	_objectives = VBoxContainer.new()
	_objectives.add_theme_constant_override("separation", 5)
	vbox.add_child(_objectives)
	_build_objectives()

func _action_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	var s := UiLayout.scale_factor()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52 * s)  # finger-friendly tap target
	b.add_theme_font_size_override("font_size", int(18 * s))
	b.pressed.connect(cb)
	return b

# --- Selection / inspector ---

func _on_tower_selected(tower) -> void:
	_selected_tower = tower
	_show_selection(tower)

func _on_selection_cleared() -> void:
	_selected_tower = null
	_show_selection(null)

# --- Touch build-confirm prompt ---

func _on_build_pending(_cell, cost: int, affordable: bool) -> void:
	_build_prompt.visible = true
	_build_prompt_label.text = "Build here — %dg" % cost
	_build_confirm_button.disabled = not affordable
	_objectives.visible = false  # prompt takes over the panel while previewing

func _on_build_pending_cleared() -> void:
	_build_prompt.visible = false
	_show_selection(_selected_tower)  # restore inspector / objectives

func _on_confirm_build() -> void:
	if build_controller != null:
		build_controller.confirm_pending_build()

func _on_cancel_build() -> void:
	if build_controller != null:
		build_controller.cancel_pending_build()

func _on_sell_pressed() -> void:
	if build_controller != null:
		build_controller.sell_selected_tower()

func _show_selection(tower) -> void:
	var has := tower != null and is_instance_valid(tower)
	_inspector.visible = has
	_objectives.visible = not has and _has_objectives()
	if has:
		_refresh_inspector()

func _refresh_inspector() -> void:
	if not _inspector.visible or not is_instance_valid(_selected_tower):
		return
	var in_build: bool = round_manager == null or round_manager.phase == "build"
	var gold: int = round_manager.gold if round_manager != null else 99999
	_insp_stats.text = "Damage done: %d   ·   Kills: %d" % [int(_selected_tower.damage_done), _selected_tower.kills]
	for stat in STATS:
		_stat_tier_labels[stat].text = "T%d" % _selected_tower.tiers[stat]
		_stat_value_labels[stat].text = _effective_value(stat)
		var button: Button = _stat_buttons[stat]
		var cost: int = _selected_tower.upgrade_cost(stat)
		if cost <= 0:
			button.text = "MAX"
			button.disabled = true
		else:
			button.text = "+ %dg" % cost
			button.disabled = (not in_build) or (gold < cost)

func _effective_value(stat: String) -> String:
	var t = _selected_tower
	match stat:
		"damage":       return "%.0f" % t.get_damage()
		"range":        return "%.1ft" % (t.get_range() / TILE_PX)
		"attack_speed": return "%.2f/s" % (1.0 / t.get_cooldown())
		"crit_chance":  return "%d%%" % int(round(t.get_crit_chance() * 100.0))
		"crit_damage":  return "x%.2f" % t.get_crit_damage_mult()
		"multishot":    return "%d tgt" % (1 + t.get_multishot())
	return "—"

func _on_upgrade_pressed(stat: String) -> void:
	if not is_instance_valid(_selected_tower):
		return
	if round_manager != null and round_manager.phase != "build":
		return
	var cost: int = _selected_tower.upgrade_cost(stat)
	if cost <= 0:
		return
	if round_manager != null and not round_manager.spend(cost):
		return
	_selected_tower.upgrade(stat)
	_refresh_inspector()

func _process(_delta: float) -> void:
	# Live damage/kills while inspecting (e.g. watching a tower during the run), and
	# keep the Build button label in sync with build mode.
	if _inspector.visible and is_instance_valid(_selected_tower):
		_insp_stats.text = "Damage done: %d   ·   Kills: %d" % [int(_selected_tower.damage_done), _selected_tower.kills]
	if build_controller != null:
		var bm: bool = build_controller.is_build_mode()
		if bm != _last_build_mode:
			_last_build_mode = bm
			_build_button.text = "Exit Build  [B]" if bm else "Build  [B]"

# --- Actions ---

func _on_pause_pressed() -> void:
	if pause_menu != null:
		pause_menu.toggle_pause()

func _on_build_pressed() -> void:
	if build_controller != null:
		build_controller.toggle_build_mode()

func _on_start_pressed() -> void:
	if round_manager == null:
		return
	if _is_pvp():
		# Toggle this board's ready vote; the coordinator starts the run once every
		# board is ready, otherwise the build timer keeps running.
		var coord = round_manager.coordinator
		coord.set_board_ready(round_manager, not coord.is_board_ready(round_manager))
		_refresh_actions()
	else:
		round_manager.request_start_now()

func _is_pvp() -> bool:
	return round_manager != null and round_manager.coordinator != null and round_manager.coordinator.is_pvp

func _on_ff_pressed() -> void:
	_ff_index = (_ff_index + 1) % FF_MULTS.size()
	_ff_button.text = "Speed: %dx" % int(FF_MULTS[_ff_index])
	_apply_time_scale()

func _apply_time_scale() -> void:
	# PVP runs at 1x always (no unilateral fast-forward in a live multiplayer match).
	if _is_pvp():
		Engine.time_scale = 1.0
		return
	if round_manager != null and round_manager.phase == "run" and not round_manager.match_over:
		Engine.time_scale = FF_MULTS[_ff_index]
	else:
		Engine.time_scale = 1.0

func _refresh_actions() -> void:
	if round_manager == null:
		return
	var building: bool = round_manager.phase == "build" and not round_manager.match_over
	_start_button.visible = building
	_build_button.disabled = not building
	if _is_pvp():
		var coord = round_manager.coordinator
		var readied: bool = coord.is_board_ready(round_manager)
		_start_button.text = "%s Ready  (%d/%d)" % [
			"✓" if readied else "○", coord.ready_count(), coord.active_boards().size()]
	else:
		_start_button.text = "Start Round"
	if _ff_button != null:
		_ff_button.text = "Speed: %dx" % int(FF_MULTS[_ff_index])

# --- Objectives (Bronze/Silver/Gold) ---

func _has_objectives() -> bool:
	return round_manager != null and round_manager.gold_threshold > 0

func _build_objectives() -> void:
	if not _has_objectives():
		_objectives.add_child(_label("Build  ·  tap a tower to upgrade or sell", 13, Color(0.7, 0.75, 0.85)))
		return
	_objectives.add_child(_label("Objectives", 17, Color(0.8, 0.85, 0.96)))
	_obj_score = _label("", 15, Color(1.0, 0.95, 0.7))
	_objectives.add_child(_obj_score)
	_obj_rows = [
		{"name": "Gold", "threshold": int(round_manager.gold_threshold), "color": Color(1.0, 0.84, 0.3)},
		{"name": "Silver", "threshold": int(round_manager.silver_threshold), "color": Color(0.82, 0.86, 0.92)},
		{"name": "Bronze", "threshold": int(round_manager.bronze_threshold), "color": Color(0.86, 0.62, 0.42)},
	]
	for row in _obj_rows:
		var l := _label("", 15, row.color)
		row["label"] = l
		_objectives.add_child(l)
	_refresh_objectives()

func _refresh_objectives() -> void:
	if not _has_objectives() or _obj_score == null:
		return
	var dmg: int = round_manager.total_damage_dealt
	_obj_score.text = "Your score: %d" % dmg
	for row in _obj_rows:
		var reached: bool = dmg >= int(row.threshold)
		row.label.text = "%s   %d%s" % [row.name, int(row.threshold), "   ·  reached" if reached else ""]
		var c: Color = row.color
		if not reached:
			c = Color(c.r, c.g, c.b, 0.5)
		row.label.add_theme_color_override("font_color", c)

# --- helpers ---

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(font_size * UiLayout.scale_factor()))
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
