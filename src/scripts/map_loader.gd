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
const ActionRailScript := preload("res://scripts/action_rail.gd")
const MatchEndPanelScript := preload("res://scripts/match_end_panel.gd")
const WinPanelScript := preload("res://scripts/win_panel.gd")
const RoundToastScript := preload("res://scripts/round_toast.gd")
const PauseMenuScript := preload("res://scripts/pause_menu.gd")
const GameViewScript := preload("res://scripts/game_view.gd")
const MinimapPanelScript := preload("res://scripts/minimap_panel.gd")
const BotControllerScript := preload("res://scripts/bot_controller.gd")
const PlaytestLogScript := preload("res://scripts/playtest_log.gd")
const ObstacleScript := preload("res://scripts/obstacle.gd")
const ZoneDefinitionScript := preload("res://resources/zone_definition.gd")
const MapResourceScript := preload("res://resources/map_resource.gd")

const CHECKPOINT_TEX := preload("res://assets/maps/level_marker_01.png")
const GRASS_TEX := preload("res://assets/maps/summer_grass_tile.png")
# The schema stores obstacles as bare cells (no texture/footprint), so every
# obstacle cell renders with this single debris prop.
const OBSTACLE_TEX := preload("res://assets/environment/props/rubble_pile_01.png")

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
static func build_match(host: Node2D, map, num_boards: int = 1) -> Array:
	var coordinator := MatchCoordinatorScript.new()
	coordinator.max_rounds = map.round_count
	coordinator.is_pvp = (map.mode == MapResourceScript.Mode.PVP)
	host.add_child(coordinator)

	var boards: Array = []
	var containers: Array = []
	for i in range(num_boards):
		var container := Node2D.new()
		container.name = "Board%d" % i
		container.position = _board_offset(i, map.grid_size)
		host.add_child(container)
		containers.append(container)
		var board = _build_board(container, map, coordinator, i == 0)
		if coordinator.is_pvp:
			board.lives = GameConstants.LIVES_PER_PLAYER
		boards.append(board)

	# On-screen UI is bound to the local player's board (board 0).
	_build_match_ui(host, boards[0], boards[0].build_controller)

	# Playtest telemetry for threshold calibration (local board only; user:// only).
	var plog := PlaytestLogScript.new()
	plog.board = boards[0]
	plog.coordinator = coordinator
	plog.map = map
	host.add_child(plog)

	# Game camera in EVERY mode — fits the board into the reserved play rect so the
	# UI frame never overlaps the play area.
	var game_view := GameViewScript.new()
	game_view.coordinator = coordinator
	game_view.board_containers = containers
	game_view.grid_size = map.grid_size
	game_view.local_index = 0
	game_view.is_pvp = coordinator.is_pvp
	game_view.local_build_controller = boards[0].build_controller  # touch tap dispatch
	host.add_child(game_view)

	# Arena minimap only for multi-board matches (PVP).
	if num_boards > 1:
		var minimap := MinimapPanelScript.new()
		minimap.coordinator = coordinator
		minimap.boards = boards
		minimap.local_index = 0
		minimap.grid_size = map.grid_size
		minimap.arena = game_view
		host.add_child(minimap)

	return boards

static func _board_offset(index: int, grid_size: Vector2i) -> Vector2:
	if index == 0:
		return Vector2.ZERO
	var stride := (grid_size.x + BOARD_GAP_TILES) * GridScript.TILE_SIZE
	return Vector2(index * stride, 0.0)

# Builds one board's full sim subtree under `container` and returns its BoardState.
static func _build_board(container: Node2D, map, coordinator, is_local: bool):
	_setup_background(container, map.grid_size)
	var zones := _setup_zones(container, map.bonus_zones)
	_setup_markers(container, map.checkpoint_cells)
	var obstacle_blocked := _setup_obstacles(container, map.obstacle_cells)

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
	coordinator.register_board(board)

	container.add_child(spawner)
	container.add_child(board)
	container.add_child(ctrl)

	# Non-local boards are played by a bot (solves cold-start; real netcode swaps
	# this for a remote driver later).
	if not is_local:
		var bot := BotControllerScript.new()
		bot.board = board
		bot.ctrl = ctrl
		bot.coordinator = coordinator
		container.add_child(bot)

	return board

static func _build_match_ui(host: Node2D, local_board, local_ctrl) -> void:
	var hud := HUDScript.new()
	hud.round_manager = local_board
	hud.build_controller = local_ctrl

	var rail := ActionRailScript.new()
	rail.round_manager = local_board
	rail.build_controller = local_ctrl

	var match_end := MatchEndPanelScript.new()
	match_end.round_manager = local_board

	var win_panel := WinPanelScript.new()
	win_panel.round_manager = local_board

	var round_toast := RoundToastScript.new()
	round_toast.round_manager = local_board

	var pause_menu := PauseMenuScript.new()
	pause_menu.build_controller = local_ctrl
	pause_menu.round_manager = local_board
	rail.pause_menu = pause_menu  # the rail's on-screen Pause button drives the menu

	host.add_child(hud)
	host.add_child(rail)
	host.add_child(match_end)
	host.add_child(win_panel)
	host.add_child(round_toast)
	host.add_child(pause_menu)

# Grass covers exactly the play grid — its edge IS the buildable boundary, so the
# player can see where they can place (the old over-pad made the off-grid margin
# look buildable and read as an "invisible blocker"). The area around the board
# inside the play rect is the dark clear colour (see project.godot), framing it.
static func _setup_background(parent: Node2D, grid_size: Vector2i) -> void:
	var bg := TextureRect.new()
	bg.texture = GRASS_TEX
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.size = Vector2(grid_size.x * GridScript.TILE_SIZE, grid_size.y * GridScript.TILE_SIZE)
	bg.z_index = -100
	parent.add_child(bg)

static func _setup_obstacles(parent: Node2D, obstacle_cells: Array) -> Dictionary:
	# Each obstacle cell becomes a permanent wall (seeds the build controller's
	# pathfinding/placement map) and renders a single-tile debris prop.
	var blocked := {}
	for cell in obstacle_cells:
		var obs := ObstacleScript.new()
		parent.add_child(obs)
		obs.setup(OBSTACLE_TEX, cell, 1, 1)
		for c in obs.cells:
			blocked[c] = true
	return blocked

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
	# only checkpoint markers are drawn.
	for cell in checkpoint_cells:
		var marker := Sprite2D.new()
		marker.texture = CHECKPOINT_TEX
		marker.position = GridScript.cell_to_world(cell)
		marker.scale = Vector2(0.55, 0.55)
		marker.z_index = -40
		parent.add_child(marker)
