extends Node2D

# The match camera, present in EVERY mode (solo gets one now too). It fits the
# focused board into the reserved play rect (screen minus the top bar / right rail /
# left dock) rather than letting the board fill the whole screen — which is what
# made the HUD overlap placeable tiles. Build / post-match frames the local board;
# during the run phase the player can focus any board (driven by clicking the arena
# minimap). Replaces the old arena_view.gd. References are untyped to avoid the
# class-name cycle pitfall noted in project memory.

const UiLayout := preload("res://scripts/ui_layout.gd")
const GridScript := preload("res://scripts/grid.gd")

var coordinator                   # MatchCoordinator
var board_containers: Array = []  # Node2D per board, world-positioned
var grid_size: Vector2i
var local_index: int = 0
var is_pvp: bool = false
var local_build_controller        # BuildController for board 0 — receives tap dispatch

var _camera: Camera2D
var _spectate_index: int = 0
var _label: Label

# --- Touch: a still single-finger tap builds/selects. The board is a FIXED, fully-
# visible view — pan and pinch-zoom are intentionally disabled (they felt wrong and
# made tapping unreliable). A drag just suppresses the tap; it does not move the view.
const TAP_MOVE_PX := 16.0  # finger travel above this = a drag (suppresses the tap)
var _touches: Dictionary = {}       # index -> current screen pos
var _touch_start: Dictionary = {}   # index -> press screen pos
var _touch_moved: Dictionary = {}   # index -> bool (dragged past the tap threshold)

func _ready() -> void:
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()

	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_label = Label.new()
	var play := UiLayout.play_rect(is_pvp, get_viewport_rect().size)
	_label.position = play.position + Vector2(14, 10)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)

	if coordinator != null:
		coordinator.phase_changed.connect(_on_phase_changed)
	_focus(local_index)

func _on_phase_changed(phase: String) -> void:
	# Build / post-match: always your own board. Run: keep whoever is being watched.
	if phase != "run":
		_focus(local_index)
	else:
		_update_label()

# Public entry for the arena minimap: frame board `i` in the big view.
func focus_board(i: int) -> void:
	if i >= 0 and i < board_containers.size():
		_focus(i)

func current_index() -> int:
	return _spectate_index

# Frame board `i`: hide the others (no neighbour bleed) and fit it into the play rect.
func _focus(i: int) -> void:
	_spectate_index = i
	for j in range(board_containers.size()):
		board_containers[j].visible = (j == i)
	if _camera == null:
		return
	var board_px := Vector2(grid_size.x, grid_size.y) * float(GridScript.TILE_SIZE)
	var vp := get_viewport_rect().size
	var play := UiLayout.play_rect(is_pvp, vp)
	# Plain fit-to-screen on every platform: the whole board is always visible, no
	# zoom/scroll (the half-size trial board is finger-friendly when fully fit).
	var z: float = minf(play.size.x / board_px.x, play.size.y / board_px.y) * UiLayout.PLAY_MARGIN
	_camera.zoom = Vector2(z, z)
	# Place the board's centre at the play-rect centre on screen. A Camera2D centres
	# its position at the viewport centre, so shift by (play_centre - viewport_centre)/z.
	var board_center: Vector2 = board_containers[i].position + board_px / 2.0
	var play_center: Vector2 = play.position + play.size / 2.0
	var screen_center: Vector2 = vp / 2.0
	_camera.position = board_center - (play_center - screen_center) / z
	_clamp_camera()
	_update_label()

func _update_label() -> void:
	if _label == null:
		return
	if _spectate_index == local_index or (coordinator != null and coordinator.phase != "run"):
		_label.text = ""
	else:
		_label.text = "Spectating Board %d" % (_spectate_index + 1)

# --- Touch gestures + tap dispatch ----------------------------------------------
# Touch lives here (not build_controller) because the camera owns screen↔world. A
# still single-finger tap inside the play rect is dispatched to the local build
# controller; a single-finger drag pans; two fingers pinch-zoom + pan. Mouse-wheel
# zoom is added for desktop parity / testing. The mouse click path is untouched.

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)

func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		# Only board taps inside the play rect; touches on the UI chrome are left to
		# those Controls (driven by mouse-from-touch emulation).
		if not UiLayout.play_rect(is_pvp, get_viewport_rect().size).has_point(e.position):
			return
		_touches[e.index] = e.position
		_touch_start[e.index] = e.position
		_touch_moved[e.index] = false
	else:
		if not _touches.has(e.index):
			return
		var moved: bool = _touch_moved.get(e.index, false)
		var was_multi: bool = _touches.size() > 1
		_touches.erase(e.index)
		_touch_start.erase(e.index)
		_touch_moved.erase(e.index)
		# A clean single-finger lift with no drag = a tap → build/select.
		if _touches.is_empty() and not moved and not was_multi:
			_dispatch_tap(e.position)

func _on_drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	_touches[e.index] = e.position
	if e.position.distance_to(_touch_start.get(e.index, e.position)) > TAP_MOVE_PX:
		_touch_moved[e.index] = true  # a drag just suppresses the tap; no scroll (board fits)

# Keep the visible play-rect within the focused board on any axis where the board
# (at the current zoom) is bigger than the play rect; otherwise leave it centred.
func _clamp_camera() -> void:
	if _camera == null or board_containers.is_empty():
		return
	var i := _spectate_index
	if i < 0 or i >= board_containers.size():
		return
	var board_px := Vector2(grid_size.x, grid_size.y) * float(GridScript.TILE_SIZE)
	var board_min: Vector2 = board_containers[i].position
	var board_max: Vector2 = board_min + board_px
	var vp := get_viewport_rect().size
	var play := UiLayout.play_rect(is_pvp, vp)
	var z := _camera.zoom.x
	# world_at(screen) = camera.position + (screen - vp/2) / z
	var lo: Vector2 = board_min - (play.position - vp / 2.0) / z
	var hi: Vector2 = board_max - (play.position + play.size - vp / 2.0) / z
	var pos: Vector2 = _camera.position
	if board_px.x * z > play.size.x:
		pos.x = clampf(pos.x, minf(lo.x, hi.x), maxf(lo.x, hi.x))
	if board_px.y * z > play.size.y:
		pos.y = clampf(pos.y, minf(lo.y, hi.y), maxf(lo.y, hi.y))
	_camera.position = pos

func _dispatch_tap(screen_pos: Vector2) -> void:
	if local_build_controller == null:
		return
	local_build_controller.handle_tap(_screen_to_world(screen_pos))

func _screen_to_world(s: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return _camera.position + (s - vp / 2.0) / _camera.zoom.x
