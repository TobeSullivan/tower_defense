extends RefCounted
class_name RankedLadder

# The Ranked LP / MMR engine (notes/pvp_ladder.md). Pure, static, store-independent — the
# match-end panel calls resolve() with the local player's pre-match state + their placement
# and gets back the new ladder value, the new hidden MMR, and everything the result screen
# (Surface 2) needs to render.
#
# Model: MMR-anchored net-positive (the TFT model). A visible LP that feels generous low on
# the ladder (retention for a small pool) but behaves honestly / zero-sum at the top (Masters
# integrity). The single sort key is the LADDER VALUE = tier_base + LP (leaderboard_schema.md
# §4), so tier promotions/demotions are implicit in the value and tier math is shared with
# LeaderboardService (ranked_tier / RANKED_BANDS) — no duplication.
#
# EVERY number below is a playtest DIAL (pvp_ladder.md "Playtest dials"); only the structural
# shape is locked — steep-extremes placement curve, MMR amplify/dampen, two-phase climb
# (net-positive Stone→Gold, honest/uncapped Masters), stickiness floors below Masters.

const LeaderboardService := preload("res://scripts/leaderboard_service.gd")

# Displayed LP per placement when your MMR ≈ the lobby average (symmetric, sums to ~0 at
# equilibrium — what stops the top of the ladder inflating). Index 0 = 1st … 7 = 8th.
const BASE_LP_8 := [45.0, 30.0, 18.0, 8.0, -8.0, -18.0, -30.0, -45.0]

# MMR engine (Elo-style, on the same 0..400+ scale as the ladder value so deficits are
# directly comparable). K = per-match swing; SCALE = the logistic/ factor width.
const MMR_K := 24.0
const MMR_SCALE := 400.0
const FACTOR_MIN := 0.5
const FACTOR_MAX := 1.5

# New-player seeds. Hidden MMR starts ~Silver-mid so a genuinely strong player's factor > 1
# and they climb fast (the "~15–20 games to your floor" feel); visible LP starts at Bronze 0.
const SEED_MMR := 150.0
const START_VALUE := 0

const MASTERS_BASE := 400   # value >= this == Masters: floors off, no demotion out, uncapped
const DEMOTE_LANDING_LP := 75  # demotion lands at 75 LP of the lower tier (anti-ping-pong buffer)

# Resolve one ranked result for the LOCAL player.
#   placement      1-based finish (1 = last standing / winner)
#   count          players in the match
#   value_before   the player's ladder value going in (tier_base + LP)
#   mmr_before     the player's hidden MMR going in
#   lobby_avg_mmr  the lobby's average hidden MMR (the net-positive anchor)
# Returns the full before/after picture for persistence + Surface 2.
static func resolve(placement: int, count: int, value_before: int, mmr_before: float, lobby_avg_mmr: float) -> Dictionary:
	var base := _base_lp(placement, count)
	var is_masters := value_before >= MASTERS_BASE

	# --- MMR factor: below your skill amplifies gains / dampens losses; above, the inverse.
	var deficit := lobby_avg_mmr - mmr_before
	var factor: float
	if base >= 0.0:
		factor = clampf(1.0 + deficit / MMR_SCALE, FACTOR_MIN, FACTOR_MAX)
	else:
		factor = clampf(1.0 - deficit / MMR_SCALE, FACTOR_MIN, FACTOR_MAX)
	var earned := int(round(base * factor))  # placement-driven LP, before stickiness/boundaries

	# --- Stickiness floors (OFF in Masters): top half never nets a loss, bottom half never a gain.
	# At count 8 this is exactly the locked "top 4 / bottom 4" rule.
	if not is_masters:
		var half := int(ceil(count / 2.0))
		if placement <= half:
			earned = maxi(0, earned)
		else:
			earned = mini(0, earned)

	# --- Apply + tier boundaries.
	var raw := value_before + earned
	var cur := LeaderboardService.ranked_tier(value_before)
	var cur_base := value_before - int(cur["lp"])
	var value_after: int
	if is_masters:
		value_after = maxi(MASTERS_BASE, raw)            # no demotion out of Masters mid-season
	elif raw < cur_base and cur_base > 0:
		value_after = maxi(0, cur_base - (100 - DEMOTE_LANDING_LP))  # demote → 75 LP of lower tier
	else:
		value_after = maxi(0, raw)

	# --- Hidden MMR update (Elo by placement vs the field).
	var expected := 1.0 / (1.0 + pow(10.0, (lobby_avg_mmr - mmr_before) / MMR_SCALE))
	var actual := 0.5 if count <= 1 else float(count - placement) / float(count - 1)
	var mmr_after := mmr_before + MMR_K * (actual - expected)

	var aft := LeaderboardService.ranked_tier(value_after)
	var bi_before := _band_index(value_before)
	var bi_after := _band_index(value_after)
	var nb := _next_band_above(value_after)
	return {
		"placement": placement, "count": count,
		"value_before": value_before, "value_after": value_after,
		"lp_delta": value_after - value_before,          # the true net move (what the player feels)
		"earned": earned,                                 # pre-boundary placement LP (final-order rows)
		"tier_before": String(cur["name"]), "tier_after": String(aft["name"]),
		"lp_before": int(cur["lp"]), "lp_after": int(aft["lp"]),
		"promoted": bi_after < bi_before,                 # bands are ordered high→low (Masters=0)
		"demoted": bi_after > bi_before,
		"is_masters": value_after >= MASTERS_BASE,
		"to_next": int(nb["base"]) - value_after if not nb.is_empty() else 0,
		"next_tier": String(nb["name"]) if not nb.is_empty() else "",
		"mmr_before": mmr_before, "mmr_after": mmr_after,
	}

# Public per-placement base LP (no MMR factor) — used to show the OTHER players' rows on the
# final-order list (we only know our own MMR). Rounded to an int.
static func base_lp(placement: int, count: int) -> int:
	return int(round(_base_lp(placement, count)))

# Placement → base LP. At count 8 it indexes the curve directly; for a smaller lobby it
# percentile-maps onto the same curve so 1st is always +45 and last always −45 (LP independent
# of lobby size — open_items lock), interpolating the middle.
static func _base_lp(placement: int, count: int) -> float:
	var p := clampi(placement, 1, maxi(count, 1))
	if count >= 8:
		return BASE_LP_8[clampi(p - 1, 0, 7)]
	if count <= 1:
		return BASE_LP_8[0]
	var pos := float(p - 1) / float(count - 1) * 7.0   # 0 (1st) .. 7 (last)
	var lo := int(floor(pos))
	var hi := mini(lo + 1, 7)
	return lerpf(BASE_LP_8[lo], BASE_LP_8[hi], pos - lo)

# Index into RANKED_BANDS for the band holding `value` (0 = Masters … 4 = Bronze; lower = higher tier).
static func _band_index(value: int) -> int:
	for i in range(LeaderboardService.RANKED_BANDS.size()):
		if value >= int(LeaderboardService.RANKED_BANDS[i]["base"]):
			return i
	return LeaderboardService.RANKED_BANDS.size() - 1

# Lowest band whose base is still above `value` = the next tier up. Empty at Masters.
static func _next_band_above(value: int) -> Dictionary:
	var best := {}
	for b in LeaderboardService.RANKED_BANDS:
		var base := int(b["base"])
		if base > value and (best.is_empty() or base < int(best["base"])):
			best = b
	return best
