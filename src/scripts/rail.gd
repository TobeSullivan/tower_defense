extends CanvasLayer
class_name Rail

# The reserved right rail — the single home for all persistent in-match UI
# (design/INMATCH_HUD.md, reference mock notes/mockups/inmatch_assembly.html). Replaces the
# old floating-pills HUD + floating action strip: three stacked boxes, top to bottom —
#   1. STATUS  — Round / Phase·timer / Supply / Gold (identical in both modes)
#   2. SCORE-or-STANDING (fixed-height frame, content swaps by mode):
#        Trials  -> SCORE:    hero "Current" + up to 3 ascending rungs (the ghost ladder)
#        Ranked  -> STANDING: hero "Lives" + Kills / Rank / blank, FROZEN during the run
#   3. BUTTONS — Start·Speed·Build·Menu (Trials) / Ready·Leaderboard·Build·Menu (Ranked)
# The board maximizes into the area LEFT of the rail (UiLayout.play_rect). The tower info
# panel docks in the rail's lower gap beneath the Buttons box (tower_slot_rect) when it fits,
# else falls back to an over-board overlay. Untyped refs avoid the class-name cycle pitfall.

const UiLayout := preload("res://scripts/ui_layout.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const GhostLadderScript := preload("res://scripts/ghost_ladder.gd")
const Motion := preload("res://scripts/motion.gd")

const FF_MULTS := [1.0, 2.0, 3.0]
const GOLD_VAL := Color("e7d39a")
const SCORE_BOX_MIN_H := 166.0  # fixed frame so the Buttons box anchors at a stable Y
const TOWER_PANEL_MIN_H := 312.0  # tower info needs ~this much rail gap to dock in-rail

# Injected by map_loader before add_child.
var round_manager       # RoundManager (the local board)
var build_controller    # BuildController
var pause_menu          # PauseMenu — the Menu button drives it
var minimap             # LeaderboardPanel (PVP) — the Leaderboard button toggles it
var ghost_ladder        # GhostLadder — Trials target ladder (null in campaign/PVP)

# Status box values
var _round_val: Label
var _phase_val: Label
var _supply_val: Label
var _gold_val: Label

# Score box (Trials / campaign)
var _score_hero: Label
var _rungs: Array = []           # up to 3 {star, key, val} row dicts
# Source for the SCORE rungs: the injected ghost_ladder (Trials, with leaderboard ghosts),
# or a local ladder built from the map's star thresholds (campaign keeps ghost_ladder null
# by design, but still shows its 1/2/3-star targets). Null in PVP (Standing box instead).
var _rung_source

# Standing box (Ranked)
var _lives_hero: Label
var _kills_val: Label
var _rank_val: Label

# Buttons
var _start_button: Button
var _ff_button: Button
var _build_button: Button
var _menu_button: Button
var _leaderboard_button: Button

var _status_box: PanelContainer    # the three rail boxes, captured for the arrival cascade
var _score_box: PanelContainer
var _buttons_box: PanelContainer   # for tower_slot_rect()
var _ff_index: int = 0
var _towers_count: int = 0
var _towers_cap: int = 0
var _last_build_mode: bool = false
# Ghost-ladder climb beat (design/JUICE.md "Staged climbs"): when the score passes a rung the
# lowest remaining target rises — pop the Current value to mark the climb. Tracked here.
var _ladder_first_target: int = 0
var _ladder_init: bool = false

func _ready() -> void:
	layer = 6
	# SCORE rung source: Trials uses the injected ghost ladder (leaderboard ghosts above
	# gold); campaign builds a local ladder from its star thresholds (no ghosts). PVP has no
	# score box. Built before _build_ui so the box renders its rungs immediately.
	if not _is_pvp():
		if ghost_ladder != null:
			_rung_source = ghost_ladder
		elif round_manager != null:
			_rung_source = GhostLadderScript.new()
			_rung_source.setup(int(round_manager.bronze_threshold), int(round_manager.silver_threshold),
				int(round_manager.gold_threshold), [], 0)
	_build_ui()

	if round_manager != null:
		round_manager.gold_changed.connect(func(_g): _refresh())
		round_manager.round_changed.connect(func(_r): _refresh())
		round_manager.phase_changed.connect(func(_p): _on_phase_changed())
		round_manager.build_timer_changed.connect(func(_t): _refresh_phase())
		round_manager.kills_changed.connect(func(_k): _refresh())
		round_manager.damage_dealt_changed.connect(func(_d): _refresh_score())
		if _is_pvp() and round_manager.coordinator != null:
			round_manager.coordinator.ready_changed.connect(_refresh_buttons)
			round_manager.coordinator.lives_resolved.connect(_refresh_standing)
	if build_controller != null:
		build_controller.towers_changed.connect(_on_towers_changed)
		_towers_count = build_controller.towers.size()
		_towers_cap = build_controller.max_towers
	_sync_ff_to_engine()
	_refresh()

	# JUICE (design/JUICE.md "Spatial grammar" + inmatch_hud_mock): the rail belongs to the
	# right edge, so its three boxes arrive from the right, staggered, on match start. Arm them
	# transparent now (before the first frame draws) so the cascade never flashes its end frame;
	# the slide itself runs deferred, once the boxes have laid out (real slide targets).
	for b in [_status_box, _score_box, _buttons_box]:
		if b != null:
			b.modulate.a = 0.0
	_play_rail_arrival.call_deferred()

func _play_rail_arrival() -> void:
	# Scale + fade, staggered top→bottom. The boxes live in a VBoxContainer that re-sorts as the
	# status text refreshes (the build timer ticks), which STOMPS any animated position — so the
	# arrival rides scale + modulate (render transforms the container never touches) rather than a
	# literal slide. Pivot at each box's centre so it grows in place.
	var boxes := [_status_box, _score_box, _buttons_box]
	for i in boxes.size():
		var b: Control = boxes[i]
		if b == null:
			continue
		b.pivot_offset = b.size * 0.5
		var d := Motion.dur(0.20 + i * 0.09)
		Motion.arrive_property(b, "scale", Vector2.ONE * 0.9, Vector2.ONE, Motion.M, d)
		Motion.fade_in(b, Motion.S, d)

# --- layout ----------------------------------------------------------------

func _build_ui() -> void:
	var s := UiLayout.scale_factor()
	var vp := get_viewport().get_visible_rect().size
	var reg := UiLayout.rail_region(vp)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var rail_ctrl := Control.new()
	rail_ctrl.position = reg.position
	rail_ctrl.custom_minimum_size = reg.size
	rail_ctrl.size = reg.size
	rail_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP  # rail area never pokes the board
	root.add_child(rail_ctrl)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(12 * s))
	margin.add_theme_constant_override("margin_right", int(12 * s))
	margin.add_theme_constant_override("margin_top", int(18 * s))
	margin.add_theme_constant_override("margin_bottom", int(18 * s))
	rail_ctrl.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(14 * s))
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(vb)

	_status_box = _build_status_box()
	vb.add_child(_status_box)
	_score_box = _build_score_box()
	vb.add_child(_score_box)
	_buttons_box = _build_buttons_box()
	vb.add_child(_buttons_box)

