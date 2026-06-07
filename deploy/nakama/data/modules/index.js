// Wend Nakama runtime module (JS / goja). Plain JS — no build step, loaded directly via
// --runtime.js_entrypoint index.js. Owns the leaderboard/tournament topology from
// notes/leaderboard_schema.md and the authoritative score-submit RPC.
//
// Boards are AUTHORITATIVE (clients cannot write directly) — scores go through the
// submit_score RPC, which writes server-side and stashes the match record for later
// re-sim re-validation (notes/resim_contract.md). For the closed beta the RPC trusts the
// client's re-sim-derived score (the client already runs the authoritative re-sim); the
// record blob it stores is the real wire format, so adding the re-sim worker later is
// additive, not a rewrite ("no disposable intermediates", STATE.md).

var SCALES = ["thread", "weave", "tangle", "snarl", "knot"];
var GROUPS = ["solo", "duo", "trio", "quad"];
// window id -> { cron: reset schedule (UTC), duration: seconds active per cycle }.
// UTC anchors per leaderboard_schema.md §5.1. Duration spans the cycle so the board stays
// live until the cron reset (monthly padded to 32d to bridge to the 1st).
var WINDOWS = {
	daily:   { cron: "0 0 * * *", duration: 86400 },
	weekly:  { cron: "0 0 * * 1", duration: 604800 },
	monthly: { cron: "0 0 1 * *", duration: 2764800 },
};
var CAMPAIGN_MISSIONS = 5;     // matches SceneManager.CAMPAIGN_MISSION_COUNT (was 10)
var CURRENT_SEASON = 1;        // ranked_s<N>; bump on season roll
var RECORD_COLLECTION = "match_records";  // storage collection for re-sim re-validation

function InitModule(ctx, logger, nk, initializer) {
	_ensureCampaignBoards(logger, nk);
	_ensureRankedBoard(logger, nk);
	_ensureTrialsTournaments(logger, nk);
	initializer.registerRpc("submit_score", rpcSubmitScore);
	logger.info("Wend runtime loaded: campaign + ranked + %d Trials tournaments + submit_score RPC",
		SCALES.length * GROUPS.length * Object.keys(WINDOWS).length);
}

// --- Board creation (idempotent: a re-create on restart throws "already exists", caught) ---

function _ensureCampaignBoards(logger, nk) {
	// All-time, no reset, exempt from balance-patch resets (schema §2). Damage, best, desc.
	for (var m = 1; m <= CAMPAIGN_MISSIONS; m++) {
		var id = "campaign_m" + (m < 10 ? "0" + m : "" + m);
		_create(logger, function () {
			nk.leaderboardCreate(id, true, "desc", "best", "", { mode: "campaign", mission: m });
		}, "leaderboard " + id);
	}
}

function _ensureRankedBoard(logger, nk) {
	// One continuous tiered ladder per season (schema §4). Sort key = tier_base + LP, so
	// operator "set" (current authoritative value), desc. Bands derived from value ranges.
	var id = "ranked_s" + CURRENT_SEASON;
	_create(logger, function () {
		nk.leaderboardCreate(id, true, "desc", "set", "", { mode: "ranked", season: CURRENT_SEASON });
	}, "leaderboard " + id);
}

function _ensureTrialsTournaments(logger, nk) {
	// 60 ephemeral tournaments: window x scale x group (schema §3). Damage, best, desc,
	// authoritative, no join required (write without explicit join). Reset purges the cycle.
	for (var w in WINDOWS) {
		var cfg = WINDOWS[w];
		for (var s = 0; s < SCALES.length; s++) {
			for (var g = 0; g < GROUPS.length; g++) {
				var id = "trials_" + w + "_" + SCALES[s] + "_" + GROUPS[g];
				var title = "Trials " + w + " " + SCALES[s] + " " + GROUPS[g];
				(function (id, cron, duration, title) {
					_create(logger, function () {
						nk.tournamentCreate(
							id, true, "desc", "best",
							duration, cron, {},          // duration, resetSchedule, metadata
							title, "", 0,                 // title, description, category
							0, 0,                         // startTime, endTime (0 = open)
							0, 0,                         // maxSize, maxNumScore (0 = unlimited)
							false                         // joinRequired
						);
					}, "tournament " + id);
				})(id, cfg.cron, cfg.duration, title);
			}
		}
	}
}

function _create(logger, fn, label) {
	try {
		fn();
		logger.info("created %s", label);
	} catch (e) {
		// Already exists (the common case on restart) or a real error — log and continue so
		// one bad board never blocks the rest.
		logger.info("skip %s (%s)", label, e.message || e);
	}
}

// --- Authoritative score submit ---------------------------------------------
// payload: { kind: "trials"|"campaign"|"ranked", board_id, score, subscore?, record? (b64) }
// Writes the score server-side (boards are authoritative) and stores the record blob keyed by
// (user, board, time) for the later re-sim worker. Returns the written record's rank info.
function rpcSubmitScore(ctx, logger, nk, payload) {
	if (!ctx.userId) throw errPermission("must be authenticated");
	var req;
	try { req = JSON.parse(payload); } catch (e) { throw errInvalid("payload must be JSON"); }
	var boardId = req.board_id;
	var score = req.score | 0;
	var subscore = (req.subscore | 0) || 0;
	if (!boardId || typeof boardId !== "string") throw errInvalid("board_id required");
	if (score < 0) throw errInvalid("score must be >= 0");

	var username = ctx.username || "";
	var meta = { submitted_unix: Math.floor(Date.now() / 1000) };

	if (req.kind === "trials") {
		nk.tournamentRecordWrite(boardId, ctx.userId, username, score, subscore, meta, "best");
	} else {
		// campaign + ranked are leaderboards; ranked uses "set", the rest "best".
		var op = req.kind === "ranked" ? "set" : "best";
		nk.leaderboardRecordWrite(boardId, ctx.userId, username, score, subscore, meta, op);
	}

	// Stash the match record for async re-validation (re-sim worker reads these later).
	if (req.record) {
		var key = boardId + "_" + meta.submitted_unix;
		nk.storageWrite([{
			collection: RECORD_COLLECTION, key: key, userId: ctx.userId,
			value: { board_id: boardId, kind: req.kind, score: score, record_b64: req.record },
			permissionRead: 0, permissionWrite: 0,  // server-only
		}]);
	}
	return JSON.stringify({ ok: true, board_id: boardId, score: score });
}

function errInvalid(msg) { return { message: msg, code: 3 }; }       // INVALID_ARGUMENT
function errPermission(msg) { return { message: msg, code: 7 }; }    // PERMISSION_DENIED

// Goja discovers InitModule in global scope after evaluating this file.
!InitModule && InitModule.bind(null);
