extends Node

# Reads a MapResource and builds the live match scene under `host`. This is the
# single configuration path: campaign passes a hand-authored .tres, PVE/PVP pass
# a generated MapResource in memory, and the loader treats them identically.
#
# A match is one MatchCoordinator (the shared clock) plus N boards. Each board is
# a self-contained sim subtree under its own container node (its own background,
# zones, markers, obstacles, spawner, build_controller, BoardState, and mobs
# array). Only the local player's board is interactive and wired to the on-screen
# HUD/panels. Solo (campaign / solo PVE) is simply num_boards == 1.
#
# The map argument is left untyped on purpose (duck-typed field access) to avoid
# the typed cross-script reference pitfalls noted in the project memory.

const GridScript := preload("res://scripts/grid.gd")
const BonusZoneScript := preload("res://scripts/bonus_zone.gd")
const SpawnerScript := preload("res://scripts/spawner.gd")
const BuildControllerScript := preload("res://scripts/build_controller.gd")
const MatchCoordinatorScript := preload("res://scripts/match_coordinator.gd")
const RoundManagerScript := preload("res://scripts/round_manager.gd")
const RailScript := preload("res://scripts/rail.gd")
const BuildConfirmScript := preload("res://scripts/build_confirm.gd")
const TowerDrawerScript := preload("res://scripts/tower_drawer.gd")
const MatchEndPanelScript := preload("res://scripts/match_end_panel.gd")
const WinPanelScript := preload("res://scripts/win_panel.gd")
const RoundToastScript := preload("res://scripts/round_toast.gd")
const PauseMenuScript := preload("res://scripts/pause_menu.gd")
const GameViewScript := preload("res://scripts/game_view.gd")
const LeaderboardPanelScript := preload("res://scripts/leaderboard_panel.gd")

# Opponent display handles for solo-queue PVP (board 0 is always "You"). A fixed pool,
# spread by index so a given match's names are stable.
const OPPONENT_HANDLES := [
	"ShadowFox", "MazeKing", "Vortex", "NightOwl", "IronWall", "Specter",
	"BlazeUp", "Quibble", "RogueAI", "Hexed", "Tidal", "Grimlock", "Pyre", "Zenith",
]
const RoadRendererScript := preload("res://scripts/road_renderer.gd")
const GridOverlayScript := preload("res://scripts/grid_overlay.gd")
const BotControllerScript := preload("res://scripts/bot_controller.gd")
const PlaytestLogScript := preload("res://scripts/playtest_log.gd")
const ObstacleScript := preload("res://scripts/obstacle.gd")
const ZoneDefinitionScript := preload("res://resources/zone_definition.gd")
const MapResourceScript := preload("res://resources/map_resource.gd")
const BuildGuideScript := preload("res://scripts/build_guide.gd")
const TutorialDirectorScript := preload("res://scripts/tutorial_director.gd")
const TutorialCalloutScript := preload("res://scripts/tutorial_callout.gd")
const GhostLadderScript := preload("res://scripts/ghost_ladder.gd")

const CHECKPOINT_TEX := preload("res://assets/maps/level_marker_flag.png")
const GRASS_TEX := preload("res://assets/maps/summer_grass_tile.png")
const ObstaclePropsScript := preload("res://resources/obstacle_props.gd")

# Horizontal gap (in tiles) between adjacent board containers when more than one
# board is laid out in world space.
const BOARD_GAP_TILES := 6

# Solo entry point (unchanged signature): a one-board match. Returns nothing.
static func load_into(host: Node2D, map) -> void:
	build_match(host, map, 1)

