extends Node

# SceneManager autoload — owns navigation between screens and carries the chosen
# MapResource into the match scene. The match scene reads `pending_map` in its
# _ready; the loader does the rest. All in-match exits route back to the home
# screen through here (DESIGN_MODES: "no intermediate screen between any in-match
# exit and the home screen").

const MapResourceScript := preload("res://resources/map_resource.gd")
const MapGeneratorScript := preload("res://scripts/map_generator.gd")
const ResimScript := preload("res://scripts/resim.gd")
const EnetTransportScript := preload("res://net/enet_transport.gd")
const NetProtocolScript := preload("res://net/net_protocol.gd")
const MatchServerScript := preload("res://net/match_server.gd")
const Motion := preload("res://scripts/motion.gd")

# PVP: 1 local player + 7 bots (DESIGN_MODES: 8-player solo-queue ranked).
const PVP_BOARD_COUNT := 8

const HOME_SCENE := "res://scenes/home_screen.tscn"
const CAMPAIGN_SELECT_SCENE := "res://scenes/campaign_select.tscn"
const PVE_SELECT_SCENE := "res://scenes/pve_select.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const LEADERBOARD_SCENE := "res://scenes/leaderboard_browse.tscn"
const MATCH_SCENE := "res://scenes/prototype.tscn"

# --- Networked match (PVP). The transport is owned HERE (an autoload) so it persists
# across the lobby→match scene change and sits at a stable tree path for RPCs. ---
var transport = null            # active MatchTransport (EnetTransport) or null
var is_dedicated_server := false  # true on the headless VPS authority (godot -- --server)
var last_player_name := "Player"  # remembered so re-queue keeps your name
var pending_local_index := 0    # the local player's seat in a networked match
var pending_player_names: Array = []  # seat-indexed lobby handles
var pending_seat_by_peer: Dictionary = {}  # {enet_peer_id: seat} — host uses it to map a disconnect to a board
# Ranked (networked PVP): the lobby-average hidden MMR carried in via the Nakama GO message
# (queue_controller._on_go), read at match end as the net-positive LP anchor. pending_is_ranked
# distinguishes a networked ranked match from offline bot practice (which has no transport/lobby).
var pending_ranked_avg_mmr := 150.0  # RankedLadder.SEED_MMR; overwritten by the real lobby avg
var pending_is_ranked := false

# Authored campaign missions, by mission index. Five missions — a tutorial curriculum
# that ramps from zero, one new concept per mission (design/CAMPAIGN.md). The old
# ten-mission arc was deprecated 2026-06-06 and removed.
const CAMPAIGN_MISSIONS := {
	1: "res://campaign/mission_01.tres",
	2: "res://campaign/mission_02.tres",
	3: "res://campaign/mission_03.tres",
	4: "res://campaign/mission_04.tres",
	5: "res://campaign/mission_05.tres",
}
const CAMPAIGN_MISSION_COUNT := 5

# The live match's MatchCoordinator, set by main.gd when a real match builds. Used to
# derive the AUTHORITATIVE score by re-simming its record at match end (resim_contract
# §4/§8). Not set on the re-sim's own throwaway builds (those go through resim.gd, not
# main.gd), so re-simming never clobbers this. Cleared on return to home.
var active_coordinator = null

# Deep-link context for the leaderboard browse screen (which category/window/scale to land
# on), consumed once by leaderboard_browse.gd. Empty = open at the default (Trials/Daily).
var pending_leaderboard := {}

# Set before a scene change; consumed by the match scene.
var pending_map = null
# Number of boards the match scene builds (1 = solo; PVP = PVP_BOARD_COUNT).
var pending_board_count := 1
# Drives the pause-menu variant (single-player pauses the tree; multiplayer does
# not). Campaign and solo PVE are single-player.
var current_is_multiplayer := false

func goto_home() -> void:
	pending_map = null
	pending_board_count = 1
	current_is_multiplayer = false
	pending_is_ranked = false
	active_coordinator = null  # the match scene (and its coordinator) is about to be freed
	get_tree().paused = false
	Engine.time_scale = 1.0  # menus always run at normal speed
	_menu_change(HOME_SCENE, true)  # "back" — the cover wipes off to the right

func goto_campaign_select() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_menu_change(CAMPAIGN_SELECT_SCENE)

func goto_pve_select() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_menu_change(PVE_SELECT_SCENE)

# --- Menu screen transition (design/JUICE.md "home->select screen transition", the
# connective tissue). SceneManager swaps scenes hard, so we snapshot the outgoing screen into
# a cover on a top CanvasLayer, swap underneath, then slide the cover off — revealing the new
# screen as it plays its own entrance. Forward wipes left; "back" (home) wipes right. Menus
# only — entering a MATCH stays a hard cut (gameplay setup shouldn't ride a menu wipe). ---
var _transition_layer: CanvasLayer = null
var _did_first_nav := false

