extends Node2D
class_name BuildController

const TowerScript := preload("res://scripts/tower.gd")
const GridScript := preload("res://scripts/grid.gd")
const PathfinderScript := preload("res://scripts/pathfinder.gd")
const UiLayout := preload("res://scripts/ui_layout.gd")
const LOADED_TEX := preload("res://assets/towers/arrow_box_loaded.png")

const TOWER_SCALE := 0.12
const RANGE_SEGMENTS := 48

# Animated path overlay tuning.

# How far past the map edge mobs spawn/despawn, so entry and exit are off-screen.
const OFFSCREEN_PAD := 160.0

signal towers_changed(count: int, cap: int)
# The action rail listens to these to show/hide the docked tower inspector.
signal tower_selected(tower)
signal selection_cleared
# Touch build flow: a tap parks a preview at a cell (build_pending); a second tap on
# the same cell (or the rail's Build button) confirms. The rail shows a Build/Cancel
# prompt from these. Mouse/desktop never uses them (it places immediately on click).
signal build_pending(cell, cost: int, affordable: bool)
signal build_pending_cleared

# Configured by main.gd before tree entry.
var mobs_array: Array
var entry_cell: Vector2i
var exit_cell: Vector2i
var checkpoint_cells: Array  # Array[Vector2i] in visit order
var max_towers: int = 50  # supply cap — per-map (DESIGN: map variable)
var grid_size: Vector2i = Vector2i(GridScript.COLS, GridScript.ROWS)  # per-map logical play area
var round_manager  # RoundManager — untyped to avoid class-name cycle
# Only the local player's board is interactive. Bot/remote boards still need a
# controller (for the maze path their spawner walks) but take no input and build
# no ghost/upgrade-panel/hint/overlay.
var interactive: bool = true
# UI overlays that float OVER the now-full-width board (set by map_loader for the
# local board). A click over an open one is for that panel, not the board behind it.
var tower_drawer    # TowerDrawer
var minimap         # MinimapPanel (PVP only)
var road_renderer   # RoadRenderer — live dirt-road for the mob path (committed + hover preview)

# Networked PVP only (set by NetMatch on the LOCAL interactive board). When set, local
# build actions are relayed to the other players; opponent boards apply the inbound
# relays via apply_remote_* (which never re-relay, so there's no loop).
const NetProtocolScript := preload("res://net/net_protocol.gd")
var net = null   # NetMatch, or null for solo / offline-bot / opponent boards
var seat: int = 0

var towers: Array = []
var blocked: Dictionary = {}  # Vector2i -> true

var _ghost: Sprite2D
var _ghost_range: Line2D
var _sel_range: Line2D   # high-contrast blue range ring shown for the selected tower
var _selected_tower  # Tower currently shown in the action-rail inspector (or null)

var _build_mode: bool = false
var _current_path: PackedVector2Array = PackedVector2Array()
var _projected_path: PackedVector2Array = PackedVector2Array()
var _show_projected: bool = false

# Ghost-cell cache: validity + projected path are recomputed only when the
# hovered cell (or the maze) changes — NOT every frame. Each recompute runs
# multi-segment A* + string-pull, so per-frame recomputation hammered the heap
# and crashed the engine. Sentinel cell forces a recompute on first hover.
const _NO_CELL := Vector2i(0x7fffffff, 0x7fffffff)
var _last_ghost_cell: Vector2i = _NO_CELL
var _last_ghost_valid: bool = false
# Touch: the cell with a parked build preview (_NO_CELL = none), and whether touch
# input is active (true → the ghost is parked, not following a cursor every frame).
var _pending_cell: Vector2i = _NO_CELL
var _touch_mode: bool = false

