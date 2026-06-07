extends Node

# Headless verify of NakamaService's device-auth round-trip against the LIVE box (:7350).
# Run by temporarily swapping run/main_scene to res://tools/nakama_auth_test.tscn (the positional
# scene arg silently no-ops — see memory reference_godot_headless_verify) and capture stderr:
#   $env path: & "C:\Users\tobes\Desktop\Godot.exe" --headless --path src  (with main_scene swapped)
# Proves: NakamaService configured -> device auth -> getAccount -> realtime socket, all real.

var _fails := 0

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
	print("=== Nakama auth round-trip (", NakamaService.is_configured(), ") ===")
	_ok("NakamaService configured (nakama_local.cfg present, key set)", NakamaService.is_configured())
	if not NakamaService.is_configured():
		print("RESULT FAIL — not configured")
		return

	var connected: bool = await NakamaService.connect_backend()
	_ok("connect_backend() succeeded", connected)
	_ok("has_session()", NakamaService.has_session())
	if not NakamaService.has_session():
		print("RESULT FAIL — no session")
		return

	var sess: NakamaSession = NakamaService.session
	_ok("session token non-empty", sess.token != "")
	_ok("session has user_id", sess.user_id != "")
	print("    user_id=", sess.user_id, "  username=", sess.username)

	var account = await NakamaService.get_account_async()
	_ok("get_account_async() returned an object", account != null)
	if account != null:
		_ok("account is not an exception", not account.is_exception())
		_ok("account.user.id == session.user_id", account.user.id == sess.user_id)
		print("    account.user.id=", account.user.id, "  username=", account.user.username, "  create_time=", account.user.create_time)

	# Bonus: realtime socket (the matchmaking transport). Proves the WS path too.
	var sock = await NakamaService.ensure_socket()
	_ok("realtime socket connected", sock != null and sock.is_connected_to_host())

	if _fails == 0:
		print("RESULT OK — device auth + getAccount + socket against :7350")
	else:
		print("RESULT FAIL — ", _fails, " check(s) failed")