# Builds an N-board match into `host`. Board 0 is the local (interactive) player;
# its sim subtree sits at the world origin so existing mouse/cell math is exact.
# Additional boards are offset to the right (for spectating / the arena view).
# Returns the array of BoardState nodes (board 0 is the local player).
# local_index = which seat is the local player (0 for solo / bot-PVP; the player's seat
# for networked). The local board is laid out at world origin so all existing mouse/cell
# math stays exact. use_bots drives the non-local boards with AI (offline practice); a
# networked match passes false (opponents are driven by relayed inputs). player_names
# (optional) supplies real lobby handles; empty falls back to "You" + pool handles.
static func build_match(host: Node2D, map, num_boards: int = 1, local_index: int = 0, use_bots: bool = true, player_names: Array = []) -> Array:
	var coordinator := MatchCoordinatorScript.new()
	coordinator.max_rounds = map.round_count
	coordinator.is_pvp = (map.mode == MapResourceScript.Mode.PVP)
	# Determinism + re-sim wiring (set BEFORE add_child so _ready seeds the RNG from it).
	# One match seed drives both map gen and the combat RNG. record_enabled captures the
	# tick-tagged input log; a re-sim build turns it back off (see scripts/resim.gd).
	coordinator.sim_seed = map.seed
	coordinator.map_ref = _map_ref_for(map)
	coordinator.record_enabled = true
	host.add_child(coordinator)

	var boards: Array = []
	var containers: Array = []
	for i in range(num_boards):
		var container := Node2D.new()
		container.name = "Board%d" % i
		container.position = _board_offset(i, map.grid_size, local_index)
		host.add_child(container)
		containers.append(container)
		var board = _build_board(container, map, coordinator, i == local_index, use_bots)
		if coordinator.is_pvp:
			board.lives = GameConstants.LIVES_PER_PLAYER
		boards.append(board)

	# Dedicated server: authority-only build (local_index < 0 = no local player). Sim all
	# boards for the authoritative kill tally + resolve_lives, but skip ALL on-screen UI,
	# camera, leaderboard and telemetry — the server is headless and holds no seat.
	if local_index < 0:
		return boards

	# Recessed dark surround behind everything (v3 bounded layout): the board is a bright
	# bordered arena floating in this. Screen-space (own CanvasLayer), so it never scales
	# with the board's camera.
	_setup_surround(host)

	# On-screen UI is bound to the LOCAL player's board (their seat).
	var local_board = boards[local_index]
	var local_ctrl = local_board.build_controller
	var ui = _build_match_ui(host, local_board, local_ctrl, map, _build_ghost_ladder(map))
	var rail = ui[0]
	var drawer = ui[1]

	# Playtest telemetry for threshold calibration (local board only; user:// only).
	var plog := PlaytestLogScript.new()
	plog.board = local_board
	plog.coordinator = coordinator
	plog.map = map
	host.add_child(plog)

	# Game camera in EVERY mode — fits the board into the reserved play rect so the
	# UI frame never overlaps the play area.
	var game_view := GameViewScript.new()
	game_view.coordinator = coordinator
	game_view.board_containers = containers
	game_view.grid_size = map.grid_size
	game_view.local_index = local_index
	game_view.is_pvp = coordinator.is_pvp
	game_view.local_build_controller = local_ctrl  # touch tap dispatch
	game_view.tower_drawer = drawer  # so taps over the open drawer don't poke the board
	local_ctrl.tower_drawer = drawer  # same guard for the mouse path
	drawer.game_view = game_view  # so collapsing the dock can re-fit the board camera
	host.add_child(game_view)

	# Campaign tutorial: beats + ghost-outline build guidance for the LOCAL board only.
	# Generated PVE/PVP maps carry no beats, so this is campaign-only by construction.
	if map.mode == MapResourceScript.Mode.CAMPAIGN and map.tutorial_beats != null and not map.tutorial_beats.is_empty():
		var guide = null
		if _beats_use_ghost(map.tutorial_beats):
			guide = BuildGuideScript.new()
			guide.build_controller = local_ctrl
			containers[local_index].add_child(guide)
			local_ctrl.towers_changed.connect(guide._on_towers_changed)
		var callout = TutorialCalloutScript.new()
		host.add_child(callout)
		var director = TutorialDirectorScript.new()
		director.coordinator = coordinator
		director.board = local_board
		director.build_controller = local_ctrl
		director.callout = callout
		director.guide = guide
		director.setup(map.tutorial_beats)
		host.add_child(director)

	# Arena leaderboard only for multi-board matches (PVP). It floats over the board's
	# left edge as a collapsible drawer toggled by the action strip's leaderboard button.
	if num_boards > 1:
		# Display handles: real lobby names if supplied, else "You" + spread pool handles.
		var names: Array = []
		names.resize(num_boards)
		for i in range(num_boards):
			if i < player_names.size() and player_names[i] != "":
				names[i] = player_names[i]
			elif i == local_index:
				names[i] = "You"
			else:
				names[i] = OPPONENT_HANDLES[(i * 5) % OPPONENT_HANDLES.size()]
		coordinator.board_names = names
		game_view.board_names = names

		var leaderboard := LeaderboardPanelScript.new()
		leaderboard.coordinator = coordinator
		leaderboard.boards = boards
		leaderboard.local_index = local_index
		leaderboard.grid_size = map.grid_size
		leaderboard.arena = game_view
		host.add_child(leaderboard)
		rail.minimap = leaderboard  # the rail's Leaderboard button toggles the pop-out
		game_view.minimap = leaderboard  # taps over the open panel don't poke the board
		local_ctrl.minimap = leaderboard  # same guard for the mouse path

	return boards