func _ready() -> void:
	# Draw path overlay under towers and mobs (which are z=0) but over background/markers.
	z_index = -10

	if interactive:
		_ghost = Sprite2D.new()
		_ghost.texture = LOADED_TEX
		_ghost.scale = Vector2(TOWER_SCALE, TOWER_SCALE)
		_ghost.visible = false
		add_child(_ghost)

		_ghost_range = Line2D.new()
		_ghost_range.width = 2.0
		_ghost_range.closed = true
		_ghost_range.visible = false
		_ghost_range.points = _circle_points(GameConstants.TOWER_BASE_RANGE)
		add_child(_ghost_range)

		# Blue range ring for a selected tower (mockup: high-contrast on grass).
		_sel_range = Line2D.new()
		_sel_range.width = 4.0
		_sel_range.closed = true
		_sel_range.visible = false
		_sel_range.default_color = Color("aee9ff")
		_sel_range.z_index = 2
		add_child(_sel_range)

		# Start in touch mode on touchscreen devices so build-mode-enter doesn't park a
		# hover ghost at a stale cursor cell; a real mouse motion flips it back to hover.
		_touch_mode = DisplayServer.is_touchscreen_available()

		# The tower inspector now lives in the action rail (built by map_loader); the
		# controller just emits tower_selected / selection_cleared for it to react to.
		if round_manager != null:
			round_manager.phase_changed.connect(_on_phase_changed)
	else:
		# Non-interactive board: no input, no per-frame ghost/overlay work.
		set_process(false)
		set_process_input(false)

	recompute_path()
	emit_signal("towers_changed", towers.size(), max_towers)

func _process(_delta: float) -> void:
	# Touch parks the ghost at the pending cell (set on tap); only the mouse path
	# follows a cursor every frame.
	if not _build_mode or _touch_mode:
		return
	var cell := GridScript.world_to_cell(get_global_mouse_position())
	var world := GridScript.cell_to_world(cell)
	_ghost.position = world
	_ghost_range.position = world

	# Recompute validity + projected path only when the hovered cell changes.
	if cell != _last_ghost_cell:
		_last_ghost_cell = cell
		_last_ghost_valid = _is_valid_placement(cell)
		if _last_ghost_valid:
			_compute_projected(cell)

	_apply_ghost_color(_last_ghost_valid)

# Colour the ghost + range ring green (valid) or red (invalid) and toggle the
# projected-path overlay. Shared by the mouse hover and the touch preview.
func _apply_ghost_color(valid: bool) -> void:
	if _ghost == null or _ghost_range == null:
		return
	if valid:
		_ghost.modulate = Color(0.55, 1.0, 0.55, 0.6)
		_ghost_range.default_color = Color(0.4, 1.0, 0.4, 0.6)
		_show_projected = true
	else:
		_ghost.modulate = Color(1.0, 0.4, 0.4, 0.45)
		_ghost_range.default_color = Color(1.0, 0.4, 0.4, 0.6)
		_show_projected = false
	_refresh_road_preview()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				_set_build_mode(not _build_mode)
				return
	# Esc is arbitrated by PauseMenu (priority stack: upgrade panel → build mode
	# → pause menu); see is_build_mode()/is_upgrade_panel_open()/close/exit below.

	# On a touch device, board taps arrive via game_view's handle_tap(). Mouse-from-
	# touch emulation is left ON so the UI buttons work, but that means a board tap also
	# fires a synthetic mouse click here — ignore it so the tap doesn't both preview AND
	# place. Desktop (no touchscreen) keeps the mouse hover/click placement path below.
	if _touch_mode:
		return

	if not (event is InputEventMouseButton and event.pressed):
		return

	var mouse_event: InputEventMouseButton = event
	# Ignore clicks on the reserved UI chrome (top bar / right rail / left dock) —
	# only clicks inside the play rect act on the board. This one screen-space gate
	# keeps board logic from firing (e.g. deselecting a tower) when you click a HUD
	# control, replacing the old floating-panel hit test.
	var is_pvp: bool = round_manager != null and round_manager.coordinator != null and round_manager.coordinator.is_pvp
	if not UiLayout.play_rect(is_pvp, get_viewport_rect().size).has_point(mouse_event.position):
		return
	# The drawer / minimap float over the full-width board; a click on an open one is
	# for that panel (its Control also consumes it), not the board behind it.
	if tower_drawer != null and tower_drawer.covers(mouse_event.position):
		return
	if minimap != null and minimap.has_method("covers") and minimap.covers(mouse_event.position):
		return

	# The placement cell comes from the WORLD mouse position, not the raw event
	# (screen) position — they diverge under the game camera (zoom + offset).
	var cell := GridScript.world_to_cell(get_global_mouse_position())

	if event.button_index == MOUSE_BUTTON_LEFT:
		if _build_mode:
			if not _in_build_phase():
				return
			if not _is_valid_placement(cell):
				return
			if not round_manager.can_afford(GameConstants.TOWER_COST):
				return
			round_manager.spend(GameConstants.TOWER_COST)
			_place_tower(cell)
			_relay_place(cell)
		else:
			var tower_at := _tower_at_cell(cell)
			if tower_at != null:
				_select_tower(tower_at)
			else:
				_clear_selection()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if _build_mode:
			_set_build_mode(false)
		else:
			_clear_selection()
			if _in_build_phase():
				if _sell_tower_at_cell(cell):
					_relay_sell(cell)