func _menu_change(path: String, back := false) -> void:
	# First navigation (boot -> home) has nothing meaningful to snapshot — hard cut.
	if not _did_first_nav:
		_did_first_nav = true
		get_tree().change_scene_to_file(path)
		return
	var vp_size := get_viewport().get_visible_rect().size
	var img := get_viewport().get_texture().get_image()  # current frame (saved screenshots prove it's upright)
	if img == null or img.is_empty():
		get_tree().change_scene_to_file(path)  # no frame to snapshot (e.g. headless) — hard cut
		return
	var cover := TextureRect.new()
	cover.texture = ImageTexture.create_from_image(img)
	cover.size = vp_size
	cover.position = Vector2.ZERO
	cover.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow input during the wipe
	if _transition_layer == null:
		_transition_layer = CanvasLayer.new()
		_transition_layer.layer = 128  # above everything
		add_child(_transition_layer)
	_transition_layer.add_child(cover)
	get_tree().change_scene_to_file(path)
	_slide_cover_off.call_deferred(cover, back, vp_size.x)

func _slide_cover_off(cover: TextureRect, back: bool, w: float) -> void:
	if not is_instance_valid(cover):
		return
	var t := cover.create_tween()
	t.set_parallel(true)
	Motion.leave(t)
	t.tween_property(cover, "position:x", (w if back else -w), Motion.dur(Motion.SCREEN))
	t.tween_property(cover, "modulate:a", 0.0, Motion.dur(Motion.SCREEN))
	t.chain().tween_callback(cover.queue_free)
	# Safety: the cover swallows input (layer 128), so guarantee it's gone even if the tween
	# never completes — a stuck cover would soft-lock all navigation.
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(cover): cover.queue_free())

# The leaderboard hub. `ctx` deep-links a category/window/scale (e.g. a Trials-select card
# or a post-match "View full board" jumps straight to its board); empty opens at the default.
func goto_leaderboards(ctx := {}) -> void:
	pending_leaderboard = ctx
	get_tree().paused = false
	Engine.time_scale = 1.0
	_menu_change(LEADERBOARD_SCENE)

# Solo PVE: a generated map played for score. Single-player for pause purposes.
func start_pve_map(map) -> void:
	pending_map = map
	pending_board_count = 1
	current_is_multiplayer = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MATCH_SCENE)

# PVP: a fully-randomized seeded map played against 7 bots (local sim; real netcode
# later). Last-standing, lives-based — no score/medals. Multiplayer pause variant.
func start_pvp() -> void:
	var match_seed := int(Time.get_unix_time_from_system())  # a fresh map each match
	var tier := (match_seed % 5) + 1
	pending_map = MapGeneratorScript.generate(match_seed, tier, MapResourceScript.Mode.PVP)
	pending_board_count = PVP_BOARD_COUNT
	current_is_multiplayer = true
	get_tree().paused = false
	get_tree().change_scene_to_file(MATCH_SCENE)

# --- Networked PVP (lobby + transport) ---

func goto_lobby() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_menu_change(LOBBY_SCENE)

# Create a fresh ENet transport as a child of this autoload (stable path for RPCs).
func _make_transport():
	net_close()
	transport = EnetTransportScript.new()
	transport.name = "Transport"
	add_child(transport)
	return transport

func net_host() -> int:
	_make_transport()
	return transport.start_host(NetProtocolScript.DEFAULT_PORT)

func net_join(address: String) -> int:
	_make_transport()
	return transport.start_join(address, NetProtocolScript.DEFAULT_PORT)

func net_close() -> void:
	if transport != null:
		transport.close()
		transport.queue_free()
		transport = null

# Boot as the headless dedicated server (godot --headless -- --server): the server is peer 1 /
# authority but never a player (no seat). A persistent MatchServer child is the ROOM ROUTER: it
# hosts many concurrent matches keyed by match_id, each an isolated authority subtree it builds
# WITHOUT change_scene (so the server's own scene tree never flips to a single match).
func start_dedicated_server() -> int:
	var err := net_host()
	if err != OK:
		push_error("dedicated server: could not host (error %d)" % err)
		return err
	is_dedicated_server = true
	var server := MatchServerScript.new()
	server.name = "MatchServer"
	add_child(server)
	return OK

# Launch a networked PVP match: every client generates the IDENTICAL map from the
# shared seed, then builds it with the local player on their own seat (no bots; the
# transport is kept alive for in-match relay). Called on host + each client from the
# lobby's START_MATCH handshake.
func start_networked_pvp(seed: int, tier: int, board_count: int, seat: int, names: Array, seat_by_peer: Dictionary = {}) -> void:
	pending_map = MapGeneratorScript.generate(seed, tier, MapResourceScript.Mode.PVP)
	pending_board_count = board_count
	pending_local_index = seat
	pending_player_names = names
	pending_seat_by_peer = seat_by_peer
	current_is_multiplayer = true
	get_tree().paused = false
	get_tree().change_scene_to_file(MATCH_SCENE)

func has_campaign_mission(index: int) -> bool:
	return CAMPAIGN_MISSIONS.has(index)

