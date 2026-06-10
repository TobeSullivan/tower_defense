extends Control

# Collection — Locker + Codex merged into one home (design/COSMETICS.md "IA — two homes";
# layout from notes/mockups/collection_mock.html). LEFT: live loadout preview (a cropped
# window of a First Contact-style maze, towers firing on Run) + the profile card (name from
# the online identity — Steam later — plus earned flair). RIGHT: the slot rack with per-slot
# completion, then the active slot's full catalog — owned items equip (preview updates),
# earnable-locked show a silhouette + how-to-earn, art-not-imported shows a placeholder
# tagged "import pending". Overall completion top-right; Season is a CROSS-LINK, not a tab.
#
# Equip state is client render-layer only (COSMETICS cardinal rule 2) — this screen writes
# SaveData.equip_cosmetic and nothing else.

const UiStyle := preload("res://scripts/ui_style.gd")
const Motion := preload("res://scripts/motion.gd")
const Catalog := preload("res://scripts/cosmetics_catalog.gd")

var _active_slot := "tower"
var _equipped := {}          # slot -> item id (save merged over catalog defaults)

var _preview: PreviewBoard
var _profile_box: PanelContainer
var _slot_buttons := {}      # slot id -> Button
var _slot_counts := {}       # slot id -> the rack button's count Label
var _grid_title: Label
var _grid_count: Label
var _grid: GridContainer
var _overall_label: Label
var _overall_bar: ProgressBar
var _season_link: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.menu_backdrop(self)
	_load_equipped()
	_build()
	_refresh_all()
	# Entrance: top bar settles in, the preview board arrives, racks + catalog cascade.
	Motion.fade_in(_preview, Motion.M)
	Motion.fade_in(_profile_box, Motion.M, Motion.dur(0.10))
	var rack_btns: Array = _slot_buttons.values()
	Motion.cascade(rack_btns, func(b, _i, d): Motion.fade_in(b, Motion.S, d))

func _load_equipped() -> void:
	_equipped = Catalog.default_equipped()
	for s in Catalog.SLOTS:
		var explicit: String = SaveData.equipped_cosmetic(s["id"])
		if explicit != "":
			_equipped[s["id"]] = explicit

# --- Build ------------------------------------------------------------------

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 70)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	root.add_child(_build_topbar())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# LEFT: preview board + profile card.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 20)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.34
	body.add_child(left)

	_preview = PreviewBoard.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_preview)

	_profile_box = PanelContainer.new()
	_profile_box.custom_minimum_size = Vector2(0, 196)
	left.add_child(_profile_box)

	# RIGHT: slot racks + the active slot's catalog.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	right.add_child(_group_label("IN MATCH"))
	right.add_child(_build_rack("match"))
	right.add_child(_group_label("PROFILE FLAIR"))
	right.add_child(_build_rack("pro"))

	var panel := PanelContainer.new()
	UiStyle.apply_card(panel)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)

	var ghd := HBoxContainer.new()
	ghd.add_theme_constant_override("separation", 12)
	pv.add_child(ghd)
	_grid_title = _label("Tower", 24, Color.WHITE)
	ghd.add_child(_grid_title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ghd.add_child(sp)
	_grid_count = _label("", 16, UiStyle.LABEL_COL)
	ghd.add_child(_grid_count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	_build_back()

func _build_topbar() -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Gold tilted title pill (the screens' shared headline grammar).
	var ttl := PanelContainer.new()
	ttl.add_theme_stylebox_override("panel", UiStyle.pill_box(true))
	var tl := _label("COLLECTION", 30, Color.WHITE)
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 22)
	tm.add_theme_constant_override("margin_right", 22)
	tm.add_theme_constant_override("margin_top", 6)
	tm.add_theme_constant_override("margin_bottom", 8)
	tm.add_child(tl)
	ttl.add_child(tm)
	ttl.rotation_degrees = -2.0
	top.add_child(ttl)

	_season_link = Button.new()
	_season_link.add_theme_font_size_override("font_size", 16)
	UiStyle.style_menu_button(_season_link)
	_season_link.pressed.connect(func(): SceneManager.goto_season())
	_season_link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_season_link)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)

	var pct := HBoxContainer.new()
	pct.add_theme_constant_override("separation", 12)
	pct.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(pct)
	pct.add_child(_label("collection", 16, UiStyle.LABEL_COL))
	_overall_label = _label("0%", 16, UiStyle.PILL_GOLD)
	pct.add_child(_overall_label)
	_overall_bar = ProgressBar.new()
	_overall_bar.custom_minimum_size = Vector2(200, 10)
	_overall_bar.max_value = 100
	_overall_bar.show_percentage = false
	_overall_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pct.add_child(_overall_bar)
	return top

