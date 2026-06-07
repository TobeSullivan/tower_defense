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

var round_manager  # RoundManager (local board) — untyped to avoid class-name cycle
# Trials (PVE) leaderboard context: {window:int, tier:int, group:String}. Set by map_loader
# for PVE only; empty for campaign/PVP (no Surface-1 placement block then).
var lb_ctx := {}

var _panel: PanelContainer
var _title_label: Label
var _result_label: Label
var _detail_label: Label
var _stars_row: HBoxContainer    # medal mode: the earned star tier
var _thresholds_vbox: VBoxContainer
var _lb_vbox: VBoxContainer       # Trials post-match placement block (Surface 1)
var _buttons_vbox: VBoxContainer

const STAR_FOR_MEDAL := {"gold": 3, "silver": 2, "bronze": 1, "none": 0}
const MEDAL_RESULT := {
	"gold": "Three stars!", "silver": "Two stars", "bronze": "One star", "none": "No stars — try again",
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

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	_buttons_vbox = VBoxContainer.new()
	_buttons_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_buttons_vbox)

# --- Mode entry points ---

func _on_match_ended() -> void:
	var coord = round_manager.coordinator
	if coord != null and coord.is_pvp:
		_show_pvp_final(coord)
	else:
		_show_medal()

func _on_board_eliminated(board) -> void:
	var coord = round_manager.coordinator
	# Only react to the LOCAL board's elimination, and not once the match is over
	# (the final panel takes precedence then).
	if board != round_manager or coord == null or coord.match_over:
		return
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
	_result_label.text = "1st — Last Standing" if won else "%s of %d" % [_ordinal(placement), coord.boards.size()]
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if won else Color.WHITE)
	_detail_label.text = "Kills: %d" % round_manager.total_kills
	_stars_row.visible = false
	_thresholds_vbox.visible = false
	_set_buttons([
		{"text": "Find New Match", "cb": _on_find_new_match, "role": "go"},
		{"text": "Return Home", "cb": _on_return_home},
	])
	_panel.visible = true

func _show_medal() -> void:
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
	_set_buttons(buttons)
	_panel.visible = true

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
	var data: Dictionary = LeaderboardService.trials_placement(window, tier, group, damage)

	var ctx := _make_label(13, UiStyle.LABEL_COL)
	ctx.text = String(data.get("context", ""))
	ctx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_vbox.add_child(ctx)

	var rank := int(data.get("rank", 0))
	var placed := _make_label(18, Color.WHITE)
	if rank > 0:
		placed.text = "You placed #%d %s" % [rank, data.get("window_word", "")]
	else:
		placed.text = "Score posted — be the first on this board"
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
