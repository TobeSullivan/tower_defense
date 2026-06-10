extends Node
class_name LeaderboardService

# The single read API every leaderboard surface goes through (notes/leaderboard_ui_spec.md).
# It owns the store-independent logic — board-id naming, scale/window names, the UTC reset
# countdowns (leaderboard_schema.md §5.1), the Ranked tier→band math — and delegates the
# actual row fetch to a swappable BACKEND. The shipping default is a LocalBackend (honest:
# real local best scores + computed countdowns; empty competitor lists, since there is no
# server yet). When Nakama lands, `set_backend(NakamaBackend.new())` lights every surface up
# with zero UI changes.
#
# Reads are synchronous today (local store). Nakama reads are async — when that backend
# lands these become coroutines; call sites already tolerate `await` on a plain return, so
# the conversion is contained to this file + the call sites gaining `await`.
#
# Row shapes (plain Dictionaries — no typed cross-script refs, per project memory):
#   trials/campaign entry : {"rank":int, "name":String, "score":int, "is_me":bool}
#   ranked entry          : {"rank":int, "name":String, "lp":int, "tier":String, "is_me":bool}

const MapResourceScript := preload("res://resources/map_resource.gd")

# Scale tier (1–5) → id / display name (DESIGN_MODES scale names, locked).
const SCALE_IDS := ["thread", "weave", "tangle", "snarl", "knot"]
const SCALE_NAMES := ["Thread", "Weave", "Tangle", "Snarl", "Knot"]
const WINDOW_IDS := {
	MapResourceScript.WindowType.DAILY: "daily",
	MapResourceScript.WindowType.WEEKLY: "weekly",
	MapResourceScript.WindowType.MONTHLY: "monthly",
}
const GROUPS := ["solo", "duo", "trio", "quad"]

# === BETA MODE (closed beta, notes/beta_design_brief.md §4) ===
# Mirrors `BETA` in deploy/nakama/data/modules/index.js — the two MUST flip together, along
# with SaveData.BUILD_SEASON (0 beta / 1 launch). true → Trials ids get the beta flag
# ("trials_beta_*") so beta play never touches the launch boards. Set false at launch.
const BETA := true

# Ranked tiers as named bands of the single ladder value = tier_base + LP (schema §4).
# cap < 0 = uncapped (Masters). Ordered high→low for display.
const RANKED_BANDS := [
	{"name": "Masters", "tag": "mas", "base": 400, "cap": -1},
	{"name": "Platinum", "tag": "plat", "base": 300, "cap": 399},
	{"name": "Gold", "tag": "gold", "base": 200, "cap": 299},
	{"name": "Silver", "tag": "sil", "base": 100, "cap": 199},
	{"name": "Bronze", "tag": "brz", "base": 0, "cap": 99},
]

const WEEK_SECONDS := 604800
const _MONDAY_EPOCH := 345600  # 1970-01-05 00:00 UTC, the first Monday after the epoch

# --- Backend wiring ----------------------------------------------------------

static var _backend  # LeaderboardBackend; lazily defaults to LocalBackend

static func backend():
	if _backend == null:
		_backend = LocalBackend.new()
	return _backend

static func set_backend(b) -> void:
	_backend = b

# --- Naming + window helpers (store-independent) -----------------------------

static func scale_id(tier: int) -> String:
	return SCALE_IDS[clampi(tier - 1, 0, 4)]

static func scale_name(tier: int) -> String:
	return SCALE_NAMES[clampi(tier - 1, 0, 4)]

static func trials_board_id(window: int, tier: int, group: String) -> String:
	var root := "trials_beta" if BETA else "trials"
	return "%s_%s_%s_%s" % [root, WINDOW_IDS.get(window, "daily"), scale_id(tier), group]

# The stable per-window key (also the local-score storage key + map seed salt). Kept here so
# pve_select and the leaderboard surfaces never diverge on what "this window" means.
static func window_date(window: int) -> String:
	var d := Time.get_date_dict_from_system()
	match window:
		MapResourceScript.WindowType.WEEKLY:
			var week := int(Time.get_unix_time_from_system() / float(WEEK_SECONDS))
			return "%04d-W%03d" % [d.year, week % 1000]
		MapResourceScript.WindowType.MONTHLY:
			return "%04d-%02d" % [d.year, d.month]
		_:
			return "%04d-%02d-%02d" % [d.year, d.month, d.day]

# Window-aware result copy: "today" / "this week" / "this month".
static func window_word(window: int) -> String:
	match window:
		MapResourceScript.WindowType.WEEKLY: return "this week"
		MapResourceScript.WindowType.MONTHLY: return "this month"
		_: return "today"

# "resets in 3h 41m" — the ephemerality signal (UTC anchors, schema §5.1). Daily 00:00,
# weekly Mon 00:00, monthly 1st 00:00 UTC.
static func window_reset_text(window: int) -> String:
	var now := int(Time.get_unix_time_from_system())
	var target := now
	match window:
		MapResourceScript.WindowType.WEEKLY:
			target = ((now - _MONDAY_EPOCH) / WEEK_SECONDS + 1) * WEEK_SECONDS + _MONDAY_EPOCH
		MapResourceScript.WindowType.MONTHLY:
			var u := Time.get_datetime_dict_from_unix_time(now)
			var ny: int = u.year + (1 if u.month == 12 else 0)
			var nm: int = 1 if u.month == 12 else u.month + 1
			target = int(Time.get_unix_time_from_datetime_dict({
				"year": ny, "month": nm, "day": 1, "hour": 0, "minute": 0, "second": 0}))
		_:
			target = (now / 86400 + 1) * 86400
	return "resets in " + _dur(maxi(0, target - now))

