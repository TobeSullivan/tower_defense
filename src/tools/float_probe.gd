extends SceneTree

# ============================================================================
# Cross-platform float determinism probe (resim_contract.md §5.1).
#
# THE QUESTION: clients run on Win/Mac; the re-sim server runs on Linux. If
# Godot's float math (sqrt via Vector2, pow, multiply-accumulate, and the float
# COMPARISONS that gate branches) produces even a 1-ULP different result on a
# different platform, the server's re-sim will disagree with an honest client
# and falsely flag them. This is the cheapest possible test of that risk:
# run an identical scripted sim and dump the bit-exact final state.
#
# This file is DELIBERATELY self-contained — no autoloads, no scene tree, no
# textures. The constants below MIRROR resources/game_constants.gd so the
# arithmetic matches the real sim, but the file depends on nothing project-side.
# That makes it a portable artifact: copy it anywhere and run
#
#   Godot --headless --path <project_src> --script res://tools/float_probe.gd
#
# on each platform, then diff the output blocks. Identical hex => floats are
# safe and we build the determinism conversion on floats. Any difference =>
# move sim-critical accumulation to fixed-point integer math before building
# the re-sim contract on a bad assumption.
#
# NOTE: this is a STRESS scenario, not a real match — mobs loop the path so the
# sim runs hot for many ticks and compounds any drift into a visible hash diff.
# It uses the real formulas and the real engine float ops; that's the point.
# ============================================================================

# --- Constants mirrored from resources/game_constants.gd ---
const MOB_BASE_HP := 100.0
const MOB_SPEED := 80.0
const MOB_SLOW_FLOOR := 0.10
const MOB_HP_FLAT_ROUNDS := 5
const MOB_HP_GROWTH := 1.12

const TOWER_BASE_RANGE := 160.0
const TOWER_BASE_DAMAGE := 25.0
const TOWER_BASE_COOLDOWN := 0.8
const TOWER_DAMAGE_INCREMENT := 0.34
const TOWER_ATTACK_SPEED_INCREMENT := 0.15
const TOWER_RANGE_INCREMENT := 0.10

const CRIT_CHANCE_PER_TIER := 0.10
const CRIT_CHANCE_HARD_CAP := 0.75
const CRIT_DAMAGE_BASE := 1.5
const CRIT_DAMAGE_PER_TIER := 0.20
const MULTISHOT_HARD_CAP := 3

const PROJECTILE_SPEED := 900.0

# --- Probe scenario parameters ---
const DT := 1.0 / 60.0
const TICKS := 9000          # 150 "seconds" of sim at 60 Hz
const MOB_COUNT := 14
const SPAWN_TICKS := 60      # one mob every 60 ticks (SPAWN_INTERVAL = 1.0s)

# A serpentine path across a ~1200x700 board (world pixels).
# (var, not const — a PackedVector2Array from a literal isn't a constant expr.)
var PATH := PackedVector2Array([
	Vector2(40, 80), Vector2(1160, 80), Vector2(1160, 220),
	Vector2(40, 220), Vector2(40, 360), Vector2(1160, 360),
	Vector2(1160, 500), Vector2(40, 500), Vector2(40, 640),
	Vector2(1160, 640),
])

# 8 towers, each as [x, y, dmg_tier, range_tier, atkspd_tier, crit_chance_tier,
# crit_dmg_tier, multishot_tier] — a spread that exercises the whole formula space.
const TOWERS := [
	[200, 150, 0, 0, 0, 0, 0, 0],
	[600, 150, 3, 1, 2, 0, 0, 0],
	[1000, 290, 1, 4, 0, 3, 0, 0],
	[300, 290, 5, 0, 1, 0, 4, 0],
	[700, 430, 2, 2, 5, 2, 0, 1],
	[1050, 430, 9, 0, 3, 7, 3, 0],
	[150, 570, 4, 3, 2, 5, 5, 2],
	[850, 570, 6, 1, 4, 9, 2, 3],
]

# --- Deterministic integer RNG (LCG) — platform-independent by construction, so
# any output divergence is pure FLOAT divergence, never branch-from-different-dice.
var _rng_state: int = 0x2545F4914F6CDD1D

