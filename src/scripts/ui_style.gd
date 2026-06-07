extends Node

# Canonical UI look (design/VISUAL_SYSTEM.md). One flat, warm vocabulary shared by the
# in-match HUD AND every menu / modal panel: rounded pills, chips, cards, and control
# buttons over a toned-grass backdrop. The old blue dark-panel theme and the wooden-plank
# theme are RETIRED and removed — this is the only vocabulary now.
#
# Type + outline are distributed by the project base theme (assets/ui/app_theme.tres),
# so screens no longer re-declare font weight or outline per-Label.

# ============================================================================
# Tokens (palette midpoints from the mockup; hex matches VISUAL_SYSTEM "Palette").
# ============================================================================

const PILL_BG := Color("323d2c")
const PILL_BORDER := Color("1a2012")
const PILL_GOLD := Color("b38e2c")
const PILL_GOLD_BORDER := Color("5e4710")
const CHIP_BG := Color("39402c")
const CHIP_BORDER := Color("23170d")
const START_BG := Color("5fbe38")
const START_BORDER := Color("2c5a18")
const UP_BG := Color("6fae3a")
const SELL_BG := Color("b04a2a")
const SELL_BORDER := Color("5e2310")
const DOCK_BG := Color("2a3322")
const DOCK_BORDER := Color("161c0f")
const LABEL_COL := Color("b9c7a4")
const STAT_BG := Color(0, 0, 0, 0.22)

# ============================================================================
# Icon loading infra (used by the in-match HUD top bar / dock / strip).
# ============================================================================

const TEX_DIR := "res://assets/ui/"

static func _tex(path: String) -> Texture2D:
	var full := TEX_DIR + path
	if ResourceLoader.exists(full):
		return load(full)
	return null

static func icon_texture(icon_name: String) -> Texture2D:
	return _tex("icons/%s.png" % icon_name)

# Small inline status icon for the top bar (coin / heart / timer / medal).
static func icon_rect(icon_name: String, px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _tex("icons/%s.png" % icon_name)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

# ============================================================================
# Flat surfaces & buttons.
# ============================================================================

static func _flat(bg: Color, corner: int, border_col: Color, border_w: int, shadow := true, pad_h := 0, pad_v := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(corner)
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.border_width_bottom = border_w + 2  # subtle bevel
	if pad_h > 0:
		sb.content_margin_left = pad_h
		sb.content_margin_right = pad_h
	if pad_v > 0:
		sb.content_margin_top = pad_v
		sb.content_margin_bottom = pad_v
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.42)
		sb.shadow_size = 3            # halved (was 7) — drop shadows were too strong
		sb.shadow_offset = Vector2(0, 2)  # halved (was 5)
	return sb

static func pill_box(gold := false) -> StyleBoxFlat:
	if gold:
		return _flat(PILL_GOLD, 16, PILL_GOLD_BORDER, 2)
	return _flat(PILL_BG, 16, PILL_BORDER, 2)

# Public flat surface for arbitrary panels (leaderboard rows, band tags) that need a
# one-off colour without a dedicated named role.
static func flat_box(bg: Color, corner: int, border_col: Color, border_w := 2, shadow := true) -> StyleBoxFlat:
	return _flat(bg, corner, border_col, border_w, shadow)

static func stat_box() -> StyleBoxFlat:
	return _flat(STAT_BG, 10, Color(0, 0, 0, 0), 0, false)

static func dock_box() -> StyleBoxFlat:
	return _flat(DOCK_BG, 18, DOCK_BORDER, 2)

# Card / modal-panel surface (pause, settings, win, match-end, mission cards).
static func apply_card(p: Control, corner := 18) -> void:
	p.add_theme_stylebox_override("panel", _flat(DOCK_BG, corner, DOCK_BORDER, 2))

# Apply a button look from a base bg colour, with hover (lighter) / pressed (darker).
# pad_h/pad_v add internal padding so text/icons aren't squished against the edges.
static func style_flat_button(b: Button, bg: Color, corner: int, border_col: Color, border_w := 2, shadow := true, pad_h := 16, pad_v := 9) -> void:
	b.add_theme_stylebox_override("normal", _flat(bg, corner, border_col, border_w, shadow, pad_h, pad_v))
	b.add_theme_stylebox_override("hover", _flat(bg.lightened(0.10), corner, border_col, border_w, shadow, pad_h, pad_v))
	b.add_theme_stylebox_override("pressed", _flat(bg.darkened(0.14), corner, border_col, border_w, shadow, pad_h, pad_v))
	b.add_theme_stylebox_override("disabled", _flat(bg.darkened(0.35), corner, border_col, border_w, false, pad_h, pad_v))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_color_disabled", Color(1, 1, 1, 0.45))

# --- Named menu button roles (hierarchy by SIZE, colour reserved per VISUAL_SYSTEM) ---

# Large hero button (PVE / PVP). Neutral pill surface; SIZE carries the hierarchy.
static func style_hero_button(b: Button) -> void:
	style_flat_button(b, PILL_BG, 16, PILL_BORDER, 2, true, 24, 16)

# Green primary "go" CTA (Resume, Play). Green is reserved for go/primary.
static func style_go_button(b: Button) -> void:
	style_flat_button(b, START_BG, 16, START_BORDER, 2, true, 18, 11)

# Destructive (Quit / Restart confirm).
static func style_danger_button(b: Button) -> void:
	style_flat_button(b, SELL_BG, 16, SELL_BORDER, 2, true, 18, 11)

# Neutral secondary / tertiary menu button (chip surface).
static func style_menu_button(b: Button) -> void:
	style_flat_button(b, CHIP_BG, 14, CHIP_BORDER, 2, true, 16, 10)

# Toggle tab (PVE Daily / Weekly / Monthly). Dim when off, gold-lit when on.
static func style_tab_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _flat(CHIP_BG.darkened(0.12), 14, CHIP_BORDER, 2, false, 18, 9))
	b.add_theme_stylebox_override("hover", _flat(CHIP_BG, 14, CHIP_BORDER, 2, false, 18, 9))
	var lit := _flat(PILL_GOLD, 14, PILL_GOLD_BORDER, 2, true, 18, 9)
	b.add_theme_stylebox_override("pressed", lit)
	b.add_theme_stylebox_override("hover_pressed", lit)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color.WHITE)

# ============================================================================
# Menu backdrop — inert toned grass + darkening vignette (VISUAL_SYSTEM "Menu
# backdrop"): a dumb static surface, NOT a live match. No fabricated decoration.
# ============================================================================

const GRASS_MENU_TEX := preload("res://assets/maps/summer_grass_tile.png")

static func menu_backdrop(parent: Control) -> void:
	var grass := TextureRect.new()
	grass.texture = GRASS_MENU_TEX
	grass.stretch_mode = TextureRect.STRETCH_TILE
	grass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grass.modulate = Color(0.72, 0.80, 0.62)  # same toned grass as in-match
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(grass)

	var vign := TextureRect.new()
	vign.texture = _vignette_tex()
	vign.stretch_mode = TextureRect.STRETCH_SCALE
	vign.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vign)

static func _vignette_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.08), Color(0, 0, 0, 0.62)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t
