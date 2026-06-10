extends Node2D

# Leaderboard verification harness (notes/leaderboard_ui_spec.md + leaderboard_schema.md).
# PASS 1: LeaderboardService store-independent logic — board-id naming, scale/window names,
#         ranked tier→band math, reset countdown text.
# PASS 2: LocalBackend honesty — empty boards with no data; your single own-entry once a
#         Trials score exists; ranked/campaign empty.
# PASS 3: wiring — with an injected sample backend, the board-browse screen renders rows for
#         every category (Trials/Ranked/Campaign) and survives category + selection switches.
# Drive headlessly: godot --headless --path src res://tools/leaderboard_test.tscn

const LeaderboardService := preload("res://scripts/leaderboard_service.gd")
const BrowseScript := preload("res://scripts/leaderboard_browse.gd")
const MapResourceScript := preload("res://resources/map_resource.gd")
const MapLoaderScript := preload("res://scripts/map_loader.gd")
const MapGeneratorScript := preload("res://scripts/map_generator.gd")
const PveSelectScript := preload("res://scripts/pve_select.gd")

var _fails := 0

func _ready() -> void:
	_test_service_logic()
	_test_local_backend()
	await _test_browse_wiring()
	await _test_entry_points()
	LeaderboardService.set_backend(null)  # restore default for anything downstream
	if _fails == 0:
		print("RESULT ✅ LEADERBOARDS OK (service logic + local backend + browse wiring)")
	else:
		print("RESULT ❌ LEADERBOARDS FAILED — ", _fails, " check(s) above")
	get_tree().quit()

func _check(label: String, got, want) -> void:
	if got == want:
		print("  ✅ ", label)
	else:
		print("  ❌ ", label, "  got=", got, "  want=", want)
		_fails += 1

func _check_true(label: String, cond: bool) -> void:
	_check(label, cond, true)

# --- PASS 1: pure service logic ---

func _test_service_logic() -> void:
	print("service logic:")
	_check("scale_name(3) = Tangle", LeaderboardService.scale_name(3), "Tangle")
	_check("scale_id(5) = knot", LeaderboardService.scale_id(5), "knot")
	var root := "trials_beta" if LeaderboardService.BETA else "trials"  # beta flag moves the id root
	_check("board id format", LeaderboardService.trials_board_id(MapResourceScript.WindowType.DAILY, 3, "solo"), root + "_daily_tangle_solo")
	_check("board id weekly/knot/quad", LeaderboardService.trials_board_id(MapResourceScript.WindowType.WEEKLY, 5, "quad"), root + "_weekly_knot_quad")
	_check("window_word daily", LeaderboardService.window_word(MapResourceScript.WindowType.DAILY), "today")
	_check("window_word monthly", LeaderboardService.window_word(MapResourceScript.WindowType.MONTHLY), "this month")
	# Ranked tier bands (value = tier_base + LP).
	_check("value 77 → Bronze 77 (sub-100)", LeaderboardService.ranked_tier(77), {"name": "Bronze", "tag": "brz", "lp": 77})
	_check("value 277 → Gold 77", LeaderboardService.ranked_tier(277), {"name": "Gold", "tag": "gold", "lp": 77})
	_check("value 2240 → Masters 1840", LeaderboardService.ranked_tier(2240), {"name": "Masters", "tag": "mas", "lp": 1840})
	# Countdown text is computed (non-empty, well-formed) for each window.
	for wt in [MapResourceScript.WindowType.DAILY, MapResourceScript.WindowType.WEEKLY, MapResourceScript.WindowType.MONTHLY]:
		_check_true("reset text non-empty (window %d)" % wt, LeaderboardService.window_reset_text(wt).begins_with("resets in "))

# --- PASS 2: LocalBackend (honest empty / own-entry) ---

func _test_local_backend() -> void:
	print("local backend:")
	var lb = LeaderboardService.LocalBackend.new()
	_check("empty board when no score", lb.fetch_trials("trials_daily_tangle_solo", 0), {"entries": [], "my_rank": 0})
	var with_score: Dictionary = lb.fetch_trials("trials_daily_tangle_solo", 940100)
	_check("own entry rank 1 when scored", with_score["my_rank"], 1)
	_check("own entry flagged is_me", bool(with_score["entries"][0]["is_me"]), true)
	_check("ranked unranked offline (you=null)", lb.fetch_ranked(1)["you"], null)
	_check("campaign empty offline", lb.fetch_campaign(1), {"entries": [], "my_score": 0})

# --- PASS 3: browse wiring with a sample (Nakama-stand-in) backend ---

func _test_browse_wiring() -> void:
	print("browse wiring (sample backend):")
	LeaderboardService.set_backend(SampleBackend.new())
	var browse = BrowseScript.new()
	add_child(browse)
	await _wait(0.1)  # let _ready build the default (Trials) view

	# Trials renders rows + a jump divider (rank gap 3→13).
	_check_true("Trials list populated", _list_count(browse) > 0)
	_check_true("Trials has a jump divider", _has_divider(browse))

	# Switch categories — each must rebuild without error and produce content.
	browse._set_category(browse.Cat.RANKED)
	await _wait(0.05)
	_check_true("Ranked list populated", _list_count(browse) > 0)

	browse._set_category(browse.Cat.CAMPAIGN)
	await _wait(0.05)
	_check_true("Campaign list populated", _list_count(browse) > 0)

	# Back to Trials, change a selector (scale) — exercises _select rebuild path.
	browse._set_category(browse.Cat.TRIALS)
	browse._select(func(): browse._tier = 5)
	await _wait(0.05)
	_check_true("Trials rebuilt after scale switch", _list_count(browse) > 0)
	browse.queue_free()