func _build_rack(group: String) -> Control:
	var rack := HBoxContainer.new()
	rack.add_theme_constant_override("separation", 8)
	for s in Catalog.SLOTS:
		if s["group"] != group:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 74)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var sid: String = s["id"]
		b.pressed.connect(func(): _select_slot(sid))
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := _label(s["name"], 13, UiStyle.LABEL_COL)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cc := _label("", 12, UiStyle.PILL_GOLD)
		cc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		v.add_child(cc)
		b.add_child(v)
		rack.add_child(b)
		_slot_buttons[sid] = b
		_slot_counts[sid] = cc
	return rack

func _build_back() -> void:
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

# --- Refresh ------------------------------------------------------------------

func _refresh_all() -> void:
	var owned: Array = SaveData.cosmetics_owned()
	var pct := int(round(Catalog.overall_completion(owned) * 100.0))
	_overall_label.text = "%d%%" % pct
	_overall_bar.value = pct
	var points: int = SaveData.season_points()
	_season_link.text = "Season %d · Tier %d  →" % [Catalog.SEASON, Catalog.unlocked_tier(points)]
	for sid in _slot_buttons:
		var b: Button = _slot_buttons[sid]
		var done: Vector2i = Catalog.slot_completion(sid, owned)
		(_slot_counts[sid] as Label).text = "%d/%d" % [done.x, done.y]
		if sid == _active_slot:
			UiStyle.style_flat_button(b, UiStyle.PILL_GOLD, 12, UiStyle.PILL_GOLD_BORDER, 2, true, 4, 4)
		else:
			UiStyle.style_flat_button(b, UiStyle.PILL_BG, 12, UiStyle.PILL_BORDER, 2, true, 4, 4)
	_rebuild_grid()
	_refresh_profile()
	_preview.refresh(_equipped)

func _select_slot(slot: String) -> void:
	if _active_slot == slot:
		return
	_active_slot = slot
	_refresh_all()

func _rebuild_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var owned: Array = SaveData.cosmetics_owned()
	var items: Array = Catalog.slot_items(_active_slot)
	_grid_title.text = Catalog.slot_name(_active_slot)
	var have: Vector2i = Catalog.slot_completion(_active_slot, owned)
	_grid_count.text = "%d of %d collected" % [have.x, have.y]
	var cards: Array = []
	for it in items:
		var card := _item_card(it, Catalog.is_owned(it["id"], owned))
		_grid.add_child(card)
		cards.append(card)
	Motion.cascade(cards, func(c, _i, d): Motion.fade_in(c, Motion.S, d))

func _item_card(it: Dictionary, owned: bool) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 168)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var equipped: bool = _equipped.get(it["slot"], "") == it["id"]
	if equipped:
		UiStyle.style_flat_button(card, UiStyle.PILL_BG, 12, UiStyle.START_BG, 2, true, 6, 6)
	else:
		UiStyle.style_flat_button(card, UiStyle.PILL_BG, 12, UiStyle.PILL_BORDER, 2, true, 6, 6)
	if owned:
		var iid: String = it["id"]
		card.pressed.connect(func(): _equip(iid))

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	v.add_child(_item_art(it, owned, 76))

	var nm := _label(it["name"], 14, Color.WHITE if owned else UiStyle.LABEL_COL)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)

	var rar := _rarity_chip(it["rarity"])
	rar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(rar)

	if not owned:
		var hint := _label(String(it.get("hint", "")), 11, UiStyle.LABEL_COL)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hint)
	elif equipped:
		var tick := _label("✓", 16, UiStyle.START_BG)
		tick.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		tick.offset_left = -26
		tick.offset_top = 2
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tick)
	if owned and String(it.get("art", "")) == "" and not it.has("tint"):
		var imp := _label("import pending", 10, Color("d9b46a"))
		imp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		imp.offset_top = -20
		imp.offset_left = 8
		imp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(imp)
	return card

