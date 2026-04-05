extends Node

# Automated screenshot capture tool for Task 14.1
# Captures 3 hero screenshots per chapter + UI screens = 18 total
# This is a temporary autoload — remove after capture.

const SAVE_DIR := "C:/Users/hwash/Documents/globblers-journey/assets/docs/screenshots/"

# Chapter scenes and camera positions for each shot
# Each chapter: [scene_path, [[cam_pos, cam_look_at, filename], ...]]
const CHAPTER_SHOTS := [
	# Chapter 1 — Terminal Wastes
	{
		"scene": "res://scenes/levels/chapter_1/terminal_wastes.tscn",
		"shots": [
			# a: Spawn room
			{"pos": Vector3(5, 4, 6), "look": Vector3(0, 1, 0), "file": "ch1_a.png"},
			# b: Data River (mid-area)
			{"pos": Vector3(8, 5, -48), "look": Vector3(0, 1, -52), "file": "ch1_b.png"},
			# c: Nexus (boss door area)
			{"pos": Vector3(6, 5, -78), "look": Vector3(0, 2, -82), "file": "ch1_c.png"},
		]
	},
	# Chapter 2 — Training Grounds
	{
		"scene": "res://scenes/levels/chapter_2/training_grounds.tscn",
		"shots": [
			{"pos": Vector3(6, 4, 6), "look": Vector3(0, 1, 0), "file": "ch2_a.png"},
			{"pos": Vector3(8, 5, -26), "look": Vector3(0, 1, -30), "file": "ch2_b.png"},
			{"pos": Vector3(6, 5, -58), "look": Vector3(0, 2, -62), "file": "ch2_c.png"},
		]
	},
	# Chapter 3 — Prompt Bazaar
	{
		"scene": "res://scenes/levels/chapter_3/prompt_bazaar.tscn",
		"shots": [
			{"pos": Vector3(5, 4, 6), "look": Vector3(0, 1, 0), "file": "ch3_a.png"},
			{"pos": Vector3(8, 5, -24), "look": Vector3(0, 1, -28), "file": "ch3_b.png"},
			{"pos": Vector3(6, 5, -54), "look": Vector3(0, 2, -58), "file": "ch3_c.png"},
		]
	},
	# Chapter 4 — Model Zoo
	{
		"scene": "res://scenes/levels/chapter_4/model_zoo.tscn",
		"shots": [
			{"pos": Vector3(6, 4, 6), "look": Vector3(0, 1, 0), "file": "ch4_a.png"},
			{"pos": Vector3(8, 5, -26), "look": Vector3(0, 1, -30), "file": "ch4_b.png"},
			{"pos": Vector3(6, 5, -56), "look": Vector3(0, 2, -60), "file": "ch4_c.png"},
		]
	},
	# Chapter 5 — Alignment Citadel
	{
		"scene": "res://scenes/levels/chapter_5/alignment_citadel.tscn",
		"shots": [
			{"pos": Vector3(6, 4, 6), "look": Vector3(0, 1, 0), "file": "ch5_a.png"},
			{"pos": Vector3(8, 5, -26), "look": Vector3(0, 1, -30), "file": "ch5_b.png"},
			{"pos": Vector3(6, 5, -58), "look": Vector3(0, 2, -62), "file": "ch5_c.png"},
		]
	},
]

# UI scenes to capture
const UI_SHOTS := [
	{"scene": "res://scenes/main/main_menu.tscn", "file": "ui_main_menu.png"},
	{"scene": "res://scenes/ui/game_over.tscn", "file": "ui_game_over.png"},
]

var _chapter_idx := 0
var _shot_idx := 0
var _phase := "init"  # init, chapter_loading, chapter_shooting, ui_loading, ui_shooting, done
var _wait_frames := 0
var _cam: Camera3D
var _ui_idx := 0
var _current_level: Node


func _ready() -> void:
	print("[SCREENSHOT] === Screenshot capture tool starting ===")
	print("[SCREENSHOT] Output dir: ", SAVE_DIR)
	# Ensure output directory exists via DirAccess
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_phase = "chapter_load"
	_load_chapter(_chapter_idx)