func _set_build_mode(value: bool) -> void:
	if value and not _in_build_phase():
		return
	_build_mode = value
	# In touch mode the ghost is hidden until a tap parks a preview; the mouse path
	# shows it immediately so it can follow the cursor.
	var show_ghost: bool = value and not _touch_mode
	if _ghost != null:
		_ghost.visible = show_ghost
	if _ghost_range != null:
		_ghost_range.visible = show_ghost
	_last_ghost_cell = _NO_CELL  # force a fresh validity/path compute on next hover
	if value:
		_ghost_range.points = _circle_points(GameConstants.TOWER_BASE_RANGE)
		_clear_selection()  # can't inspect a tower while placing
	else:
		_show_projected = false
		_refresh_road_preview()
		_clear_pending()  # drop any parked touch preview when leaving build mode

# Public toggle for the action-rail Build button.
func toggle_build_mode() -> void:
	_set_build_mode(not _build_mode)

# --- Touch input (driven by game_view, which owns the camera) ---

# A confirmed tap at a world position. game_view has already gated it to the play
# rect and converted screen→world. Splits into the cell-level state machine below so
# a headless harness can drive _tap_cell() directly without a camera/viewport.
func handle_tap(world_pos: Vector2) -> void:
	if not interactive:
		return
	_touch_mode = true
	_tap_cell(GridScript.world_to_cell(world_pos))

func _tap_cell(cell: Vector2i) -> void:
	# Direct, mode-less tapping (no "enter build mode" step on touch): a tower → inspect
	# it; an empty buildable cell → preview, then a second tap on the same cell (or the
	# rail's Build button) places it.
	var t := _tower_at_cell(cell)
	if t != null:
		_clear_pending()
		_select_tower(t)
		return
	if not _in_build_phase():
		return
	if _pending_cell != _NO_CELL and cell == _pending_cell:
		confirm_pending_build()
	elif _is_valid_placement(cell):
		_clear_selection()
		_set_pending(cell)
	else:
		_clear_pending()  # tapped an unbuildable empty cell — drop the preview

# Build the currently-previewed tower (rail Build button or a second tap on the cell).
func confirm_pending_build() -> void:
	if _pending_cell == _NO_CELL or not _in_build_phase():
		return
	var cell := _pending_cell
	if not _is_valid_placement(cell):
		_clear_pending()
		return
	if round_manager == null or not round_manager.can_afford(GameConstants.TOWER_COST):
		return
	round_manager.spend(GameConstants.TOWER_COST)
	_place_tower(cell)
	_relay_place(cell)
	_clear_pending()  # keep build mode armed for the next tap

func cancel_pending_build() -> void:
	_clear_pending()

# Sell the tower currently shown in the inspector (replaces right-click, which touch
# has no equivalent for). Also wired to the rail's Sell button on desktop.
func sell_selected_tower() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	if not _in_build_phase():
		return
	var cell: Vector2i = _selected_tower.grid_cell
	if _sell_tower_at_cell(cell):
		_relay_sell(cell)

# Park the preview ghost at `cell`, colour it, and tell the rail to show Build/Cancel.
func _set_pending(cell: Vector2i) -> void:
	_pending_cell = cell
	var world := GridScript.cell_to_world(cell)
	if _ghost != null:
		_ghost.position = world
		_ghost.visible = true
	if _ghost_range != null:
		_ghost_range.position = world
		_ghost_range.visible = true
	var valid := _is_valid_placement(cell)
	if valid:
		_compute_projected(cell)
	_apply_ghost_color(valid)
	var afford: bool = round_manager != null and round_manager.can_afford(GameConstants.TOWER_COST)
	emit_signal("build_pending", cell, GameConstants.TOWER_COST, valid and afford)

