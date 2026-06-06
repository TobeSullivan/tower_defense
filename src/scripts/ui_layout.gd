extends Node

# Single source of truth for the in-match UI frame (v3 bounded layout, 2026-06-06).
# The board is a BRIGHT, BORDERED arena recessed into a dark surround — it does NOT
# fill the screen. game_view's camera fits it into the play rect, which is bounded by
# reserved UI zones: a top status bar, a bottom action strip, and a PERMANENT right
# inspector dock (the tower-detail panel). Nothing buildable ever sits under the UI,
# because the click gate (build_controller) and the camera both fit to this same rect.
# The PVP arena minimap (left edge) still FLOATS over the board on demand — it is not a
# reserved zone. (This reverses the earlier full-bleed rework.)
#
# The camera, the bars, the inspector dock, and build_controller's click gate all read
# these statics so they can never disagree. Consumers preload this script and call the
# statics (no class_name, to stay clear of the class-name cycle pitfall).

# NOTE: the bar consts must be ≥ the actual rendered chrome height, or the panels
# overflow onto the board. Verified via the --uidebug overlay.
const TOP_BAR_H := 75.0         # reserved top band; sized so the board clears the pills + their shadow
const BOTTOM_STRIP_H := 87.0   # action plank (round buttons + padding); tuned so the board's gap to the bottom buttons == its gap to the top pills
# Right inspector dock — a PERMANENT reserved zone (the tower-detail panel lives here).
const INSP_W := 248.0          # matches TowerDrawer.DOCK_W
# PVP arena minimap floats over the board (NOT reserved) so the board keeps its width.
const MINIMAP_W := 300.0       # PVP arena minimap, slides in from the left edge
# Gap between the board and the surrounding chrome (left/right/top/bottom breathing).
const BOARD_MARGIN := 12.0
# Board fills the play rect (1.0); margins are baked into play_rect itself.
const PLAY_MARGIN := 1.0
# Kept for the minimap tile-grid internal sizing; no longer a reserved screen zone.
const ARENA_H := 432.0

# High-DPI phones make the 1080p-designed UI illegible at 1x, so scale the whole UI
# (fonts, bars, buttons) AND the in-match board zoom (see game_view) up on touch.
# Desktop stays 1x. The base consts above are the 1x (desktop) values.
# _scale_override lets the capture harness force a scale (e.g. eyeball the 2x touch
# layout on a desktop with no touchscreen); 0 = use the real DisplayServer.
static var _scale_override: float = 0.0

# When the player collapses the right inspector dock, the board reclaims that width.
# play_rect reads this; the inspector toggles it and asks game_view to re-fit.
static var _inspector_hidden: bool = false

static func set_inspector_hidden(v: bool) -> void:
	_inspector_hidden = v

static func set_scale_override(v: float) -> void:
	_scale_override = v

static func scale_factor() -> float:
	if _scale_override > 0.0:
		return _scale_override
	return 2.0 if DisplayServer.is_touchscreen_available() else 1.0

static func top_bar_h() -> float:
	return TOP_BAR_H * scale_factor()

static func bottom_strip_h() -> float:
	return BOTTOM_STRIP_H * scale_factor()

static func insp_w() -> float:
	return INSP_W * scale_factor()

static func board_margin() -> float:
	return BOARD_MARGIN * scale_factor()

static func minimap_w() -> float:
	return MINIMAP_W * scale_factor()

static func arena_h() -> float:
	return ARENA_H * scale_factor()

# The board is recessed into the surround: the play rect is the viewport minus the top
# bar, the bottom strip, the right inspector dock, and a small margin all round. The
# camera fits the bright bordered board into this; everything outside it is dark surround.
static func play_rect(_is_pvp: bool, vp: Vector2) -> Rect2:
	var m := board_margin()
	var top := top_bar_h() + m   # a surround gap below the top bar so the board floats clear of the pills
	var reserved_right := (m if _inspector_hidden else insp_w()) + m
	var w := vp.x - reserved_right - m
	var h := vp.y - top - bottom_strip_h() - m  # and a matching gap above the bottom strip
	return Rect2(m, top, maxf(w, 120.0), maxf(h, 120.0))

# Right-edge zone the tower-detail inspector docks into (PERMANENT reserved zone). Its top
# aligns with the board's (top bar + the same surround gap).
static func inspector_region(vp: Vector2) -> Rect2:
	var m := board_margin()
	return Rect2(vp.x - insp_w(), top_bar_h() + m, insp_w(), vp.y - top_bar_h() - bottom_strip_h() - m * 2.0)

# Left-edge band the PVP arena minimap docks into (floats over the board).
static func minimap_region(vp: Vector2) -> Rect2:
	return Rect2(0.0, top_bar_h(), minimap_w(), vp.y - top_bar_h() - bottom_strip_h())