func _rng_next() -> int:
	# 64-bit LCG (Knuth MMIX constants). GDScript ints are 64-bit signed and
	# overflow wraps two's-complement identically on every platform — no mask
	# needed (and the 0xFFFF...FFFF literal isn't representable as signed int64).
	_rng_state = _rng_state * 6364136223846793005 + 1442695040888963407
	return _rng_state

func _rng_randf() -> float:
	# Top 53 bits -> [0,1). Integer-derived, so identical on every platform.
	var bits := (_rng_next() >> 11) & 0x1FFFFFFFFFFFFF
	return float(bits) / 9007199254740992.0  # 2^53

# --- Tower stat formulas (mirror tower.gd; zone bonuses omitted — none in probe) ---
func _tower_damage(t: Array) -> float:
	return TOWER_BASE_DAMAGE * (1.0 + t[2] * TOWER_DAMAGE_INCREMENT)

func _tower_range(t: Array) -> float:
	return TOWER_BASE_RANGE * (1.0 + t[3] * TOWER_RANGE_INCREMENT)

func _tower_cooldown(t: Array) -> float:
	return TOWER_BASE_COOLDOWN / (1.0 + t[4] * TOWER_ATTACK_SPEED_INCREMENT)

func _tower_crit_chance(t: Array) -> float:
	return minf(t[5] * CRIT_CHANCE_PER_TIER, CRIT_CHANCE_HARD_CAP)

func _tower_crit_mult(t: Array) -> float:
	return CRIT_DAMAGE_BASE + t[6] * CRIT_DAMAGE_PER_TIER

func _tower_multishot(t: Array) -> int:
	return mini(int(t[7]), MULTISHOT_HARD_CAP)

func _round_hp(round_num: int) -> float:
	if round_num <= MOB_HP_FLAT_ROUNDS:
		return MOB_BASE_HP
	return MOB_BASE_HP * pow(MOB_HP_GROWTH, round_num - MOB_HP_FLAT_ROUNDS)

