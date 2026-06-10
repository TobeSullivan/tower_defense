extends RefCounted
class_name NakamaBackend

# Nakama-backed LeaderboardService backend (notes/leaderboard_schema.md). Reproduces the exact
# dict shapes of LeaderboardService.LocalBackend (and the test SampleBackend), populated from the
# LIVE server: Trials = tournament records, Campaign + Ranked = leaderboards. Writes go through the
# authoritative `submit_score` RPC (boards reject direct client writes). Every read degrades to an
# empty board on any error or missing session, so a surface never crashes when offline.
#
# Nakama returns score/rank/subscore as STRINGS (int64-as-text) — always int() them.

const TOP_N := 10           # leading rows shown before the player's neighborhood
const NEIGHBORHOOD := 5     # rows fetched around the player (around-owner)
const RANKED_PAGE := 100    # ranked ladder page (also the "total" denominator, accurate <= this)

var _svc  # NakamaService (autoload); injected so this stays unit-testable

func _init(service = null) -> void:
	_svc = service
	if _svc == null:
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			_svc = (loop as SceneTree).root.get_node_or_null("NakamaService")

func _live() -> bool:
	return _svc != null and _svc.has_session()

# --- Trials (tournaments) ----------------------------------------------------

func fetch_trials(board_id: String, my_score: int) -> Dictionary:
	if not _live():
		return {"entries": [], "my_rank": 0}
	var session = _svc.session
	var by_rank := {}   # rank -> entry (dedupes the top-N / neighborhood overlap)
	var my_rank := 0

	var top = await _svc.client.list_tournament_records_async(session, board_id, null, TOP_N)
	if top == null or top.is_exception():
		return {"entries": [], "my_rank": 0}
	for rec in top.records:
		var e := _score_entry(rec, session.user_id)
		by_rank[e["rank"]] = e
		if e["is_me"]:
			my_rank = e["rank"]

	# The player's neighborhood — only matters once they've posted a score.
	if my_score > 0:
		var around = await _svc.client.list_tournament_records_around_owner_async(session, board_id, session.user_id, NEIGHBORHOOD)
		if around != null and not around.is_exception():
			for rec in around.records:
				var e := _score_entry(rec, session.user_id)
				by_rank[e["rank"]] = e
				if e["is_me"]:
					my_rank = e["rank"]

	var entries: Array = by_rank.values()
	entries.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))
	return {"entries": entries, "my_rank": my_rank}

func fetch_trials_neighborhood(board_id: String, my_score: int, radius: int) -> Dictionary:
	if not _live() or my_score <= 0:
		return {"rank": 0, "rows": []}
	var session = _svc.session
	var around = await _svc.client.list_tournament_records_around_owner_async(session, board_id, session.user_id, radius * 2 + 1)
	if around == null or around.is_exception():
		return {"rank": 0, "rows": []}
	var rows: Array = []
	var my_rank := 0
	for rec in around.records:
		var e := _score_entry(rec, session.user_id)
		rows.append(e)
		if e["is_me"]:
			my_rank = e["rank"]
	rows.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))
	return {"rank": my_rank, "rows": rows}

func fetch_trials_rank(board_id: String, _my_score: int) -> Dictionary:
	if not _live():
		return {"rank": 0}
	var session = _svc.session
	# owner_ids = [me] → my record comes back in owner_records, carrying my global rank.
	var res = await _svc.client.list_tournament_records_async(session, board_id, [session.user_id], 1)
	if res == null or res.is_exception():
		return {"rank": 0}
	for rec in res.owner_records:
		if String(rec.owner_id) == session.user_id:
			return {"rank": int(rec.rank)}
	return {"rank": 0}

# --- Campaign (all-time leaderboards) ----------------------------------------

func fetch_campaign(mission: int) -> Dictionary:
	if not _live():
		return {"entries": [], "my_score": 0}
	var board_id := "campaign_m%02d" % mission
	var session = _svc.session
	var top = await _svc.client.list_leaderboard_records_async(session, board_id, null, null, TOP_N)
	if top == null or top.is_exception():
		return {"entries": [], "my_score": 0}
	var by_rank := {}
	var my_score := 0
	for rec in top.records:
		var e := _score_entry(rec, session.user_id)
		by_rank[e["rank"]] = e
		if e["is_me"]:
			my_score = e["score"]
	# Ensure the player's own row is present even when outside the top-N.
	if my_score == 0:
		var mine = await _svc.client.list_leaderboard_records_async(session, board_id, [session.user_id], null, 1)
		if mine != null and not mine.is_exception():
			for rec in mine.owner_records:
				if String(rec.owner_id) == session.user_id:
					var e := _score_entry(rec, session.user_id)
					by_rank[e["rank"]] = e
					my_score = e["score"]
	var entries: Array = by_rank.values()
	entries.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))
	return {"entries": entries, "my_score": my_score}

