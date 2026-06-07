extends Node
class_name RoundManager

# Per-board state for one player's maze: gold/economy, damage + kill tallies,
# this board's spawner, and run-completion detection. The SHARED match clock
# (round number, phase, build timer, win condition) lives in MatchCoordinator —
# this node is driven by it. A solo match is a coordinator with one board.
#
# NOTE: this used to own the whole match (clock + state). It was split for
# multiplayer (N boards, one clock). The class is still named RoundManager and
# consumers still hold a `round_manager` ref — it now means "this board." It
# proxies the clock fields (phase/round/build_time/max_rounds/match_over) and
# forwards the coordinator's clock signals, so HUD/build_controller/panels need
# no changes whether there's one board or eight.
#
# Global tuning (economy, timings, HP growth) lives in the GameConstants autoload.

# Per-map config — set by map_loader from the MapResource.
var mob_count: int = 8           # enemy supply, constant per match
var bronze_threshold: int = 0
var silver_threshold: int = 0
var gold_threshold: int = 0

# The shared clock. Set by map_loader before tree entry.
var coordinator  # MatchCoordinator — untyped to avoid class-name cycle

# Per-board economy/score signals (owned here).
signal gold_changed(new_gold: int)
signal damage_dealt_changed(total: int)
signal kills_changed(total: int)
signal gold_goal_reached  # total damage crossed the Gold threshold mid-match
signal round_summary(round_completed: int, kill_gold: int, round_bonus: int, interest: int)

# Clock signals — forwarded verbatim from the coordinator so consumers can keep
# connecting to `round_manager.<signal>` regardless of board count.
signal phase_changed(phase: String)
signal round_changed(new_round: int)
signal build_timer_changed(time_left: float)
signal match_ended

var gold: int = GameConstants.STARTING_GOLD
var total_damage_dealt: int = 0
var total_kills: int = 0
var gold_goal_hit: bool = false  # has the Gold threshold been reached this match
# PVP lives (zero-sum across boards). Set by map_loader for PVP; unused otherwise.
var lives: int = 0
var kills_this_round: int = 0    # reset by the coordinator after lives resolution
var eliminated: bool = false     # PVP only; always false in solo
var _round_kill_gold: int = 0    # kill gold accumulated during the current round

var spawner  # Spawner — untyped to avoid class-name cycle
var build_controller  # BuildController — untyped to avoid class-name cycle
var mobs_array: Array  # shared with this board's towers + spawner
var projectiles: Array = []  # in-flight projectiles on this board, stepped by sim_step
                             # in creation order (each tower appends here when it fires)
var bonus_zones: Array = []  # this board's BonusZone nodes (board-scoped, not a
                             # global group — towers/mobs on other boards must not
                             # see these once multiple boards coexist)

# --- Clock proxies: read straight from the coordinator so existing consumers
# (HUD, build_controller, upgrade_panel, panels) keep reading round_manager.* ---

var phase: String:
	get:
		return coordinator.phase if coordinator != null else "build"

var round_num: int:
	get:
		return coordinator.round_num if coordinator != null else 1

var build_time_left: float:
	get:
		return coordinator.build_time_left if coordinator != null else GameConstants.BUILD_TIME_FIRST

var max_rounds: int:
	get:
		return coordinator.max_rounds if coordinator != null else 10

var match_over: bool:
	get:
		return coordinator.match_over if coordinator != null else false

func _ready() -> void:
	if coordinator != null:
		# Forward the shared clock signals so board consumers see them as ours.
		coordinator.phase_changed.connect(func(p): emit_signal("phase_changed", p))
		coordinator.round_changed.connect(func(r): emit_signal("round_changed", r))
		coordinator.build_timer_changed.connect(func(t): emit_signal("build_timer_changed", t))
		coordinator.match_ended.connect(func(): emit_signal("match_ended"))
	# Seed consumers with current state (clock read from the coordinator).
	emit_signal("gold_changed", gold)
	emit_signal("damage_dealt_changed", total_damage_dealt)
	emit_signal("kills_changed", total_kills)
	emit_signal("phase_changed", phase)
	emit_signal("round_changed", round_num)
	emit_signal("build_timer_changed", build_time_left)

# --- Active flag (PVP elimination; always active in solo) ---

func is_active() -> bool:
	return not eliminated

# --- Economy ---

func can_afford(cost: int) -> bool:
	return gold >= cost

func spend(cost: int) -> bool:
	if gold < cost:
		return false
	gold -= cost
	emit_signal("gold_changed", gold)
	return true

