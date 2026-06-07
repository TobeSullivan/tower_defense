extends Control

# Board-browse — the leaderboard hub (notes/leaderboard_ui_spec.md Surface 3; layout from
# notes/mockups/leaderboard_ui_pass2.html §B/B2 + ranked_ladder_bands.html). One screen, a
# category segmented control (Trials / Ranked / Campaign), each with its own selectors:
#   Trials   — window tabs + reset countdown, group seg, scale pills, then ranked rows.
#   Ranked   — season seg, your-standing header, one continuous tiered-band ladder.
#   Campaign — per-mission all-time boards.
# All rows come from LeaderboardService; offline the LocalBackend yields just your own
# entries, so the screen renders clean empty states until Nakama lands.
#
# Open context (which category/window/scale to land on) is passed via
# SceneManager.pending_leaderboard — e.g. a select card or "View full board" deep-links here.

const UiStyle := preload("res://scripts/ui_style.gd")
const LeaderboardService := preload("res://scripts/leaderboard_service.gd")
const MapResourceScript := preload("res://resources/map_resource.gd")

enum Cat { TRIALS, RANKED, CAMPAIGN }

var _cat: int = Cat.TRIALS
var _window: int = MapResourceScript.WindowType.DAILY
var _group: String = "solo"
var _tier: int = 3
var _season: int = 1
var _mission: int = 1

var _cat_buttons: Dictionary = {}
var _selectors: VBoxContainer   # per-category selector rows (rebuilt on category switch)
var _list_box: VBoxContainer    # the rows area (rebuilt on any selection change)
var _countdown: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.menu_backdrop(self)
	_apply_open_context()
	_build_topbar()
	_build_body()
	_rebuild_selectors()
	_rebuild_list()

# Deep-link target set by the caller (SceneManager.pending_leaderboard), consumed once.
func _apply_open_context() -> void:
	var ctx = SceneManager.pending_leaderboard if SceneManager.get("pending_leaderboard") != null else {}
	if typeof(ctx) != TYPE_DICTIONARY or ctx.is_empty():
		return
	_cat = int(ctx.get("category", _cat))
	_window = int(ctx.get("window", _window))
	_group = String(ctx.get("group", _group))
	_tier = int(ctx.get("tier", _tier))
	SceneManager.pending_leaderboard = {}

# --- Top bar: back · title · category segmented ---

func _build_topbar() -> void:
	var back := Button.new()
	back.text = "← Back"
	back.add_theme_font_size_override("font_size", 16)
	UiStyle.style_menu_button(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 28
	back.offset_top = 24
	back.offset_right = 148
	back.offset_bottom = 64
	back.pressed.connect(func(): SceneManager.goto_home())
	add_child(back)

	var title := _label("Leaderboards", 30, Color.WHITE)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	title.offset_left = 168
	title.offset_top = 24
	add_child(title)

	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 8)
	seg.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	seg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	seg.offset_top = 24
	seg.offset_right = -28
	add_child(seg)
	for c in [Cat.TRIALS, Cat.RANKED, Cat.CAMPAIGN]:
		var b := _tab(["Trials", "Ranked", "Campaign"][c], func(): _set_category(c))
		seg.add_child(b)
		_cat_buttons[c] = b

func _build_body() -> void:
	_selectors = VBoxContainer.new()
	_selectors.add_theme_constant_override("separation", 10)
	_selectors.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_selectors.offset_left = 28
	_selectors.offset_right = -28
	_selectors.offset_top = 84
	add_child(_selectors)

	# Scrollable list below the selectors. ScrollContainer → a full-width HBox that centers
	# the fixed-width column (h-scroll disabled, so the HBox fills width and ALIGNMENT_CENTER
	# centres the list; vertical scroll kicks in when the board is long).
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 28
	scroll.offset_right = -28
	scroll.offset_top = 220
	scroll.offset_bottom = -28
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var wrap := HBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(wrap)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 5)
	_list_box.custom_minimum_size = Vector2(620, 0)
	_list_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrap.add_child(_list_box)

# --- Category / selection switching ---

func _set_category(c: int) -> void:
	_cat = c
	_rebuild_selectors()
	_rebuild_list()

func _rebuild_selectors() -> void:
	for b in _cat_buttons:
		_cat_buttons[b].button_pressed = (b == _cat)
	for child in _selectors.get_children():
		child.queue_free()
	match _cat:
		Cat.TRIALS: _build_trials_selectors()
		Cat.RANKED: _build_ranked_selectors()
		Cat.CAMPAIGN: _build_campaign_selectors()

