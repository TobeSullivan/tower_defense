extends Node
class_name Matchmaker

# Client-side ranked matchmaker (matchmaking_orchestration.md steps 1–2). Submits a Nakama
# matchmaker ticket over the realtime socket and runs an ESCALATION schedule that widens the
# query and lowers the count floor over time (8 → 6 → 4), until the matchmaker pops a group.
# On a pop it emits matched(); phase 3c joins that group into the Nakama forming-lobby handler,
# which then points everyone at a Godot match-server room (phase 3d).
#
# Escalation timings + band widths are DIALS (need queue telemetry — orchestration §"dials"):
# tune RANKED_SCHEDULE. "Speed beats quality" — the terminal step matches anyone down to the floor.

signal matched(info)          # {match_id, token, ticket, users:[{user_id, username}]}
signal escalated(step, info)  # advanced to a wider step; info = {query, min, max}
signal failed(reason)

# (seconds_from_start, query, min_count, max_count). Floor is 4 for ranked (orchestration).
const RANKED_SCHEDULE := [
	{"at": 0.0,  "query": "+properties.mode:ranked", "min": 8, "max": 8},
	{"at": 15.0, "query": "+properties.mode:ranked", "min": 6, "max": 8},
	{"at": 30.0, "query": "+properties.mode:ranked", "min": 4, "max": 8},
]

var _socket
var _schedule: Array = []
var _string_props: Dictionary = {}
var _numeric_props: Dictionary = {}
var _ticket := ""
var _step := -1
var _elapsed := 0.0
var _running := false
var _advancing := false

func is_running() -> bool:
	return _running

func current_ticket() -> String:
	return _ticket

# Begin queueing. `schedule` defaults to the ranked escalation; pass a custom one for other modes
# or tests. string/numeric props are attached to every ticket (the query filters on the OTHER
# side's props), e.g. {"mode": "ranked"} + {"lp": 1240}.
func start(socket, schedule: Array = RANKED_SCHEDULE, string_props: Dictionary = {"mode": "ranked"}, numeric_props: Dictionary = {}) -> void:
	if _running:
		return
	_socket = socket
	_schedule = schedule
	_string_props = string_props
	_numeric_props = numeric_props
	_elapsed = 0.0
	_step = -1
	_running = true
	if not _socket.received_matchmaker_matched.is_connected(_on_matched):
		_socket.received_matchmaker_matched.connect(_on_matched)
	await _advance_to(0)

func cancel() -> void:
	_running = false
	if _socket != null and _socket.received_matchmaker_matched.is_connected(_on_matched):
		_socket.received_matchmaker_matched.disconnect(_on_matched)
	if _ticket != "" and _socket != null:
		await _socket.remove_matchmaker_async(_ticket)
	_ticket = ""

func _process(dt: float) -> void:
	if not _running or _advancing:
		return
	_elapsed += dt
	# Jump to the latest schedule step whose `at` has elapsed (skips intermediate steps if frames
	# stalled — the goal is "as wide as time allows", not stepping through each).
	var target := _step
	for i in range(_schedule.size()):
		if _elapsed >= float(_schedule[i]["at"]):
			target = i
	if target > _step:
		_advance_to(target)  # coroutine; _advancing guards re-entry

func _advance_to(step: int) -> void:
	if not _running or step <= _step or _advancing:
		return
	_advancing = true
	# Remove the previous (narrower) ticket before re-adding, so we never hold two tickets.
	if _ticket != "":
		await _socket.remove_matchmaker_async(_ticket)
		_ticket = ""
	if not _running:  # cancelled mid-await
		_advancing = false
		return
	var s: Dictionary = _schedule[step]
	var res = await _socket.add_matchmaker_async(String(s["query"]), int(s["min"]), int(s["max"]), _string_props, _numeric_props)
	if res == null or res.is_exception():
		_advancing = false
		_running = false
		failed.emit("add_matchmaker failed: %s" % (str(res.get_exception()) if res != null else "null"))
		return
	_ticket = res.ticket
	_step = step
	_advancing = false
	escalated.emit(step, {"query": String(s["query"]), "min": int(s["min"]), "max": int(s["max"])})

func _on_matched(m) -> void:
	if not _running:
		return
	_running = false
	_ticket = ""  # consumed by the match — don't try to remove it on cancel (would 404)
	var users: Array = []
	for u in m.users:
		users.append({"user_id": String(u.presence.user_id), "username": String(u.presence.username)})
	matched.emit({"match_id": String(m.match_id), "token": String(m.token), "ticket": String(m.ticket), "users": users})