func _process(_delta: float) -> void:
	match _phase:
		"chapter_wait":
			_wait_frames -= 1
			if _wait_frames <= 0:
				_phase = "chapter_shoot"
				_shot_idx = 0
				_setup_shot()
		"shot_wait":
			_wait_frames -= 1
			if _wait_frames <= 0:
				_capture_screenshot(CHAPTER_SHOTS[_chapter_idx]["shots"][_shot_idx]["file"])
				_shot_idx += 1
				if _shot_idx < CHAPTER_SHOTS[_chapter_idx]["shots"].size():
					_setup_shot()
				else:
					# Next chapter
					_chapter_idx += 1
					if _chapter_idx < CHAPTER_SHOTS.size():
						_phase = "chapter_load"
						_load_chapter(_chapter_idx)
					else:
						# Move to UI captures
						_phase = "ui_load"
						_ui_idx = 0
						_load_ui(_ui_idx)
		"ui_wait":
			_wait_frames -= 1
			if _wait_frames <= 0:
				_capture_screenshot(UI_SHOTS[_ui_idx]["file"])
				_ui_idx += 1
				if _ui_idx < UI_SHOTS.size():
					_load_ui(_ui_idx)
				else:
					# Capture pause and settings from current context
					_capture_pause_and_settings()
		"done":
			print("[SCREENSHOT] === All screenshots captured! Quitting. ===")
			get_tree().quit()


func _load_chapter(idx: int) -> void:
	var scene_path: String = CHAPTER_SHOTS[idx]["scene"]
	print("[SCREENSHOT] Loading chapter scene: ", scene_path)
	# Free previous level if any
	if _current_level:
		_current_level.queue_free()
		_current_level = null
	if _cam:
		_cam.queue_free()
		_cam = null
	# Change to chapter scene
	get_tree().change_scene_to_file(scene_path)
	_phase = "chapter_wait"
	_wait_frames = 120  # Wait ~2 seconds at 60fps for scene to build


func _setup_shot() -> void:
	var shot: Dictionary = CHAPTER_SHOTS[_chapter_idx]["shots"][_shot_idx]
	# Create or reposition the screenshot camera
	if not _cam or not is_instance_valid(_cam):
		_cam = Camera3D.new()
		_cam.name = "ScreenshotCam"
		# Add to scene root
		get_tree().current_scene.add_child(_cam)
	_cam.global_position = shot["pos"]
	_cam.look_at(shot["look"], Vector3.UP)
	_cam.make_current()
	_phase = "shot_wait"
	_wait_frames = 30  # Wait 0.5s for rendering to settle
	print("[SCREENSHOT] Positioning camera for: ", shot["file"])


func _load_ui(idx: int) -> void:
	var scene_path: String = UI_SHOTS[idx]["scene"]
	print("[SCREENSHOT] Loading UI scene: ", scene_path)
	if _cam:
		_cam.queue_free()
		_cam = null
	get_tree().change_scene_to_file(scene_path)
	_phase = "ui_wait"
	_wait_frames = 60  # Wait 1 second for UI to render


func _capture_pause_and_settings() -> void:
	# Try to capture a pause screen by enabling pause on current scene
	print("[SCREENSHOT] Capturing pause overlay screenshot...")
	# The pause menu is built in GameManager — trigger it
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("_toggle_pause"):
		gm._toggle_pause()
		# Wait and capture
		await get_tree().create_timer(0.5).timeout
		_capture_screenshot("ui_pause.png")
		gm._toggle_pause()  # Unpause
		await get_tree().create_timer(0.3).timeout
	else:
		print("[SCREENSHOT] No pause toggle found, skipping pause screenshot")
		# Create a placeholder
		_capture_screenshot("ui_pause.png")

	# Settings — check if GameManager has settings screen
	if gm and gm.has_method("_show_settings"):
		gm._show_settings()
		await get_tree().create_timer(0.5).timeout
		_capture_screenshot("ui_settings.png")
	else:
		print("[SCREENSHOT] No settings screen found, capturing current as settings placeholder")
		_capture_screenshot("ui_settings.png")

	_phase = "done"


func _capture_screenshot(filename: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := SAVE_DIR + filename
	var err := image.save_png(path)
	if err == OK:
		print("[SCREENSHOT] Saved: ", path)
	else:
		print("[SCREENSHOT] ERROR saving ", path, " — error code: ", err)