# --- Ranked (one tiered ladder per season; value = tier_base + LP) -----------

func fetch_ranked(season: int) -> Dictionary:
	var out := {"season_label": "Season %d · live" % season, "reset_text": "",
		"seasons": _season_list(season), "you": null, "bands": []}
	if not _live():
		return out
	var board_id := "ranked_s%d" % season
	var session = _svc.session
	var top = await _svc.client.list_leaderboard_records_async(session, board_id, null, null, RANKED_PAGE)
	if top == null or top.is_exception():
		return out

	# Group rows into named bands by ladder value.
	var by_tag := {}
	for rec in top.records:
		var value := int(rec.score)
		var tinfo := LeaderboardService.ranked_tier(value)
		var row := {"rank": int(rec.rank), "name": _name(rec),
			"tier": tinfo["name"], "lp": int(tinfo["lp"]), "is_me": String(rec.owner_id) == session.user_id}
		if not by_tag.has(tinfo["tag"]):
			by_tag[tinfo["tag"]] = []
		by_tag[tinfo["tag"]].append(row)

	var bands: Array = []
	for b in LeaderboardService.RANKED_BANDS:
		if by_tag.has(b["tag"]):
			var rws: Array = by_tag[b["tag"]]
			rws.sort_custom(func(a, c): return int(a["rank"]) < int(c["rank"]))
			bands.append({"name": b["name"], "tag": b["tag"], "rows": rws})
	out["bands"] = bands

	# The player's own standing.
	var you = await _ranked_you(board_id, session)
	if you != null:
		you["total"] = top.records.size()  # accurate while the board fits in one page
	out["you"] = you
	return out

func _ranked_you(board_id: String, session) -> Variant:
	var mine = await _svc.client.list_leaderboard_records_async(session, board_id, [session.user_id], null, 1)
	if mine == null or mine.is_exception():
		return null
	for rec in mine.owner_records:
		if String(rec.owner_id) == session.user_id:
			var value := int(rec.score)
			var tinfo := LeaderboardService.ranked_tier(value)
			var you := {"tier": tinfo["name"], "lp": int(tinfo["lp"]), "rank": int(rec.rank), "total": 0}
			var nb := _next_band_above(value)
			if not nb.is_empty():
				you["to_next"] = int(nb["base"]) - value
				you["next_tier"] = String(nb["name"])
			return you
	return null

# --- Server-owned Trials seeds (leaderboard_schema.md §3) --------------------

# { daily:[5], weekly:[5], monthly:[5] } of per-scale map seeds for the live windows. Empty on
# any error / offline → the caller falls back to its local derivation.
func fetch_trials_seeds() -> Dictionary:
	if not _live():
		return {}
	var res = await _svc.client.rpc_async(_svc.session, "trials_seeds", "")
	if res == null or res.is_exception():
		return {}
	var parsed = JSON.parse_string(res.payload)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

# --- Authoritative write (boards reject direct client writes) ----------------

# kind: "trials" | "campaign" | "ranked". record_b64 = Resim.encode_record(...) base64'd (optional,
# stored server-side for the later re-sim worker). Returns true on a successful RPC.
func submit(kind: String, board_id: String, score: int, record_b64: String = "") -> bool:
	if not _live():
		return false
	var payload := {"kind": kind, "board_id": board_id, "score": score}
	if record_b64 != "":
		payload["record"] = record_b64
	var res = await _svc.client.rpc_async(_svc.session, "submit_score", JSON.stringify(payload))
	if res == null or res.is_exception():
		push_warning("NakamaBackend.submit(%s/%s) failed: %s" % [kind, board_id,
			str(res.get_exception()) if res != null else "null result"])
		return false
	return true

# --- Helpers -----------------------------------------------------------------

func _score_entry(rec, my_id: String) -> Dictionary:
	return {"rank": int(rec.rank), "name": _name(rec), "score": int(rec.score),
		"is_me": String(rec.owner_id) == my_id}

func _name(rec) -> String:
	var u := String(rec.username)
	return u if u != "" else String(rec.owner_id).substr(0, 8)

func _season_list(current: int) -> Array:
	# Descends from the current season to 1. Season 0 is the closed beta: while it's current
	# it is the only entry; once launch rolls to s1+ it stays off the list (beta data survives
	# server-side for analysis, not for display).
	var out: Array = []
	for s in range(current, mini(current, 1) - 1, -1):
		out.append("Season %d%s" % [s, " · live" if s == current else ""])
	return out

# Lowest band whose base is still above `value` = the next tier up. Empty at Masters.
func _next_band_above(value: int) -> Dictionary:
	var best := {}
	for b in LeaderboardService.RANKED_BANDS:
		var base := int(b["base"])
		if base > value and (best.is_empty() or base < int(best["base"])):
			best = b
	return best
