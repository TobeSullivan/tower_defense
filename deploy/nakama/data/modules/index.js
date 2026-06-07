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

// --- Forming lobby (matchmaking_orchestration.md) ---
var LOBBY_MODULE = "lobby";
var LOBBY_MAX = 8;     // auto-launch (no vote) when the lobby fills to this
var LOBBY_FLOOR = 4;   // minimum present before a launch vote is allowed
// The Godot match server clients connect to after launch (same box, UDP). Override per deploy.
var MATCH_SERVER_HOST = "5.78.110.182";
var MATCH_SERVER_PORT = 8771;
// Lobby match op codes.
var OP_VOTE = 1;          // C->S: vote to launch now
var OP_LOBBY_STATE = 2;   // S->C: { count, max, floor, mode, present:[], voted:[] }
var OP_GO = 3;            // S->C: { match_id, host, port } — go join the Godot room

function InitModule(ctx, logger, nk, initializer) {
	_ensureCampaignBoards(logger, nk);
	_ensureRankedBoard(logger, nk);
	_ensureTrialsTournaments(logger, nk);
	initializer.registerRpc("submit_score", rpcSubmitScore);
	// Forming lobby: an authoritative "lobby" match accretes matchmaker pops up to 8, runs the
	// vote, then points everyone at a Godot match-server room (notes/matchmaking_orchestration.md).
	initializer.registerMatch(LOBBY_MODULE, {
		matchInit: lobbyInit, matchJoinAttempt: lobbyJoinAttempt, matchJoin: lobbyJoin,
		matchLeave: lobbyLeave, matchLoop: lobbyLoop, matchTerminate: lobbyTerminate,
		matchSignal: lobbySignal,
	});
	initializer.registerMatchmakerMatched(matchmakerMatched);
	logger.info("Wend runtime loaded: campaign + ranked + %d Trials tournaments + submit_score RPC + lobby match",
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

// ---------------------------------------------------------------------------
// Forming-lobby authoritative match + matchmaker routing (orchestration spine).
// Authority stays in the Godot match server; this lobby only forms the group and then hands
// everyone a (match_id, host, port) to join there. Accreting model: each matchmaker pop joins
// the SAME open lobby for its mode until it locks (8, or a unanimous-of-present vote at 4–7).
// ---------------------------------------------------------------------------

// Matchmaker pop → route into an OPEN lobby for the mode (accretion), else create one.
function matchmakerMatched(ctx, logger, nk, matches) {
	var mode = "ranked";
	if (matches.length > 0 && matches[0].properties && matches[0].properties.mode) {
		mode = matches[0].properties.mode;
	}
	try {
		var open = nk.matchList(1, true, "", null, null, "+label.mode:" + mode + " +label.open:1");
		if (open.length > 0) {
			logger.info("matchmaker → existing lobby %s (mode %s)", open[0].matchId, mode);
			return open[0].matchId;
		}
	} catch (e) {
		logger.warn("matchList failed: %s", (e && e.message) || e);
	}
	return nk.matchCreate(LOBBY_MODULE, { mode: mode });
}

function lobbyInit(ctx, logger, nk, params) {
	var mode = (params && params.mode) ? params.mode : "ranked";
	var state = { mode: mode, presences: {}, votes: {}, launched: false };
	return { state: state, tickRate: 2, label: JSON.stringify({ mode: mode, open: 1 }) };
}

function lobbyJoinAttempt(ctx, logger, nk, dispatcher, tick, state, presence, metadata) {
	if (state.launched || _lobbyCount(state) >= LOBBY_MAX) {
		return { state: state, accept: false, rejectMessage: "lobby full or already launched" };
	}
	return { state: state, accept: true };
}

function lobbyJoin(ctx, logger, nk, dispatcher, tick, state, presences) {
	for (var i = 0; i < presences.length; i++) state.presences[presences[i].userId] = presences[i];
	_lobbyBroadcast(dispatcher, state);
	if (_lobbyCount(state) >= LOBBY_MAX) _lobbyLaunch(dispatcher, nk, state, logger);  // auto at 8
	_lobbyRelabel(dispatcher, state);
	return { state: state };
}

function lobbyLeave(ctx, logger, nk, dispatcher, tick, state, presences) {
	for (var i = 0; i < presences.length; i++) {
		delete state.presences[presences[i].userId];
		delete state.votes[presences[i].userId];
	}
	if (_lobbyCount(state) === 0) return null;  // empty → terminate
	if (!state.launched) _lobbyBroadcast(dispatcher, state);
	_lobbyRelabel(dispatcher, state);
	return { state: state };
}

function lobbyLoop(ctx, logger, nk, dispatcher, tick, state, messages) {
	if (state.launched) return null;  // GO was sent last tick → tear the lobby down now
	var changed = false;
	for (var i = 0; i < messages.length; i++) {
		if (messages[i].opCode === OP_VOTE) {
			state.votes[messages[i].sender.userId] = true;
			changed = true;
		}
	}
	if (changed) {
		_lobbyBroadcast(dispatcher, state);
		_lobbyMaybeVoteLaunch(dispatcher, nk, state, logger);
	}
	return { state: state };
}

function lobbySignal(ctx, logger, nk, dispatcher, tick, state, data) { return { state: state, data: data }; }
function lobbyTerminate(ctx, logger, nk, dispatcher, tick, state, graceSeconds) { return { state: state }; }

function _lobbyCount(state) { return Object.keys(state.presences).length; }

function _lobbyBroadcast(dispatcher, state) {
	var present = Object.keys(state.presences);
	var voted = Object.keys(state.votes);
	dispatcher.broadcastMessage(OP_LOBBY_STATE, JSON.stringify({
		count: present.length, max: LOBBY_MAX, floor: LOBBY_FLOOR,
		mode: state.mode, present: present, voted: voted }), null, null);
}

// Unanimous-of-present at floor..max-1: every present player must have voted yes (abstain = no).
function _lobbyMaybeVoteLaunch(dispatcher, nk, state, logger) {
	var present = Object.keys(state.presences);
	if (present.length < LOBBY_FLOOR) return;
	for (var i = 0; i < present.length; i++) {
		if (!state.votes[present[i]]) return;
	}
	_lobbyLaunch(dispatcher, nk, state, logger);
}

function _lobbyLaunch(dispatcher, nk, state, logger) {
	if (state.launched) return;
	state.launched = true;
	var matchId = nk.uuidv4();
	dispatcher.broadcastMessage(OP_GO, JSON.stringify({
		match_id: matchId, host: MATCH_SERVER_HOST, port: MATCH_SERVER_PORT }), null, null);
	dispatcher.matchLabelUpdate(JSON.stringify({ mode: state.mode, open: 0 }));
	logger.info("lobby launched: room=%s players=%d", matchId, _lobbyCount(state));
}

function _lobbyRelabel(dispatcher, state) {
	var open = (!state.launched && _lobbyCount(state) < LOBBY_MAX) ? 1 : 0;
	dispatcher.matchLabelUpdate(JSON.stringify({ mode: state.mode, open: open }));
}

// Goja discovers InitModule in global scope after evaluating this file.
!InitModule && InitModule.bind(null);
