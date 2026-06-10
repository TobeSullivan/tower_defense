extends Control

# Season — the free, earned-only reward track (design/SEASON.md, 30 tiers x 1,000 pts;
# layout from notes/mockups/season_mock.html). Header: season + time left + points.
# Progress strip: current tier, bar to the next, the next unclaimed reward. Track: one
# horizontal row of 30 tier cards — claimed (green check) / claimable (gold Claim) /
# current (YOU ARE HERE) / locked — with the milestone towers big at 10/20/30.
#
# No pricing anywhere: the absence of a buy button is what says "free" (SEASON.md — don't
# label it). XP comes from tasks (notes/task_system.md, runtime not built yet), so points
# only move when the task system lands; the claim flow is live now and grants into the
# Collection. Prestige never appears here (Ranked-exclusive).

const UiStyle := preload("res://scripts/ui_style.gd")
const Motion := preload("res://scripts/motion.gd")
const Catalog := preload("res://scripts/cosmetics_catalog.gd")

const TIER_W := 236.0

var _points_label: Label
var _tier_label: Label
var _bar: ProgressBar
var _to_next: Label
var _next_name: Label
var _next_art: PanelContainer
var _scroll: ScrollContainer
var _track: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.menu_backdrop(self)
	_build()
	_refresh()
	# Land the view on the action: scroll to the current tier after layout.
	_center_on_current.call_deferred()

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 70)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# --- Top bar: tilted gold season pill + meta (time left / points). ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	root.add_child(top)

	var ttl := PanelContainer.new()
	ttl.add_theme_stylebox_override("panel", UiStyle.pill_box(true))
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 22)
	tm.add_theme_constant_override("margin_right", 22)
	tm.add_theme_constant_override("margin_top", 6)
	tm.add_theme_constant_override("margin_bottom", 8)
	tm.add_child(_label("SEASON %d" % Catalog.SEASON, 30, Color.WHITE))
	ttl.add_child(tm)
	ttl.rotation_degrees = -2.0
	top.add_child(ttl)

	var collection_link := Button.new()
	collection_link.text = "Collection  →"
	collection_link.add_theme_font_size_override("font_size", 16)
	UiStyle.style_menu_button(collection_link)
	collection_link.pressed.connect(func(): SceneManager.goto_collection())
	collection_link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(collection_link)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)

	# Time left: the season clock is server-owned and not live pre-beta — honest dash.
	top.add_child(_meta_block("time left", "—"))
	var pts := _meta_block("season points", "0")
	_points_label = pts.get_child(1)
	_points_label.add_theme_color_override("font_color", UiStyle.PILL_GOLD)
	top.add_child(pts)

	# --- Progress strip. ---
	var prog := PanelContainer.new()
	UiStyle.apply_card(prog, 14)
	root.add_child(prog)
	var pmargin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		pmargin.add_theme_constant_override(side, 24)
	pmargin.add_theme_constant_override("margin_top", 12)
	pmargin.add_theme_constant_override("margin_bottom", 12)
	prog.add_child(pmargin)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 22)
	pmargin.add_child(prow)

	_tier_label = _label("Tier 1", 22, UiStyle.PILL_GOLD)
	prow.add_child(_tier_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.max_value = Catalog.POINTS_PER_TIER
	_bar.show_percentage = false
	prow.add_child(_bar)

	_to_next = _label("", 15, UiStyle.LABEL_COL)
	prow.add_child(_to_next)

	var nxt := HBoxContainer.new()
	nxt.add_theme_constant_override("separation", 12)
	prow.add_child(nxt)
	_next_art = PanelContainer.new()
	_next_art.custom_minimum_size = Vector2(56, 56)
	nxt.add_child(_next_art)
	var nv := VBoxContainer.new()
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nxt.add_child(nv)
	nv.add_child(_label("next reward", 12, UiStyle.LABEL_COL))
	_next_name = _label("", 15, Color.WHITE)
	nv.add_child(_next_name)

	# --- The track. ---
	var wrap := PanelContainer.new()
	UiStyle.apply_card(wrap)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(wrap)
	var wm := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		wm.add_theme_constant_override(side, 14)
	wm.add_theme_constant_override("margin_top", 18)
	wm.add_theme_constant_override("margin_bottom", 12)
	wrap.add_child(wm)
	_scroll = ScrollContainer.new()
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wm.add_child(_scroll)
	_track = HBoxContainer.new()
	_track.add_theme_constant_override("separation", 0)
	_track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The rail behind the tier circles: the HBox draws it on itself, so it sits behind
	# all the tier columns and scrolls with them.
	_track.draw.connect(_draw_rail)
	_scroll.add_child(_track)

	var back := Button.new()
	back.text = "Back"
	back.add_theme_font_size_override("font_size", 16)
	UiStyle.style_menu_button(back)
	back.pressed.connect(func(): SceneManager.goto_home())
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back.offset_left = -140
	back.offset_top = -56
	back.offset_right = -20
	back.offset_bottom = -16
	add_child(back)

func _meta_block(lab: String, val: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.add_child(_label(lab, 13, UiStyle.LABEL_COL))
	v.add_child(_label(val, 21, Color.WHITE))
	return v

# --- Refresh / state -----------------------------------------------------------

func _refresh() -> void:
	var points: int = SaveData.season_points()
	var claimed: Array = SaveData.claimed_season_tiers()
	var unlocked := Catalog.unlocked_tier(points)

	_points_label.text = _fmt(points)
	var display_tier := mini(unlocked + 1, Catalog.TIER_COUNT)
	_tier_label.text = "Tier %d" % display_tier
	var into := points % Catalog.POINTS_PER_TIER if unlocked < Catalog.TIER_COUNT else Catalog.POINTS_PER_TIER
	_bar.value = into
	if unlocked >= Catalog.TIER_COUNT:
		_to_next.text = "track complete"
	else:
		_to_next.text = "%s / %s to Tier %d" % [_fmt(into), _fmt(Catalog.POINTS_PER_TIER), display_tier]

	var next_tier := Catalog.next_reward_tier(points, claimed)
	for c in _next_art.get_children():
		c.queue_free()
	if next_tier > 0:
		var first := Catalog.item(Catalog.tier_items(next_tier)[0])
		_next_name.text = first["name"]
		_next_art.add_theme_stylebox_override("panel", UiStyle.flat_box(Color("222820"), 10, Color("161c0f"), 2, false))
		_next_art.add_child(_art_inner(first, true, 48))
	else:
		_next_name.text = "all claimed"

	for c in _track.get_children():
		c.queue_free()
	var cards: Array = []
	for t in Catalog.TRACK:
		var col := _tier_column(t, points, claimed)
		_track.add_child(col)
		cards.append(col)
	Motion.cascade(cards, func(c, _i, d): Motion.fade_in(c, Motion.S, d))
	_track.queue_redraw()

func _tier_column(t: Dictionary, points: int, claimed: Array) -> Control:
	var tier: int = t["tier"]
	var state := Catalog.tier_state(tier, points, claimed)
	var big: bool = tier in Catalog.MILESTONES
	var items: Array = t["items"]
	var first := Catalog.item(items[0])
	var owned_look := state == "claimed"

	# Tier circle.
	var num := PanelContainer.new()
	num.custom_minimum_size = Vector2(74, 74)
	num.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ncol := UiStyle.CHIP_BG
	var nborder := UiStyle.CHIP_BORDER
	var ntext := UiStyle.LABEL_COL
	match state:
		"claimed":
			ncol = UiStyle.START_BG
			nborder = UiStyle.START_BORDER
			ntext = Color("10240a")
		"claimable":
			ncol = UiStyle.PILL_GOLD
			nborder = UiStyle.PILL_GOLD_BORDER
			ntext = Color.WHITE
		"current":
			ncol = UiStyle.SELL_BG
			nborder = UiStyle.SELL_BORDER
			ntext = Color.WHITE
	var nsb := UiStyle.flat_box(ncol, 37, nborder, 3)
	num.add_theme_stylebox_override("panel", nsb)
	var nl := _label(str(tier), 24, ntext)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_child(nl)

	# Reward card.
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var border := UiStyle.PILL_BORDER
	var bg := UiStyle.PILL_BG
	if big:
		border = UiStyle.PILL_GOLD
		bg = Color("3a3a26")
	if state == "current":
		border = UiStyle.SELL_BG
	card.add_theme_stylebox_override("panel", UiStyle.flat_box(bg, 12, border, 2))
	if state == "locked":
		card.modulate = Color(1, 1, 1, 0.62)
	var cm := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		cm.add_theme_constant_override(side, 12)
	cm.add_theme_constant_override("margin_top", 12)
	cm.add_theme_constant_override("margin_bottom", 10)
	card.add_child(cm)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	cm.add_child(v)

	var art_box := PanelContainer.new()
	var art_px := 188 if big else 150
	art_box.custom_minimum_size = Vector2(art_px, art_px)
	art_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art_box.add_theme_stylebox_override("panel", UiStyle.flat_box(Color("222820"), 10, Color("161c0f"), 2, false))
	art_box.add_child(_art_inner(first, owned_look or state != "locked", art_px - 24))
	v.add_child(art_box)

	var nm_text: String = first["name"]
	if items.size() > 1:
		nm_text += "  + FX"
	var nm := _label(nm_text, 15, Color.WHITE if state != "locked" else UiStyle.LABEL_COL)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(0, 44)
	v.add_child(nm)

	var rar := _rarity_chip(first["rarity"])
	rar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(rar)

	var foot_sp := Control.new()
	foot_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(foot_sp)

	match state:
		"claimed":
			var f := _label("✓ Claimed", 14, UiStyle.START_BG)
			f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(f)
		"claimable":
			var btn := Button.new()
			btn.text = "Claim"
			btn.add_theme_font_size_override("font_size", 15)
			UiStyle.style_flat_button(btn, UiStyle.PILL_GOLD, 10, UiStyle.PILL_GOLD_BORDER, 2, true, 18, 5)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn.pressed.connect(func(): _claim(tier))
			v.add_child(btn)
		"current":
			var here := PanelContainer.new()
			here.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(UiStyle.SELL_BG, 0.16), 8, Color(0, 0, 0, 0), 0, false))
			var hm := MarginContainer.new()
			hm.add_theme_constant_override("margin_left", 10)
			hm.add_theme_constant_override("margin_right", 10)
			hm.add_child(_label("YOU ARE HERE", 12, UiStyle.SELL_BG))
			here.add_child(hm)
			here.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(here)
		_:
			var f := _label("Tier %d" % tier, 13, UiStyle.LABEL_COL)
			f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(f)

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		pad.add_theme_constant_override(side, 8)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(card)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(TIER_W, 0)
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_child(num)
	col.add_child(pad)
	return col

