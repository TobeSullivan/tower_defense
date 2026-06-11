extends CanvasLayer
class_name MatchEndPanel

# End-of-match panel, bound to the local board. Three modes:
#   - medal: campaign / solo PVE — medal + thresholds + Return Home / Play Again
#   - pvp_final: PVP match over — your placement + Find New Match / Return Home
#   - pvp_eliminated: local board knocked out mid-match — placement + Spectate /
#     Quit to Menu (the match keeps running; the player can watch via the camera)

const UiStyle := preload("res://scripts/ui_style.gd")
const StarRatingScript := preload("res://scripts/star_rating.gd")
const LeaderboardService := preload("res://scripts/leaderboard_service.gd")
const RankedLadder := preload("res://scripts/ranked_ladder.gd")
const Motion := preload("res://scripts/motion.gd")
const TaskCatalogScript := preload("res://scripts/task_catalog.gd")  # season nudge labels

var round_manager  # RoundManager (local board) — untyped to avoid class-name cycle
# Trials (PVE) leaderboard context: {window:int, tier:int, group:String}. Set by map_loader
# for PVE only; empty for campaign/PVP (no Surface-1 placement block then).
var lb_ctx := {}
# Networked PVP == ranked: render Surface 2 (LP/placement) instead of the plain placement panel.
# Set by map_loader (true only for a networked match; bot practice keeps _show_pvp_final).
var ranked := false

var _panel: PanelContainer
var _title_label: Label
var _result_label: Label
var _detail_label: Label
var _stars_row: HBoxContainer    # medal mode: the earned star tier
var _thresholds_vbox: VBoxContainer
var _lb_vbox: VBoxContainer       # Trials post-match placement block (Surface 1)
var _season_vbox: VBoxContainer   # season-XP nudge (tasks completed this match) — Trials/Ranked
var _buttons_vbox: VBoxContainer

# Scrim dims the (now-static) board behind any result (design/JUICE.md victory_screen_mock:
# "board stays calm, dimmed; juice lives in the frame"). Shown for every result mode.
var _scrim: ColorRect
# Campaign victory composition (the mock): an angled gold hero overlapping the dimmed board,
# square star tiles (full outline — fixes polish #7), a DAMAGE score, and leave-only buttons.
# Separate from the card so the data-dense PVP/ranked/Trials modes keep their card layout.
var _victory: Control
var _hero: PanelContainer
var _hero_big: Label
var _hero_sub: Label
var _tiles_row: HBoxContainer
var _vscore_val: Label
var _score_block: VBoxContainer   # DAMAGE key + value, faded/ticked as one unit in the choreo
var _vbuttons: HBoxContainer
var _victory_damage := 0          # cached for the score tick

# Ranked Surface 2 staged-climb refs (design/JUICE.md "Staged climbs" + staged_climbs_mock):
# the LP bar fills on the settle curve, values pop, a promotion is a staged set-piece.
var _lp_bar: ProgressBar
var _lp_value_lbl: Label
var _lp_tier_lbl: Label
var _promo_note: Label            # null unless promoted/demoted
var _ranked_rows: Array = []      # FINAL ORDER rows, staggered in

const STAR_FOR_MEDAL := {"gold": 3, "silver": 2, "bronze": 1, "none": 0}
const MEDAL_RESULT := {
	"gold": "Three stars!", "silver": "Two stars", "bronze": "One star", "none": "No stars yet",
}
const MEDAL_RESULT_COLOR := {
	"gold":   Color(1.0, 0.85, 0.2),
	"silver": Color(0.85, 0.85, 0.9),
	"bronze": Color(0.85, 0.55, 0.25),
	"none":   Color(0.8, 0.8, 0.8),
}

func _ready() -> void:
	layer = 20
	_build_ui()
	_panel.visible = false
	if round_manager != null:
		round_manager.match_ended.connect(_on_match_ended)
		var coord = round_manager.coordinator
		if coord != null and coord.is_pvp:
			coord.board_eliminated.connect(_on_board_eliminated)

