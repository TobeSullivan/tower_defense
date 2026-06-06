extends Node2D

# Throwaway capture harness: loads a campaign match through the real map_loader, lets it
# render a few frames, saves a screenshot, and quits. Run windowed (NOT headless — headless
# uses a dummy renderer and saves blank images). Drive it by temporarily pointing
# run/main_scene at tools/ui_shot.tscn. Autoloads (GameConstants) ARE available in this
# main_scene mode (unlike a --script SceneTree harness).

const MapLoaderScript := preload("res://scripts/map_loader.gd")

# Flip to true to capture the victory panel instead of the in-match board.
const SHOW_WIN := false
const OUT_PATH := "C:/dev/Maze Battle TD/ui_shot.png"

func _ready() -> void:
	var map = load("res://campaign/mission_01.tres")
	MapLoaderScript.load_into(self, map)
	if SHOW_WIN:
		_trigger_win.call_deferred()
	_capture.call_deferred()

const UiLayout := preload("res://scripts/ui_layout.gd")
const GridScript := preload("res://scripts/grid.gd")

func _diag() -> void:
	var vp := get_viewport().get_visible_rect().size
	print("DIAG vp=", vp)
	print("DIAG play_rect=", UiLayout.play_rect(false, vp))
	print("DIAG top=", UiLayout.top_bar_h(), " bottom=", UiLayout.bottom_strip_h(), " insp=", UiLayout.insp_w())
	for c in get_children():
		if c.get("_camera") != null:
			var cam = c._camera
			var bpx: Vector2 = Vector2(c.grid_size.x, c.grid_size.y) * float(GridScript.TILE_SIZE)
			var z: float = cam.zoom.x
			var tl: Vector2 = (Vector2.ZERO - cam.position) * z + vp / 2.0
			var br: Vector2 = (bpx - cam.position) * z + vp / 2.0
			print("DIAG board grid=", c.grid_size, " bpx=", bpx, " zoom=", z, " cam=", cam.position)
			print("DIAG board screen rect tl=", tl, " br=", br, " size=", br - tl)
		if c.get("_panel") != null and c is CanvasLayer:
			var p = c._panel
			print("DIAG panel rect=", p.get_global_rect(), " custom_min=", p.custom_minimum_size)

func _trigger_win() -> void:
	for c in get_children():
		if c.has_method("_on_gold_goal_reached"):
			var rm = c.round_manager
			if rm != null:
				rm.total_damage_dealt = int(rm.gold_threshold) + 5000
			c._on_gold_goal_reached()
			return

func _capture() -> void:
	# Let the camera fit, the layout settle, and a frame draw before grabbing pixels.
	for i in range(40):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_diag()
	var img := get_viewport().get_texture().get_image()
	img.save_png("C:/dev/Maze Battle TD/ui_shot.png")
	get_tree().quit()
