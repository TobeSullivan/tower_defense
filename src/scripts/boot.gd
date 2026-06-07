extends Node

# Entry point (run/main_scene). Decides where the game opens:
#   - First ever launch: set the flag, drop straight into mission 1 (DESIGN_MODES
#     first-launch flow — no home screen, no mode select).
#   - Every launch after: open the home screen.
# The flag is set on first launch, NOT on mission completion, so quitting mission
# 1 immediately still counts as launched.

func _ready() -> void:
	# Defer: changing scene during _ready fails ("tree is busy setting up
	# children"). A deferred call runs once this scene is fully in the tree.
	_route.call_deferred()

func _route() -> void:
	# Dedicated headless server (godot --headless -- --server): host the lobby authority,
	# no UI, no player board. Every other launch is a normal client / solo game.
	if "--server" in OS.get_cmdline_user_args():
		SceneManager.start_dedicated_server()
		return
	# Bring the meta backend online (identity + leaderboards) in the background. Non-blocking:
	# on success it swaps LeaderboardService onto the NakamaBackend; until then surfaces show the
	# honest LocalBackend view. Only the real client boots through here — test scenes bypass it.
	if NakamaService.is_configured():
		NakamaService.connect_backend()
	if SaveData.is_first_launch():
		SaveData.mark_first_launch_done()
		if SceneManager.has_campaign_mission(1):
			SceneManager.start_campaign_mission(1)
			return
		# No mission authored — fall through to the home screen rather than crash.
	SceneManager.goto_home()