func _build_ui() -> void:
	# Scrim behind everything (added first = drawn behind the card / victory composition).
	_scrim = ColorRect.new()
	_scrim.color = Color(0.03, 0.04, 0.02, 0.62)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP  # absorb board clicks under the result
	_scrim.visible = false
	add_child(_scrim)

	_panel = PanelContainer.new()
	UiStyle.apply_card(_panel, 18)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	# Size to content (the Trials placement block makes the medal panel taller than PVP).
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(480, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_title_label = _make_label(28, Color.WHITE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Earned star tier (medal mode only) — big stars above the result caption.
	_stars_row = HBoxContainer.new()
	_stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_stars_row)

	_result_label = _make_label(28, Color.WHITE)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_result_label)

	_detail_label = _make_label(20, Color.WHITE)
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_detail_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_thresholds_vbox = VBoxContainer.new()
	_thresholds_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_thresholds_vbox)

	# Trials post-match placement block (Surface 1) — populated in medal mode for PVE only.
	_lb_vbox = VBoxContainer.new()
	_lb_vbox.add_theme_constant_override("separation", 6)
	_lb_vbox.visible = false
	vbox.add_child(_lb_vbox)

	# Season-XP nudge (populated in Trials/Ranked when this match completed a task).
	_season_vbox = VBoxContainer.new()
	_season_vbox.add_theme_constant_override("separation", 6)
	_season_vbox.visible = false
	vbox.add_child(_season_vbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	_buttons_vbox = VBoxContainer.new()
	_buttons_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_buttons_vbox)

	_build_victory()

# --- Campaign victory composition (design/JUICE.md victory_screen_mock.html) ---
# An angled gold hero overlapping the dimmed board, a row of square star tiles (full clean
# outline — polish #7), the DAMAGE score, and leave-only buttons. Static positions now; the
# staged reveal (cascade / pop / tick) is the later juice pass and slots onto these elements.
func _build_victory() -> void:
	_victory = Control.new()
	_victory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_victory.visible = false
	add_child(_victory)

	# Centered column: hero (tilted) → star tiles → score. Lifted slightly above center so the
	# bottom buttons have clear room.
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 30)
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.offset_top = -70  # nudge the centered block up; buttons live at the bottom
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_victory.add_child(col)

	# Hero — one tidy gold box, text on the box's angle (tilt applied after layout).
	_hero = PanelContainer.new()
	_hero.add_theme_stylebox_override("panel", UiStyle.flat_box(UiStyle.PILL_GOLD, 16, UiStyle.PILL_GOLD_BORDER, 2, true))
	_hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 44); hm.add_theme_constant_override("margin_right", 44)
	hm.add_theme_constant_override("margin_top", 14); hm.add_theme_constant_override("margin_bottom", 16)
	_hero.add_child(hm)
	var hv := VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 2)
	hm.add_child(hv)
	_hero_big = _make_label(44, Color.WHITE)
	_hero_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_big.add_theme_color_override("font_outline_color", UiStyle.PILL_GOLD_BORDER)
	_hero_big.add_theme_constant_override("outline_size", 6)
	hv.add_child(_hero_big)
	_hero_sub = _make_label(15, UiStyle.PILL_GOLD_BORDER)
	_hero_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_sub.add_theme_constant_override("outline_size", 0)
	hv.add_child(_hero_sub)
	col.add_child(_hero)

	# Star tiles.
	_tiles_row = HBoxContainer.new()
	_tiles_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tiles_row.add_theme_constant_override("separation", 18)
	col.add_child(_tiles_row)

	# Score block.
	var sblk := VBoxContainer.new()
	_score_block = sblk
	sblk.alignment = BoxContainer.ALIGNMENT_CENTER
	sblk.add_theme_constant_override("separation", 2)
	var skey := _make_label(13, UiStyle.LABEL_COL)
	skey.text = "DAMAGE"
	skey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sblk.add_child(skey)
	_vscore_val = _make_label(46, UiStyle.PILL_GOLD)
	_vscore_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sblk.add_child(_vscore_val)
	col.add_child(sblk)

	# Buttons — axis-aligned (precision targets stay square), anchored bottom-center.
	_vbuttons = HBoxContainer.new()
	_vbuttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbuttons.add_theme_constant_override("separation", 12)
	_vbuttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_vbuttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_vbuttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_vbuttons.offset_bottom = -48  # 48px clear of the bottom edge
	_victory.add_child(_vbuttons)

# One 78px square star tile: earned = gold fill + full clean outline; empty = card fill.
func _star_tile(earned: bool) -> Control:
	var size := 78.0
	var tile := PanelContainer.new()
	tile.set_meta("earned", earned)  # the choreo pops earned tiles on land
	tile.custom_minimum_size = Vector2(size, size)
	var bg: Color = UiStyle.PILL_GOLD if earned else UiStyle.CHIP_BG
	var border: Color = UiStyle.PILL_GOLD_BORDER if earned else UiStyle.CHIP_BORDER
	tile.add_theme_stylebox_override("panel", UiStyle.flat_box(bg, 16, border, 3, earned))
	var cc := CenterContainer.new()
	tile.add_child(cc)
	var l := _make_label(38, Color("fff8e6") if earned else Color("566049"))
	l.text = "★"
	cc.add_child(l)
	return tile