# Lay boards out in a row with the LOCAL board at world origin (slot 0) so the local
# player's sim sits at the origin and the existing cell/mouse math is exact; opponents
# fill the remaining slots in seat order.
# Identifies the exact map for the re-sim record (§2.1). Generated maps rebuild from
# (seed, scale_tier, mode, window); authored campaign maps reload by mission index.
# True if any beat carries ghost_cells — i.e. the mission needs a build-guide overlay.
static func _beats_use_ghost(beats: Array) -> bool:
	for b in beats:
		if b.ghost_cells != null and not b.ghost_cells.is_empty():
			return true
	return false

static func _map_ref_for(map) -> Dictionary:
	if map.mode == MapResourceScript.Mode.CAMPAIGN:
		return {"kind": "authored", "mission_index": map.mission_index, "tres_version": 1}
	return {
		"kind": "generated",
		"seed": map.seed,
		"scale_tier": map.scale_tier,
		"mode": int(map.mode),
		"window_type": int(map.window_type),
		"window_date": map.window_date,
	}

static func _board_offset(index: int, grid_size: Vector2i, local_index: int = 0) -> Vector2:
	if index == local_index:
		return Vector2.ZERO
	var slot := index + 1 if index < local_index else index
	var stride := (grid_size.x + BOARD_GAP_TILES) * GridScript.TILE_SIZE
	return Vector2(slot * stride, 0.0)

