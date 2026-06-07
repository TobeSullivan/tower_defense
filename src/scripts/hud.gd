extends CanvasLayer
class_name HUD

# Floating HUD pills (mockup maze_battle_td_mockup.html), overlaid on the full-bleed
# battlefield — they reserve no space. Top-left: Round + phase/timer pills. Top-right:
# gold, kills, score (+ next medal) pills; lives pill in PVP. Untyped refs avoid the
# class-name cycle pitfall.

const UiLayout := preload("res://scripts/ui_layout.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const GhostLadderScript := preload("res://scripts/ghost_ladder.gd")
const TOWER_ICON := preload("res://assets/towers/arrow_box_loaded.png")

var round_manager  # RoundManager
var build_controller  # BuildController
# Trials only: the in-match ghost ladder (notes/ghost_ladder.md). Set by map_loader BEFORE
# add_child so _ready can build the caption. Null in campaign (keeps the medal-only target)
# and PVP (the SCORE pill is hidden there).
var ghost_ladder  # GhostLadder — untyped to avoid the class-name cycle

var _round_val: Label
var _phase_val: Label
var _gold_val: Label
var _kills_val: Label
var _score_val: Label
var _score_medal_lab: Label
var _medal_icon: TextureRect
var _score_pill: Control
var _lives_pill: Control
var _lives_val: Label
var _supply_val: Label
var _ladder_caption: Label  # "standings as of match start" — ghost-ladder honesty contract

var _towers_count: int = 0
var _towers_cap: int = 0

func _ready() -> void:
	layer = 6
	var s := UiLayout.scale_factor()

	# --- Top-left cluster: Round + phase ---
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", int(10 * s))
	left.position = Vector2(16, 16) * s
	add_child(left)
	var round_pill := _pill(false)
	_label(round_pill, "ROUND", true)
	_round_val = _label(round_pill, "—", false)
	left.add_child(round_pill["root"])
	var phase_pill := _pill(true)
	_icon(phase_pill, "timer", Color("2a2008"))
	_phase_val = _label(phase_pill, "—", false, Color("2a2008"))
	left.add_child(phase_pill["root"])
	var supply_pill := _pill(false)
	_tex_icon(supply_pill, TOWER_ICON, int(26 * s))
	_supply_val = _label(supply_pill, "0 / 0", false)
	left.add_child(supply_pill["root"])

	# --- Top-right cluster: gold / kills / score (+ lives in PVP) ---
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", int(10 * s))
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_top = 16 * s
	right.offset_right = -16 * s
	add_child(right)

	var lives_pill := _pill(false)
	_icon(lives_pill, "heart")
	_lives_val = _label(lives_pill, "0", false)
	_lives_pill = lives_pill["root"]
	_lives_pill.visible = false
	right.add_child(_lives_pill)

	var gold_pill := _pill(false)
	_icon(gold_pill, "coin")
	_gold_val = _label(gold_pill, "0", false, Color("ffe98c"))
	right.add_child(gold_pill["root"])

	var kills_pill := _pill(false)
	_label(kills_pill, "KILLS", true)
	_kills_val = _label(kills_pill, "0", false)
	right.add_child(kills_pill["root"])

	var score_pill := _pill(false)
	_medal_icon = _icon(score_pill, "medal_bronze")
	_label(score_pill, "SCORE", true)
	_score_val = _label(score_pill, "0", false)
	_score_medal_lab = _label(score_pill, "", true, Color("e0a55a"))
	_score_pill = score_pill["root"]
	# PVP is judged by placement/lives, not a score number — drop the SCORE pill there.
	_score_pill.visible = not _is_pvp()
	right.add_child(_score_pill)

	# Ghost-ladder honesty contract: a persistent caption stating the targets are a
	# match-start snapshot, never a live rank (notes/ghost_ladder.md). Trials only.
	if ghost_ladder != null and not _is_pvp():
		_ladder_caption = Label.new()
		_ladder_caption.text = "standings as of match start"
		_ladder_caption.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_ladder_caption.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_ladder_caption.offset_top = 62 * s
		_ladder_caption.offset_right = -16 * s
		_ladder_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_ladder_caption.add_theme_font_size_override("font_size", int(11 * s))
		_ladder_caption.add_theme_color_override("font_color", UiStyle.LABEL_COL)
		add_child(_ladder_caption)

	if round_manager != null:
		round_manager.gold_changed.connect(func(_g): _refresh())
		round_manager.round_changed.connect(func(_r): _refresh())
		round_manager.phase_changed.connect(func(_p): _refresh())
		round_manager.build_timer_changed.connect(func(_t): _refresh())
		round_manager.damage_dealt_changed.connect(func(_d): _refresh())
		round_manager.kills_changed.connect(func(_k): _refresh())
	if build_controller != null:
		build_controller.towers_changed.connect(_on_towers_changed)
		_towers_count = build_controller.towers.size()
		_towers_cap = build_controller.max_towers
	_refresh()

# Build a pill: PanelContainer ("root") → margin → HBox ("hb" for content).
func _pill(gold: bool) -> Dictionary:
	var s := UiLayout.scale_factor()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.pill_box(gold))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(15 * s))
	m.add_theme_constant_override("margin_right", int(15 * s))
	m.add_theme_constant_override("margin_top", int(8 * s))
	m.add_theme_constant_override("margin_bottom", int(8 * s))
	panel.add_child(m)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(9 * s))
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(hb)
	return {"root": panel, "hb": hb}