# --- Mode entry points ---

func _on_match_ended() -> void:
	_scrim.visible = true  # dim the now-static board behind any result
	var coord = round_manager.coordinator
	if coord != null and coord.is_pvp:
		if ranked:
			_show_pvp_ranked(coord)
		else:
			_show_pvp_final(coord)
	else:
		_show_medal()

func _on_board_eliminated(board) -> void:
	var coord = round_manager.coordinator
	# Only react to the LOCAL board's elimination, and not once the match is over
	# (the final panel takes precedence then).
	if board != round_manager or coord == null or coord.match_over:
		return
	_scrim.visible = true
	var placement: int = coord.placement_of(round_manager)
	_title_label.text = "Eliminated"
	_result_label.text = "%s of %d" % [_ordinal(placement), coord.boards.size()]
	_result_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	_detail_label.text = "Your lives ran out. The match continues."
	_stars_row.visible = false
	_thresholds_vbox.visible = false
	_set_buttons([
		{"text": "Spectate", "cb": _hide_panel, "role": "go"},
		{"text": "Quit to Menu", "cb": _on_return_home, "role": "danger"},
	])
	_panel.visible = true

func _show_pvp_final(coord) -> void:
	var placement: int = coord.placement_of(round_manager)
	var won := placement == 1
	_title_label.text = "Victory!" if won else "Match Over"
	_result_label.text = "1st · Last Standing" if won else "%s of %d" % [_ordinal(placement), coord.boards.size()]
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if won else Color.WHITE)
	_detail_label.text = "Kills: %d" % round_manager.total_kills
	_stars_row.visible = false
	_thresholds_vbox.visible = false
	_set_buttons([
		{"text": "Find New Match", "cb": _on_find_new_match, "role": "go"},
		{"text": "Return Home", "cb": _on_return_home},
	])
	_panel.visible = true

# Surface 2 (notes/leaderboard_ui_spec.md): the Ranked result screen — no stars/medals. Placement
# + the LP/MMR settle + ladder progress + the final order. Computes the LP result from this match
# (host-authoritative placement → LP engine), persists it, mirrors it to the season board, then renders.
func _show_pvp_ranked(coord) -> void:
	var placement: int = coord.placement_of(round_manager)
	var count: int = coord.boards.size()
	var result: Dictionary = RankedLadder.resolve(
		placement, count, SaveData.ranked_value(), SaveData.ranked_mmr(), SceneManager.pending_ranked_avg_mmr)
	# Persist locally + mirror the new authoritative ladder value to ranked_s<season>.
	SaveData.record_ranked_result(int(result["value_after"]), float(result["mmr_after"]))
	SceneManager.report_ranked_result(int(result["value_after"]))

	var won := placement == 1
	# Repurpose the shared labels: title = small season ctx, result = the big placement line.
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", UiStyle.LABEL_COL)
	_title_label.text = "Ranked · Season %d" % SaveData.ranked_season()
	_stars_row.visible = false
	_result_label.text = "You finished %s of %d" % [_ordinal(placement), count]
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if won else Color.WHITE)
	_detail_label.visible = false
	_thresholds_vbox.visible = false

	_populate_ranked(result, coord)
	_show_season_award()   # season-XP nudge if a task completed this Ranked match
	_set_buttons([
		{"text": "View season ladder", "cb": _on_view_season},
		{"text": "Queue again ›", "cb": _on_find_new_match, "role": "go"},
	])

	# Arm-before-reveal: the bar starts at the PRE-match LP and the order rows start hidden, so
	# the staged climb (bar fill → value/tier pop → order stagger) plays from the right frame.
	if _lp_bar != null and not bool(result["is_masters"]):
		_lp_bar.value = clampi(int(result["lp_before"]), 0, 100)
	for r in _ranked_rows:
		r.modulate.a = 0.0
	_scrim.visible = true
	_panel.visible = true
	_play_ranked_climb.call_deferred(result)