# Builds one board's full sim subtree under `container` and returns its BoardState.
static func _build_board(container: Node2D, map, coordinator, is_local: bool, use_bots: bool = true):
	# Equipped cosmetics — LOCAL board only. Opponent boards keep defaults: their cosmetics
	# aren't known here and must never ride the match record (cardinal rule 2). All render-only
	# reads; never enter the sim/record, so determinism is untouched (resim builds local=-1).
	var board_tex: Texture2D = GRASS_TEX
	var tower_skin: Texture2D = null
	var proj_tint := Color.WHITE
	var board_id := ""   # drives board-scoped obstacle art (local only; "" => default pool)
	if is_local:
		board_id = SaveData.equipped_cosmetic("board")
		board_tex = CosmeticsCatalog.texture_for(
			board_id, "res://assets/maps/summer_grass_tile.png")
		var tw := SaveData.equipped_cosmetic("tower")
		if tw != "" and tw != "tower_arrow":  # non-default body → skin it
			tower_skin = CosmeticsCatalog.texture_for(tw, "res://assets/towers/arrow_box_loaded.png")
		proj_tint = CosmeticsCatalog.tint_for(SaveData.equipped_cosmetic("proj"), Color.WHITE)
	_setup_background(container, map.grid_size, board_tex)

	# Live dirt-road renderer for the mob path (replaces the old dashed overlay). Add
	# THEN configure (configure needs _ready done). Above grass, below towers/mobs.
	var road := RoadRendererScript.new()
	container.add_child(road)
	road.configure(float(GridScript.TILE_SIZE))
	road.z_index = -50

	var zones := _setup_zones(container, map.bonus_zones)
	_setup_markers(container, map.checkpoint_cells)
	var obstacle_blocked := _setup_obstacles(container, map, board_id)

	# Each board owns its own mob list (NOT shared — that would cross-contaminate
	# targeting and run-completion detection across boards).
	var mobs: Array = []

	var spawner := SpawnerScript.new()
	spawner.mobs_array = mobs

	var ctrl := BuildControllerScript.new()
	ctrl.interactive = is_local
	ctrl.tower_skin_tex = tower_skin  # set before add_child so ctrl._ready skins the ghost
	ctrl.proj_tint = proj_tint
	ctrl.mobs_array = mobs
	ctrl.entry_cell = map.entry_cell
	ctrl.exit_cell = map.exit_cell
	ctrl.checkpoint_cells = map.checkpoint_cells
	ctrl.max_towers = map.supply_cap
	ctrl.grid_size = map.grid_size
	ctrl.blocked = obstacle_blocked  # obstacles are permanent walls from the start

	var board := RoundManagerScript.new()
	board.coordinator = coordinator
	board.spawner = spawner
	board.mobs_array = mobs
	board.build_controller = ctrl
	board.bonus_zones = zones
	board.mob_count = map.mob_count
	board.bronze_threshold = map.bronze_threshold
	board.silver_threshold = map.silver_threshold
	board.gold_threshold = map.gold_threshold

	spawner.board = board  # mobs credit damage/kills to this board
	ctrl.round_manager = board
	ctrl.road_renderer = road  # set BEFORE add_child(ctrl): ctrl._ready calls recompute_path → set_path
	coordinator.register_board(board)

	container.add_child(spawner)
	container.add_child(board)
	container.add_child(ctrl)

	# Non-local boards are played by a bot in offline practice. A networked match
	# passes use_bots=false — opponents are driven by relayed human inputs instead.
	if not is_local and use_bots:
		var bot := BotControllerScript.new()
		bot.board = board
		bot.ctrl = ctrl
		bot.coordinator = coordinator
		container.add_child(bot)

	return board

# Builds the on-screen UI frame for the local board and returns [rail, drawer] (so the
# caller can inject the PVP leaderboard ref and wire the game_view tap guard + drawer's
# game_view). `map` is the MapResource; `ghost_ladder` is the Trials target ladder (null
# outside PVE). The rail (design/INMATCH_HUD.md) is the single home for persistent UI; the
# tower drawer is contextual (docks in the rail's lower gap, or overlays the board).
static func _build_match_ui(host: Node2D, local_board, local_ctrl, map, ghost_ladder) -> Array:
	var mode: int = int(map.mode)
	var rail := RailScript.new()
	rail.round_manager = local_board
	rail.build_controller = local_ctrl
	rail.ghost_ladder = ghost_ladder  # set BEFORE add_child so the SCORE box builds its rungs

	var drawer := TowerDrawerScript.new()
	drawer.round_manager = local_board
	drawer.build_controller = local_ctrl
	drawer.rail = rail  # ask the rail for the in-rail dock slot (else it overlays the board)

	var match_end := MatchEndPanelScript.new()
	match_end.round_manager = local_board
	# Trials (PVE) only: the post-match leaderboard placement block (Surface 1).
	if mode == MapResourceScript.Mode.PVE:
		match_end.lb_ctx = {"window": int(map.window_type), "tier": int(map.scale_tier), "group": "solo"}
	# Networked PVP == ranked → Surface 2 (LP/placement). Offline bot practice has no transport
	# and keeps the plain placement panel (_show_pvp_final).
	match_end.ranked = (mode == MapResourceScript.Mode.PVP and SceneManager.transport != null)

	var round_toast := RoundToastScript.new()
	round_toast.round_manager = local_board

	var pause_menu := PauseMenuScript.new()
	pause_menu.build_controller = local_ctrl
	pause_menu.round_manager = local_board
	rail.pause_menu = pause_menu  # the rail's Menu button drives the pause/menu overlay

	host.add_child(rail)
	host.add_child(drawer)
	# Touch-only bottom-center placement confirm (a board interaction, not rail state).
	if DisplayServer.is_touchscreen_available():
		var build_confirm := BuildConfirmScript.new()
		build_confirm.build_controller = local_ctrl
		host.add_child(build_confirm)
	host.add_child(match_end)
	# The gold-reached "you won — keep playing / go home?" prompt is a campaign-ism. Trials
	# (PVE) runs until its rounds are spent — never interrupt a climb (notes/ghost_ladder.md).
	if mode == MapResourceScript.Mode.CAMPAIGN:
		var win_panel := WinPanelScript.new()
		win_panel.round_manager = local_board
		host.add_child(win_panel)
	host.add_child(round_toast)
	host.add_child(pause_menu)
	return [rail, drawer]

