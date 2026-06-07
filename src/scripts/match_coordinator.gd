extends Node
class_name MatchCoordinator

# Owns the SHARED match clock across all boards: round number, phase, and the
# build timer. Every board builds together and runs together; the run phase ends
# only when *all* active boards' trains have exited. Between rounds the coordinator
# runs cross-board resolution (PVP lives transfers / PVE scoring — added in later
# phases) and the win check.
#
# A solo match (campaign / solo PVE) is simply a coordinator with one board, so
# this single path serves every mode — the same philosophy as map_loader.
#
# Per-board state (gold, damage, kills, economy, towers, spawner) lives in the
# BoardState (round_manager.gd). Boards are referenced untyped to avoid the
# class-name cycle pitfall noted in project memory.

signal phase_changed(phase: String)
signal round_changed(new_round: int)
signal build_timer_changed(time_left: float)
signal match_ended
signal lives_resolved          # PVP: emitted after each round's lives transfer
signal board_eliminated(board) # PVP: a board dropped to 0 lives
signal ready_changed           # PVP: a board's build-phase ready vote changed

var max_rounds: int = 10  # set by map_loader from the MapResource

# PVP: lives transfer pairwise after each run phase and the match is last-standing
# (not capped by max_rounds). A safety cap prevents an unkillable stalemate.
var is_pvp: bool = false
const PVP_SAFETY_CAP := 60

var round_num: int = 1
var phase: String = "build"  # "build", "run", or "ended"
# PVP ready votes for the current build phase. The run starts early only when every
# active board has readied; otherwise it waits for the build timer (lockstep — no
# unilateral start, and no fast-forward, in multiplayer).
var _ready_set: Dictionary = {}
var build_time_left: float = GameConstants.BUILD_TIME_FIRST  # SECONDS — display proxy for the HUD
var match_over: bool = false

# === Fixed-step deterministic sim clock (resim_contract.md §5) ===
# The sim advances in fixed increments; the tick count is the ONLY clock inside the
# sim. Render framerate and Engine.time_scale change only HOW MANY ticks run per
# rendered frame (live pacing) — never the result. Re-sim replays the same tick
# sequence headless and gets the same answer. §5.1 confirmed floats are safe here.
const SIM_HZ := 60
const SIM_DT := 1.0 / SIM_HZ          # the only dt the sim ever sees
const MAX_STEPS_PER_FRAME := 8        # spiral-of-death guard / fast-forward cap (pacing only)
var sim_tick: int = 0
var _sim_accum: float = 0.0
# Build-phase countdown in TICKS (authoritative); build_time_left mirrors it in
# seconds for the HUD. On a networked client the host owns it (net_set_build_time).
var build_ticks_left: int = 0
# One per-match seeded RNG for ALL combat rolls (crit), drawn in a fixed order:
# boards in registration order → towers in placement order (see _step_entities /
# BoardState.sim_step). Seed comes from the match record; default 0 keeps offline
# runs reproducible. Wiring the server-issued seed is the record-capture task.
var sim_seed: int = 0
var rng := RandomNumberGenerator.new()

# === Match record capture (resim_contract.md §2) ===
# While recording, every applied build action is appended to input_log tagged with
# the sim_tick it landed on. The record (make_record) = seed + map_ref + input_log;
# replaying it headless from the same seed reproduces the match exactly (see
# scripts/resim.gd). Disabled on a re-sim build so the replay doesn't re-log.
# Set by map_loader for real matches.
var record_enabled := false
var ruleset_version := "0.1"
var map_ref: Dictionary = {}   # identifies the exact map (§2.1); set by map_loader
var input_log: Array = []      # ordered [{tick, seat, action:{type, ...}}]

# Append one applied action to the record, tagged with the current sim_tick. Build
# actions are build-phase-only (nothing sims during build), so the exact within-phase
# tick never changes the outcome — but it's recorded for audit and round-start derivation.
func log_input(seat: int, action: Dictionary) -> void:
	if not record_enabled:
		return
	input_log.append({"tick": sim_tick, "seat": seat, "action": action})

# The canonical match record (§2). Deep-copied so later play can't mutate a taken record.
func make_record() -> Dictionary:
	return {
		"seed": sim_seed,
		"map_ref": map_ref.duplicate(true),
		"ruleset_version": ruleset_version,
		"players": boards.size(),
		"input_log": input_log.duplicate(true),
	}