func start_campaign_mission(index: int) -> void:
	if not CAMPAIGN_MISSIONS.has(index):
		push_warning("SceneManager: campaign mission %d is not authored" % index)
		return
	pending_map = load(CAMPAIGN_MISSIONS[index])
	pending_board_count = 1
	current_is_multiplayer = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MATCH_SCENE)

func restart_current_match() -> void:
	# pending_map is still set; reloading the match scene re-runs the loader on it.
	get_tree().paused = false
	get_tree().reload_current_scene()

# Records the result for the current map (campaign medal or PVE score). Storage is
# best-kept, so calling this with a partial score is always safe — a partial can
# never beat a full run. PVP records nothing (last-standing, no medals/score).
func report_match_result(advisory_damage: int) -> void:
	if pending_map == null:
		return
	# resim_contract §4/§8: the score we RECORD is the authoritative re-sim of the match
	# record, never the live client tally (that's advisory/UX). An illegal log (§4.1) is
	# rejected outright — no score is written. Locally the re-sim runs client-side: a
	# stand-in for the server, and a continuous determinism self-check.
	var result := _authoritative_score(advisory_damage)
	if not bool(result["legal"]):
		push_warning("Match record failed legality check (%s) — no score recorded." % str(result.get("reason", "")))
		return
	var damage: int = int(result["score"])
	if pending_map.mode == MapResourceScript.Mode.CAMPAIGN and pending_map.mission_index > 0:
		SaveData.record_campaign_medal(pending_map.mission_index, _medal_for(damage))
		_post_online("campaign", "campaign_m%02d" % pending_map.mission_index, damage)
	elif pending_map.mode == MapResourceScript.Mode.PVE:
		SaveData.record_pve_score(pending_map.window_date, pending_map.scale_tier, damage)
		_post_online("trials", LeaderboardService.trials_board_id(
			pending_map.window_type, pending_map.scale_tier, "solo"), damage)

# Networked Ranked result: write the player's new authoritative LADDER VALUE (tier_base + LP)
# to the season board via the submit_score RPC (op "set"; boards reject direct client writes).
# Unlike Trials/campaign, the value is NOT a re-sim of local damage — it's derived from the
# host-authoritative placement (finish_order via MATCH_END) by the LP engine, then mirrored
# here. The match record blob still rides along for the later re-sim worker. No-op offline.
func report_ranked_result(value_after: int) -> void:
	_post_online("ranked", "ranked_s%d" % SaveData.ranked_season(), value_after)

# Post the authoritative score to the online board when a Nakama backend is active. Offline
# (LocalBackend) this is a no-op — boards are write-gated to the submit_score RPC. The match record
# is encoded SYNCHRONOUSLY (before the first await) so active_coordinator is read while still valid;
# the network submit is then fire-and-forget (match-end must not block on the network).
func _post_online(kind: String, board_id: String, score: int) -> void:
	var be = LeaderboardService.backend()
	if be == null or not be.has_method("submit"):
		return
	var record_b64 := ""
	var coord = active_coordinator
	if coord != null and is_instance_valid(coord) and coord.record_enabled:
		var bytes: PackedByteArray = ResimScript.encode_record(coord.make_record())
		record_b64 = Marshalls.raw_to_base64(bytes)
	await be.submit(kind, board_id, score, record_b64)

# Derive the local board's authoritative score by re-simming the captured match record.
# Returns { score, legal, reason }. Falls back to the advisory value (legal) only when
# there's no record to replay (e.g. a scene opened directly with no coordinator). An
# illegal record (§4.1) returns legal=false and the caller writes no score. A mid-match
# bow-out logs an `end` marker first so the re-sim scores the partial, not the played-out
# remainder.
func _authoritative_score(advisory: int) -> Dictionary:
	var coord = active_coordinator
	if coord == null or not is_instance_valid(coord) or not coord.record_enabled:
		return {"score": advisory, "legal": true, "reason": ""}
	if not coord.match_over:
		coord.record_end_marker()
	var record: Dictionary = coord.make_record()
	var host := Node2D.new()
	add_child(host)
	var res: Dictionary = ResimScript.run(host, record)
	host.queue_free()
	if not bool(res.get("legal", true)):
		return {"score": 0, "legal": false, "reason": str(res.get("illegal", ""))}
	var rboards: Array = res.get("boards", [])
	if rboards.is_empty():
		return {"score": advisory, "legal": true, "reason": ""}
	var score := int(rboards[0]["damage"])  # solo = seat 0
	if score != advisory:
		push_warning("Re-sim score %d differs from live %d — determinism check (recording re-sim)." % [score, advisory])
	return {"score": score, "legal": true, "reason": ""}

func _medal_for(damage: int) -> String:
	if pending_map == null:
		return "none"
	if damage >= pending_map.gold_threshold:
		return "gold"
	if damage >= pending_map.silver_threshold:
		return "silver"
	if damage >= pending_map.bronze_threshold:
		return "bronze"
	return "none"

# Bow out mid-match: record the (possibly partial) result, then go home. Used by
# the gold-reached popup and the pause-menu quit. Partial scores count by design.
func leave_match_to_home(damage: int) -> void:
	report_match_result(damage)
	goto_home()