func _art_inner(it: Dictionary, revealed: bool, px: int) -> Control:
	var art := String(it.get("art", ""))
	if art != "" and ResourceLoader.exists(art):
		var tr := TextureRect.new()
		tr.texture = load(art)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not revealed:
			tr.modulate = Color(0, 0, 0, 0.5)
		return tr
	if it["slot"] == "title":
		var t := Label.new()
		t.text = "T"
		t.add_theme_font_size_override("font_size", maxi(22, px / 3))
		t.add_theme_color_override("font_color", UiStyle.PILL_GOLD)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return t
	if it.has("tint"):
		var tint: Color = it["tint"]
		var sw := Control.new()
		sw.draw.connect(func():
			var r: float = minf(sw.size.x, sw.size.y) * 0.30
			sw.draw_circle(sw.size * 0.5, r, tint if revealed else Color(tint, 0.3))
			sw.draw_arc(sw.size * 0.5, r, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 2.0, true))
		return sw
	var q := Label.new()
	q.text = "?"
	q.add_theme_font_size_override("font_size", 30)
	q.add_theme_color_override("font_color", UiStyle.LABEL_COL)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return q

func _rarity_chip(rarity: String) -> Control:
	var colors := {
		"common": [Color("444a38"), UiStyle.LABEL_COL],
		"rare": [Color("234a66"), Color("9fcdee")],
		"prestige": [UiStyle.PILL_GOLD_BORDER, Color("f0d68a")],
	}
	var pair: Array = colors.get(rarity, colors["common"])
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiStyle.flat_box(pair[0], 7, Color(0, 0, 0, 0), 0, false))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_child(_label(Catalog.RARITY_LABEL.get(rarity, rarity), 11, pair[1]))
	chip.add_child(m)
	return chip