# Ranked Surface 2 staged climb (design/JUICE.md "Staged climbs"): the LP bar fills on the
# settle curve, the LP value pops on landing, a promotion is a staged set-piece (the bar tops
# out, the tier + note pop, then the bar resets and fills into the new tier), and the FINAL
# ORDER rows slide in staggered from the left. Reduced-motion still lands on the right values.
func _play_ranked_climb(result: Dictionary) -> void:
	if _victory != null and _victory.visible:
		return  # campaign victory owns the surface; never both
	# Final order rows slide in from the left, after the bar has had a moment to fill.
	for i in _ranked_rows.size():
		Motion.slide_in(_ranked_rows[i], Vector2(-18, 0), Motion.S, Motion.dur(0.55 + i * 0.06))
	if _lp_bar == null:
		return
	if bool(result["is_masters"]):
		if _lp_value_lbl != null:
			Motion.pop(_lp_value_lbl, 1.14, Motion.M)  # bar is static at 100; just pop the LP
		return
	var after := clampf(float(result["lp_after"]), 0.0, 100.0)
	var t := create_tween()
	if bool(result["promoted"]):
		# fill the old tier to the cap → PROMOTED beat (tier/note/value pop) → reset + fill new tier
		Motion.settle(t)
		t.tween_property(_lp_bar, "value", 100.0, Motion.dur(Motion.M))
		t.tween_callback(_ranked_tier_break)
		t.tween_interval(Motion.dur(0.12))
		Motion.settle(t)
		t.tween_property(_lp_bar, "value", after, Motion.dur(Motion.M))
	elif bool(result["demoted"]):
		# empty the old tier → drop into the top of the lower tier → settle at the new value
		Motion.settle(t)
		t.tween_property(_lp_bar, "value", 0.0, Motion.dur(Motion.M))
		t.tween_callback(_ranked_tier_break)
		t.tween_callback(func(): _lp_bar.value = 100.0)
		t.tween_interval(Motion.dur(0.12))
		Motion.settle(t)
		t.tween_property(_lp_bar, "value", after, Motion.dur(Motion.M))
	else:
		# same tier: a single fill on the settle curve, the value pops as it lands
		Motion.settle(t)
		t.tween_property(_lp_bar, "value", after, Motion.dur(Motion.L))
		t.tween_callback(func(): if _lp_value_lbl != null: Motion.pop(_lp_value_lbl, 1.14, Motion.S))

# The tier-crossing beat: pop the tier name, the promotion/demotion note, and the LP value.
func _ranked_tier_break() -> void:
	if _lp_tier_lbl != null:
		Motion.pop(_lp_tier_lbl, 1.18, Motion.M)
	if _promo_note != null:
		Motion.pop(_promo_note, 1.18, Motion.M)
	if _lp_value_lbl != null:
		Motion.pop(_lp_value_lbl, 1.14, Motion.S)

# The LP block (tier · lp arrow · +LP chip · progress bar · "to next") + FINAL ORDER rows.
func _populate_ranked(result: Dictionary, coord) -> void:
	for child in _lb_vbox.get_children():
		child.queue_free()
	_promo_note = null
	_ranked_rows = []

	# --- Tier + LP delta row. (No icon: Ranked has no medals, and the asset set has no trophy.)
	var lp_row := HBoxContainer.new()
	lp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lp_row.add_theme_constant_override("separation", 10)
	_lp_tier_lbl = _make_label(18, Color("e8c45a"))
	_lp_tier_lbl.text = String(result["tier_after"])
	lp_row.add_child(_lp_tier_lbl)
	_lp_value_lbl = _make_label(18, Color.WHITE)
	if bool(result["is_masters"]):
		_lp_value_lbl.text = "%d LP" % int(result["lp_after"])
	else:
		_lp_value_lbl.text = "%d → %d" % [int(result["lp_before"]), int(result["lp_after"])]
	lp_row.add_child(_lp_value_lbl)
	lp_row.add_child(_lp_chip(int(result["lp_delta"])))
	_lb_vbox.add_child(lp_row)

	# --- Promotion / demotion note (only when the band changed).
	if bool(result["promoted"]) or bool(result["demoted"]):
		_promo_note = _make_label(15, Color("bfe6a3") if bool(result["promoted"]) else Color(0.9, 0.55, 0.45))
		_promo_note.text = ("Promoted to %s!" if bool(result["promoted"]) else "Demoted to %s") % String(result["tier_after"])
		_promo_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lb_vbox.add_child(_promo_note)

	# --- Progress bar toward the next tier (full + uncapped caption for Masters). The bar FILLS
	# in the staged climb (armed at lp_before in _show_pvp_ranked); here it's set to the resting
	# end value so a non-animated path (or reduced-motion) still reads correct.
	_lp_bar = ProgressBar.new()
	_lp_bar.show_percentage = false
	_lp_bar.custom_minimum_size = Vector2(0, 12)
	_lp_bar.min_value = 0
	_lp_bar.max_value = 100
	_lp_bar.value = 100 if bool(result["is_masters"]) else clampi(int(result["lp_after"]), 0, 100)
	_lp_bar.add_theme_stylebox_override("background", UiStyle.flat_box(UiStyle.CHIP_BG, 7, UiStyle.CHIP_BORDER, 2, false))
	_lp_bar.add_theme_stylebox_override("fill", UiStyle.flat_box(UiStyle.START_BG, 7, UiStyle.START_BORDER, 0, false))
	_lb_vbox.add_child(_lp_bar)

	var to_next := _make_label(12, UiStyle.LABEL_COL)
	to_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	to_next.text = "Masters · uncapped" if bool(result["is_masters"]) else "%d LP to %s" % [int(result["to_next"]), String(result["next_tier"])]
	_lb_vbox.add_child(to_next)

	# --- FINAL ORDER (1..N), reusing the arena row style; your row highlighted, OUT for eliminated.
	var divider := _make_label(12, UiStyle.LABEL_COL)
	divider.text = "FINAL ORDER"
	divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_vbox.add_child(divider)
	var count: int = coord.boards.size()
	var by_place := {}
	for b in coord.boards:
		var pl: int = coord.placement_of(b)
		if pl > 0:
			by_place[pl] = b
	for p in range(1, count + 1):
		var b = by_place.get(p)
		if b == null:
			continue
		var is_me: bool = b == round_manager
		# Own row shows the actual MMR-adjusted LP earned; others show the public base LP for that place.
		var lp: int = int(result["earned"]) if is_me else RankedLadder.base_lp(p, count)
		var row := _ranked_row(p, coord.name_for(b), lp, is_me, bool(b.eliminated))
		_lb_vbox.add_child(row)
		_ranked_rows.append(row)
	_lb_vbox.visible = true