func _initialize() -> void:
	# Run the same scenario across a few "rounds" so the pow()-based HP curve is
	# exercised (round 8 => non-trivial pow argument).
	var max_hp := _round_hp(8)

	# Mob state (parallel arrays for tight, allocation-free iteration).
	var mob_pos: Array[Vector2] = []
	var mob_idx: Array[int] = []       # path_index
	var mob_hp: Array[float] = []
	var spawned := 0

	# Projectile state.
	var proj_pos: Array[Vector2] = []
	var proj_tgt: Array[int] = []      # index into mob arrays
	var proj_dmg: Array[float] = []

	# Tower cooldowns.
	var cd: Array[float] = []
	for _i in range(TOWERS.size()):
		cd.append(0.0)

	# Sensitive accumulators — folded EVERY tick so a single flipped bit anywhere
	# propagates into the final fingerprint.
	var acc_damage := 0.0
	var acc_pos := 0.0
	var acc_hp := 0.0
	var total_kills := 0

	for tick in range(TICKS):
		# --- spawn (one mob per SPAWN_TICKS until supply is met) ---
		if spawned < MOB_COUNT and tick % SPAWN_TICKS == 0:
			mob_pos.append(PATH[0])
			mob_idx.append(1)
			mob_hp.append(max_hp)
			spawned += 1

		# --- towers fire (fixed index order => fixed draw order) ---
		for ti in range(TOWERS.size()):
			var t: Array = TOWERS[ti]
			cd[ti] = maxf(0.0, cd[ti] - DT)
			var tpos := Vector2(t[0], t[1])
			var rng := _tower_range(t)
			# Targets: alive mobs in range, furthest-along first (path_index desc).
			var in_range: Array[int] = []
			for mi in range(mob_pos.size()):
				if tpos.distance_to(mob_pos[mi]) <= rng:
					in_range.append(mi)
			in_range.sort_custom(func(a, b): return mob_idx[a] > mob_idx[b])
			var shots := 1 + _tower_multishot(t)
			if in_range.size() > shots:
				in_range = in_range.slice(0, shots)
			if cd[ti] > 0.0 or in_range.is_empty():
				continue
			for mi in in_range:
				var is_crit := _rng_randf() < _tower_crit_chance(t)
				var dmg := _tower_damage(t)
				if is_crit:
					dmg *= _tower_crit_mult(t)
				proj_pos.append(tpos)
				proj_tgt.append(mi)
				proj_dmg.append(dmg)
			cd[ti] = _tower_cooldown(t)

		# --- projectiles move + resolve (back-to-front so removals are safe) ---
		var pi := proj_pos.size() - 1
		while pi >= 0:
			var mi: int = proj_tgt[pi]
			var to_target := mob_pos[mi] - proj_pos[pi]
			var dist := to_target.length()
			var step := PROJECTILE_SPEED * DT
			if step >= dist:
				# hit: credited damage clamps at remaining hp (overkill not scored)
				var credited := minf(proj_dmg[pi], mob_hp[mi])
				mob_hp[mi] -= proj_dmg[pi]
				acc_damage += credited
				if mob_hp[mi] <= 0.0:
					mob_hp[mi] = max_hp   # respawn in place (per design)
					total_kills += 1
				# remove projectile (swap-pop)
				var last := proj_pos.size() - 1
				proj_pos[pi] = proj_pos[last]; proj_pos.remove_at(last)
				proj_tgt[pi] = proj_tgt[last]; proj_tgt.remove_at(last)
				proj_dmg[pi] = proj_dmg[last]; proj_dmg.remove_at(last)
			else:
				proj_pos[pi] = proj_pos[pi] + to_target.normalized() * step
			pi -= 1

		# --- mobs move along the path (loop at the exit to keep the sim hot) ---
		for mi in range(mob_pos.size()):
			var target := PATH[mob_idx[mi]]
			var to_target := target - mob_pos[mi]
			var step := MOB_SPEED * DT
			if step >= to_target.length():
				mob_pos[mi] = target
				mob_idx[mi] += 1
				if mob_idx[mi] >= PATH.size():
					mob_pos[mi] = PATH[0]
					mob_idx[mi] = 1
			else:
				mob_pos[mi] = mob_pos[mi] + to_target.normalized() * step

		# --- fold sensitive state into the fingerprint every tick ---
		for mi in range(mob_pos.size()):
			acc_pos += mob_pos[mi].x + mob_pos[mi].y
			acc_hp += mob_hp[mi]

	_report(acc_damage, acc_pos, acc_hp, total_kills)
	quit()

# Raw 8 bytes of a double (every mantissa bit preserved — printing a float rounds).
func _bytes64(x: float) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return b

# Big-endian hex of a byte buffer (stable to read/diff).
func _hex(b: PackedByteArray) -> String:
	var s := ""
	for i in range(b.size() - 1, -1, -1):
		s += "%02x" % b[i]
	return s

func _report(acc_damage: float, acc_pos: float, acc_hp: float, total_kills: int) -> void:
	var b_dmg := _bytes64(acc_damage)
	var b_pos := _bytes64(acc_pos)
	var b_hp := _bytes64(acc_hp)
	# Combined fingerprint: XOR the three byte-buffers (no int parsing => no sign
	# overflow), then fold total_kills into the low bytes. One line to diff.
	var combined := PackedByteArray()
	combined.resize(8)
	for i in range(8):
		combined[i] = b_dmg[i] ^ b_pos[i] ^ b_hp[i]
	combined[0] = combined[0] ^ (total_kills & 0xFF)
	combined[1] = combined[1] ^ ((total_kills >> 8) & 0xFF)
	print("=== FLOAT PROBE RESULT ===")
	print("ticks=%d mobs=%d towers=%d" % [TICKS, MOB_COUNT, TOWERS.size()])
	print("acc_damage  = %.6f  bits=%s" % [acc_damage, _hex(b_dmg)])
	print("acc_pos     = %.6f  bits=%s" % [acc_pos, _hex(b_pos)])
	print("acc_hp      = %.6f  bits=%s" % [acc_hp, _hex(b_hp)])
	print("total_kills = %d" % total_kills)
	print("COMBINED    = %s" % _hex(combined))
	print("=== END ===")
