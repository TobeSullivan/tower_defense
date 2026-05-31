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

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(140, 44)
	cancel.add_theme_font_size_override("font_size", 16)
	cancel.pressed.connect(_close_confirm)
	row.add_child(cancel)

	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.custom_minimum_size = Vector2(140, 44)
	confirm.add_theme_font_size_override("font_size", 16)
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
	panel.custom_minimum_size = min_size
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(on_pressed)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l