# --- PASS 4: entry points (Surface 4 select cards, Surface 1 post-match block) ---

func _test_entry_points() -> void:
	print("entry points:")
	LeaderboardService.set_backend(SampleBackend.new())

	# Surface 4: the Trials-select screen builds (renamed cards + inline rank path).
	var select = PveSelectScript.new()
	add_child(select)
	await _wait(0.1)
	_check_true("Trials-select screen builds", select.is_inside_tree())
	select.queue_free()

	# Surface 1: a PVE match wires lb_ctx onto the match-end panel; campaign does not.
	var pve_host := Node2D.new()
	add_child(pve_host)
	MapLoaderScript.build_match(pve_host, MapGeneratorScript.generate(7, 3, MapResourceScript.Mode.PVE), 1, 0, false)
	await _wait(0.1)
	var pve_end = _find(pve_host, "MatchEndPanel")
	_check_true("PVE match-end has lb_ctx (Trials placement enabled)", pve_end != null and not pve_end.lb_ctx.is_empty())
	if pve_end != null:
		pve_end._populate_placement(1284500)
		_check_true("placement block renders rows", pve_end._lb_vbox.get_child_count() > 0)
	pve_host.queue_free()

	var camp_host := Node2D.new()
	add_child(camp_host)
	MapLoaderScript.build_match(camp_host, load("res://campaign/mission_03.tres"), 1, 0, false)
	await _wait(0.1)
	var camp_end = _find(camp_host, "MatchEndPanel")
	_check_true("Campaign match-end has NO lb_ctx", camp_end != null and camp_end.lb_ctx.is_empty())
	camp_host.queue_free()

func _find(root: Node, cls: String) -> Node:
	for n in root.get_children():
		var s = n.get_script()
		if s != null and s.get_global_name() == cls:
			return n
		var hit = _find(n, cls)
		if hit != null:
			return hit
	return null

func _list_count(browse) -> int:
	return browse._list_box.get_child_count()

func _has_divider(browse) -> bool:
	for c in browse._list_box.get_children():
		if c is Label and "jump to your position" in c.text:
			return true
	return false

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# Sample backend: stands in for Nakama so the UI can be verified against full boards. Never
# ships — the shipping default is LeaderboardService.LocalBackend. Duck-typed (the service
# only calls these method names), so no inheritance coupling.
class SampleBackend extends RefCounted:
	func fetch_trials(_board_id: String, _my_score: int) -> Dictionary:
		return {"my_rank": 14, "entries": [
			{"rank": 1, "name": "apex_builder", "score": 2104900, "is_me": false},
			{"rank": 2, "name": "mazewright", "score": 1902330, "is_me": false},
			{"rank": 3, "name": "a_very_long_handle_that_truncates_here", "score": 1766010, "is_me": false},
			{"rank": 13, "name": "tower_of_pwr", "score": 1301880, "is_me": false},
			{"rank": 14, "name": "you", "score": 1284500, "is_me": true},
			{"rank": 15, "name": "creepkiller_99", "score": 1260140, "is_me": false},
		]}
	func fetch_trials_neighborhood(_board_id: String, _my_score: int, _radius: int) -> Dictionary:
		return {"rank": 14, "rows": [
			{"rank": 12, "name": "mazewright", "score": 1340200, "is_me": false},
			{"rank": 13, "name": "tower_of_pwr", "score": 1301880, "is_me": false},
			{"rank": 14, "name": "you", "score": 1284500, "is_me": true},
			{"rank": 15, "name": "creepkiller_99", "score": 1260140, "is_me": false},
		]}
	func fetch_trials_rank(_board_id: String, _my_score: int) -> Dictionary:
		return {"rank": 14}
	func fetch_trials_seeds() -> Dictionary:
		return {}  # empty → callers fall back to the local window-identity derivation
	func fetch_ranked(_season: int) -> Dictionary:
		return {
			"season_label": "Season 2 · live", "reset_text": "18 days left",
			"seasons": ["Season 2 · live", "Season 1"],
			"you": {"tier": "Gold", "lp": 77, "rank": 34, "total": 100, "to_next": 23, "next_tier": "Platinum"},
			"bands": [
				{"name": "Masters", "tag": "mas", "rows": [
					{"rank": 1, "name": "apex_builder", "tier": "Masters", "lp": 1840, "is_me": false}]},
				{"name": "Gold", "tag": "gold", "rows": [
					{"rank": 33, "name": "mazewright", "tier": "Gold", "lp": 80, "is_me": false},
					{"rank": 34, "name": "you", "tier": "Gold", "lp": 77, "is_me": true},
					{"rank": 35, "name": "creepkiller_99", "tier": "Gold", "lp": 71, "is_me": false}]},
			]}
	func fetch_campaign(_mission: int) -> Dictionary:
		return {"my_score": 88000, "entries": [
			{"rank": 1, "name": "apex_builder", "score": 142000, "is_me": false},
			{"rank": 2, "name": "you", "score": 88000, "is_me": true},
		]}