func _clear_pending() -> void:
	if _pending_cell == _NO_CELL:
		return
	_pending_cell = _NO_CELL
	if _ghost != null:
		_ghost.visible = false
	if _ghost_range != null:
		_ghost_range.visible = false
	_show_projected = false
	_refresh_road_preview()
	emit_signal("build_pending_cleared")

# --- Tower selection (drives the action-rail inspector) ---

func _select_tower(tower: Node2D) -> void:
	if _selected_tower != null and _selected_tower != tower and is_instance_valid(_selected_tower):
		_selected_tower.set_selected(false)
	_selected_tower = tower
	if is_instance_valid(_selected_tower):
		_selected_tower.set_selected(true)
		if _sel_range != null:
			_sel_range.points = _circle_points(_selected_tower.get_range())
			_sel_range.position = _selected_tower.position
			_sel_range.visible = true
	emit_signal("tower_selected", tower)

func _clear_selection() -> void:
	if _sel_range != null:
		_sel_range.visible = false
	if _selected_tower != null and is_instance_valid(_selected_tower):
		_selected_tower.set_selected(false)
	if _selected_tower != null:
		_selected_tower = null
		emit_signal("selection_cleared")

# --- Esc priority-stack hooks, driven by PauseMenu ---

func is_build_mode() -> bool:
	return _build_mode

func is_upgrade_panel_open() -> bool:
	return _selected_tower != null

func close_upgrade_panel() -> void:
	_clear_selection()

func exit_build_mode() -> void:
	_set_build_mode(false)

func _in_build_phase() -> bool:
	return round_manager == null or round_manager.phase == "build"

func _on_phase_changed(phase: String) -> void:
	if phase == "run" and _build_mode:
		_set_build_mode(false)
	# Direction chevrons are a build-phase guide only — hide them once mobs start moving.
	if road_renderer != null:
		road_renderer.set_chevrons_visible(phase == "build")

func _tower_at_cell(cell: Vector2i) -> Node2D:
	for t in towers:
		if not is_instance_valid(t):
			continue
		if t.grid_cell == cell:
			return t
	return null

func _is_valid_placement(cell: Vector2i) -> bool:
	if towers.size() >= max_towers:
		return false
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return false
	if blocked.has(cell):
		return false
	if cell == entry_cell or cell == exit_cell:
		return false
	for cp in checkpoint_cells:
		if cell == cp:
			return false
	var trial: Dictionary = blocked.duplicate()
	trial[cell] = true
	var trial_path := PathfinderScript.compute_full_path(entry_cell, checkpoint_cells, exit_cell, trial)
	return not trial_path.is_empty()

# Bot/remote driver entry: validate, pay, and place a tower at `cell`. Goes through
# the same checks as the human input path. Returns true on success.
func bot_place_tower(cell: Vector2i) -> bool:
	if not _is_valid_placement(cell):
		return false
	if round_manager == null or not round_manager.can_afford(GameConstants.TOWER_COST):
		return false
	round_manager.spend(GameConstants.TOWER_COST)
	_place_tower(cell)
	return true

func _place_tower(cell: Vector2i) -> void:
	var tower := TowerScript.new()
	tower.grid_cell = cell
	tower.position = GridScript.cell_to_world(cell)
	tower.mobs = mobs_array
	tower.board = round_manager  # board-scoped zone lookup (set before _ready)
	tower.total_invested = GameConstants.TOWER_COST
	get_parent().add_child(tower)
	towers.append(tower)
	blocked[cell] = true
	recompute_path()
	_last_ghost_cell = _NO_CELL  # maze changed — invalidate cached ghost validity
	emit_signal("towers_changed", towers.size(), max_towers)

func _sell_tower_at_cell(cell: Vector2i) -> bool:
	for i in range(towers.size() - 1, -1, -1):
		var t = towers[i]
		if not is_instance_valid(t):
			towers.remove_at(i)
			continue
		if t.grid_cell == cell:
			if t == _selected_tower:
				_clear_selection()  # close the inspector for the tower being sold
			var refund := int(floor(t.total_invested * GameConstants.SELL_REFUND_RATE))
			if round_manager != null:
				round_manager.refund(refund)
			blocked.erase(t.grid_cell)
			t.queue_free()
			towers.remove_at(i)
			recompute_path()
			_last_ghost_cell = _NO_CELL  # maze changed — invalidate cached ghost validity
			emit_signal("towers_changed", towers.size(), max_towers)
			return true
	return false