# Trials only: build the in-match ghost ladder (notes/ghost_ladder.md). The snapshot of
# ghost scores is one cached leaderboard read fanned out per (map, window, group-size) at
# match start — empty until the backend is wired, in which case the ladder falls through to
# YOUR BEST / TOP. Campaign keeps the medal-only target; PVP hides the SCORE pill entirely.
static func _build_ghost_ladder(map):
	if map.mode != MapResourceScript.Mode.PVE:
		return null
	var ladder = GhostLadderScript.new()
	var best := SaveData.best_pve_score(map.window_date, map.scale_tier)
	ladder.setup(int(map.bronze_threshold), int(map.silver_threshold), int(map.gold_threshold),
		GhostLadderScript.fetch_snapshot(map), best)
	return ladder

# Bounded board (v3 mockup): a BRIGHT, BORDERED grass arena sized exactly to the play
# grid — no bleed. It sits in the dark recessed surround (see _setup_surround), so the
# playfield is unmistakable and nothing buildable can sit under the UI. A faint cell grid
# marks the buildable cells; it covers exactly the board.
const BOARD_BORDER := 6  # world px of grass-edge frame around the board
static func _setup_background(parent: Node2D, grid_size: Vector2i, board_tex: Texture2D = GRASS_TEX) -> void:
	var tile := GridScript.TILE_SIZE
	var board := Vector2(grid_size.x * tile, grid_size.y * tile)

	# Edge frame: a darker grass-edge rect just behind the grass, peeking BOARD_BORDER px.
	var edge := ColorRect.new()
	edge.color = Color("3c6e26")  # --grass-edge
	edge.position = Vector2(-BOARD_BORDER, -BOARD_BORDER)
	edge.size = board + Vector2(BOARD_BORDER * 2, BOARD_BORDER * 2)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.z_index = -101
	parent.add_child(edge)

	# Bright grass fill, exactly board-sized (tiled). Brighter than the old full-bleed
	# value so the board reads as a lit arena against the dark surround.
	var grass := TextureRect.new()
	grass.texture = board_tex
	grass.stretch_mode = TextureRect.STRETCH_TILE
	grass.size = board
	grass.position = Vector2.ZERO
	grass.modulate = Color(0.88, 0.97, 0.74)
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grass.z_index = -100
	parent.add_child(grass)

	var grid := GridOverlayScript.new()
	grid.cols = grid_size.x
	grid.rows = grid_size.y
	grid.cell = float(tile)
	grid.z_index = -90  # above grass, below the road (-50)
	parent.add_child(grid)

# Screen-space recessed surround: a dark radial-gradient backdrop on its own CanvasLayer
# behind the world, so it fills the whole viewport and never moves with the board camera.
static func _setup_surround(host: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100  # behind the world (default layer 0)
	host.add_child(layer)
	var bg := TextureRect.new()
	bg.texture = _surround_tex()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

static func _surround_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color("26301a"), Color("1d2614")])  # --surround → --surround-2
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.42)
	t.fill_to = Vector2(1.05, 1.05)
	t.width = 256
	t.height = 256
	return t

