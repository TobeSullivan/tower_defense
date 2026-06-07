extends Node

# Live verify of the Matchmaker against the box (phase 3b). Two sessions (me + a bot), each with
# its own realtime socket and Matchmaker, submit compatible tickets — Nakama's matchmaker must pop
# them into one group and deliver `matched` to BOTH with the two expected users.
# Run by swapping run/main_scene to res://tools/matchmaker_test.tscn.

const MatchmakerScript := preload("res://scripts/matchmaker.gd")

# Single-step test schedule: match any 2 immediately (the production ranked schedule is 8→6→4 over
# 30s, which a 2-client test can't fill — the mechanism is identical).
const TEST_SCHED := [{"at": 0.0, "query": "*", "min": 2, "max": 2}]

var _fails := 0
# Captured from signals. MEMBER vars, not locals — a GDScript lambda captures locals by VALUE, so
# `func(info): got = info` would assign a throwaway copy; assigning a member mutates via `self`.
var _got_me := {}
var _got_bot := {}
var _mm_err := ""

func _ready() -> void:
	await _run()
	get_tree().quit(_fails)

func _ok(label: String, cond: bool) -> void:
	if cond:
		print("  OK  ", label)
	else:
		print("  FAIL  ", label)
		_fails += 1

func _run() -> void:
	print("=== matchmaker live verify ===")
	var connected: bool = await NakamaService.connect_backend()
	_ok("connected", connected)
	if not connected:
		print("RESULT FAIL — no session"); return
	var client = NakamaService.client
	var my_id := String(NakamaService.session.user_id)
	var my_socket = await NakamaService.ensure_socket()
	_ok("my socket connected", my_socket != null and my_socket.is_connected_to_host())

	# Second player: a bot session with its own socket.
	var bot_session = await client.authenticate_device_async("wendtest_mm_bot_padpad")
	_ok("bot authed", bot_session != null and not bot_session.is_exception())
	var bot_id := String(bot_session.user_id)
	var bot_socket = Nakama.create_socket_from(client)
	await bot_socket.connect_async(bot_session)
	_ok("bot socket connected", bot_socket.is_connected_to_host())

	var mm_me = MatchmakerScript.new(); mm_me.name = "MM_Me"; add_child(mm_me)
	var mm_bot = MatchmakerScript.new(); mm_bot.name = "MM_Bot"; add_child(mm_bot)
	mm_me.matched.connect(func(info): _got_me = info)
	mm_bot.matched.connect(func(info): _got_bot = info)
	mm_me.failed.connect(func(r): _mm_err = r)
	mm_bot.failed.connect(func(r): _mm_err = r)

	# Raw socket-level listeners — disambiguate "no match" from "matched but Matchmaker missed it".
	my_socket.received_matchmaker_matched.connect(func(m): print("    RAW my matched: users=", m.users.size(), " token?=", m.token != ""))
	bot_socket.received_matchmaker_matched.connect(func(m): print("    RAW bot matched: users=", m.users.size()))

	await mm_me.start(my_socket, TEST_SCHED, {}, {})
	await mm_bot.start(bot_socket, TEST_SCHED, {}, {})
	_ok("both tickets submitted", mm_me.current_ticket() != "" and mm_bot.current_ticket() != "")

	# Wait for the matchmaker to pop (server interval; in practice ~immediate for 2 ready tickets).
	for i in range(60):
		if not _got_me.is_empty() and not _got_bot.is_empty():
			break
		await get_tree().create_timer(0.5).timeout

	_ok("no matchmaker error", _mm_err == "")
	_ok("I was matched", not _got_me.is_empty())
	_ok("bot was matched", not _got_bot.is_empty())
	if not _got_me.is_empty():
		var ids := _ids(_got_me.get("users", []))
		_ok("my match has 2 users", (_got_me.get("users", []) as Array).size() == 2)
		_ok("my match contains me + bot", ids.has(my_id) and ids.has(bot_id))
		_ok("match carries a join token", String(_got_me.get("token", "")) != "")

	# Cleanup: drop tickets + the bot socket.
	await mm_me.cancel()
	await mm_bot.cancel()
	bot_socket.close()

	if _fails == 0:
		print("RESULT OK — matchmaker pops a group and delivers matched to both clients")
	else:
		print("RESULT FAIL — ", _fails, " check(s) failed")

func _ids(users: Array) -> Array:
	var out: Array = []
	for u in users:
		out.append(String(u.get("user_id", "")))
	return out