func _build_trials_selectors() -> void:
	# Row 1: window tabs + reset countdown.
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	for wt in [MapResourceScript.WindowType.DAILY, MapResourceScript.WindowType.WEEKLY, MapResourceScript.WindowType.MONTHLY]:
		var b := _tab(["Daily", "Weekly", "Monthly"][wt], func(): _select(func(): _window = wt))
		b.button_pressed = (wt == _window)
		r1.add_child(b)
	_countdown = _label("⏳ " + LeaderboardService.window_reset_text(_window), 14, Color("cf9a2f"))
	_countdown.offset_left = 12
	var cd_wrap := MarginContainer.new()
	cd_wrap.add_theme_constant_override("margin_left", 14)
	cd_wrap.add_child(_countdown)
	r1.add_child(cd_wrap)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r1.add_child(sp)
	# group seg on the right
	for g in LeaderboardService.GROUPS:
		var gb := _tab(g.capitalize(), func(): _select(func(): _group = g))
		gb.button_pressed = (g == _group)
		r1.add_child(gb)
	_selectors.add_child(r1)

	# Row 2: scale pills.
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	for t in range(1, 6):
		var sb := _tab(LeaderboardService.scale_name(t), func(): _select(func(): _tier = t))
		sb.button_pressed = (t == _tier)
		r2.add_child(sb)
	_selectors.add_child(r2)

func _build_ranked_selectors() -> void:
	var data: Dictionary = await LeaderboardService.ranked_ladder(_season)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	var seasons: Array = data.get("seasons", ["Season 1"])
	for i in range(seasons.size()):
		var idx := i + 1
		var b := _tab(String(seasons[i]), func(): _select(func(): _season = idx))
		b.button_pressed = (idx == _season)
		r1.add_child(b)
	_selectors.add_child(r1)

func _build_campaign_selectors() -> void:
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	for m in range(1, SceneManager.CAMPAIGN_MISSION_COUNT + 1):
		var b := _tab("Mission %d" % m, func(): _select(func(): _mission = m))
		b.button_pressed = (m == _mission)
		r1.add_child(b)
	_selectors.add_child(r1)

# Apply a selection change then refresh selector toggles + the list.
func _select(setter: Callable) -> void:
	setter.call()
	_rebuild_selectors()
	_rebuild_list()

# --- List rendering ---

func _rebuild_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	match _cat:
		Cat.TRIALS: _render_trials()
		Cat.RANKED: _render_ranked()
		Cat.CAMPAIGN: _render_campaign()

func _render_trials() -> void:
	var data: Dictionary = await LeaderboardService.trials_board(_window, _tier, _group)
	var entries: Array = data.get("entries", [])
	if entries.is_empty():
		_list_box.add_child(_empty_state("No scores on this board yet.", "Be the first — post a run."))
		return
	_render_score_rows(entries)

func _render_ranked() -> void:
	var data: Dictionary = await LeaderboardService.ranked_ladder(_season)
	var you = data.get("you", null)
	if you != null:
		_list_box.add_child(_ranked_standing(you))
	var bands: Array = data.get("bands", [])
	if bands.is_empty():
		_list_box.add_child(_empty_state("No ranked standings yet.",
			"Play Ranked to claim a place on the season ladder."))
		return
	for band in bands:
		_list_box.add_child(_band_header(String(band.get("name", "")), String(band.get("tag", ""))))
		_render_ranked_rows(band.get("rows", []))

func _render_campaign() -> void:
	var data: Dictionary = await LeaderboardService.campaign_board(_mission)
	var entries: Array = data.get("entries", [])
	if entries.is_empty():
		_list_box.add_child(_empty_state("No times on this mission's board yet.",
			"Campaign boards are all-time — set the pace."))
		return
	_render_score_rows(entries)

# Score rows (Trials/Campaign): rank · name · score. Inserts a "jump to your position"
# divider wherever the rank sequence skips (top-N → neighborhood).
func _render_score_rows(entries: Array) -> void:
	var prev_rank := 0
	for e in entries:
		var rank := int(e.get("rank", 0))
		if prev_rank != 0 and rank > prev_rank + 1:
			_list_box.add_child(_divider("· · · jump to your position · · ·"))
		prev_rank = rank
		_list_box.add_child(_score_row(rank, String(e.get("name", "")), int(e.get("score", 0)), bool(e.get("is_me", false))))

func _render_ranked_rows(rows: Array) -> void:
	var prev_rank := 0
	for e in rows:
		var rank := int(e.get("rank", 0))
		if prev_rank != 0 and rank > prev_rank + 1:
			_list_box.add_child(_divider("· · · jump to your position · · ·"))
		prev_rank = rank
		_list_box.add_child(_ranked_row(rank, String(e.get("name", "")),
			String(e.get("tier", "")), int(e.get("lp", 0)), bool(e.get("is_me", false))))