# A styled box (dock surface) with an inner padded VBox; returns [panel, content_vbox].
func _box() -> Array:
	var s := UiLayout.scale_factor()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.dock_box())
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(13 * s))
	m.add_theme_constant_override("margin_right", int(13 * s))
	m.add_theme_constant_override("margin_top", int(12 * s))
	m.add_theme_constant_override("margin_bottom", int(12 * s))
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(3 * s))
	m.add_child(v)
	return [panel, v]

func _build_status_box() -> PanelContainer:
	var box := _box()
	var v: VBoxContainer = box[1]
	_round_val = _kv(v, "Round", Color.WHITE)
	_phase_val = _kv(v, "Phase", Color.WHITE)
	_supply_val = _kv(v, "Supply", Color.WHITE)
	_gold_val = _kv(v, "Gold", GOLD_VAL)
	return box[0]

func _build_score_box() -> PanelContainer:
	var s := UiLayout.scale_factor()
	var box := _box()
	var panel: PanelContainer = box[0]
	var v: VBoxContainer = box[1]
	# Fixed frame: the score/standing box never resizes, so the Buttons box anchors stable.
	panel.custom_minimum_size = Vector2(0, SCORE_BOX_MIN_H * s)
	var head := Label.new()
	head.text = "STANDING" if _is_pvp() else "SCORE"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", int(11 * s))
	head.add_theme_color_override("font_color", UiStyle.LABEL_COL)
	v.add_child(head)
	v.add_child(_sep(s))

	if _is_pvp():
		_lives_hero = _hero(v, "Lives")
		_kills_val = _kv(v, "Kills", Color.WHITE)
		_rank_val = _kv(v, "Rank", Color.WHITE)
		_kv(v, "", Color.WHITE)  # one blank slot to match the Score-box height
	else:
		_score_hero = _hero(v, "Current")
		for i in range(3):
			_rungs.append(_rung_row(v))
	return panel

