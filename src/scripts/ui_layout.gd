extends Node

# Single source of truth for the in-match UI frame. The board no longer fills the
# screen — it's fit (by game_view's camera) into a play rect bounded by reserved UI
# zones: a top status bar, a right action/inspector rail, and (PVP only) a left
# arena dock. The camera, the bars, the dock, and build_controller's click gate all
# read these so they can never disagree. Consumers preload this script and call the
# statics (no class_name, to stay clear of the class-name cycle pitfall in memory).

const TOP_BAR_H := 52.0
const RIGHT_RAIL_W := 340.0
# Board fills the play rect (1.0). It's a wide 40×22, so it's width-limited and a
# small dark letterbox remains top/bottom — that's inherent to the aspect, not slack.
const PLAY_MARGIN := 1.0
# The PVP arena minimap lives in the bottom of the right rail (no separate left
# dock), so the board reserves only the rail and gets the full screen width.
const ARENA_H := 432.0

# High-DPI phones make the 1080p-designed UI illegible at 1x, so scale the whole UI
# (fonts, bars, buttons) AND the in-match board zoom (see game_view) up on touch.
# Desktop stays 1x. The base consts above are the 1x (desktop) values.
static func scale_factor() -> float:
	return 2.0 if DisplayServer.is_touchscreen_available() else 1.0

static func top_bar_h() -> float:
	return TOP_BAR_H * scale_factor()

static func right_rail_w() -> float:
	return RIGHT_RAIL_W * scale_factor()

static func arena_h() -> float:
	return ARENA_H * scale_factor()

# The rectangle (in screen space) the board is allowed to occupy. Both modes reserve
# only the right rail (is_pvp kept for callers; the layout no longer differs by it).
static func play_rect(is_pvp: bool, vp: Vector2) -> Rect2:
	return Rect2(0.0, top_bar_h(), vp.x - right_rail_w(), vp.y - top_bar_h())

# Region inside the right rail where the PVP arena minimap is drawn (bottom strip).
static func arena_region(vp: Vector2) -> Rect2:
	return Rect2(vp.x - right_rail_w(), vp.y - arena_h(), right_rail_w(), arena_h())
