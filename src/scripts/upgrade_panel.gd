extends CanvasLayer
class_name UpgradePanel

const STATS := ["damage", "range", "attack_speed", "crit_chance", "crit_damage", "multishot"]
const STAT_LABELS := {
	"damage": "Damage",
	"range": "Range",
	"attack_speed": "Atk Speed",
	"crit_chance": "Crit Chance",
	"crit_damage": "Crit Damage",
	"multishot": "Multishot",
}

var round_manager  # RoundManager — untyped to avoid class-name cycle

const TILE_PX := 48.0  # for range-in-tiles display

var _target_tower: Node2D
var _panel: PanelContainer
var _stats_label: Label
var _stat_tier_labels: Dictionary = {}
var _stat_value_labels: Dictionary = {}
var _stat_buttons: Dictionary = {}

func _ready() -> void:
	layer = 10
	_build_ui()
	_panel.visible = false
	if round_manager != null:
		round_manager.gold_changed.connect(_on_gold_changed)
		round_manager.phase_changed.connect(_on_phase_changed)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(400, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Tower upgrades"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Cumulative performance — updates live so you can spot your top-DPS tower.
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 15)
	_stats_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(_stats_label)

	var hsep := HSeparator.new()
	vbox.add_child(hsep)

	for stat in STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_label := Label.new()
		name_label.text = STAT_LABELS[stat]
		name_label.custom_minimum_size = Vector2(110, 40)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)

		var tier_label := Label.new()
		tier_label.text = "T0"
		tier_label.custom_minimum_size = Vector2(34, 40)
		tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stat_tier_labels[stat] = tier_label
		row.add_child(tier_label)

		var value_label := Label.new()
		value_label.text = "—"
		value_label.custom_minimum_size = Vector2(64, 40)
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		_stat_value_labels[stat] = value_label
		row.add_child(value_label)

		var button := Button.new()
		button.text = "+"
		button.custom_minimum_size = Vector2(110, 40)
		button.pressed.connect(_on_upgrade_pressed.bind(stat))
		_stat_buttons[stat] = button
		row.add_child(button)

		vbox.add_child(row)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(hide_panel)
	vbox.add_child(close)

func show_for(tower: Node2D) -> void:
	if _target_tower != null and _target_tower != tower and is_instance_valid(_target_tower):
		_target_tower.set_selected(false)
	_target_tower = tower
	if is_instance_valid(_target_tower):
		_target_tower.set_selected(true)
	_refresh_labels()
	_panel.visible = true
	_position_near(tower)

# Place the panel beside the tower but always fully on-screen: flip to the
# tower's left if it would spill off the right edge, then clamp into the viewport
# so a tower near any edge never hides part of the panel.
func _position_near(tower: Node2D) -> void:
	var panel_size := _panel.get_combined_minimum_size()
	var vp := get_viewport().get_visible_rect().size
	var margin := 8.0
	var pos := tower.position + Vector2(80, -120)
	if pos.x + panel_size.x > vp.x - margin:
		pos.x = tower.position.x - 80.0 - panel_size.x
	pos.x = clampf(pos.x, margin, maxf(margin, vp.x - panel_size.x - margin))
	pos.y = clampf(pos.y, margin, maxf(margin, vp.y - panel_size.y - margin))
	_panel.position = pos

func hide_panel() -> void:
	if _target_tower != null and is_instance_valid(_target_tower):
		_target_tower.set_selected(false)
	_target_tower = null
	_panel.visible = false

func _refresh_labels() -> void:
	if not is_instance_valid(_target_tower):
		return
	var in_build: bool = round_manager == null or round_manager.phase == "build"
	var gold: int = round_manager.gold if round_manager != null else 99999
	_stats_label.text = "Damage done: %d   ·   Kills: %d" % [int(_target_tower.damage_done), _target_tower.kills]
	for stat in STATS:
		_stat_tier_labels[stat].text = "T%d" % _target_tower.tiers[stat]
		_stat_value_labels[stat].text = _effective_value(stat)
		var button: Button = _stat_buttons[stat]
		var cost: int = _target_tower.upgrade_cost(stat)
		if cost <= 0:
			button.text = "MAX"
			button.disabled = true
		else:
			button.text = "+ %dg" % cost
			button.disabled = (not in_build) or (gold < cost)

# Real, effective stat values (zone bonuses included) pulled from the tower's getters.
func _effective_value(stat: String) -> String:
	var t := _target_tower
	match stat:
		"damage":       return "%.0f" % t.get_damage()
		"range":        return "%.1ft" % (t.get_range() / TILE_PX)
		"attack_speed": return "%.2f/s" % (1.0 / t.get_cooldown())
		"crit_chance":  return "%d%%" % int(round(t.get_crit_chance() * 100.0))
		"crit_damage":  return "x%.2f" % t.get_crit_damage_mult()
		"multishot":    return "%d tgt" % (1 + t.get_multishot())
	return "—"

func _process(_delta: float) -> void:
	# Live-refresh the cumulative damage/kills while the panel is open (e.g. watching
	# a tower during the run phase).
	if _panel.visible and is_instance_valid(_target_tower):
		_stats_label.text = "Damage done: %d   ·   Kills: %d" % [int(_target_tower.damage_done), _target_tower.kills]

func _on_upgrade_pressed(stat: String) -> void:
	if not is_instance_valid(_target_tower):
		return
	if round_manager == null:
		_target_tower.upgrade(stat)
		_refresh_labels()
		return
	if round_manager.phase != "build":
		return
	var cost: int = _target_tower.upgrade_cost(stat)
	if cost <= 0:
		return
	if not round_manager.spend(cost):
		return
	_target_tower.upgrade(stat)
	_refresh_labels()

func _on_gold_changed(_new_gold: int) -> void:
	if _panel.visible:
		_refresh_labels()

func _on_phase_changed(_phase: String) -> void:
	if _panel.visible:
		_refresh_labels()

func is_visible_panel() -> bool:
	return _panel.visible

func contains_screen_point(screen_pos: Vector2) -> bool:
	if not _panel.visible:
		return false
	return _panel.get_global_rect().has_point(screen_pos)