func _build_buttons_box() -> PanelContainer:
	var s := UiLayout.scale_factor()
	var box := _box()
	var v: VBoxContainer = box[1]
	v.add_theme_constant_override("separation", int(9 * s))
	if _is_pvp():
		_start_button = _rail_button(v, "✓ Ready", true)
		_start_button.pressed.connect(_on_start_pressed)
		_leaderboard_button = _rail_button(v, "Leaderboard", false)
		_leaderboard_button.pressed.connect(_on_minimap_pressed)
	else:
		_start_button = _rail_button(v, "▶ Start Round", true)
		_start_button.pressed.connect(_on_start_pressed)
		_ff_button = _rail_button(v, "Speed 1×", false)
		_ff_button.pressed.connect(_on_ff_pressed)
	_build_button = _rail_button(v, "Build  [B]", false)
	_build_button.pressed.connect(_on_build_pressed)
	_menu_button = _rail_button(v, "Menu", false)
	_menu_button.pressed.connect(_on_menu_pressed)
	return box[0]

# --- small builders --------------------------------------------------------

func _kv(parent: VBoxContainer, key: String, val_col: Color) -> Label:
	var s := UiLayout.scale_factor()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(9 * s))
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", int(15 * s))
	k.add_theme_color_override("font_color", Color("d5e0c6"))
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var val := Label.new()
	val.add_theme_font_size_override("font_size", int(15 * s))
	val.add_theme_color_override("font_color", val_col)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	parent.add_child(row)
	return val

func _hero(parent: VBoxContainer, key: String) -> Label:
	var s := UiLayout.scale_factor()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(9 * s))
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", int(14 * s))
	k.add_theme_color_override("font_color", Color("d5e0c6"))
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(k)
	var val := Label.new()
	val.text = "0"
	val.add_theme_font_size_override("font_size", int(24 * s))
	val.add_theme_color_override("font_color", Color.WHITE)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	parent.add_child(row)
	return val

# A SCORE rung: [star][label][value]. Returns {star, key, val} labels for in-place update.
func _rung_row(parent: VBoxContainer) -> Dictionary:
	var s := UiLayout.scale_factor()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(8 * s))
	row.custom_minimum_size = Vector2(0, 23 * s)
	var star := Label.new()
	star.custom_minimum_size = Vector2(18 * s, 0)
	star.add_theme_font_size_override("font_size", int(14 * s))
	star.add_theme_color_override("font_color", UiStyle.PILL_GOLD)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(star)
	var key := Label.new()
	key.add_theme_font_size_override("font_size", int(14 * s))
	key.add_theme_color_override("font_color", Color("cdd8be"))
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.clip_text = true
	key.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(key)
	var val := Label.new()
	val.add_theme_font_size_override("font_size", int(14 * s))
	val.add_theme_color_override("font_color", Color.WHITE)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	parent.add_child(row)
	return {"star": star, "key": key, "val": val}

func _sep(s: float) -> Control:
	var line := ColorRect.new()
	line.color = Color("1c2414")
	line.custom_minimum_size = Vector2(0, maxf(1.0, s))
	return line

