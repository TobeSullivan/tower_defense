extends Control

# PVP lobby — a thin CLIENT of the dedicated match server (src/net/match_server.gd on a
# headless VPS). The old P2P "Host / Join by IP" model is gone: everyone connects to the
# same server, which owns the authoritative player list + seats and starts the match.
#   CONNECT — name field, Play Online, Back.
#   ROOM    — player list; the leader (first to join) gets Start; Leave.
# 4-digit room codes (multiple lobbies on one server) are the next step; for now everyone
# who connects shares the single lobby. Built from the locked visual system (ui_style.gd).

const UiStyle := preload("res://scripts/ui_style.gd")
const NetProtocol := preload("res://net/net_protocol.gd")

# Server the client dials: the live Hetzner dedicated server (Ashburn, UDP 8771 — see
# deploy/README.md). Overridable via the MBTD_SERVER env var, e.g. MBTD_SERVER=127.0.0.1
# to dev against a local headless server (godot --headless -- --server).
const DEFAULT_SERVER := "5.78.110.182"

var _t                                  # MatchTransport (from SceneManager)
var _my_id := 1
var _my_seat := 0
var _leader_id := 0
var _players: Array = []                # [{id, name, seat}] — mirror of the server's list

# UI
var _card: PanelContainer
var _connect_box: VBoxContainer
var _room_box: VBoxContainer
var _name_edit: LineEdit
var _status: Label
var _rows: VBoxContainer
var _start_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.menu_backdrop(self)
	_build_ui()
	_name_edit.text = SceneManager.last_player_name
	# Returning from a finished match still connected to the dedicated server: skip the
	# connect step, go straight to the room, and re-register so the server (which has reset
	# to its lobby) resends the current state.
	if SceneManager.transport != null:
		_t = SceneManager.transport
		_my_id = _t.unique_id()
		_wire_transport()
		_show_room()
		_t.send_to_authority({"t": NetProtocol.SET_NAME, "name": _my_name()})
	else:
		_show_connect()

func _server_address() -> String:
	var env := OS.get_environment("MBTD_SERVER")
	return env if env != "" else DEFAULT_SERVER

# ============================================================================
# UI
# ============================================================================

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	UiStyle.apply_card(_card)
	_card.custom_minimum_size = Vector2(440, 0)
	center.add_child(_card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_card.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := _label("MULTIPLAYER", 30, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_status = _label("", 15, UiStyle.LABEL_COL)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)

	_connect_box = _build_connect_box()
	col.add_child(_connect_box)

	_room_box = _build_room_box()
	col.add_child(_room_box)

func _build_connect_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)

	box.add_child(_field_label("Your name"))
	_name_edit = LineEdit.new()
	_name_edit.text = "Player"
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 40)
	box.add_child(_name_edit)

	var play_btn := Button.new()
	play_btn.text = "Play Online"
	play_btn.add_theme_font_size_override("font_size", 18)
	UiStyle.style_hero_button(play_btn)
	play_btn.pressed.connect(_on_play_online_pressed)
	box.add_child(play_btn)

	box.add_child(_spacer(6))
	var back := Button.new()
	back.text = "← Back"
	back.add_theme_font_size_override("font_size", 15)
	UiStyle.style_menu_button(back)
	back.pressed.connect(_on_back_pressed)
	box.add_child(back)
	return box

func _build_room_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.visible = false

	var hdr := _label("PLAYERS", 14, UiStyle.LABEL_COL)
	box.add_child(hdr)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	box.add_child(_rows)

	box.add_child(_spacer(4))

	_start_btn = Button.new()
	_start_btn.text = "Start"
	_start_btn.add_theme_font_size_override("font_size", 18)
	UiStyle.style_go_button(_start_btn)
	_start_btn.pressed.connect(_on_start_pressed)
	box.add_child(_start_btn)

	var leave := Button.new()
	leave.text = "Leave"
	leave.add_theme_font_size_override("font_size", 15)
	UiStyle.style_danger_button(leave)
	leave.pressed.connect(_on_leave_pressed)
	box.add_child(leave)
	return box

func _show_connect() -> void:
	_connect_box.visible = true
	_room_box.visible = false

func _show_room() -> void:
	_connect_box.visible = false
	_room_box.visible = true
	_refresh_room()

# ============================================================================
# Connect / leave
# ============================================================================

