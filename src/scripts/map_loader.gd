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
const HUDScript := preload("res://scripts/hud.gd")
const ActionStripScript := preload("res://scripts/action_strip.gd")
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
	var ui = _build_match_ui(host, local_board, local_ctrl)
	var strip = ui[0]
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
		strip.minimap = leaderboard  # the strip's PVP leaderboard button toggles it
		game_view.minimap = leaderboard  # taps over the open panel don't poke the board
		local_ctrl.minimap = leaderboard  # same guard for the mouse path

	return boards

# Lay boards out in a row with the LOCAL board at world origin (slot 0) so the local
# player's sim sits at the origin and the existing cell/mouse math is exact; opponents
# fill the remaining slots in seat order.
# Identifies the exact map for the re-sim record (§2.1). Generated maps rebuild from
# (seed, scale_tier, mode, window); authored campaign maps reload by mission index.
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
	_setup_background(container, map.grid_size)

	# Live dirt-road renderer for the mob path (replaces the old dashed overlay). Add
	# THEN configure (configure needs _ready done). Above grass, below towers/mobs.
	var road := RoadRendererScript.new()
	container.add_child(road)
	road.configure(float(GridScript.TILE_SIZE))
	road.z_index = -50

	var zones := _setup_zones(container, map.bonus_zones)
	_setup_markers(container, map.checkpoint_cells)
	var obstacle_blocked := _setup_obstacles(container, map)

	# Each board owns its own mob list (NOT shared — that would cross-contaminate
	# targeting and run-completion detection across boards).
	var mobs: Array = []

	var spawner := SpawnerScript.new()
	spawner.mobs_array = mobs

	var ctrl := BuildControllerScript.new()
	ctrl.interactive = is_local
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

# Builds the on-screen UI frame for the local board and returns [strip, drawer] (so
# the caller can inject the PVP minimap ref and wire the game_view tap guard).
static func _build_match_ui(host: Node2D, local_board, local_ctrl) -> Array:
	var hud := HUDScript.new()
	hud.round_manager = local_board
	hud.build_controller = local_ctrl

	var strip := ActionStripScript.new()
	strip.round_manager = local_board
	strip.build_controller = local_ctrl

	var drawer := TowerDrawerScript.new()
	drawer.round_manager = local_board
	drawer.build_controller = local_ctrl

	var match_end := MatchEndPanelScript.new()
	match_end.round_manager = local_board

	var win_panel := WinPanelScript.new()
	win_panel.round_manager = local_board

	var round_toast := RoundToastScript.new()
	round_toast.round_manager = local_board

	var pause_menu := PauseMenuScript.new()
	pause_menu.build_controller = local_ctrl
	pause_menu.round_manager = local_board
	strip.pause_menu = pause_menu  # the strip's on-screen Pause button drives the menu

	host.add_child(hud)
	host.add_child(strip)
	host.add_child(drawer)
	host.add_child(match_end)
	host.add_child(win_panel)
	host.add_child(round_toast)
	host.add_child(pause_menu)
	return [strip, drawer]

# Bounded board (v3 mockup): a BRIGHT, BORDERED grass arena sized exactly to the play
# grid — no bleed. It sits in the dark recessed surround (see _setup_surround), so the
# playfield is unmistakable and nothing buildable can sit under the UI. A faint cell grid
# marks the buildable cells; it covers exactly the board.
const BOARD_BORDER := 6  # world px of grass-edge frame around the board
static func _setup_background(parent: Node2D, grid_size: Vector2i) -> void:
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
	grass.texture = GRASS_TEX
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

static func _setup_obstacles(parent: Node2D, map) -> Dictionary:
	# Each prop blocks its footprint rect (seeds the build controller's pathfinding/
	# placement map) and renders a sized, base-anchored sprite (may overhang upward).
	# Falls back to the deprecated bare-cell list (1×1 rubble) if no sized obstacles.
	var blocked := {}
	var defs: Array = map.obstacles if map.obstacles != null else []
	if defs.is_empty() and not map.obstacle_cells.is_empty():
		for cell in map.obstacle_cells:
			_spawn_obstacle(parent, ObstaclePropsScript.FALLBACK_ID, cell, Vector2i.ONE, blocked)
	else:
		for d in defs:
			_spawn_obstacle(parent, d.prop_id, d.origin, d.footprint, blocked)
	return blocked

static func _spawn_obstacle(parent: Node2D, prop_id: String, origin: Vector2i, footprint: Vector2i, blocked: Dictionary) -> void:
	var obs := ObstacleScript.new()
	parent.add_child(obs)
	obs.setup(ObstaclePropsScript.tex_for(prop_id), origin, footprint, ObstaclePropsScript.overhang_for(prop_id))
	for c in obs.cells:
		blocked[c] = true

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