# --- Networked relay (local actions out) + remote application (inbound) ---

func _relay_place(cell: Vector2i) -> void:
	if net != null:
		net.submit_local_input(NetProtocolScript.build_input_place(seat, cell))

func _relay_sell(cell: Vector2i) -> void:
	if net != null:
		net.submit_local_input(NetProtocolScript.build_input_sell(seat, cell))

# Called by tower_drawer after the LOCAL player upgrades a tower (so it relays).
func on_local_upgrade(cell: Vector2i, stat: String) -> void:
	if net != null:
		net.submit_local_input(NetProtocolScript.build_input_upgrade(seat, cell, stat))

# Inbound relays from other players, applied to THIS (opponent) board. The owner already
# validated, so these force-apply (owner is authoritative); economy is best-effort so the
# opponent's gold display stays sane. None of these re-relay (no loop).
func apply_remote_place(cell: Vector2i) -> void:
	if not _is_valid_placement(cell):
		return
	if round_manager != null:
		round_manager.net_spend(GameConstants.TOWER_COST)
	_place_tower(cell)

func apply_remote_sell(cell: Vector2i) -> void:
	_sell_tower_at_cell(cell)

func apply_remote_upgrade(cell: Vector2i, stat: String) -> void:
	var t := _tower_at_cell(cell)
	if t == null:
		return
	if round_manager != null:
		round_manager.net_spend(t.upgrade_cost(stat))
	t.upgrade(stat)

func recompute_path() -> void:
	# Mobs AND the road follow the same ORTHOGONAL grid path (clean L corners, mockup
	# look) so mobs stay ON the road (option B). An 8-dir no-corner-cut path always has
	# an orthogonal equivalent, so this never fails where the old path succeeded.
	_current_path = PathfinderScript.compute_orthogonal_path(entry_cell, checkpoint_cells, exit_cell, blocked)
	if road_renderer != null:
		# Feed the road the SAME horizontally-extended path the mobs walk, so it enters/
		# exits straight off the left/right screen edges instead of forcing a stub in
		# whatever direction the first/last in-grid segment happened to take.
		road_renderer.set_path(current_path_world())

# Push the build-phase hover preview (or clear it) to the road renderer, mirroring
# _show_projected / _projected_path. Called wherever those change.
func _refresh_road_preview() -> void:
	if road_renderer == null:
		return
	if _show_projected and _projected_path.size() >= 2:
		road_renderer.set_preview(_extend_offscreen(_projected_path))
	else:
		road_renderer.clear_preview()

# Path the mobs actually walk: the in-grid path plus off-screen lead-in/lead-out
# so they spawn and despawn beyond the visible map edges.
func current_path_world() -> PackedVector2Array:
	return _extend_offscreen(_current_path)

# Prepend/append a straight lead-in/out to the LEFT (entry) and RIGHT (exit) BOARD EDGES
# at the endpoint's row — so the road and mobs run cleanly to the board boundary and stop
# THERE (bounded layout: nothing spills into the dark surround), while still avoiding a
# vertical stub if the maze's first/last in-grid move is vertical. Mobs spawn/despawn at
# the edge instead of off-screen (the old OFFSCREEN_PAD lead is gone — it bled past the
# bounded board).
func _extend_offscreen(p: PackedVector2Array) -> PackedVector2Array:
	if p.size() < 2:
		return p
	var first: Vector2 = p[0]
	var last: Vector2 = p[p.size() - 1]
	var board_w: float = float(grid_size.x * GridScript.TILE_SIZE)
	var out := PackedVector2Array()
	out.append(Vector2(0.0, first.y))      # left board edge
	out.append_array(p)
	out.append(Vector2(board_w, last.y))   # right board edge
	return out

func _compute_projected(cell: Vector2i) -> void:
	# Only feeds the road hover-preview now, so it uses the orthogonal path too.
	var trial: Dictionary = blocked.duplicate()
	trial[cell] = true
	_projected_path = PathfinderScript.compute_orthogonal_path(entry_cell, checkpoint_cells, exit_cell, trial)

# The mob path is now drawn by RoadRenderer (a Line2D dirt road), updated on path/
# preview change via set_path / set_preview — no per-frame _draw overlay.

static func _circle_points(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(RANGE_SEGMENTS):
		var a := i * TAU / RANGE_SEGMENTS
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