func _rail_button(parent: VBoxContainer, text: String, go: bool) -> Button:
	var s := UiLayout.scale_factor()
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44 * s)
	b.add_theme_font_size_override("font_size", int(16 * s))
	if go:
		UiStyle.style_go_button(b)
	else:
		UiStyle.style_menu_button(b)
	parent.add_child(b)
	return b

# --- refresh ---------------------------------------------------------------

func _refresh() -> void:
	if round_manager == null:
		return
	if _is_pvp():
		_round_val.text = "%d" % round_manager.round_num
	else:
		_round_val.text = "%d / %d" % [round_manager.round_num, round_manager.max_rounds]
	_supply_val.text = "%d / %d" % [_towers_count, _towers_cap]
	_gold_val.text = "%d" % round_manager.gold
	_refresh_phase()
	_refresh_score()
	_refresh_standing()
	_refresh_buttons()

func _refresh_phase() -> void:
	if round_manager == null or _phase_val == null:
		return
	if round_manager.match_over:
		_phase_val.text = "Ended"
	elif round_manager.phase == "build":
		_phase_val.text = "Build · %d:%02d" % [int(round_manager.build_time_left) / 60, int(round_manager.build_time_left) % 60]
	else:
		_phase_val.text = "Run"

# Trials SCORE box: live hero score + the ascending remaining rungs (ghost ladder).
func _refresh_score() -> void:
	if _is_pvp() or _score_hero == null or round_manager == null:
		return
	var dmg: int = round_manager.total_damage_dealt
	_score_hero.text = _commas(dmg)
	var rungs: Array = []
	if _rung_source != null:
		rungs = _rung_source.rungs_above(dmg, _rungs.size())
	# JUICE: the lowest remaining target is the next rung; when it rises, the score just climbed
	# past a rung — pop the Current value as the climb beat (one pop per pass, not per hit).
	var first_target: int = int(rungs[0]["target"]) if not rungs.is_empty() else -1
	if _ladder_init and first_target != _ladder_first_target:
		Motion.pop(_score_hero, 1.14, Motion.S)
	_ladder_first_target = first_target
	_ladder_init = true
	for i in range(_rungs.size()):
		var r: Dictionary = _rungs[i]
		if i < rungs.size():
			var e: Dictionary = rungs[i]
			r["star"].text = "★" if e["kind"] == "star" else ""
			r["key"].text = String(e["label"])
			r["val"].text = _commas(int(e["target"]))
		else:
			r["star"].text = ""
			r["key"].text = ""
			r["val"].text = ""

# Ranked STANDING box: lives/kills/rank, FROZEN during the run (resolved at round end so a
# live rank never asserts info that doesn't exist yet). Refreshed on lives_resolved / round.
func _refresh_standing() -> void:
	if not _is_pvp() or _lives_hero == null or round_manager == null:
		return
	if round_manager.phase == "run" and not round_manager.match_over:
		return  # frozen mid-run
	_lives_hero.text = "%d" % maxi(0, round_manager.lives)
	_kills_val.text = "%d" % round_manager.total_kills
	_rank_val.text = _rank_text()

func _rank_text() -> String:
	var co = round_manager.coordinator
	if co == null:
		return "-"
	var active: int = co.active_boards().size() if co.has_method("active_boards") else 0
	var total: int = co.boards.size() if co.get("boards") != null else active
	if co.has_method("placement_of") and round_manager.eliminated:
		return "%d / %d" % [co.placement_of(round_manager), total]
	# Active: rank by settled lives among all boards (better lives = better rank).
	var rank := 1
	if co.get("boards") != null:
		for b in co.boards:
			if b != round_manager and not b.eliminated and b.lives > round_manager.lives:
				rank += 1
	return "%d / %d" % [rank, maxi(total, 1)]

