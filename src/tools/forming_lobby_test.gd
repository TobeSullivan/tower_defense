extends Node

# End-to-end verify of the forming lobby (phase 3c) against the live box. Four sessions queue in
# TWO matchmaker pops: the first pop creates a lobby, the second must ACCRETE into the SAME lobby
# (not spawn a new one). Then a unanimous-of-present vote at the floor (4) launches → all four
# receive GO with the Godot room's match_id + host + port. Proves: matchmaker→lobby routing,
# accretion, vote-launch, and the handoff payload. Run via res://tools/forming_lobby_test.tscn.

const MatchmakerScript := preload("res://scripts/matchmaker.gd")
const LobbyClientScript := preload("res://scripts/lobby_client.gd")
const TEST_SCHED := [{"at": 0.0, "query": "*", "min": 2, "max": 2}]  # pops of exactly 2

var _fails := 0
var _sessions: Array = []
var _sockets: Array = []
var _mms: Array = []
var _lobbies: Array = []
var _mid: Array = []     # lobby match_id seen by each player
var _count: Array = []   # latest lobby count seen by each player
var _go: Array = []      # GO payload received by each player

func _ready() -> void:
	await _run()
	get_tree().quit(_fails)

func _ok(label: String, cond: bool) -> void:
	print("  ", "OK  " if cond else "FAIL  ", label)
	if not cond:
		_fails += 1

func _run() -> void:
	print("=== forming lobby E2E ===")
	var connected: bool = await NakamaService.connect_backend()
	_ok("connected", connected)
	if not connected:
		return
	var client = NakamaService.client

	for i in range(4):
		var session
		var socket
		if i == 0:
			session = NakamaService.session
			socket = await NakamaService.ensure_socket()
		else:
			session = await client.authenticate_device_async("wendtest_lobby_b%d_padpad" % i)
			socket = Nakama.create_socket_from(client)
			await socket.connect_async(session)
		_sessions.append(session); _sockets.append(socket)
		_mid.append(""); _count.append(0); _go.append({})
		var mm = MatchmakerScript.new(); mm.name = "MM%d" % i; add_child(mm)
		var lobby = LobbyClientScript.new(); lobby.name = "Lobby%d" % i; add_child(lobby)
		_mms.append(mm); _lobbies.append(lobby)
		mm.matched.connect(_on_matched.bind(i))
		lobby.lobby_state.connect(_on_state.bind(i))
		lobby.launched.connect(_on_go.bind(i))
	_ok("4 sockets connected", _sockets.all(func(s): return s != null and s.is_connected_to_host()))

	# Wave 1 — players 0,1 form a lobby.
	await _mms[0].start(_sockets[0], TEST_SCHED, {}, {})
	await _mms[1].start(_sockets[1], TEST_SCHED, {}, {})
	_ok("wave 1 formed a lobby of 2", await _until(func(): return _count[0] >= 2 and _count[1] >= 2, 25.0))
	var L := String(_mid[0])
	_ok("both wave-1 players in the same lobby", L != "" and _mid[1] == L)

	# Wave 2 — players 2,3 must ACCRETE into L (the open lobby), not a new one.
	await get_tree().create_timer(2.0).timeout  # let the lobby register in matchList
	await _mms[2].start(_sockets[2], TEST_SCHED, {}, {})
	await _mms[3].start(_sockets[3], TEST_SCHED, {}, {})
	_ok("lobby accreted to 4 (second pop joined the SAME lobby)",
		await _until(func(): return _count.all(func(c): return c >= 4), 30.0))
	_ok("wave-2 players landed in lobby L", _mid[2] == L and _mid[3] == L)

	# Unanimous-of-present vote at the floor (4) → launch.
	for i in range(4):
		await _lobbies[i].vote()
	_ok("all 4 received GO after unanimous vote",
		await _until(func(): return _go.all(func(g): return not g.is_empty()), 15.0))
	var gid := String(_go[0].get("match_id", ""))
	_ok("GO carries a Godot room match_id", gid != "")
	_ok("all four GO match_ids identical",
		String(_go[1].get("match_id")) == gid and String(_go[2].get("match_id")) == gid and String(_go[3].get("match_id")) == gid)
	_ok("GO host is the match server", String(_go[0].get("host", "")) == "5.78.110.182")
	_ok("GO port is 8771", int(_go[0].get("port", 0)) == 8771)

	for i in range(4):
		await _lobbies[i].leave()
	for i in range(1, 4):
		_sockets[i].close()

	if _fails == 0:
		print("RESULT OK — matchmaker→lobby routing, accretion, unanimous vote-launch, handoff payload")
	else:
		print("RESULT FAIL — ", _fails, " check(s) failed")

func _on_matched(info, idx) -> void:
	_mid[idx] = String(info.get("match_id", ""))
	await _lobbies[idx].join(_sockets[idx], _mid[idx], String(_sessions[idx].user_id))

func _on_state(info, idx) -> void:
	_count[idx] = int(info.get("count", 0))

func _on_go(info, idx) -> void:
	_go[idx] = info

func _until(cond: Callable, max_secs: float) -> bool:
	var waited := 0.0
	while waited < max_secs:
		if cond.call():
			return true
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	return cond.call()