# The green "+30 LP" delta chip (red-tinted for a net loss).
func _lp_chip(delta: int) -> Control:
	var chip := PanelContainer.new()
	var gain := delta >= 0
	var bg := Color("3b5a2a") if gain else Color("5e2a1f")
	var border := UiStyle.START_BORDER if gain else UiStyle.SELL_BORDER
	chip.add_theme_stylebox_override("panel", UiStyle.flat_box(bg, 11, border, 2, false))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 9); m.add_theme_constant_override("margin_right", 9)
	m.add_theme_constant_override("margin_top", 3); m.add_theme_constant_override("margin_bottom", 3)
	chip.add_child(m)
	var l := _make_label(14, Color("dffacb") if gain else Color("f2c6bb"))
	l.text = "%+d LP" % delta
	m.add_child(l)
	return chip

# A final-order row: rank · name · signed LP (OUT prefix for an eliminated board). Your row green.
func _ranked_row(rank: int, name: String, lp: int, is_me: bool, is_out: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 34)
	var bg := Color("3b5a2a") if is_me else UiStyle.CHIP_BG
	var border := UiStyle.START_BORDER if is_me else UiStyle.CHIP_BORDER
	p.add_theme_stylebox_override("panel", UiStyle.flat_box(bg, 10, border, 2, false))
	p.modulate = Color(1, 1, 1, 0.6) if is_out and not is_me else Color(1, 1, 1, 1)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12); m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 3); m.add_theme_constant_override("margin_bottom", 3)
	p.add_child(m)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	m.add_child(hb)
	var rk := _make_label(14, Color("bfe6a3") if is_me else UiStyle.LABEL_COL)
	rk.text = "%d" % rank
	rk.custom_minimum_size = Vector2(34, 0)
	rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(rk)
	var nm := _make_label(14, Color("dffacb") if is_me else Color.WHITE)
	nm.text = name
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hb.add_child(nm)
	var val := _make_label(14, UiStyle.LABEL_COL)
	val.text = ("OUT · %+d" % lp) if is_out else ("%+d" % lp)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(val)
	return p

func _on_view_season() -> void:
	# Surface 3, Ranked category (the season tiered ladder).
	SceneManager.net_close()
	SceneManager.goto_leaderboards({"category": 1, "season": SaveData.ranked_season()})