# Networked PVP: on a CLIENT the authoritative host owns the clock, so the client's
# coordinator does NOT self-tick — NetMatch drives it via the net_* methods below.
# The host (authority) leaves this false and runs the clock normally. `net` is the
# NetMatch driver (set by map_loader/NetMatch); null for solo / offline-bot matches.
var driven_externally: bool = false
var net = null

var boards: Array = []  # BoardState nodes, registered by map_loader
# PVP: display handles per board (same index as `boards`). Board 0 is the local
# player ("You"); the rest are opponent handles. Set by map_loader for PVP matches.
var board_names: Array = []

# Display name for a board node (falls back to "Board N" if names aren't set).
func name_for(board) -> String:
	var i := boards.find(board)
	if i >= 0 and i < board_names.size():
		return board_names[i]
	return "Board %d" % (i + 1) if i >= 0 else "—"

# Per-frame cap on bot build actions across ALL boards. Each bot action runs a
# burst of A* path computations; with 7 bots created together their timers fired on
# the same frame (~90 A* runs at once), producing multi-second build-phase hitches
# that could trip the OS GPU watchdog. This serializes them to a few per frame —
# they still build over the (seconds-long) build phase, just without the spike.
const MAX_BOT_ACTIONS_PER_FRAME := 2
var _bot_actions_this_frame := 0
# PVP placement, worst-first: boards are appended as they're eliminated, and the
# surviving winner(s) are appended last. placement_of() reads this.
var finish_order: Array = []

func register_board(board) -> void:
	boards.append(board)

# A bot asks permission to act this frame; returns false once the frame's budget is
# spent (the bot keeps its timer and retries next frame). Caps total bot pathfinding
# per frame regardless of how many bots are ready at once.
func try_consume_bot_action() -> bool:
	if _bot_actions_this_frame >= MAX_BOT_ACTIONS_PER_FRAME:
		return false
	_bot_actions_this_frame += 1
	return true

func _ready() -> void:
	# Seed the single combat RNG and arm the tick-based build timer. map_loader sets
	# all coordinator config (incl. sim_seed) BEFORE add_child, so it's ready here.
	rng.seed = sim_seed
	build_ticks_left = _build_ticks_for(round_num)
	build_time_left = build_ticks_left * SIM_DT

func _process(delta: float) -> void:
	_bot_actions_this_frame = 0  # reset the per-frame bot budget (coordinator runs first)
	if match_over:
		return
	# Fixed-timestep accumulator: convert real (time_scaled) frame time into a whole
	# number of fixed sim ticks. Backlog beyond the cap is dropped — that only slows
	# live pacing under load; the authoritative outcome is the tick sequence itself.
	_sim_accum += delta
	var backlog_cap := MAX_STEPS_PER_FRAME * SIM_DT
	if _sim_accum > backlog_cap:
		_sim_accum = backlog_cap
	var steps := 0
	while _sim_accum >= SIM_DT and steps < MAX_STEPS_PER_FRAME:
		_sim_accum -= SIM_DT
		steps += 1
		_sim_tick_once()

# One fixed logical tick. Entities simulate locally on EVERY machine during the run
# (host and client both run the full sim — only build inputs + the clock cross the
# wire). The match clock is host-owned: a networked client mirrors it via net_* and
# must not self-advance.
func _sim_tick_once() -> void:
	sim_tick += 1
	if phase == "run":
		_step_entities()
	if driven_externally:
		return
	if phase == "build":
		if build_ticks_left > 0:
			build_ticks_left -= 1
			build_time_left = build_ticks_left * SIM_DT
			emit_signal("build_timer_changed", build_time_left)
		if build_ticks_left <= 0:
			_start_run_phase()
	else:  # run
		if _all_runs_done():
			_end_round()

# Step every active board's sim by one tick, boards in registration (seat) order so
# the shared RNG's draw sequence is fixed and reproducible by the re-sim.
func _step_entities() -> void:
	for b in boards:
		if b.is_active():
			b.sim_step(SIM_DT, rng)

func _build_ticks_for(rn: int) -> int:
	return int(round(_build_duration_for(rn) * SIM_HZ))

# Global mob-HP curve (per DESIGN): flat for the first N rounds, then geometric.
func mob_hp_for_round() -> float:
	if round_num <= GameConstants.MOB_HP_FLAT_ROUNDS:
		return GameConstants.MOB_BASE_HP
	var growth_rounds := round_num - GameConstants.MOB_HP_FLAT_ROUNDS
	return GameConstants.MOB_BASE_HP * pow(GameConstants.MOB_HP_GROWTH, growth_rounds)