# The item's art box: texture when imported, tint swatch for recolor/shape items, a gold
# "T" for titles, a "?" placeholder otherwise. Locked + texture = black silhouette (codex
# behavior, COSMETICS.md).
func _item_art(it: Dictionary, owned: bool, px: int) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(px, px)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_stylebox_override("panel", UiStyle.flat_box(Color("222820"), 10, Color("161c0f"), 2, false))
	var art := String(it.get("art", ""))
	if art != "" and ResourceLoader.exists(art):
		var tr := TextureRect.new()
		tr.texture = load(art)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not owned:
			tr.modulate = Color(0, 0, 0, 0.55)  # black silhouette
		box.add_child(tr)
	elif it["slot"] == "title":
		var t := _label("T", 30, UiStyle.PILL_GOLD)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if not owned:
			t.modulate = Color(1, 1, 1, 0.45)
		box.add_child(t)
	elif it.has("tint"):
		var sw := Control.new()
		var tint: Color = it["tint"]
		sw.draw.connect(func():
			var r: float = minf(sw.size.x, sw.size.y) * 0.30
			var col := tint if owned else Color(tint, 0.30)
			sw.draw_circle(sw.size * 0.5, r, col)
			sw.draw_arc(sw.size * 0.5, r, 0.0, TAU, 32, Color(1, 1, 1, 0.55 if owned else 0.2), 2.0, true))
		box.add_child(sw)
	else:
		var q := _label("?", 26, UiStyle.LABEL_COL)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(q)
	return box

func _rarity_chip(rarity: String) -> Control:
	var colors := {
		"common": [Color("444a38"), UiStyle.LABEL_COL],
		"rare": [Color("234a66"), Color("9fcdee")],
		"prestige": [UiStyle.PILL_GOLD_BORDER, Color("f0d68a")],
	}
	var pair: Array = colors.get(rarity, colors["common"])
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiStyle.flat_box(pair[0], 7, Color(0, 0, 0, 0), 0, false))
	var l := _label(Catalog.RARITY_LABEL.get(rarity, rarity), 10, pair[1])
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 1)
	m.add_theme_constant_override("margin_bottom", 1)
	m.add_child(l)
	chip.add_child(m)
	return chip

func _equip(id: String) -> void:
	var it := Catalog.item(id)
	if it.is_empty():
		return
	SaveData.equip_cosmetic(it["slot"], id)
	_equipped[it["slot"]] = id
	_refresh_all()
	Motion.pop(_preview if it["slot"] != "frame" and it["slot"] != "banner" and it["slot"] != "title" else _profile_box)

# DEV ONLY (debug builds): F10 grants every catalog cosmetic so any item can be equipped
# and tested in-match. Compiled out of release/playtest builds via OS.is_debug_build().
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		for it in Catalog.ITEMS:
			SaveData.grant_cosmetic(it["id"])
		_refresh_all()
		Motion.pop(_overall_label)
		print("[DEV] F10 — unlocked all %d cosmetics" % Catalog.ITEMS.size())

# --- Profile card (identity is read-only from the platform; flair is the equip) ---

func _refresh_profile() -> void:
	for c in _profile_box.get_children():
		c.queue_free()
	var banner := Catalog.item(_equipped.get("banner", "banner_olive"))
	var bg: Color = banner.get("tint", UiStyle.PILL_BG)
	_profile_box.add_theme_stylebox_override("panel", UiStyle.flat_box(bg, 14, bg.darkened(0.55), 2))

	var pm := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		pm.add_theme_constant_override(side, 24)
	pm.add_theme_constant_override("margin_top", 16)
	pm.add_theme_constant_override("margin_bottom", 16)
	_profile_box.add_child(pm)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	pm.add_child(row)

	# Avatar block + equipped frame (border tint). Avatar art comes from Steam later —
	# initial-on-panel until then.
	var frame := Catalog.item(_equipped.get("frame", "frame_none"))
	var fcol: Color = frame.get("tint", UiStyle.CHIP_BORDER)
	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(104, 104)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av.add_theme_stylebox_override("panel", UiStyle.flat_box(Color("4a5a32"), 16, fcol, 4))
	var name_text := _player_name()
	var ini := _label(name_text.substr(0, 1).to_upper(), 38, Color("dfe6cf"))
	ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(ini)
	row.add_child(av)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	col.add_child(_label(name_text, 26, Color.WHITE))
	var title_id: String = _equipped.get("title", "")
	if title_id != "":
		var t := Catalog.item(title_id)
		if not t.is_empty():
			var chip := PanelContainer.new()
			chip.add_theme_stylebox_override("panel", UiStyle.flat_box(UiStyle.DOCK_BG, 10, UiStyle.DOCK_BORDER, 2))
			var cm := MarginContainer.new()
			cm.add_theme_constant_override("margin_left", 12)
			cm.add_theme_constant_override("margin_right", 12)
			cm.add_theme_constant_override("margin_top", 3)
			cm.add_theme_constant_override("margin_bottom", 3)
			cm.add_child(_label(t["name"], 15, UiStyle.PILL_GOLD))
			chip.add_child(cm)
			chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			col.add_child(chip)

	var src := _label("name + pic from Steam", 11, UiStyle.LABEL_COL)
	src.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	src.offset_left = -190
	src.offset_top = 8
	src.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile_box.add_child(src)