func _show_medal() -> void:
	# Campaign → the break-the-grid victory composition (the mock); PVE Trials → the card +
	# placement block below. (lb_ctx is set for PVE only.)
	if lb_ctx.is_empty():
		_show_campaign_victory()
		return
	var damage: int = round_manager.total_damage_dealt
	var medal: String = round_manager.medal_for(damage)
	_title_label.text = "Match Complete"
	# Big earned-star tier above the caption.
	for child in _stars_row.get_children():
		child.queue_free()
	var stars = StarRatingScript.new()
	stars.configure(int(STAR_FOR_MEDAL[medal]), 3, 40.0)
	_stars_row.add_child(stars)
	_stars_row.visible = true
	_result_label.text = MEDAL_RESULT[medal]
	_result_label.add_theme_color_override("font_color", MEDAL_RESULT_COLOR[medal])
	_detail_label.text = "Total damage: %d  ·  Rounds: %d" % [damage, round_manager.max_rounds]
	_thresholds_vbox.visible = true
	_populate_thresholds(damage)
	# Persist the result (campaign medal / PVE score) BEFORE reading placement so the board
	# reflects this run's score.
	SceneManager.report_match_result(damage)
	# Trials (PVE) only: the leaderboard placement block + a "View full board" jump.
	var buttons := [
		{"text": "Play Again", "cb": _on_play_again, "role": "go"},
		{"text": "Return Home", "cb": _on_return_home},
	]
	if not lb_ctx.is_empty():
		_populate_placement(damage)
		buttons.push_front({"text": "View full board", "cb": _on_view_board})
	else:
		_lb_vbox.visible = false
	_show_season_award()   # season-XP nudge if a task completed this Trials match
	_set_buttons(buttons)
	_panel.visible = true

# Campaign victory composition (the mock). Stars from the medal, DAMAGE score, leave-only
# Next map / Trials / Ranked (resolves campaign follow-up #4: mission-end is leave-only).
func _show_campaign_victory() -> void:
	var damage: int = round_manager.total_damage_dealt
	var medal: String = round_manager.medal_for(damage)
	var stars: int = STAR_FOR_MEDAL[medal]
	SceneManager.report_match_result(damage)  # persist before anything reads the board

	_hero_big.text = "VICTORY" if stars >= 1 else "COMPLETE"
	var idx := 0
	var mname := ""
	if SceneManager.pending_map != null:
		idx = int(SceneManager.pending_map.mission_index)
		mname = String(SceneManager.pending_map.mission_name)
	_hero_sub.text = ("MISSION %d · %s" % [idx, mname.to_upper()]) if mname != "" else "MISSION %d" % idx

	for c in _tiles_row.get_children():
		c.queue_free()
	for i in range(3):
		_tiles_row.add_child(_star_tile(i < stars))

	_victory_damage = damage
	_vscore_val.text = _commas(damage)

	for c in _vbuttons.get_children():
		c.queue_free()
	var has_next := SceneManager.has_campaign_mission(idx + 1)
	_vbuttons.add_child(_vbutton("Next map" if has_next else "Campaign", _on_next_map, true))
	_vbuttons.add_child(_vbutton("Trials", _on_goto_trials, false))
	_vbuttons.add_child(_vbutton("Ranked", _on_goto_ranked, false))

	# Arm-before-reveal (JUICE): set every element's pre-entrance alpha to 0 BEFORE the surface
	# is shown, so the staged choreo never flashes its end frame. Position/scale are armed in the
	# deferred play step (they need the post-layout rect for pivots + slide targets).
	_scrim.visible = true  # self-sufficient (normally _on_match_ended already set it)
	_scrim.modulate.a = 0.0
	_hero.modulate.a = 0.0
	for s in _tiles_row.get_children():
		s.modulate.a = 0.0
	_score_block.modulate.a = 0.0
	for b in _vbuttons.get_children():
		b.modulate.a = 0.0

	_panel.visible = false
	_victory.visible = true
	_apply_hero_tilt.call_deferred()
	_play_victory_choreo.call_deferred()