func _on_play_online_pressed() -> void:
	SceneManager.last_player_name = _my_name()  # remembered across re-queue
	var err = SceneManager.net_join(_server_address())
	if err != OK:
		_status.text = "Could not reach server (error %d)" % err
		return
	_t = SceneManager.transport
	_wire_transport()
	_status.text = "Connecting to %s…" % _server_address()
	_show_room()

func _on_back_pressed() -> void:
	SceneManager.net_close()
	SceneManager.goto_home()

func _on_leave_pressed() -> void:
	SceneManager.net_close()
	_t = null
	_players = []
	_leader_id = 0
	_status.text = ""
	_show_connect()

# ============================================================================
# Transport wiring (client only — the server owns the lobby authority)
# ============================================================================

func _wire_transport() -> void:
	_t.received.connect(_on_received)
	_t.connection_succeeded.connect(_on_connected)
	_t.connection_failed.connect(_on_conn_failed)
	_t.server_closed.connect(_on_server_closed)

func _on_connected() -> void:
	_my_id = _t.unique_id()
	_status.text = "Connected — waiting for players"
	_t.send_to_authority({"t": NetProtocol.SET_NAME, "name": _my_name()})

func _on_conn_failed() -> void:
	_status.text = "Connection failed"
	SceneManager.net_close()
	_t = null
	_show_connect()

func _on_server_closed() -> void:
	_status.text = "Lost connection to server"
	SceneManager.net_close()
	_t = null
	_show_connect()

func _on_received(_from_id: int, msg: Dictionary) -> void:
	match msg.get("t", ""):
		NetProtocol.LOBBY_STATE:
			_players = msg.get("players", [])
			_leader_id = int(msg.get("host_id", 0))
			_my_seat = _seat_of(_my_id)
			_refresh_room()
		NetProtocol.START_MATCH:
			_my_seat = _seat_of(_my_id)
			SceneManager.start_networked_pvp(msg["seed"], msg["tier"], msg["count"], _my_seat, msg["names"])

# ============================================================================
# Start (leader only — asks the server to begin)
# ============================================================================

func _on_start_pressed() -> void:
	if not _is_leader() or _players.size() < 2:
		return
	_t.send_to_authority({"t": NetProtocol.PLAY})

# ============================================================================
# Helpers
# ============================================================================

func _is_leader() -> bool:
	return _my_id == _leader_id

func _seat_of(id: int) -> int:
	for p in _players:
		if int(p["id"]) == id:
			return int(p["seat"])
	return 0

func _refresh_room() -> void:
	if _rows == null:
		return
	for c in _rows.get_children():
		c.queue_free()
	var ordered: Array = _players.duplicate()
	ordered.sort_custom(func(a, b): return int(a["seat"]) < int(b["seat"]))
	for p in ordered:
		_rows.add_child(_player_row(p))
	# Status: only the leader can start; everyone else waits.
	if _is_leader():
		if _players.size() < 2:
			_status.text = "Waiting for players (need 2+)"
		else:
			_status.text = "%d players — press Start" % _players.size()
	else:
		_status.text = "%d players — waiting for the leader to start" % maxi(_players.size(), 1)
	_start_btn.visible = _is_leader()
	_start_btn.disabled = _players.size() < 2

func _player_row(p: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	var is_me := int(p["id"]) == _my_id
	row.add_theme_stylebox_override("panel", UiStyle.pill_box())
	if is_me:
		row.modulate = Color(0.78, 1.0, 0.78)  # tint your own row green-ish

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 7)
	m.add_theme_constant_override("margin_bottom", 7)
	row.add_child(m)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	m.add_child(hb)

	var seat_lbl := _label("%d" % (int(p["seat"]) + 1), 15, UiStyle.LABEL_COL)
	seat_lbl.custom_minimum_size = Vector2(22, 0)
	hb.add_child(seat_lbl)

	var tag := ""
	if int(p["id"]) == _leader_id:
		tag = "  (leader)"
	if is_me:
		tag += "  (you)"
	var name_lbl := _label(String(p["name"]) + tag, 16, Color.WHITE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(name_lbl)
	return row

func _my_name() -> String:
	var n := _name_edit.text.strip_edges() if _name_edit != null else "Player"
	return n.substr(0, 16) if n != "" else "Player"

func _field_label(text: String) -> Label:
	return _label(text, 13, UiStyle.LABEL_COL)

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	return l