func refund(amount: int) -> void:
	gold += amount
	emit_signal("gold_changed", gold)

# Best-effort spend for REPLICATED opponent boards (networked): the owner already
# validated affordability, so apply unconditionally (clamped at 0 so the displayed
# gold never goes negative under cross-machine economy drift).
func net_spend(cost: int) -> void:
	gold = maxi(0, gold - cost)
	emit_signal("gold_changed", gold)

func _on_mob_killed() -> void:
	gold += GameConstants.KILL_BONUS
	_round_kill_gold += GameConstants.KILL_BONUS
	total_kills += 1
	kills_this_round += 1  # drives PVP pairwise lives transfers
	emit_signal("gold_changed", gold)
	emit_signal("kills_changed", total_kills)

# Called directly by this board's mobs (mob.board._on_damage_dealt). Overkill is
# clamped at the call site so a 100-damage shot on a 10-HP mob credits 10.
func _on_damage_dealt(amount: float) -> void:
	total_damage_dealt += int(round(amount))
	emit_signal("damage_dealt_changed", total_damage_dealt)
	# Crossing the Gold threshold mid-match offers an early "you won" choice
	# (campaign / solo PVE). gold_threshold is 0 in PVP, so this never fires there.
	if gold_threshold > 0 and not gold_goal_hit and not match_over and total_damage_dealt >= gold_threshold:
		gold_goal_hit = true
		emit_signal("gold_goal_reached")

func medal_for(damage: int) -> String:
	if damage >= gold_threshold:
		return "gold"
	if damage >= silver_threshold:
		return "silver"
	if damage >= bronze_threshold:
		return "bronze"
	return "none"

# Convenience pass-through so HUD's "start now" button stays wired to the board.
func request_start_now() -> void:
	if coordinator != null:
		coordinator.request_start_now()

# --- Driven by the coordinator ---

# Start this board's run phase: spawn its train along its current maze path.
func start_run(_round_num: int, mob_hp: float) -> void:
	clear_projectiles()  # drop any leftovers so each run starts clean
	var wave_path: PackedVector2Array = build_controller.current_path_world()
	spawner.start_wave(mob_count, GameConstants.SPAWN_INTERVAL, mob_hp, wave_path)

# Advance THIS board's sim by one fixed tick, in a fixed, reproducible order:
#   spawn → towers fire → projectiles move/resolve → mobs move.
# The single match RNG is threaded through so every crit draw lands in one defined
# sequence (towers in placement order). Despawns are applied SYNCHRONOUSLY (removed
# from the arrays this tick, not via end-of-frame queue_free) so a frame that runs
# several ticks never sees a half-dead entity.
func sim_step(dt: float, rng: RandomNumberGenerator) -> void:
	if spawner != null:
		spawner.sim_step(dt)
	if build_controller != null:
		for t in build_controller.towers:
			if is_instance_valid(t):
				t.sim_step(dt, rng)
	var i := 0
	while i < projectiles.size():
		var p = projectiles[i]
		if not is_instance_valid(p):
			projectiles.remove_at(i)
			continue
		if p.sim_step(dt):  # true = done (hit or target gone)
			projectiles.remove_at(i)
			p.queue_free()
		else:
			i += 1
	var j := 0
	while j < mobs_array.size():
		var m = mobs_array[j]
		if not is_instance_valid(m):
			mobs_array.remove_at(j)
			continue
		if m.sim_step(dt):  # true = reached the exit
			m.alive = false
			mobs_array.remove_at(j)
			m.queue_free()
		else:
			j += 1

func clear_projectiles() -> void:
	for p in projectiles:
		if is_instance_valid(p):
			p.queue_free()
	projectiles.clear()

# True once the train has fully spawned and no mobs remain on this board.
func is_run_done() -> bool:
	return spawner != null and spawner.is_done() and _alive_mob_count() == 0

# Award the completed round's bonus + interest and emit this board's summary.
func settle_round(round_completed: int) -> void:
	var round_bonus := GameConstants.ROUND_BONUS_BASE + round_completed
	var interest := mini(int(floor(gold * GameConstants.INTEREST_RATE)), GameConstants.INTEREST_CAP)
	gold += round_bonus + interest
	emit_signal("gold_changed", gold)
	emit_signal("round_summary", round_completed, _round_kill_gold, round_bonus, interest)
	_round_kill_gold = 0

func _alive_mob_count() -> int:
	var n := 0
	for m in mobs_array:
		if is_instance_valid(m):
			n += 1
	return n
