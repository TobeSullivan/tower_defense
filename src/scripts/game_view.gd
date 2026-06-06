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
var tower_drawer                  # TowerDrawer — taps over its open panel skip the board
var minimap                       # LeaderboardPanel (PVP) — taps over its open panel skip too
var board_names: Array = []       # PVP display handles (index = board index)

const UiStyle := preload("res://scripts/ui_style.gd")

var _camera: Camera2D
var _spectate_index: int = 0
# Spectate safeguards (PVP): a green inset frame + "Spectating <name>" banner + an
# always-present "Back to your board" button make it unmistakable you are NOT on your
# own board. Build phase force-returns the camera home, so these never show then.
var _frame: Panel
var _banner: PanelContainer
var _banner_label: Label
var _back_button: Button

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
	layer.layer = 7  # above HUD/strip so the spectate chrome is unmistakable
	add_child(layer)
	_build_spectate_chrome(layer)

	if coordinator != null:
		coordinator.phase_changed.connect(_on_phase_changed)
	_focus(local_index)

# Green inset frame + top-centre banner + "Back to your board" button. All hidden until
# the player spectates an opponent during the run; the frame is mouse-transparent.
func _build_spectate_chrome(layer: CanvasLayer) -> void:
	var s := UiLayout.scale_factor()

	_frame = Panel.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0)        # border only — see the live board through it
	fsb.draw_center = false
	fsb.border_color = UiStyle.START_BG     # green
	fsb.set_border_width_all(int(6 * s))
	fsb.set_corner_radius_all(0)
	_frame.add_theme_stylebox_override("panel", fsb)
	_frame.visible = false
	layer.add_child(_frame)

	_banner = PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = UiStyle.START_BG
	bsb.border_color = UiStyle.START_BORDER
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(14)
	bsb.content_margin_left = 18 * s
	bsb.content_margin_right = 18 * s
	bsb.content_margin_top = 8 * s
	bsb.content_margin_bottom = 8 * s
	_banner.add_theme_stylebox_override("panel", bsb)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 14 * s
	_banner.visible = false
	layer.add_child(_banner)
	_banner_label = Label.new()
	_banner_label.add_theme_font_size_override("font_size", int(18 * s))
	_banner.add_child(_banner_label)

	_back_button = Button.new()
	_back_button.text = "← Back to your board"
	_back_button.add_theme_font_size_override("font_size", int(16 * s))
	UiStyle.style_flat_button(_back_button, UiStyle.PILL_BG, 14, UiStyle.PILL_BORDER)
	_back_button.anchor_left = 0.5
	_back_button.anchor_right = 0.5
	_back_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_back_button.offset_top = 58 * s
	_back_button.visible = false
	_back_button.pressed.connect(func(): focus_board(local_index))
	layer.add_child(_back_button)

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

# Re-fit the current board into the (possibly changed) play rect — e.g. after the
# inspector dock is collapsed/expanded, which changes how much width the board gets.
func refit() -> void:
	_focus(_spectate_index)

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
	if _frame == null:
		return
	var spectating: bool = _spectate_index != local_index \
		and coordinator != null and coordinator.phase == "run"
	_frame.visible = spectating
	_banner.visible = spectating
	_back_button.visible = spectating
	if spectating:
		_banner_label.text = "Spectating %s" % _name_for(_spectate_index)

func _name_for(i: int) -> String:
	if i >= 0 and i < board_names.size() and String(board_names[i]) != "":
		return board_names[i]
	return "Board %d" % (i + 1)

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
		# The tower drawer / arena minimap float OVER the full-width board; a tap on an
		# open one is for that panel, not the board behind it.
		if _over_open_overlay(e.position):
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

func _over_open_overlay(pos: Vector2) -> bool:
	if tower_drawer != null and tower_drawer.covers(pos):
		return true
	if minimap != null and minimap.has_method("covers") and minimap.covers(pos):
		return true
	return false

func _dispatch_tap(screen_pos: Vector2) -> void:
	if local_build_controller == null:
		return
	if _over_open_overlay(screen_pos):
		return
	local_build_controller.handle_tap(_screen_to_world(screen_pos))

func _screen_to_world(s: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return _camera.position + (s - vp / 2.0) / _camera.zoom.x