func _refresh_buttons() -> void:
	if round_manager == null or _start_button == null:
		return
	var building: bool = round_manager.phase == "build" and not round_manager.match_over
	if _is_pvp():
		var coord = round_manager.coordinator
		var readied: bool = coord.is_board_ready(round_manager)
		_start_button.text = "%s Ready (%d/%d)" % ["✓" if readied else "○", coord.ready_count(), coord.active_boards().size()]
		_start_button.visible = building
	else:
		_start_button.text = "▶ Start Round"
		_start_button.visible = building
		if _ff_button != null:
			_ff_button.disabled = building  # Speed changes in RUN only (locked rule)
			_ff_button.text = "Speed %d×" % int(FF_MULTS[_ff_index])
	if _build_button != null:
		_build_button.disabled = not building

func _on_phase_changed() -> void:
	_refresh()
	_apply_time_scale()

func _on_towers_changed(count: int, cap: int) -> void:
	_towers_count = count
	_towers_cap = cap
	_refresh()

# Keep the Build button label in sync with build-mode (desktop toggle).
func _process(_dt: float) -> void:
	if _build_button != null and build_controller != null:
		var bm: bool = build_controller.is_build_mode()
		if bm != _last_build_mode:
			_last_build_mode = bm
			_build_button.text = "Exit Build  [B]" if bm else "Build  [B]"

# --- actions ---------------------------------------------------------------

func _on_start_pressed() -> void:
	if round_manager == null:
		return
	if _is_pvp():
		var coord = round_manager.coordinator
		coord.set_board_ready(round_manager, not coord.is_board_ready(round_manager))
		_refresh_buttons()
	else:
		round_manager.request_start_now()

func _on_ff_pressed() -> void:
	_ff_index = (_ff_index + 1) % FF_MULTS.size()
	_ff_button.text = "Speed %d×" % int(FF_MULTS[_ff_index])
	_apply_time_scale()

func _on_build_pressed() -> void:
	if build_controller != null:
		build_controller.toggle_build_mode()

func _on_minimap_pressed() -> void:
	if minimap != null:
		minimap.toggle()

func _on_menu_pressed() -> void:
	if pause_menu != null:
		pause_menu.toggle_pause()

# Speed multiplier applies in the RUN phase only (and never in PVP).
func _apply_time_scale() -> void:
	if _is_pvp():
		Engine.time_scale = 1.0
		return
	if round_manager != null and round_manager.phase == "run" and not round_manager.match_over:
		Engine.time_scale = FF_MULTS[_ff_index]
	else:
		Engine.time_scale = 1.0

# Init the speed index from the current engine scale so the button label never desyncs from
# the actual speed (polish #4: a 3× default used to start at 3× but the button read 1×).
func _sync_ff_to_engine() -> void:
	var cur := Engine.time_scale
	for i in range(FF_MULTS.size()):
		if is_equal_approx(FF_MULTS[i], cur):
			_ff_index = i
			break
	if _ff_button != null:
		_ff_button.text = "Speed %d×" % int(FF_MULTS[_ff_index])

# --- tower info dock query -------------------------------------------------

# The screen-space rectangle in the rail's lower gap beneath the Buttons box, where the
# tower info panel docks. Returns an EMPTY Rect2 when there isn't enough height — the tower
# node then falls back to an over-board overlay (design: in-rail with overlay fallback).
func tower_slot_rect() -> Rect2:
	if _buttons_box == null:
		return Rect2()
	var s := UiLayout.scale_factor()
	var vp := get_viewport().get_visible_rect().size
	var reg := UiLayout.rail_region(vp)
	var br := _buttons_box.get_global_rect()
	var top := br.position.y + br.size.y + 14.0 * s
	var bottom := reg.position.y + reg.size.y - 18.0 * s
	if bottom - top < TOWER_PANEL_MIN_H * s:
		return Rect2()
	return Rect2(br.position.x, top, br.size.x, bottom - top)

func _is_pvp() -> bool:
	return round_manager != null and round_manager.coordinator != null and round_manager.coordinator.is_pvp

func _commas(n: int) -> String:
	var str_n := str(n)
	var out := ""
	var c := 0
	for i in range(str_n.length() - 1, -1, -1):
		out = str_n[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
