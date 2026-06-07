extends Node2D

# Ghost-ladder verification harness (notes/ghost_ladder.md).
# PASS 1: the four-state ladder machine across a full climb — named tiers → ghost scores
#         → your-best → TOP, plus the dead-board and brand-new-player fallbacks, and the
#         passed()/rung_count() counters.
# PASS 2: wiring — a PVE match builds with a ghost ladder on the HUD and NO win panel
#         (the "go home?" prompt is removed for Trials); a CAMPAIGN match builds with no
#         ghost ladder and the win panel intact.
# Drive headlessly: godot --headless --path src res://tools/ghost_ladder_test.tscn

const GhostLadderScript := preload("res://scripts/ghost_ladder.gd")
const MapLoaderScript := preload("res://scripts/map_loader.gd")
const MapGeneratorScript := preload("res://scripts/map_generator.gd")
const MapResourceScript := preload("res://resources/map_resource.gd")

var _fails := 0

func _ready() -> void:
	_test_state_machine()
	_test_dead_board()
	_test_new_player()
	_test_counters()
	await _test_wiring()
	if _fails == 0:
		print("RESULT ✅ GHOST LADDER OK (state machine + fallbacks + counters + wiring)")
	else:
		print("RESULT ❌ GHOST LADDER FAILED — ", _fails, " check(s) above")
	get_tree().quit()

# --- helpers ---

func _check(label: String, got, want) -> void:
	if got == want:
		print("  ✅ ", label)
	else:
		print("  ❌ ", label, "  got=", got, "  want=", want)
		_fails += 1

func _state(t: Dictionary) -> int:
	return int(t["state"])

# --- PASS 1: the four states across a full climb ---

func _test_state_machine() -> void:
	print("state machine (B=100 S=200 G=300; ghosts Bob=400 Alice=500, Carl=250 below gold; best=600):")
	var l = GhostLadderScript.new()
	# Carl (250) is below gold and must be ignored as a rung. Order is intentionally unsorted.
	l.setup(100, 200, 300, [
		{"name": "Alice", "score": 500},
		{"name": "Carl", "score": 250},
		{"name": "Bob", "score": 400},
	], 600)

	var below_b = l.target_for(50)
	_check("50 → NAMED_TIER Bronze 100", [_state(below_b), below_b["label"], int(below_b["target"])],
		[GhostLadderScript.State.NAMED_TIER, "Bronze", 100])

	var below_s = l.target_for(150)
	_check("150 → NAMED_TIER Silver 200", [_state(below_s), below_s["label"], int(below_s["target"])],
		[GhostLadderScript.State.NAMED_TIER, "Silver", 200])

	# 250 equals Carl's score but Carl is below gold — must still climb to Gold, not GHOST.
	var below_g = l.target_for(250)
	_check("250 → NAMED_TIER Gold 300 (sub-gold ghost ignored)",
		[_state(below_g), below_g["label"], int(below_g["target"])],
		[GhostLadderScript.State.NAMED_TIER, "Gold", 300])

	var ghost1 = l.target_for(350)
	_check("350 → GHOST Bob 400", [_state(ghost1), ghost1["name"], int(ghost1["target"])],
		[GhostLadderScript.State.GHOST, "Bob", 400])

	var ghost2 = l.target_for(450)
	_check("450 → GHOST Alice 500", [_state(ghost2), ghost2["name"], int(ghost2["target"])],
		[GhostLadderScript.State.GHOST, "Alice", 500])

	var yours = l.target_for(550)
	_check("550 → YOUR_BEST 600", [_state(yours), int(yours["target"])],
		[GhostLadderScript.State.YOUR_BEST, 600])

	var top = l.target_for(650)
	_check("650 → TOP", _state(top), GhostLadderScript.State.TOP)

# --- dead board: no ghosts → straight to your-best above gold, then TOP ---

func _test_dead_board() -> void:
	print("dead board (no ghosts; best=400):")
	var l = GhostLadderScript.new()
	l.setup(100, 200, 300, [], 400)
	_check("350 → YOUR_BEST 400", [_state(l.target_for(350)), int(l.target_for(350)["target"])],
		[GhostLadderScript.State.YOUR_BEST, 400])
	_check("450 → TOP", _state(l.target_for(450)), GhostLadderScript.State.TOP)

# --- brand-new player on a dead board: no ghosts, no best → TOP once past gold ---

func _test_new_player() -> void:
	print("new player (no ghosts, no best):")
	var l = GhostLadderScript.new()
	l.setup(100, 200, 300, [], 0)
	_check("250 → NAMED_TIER Gold 300", _state(l.target_for(250)), GhostLadderScript.State.NAMED_TIER)
	_check("350 → TOP (nothing left to chase)", _state(l.target_for(350)), GhostLadderScript.State.TOP)

# --- passed()/rung_count() ---

func _test_counters() -> void:
	print("counters:")
	var l = GhostLadderScript.new()
	l.setup(100, 200, 300, [{"name": "Bob", "score": 400}, {"name": "Alice", "score": 500}], 600)
	_check("rung_count = 5 (3 tiers + 2 ghosts)", l.rung_count(), 5)
	_check("passed(50) = 0", l.passed(50), 0)
	_check("passed(450) = 4 (B,S,G,Bob)", l.passed(450), 4)
	_check("passed(999) = 5 (all)", l.passed(999), 5)

# --- PASS 2: wiring (HUD ladder + win-panel gating per mode) ---

func _test_wiring() -> void:
	print("wiring:")
	# PVE (Trials): ghost ladder on the HUD, no win panel.
	var pve_map = MapGeneratorScript.generate(12345, 2, MapResourceScript.Mode.PVE)
	var pve_host := Node2D.new()
	add_child(pve_host)
	MapLoaderScript.build_match(pve_host, pve_map, 1, 0, false)
	await _wait(0.1)
	var pve_hud = _find(pve_host, "HUD")
	_check("PVE: HUD exists", pve_hud != null, true)
	if pve_hud != null:
		_check("PVE: HUD has a ghost ladder", pve_hud.ghost_ladder != null, true)
	_check("PVE: no win panel (go-home prompt removed)", _find(pve_host, "WinPanel") == null, true)
	pve_host.queue_free()

	# Campaign: no ghost ladder (medal-only target), win panel intact.
	var camp_map = load("res://campaign/mission_03.tres")
	var camp_host := Node2D.new()
	add_child(camp_host)
	MapLoaderScript.build_match(camp_host, camp_map, 1, 0, false)
	await _wait(0.1)
	var camp_hud = _find(camp_host, "HUD")
	_check("Campaign: HUD exists", camp_hud != null, true)
	if camp_hud != null:
		_check("Campaign: HUD has NO ghost ladder", camp_hud.ghost_ladder == null, true)
	_check("Campaign: win panel intact", _find(camp_host, "WinPanel") != null, true)
	camp_host.queue_free()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _find(root: Node, cls: String) -> Node:
	for n in root.get_children():
		var s = n.get_script()
		if s != null and s.get_global_name() == cls:
			return n
		var hit = _find(n, cls)
		if hit != null:
			return hit
	return null