# --- Row / chrome builders ---

func _score_row(rank: int, name: String, score: int, is_me: bool) -> Control:
	var row := _row_panel(is_me)
	var hb := _row_hbox(row)
	hb.add_child(_cell("%d" % rank, 44, _rank_col(is_me), HORIZONTAL_ALIGNMENT_RIGHT))
	var nm := _cell(name, 0, Color("dffacb") if is_me else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hb.add_child(nm)
	hb.add_child(_cell(_commas(score), 0, Color("e8c45a"), HORIZONTAL_ALIGNMENT_RIGHT))
	return row

func _ranked_row(rank: int, name: String, tier: String, lp: int, is_me: bool) -> Control:
	var row := _row_panel(is_me)
	var hb := _row_hbox(row)
	hb.add_child(_cell("%d" % rank, 44, _rank_col(is_me), HORIZONTAL_ALIGNMENT_RIGHT))
	var nm := _cell(name, 0, Color("dffacb") if is_me else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hb.add_child(nm)
	# Masters shows raw LP; lower bands show "<Tier> · <LP>".
	var lp_text := "%s LP" % _commas(lp) if tier == "Masters" else "%s · %d" % [tier, lp]
	hb.add_child(_cell(lp_text, 0, Color("e8c45a") if is_me else Color("cdd6bf"), HORIZONTAL_ALIGNMENT_RIGHT))
	return row

func _ranked_standing(you: Dictionary) -> Control:
	var panel := PanelContainer.new()
	UiStyle.apply_card(panel, 16)
	panel.custom_minimum_size = Vector2(620, 0)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16); m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 12); m.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(m)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	m.add_child(hb)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(who)
	who.add_child(_label("%s · %d LP" % [you.get("tier", ""), int(you.get("lp", 0))], 20, Color("e8c45a")))
	who.add_child(_label("#%d of %d" % [int(you.get("rank", 0)), int(you.get("total", 0))], 14, UiStyle.LABEL_COL))
	if you.has("to_next"):
		who.add_child(_label("%d LP to %s" % [int(you.get("to_next", 0)), you.get("next_tier", "")], 12, UiStyle.LABEL_COL))
	return panel

func _band_header(name: String, tag: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.custom_minimum_size = Vector2(0, 30)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiStyle.flat_box(_band_color(tag), 9, _band_color(tag).darkened(0.4), 2))
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 9); cm.add_theme_constant_override("margin_right", 9)
	cm.add_theme_constant_override("margin_top", 2); cm.add_theme_constant_override("margin_bottom", 2)
	chip.add_child(cm)
	cm.add_child(_label(name.to_upper(), 12, Color.WHITE))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(chip)
	var line := Control.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(line)
	return hb

func _divider(text: String) -> Control:
	var l := _label(text, 12, Color("6f7d5c"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, 24)
	return l

func _empty_state(title: String, sub: String) -> Control:
	var panel := PanelContainer.new()
	UiStyle.apply_card(panel, 16)
	panel.custom_minimum_size = Vector2(620, 0)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 22); m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 24); m.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)
	var t := _label(title, 18, Color.WHITE); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _label(sub, 14, UiStyle.LABEL_COL); s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	return panel

# --- Small shared widgets ---

func _row_panel(is_me: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(620, 40)
	var bg := Color("3b5a2a") if is_me else UiStyle.CHIP_BG
	var border := UiStyle.START_BORDER if is_me else UiStyle.CHIP_BORDER
	p.add_theme_stylebox_override("panel", UiStyle.flat_box(bg, 12, border, 2))
	return p

func _row_hbox(row: PanelContainer) -> HBoxContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12); m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 5); m.add_theme_constant_override("margin_bottom", 5)
	row.add_child(m)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	m.add_child(hb)
	return hb

func _cell(text: String, min_w: int, col: Color, align: int) -> Label:
	var l := _label(text, 15, col)
	if min_w > 0:
		l.custom_minimum_size = Vector2(min_w, 0)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _rank_col(is_me: bool) -> Color:
	return Color("bfe6a3") if is_me else UiStyle.LABEL_COL

func _band_color(tag: String) -> Color:
	match tag:
		"mas": return UiStyle.PILL_GOLD
		"plat": return Color("7d8a6a")
		"gold": return Color("9c7c2a")
		"sil": return Color("5d6a4f")
		_: return UiStyle.SELL_BG  # bronze ~ terracotta

func _tab(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	UiStyle.style_tab_button(b)
	b.pressed.connect(on_pressed)
	return b

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

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