# Single-player (campaign / solo PVE): skip the remaining build timer and start now.
# Ignored in PVP, where the run is gated on the ready vote (set_board_ready).
func request_start_now() -> void:
	if phase != "build" or is_pvp:
		return
	log_input(0, {"type": "start"})  # solo early start (§9.2); seat 0 (solo = one board)
	_start_run_phase()

# PVP ready vote. The run starts early once every active board has readied; until
# then the build timer keeps running and the round simply waits.
func set_board_ready(board, value: bool) -> void:
	# Networked client: the host owns ready resolution — send the vote up, don't apply.
	if driven_externally and net != null:
		net.send_local_ready(value)
		return
	if not is_pvp or phase != "build":
		return
	log_input(boards.find(board), {"type": "vote_start", "value": value})  # §9.2
	if value:
		_ready_set[board] = true
	else:
		_ready_set.erase(board)
	emit_signal("ready_changed")
	for b in boards:
		if b.is_active() and not _ready_set.has(b):
			return  # someone still isn't ready — keep waiting
	_start_run_phase()

func is_board_ready(board) -> bool:
	# Networked client tracks only its OWN vote locally (host owns the rest).
	if driven_externally and net != null:
		return net.local_ready if net.is_local_board(board) else false
	return _ready_set.has(board)

func ready_count() -> int:
	if driven_externally and net != null:
		return net.net_ready_count  # host-reported, via CLOCK
	var n := 0
	for b in active_boards():
		if _ready_set.has(b):
			n += 1
	return n

func _start_run_phase() -> void:
	_ready_set.clear()  # ready votes are per build phase
	phase = "run"
	emit_signal("phase_changed", phase)
	var hp := mob_hp_for_round()
	for b in boards:
		if b.is_active():
			b.start_run(round_num, hp)

func _all_runs_done() -> bool:
	for b in boards:
		if b.is_active() and not b.is_run_done():
			return false
	return true

func _end_round() -> void:
	# Each board awards its own end-of-round economy (round bonus + interest) and
	# emits its round summary.
	for b in boards:
		if b.is_active():
			b.settle_round(round_num)

	# PVP: pairwise lives transfers + eliminations; last-standing ends the match.
	if is_pvp:
		resolve_lives()
		var active := active_boards()
		if active.size() <= 1 or round_num >= PVP_SAFETY_CAP:
			# Rank any survivors best-last, then finish.
			active.sort_custom(func(a, b): return a.lives < b.lives)
			for b in active:
				finish_order.append(b)
			_end_match()
			return
	elif round_num >= max_rounds:
		_end_match()
		return

	round_num += 1
	emit_signal("round_changed", round_num)
	phase = "build"
	build_ticks_left = _build_ticks_for(round_num)
	build_time_left = build_ticks_left * SIM_DT
	emit_signal("phase_changed", phase)
	emit_signal("build_timer_changed", build_time_left)

# Active = not eliminated.
func active_boards() -> Array:
	var a: Array = []
	for b in boards:
		if b.is_active():
			a.append(b)
	return a

# Model B pairwise transfers among active boards: each board's net change equals
# the sum over opponents of (my kills - their kills) this round, i.e.
# n*my_kills - total_kills. Zero-sum. Then eliminate boards at <= 0 lives.
func resolve_lives() -> void:
	var active := active_boards()
	var n := active.size()
	if n <= 1:
		return
	var total_kills := 0
	for b in active:
		total_kills += b.kills_this_round
	# Raw zero-sum pairwise deltas: n*my_kills - total_kills (depend only on this round).
	var deltas := {}
	for b in active:
		deltas[b] = n * b.kills_this_round - total_kills
	# A losing board can only forfeit the lives it actually HAS. Any extra it "owes"
	# beyond that is phantom — crediting it to the winners would inflate the pool (the
	# old code added the full delta then clamped losers up to 0, leaking those lives, so
	# a 2-player match could end at 209/0 instead of 200/0). Sum the shortfall and pull
	# it back out of the winners, split by each winner's share of the gains, so the pool
	# stays EXACTLY conserved and no board ends below 0.
	var shortfall := 0
	var total_gain := 0
	for b in active:
		if b.lives + deltas[b] < 0:
			shortfall += -(b.lives + deltas[b])
		if deltas[b] > 0:
			total_gain += deltas[b]
	var reduce := {}
	if shortfall > 0 and total_gain > 0:
		var assigned := 0
		var rema: Array = []  # [board, fractional remainder] for exact integer split
		for b in active:
			if deltas[b] > 0:
				var exact := float(shortfall) * float(deltas[b]) / float(total_gain)
				reduce[b] = int(floor(exact))
				assigned += reduce[b]
				rema.append([b, exact - floor(exact)])
		# Hand the leftover units to the largest remainders so reductions sum to shortfall.
		rema.sort_custom(func(a, c): return a[1] > c[1])
		for i in range(shortfall - assigned):
			reduce[rema[i % rema.size()][0]] += 1
	# Apply; keep the pre-clamp value to order eliminations (worst deficit places worst).
	var raw_new := {}
	for b in active:
		var d: int = deltas[b] - int(reduce.get(b, 0))
		raw_new[b] = b.lives + d
		b.lives = max(0, raw_new[b])
	for b in active:
		b.kills_this_round = 0
	# Eliminate, worst (most negative pre-clamp) first so placement ties resolve sensibly.
	var newly: Array = []
	for b in active:
		if b.lives <= 0:
			newly.append(b)
	newly.sort_custom(func(a, c): return raw_new[a] < raw_new[c])
	for b in newly:
		b.lives = 0
		b.eliminated = true
		finish_order.append(b)
		emit_signal("board_eliminated", b)
	emit_signal("lives_resolved")