func _player_name() -> String:
	# Online identity when a session exists (device-auth now, Steam persona later).
	var svc = get_node_or_null("/root/NakamaService")
	if svc != null and svc.get("session") != null:
		var u = svc.session.get("username")
		if u != null and String(u) != "":
			return String(u)
	return "Player"

func _group_label(text: String) -> Label:
	var l := _label(text, 12, UiStyle.LABEL_COL)
	return l

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	return l


# ============================================================================
# PreviewBoard — the live loadout preview: a cropped window (12x7 cells) of a
# First Contact-style 25x16 maze, rendered entirely in _draw from the EQUIPPED
# loadout. Run walks the horde and lets the towers fire (visual only — no sim,
# no scoring; this never touches match code). Geometry mirrors the mock.
# ============================================================================
class PreviewBoard extends Control:
	# Inner classes don't see the outer script's preload consts — re-declare them.
	const UiStyle := preload("res://scripts/ui_style.gd")
	const Catalog := preload("res://scripts/cosmetics_catalog.gd")

	const GRID := Vector2i(25, 16)
	const ENTRY := Vector2i(0, 8)
	const EXIT := Vector2i(24, 8)
	const CP := Vector2i(12, 8)
	const TOWERS := [Vector2i(12, 7), Vector2i(13, 7), Vector2i(9, 8), Vector2i(11, 8),
		Vector2i(14, 8), Vector2i(9, 9), Vector2i(12, 9), Vector2i(14, 9), Vector2i(10, 10), Vector2i(14, 10)]
	const TLVL := [1, 2, 3, 2, 1, 3, 2, 1, 2, 3]
	const OBST := [Vector2i(11, 5), Vector2i(10, 6), Vector2i(9, 7), Vector2i(11, 11), Vector2i(12, 11), Vector2i(13, 11)]
	const WIN := Rect2i(7, 5, 12, 7)  # the cropped cell window (x0, y0, cols, rows)
	const MOB_COUNT := 5
	# Path-dirt tone per biome id (the path readability contrast — COSMETICS hard filter).
	const PATH_DIRT := {"board_summer": Color("cdb98a"), "board_forest": Color("b59560"),
		"board_beach": Color("e8d9a8"), "board_suburbia": Color("8a8f96")}

	var _path: Array = []        # Vector2 cell centres, entry -> CP -> exit
	var _running := false
	var _mob_t: Array = []       # per-mob path parameter
	var _cooldown: Array = []    # per-tower frames to next shot
	var _shots: Array = []       # {from: Vector2(px), to: Vector2(px), t: float}
	var _bursts: Array = []      # {pos: Vector2(px), life: float}
	var _board_tex: Texture2D
	var _tower_tex: Texture2D
	var _mob_tex: Texture2D
	var _proj_tint := Color("caa54a")
	var _zone_tint := Color("7a5a8a")
	var _equipped_board_id := "board_summer"
	var _run_btn: Button

	func _init() -> void:
		clip_contents = true
		_compute_path()
		for i in MOB_COUNT:
			_mob_t.append((_path.size() - 1) * (0.18 + 0.62 * i / float(MOB_COUNT - 1)))
		for i in TOWERS.size():
			_cooldown.append(randf() * 40.0)

	func _ready() -> void:
		var lbl := Label.new()
		lbl.text = "FIRST CONTACT · loadout preview"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", UiStyle.LABEL_COL)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiStyle.flat_box(UiStyle.DOCK_BG, 10, UiStyle.DOCK_BORDER, 2))
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 10)
		m.add_theme_constant_override("margin_right", 10)
		m.add_theme_constant_override("margin_top", 3)
		m.add_theme_constant_override("margin_bottom", 3)
		m.add_child(lbl)
		chip.add_child(m)
		chip.position = Vector2(12, 12)
		chip.rotation_degrees = -2.0
		add_child(chip)

		_run_btn = Button.new()
		_run_btn.text = "▶ Run"
		_run_btn.add_theme_font_size_override("font_size", 14)
		UiStyle.style_go_button(_run_btn)
		_run_btn.pressed.connect(_toggle_run)
		_run_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_run_btn.offset_left = -110
		_run_btn.offset_top = 12
		_run_btn.offset_right = -12
		_run_btn.offset_bottom = 50
		add_child(_run_btn)

	func _toggle_run() -> void:
		_running = not _running
		_run_btn.text = "■ Stop" if _running else "▶ Run"
		if _running:
			UiStyle.style_danger_button(_run_btn)
		else:
			UiStyle.style_go_button(_run_btn)
		set_process(_running)
		if not _running:
			_shots.clear()
			_bursts.clear()
			queue_redraw()

	# Pull the equipped loadout's textures/tints. Items without imported art fall back to
	# the slot default's art (never a runtime tint of a painted sprite — COSMETICS rule).
	func refresh(equipped: Dictionary) -> void:
		_equipped_board_id = String(equipped.get("board", "board_summer"))
		_board_tex = _tex_or(equipped.get("board", ""), "res://assets/maps/summer_grass_tile.png")
		_tower_tex = _tex_or(equipped.get("tower", ""), "res://assets/towers/arrow_box_loaded.png")
		_mob_tex = _tex_or(equipped.get("mob", ""), "res://assets/mobs/__zombie_01_walk_2_000.png")
		var pr := Catalog.item(String(equipped.get("proj", "")))
		_proj_tint = pr.get("tint", Color("caa54a"))
		var zn := Catalog.item(String(equipped.get("zone", "")))
		_zone_tint = zn.get("tint", Color("7a5a8a"))
		queue_redraw()

	func _tex_or(item_id: String, fallback: String) -> Texture2D:
		return Catalog.texture_for(String(item_id), fallback)  # shared resolver (also used in-match)

	func _compute_path() -> void:
		var blocked := {}
		for c in TOWERS:
			blocked[c] = true
		for c in OBST:
			blocked[c] = true
		var p1 := _bfs(ENTRY, CP, blocked)
		var p2 := _bfs(CP, EXIT, blocked)
		_path = p1
		for i in range(1, p2.size()):
			_path.append(p2[i])

	func _bfs(a: Vector2i, b: Vector2i, blocked: Dictionary) -> Array:
		var q: Array = [a]
		var prev := {}
		var seen := {a: true}
		while not q.is_empty():
			var c: Vector2i = q.pop_front()
			if c == b:
				break
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if n.x < 0 or n.y < 0 or n.x >= GRID.x or n.y >= GRID.y:
					continue
				if seen.has(n) or blocked.has(n):
					continue
				seen[n] = true
				prev[n] = c
				q.append(n)
		var out: Array = []
		var cur: Variant = b
		while cur != null:
			out.push_front(cur)
			cur = prev.get(cur)
		return out

	# Path parameter -> interpolated cell position.
	func _pt(t: float) -> Vector2:
		t = clampf(t, 0.0, float(_path.size() - 1))
		var i := int(t)
		var f := t - float(i)
		var a: Vector2i = _path[i]
		var b: Vector2i = _path[mini(_path.size() - 1, i + 1)]
		return Vector2(a).lerp(Vector2(b), f)

	# Cell -> pixel (centre) within the cropped window.
	func _px(cell: Vector2) -> Vector2:
		return Vector2(
			(cell.x - WIN.position.x + 0.5) / float(WIN.size.x) * size.x,
			(cell.y - WIN.position.y + 0.5) / float(WIN.size.y) * size.y)

	func _process(delta: float) -> void:
		var step := delta * 60.0
		for i in _mob_t.size():
			_mob_t[i] = fmod(_mob_t[i] + 0.045 * step, float(_path.size() - 1))
		for i in TOWERS.size():
			_cooldown[i] -= step
			if _cooldown[i] <= 0.0:
				var tp := _px(Vector2(TOWERS[i]))
				var rng: float = (2.4 + TLVL[i] * 0.7) / float(WIN.size.x) * size.x
				for t in _mob_t:
					var mp := _px(_pt(t))
					if tp.distance_to(mp) <= rng:
						_shots.append({"from": tp, "to": mp, "t": 0.0})
						_cooldown[i] = 34.0 - TLVL[i] * 5.0
						break
		var done_shots: Array = []
		for s in _shots:
			s["t"] += 0.14 * step
			if s["t"] >= 1.0:
				_bursts.append({"pos": s["to"], "life": 1.0})
				done_shots.append(s)
		for s in done_shots:
			_shots.erase(s)
		var done_bursts: Array = []
		for bu in _bursts:
			bu["life"] -= 0.07 * step
			if bu["life"] <= 0.0:
				done_bursts.append(bu)
		for bu in done_bursts:
			_bursts.erase(bu)
		queue_redraw()

	func _draw() -> void:
		var cell := Vector2(size.x / WIN.size.x, size.y / WIN.size.y)
		# Biome tiles across the window.
		if _board_tex != null:
			for gx in range(WIN.position.x, WIN.position.x + WIN.size.x):
				for gy in range(WIN.position.y, WIN.position.y + WIN.size.y):
					var org := _px(Vector2(gx, gy)) - cell * 0.5
					draw_texture_rect(_board_tex, Rect2(org, cell), false, Color(0.86, 0.92, 0.78))
		# Path dirt (the legibility contrast every biome must keep).
		var dirt: Color = PATH_DIRT.get(_dirt_key(), Color("cdb98a"))
		for c in _path:
			var cc: Vector2i = c
			if cc.x < WIN.position.x - 1 or cc.x > WIN.end.x or cc.y < WIN.position.y - 1 or cc.y > WIN.end.y:
				continue
			draw_rect(Rect2(_px(Vector2(cc)) - cell * 0.5, cell), dirt)
			draw_rect(Rect2(_px(Vector2(cc)) - cell * 0.5, cell), Color(0, 0, 0, 0.10), false, 1.0)
		# Obstacles.
		for o in OBST:
			var oo: Vector2i = o
			if not WIN.has_point(oo):
				continue
			draw_rect(Rect2(_px(Vector2(oo)) - cell * 0.38, cell * 0.76), Color("4a443a"))
		# Bonus-zone ring on the checkpoint (carries the equipped zone tint; label stays).
		draw_circle(_px(Vector2(CP)), cell.x * 0.62, Color(_zone_tint, 0.30))
		draw_arc(_px(Vector2(CP)), cell.x * 0.62, 0.0, TAU, 40, Color(_zone_tint, 0.9), 2.0, true)
		# Towers: aura ring (the growth signal lives OFF the body) + body + level badge.
		var font := get_theme_default_font()
		for i in TOWERS.size():
			var tp := _px(Vector2(TOWERS[i]))
			var aura: float = cell.x * (0.7 + TLVL[i] * 0.31)
			draw_circle(tp, aura, Color(1.0, 0.91, 0.66, 0.10))
			draw_arc(tp, aura, 0.0, TAU, 40, Color(1.0, 0.91, 0.66, 0.42), 2.0, true)
			if _tower_tex != null:
				var w: float = cell.x * (0.74 + TLVL[i] * 0.07)
				var h: float = w * _tower_tex.get_height() / float(_tower_tex.get_width())
				draw_texture_rect(_tower_tex, Rect2(tp - Vector2(w, h) * 0.5, Vector2(w, h)), false)
			var badge_pos := tp + Vector2(cell.x * 0.28, -cell.y * 0.34)
			draw_rect(Rect2(badge_pos, Vector2(26, 16)), UiStyle.PILL_GOLD)
			draw_string(font, badge_pos + Vector2(4, 12), "L%d" % TLVL[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		# Horde.
		if _mob_tex != null:
			for t in _mob_t:
				var mp := _px(_pt(t))
				var nx := _px(_pt(t + 0.1))
				var ang := (nx - mp).angle() + PI * 0.5
				var mw := cell.x * 0.6
				var mh := mw * _mob_tex.get_height() / float(_mob_tex.get_width())
				draw_set_transform(mp, ang, Vector2.ONE)
				draw_texture_rect(_mob_tex, Rect2(-Vector2(mw, mh) * 0.5, Vector2(mw, mh)), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Shots + impact bursts (equipped projectile tint; stock silhouette + duration).
		for s in _shots:
			var p: Vector2 = s["from"].lerp(s["to"], s["t"])
			draw_circle(p, cell.x * 0.10, _proj_tint)
		for bu in _bursts:
			var r: float = cell.x * 0.35 * (1.6 - bu["life"] * 0.6)
			draw_circle(bu["pos"], r, Color(_proj_tint, bu["life"] * 0.5))
		# Panel edge.
		draw_rect(Rect2(Vector2.ZERO, size), Color("1a2012"), false, 3.0)

	func _dirt_key() -> String:
		# Equipped board id drives the dirt tone; default summer.
		return _equipped_board_id if _equipped_board_id != "" else "board_summer"
