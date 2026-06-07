extends Node
class_name LobbyClient

# Client side of the Nakama forming lobby (phase 3c). After the Matchmaker pops (matched.match_id),
# the client joins that authoritative "lobby" match; it then receives lobby state (X/N + who has
# voted), can cast a launch vote, and finally receives GO — the (match_id, host, port) of the Godot
# match-server room to JOIN_ROOM into (phase 3d). Authority stays in the Godot server; this lobby
# only forms the group.

signal lobby_state(info)   # {count, max, floor, mode, present, voted, you_voted}
signal launched(info)      # {match_id, host, port} — go join the Godot room
signal closed(reason)

const OP_VOTE := 1
const OP_LOBBY_STATE := 2
const OP_GO := 3

var _socket
var _match_id := ""
var _my_id := ""
var _joined := false

func join(socket, match_id: String, my_user_id: String) -> bool:
	_socket = socket
	_match_id = match_id
	_my_id = my_user_id
	if not _socket.received_match_state.is_connected(_on_state):
		_socket.received_match_state.connect(_on_state)
	var res = await _socket.join_match_async(match_id)
	if res == null or res.is_exception():
		closed.emit("join failed: %s" % (str(res.get_exception()) if res != null else "null"))
		return false
	_joined = true
	return true

func vote() -> void:
	if _joined:
		await _socket.send_match_state_async(_match_id, OP_VOTE, "")

func leave() -> void:
	if _joined and _socket != null:
		_joined = false
		await _socket.leave_match_async(_match_id)

func _on_state(d) -> void:
	if String(d.match_id) != _match_id:
		return
	var payload = JSON.parse_string(d.data)
	if typeof(payload) != TYPE_DICTIONARY:
		return
	match int(d.op_code):
		OP_LOBBY_STATE:
			payload["you_voted"] = (payload.get("voted", []) as Array).has(_my_id)
			lobby_state.emit(payload)
		OP_GO:
			launched.emit(payload)