# Live PVP lives projection DURING the run: lives + the net pairwise transfer the
# board would get if the round ended right now (same zero-sum formula as resolve_lives,
# n*my_kills - total_kills). Lets the HUD/leaderboard move lives mid-match instead of
# snapping only at round end. Outside the run (or non-PVP) it's just the settled lives.
# Can be negative (board on track for elimination) — callers clamp for display.
func projected_lives(board) -> int:
	if not is_pvp or phase != "run":
		return board.lives
	var active := active_boards()
	var n := active.size()
	if n <= 1 or not active.has(board):
		return board.lives
	var total_kills := 0
	var pool := 0
	for b in active:
		total_kills += b.kills_this_round
		pool += b.lives
	# Same zero-sum formula as resolve_lives, but a board can never end up holding more
	# than the whole live pool (no board can take lives the others don't have). Upper-cap
	# keeps the HUD from briefly showing >pool mid-run; callers still clamp the low side.
	return mini(board.lives + n * board.kills_this_round - total_kills, pool)

# 1-based placement (1 = winner / last standing). 0 if not yet decided.
func placement_of(board) -> int:
	var idx := finish_order.find(board)
	if idx == -1:
		return 0
	return boards.size() - idx

func _end_match() -> void:
	match_over = true
	phase = "ended"
	emit_signal("phase_changed", phase)
	emit_signal("match_ended")

# ============================================================================
# Networked CLIENT driving (driven_externally). NetMatch calls these in response to
# the host's authoritative CLOCK / RESOLUTION / MATCH_END messages — the client never
# runs the clock or resolve_lives itself; it mirrors the host.
# ============================================================================

func net_enter_run() -> void:
	phase = "run"
	emit_signal("phase_changed", phase)
	var hp := mob_hp_for_round()
	for b in boards:
		if b.is_active():
			b.start_run(round_num, hp)

# Round ended on the host: settle economy locally + clear leftover mobs, then enter
# the next build. Lives arrive separately via RESOLUTION (NetMatch), not here.
func net_enter_build(new_round: int) -> void:
	for b in boards:
		if b.is_active():
			b.settle_round(round_num)
	_clear_all_mobs()
	round_num = new_round
	emit_signal("round_changed", round_num)
	phase = "build"
	emit_signal("phase_changed", phase)

func net_set_build_time(t: float) -> void:
	build_time_left = t
	emit_signal("build_timer_changed", build_time_left)

func net_end_match() -> void:
	if match_over:
		return
	match_over = true
	phase = "ended"
	emit_signal("phase_changed", phase)
	emit_signal("match_ended")

func _clear_all_mobs() -> void:
	for b in boards:
		for m in b.mobs_array:
			if is_instance_valid(m):
				m.alive = false
				m.queue_free()
		b.mobs_array.clear()
		b.clear_projectiles()

func _build_duration_for(rn: int) -> float:
	if rn == 1:
		return GameConstants.BUILD_TIME_FIRST
	if rn >= GameConstants.LATE_ROUND_THRESHOLD:
		return GameConstants.BUILD_TIME_LATE
	return GameConstants.BUILD_TIME_NORMAL