# The rail behind the tier circles, gold-filled to the current position.
func _draw_rail() -> void:
	if _track.get_child_count() == 0:
		return
	var y := 37.0
	var x0 := TIER_W * 0.5
	var x1 := _track.size.x - TIER_W * 0.5
	_track.draw_line(Vector2(x0, y), Vector2(x1, y), UiStyle.CHIP_BORDER, 10.0)
	var unlocked := Catalog.unlocked_tier(SaveData.season_points())
	if unlocked > 0:
		var fx: float = TIER_W * (minf(unlocked, Catalog.TIER_COUNT - 1) + 0.5)
		_track.draw_line(Vector2(x0, y), Vector2(minf(fx, x1), y), UiStyle.PILL_GOLD, 10.0)

func _claim(tier: int) -> void:
	for id in Catalog.tier_items(tier):
		SaveData.grant_cosmetic(id)
	SaveData.claim_season_tier(tier)
	_refresh()
	_center_on_current.call_deferred()

func _center_on_current() -> void:
	var unlocked := Catalog.unlocked_tier(SaveData.season_points())
	var target := clampf(TIER_W * float(unlocked) - _scroll.size.x * 0.5 + TIER_W * 0.5, 0.0, 1e9)
	_scroll.scroll_horizontal = int(target)

func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	return l
