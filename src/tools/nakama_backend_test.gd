extends Node

# Live verify of NakamaBackend against the box :7350 — proves the 3 leaderboard surfaces light
# up with REAL server data through LeaderboardService. Seeds a small field (3 bot accounts + me)
# on a DAILY trials board (self-purges at the UTC reset), campaign_m01, and the build's ranked
# season board, then reads
# back through the service (now on NakamaBackend) and asserts ranks / neighborhood / banding.
# Run by swapping run/main_scene to res://tools/nakama_backend_test.tscn. Test records are deleted
# afterward by the SSH cleanup step in the session (psql), so boards return to empty.

# Board ids follow the build's beta flags (LeaderboardService.BETA / SaveData.BUILD_SEASON) so
# this harness exercises whichever board set the box currently serves (beta or launch).
var TRIALS: String = LeaderboardService.trials_board_id(0, 1, "solo")  # daily/thread/solo
const CAMP := "campaign_m01"
var RANKED: String = "ranked_s%d" % SaveData.BUILD_SEASON

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
	print("=== NakamaBackend live verify ===")
	var connected: bool = await NakamaService.connect_backend()
	_ok("connect_backend()", connected)
	if not connected:
		print("RESULT FAIL — no session")
		return
	_ok("backend is NakamaBackend", LeaderboardService.backend() is NakamaBackend)

	var client = NakamaService.client
	var me = NakamaService.session
	# Make the service report my local best for the daily/thread board (mirrors a real match write).
	SaveData.record_pve_score(LeaderboardService.window_date(0), 1, 1750000)

	# 3 bot competitors (fixed device ids → idempotent across reruns).
	var b0 = await _bot(client, 0)
	var b1 = await _bot(client, 1)
	var b2 = await _bot(client, 2)
	_ok("3 bot accounts authed", b0 != null and b1 != null and b2 != null
		and not b0.is_exception() and not b1.is_exception() and not b2.is_exception())

	# Seed scores. Trials/campaign = "best", ranked = "set".
	var s := true
	s = await _submit(client, b0, "trials", TRIALS, 2000000) and s
	s = await _submit(client, b1, "trials", TRIALS, 1500000) and s
	s = await _submit(client, b2, "trials", TRIALS, 1000000) and s
	s = await _submit(client, me, "trials", TRIALS, 1750000) and s
	s = await _submit(client, b0, "campaign", CAMP, 142000) and s
	s = await _submit(client, me, "campaign", CAMP, 88000) and s
	s = await _submit(client, b0, "ranked", RANKED, 2240) and s   # Masters 1840
	s = await _submit(client, b1, "ranked", RANKED, 277) and s    # Gold 77
	s = await _submit(client, me, "ranked", RANKED, 250) and s    # Gold 50
	_ok("all submit_score RPCs ok", s)

	# --- Reads through LeaderboardService (NakamaBackend active) ---
	print("trials:")
	var tb: Dictionary = await LeaderboardService.trials_board(0, 1, "solo")
	var entries: Array = tb.get("entries", [])
	_ok("entries >= 4 (real field)", entries.size() >= 4)
	_ok("my_rank == 2", int(tb.get("my_rank", 0)) == 2)
	_ok("sorted ascending by rank", _sorted(entries))
	_ok("is_me flagged at rank 2", _is_me_at(entries, 2))
	_ok("top score is 2,000,000", entries.size() > 0 and int(entries[0].get("score", 0)) == 2000000)

	var tr: Dictionary = await LeaderboardService.trials_rank(0, 1, "solo")
	_ok("trials_rank == 2", int(tr.get("rank", 0)) == 2)

	var pl: Dictionary = await LeaderboardService.trials_placement(0, 1, "solo", 1750000)
	_ok("placement rank == 2", int(pl.get("rank", 0)) == 2)
	_ok("placement neighborhood non-empty", (pl.get("rows", []) as Array).size() > 0)

	print("campaign:")
	var cb: Dictionary = await LeaderboardService.campaign_board(1)
	_ok("my_score == 88000", int(cb.get("my_score", 0)) == 88000)
	_ok("entries include me at rank 2", _is_me_at(cb.get("entries", []), 2))

	print("ranked:")
	var rl: Dictionary = await LeaderboardService.ranked_ladder(1)
	var you = rl.get("you", null)
	_ok("you not null", you != null)
	if you != null:
		_ok("you.tier == Gold", String(you.get("tier", "")) == "Gold")
		_ok("you.lp == 50", int(you.get("lp", -1)) == 50)
		_ok("you.rank == 3", int(you.get("rank", 0)) == 3)
		_ok("you.to_next == 50", int(you.get("to_next", -1)) == 50)
		_ok("you.next_tier == Platinum", String(you.get("next_tier", "")) == "Platinum")
	var bands: Array = rl.get("bands", [])
	_ok("bands >= 2", bands.size() >= 2)
	_ok("Masters band present", _has_band(bands, "Masters"))
	_ok("Gold band has >= 2 rows", _band_rows(bands, "Gold") >= 2)

	if _fails == 0:
		print("RESULT OK — surfaces light up with real Nakama data (trials/campaign/ranked)")
	else:
		print("RESULT FAIL — ", _fails, " check(s) failed")

# --- helpers ---

func _bot(client, idx: int):
	return await client.authenticate_device_async("wendtest_bot_%d_padpadpad" % idx)

func _submit(client, session, kind: String, board: String, score: int) -> bool:
	var r = await client.rpc_async(session, "submit_score",
		JSON.stringify({"kind": kind, "board_id": board, "score": score}))
	return r != null and not r.is_exception()

func _sorted(entries: Array) -> bool:
	var prev := -1
	for e in entries:
		var rk := int(e.get("rank", 0))
		if rk < prev:
			return false
		prev = rk
	return true

func _is_me_at(entries: Array, rank: int) -> bool:
	for e in entries:
		if int(e.get("rank", 0)) == rank and bool(e.get("is_me", false)):
			return true
	return false

func _has_band(bands: Array, name: String) -> bool:
	for b in bands:
		if String(b.get("name", "")) == name:
			return true
	return false

func _band_rows(bands: Array, name: String) -> int:
	for b in bands:
		if String(b.get("name", "")) == name:
			return (b.get("rows", []) as Array).size()
	return 0