static func _setup_obstacles(parent: Node2D, map, board_id: String) -> Dictionary:
	# Each prop blocks its footprint rect (seeds the build controller's pathfinding/
	# placement map) and renders a sized, base-anchored sprite (may overhang upward).
	# The footprint comes from the seed (shared); the ART is resolved LOCALLY for this
	# board (board_id) over that footprint — an authored prop_id (campaign .tres) wins,
	# else ObstacleProps.art_for picks a board-scoped prop. Falls back to the deprecated
	# bare-cell list (1×1, board-resolved) if no sized obstacles.
	var blocked := {}
	var defs: Array = map.obstacles if map.obstacles != null else []
	if defs.is_empty() and not map.obstacle_cells.is_empty():
		for cell in map.obstacle_cells:
			_spawn_obstacle(parent, board_id, "", cell, Vector2i.ONE, blocked)
	else:
		for d in defs:
			_spawn_obstacle(parent, board_id, d.prop_id, d.origin, d.footprint, blocked)
	return blocked

static func _spawn_obstacle(parent: Node2D, board_id: String, prop_id: String, origin: Vector2i, footprint: Vector2i, blocked: Dictionary) -> void:
	var tex: Texture2D
	var overhang: float
	if prop_id != "":
		tex = ObstaclePropsScript.tex_for(prop_id)          # authored: use the stamped prop
		overhang = ObstaclePropsScript.overhang_for(prop_id)
	else:
		var art := ObstaclePropsScript.art_for(board_id, footprint, _cell_art_key(origin))
		tex = art["tex"]
		overhang = art["overhang"]
	var obs := ObstacleScript.new()
	parent.add_child(obs)
	obs.setup(tex, origin, footprint, overhang)
	for c in obs.cells:
		blocked[c] = true

# Stable per-cell key so a given obstacle origin always draws the same prop (varied
# across cells). Pure function of the cell — no rng, deterministic, board-scoped.
static func _cell_art_key(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663)

# Builds this board's zones and returns them as an Array (kept on the BoardState
# so towers/mobs query only their own board's zones, not a global group).
static func _setup_zones(parent: Node2D, zone_defs: Array) -> Array:
	var zones: Array = []
	for z in zone_defs:
		var zone := BonusZoneScript.new()
		zone.type = z.type_name()
		zone.magnitude = z.magnitude
		zone.radius = BonusZoneScript.radius_for_magnitude(z.magnitude)
		zone.position = GridScript.cell_to_world(z.cell)
		parent.add_child(zone)
		zones.append(zone)
	return zones

static func _setup_markers(parent: Node2D, checkpoint_cells: Array) -> void:
	# Entry and exit are off-screen (mobs spawn/despawn beyond the map edge), so
	# only checkpoint markers are drawn. Each flag is numbered with its visit order.
	var flag_h := CHECKPOINT_TEX.get_height() * 0.42
	for i in range(checkpoint_cells.size()):
		var cell = checkpoint_cells[i]
		var base := GridScript.cell_to_world(cell)
		var marker := Sprite2D.new()
		marker.texture = CHECKPOINT_TEX
		marker.position = base
		marker.scale = Vector2(0.42, 0.42)
		# Flag is tall (pole) — anchor its BASE at the cell centre, not its middle.
		marker.offset = Vector2(0, -CHECKPOINT_TEX.get_height() * 0.5)
		marker.z_index = 3  # above the road so the flag reads on top of the path
		parent.add_child(marker)

		# Visit-order number, centred on the flag's banner. The digit sits on the pole
		# (horizontally centred) at this fraction of the flag height above the cell —
		# nudged down again per playtest (was .558, still riding too high on the banner).
		# A square label box with centre alignment keeps the digit centred regardless of font.
		var banner_cy := 0.50 * flag_h
		var box := 26.0
		var num := Label.new()
		num.text = str(i + 1)
		num.add_theme_font_size_override("font_size", 15)
		num.add_theme_color_override("font_color", Color.WHITE)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.custom_minimum_size = Vector2(box, box)
		num.z_index = 4  # above the flag sprite
		num.position = base + Vector2(-box * 0.5, -banner_cy - box * 0.5)
		parent.add_child(num)