# Staged victory choreography (design/JUICE.md + victory_screen_mock.html): dim → hero drops in
# (earns L) → stars cascade low→high, each earned tile pops on land → DAMAGE fades + ticks + pops
# → buttons settle in. Runs deferred so the composition has laid out (pivots + slide targets are
# real). The board behind stays static and dimmed — juice lives in the frame. All delays route
# through Motion.dur() so reduced-motion compresses the whole sequence from one place.
func _play_victory_choreo() -> void:
	if _victory == null or not _victory.visible:
		return
	# 1 — dim the board.
	Motion.fade_in(_scrim, Motion.M)
	# 2 — hero drops from above on the arrive curve (the one earned L). Tilt is already applied.
	Motion.slide_in(_hero, Vector2(0, -150.0), Motion.L, Motion.dur(0.18))
	# 3 — stars cascade low→high; each earned tile pops as it lands (set-piece stagger).
	var stars := _tiles_row.get_children()
	for i in stars.size():
		var s: Control = stars[i]
		s.pivot_offset = s.size * 0.5
		var d := Motion.dur(0.56 + i * Motion.STAGGER_SETPIECE)
		Motion.arrive_property(s, "scale", Vector2.ONE * 0.55, Vector2.ONE, Motion.M, d)
		Motion.fade_in(s, Motion.S, d)
		if bool(s.get_meta("earned", false)):
			_pop_after(s, d + Motion.dur(Motion.M) * 0.8)
	# 4 — DAMAGE block fades in, the number ticks up, then pops.
	Motion.fade_in(_score_block, Motion.M, Motion.dur(1.08))
	var st := create_tween()
	st.tween_interval(Motion.dur(1.08))
	st.tween_callback(_tick_score.bind(_victory_damage, Motion.dur(0.62)))
	# 5 — buttons settle in last, axis-aligned (precision targets stay square).
	var btns := _vbuttons.get_children()
	for i in btns.size():
		var b: Control = btns[i]
		b.pivot_offset = b.size * 0.5
		var d := Motion.dur(1.48 + i * 0.07)
		Motion.arrive_property(b, "scale", Vector2.ONE * 0.9, Vector2.ONE, Motion.S, d)
		Motion.fade_in(b, Motion.S, d)

# Count the DAMAGE value 0 → target on an ease-out curve, then emphasis-pop the final number.
func _tick_score(target: int, duration: float) -> void:
	if _vscore_val == null:
		return
	var t := create_tween()
	t.tween_method(
		func(p: float): _vscore_val.text = _commas(int(round((1.0 - pow(1.0 - p, 3.0)) * target))),
		0.0, 1.0, maxf(duration, 0.01))
	t.tween_callback(func():
		_vscore_val.text = _commas(target)
		Motion.pop(_vscore_val))

# Emphasis-pop a node after `delay` seconds (used for star tiles landing).
func _pop_after(node: CanvasItem, delay: float) -> void:
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(Motion.pop.bind(node))

# Tilt the hero around its centre once it has a real size (break-the-grid: ~3.5° on heroes).
func _apply_hero_tilt() -> void:
	if _hero == null:
		return
	_hero.pivot_offset = _hero.size * 0.5
	_hero.rotation_degrees = -3.5

func _vbutton(text: String, cb: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 48)
	b.add_theme_font_size_override("font_size", 16)
	if primary:
		UiStyle.style_go_button(b)
	else:
		UiStyle.style_menu_button(b)
	b.pressed.connect(cb)
	return b

func _on_next_map() -> void:
	var idx := int(SceneManager.pending_map.mission_index) if SceneManager.pending_map != null else 0
	if SceneManager.has_campaign_mission(idx + 1):
		SceneManager.start_campaign_mission(idx + 1)
	else:
		SceneManager.goto_campaign_select()

func _on_goto_trials() -> void:
	SceneManager.goto_pve_select()

func _on_goto_ranked() -> void:
	SceneManager.goto_lobby()

# --- Helpers ---

func _set_buttons(specs: Array) -> void:
	for child in _buttons_vbox.get_children():
		child.queue_free()
	for spec in specs:
		var b := Button.new()
		b.text = spec["text"]
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 16)
		match spec.get("role", "menu"):
			"go": UiStyle.style_go_button(b)
			"danger": UiStyle.style_danger_button(b)
			_: UiStyle.style_menu_button(b)
		b.pressed.connect(spec["cb"])
		_buttons_vbox.add_child(b)

# Season-XP nudge: a green chip with the total XP earned this match + the tasks that
# completed (Cadence: Shape ✓). Hidden when nothing crossed a threshold — the nudge is the
# celebratory "you finished a task" beat, not a per-match noise line. Reads SceneManager's
# cached record_match result.
func _show_season_award() -> void:
	for c in _season_vbox.get_children():
		c.queue_free()
	var award: Dictionary = SceneManager.last_task_award
	var pts := int(award.get("points", 0))
	if pts <= 0:
		_season_vbox.visible = false
		return
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiStyle.flat_box(Color("3b5a2a"), 12, UiStyle.START_BORDER, 2, false))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14); m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 8); m.add_theme_constant_override("margin_bottom", 8)
	chip.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	m.add_child(v)
	var head := _make_label(18, Color("dffacb"))
	head.text = "+%s season XP" % _commas(pts)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	for t in award.get("completed", []):
		var lbl := _make_label(13, UiStyle.LABEL_COL)
		lbl.text = "%s: %s ✓" % [TaskCatalogScript.CADENCE_LABEL[t["cadence"]], TaskCatalogScript.SHAPE_LABEL[t["shape"]]]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lbl)
	_season_vbox.add_child(chip)
	_season_vbox.visible = true