static func _dur(secs: int) -> String:
	var days := secs / 86400
	var hours := (secs % 86400) / 3600
	var mins := (secs % 3600) / 60
	if days > 0:
		return "%dd %dh" % [days, hours]
	if hours > 0:
		return "%dh %dm" % [hours, mins]
	return "%dm" % mins

# --- Ranked tier math --------------------------------------------------------

# {name, tag, lp} for a ladder value. Masters reports raw over-base LP; others LP within band.
static func ranked_tier(value: int) -> Dictionary:
	for band in RANKED_BANDS:
		if value >= int(band["base"]):
			return {"name": band["name"], "tag": band["tag"], "lp": value - int(band["base"])}
	return {"name": "Bronze", "tag": "brz", "lp": 0}

# --- Surface reads (delegate the row fetch to the backend) -------------------

# Surface 3 (Trials board) + the "View full board" target. Top-N + your neighborhood.
static func trials_board(window: int, tier: int, group: String) -> Dictionary:
	var bid := trials_board_id(window, tier, group)
	var my_score := SaveData.best_pve_score(window_date(window), tier) if group == "solo" else 0
	var res: Dictionary = await backend().fetch_trials(bid, my_score)
	res["id"] = bid
	res["reset_text"] = window_reset_text(window)
	res["my_score"] = my_score
	return res

# Surface 1 (Trials post-match placement): rank + window word + neighborhood ±2.
static func trials_placement(window: int, tier: int, group: String, my_score: int) -> Dictionary:
	var bid := trials_board_id(window, tier, group)
	var res: Dictionary = await backend().fetch_trials_neighborhood(bid, my_score, 2)
	res["window_word"] = window_word(window)
	res["context"] = "%s · %s · %s" % [
		WINDOW_IDS.get(window, "daily").to_upper(), scale_name(tier).to_upper(), group.to_upper()]
	return res

# Surface 4 (Trials-select card): your best + live rank for one map. rank 0 = unplayed.
static func trials_rank(window: int, tier: int, group: String = "solo") -> Dictionary:
	var my_score := SaveData.best_pve_score(window_date(window), tier)
	if my_score <= 0:
		return {"best": 0, "rank": 0}
	var res: Dictionary = await backend().fetch_trials_rank(trials_board_id(window, tier, group), my_score)
	return {"best": my_score, "rank": int(res.get("rank", 0))}

# Surface 3 (Ranked): one continuous tiered ladder for a season (schema §4).
static func ranked_ladder(season: int) -> Dictionary:
	return await backend().fetch_ranked(season)

# Surface 3 (Campaign): the all-time per-mission board.
static func campaign_board(mission: int) -> Dictionary:
	return await backend().fetch_campaign(mission)

# Server-owned per-window Trials map seeds (schema §3): { daily:[5], weekly:[5], monthly:[5] }.
# Empty offline → pve_select falls back to its local window-identity derivation.
static func trials_seeds() -> Dictionary:
	return await backend().fetch_trials_seeds()


# ============================================================================
# Backend base — the store seam. Default impl returns empty boards so a missing
# backend degrades gracefully (never crashes a surface).
# ============================================================================
class LeaderboardBackend extends RefCounted:
	# Top-N + the player's neighborhood, with my row flagged. {entries, my_rank}.
	func fetch_trials(_board_id: String, _my_score: int) -> Dictionary:
		return {"entries": [], "my_rank": 0}
	# ±radius rows around the player. {rank, rows}.
	func fetch_trials_neighborhood(_board_id: String, _my_score: int, _radius: int) -> Dictionary:
		return {"rank": 0, "rows": []}
	# Just the player's rank on a board. {rank}.
	func fetch_trials_rank(_board_id: String, _my_score: int) -> Dictionary:
		return {"rank": 0}
	# {season_label, reset_text, seasons, you, bands}. you=null when unranked.
	func fetch_ranked(season: int) -> Dictionary:
		return {"season_label": "Season %d · live" % season, "reset_text": "", "seasons": ["Season %d" % season], "you": null, "bands": []}
	# {entries, my_score}.
	func fetch_campaign(_mission: int) -> Dictionary:
		return {"entries": [], "my_score": 0}
	# { daily:[5], weekly:[5], monthly:[5] } server-owned seeds; empty = caller derives locally.
	func fetch_trials_seeds() -> Dictionary:
		return {}


# ============================================================================
# LocalBackend — the honest no-server default. The only real competitor data we
# have offline is the player themselves, so Trials boards show your single entry
# (rank 1 of 1 once you've posted a score); Ranked/Campaign have no local store
# of others and return empty boards (the surfaces render a clean empty state).
# This is correct pre-Nakama, not a placeholder — it's exactly what a brand-new
# online board looks like before anyone else has played.
# ============================================================================
class LocalBackend extends LeaderboardBackend:
	func fetch_trials(_board_id: String, my_score: int) -> Dictionary:
		if my_score <= 0:
			return {"entries": [], "my_rank": 0}
		return {"entries": [{"rank": 1, "name": "you", "score": my_score, "is_me": true}], "my_rank": 1}

	func fetch_trials_neighborhood(_board_id: String, my_score: int, _radius: int) -> Dictionary:
		if my_score <= 0:
			return {"rank": 0, "rows": []}
		return {"rank": 1, "rows": [{"rank": 1, "name": "you", "score": my_score, "is_me": true}]}

	func fetch_trials_rank(_board_id: String, _my_score: int) -> Dictionary:
		return {"rank": 1}

	func fetch_ranked(season: int) -> Dictionary:
		return {"season_label": "Season %d · live" % season, "reset_text": "", "seasons": ["Season %d" % season], "you": null, "bands": []}

	func fetch_campaign(_mission: int) -> Dictionary:
		return {"entries": [], "my_score": 0}