func _icon(pill: Dictionary, name: String, _modulate := Color.WHITE) -> TextureRect:
	var s := UiLayout.scale_factor()
	var tr := UiStyle.icon_rect(name, int(24 * s))
	if _modulate != Color.WHITE:
		tr.modulate = _modulate
	(pill["hb"] as HBoxContainer).add_child(tr)
	return tr

func _tex_icon(pill: Dictionary, tex: Texture2D, px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(pill["hb"] as HBoxContainer).add_child(tr)
	return tr

func _label(pill: Dictionary, text: String, is_lab: bool, col := Color.WHITE) -> Label:
	var s := UiLayout.scale_factor()
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_lab:
		l.add_theme_font_size_override("font_size", int(12 * s))
		l.add_theme_color_override("font_color", col if col != Color.WHITE else UiStyle.LABEL_COL)
	else:
		l.add_theme_font_size_override("font_size", int(23 * s))
		l.add_theme_color_override("font_color", col)
	(pill["hb"] as HBoxContainer).add_child(l)
	return l

func _on_towers_changed(count: int, cap: int) -> void:
	_towers_count = count
	_towers_cap = cap
	_refresh()

func _is_pvp() -> bool:
	return round_manager != null and round_manager.coordinator != null and round_manager.coordinator.is_pvp

# PVP lives to show: the LIVE projection during the run (moves as either you or an
# opponent racks up kills), the settled value otherwise. Clamped at 0 for display.
func _lives_display() -> int:
	var co = round_manager.coordinator
	if co != null and co.is_pvp:
		return maxi(0, co.projected_lives(round_manager))
	return round_manager.lives

# Local kills fire kills_changed, but an OPPONENT's kill also shifts my projection and
# emits no local signal — so poll the lives pill each frame during the PVP run.
func _process(_dt: float) -> void:
	if _is_pvp() and round_manager.phase == "run" and not round_manager.match_over:
		_lives_val.text = "%d" % _lives_display()

func _refresh() -> void:
	if round_manager == null:
		return
	if _is_pvp():
		_round_val.text = "%d" % round_manager.round_num
		_lives_pill.visible = true
		_lives_val.text = "%d" % _lives_display()
	else:
		_round_val.text = "%d / %d" % [round_manager.round_num, round_manager.max_rounds]
		_lives_pill.visible = false
	_gold_val.text = "%d" % round_manager.gold
	_kills_val.text = "%d" % round_manager.total_kills
	_supply_val.text = "%d / %d" % [_towers_count, _towers_cap]
	if round_manager.match_over:
		_phase_val.text = "ENDED"
	elif round_manager.phase == "build":
		_phase_val.text = "BUILD  %d:%02d" % [int(round_manager.build_time_left) / 60, int(round_manager.build_time_left) % 60]
	else:
		_phase_val.text = "RUN"
	_refresh_score()

func _refresh_score() -> void:
	var dmg: int = round_manager.total_damage_dealt
	_score_val.text = _commas(dmg)
	# Trials: the ghost ladder owns the target line (named tier → ghost → your best → TOP).
	if ghost_ladder != null:
		_refresh_ghost_target(dmg)
		return
	if round_manager.gold_threshold <= 0:
		_score_medal_lab.text = ""
		_medal_icon.visible = false
		return
	_medal_icon.visible = true
	var tier := "gold"
	var nextv := int(round_manager.gold_threshold)
	if dmg < int(round_manager.bronze_threshold):
		tier = "bronze"; nextv = int(round_manager.bronze_threshold)
	elif dmg < int(round_manager.silver_threshold):
		tier = "silver"; nextv = int(round_manager.silver_threshold)
	elif dmg < int(round_manager.gold_threshold):
		tier = "gold"; nextv = int(round_manager.gold_threshold)
	else:
		_score_medal_lab.text = "★ GOLD"
		_medal_icon.texture = UiStyle.icon_texture("medal_gold")
		return
	_medal_icon.texture = UiStyle.icon_texture("medal_%s" % tier)
	_score_medal_lab.text = "→%s %s" % [tier.capitalize(), _commas(nextv)]

# Drive the SCORE pill's target line from the ghost ladder. The medal icon shows only in
# the named-tier states (below gold); above gold the badge text carries the state. The line
# always points at something until TOP — and never asserts a live rank (notes/ghost_ladder.md).
func _refresh_ghost_target(dmg: int) -> void:
	var t: Dictionary = ghost_ladder.target_for(dmg)
	match int(t["state"]):
		GhostLadderScript.State.NAMED_TIER:
			_medal_icon.visible = true
			_medal_icon.texture = UiStyle.icon_texture("medal_%s" % String(t["label"]).to_lower())
			_score_medal_lab.text = "→%s %s" % [t["label"], _commas(int(t["target"]))]
		GhostLadderScript.State.GHOST:
			_medal_icon.visible = false
			_score_medal_lab.text = "GHOST  →%s  %s" % [t["name"], _commas(int(t["target"]))]
		GhostLadderScript.State.YOUR_BEST:
			_medal_icon.visible = false
			_score_medal_lab.text = "YOUR BEST  →%s" % _commas(int(t["target"]))
		_:  # TOP — ladder exhausted; show your score only + the tag (rank waits for results)
			_medal_icon.visible = false
			_score_medal_lab.text = "TOP"

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
