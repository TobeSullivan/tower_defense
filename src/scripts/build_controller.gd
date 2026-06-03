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
const PATH_COLOR := Color(0.30, 0.65, 1.0, 0.85)
const PATH_PROJECTED_COLOR := Color(0.55, 0.95, 1.0, 0.95)
const PATH_WIDTH := 6.0
const PATH_PROJECTED_WIDTH := 5.0
const DASH_LEN := 22.0
const DASH_GAP := 14.0
const DASH_FLOW_SPEED := 70.0  # pixels/sec — speed dashes scroll along the path

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

var towers: Array = []
var blocked: Dictionary = {}  # Vector2i -> true

var _ghost: Sprite2D
var _ghost_range: Line2D
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
var _anim_time: float = 0.0
var _redraw_accum: float = 0.0
const REDRAW_INTERVAL := 1.0 / 30.0  # overlay repaint cadence (seconds)

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

func _process(delta: float) -> void:
	_anim_time += delta
	# Throttle the flowing-dash repaint to ~30fps. Repainting every frame meant
	# re-drawing the whole (now much longer, post-supply-bump) maze path 60×/sec,
	# which hammered the GL-compat canvas renderer during build-mode hovering.
	_redraw_accum += delta
	if _redraw_accum >= REDRAW_INTERVAL:
		_redraw_accum = 0.0
		queue_redraw()

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
				_sell_tower_at_cell(cell)

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
	_sell_tower_at_cell(_selected_tower.grid_cell)

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
	queue_redraw()

func _clear_pending() -> void:
	if _pending_cell == _NO_CELL:
		return
	_pending_cell = _NO_CELL
	if _ghost != null:
		_ghost.visible = false
	if _ghost_range != null:
		_ghost_range.visible = false
	_show_projected = false
	emit_signal("build_pending_cleared")
	queue_redraw()

# --- Tower selection (drives the action-rail inspector) ---

func _select_tower(tower: Node2D) -> void:
	if _selected_tower != null and _selected_tower != tower and is_instance_valid(_selected_tower):
		_selected_tower.set_selected(false)
	_selected_tower = tower
	if is_instance_valid(_selected_tower):
		_selected_tower.set_selected(true)
	emit_signal("tower_selected", tower)

func _clear_selection() -> void:
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

func _sell_tower_at_cell(cell: Vector2i) -> void:
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
			return

func recompute_path() -> void:
	_current_path = PathfinderScript.compute_full_path(entry_cell, checkpoint_cells, exit_cell, blocked)

# Path the mobs actually walk: the in-grid path plus off-screen lead-in/lead-out
# so they spawn and despawn beyond the visible map edges.
func current_path_world() -> PackedVector2Array:
	if _current_path.size() < 2:
		return _current_path
	var first: Vector2 = _current_path[0]
	var last: Vector2 = _current_path[_current_path.size() - 1]
	var extended := PackedVector2Array()
	extended.append(Vector2(first.x - OFFSCREEN_PAD, first.y))
	extended.append_array(_current_path)
	extended.append(Vector2(last.x + OFFSCREEN_PAD, last.y))
	return extended

func _compute_projected(cell: Vector2i) -> void:
	var trial: Dictionary = blocked.duplicate()
	trial[cell] = true
	_projected_path = PathfinderScript.compute_full_path(entry_cell, checkpoint_cells, exit_cell, trial)

# --- Drawing ---

func _draw() -> void:
	if _show_projected and _projected_path.size() >= 2:
		_draw_animated_dashes(_projected_path, PATH_PROJECTED_COLOR, PATH_PROJECTED_WIDTH)
	elif _current_path.size() >= 2:
		_draw_animated_dashes(_current_path, PATH_COLOR, PATH_WIDTH)

# Draws a flowing dashed polyline. Dashes are clipped at polyline vertices so
# bends look correct (no straight chords across corners).
func _draw_animated_dashes(pts: PackedVector2Array, color: Color, width: float) -> void:
	var period := DASH_LEN + DASH_GAP
	var offset := fposmod(_anim_time * DASH_FLOW_SPEED, period)

	var cumulative := 0.0
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len <= 0.0001:
			continue
		var dir: Vector2 = (b - a) / seg_len
		var seg_start_g := cumulative
		var seg_end_g := cumulative + seg_len

		var first_k: int = int(floor((seg_start_g - offset) / period)) - 1
		var k := first_k
		while true:
			var dash_g_start := float(k) * period + offset
			var dash_g_end := dash_g_start + DASH_LEN
			if dash_g_start > seg_end_g:
				break
			if dash_g_end > seg_start_g:
				var clip_s: float = maxf(dash_g_start, seg_start_g)
				var clip_e: float = minf(dash_g_end, seg_end_g)
				if clip_e > clip_s:
					var p1: Vector2 = a + dir * (clip_s - seg_start_g)
					var p2: Vector2 = a + dir * (clip_e - seg_start_g)
					draw_line(p1, p2, color, width)  # no AA — AA polylines are heavy in GL compat
			k += 1
		cumulative = seg_end_g

static func _circle_points(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(RANGE_SEGMENTS):
		var a := i * TAU / RANGE_SEGMENTS
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