func _populate_thresholds(damage: int) -> void:
	for child in _thresholds_vbox.get_children():
		child.queue_free()
	# Ascending star tiers, each with its score-to-beat; a tick when reached, dim when not.
	_add_threshold_row(1, round_manager.bronze_threshold, damage)
	_add_threshold_row(2, round_manager.silver_threshold, damage)
	_add_threshold_row(3, round_manager.gold_threshold,   damage)

func _add_threshold_row(star_count: int, threshold: int, achieved: int) -> void:
	var reached: bool = achieved >= threshold
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var stars = StarRatingScript.new()
	stars.configure(star_count, 3, 16.0)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stars)

	var text := _make_label(16, Color.WHITE)
	text.text = "%d" % threshold
	row.add_child(text)

	var tick := UiStyle.icon_rect("tick", 16)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tick.visible = reached
	row.add_child(tick)

	row.modulate = Color(1, 1, 1, 1.0) if reached else Color(1, 1, 1, 0.45)
	_thresholds_vbox.add_child(row)

# Surface 1: board context · "You placed #N today" · your neighborhood (±2). Reads through
# LeaderboardService — offline you're #1 of your own board; Nakama fills the neighbors later.
func _populate_placement(damage: int) -> void:
	for child in _lb_vbox.get_children():
		child.queue_free()
	var window := int(lb_ctx.get("window", 0))
	var tier := int(lb_ctx.get("tier", 1))
	var group := String(lb_ctx.get("group", "solo"))
	var data: Dictionary = await LeaderboardService.trials_placement(window, tier, group, damage)

	var ctx := _make_label(13, UiStyle.LABEL_COL)
	ctx.text = String(data.get("context", ""))
	ctx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_vbox.add_child(ctx)

	var rank := int(data.get("rank", 0))
	var placed := _make_label(18, Color.WHITE)
	if rank > 0:
		placed.text = "You placed #%d %s" % [rank, data.get("window_word", "")]
	else:
		placed.text = "Score posted! Be the first on this board"
	placed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_vbox.add_child(placed)

	for e in data.get("rows", []):
		_lb_vbox.add_child(_placement_row(
			int(e.get("rank", 0)), String(e.get("name", "")), int(e.get("score", 0)), bool(e.get("is_me", false))))
	_lb_vbox.visible = true

func _placement_row(rank: int, name: String, score: int, is_me: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 34)
	var bg := Color("3b5a2a") if is_me else UiStyle.CHIP_BG
	var border := UiStyle.START_BORDER if is_me else UiStyle.CHIP_BORDER
	p.add_theme_stylebox_override("panel", UiStyle.flat_box(bg, 10, border, 2, false))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12); m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 3); m.add_theme_constant_override("margin_bottom", 3)
	p.add_child(m)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	m.add_child(hb)
	var rk := _make_label(14, Color("bfe6a3") if is_me else UiStyle.LABEL_COL)
	rk.text = "%d" % rank
	rk.custom_minimum_size = Vector2(34, 0)
	rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(rk)
	var nm := _make_label(14, Color("dffacb") if is_me else Color.WHITE)
	nm.text = name
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hb.add_child(nm)
	var sc := _make_label(14, Color("e8c45a"))
	sc.text = _commas(score)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(sc)
	return p

func _on_view_board() -> void:
	SceneManager.goto_leaderboards({
		"category": 0, "window": int(lb_ctx.get("window", 0)),
		"tier": int(lb_ctx.get("tier", 1)), "group": String(lb_ctx.get("group", "solo"))})

func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out

func _hide_panel() -> void:
	_panel.visible = false
	_victory.visible = false
	_scrim.visible = false

func _on_return_home() -> void:
	SceneManager.net_close()  # leave the server cleanly (no-op for solo/campaign)
	SceneManager.goto_home()

func _on_play_again() -> void:
	SceneManager.restart_current_match()

func _on_find_new_match() -> void:
	# Networked: re-queue in the lobby (the dedicated server resets after a match so the
	# same players can play again). Offline practice (no transport): a fresh local match.
	if SceneManager.transport != null:
		SceneManager.goto_lobby()
	else:
		SceneManager.start_pvp()

func _ordinal(n: int) -> String:
	if n <= 0:
		return "—"
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]

func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l
