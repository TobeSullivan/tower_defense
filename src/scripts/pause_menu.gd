extends CanvasLayer
class_name PauseMenu

# In-match pause menu (DESIGN_MODES "Pause menu"). Owns the Esc priority stack:
#   1. upgrade panel open  → Esc closes it
#   2. build mode active   → Esc exits build mode
#   3. neither             → Esc opens this menu (Esc again resumes)
# build_controller no longer handles Esc; this is the single arbiter.
#
# Single player (campaign / solo PVE) pauses the scene tree while open. Multiplayer
# (PVP / group PVE) does NOT pause — the match continues — and shows "Quit Match"
# instead of Restart + Quit to Menu.

const MapResourceScript := preload("res://resources/map_resource.gd")
const SettingsPanelScript := preload("res://scripts/settings_panel.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const UiLayout := preload("res://scripts/ui_layout.gd")

var build_controller  # BuildController — untyped to avoid class-name cycle
var round_manager     # RoundManager — untyped to avoid class-name cycle

var is_multiplayer := false
var _settings

var _open := false
var _dim: ColorRect
var _menu_panel: PanelContainer
var _confirm_dim: ColorRect
var _confirm_panel: PanelContainer
var _confirm_label: Label
var _pending_confirm: Callable = Callable()

# Objectives readout (Bronze/Silver/Gold) — Campaign & PVE only; PVP has no medals.
var _obj_score: Label
var _obj_rows: Array = []  # [{name, threshold, color, label}]

func _ready() -> void:
	layer = 30  # above HUD/upgrade panel; match-end/win guard prevents stacking
	process_mode = Node.PROCESS_MODE_ALWAYS  # must work while the tree is paused
	is_multiplayer = SceneManager.current_is_multiplayer
	_build_ui()
	_settings = SettingsPanelScript.new()
	add_child(_settings)

func _build_ui() -> void:
	_dim = _make_dim()
	add_child(_dim)

	_menu_panel = _make_centered_panel(Vector2(300, 0))
	add_child(_menu_panel)
	_populate_menu()

	# Confirm overlay sits on top of the menu, with its own click-blocking dim.
	_confirm_dim = _make_dim()
	add_child(_confirm_dim)
	_confirm_panel = _make_centered_panel(Vector2(380, 0))
	add_child(_confirm_panel)
	_populate_confirm()

	_dim.visible = false
	_menu_panel.visible = false
	_confirm_dim.visible = false
	_confirm_panel.visible = false

func _populate_menu() -> void:
	var vbox := _panel_vbox(_menu_panel)

	var title := _label("Paused", 28, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(_spacer(8))

	_build_objectives(vbox)

	vbox.add_child(_menu_button("Resume", _resume))

	vbox.add_child(_menu_button("Settings", func(): _settings.open()))

	if not is_multiplayer:
		vbox.add_child(_menu_button("Restart", _on_restart))
		vbox.add_child(_menu_button("Quit to Menu", _on_quit))
	else:
		vbox.add_child(_menu_button("Quit Match", _on_quit))

func _populate_confirm() -> void:
	var vbox := _panel_vbox(_confirm_panel)

	_confirm_label = _label("", 18, Color.WHITE)
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.custom_minimum_size = Vector2(340, 0)
	vbox.add_child(_confirm_label)
	vbox.add_child(_spacer(8))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var s := UiLayout.scale_factor()
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(140, 44) * s
	cancel.add_theme_font_size_override("font_size", int(16 * s))
	cancel.pressed.connect(_close_confirm)
	row.add_child(cancel)

	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.custom_minimum_size = Vector2(140, 44) * s
	confirm.add_theme_font_size_override("font_size", int(16 * s))
	confirm.pressed.connect(_on_confirm_yes)
	row.add_child(confirm)

# --- Esc arbitration ---

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ESCAPE:
		return
	_handle_escape()
	get_viewport().set_input_as_handled()

func _handle_escape() -> void:
	# Settings overlay sits on top of everything — Esc closes it first.
	if _settings != null and _settings.is_open():
		_settings.close()
		return
	if _confirm_panel.visible:
		_close_confirm()
		return
	if _open:
		_resume()
		return
	if build_controller != null and build_controller.is_upgrade_panel_open():
		build_controller.close_upgrade_panel()
		return
	if build_controller != null and build_controller.is_build_mode():
		build_controller.exit_build_mode()
		return
	if _can_open():
		_open_menu()

func _can_open() -> bool:
	# Don't open over the match-end / win panels (which already pause in SP).
	if round_manager != null and round_manager.match_over:
		return false
	if not is_multiplayer and get_tree().paused:
		return false
	return true

func _open_menu() -> void:
	_open = true
	_refresh_objectives()  # reflect the score as of this open (live in group PVE)
	_dim.visible = true
	_menu_panel.visible = true
	if not is_multiplayer:
		get_tree().paused = true

func _resume() -> void:
	_open = false
	_close_confirm()
	_dim.visible = false
	_menu_panel.visible = false
	if not is_multiplayer:
		get_tree().paused = false

# Public entry for the on-screen Pause button (mobile has no Esc key). Opens the
# menu, closes the topmost overlay if one is up, or resumes if already paused.
func toggle_pause() -> void:
	if _settings != null and _settings.is_open():
		_settings.close()
		return
	if _confirm_panel.visible:
		_close_confirm()
		return
	if _open:
		_resume()
	elif _can_open():
		_open_menu()

# --- Objectives (Bronze / Silver / Gold) ---

# Campaign and PVE carry medal thresholds; PVP leaves them at 0 (last-standing,
# no medals), so the objectives block is shown only when a Gold threshold exists.
func _has_objectives() -> bool:
	return round_manager != null and round_manager.gold_threshold > 0

func _build_objectives(vbox: VBoxContainer) -> void:
	if not _has_objectives():
		return

	var header := _label("Objectives", 18, Color(0.78, 0.84, 0.96))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	_obj_score = _label("", 16, Color(1.0, 0.95, 0.7))
	_obj_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_obj_score)

	_obj_rows = [
		{"name": "Gold", "threshold": int(round_manager.gold_threshold), "color": Color(1.0, 0.84, 0.3)},
		{"name": "Silver", "threshold": int(round_manager.silver_threshold), "color": Color(0.82, 0.86, 0.92)},
		{"name": "Bronze", "threshold": int(round_manager.bronze_threshold), "color": Color(0.86, 0.62, 0.42)},
	]
	for row in _obj_rows:
		var l := _label("", 16, row.color)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row["label"] = l
		vbox.add_child(l)

	vbox.add_child(_spacer(10))
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
			c = Color(c.r, c.g, c.b, 0.5)  # dim the targets not yet hit
		row.label.add_theme_color_override("font_color", c)

# --- Confirm dialog ---

func _ask_confirm(message: String, on_confirm: Callable) -> void:
	_confirm_label.text = message
	_pending_confirm = on_confirm
	_confirm_dim.visible = true
	_confirm_panel.visible = true

func _close_confirm() -> void:
	_confirm_dim.visible = false
	_confirm_panel.visible = false
	_pending_confirm = Callable()

func _on_confirm_yes() -> void:
	var cb := _pending_confirm
	_close_confirm()
	# SceneManager unpauses the tree itself on transition.
	if cb.is_valid():
		cb.call()

# --- Menu actions ---

func _on_restart() -> void:
	_ask_confirm("Restart this mission? Your progress will be lost.",
		func(): SceneManager.restart_current_match())

func _on_quit() -> void:
	_ask_confirm(_quit_message(), func(): SceneManager.leave_match_to_home(_current_damage()))

func _current_damage() -> int:
	return round_manager.total_damage_dealt if round_manager != null else 0

func _quit_message() -> String:
	if not is_multiplayer:
		# Single-player (campaign / solo PVE): the result so far is recorded on quit.
		return "Quit to the main menu? Your score so far is saved."
	if _is_pvp():
		return "Quit the match? You will be eliminated and your lives will leave the pool."
	return "Quit the match? Your score will not be posted."

func _is_pvp() -> bool:
	var map = SceneManager.pending_map
	return map != null and map.mode == MapResourceScript.Mode.PVP

# --- UI helpers ---

func _make_dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks to the match below
	return dim

func _make_centered_panel(min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size * UiLayout.scale_factor()
	# Anchor to the screen centre and grow in both directions so the panel stays
	# truly centred as it sizes to its content. PRESET_CENTER froze the offsets
	# from the panel's size at build time — before any children were added, so
	# height was 0 — which left the finished menu sitting low and off-centre.
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyle.apply_panel(panel, 12)
	return panel

func _panel_vbox(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	return vbox

func _menu_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	var s := UiLayout.scale_factor()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48 * s)
	b.add_theme_font_size_override("font_size", int(18 * s))
	b.pressed.connect(on_pressed)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(font_size * UiLayout.scale_factor()))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l
