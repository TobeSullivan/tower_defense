extends RefCounted
class_name GhostLadder

# In-match "next score to beat" model for Trials (notes/ghost_ladder.md).
# Merges the named tier thresholds and a leaderboard snapshot into ONE ascending
# ladder of score-targets, then drives four display states as the live score climbs:
#   1. NAMED_TIER — below gold: next of Bronze / Silver / Gold (baked into the map)
#   2. GHOST      — above gold: the next snapshot score above you, shown with its name
#   3. YOUR_BEST  — no ghosts left (dead board, or you passed them all): your prior best
#   4. TOP        — snapshot cleared: nothing left to chase
#
# It is a SNAPSHOT (a racing-game ghost car, not the live board): the targets are fixed
# for the whole run, so a rung never moves away mid-run. It NEVER asserts a live rank —
# only "NEXT: <score>" / "TOP" / your own score. The live-rank reveal happens on the
# result screen alone (the ghost model is what makes that honest).

enum State { NAMED_TIER, GHOST, YOUR_BEST, TOP }

# Named-tier rungs (the map's campaign/PVE thresholds). Below gold the ladder uses these.
var bronze: int = 0
var silver: int = 0
var gold: int = 0

# Snapshot of leaderboard scores for this (map, window, group-size) board, captured once
# at match start. Each entry: {"name": String, "score": int}. Above gold the ladder climbs
# these ascending. Empty on a dead board / before the backend is wired (see fetch_snapshot).
var ghosts: Array = []

# The player's own previous best on this board — the population-independent fallback so a
# dead board still gives you something to chase.
var own_best: int = 0

# Ghost entries strictly above gold, sorted ascending by score (cached by setup()).
var _ghost_rungs: Array = []

func setup(bronze_t: int, silver_t: int, gold_t: int, ghost_list: Array, best: int) -> void:
	bronze = bronze_t
	silver = silver_t
	gold = gold_t
	own_best = best
	ghosts = ghost_list.duplicate(true)
	# Only ghosts above gold are rungs; below gold the named tiers own the ladder.
	_ghost_rungs = []
	for g in ghosts:
		if int(g.get("score", 0)) > gold:
			_ghost_rungs.append(g)
	_ghost_rungs.sort_custom(func(a, b): return int(a["score"]) < int(b["score"]))

# The current target for a live score. Returns:
#   {"state", "target" (int; 0 for TOP), "label" (badge text), "name" (ghost name or "")}
func target_for(score: int) -> Dictionary:
	# State 1 — below gold: climb the named tiers in order.
	if gold > 0 and score < gold:
		if bronze > 0 and score < bronze:
			return {"state": State.NAMED_TIER, "target": bronze, "label": "Bronze", "name": ""}
		if silver > 0 and score < silver:
			return {"state": State.NAMED_TIER, "target": silver, "label": "Silver", "name": ""}
		return {"state": State.NAMED_TIER, "target": gold, "label": "Gold", "name": ""}
	# State 2 — above gold: the next ghost score strictly above you.
	for g in _ghost_rungs:
		if int(g["score"]) > score:
			return {"state": State.GHOST, "target": int(g["score"]), "label": "GHOST", "name": str(g["name"])}
	# State 3 — no ghosts left: your own previous best, if it's still ahead.
	if own_best > score:
		return {"state": State.YOUR_BEST, "target": own_best, "label": "YOUR BEST", "name": ""}
	# State 4 — cleared everything.
	return {"state": State.TOP, "target": 0, "label": "TOP", "name": ""}

# Optional "passed N this run" counter — how many ladder rungs the live score has cleared
# (named tiers below gold + every ghost rung). notes/ghost_ladder.md, optional secondary.
func passed(score: int) -> int:
	var n := 0
	for t in [bronze, silver, gold]:
		if t > 0 and score >= t:
			n += 1
	for g in _ghost_rungs:
		if score >= int(g["score"]):
			n += 1
	return n

# Total rungs in the merged ladder (named tiers present + ghost rungs). Lets the caller
# show "N / TOTAL passed" without reaching into internals.
func rung_count() -> int:
	var n := 0
	for t in [bronze, silver, gold]:
		if t > 0:
			n += 1
	return n + _ghost_rungs.size()

# --- Snapshot source ---------------------------------------------------------
# The real snapshot is ONE cached leaderboard read fanned out per (map, window, group-size)
# at match start (notes/ghost_ladder.md) — population-independent, not a per-player query.
# No backend is wired yet, so this returns an empty list and the ladder falls through to
# YOUR BEST / TOP (correct, population-independent behavior). When Nakama lands, return the
# cached snapshot here; the GHOST state then lights up with zero changes elsewhere.
static func fetch_snapshot(_map) -> Array:
	return []
