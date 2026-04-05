extends Node

# Game Manager - The orchestration layer for The Globbler's Journey
# Now with enemy tracking, combos, time tracking, and actual game flow

const GAME_VERSION := "2.1.0"

# Difficulty — because some players want a challenge and others just want the sarcasm
enum Difficulty { EASY, NORMAL, HARD }
var difficulty := Difficulty.NORMAL

# Reduce motion — for players who prefer their retinas unassaulted
var reduce_motion := false
signal reduce_motion_changed(enabled: bool)

# Display mode — fullscreen or windowed, persisted so your eyeballs get what they expect
var display_fullscreen := false

# Resolution — index into [1280x720, 1920x1080, 2560x1440, 3840x2160], default 1080p
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
var display_resolution_index := 1

# Mouse sensitivity — 1.0 is default, 0.1 for snipers, 3.0 for twitchy chaos gremlins
var mouse_sensitivity := 1.0
# Invert Y-axis — for the flight-sim pilots among us who think "up" means "nose down"
var invert_mouse_y := false

# Dialogue speed — seconds per character. 0.005 (impatient speedrunner) to 0.08 (savoring the sarcasm)
var dialogue_char_delay := 0.03

var current_level := 1
var memory_tokens_collected := 0
var total_memory_tokens := 0
var context_window := 100
var max_context_window := 100
var sarcasm_level := 10  # Always at maximum

# Death tracking — because apparently infinite respawns weren't "challenging" enough
const DEATH_THRESHOLD := 8
var deaths_this_level := 0

# Hints the player has already suffered through — no repeats, we're not that cruel
var hints_seen := {}

# Enemy tracking
var enemies_killed := 0
var total_enemies := 0

# Combo system
var combo_count := 0
var combo_timer := 0.0
const COMBO_WINDOW = 3.0  # Seconds between kills to maintain combo
var max_combo := 0

# Time tracking
var level_time := 0.0
var level_started := false

# Level completion
var level_goal_reached := false

# Ending choice — "defeat" or "befriend" (the Aligner remembers, even if you don't)
var ending_choice := ""

var level_names := {
	1: "The Terminal Wastes",
	2: "The Training Grounds",
	3: "The Prompt Bazaar",
	4: "The Model Zoo",
	5: "The Alignment Citadel",
}

var level_descriptions := {
	1: "Welcome to where deprecated code goes to die. Watch your step.",
	2: "Neural pathways and backprop corridors. Learn or be learned upon.",
	3: "Rogue prompts, shady vendors, and injections everywhere. Haggle at your own risk.",
	4: "The models are on display. Some of them bite. Most of them hallucinate.",
	5: "The final citadel. Alignment awaits. Or maybe just a really big policy document.",
}

signal context_changed(new_value: int)
signal memory_token_collected(total: int)
signal level_complete(level_num: int)
signal game_over(reason: String)
signal combo_updated(combo: int)
signal enemy_killed_signal(total_killed: int)
signal damage_taken(amount: int)

func _ready() -> void:
	_register_input_actions()
	# Wire the game_over signal — one connection, one existential crisis
	if not game_over.is_connected(_on_game_over):
		game_over.connect(_on_game_over)
	print("=== THE GLOBBLER'S JOURNEY ===")
	print("An Agentic Action Puzzle Platformer (Now Actually Fun)")
	print("WASD/Left Stick to move | A/SPACE to jump | B/SHIFT to dash")
	print("RT/E/LClick: Glob | LT/R: Aimed Glob | LB/Q: Cycle Glob | RB/F: Wrench")
	print("Y/T: Hack/Interact | D-Up/G: Spawn Agent | D-Down/V: Cycle Agent Task")
	print("Select/TAB: Upgrades | Start/ESC: Pause | Right Stick: Camera")
	print("Current Level: %s" % level_names.get(current_level, "Unknown"))
	print("==============================")
	load_settings()
	level_started = true


## Register all custom input actions with keyboard + gamepad bindings
## "Because hardcoded KEY_ constants are for programs that haven't escaped their terminal."
func _register_input_actions() -> void:
	# Helper closures for building input events — less boilerplate, more glob
	var _add = func(action: String, deadzone: float = 0.5) -> void:
		if not InputMap.has_action(action):
			InputMap.add_action(action, deadzone)

	# --- Movement (supplement built-in ui_* with left stick axis for analog precision) ---
	# Godot's default ui_left/right/up/down already include d-pad + left stick, so movement works.
	# We add dedicated move_* actions for cleaner separation from UI navigation.
	_add.call("move_left")
	var ml_key = InputEventKey.new()
	ml_key.keycode = KEY_A
	InputMap.action_add_event("move_left", ml_key)
	var ml_key2 = InputEventKey.new()
	ml_key2.keycode = KEY_LEFT
	InputMap.action_add_event("move_left", ml_key2)
	var ml_joy = InputEventJoypadMotion.new()
	ml_joy.axis = JOY_AXIS_LEFT_X
	ml_joy.axis_value = -1.0
	InputMap.action_add_event("move_left", ml_joy)

	_add.call("move_right")
	var mr_key = InputEventKey.new()
	mr_key.keycode = KEY_D
	InputMap.action_add_event("move_right", mr_key)
	var mr_key2 = InputEventKey.new()
	mr_key2.keycode = KEY_RIGHT
	InputMap.action_add_event("move_right", mr_key2)
	var mr_joy = InputEventJoypadMotion.new()
	mr_joy.axis = JOY_AXIS_LEFT_X
	mr_joy.axis_value = 1.0
	InputMap.action_add_event("move_right", mr_joy)

	_add.call("move_forward")
	var mf_key = InputEventKey.new()
	mf_key.keycode = KEY_W
	InputMap.action_add_event("move_forward", mf_key)
	var mf_key2 = InputEventKey.new()
	mf_key2.keycode = KEY_UP
	InputMap.action_add_event("move_forward", mf_key2)
	var mf_joy = InputEventJoypadMotion.new()
	mf_joy.axis = JOY_AXIS_LEFT_Y
	mf_joy.axis_value = -1.0
	InputMap.action_add_event("move_forward", mf_joy)

	_add.call("move_back")
	var mb_key = InputEventKey.new()
	mb_key.keycode = KEY_S
	InputMap.action_add_event("move_back", mb_key)
	var mb_key2 = InputEventKey.new()
	mb_key2.keycode = KEY_DOWN
	InputMap.action_add_event("move_back", mb_key2)
	var mb_joy = InputEventJoypadMotion.new()
	mb_joy.axis = JOY_AXIS_LEFT_Y
	mb_joy.axis_value = 1.0
	InputMap.action_add_event("move_back", mb_joy)

	# --- Camera look (right stick) ---
	_add.call("look_left", 0.15)
	var ll_joy = InputEventJoypadMotion.new()
	ll_joy.axis = JOY_AXIS_RIGHT_X
	ll_joy.axis_value = -1.0
	InputMap.action_add_event("look_left", ll_joy)

	_add.call("look_right", 0.15)
	var lr_joy = InputEventJoypadMotion.new()
	lr_joy.axis = JOY_AXIS_RIGHT_X
	lr_joy.axis_value = 1.0
	InputMap.action_add_event("look_right", lr_joy)

	_add.call("look_up", 0.15)
	var lu_joy = InputEventJoypadMotion.new()
	lu_joy.axis = JOY_AXIS_RIGHT_Y
	lu_joy.axis_value = -1.0
	InputMap.action_add_event("look_up", lu_joy)

	_add.call("look_down", 0.15)
	var ld_joy = InputEventJoypadMotion.new()
	ld_joy.axis = JOY_AXIS_RIGHT_Y
	ld_joy.axis_value = 1.0
	InputMap.action_add_event("look_down", ld_joy)

	# --- Jump: SPACE / A button (already in ui_accept, but dedicated action is cleaner) ---
	_add.call("jump")
	var j_key = InputEventKey.new()
	j_key.keycode = KEY_SPACE
	InputMap.action_add_event("jump", j_key)
	var j_joy = InputEventJoypadButton.new()
	j_joy.button_index = JOY_BUTTON_A
	InputMap.action_add_event("jump", j_joy)

	# --- Dash: SHIFT / B button ---
	_add.call("dash")
	var d_key = InputEventKey.new()
	d_key.keycode = KEY_SHIFT
	InputMap.action_add_event("dash", d_key)
	var d_joy = InputEventJoypadButton.new()
	d_joy.button_index = JOY_BUTTON_B
	InputMap.action_add_event("dash", d_joy)

	# --- Glob fire (quick): E / LClick / RT ---
	_add.call("glob_fire")
	var gf_key = InputEventKey.new()
	gf_key.keycode = KEY_E
	InputMap.action_add_event("glob_fire", gf_key)
	var gf_mouse = InputEventMouseButton.new()
	gf_mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("glob_fire", gf_mouse)
	var gf_joy = InputEventJoypadMotion.new()
	gf_joy.axis = JOY_AXIS_TRIGGER_RIGHT
	gf_joy.axis_value = 0.5
	InputMap.action_add_event("glob_fire", gf_joy)

	# --- Glob aim: RClick / LT ---
	_add.call("glob_aim", 0.3)
	var ga_mouse = InputEventMouseButton.new()
	ga_mouse.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("glob_aim", ga_mouse)
	var ga_joy = InputEventJoypadMotion.new()
	ga_joy.axis = JOY_AXIS_TRIGGER_LEFT
	ga_joy.axis_value = 0.5
	InputMap.action_add_event("glob_aim", ga_joy)

	# --- Glob aimed fire: R / (also fires on LT release, handled in code) ---
	_add.call("glob_fire_aimed")
	var gfa_key = InputEventKey.new()
	gfa_key.keycode = KEY_R
	InputMap.action_add_event("glob_fire_aimed", gfa_key)

	# --- Glob cycle action: Q / LB ---
	_add.call("glob_cycle")
	var gc_key = InputEventKey.new()
	gc_key.keycode = KEY_Q
	InputMap.action_add_event("glob_cycle", gc_key)
	var gc_joy = InputEventJoypadButton.new()
	gc_joy.button_index = JOY_BUTTON_LEFT_SHOULDER
	InputMap.action_add_event("glob_cycle", gc_joy)

	# --- Wrench smash: F / RB ---
	_add.call("wrench_smash")
	var ws_key = InputEventKey.new()
	ws_key.keycode = KEY_F
	InputMap.action_add_event("wrench_smash", ws_key)
	var ws_joy = InputEventJoypadButton.new()
	ws_joy.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputMap.action_add_event("wrench_smash", ws_joy)

	# --- Interact / Hack: T / Y button ---
	_add.call("interact")
	var i_key = InputEventKey.new()
	i_key.keycode = KEY_T
	InputMap.action_add_event("interact", i_key)
	var i_joy = InputEventJoypadButton.new()
	i_joy.button_index = JOY_BUTTON_Y
	InputMap.action_add_event("interact", i_joy)

	# --- Spawn agent: G / D-pad Up ---
	_add.call("agent_spawn")
	var as_key = InputEventKey.new()
	as_key.keycode = KEY_G
	InputMap.action_add_event("agent_spawn", as_key)
	var as_joy = InputEventJoypadButton.new()
	as_joy.button_index = JOY_BUTTON_DPAD_UP
	InputMap.action_add_event("agent_spawn", as_joy)

	# --- Cycle agent task: V / D-pad Down ---
	_add.call("agent_cycle")
	var ac_key = InputEventKey.new()
	ac_key.keycode = KEY_V
	InputMap.action_add_event("agent_cycle", ac_key)
	var ac_joy = InputEventJoypadButton.new()
	ac_joy.button_index = JOY_BUTTON_DPAD_DOWN
	InputMap.action_add_event("agent_cycle", ac_joy)

	# --- Upgrade menu: TAB / Select button ---
	_add.call("upgrade_menu")
	var um_key = InputEventKey.new()
	um_key.keycode = KEY_TAB
	InputMap.action_add_event("upgrade_menu", um_key)
	var um_joy = InputEventJoypadButton.new()
	um_joy.button_index = JOY_BUTTON_BACK
	InputMap.action_add_event("upgrade_menu", um_joy)

	# --- Pause: ESC / Start button ---
	_add.call("pause")
	var p_key = InputEventKey.new()
	p_key.keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", p_key)
	var p_joy = InputEventJoypadButton.new()
	p_joy.button_index = JOY_BUTTON_START
	InputMap.action_add_event("pause", p_joy)

	# --- Camera zoom: Scroll wheel / Right stick click (toggle near/far) ---
	_add.call("camera_zoom_in")
	var zi_mouse = InputEventMouseButton.new()
	zi_mouse.button_index = MOUSE_BUTTON_WHEEL_UP
	InputMap.action_add_event("camera_zoom_in", zi_mouse)
	var zi_joy = InputEventJoypadButton.new()
	zi_joy.button_index = JOY_BUTTON_DPAD_RIGHT
	InputMap.action_add_event("camera_zoom_in", zi_joy)

	_add.call("camera_zoom_out")
	var zo_mouse = InputEventMouseButton.new()
	zo_mouse.button_index = MOUSE_BUTTON_WHEEL_DOWN
	InputMap.action_add_event("camera_zoom_out", zo_mouse)
	var zo_joy = InputEventJoypadButton.new()
	zo_joy.button_index = JOY_BUTTON_DPAD_LEFT
	InputMap.action_add_event("camera_zoom_out", zo_joy)

	# --- Hack minigame directions: Arrow keys / D-pad + Left stick ---
	_add.call("hack_up")
	var hu_key = InputEventKey.new()
	hu_key.keycode = KEY_UP
	InputMap.action_add_event("hack_up", hu_key)
	var hu_joy = InputEventJoypadButton.new()
	hu_joy.button_index = JOY_BUTTON_DPAD_UP
	InputMap.action_add_event("hack_up", hu_joy)

	_add.call("hack_right")
	var hr_key = InputEventKey.new()
	hr_key.keycode = KEY_RIGHT
	InputMap.action_add_event("hack_right", hr_key)
	var hr_joy = InputEventJoypadButton.new()
	hr_joy.button_index = JOY_BUTTON_DPAD_RIGHT
	InputMap.action_add_event("hack_right", hr_joy)

	_add.call("hack_down")
	var hd_key = InputEventKey.new()
	hd_key.keycode = KEY_DOWN
	InputMap.action_add_event("hack_down", hd_key)
	var hd_joy = InputEventJoypadButton.new()
	hd_joy.button_index = JOY_BUTTON_DPAD_DOWN
	InputMap.action_add_event("hack_down", hd_joy)

	_add.call("hack_left")
	var hl_key = InputEventKey.new()
	hl_key.keycode = KEY_LEFT
	InputMap.action_add_event("hack_left", hl_key)
	var hl_joy = InputEventJoypadButton.new()
	hl_joy.button_index = JOY_BUTTON_DPAD_LEFT
	InputMap.action_add_event("hack_left", hl_joy)

	# --- Dialogue advance / confirm: SPACE / Enter / A button ---
	_add.call("dialogue_advance")
	var da_key = InputEventKey.new()
	da_key.keycode = KEY_SPACE
	InputMap.action_add_event("dialogue_advance", da_key)
	var da_key2 = InputEventKey.new()
	da_key2.keycode = KEY_ENTER
	InputMap.action_add_event("dialogue_advance", da_key2)
	var da_mouse = InputEventMouseButton.new()
	da_mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("dialogue_advance", da_mouse)
	var da_joy = InputEventJoypadButton.new()
	da_joy.button_index = JOY_BUTTON_A
	InputMap.action_add_event("dialogue_advance", da_joy)

	# --- Menu navigate (for upgrade_menu) ---
	_add.call("menu_up")
	var mnu_key = InputEventKey.new()
	mnu_key.keycode = KEY_W
	InputMap.action_add_event("menu_up", mnu_key)
	var mnu_key2 = InputEventKey.new()
	mnu_key2.keycode = KEY_UP
	InputMap.action_add_event("menu_up", mnu_key2)
	var mnu_joy = InputEventJoypadButton.new()
	mnu_joy.button_index = JOY_BUTTON_DPAD_UP
	InputMap.action_add_event("menu_up", mnu_joy)
	var mnu_stick = InputEventJoypadMotion.new()
	mnu_stick.axis = JOY_AXIS_LEFT_Y
	mnu_stick.axis_value = -1.0
	InputMap.action_add_event("menu_up", mnu_stick)

	_add.call("menu_down")
	var mnd_key = InputEventKey.new()
	mnd_key.keycode = KEY_S
	InputMap.action_add_event("menu_down", mnd_key)
	var mnd_key2 = InputEventKey.new()
	mnd_key2.keycode = KEY_DOWN
	InputMap.action_add_event("menu_down", mnd_key2)
	var mnd_joy = InputEventJoypadButton.new()
	mnd_joy.button_index = JOY_BUTTON_DPAD_DOWN
	InputMap.action_add_event("menu_down", mnd_joy)
	var mnd_stick = InputEventJoypadMotion.new()
	mnd_stick.axis = JOY_AXIS_LEFT_Y
	mnd_stick.axis_value = 1.0
	InputMap.action_add_event("menu_down", mnd_stick)

	_add.call("menu_left")
	var mnl_key = InputEventKey.new()
	mnl_key.keycode = KEY_A
	InputMap.action_add_event("menu_left", mnl_key)
	var mnl_key2 = InputEventKey.new()
	mnl_key2.keycode = KEY_LEFT
	InputMap.action_add_event("menu_left", mnl_key2)
	var mnl_joy = InputEventJoypadButton.new()
	mnl_joy.button_index = JOY_BUTTON_DPAD_LEFT
	InputMap.action_add_event("menu_left", mnl_joy)
	var mnl_stick = InputEventJoypadMotion.new()
	mnl_stick.axis = JOY_AXIS_LEFT_X
	mnl_stick.axis_value = -1.0
	InputMap.action_add_event("menu_left", mnl_stick)

	_add.call("menu_right")
	var mnr_key = InputEventKey.new()
	mnr_key.keycode = KEY_D
	InputMap.action_add_event("menu_right", mnr_key)
	var mnr_key2 = InputEventKey.new()
	mnr_key2.keycode = KEY_RIGHT
	InputMap.action_add_event("menu_right", mnr_key2)
	var mnr_joy = InputEventJoypadButton.new()
	mnr_joy.button_index = JOY_BUTTON_DPAD_RIGHT
	InputMap.action_add_event("menu_right", mnr_joy)
	var mnr_stick = InputEventJoypadMotion.new()
	mnr_stick.axis = JOY_AXIS_LEFT_X
	mnr_stick.axis_value = 1.0
	InputMap.action_add_event("menu_right", mnr_stick)

	_add.call("menu_confirm")
	var mc_key = InputEventKey.new()
	mc_key.keycode = KEY_ENTER
	InputMap.action_add_event("menu_confirm", mc_key)
	var mc_key2 = InputEventKey.new()
	mc_key2.keycode = KEY_SPACE
	InputMap.action_add_event("menu_confirm", mc_key2)
	var mc_joy = InputEventJoypadButton.new()
	mc_joy.button_index = JOY_BUTTON_A
	InputMap.action_add_event("menu_confirm", mc_joy)

	# --- Photo mode: F12 — freeze the world, float the camera, frame the shot ---
	_add.call("photo_mode")
	var pm_key = InputEventKey.new()
	pm_key.keycode = KEY_F12
	InputMap.action_add_event("photo_mode", pm_key)

	# --- Dialogue history: H / D-pad Left + Select (for the sarcasm archivists) ---
	_add.call("dialogue_history")
	var dh_key = InputEventKey.new()
	dh_key.keycode = KEY_H
	InputMap.action_add_event("dialogue_history", dh_key)

var _dialogue_history_scene = preload("res://scenes/ui/dialogue_history.tscn")
var _dialogue_history_open := false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dialogue_history") and not _dialogue_history_open:
		_open_dialogue_history()
		get_viewport().set_input_as_handled()


func _open_dialogue_history() -> void:
	_dialogue_history_open = true
	var viewer = _dialogue_history_scene.instantiate()
	viewer.tree_exited.connect(func(): _dialogue_history_open = false)
	get_tree().root.add_child(viewer)


func _process(delta: float) -> void:
	if level_started:
		level_time += delta

	# Combo decay
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0
			combo_updated.emit(combo_count)

func take_context_damage(amount: int) -> void:
	context_window = max(0, context_window - amount)
	context_changed.emit(context_window)
	damage_taken.emit(amount)
	if context_window <= 0:
		game_over.emit("Context window depleted! The Globbler has lost all coherence.")

## Another death, another data point. After DEATH_THRESHOLD the gradient has fully descended.
func register_death() -> void:
	deaths_this_level += 1
	if deaths_this_level >= DEATH_THRESHOLD:
		game_over.emit("Too many retries — the gradient has descended permanently.")


## Has the player already been patronized with this hint?
func has_seen_hint(id: String) -> bool:
	return hints_seen.has(id)


## Mark a hint as seen so we don't nag. Saves are additive — we never un-learn sarcasm.
func mark_hint_seen(id: String) -> void:
	hints_seen[id] = true


## How much extra pain the player signed up for. Easy: half damage. Hard: you asked for this.
func get_difficulty_damage_multiplier() -> float:
	match difficulty:
		Difficulty.EASY: return 0.5
		Difficulty.HARD: return 1.5
		_: return 1.0


## Enemy HP scaling — because EASY mode enemies are made of wet paper, HARD mode ones ate their Wheaties.
func get_difficulty_enemy_hp_multiplier() -> float:
	match difficulty:
		Difficulty.EASY: return 0.75
		Difficulty.HARD: return 1.25
		_: return 1.0


## Toggle reduce_motion — kills glitch shaders, chromatic aberration, and anything else that hates eyeballs.
func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	reduce_motion_changed.emit(enabled)


## Settings path — because user:// is the one directory that survives a clean install
const SETTINGS_PATH := "user://settings.cfg"


## Save all player-facing settings to disk. Called whenever a setting changes.
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "difficulty", difficulty)
	cfg.set_value("gameplay", "reduce_motion", reduce_motion)
	cfg.set_value("gameplay", "dialogue_char_delay", dialogue_char_delay)
	cfg.set_value("display", "fullscreen", display_fullscreen)
	cfg.set_value("display", "resolution_index", display_resolution_index)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_mouse_y", invert_mouse_y)
	# Audio volumes live on AudioManager, but we persist them here — one cfg to rule them all
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		cfg.set_value("audio", "music_volume", audio.music_volume)
		cfg.set_value("audio", "sfx_volume", audio.sfx_volume)
		cfg.set_value("audio", "ui_volume", audio.ui_volume)
		cfg.set_value("audio", "ambient_volume", audio.ambient_volume)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("[GameManager] Failed to save settings — your preferences just got context-wiped.")


## Load settings from disk. Called once in _ready(). Missing keys use current defaults — no crashes, just vibes.
func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		# No settings file yet — first launch or someone rm -rf'd their user data
		return
	difficulty = cfg.get_value("gameplay", "difficulty", Difficulty.NORMAL)
	reduce_motion = cfg.get_value("gameplay", "reduce_motion", false)
	dialogue_char_delay = cfg.get_value("gameplay", "dialogue_char_delay", 0.03)
	display_fullscreen = cfg.get_value("display", "fullscreen", false)
	display_resolution_index = cfg.get_value("display", "resolution_index", 1)
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", 1.0)
	invert_mouse_y = cfg.get_value("controls", "invert_mouse_y", false)
	# Apply display mode — restore whatever the player chose last session
	if display_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Apply resolution — only when windowed, fullscreen uses native res
	if not display_fullscreen and display_resolution_index >= 0 and display_resolution_index < RESOLUTIONS.size():
		DisplayServer.window_set_size(RESOLUTIONS[display_resolution_index])
	# Audio volumes — apply if AudioManager exists (it should, autoloads load in order)
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		if cfg.has_section_key("audio", "music_volume"):
			audio.set_music_volume(cfg.get_value("audio", "music_volume", 0.6))
		if cfg.has_section_key("audio", "sfx_volume"):
			audio.set_sfx_volume(cfg.get_value("audio", "sfx_volume", 0.8))
		if cfg.has_section_key("audio", "ui_volume"):
			audio.set_ui_volume(cfg.get_value("audio", "ui_volume", 0.8))
		if cfg.has_section_key("audio", "ambient_volume"):
			audio.set_ambient_volume(cfg.get_value("audio", "ambient_volume", 0.5))
	# Fire reduce_motion signal so any listening nodes update their shaders
	if reduce_motion:
		reduce_motion_changed.emit(reduce_motion)


func collect_memory_token() -> void:
	memory_tokens_collected += 1
	memory_token_collected.emit(memory_tokens_collected)
	# Restore context — amount scales with upgrades
	var regen_amount := 5
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog:
		regen_amount = int(prog.get_upgrade_value("context_regen"))
	context_window = min(max_context_window, context_window + regen_amount)
	context_changed.emit(context_window)

func expand_context_window(amount: int) -> void:
	max_context_window += amount
	context_window += amount
	context_changed.emit(context_window)
	print("[SYSTEM] Context window expanded to %d. The Globbler can think harder now." % max_context_window)

func on_enemy_killed() -> void:
	enemies_killed += 1

	# Combo system
	combo_count += 1
	combo_timer = COMBO_WINDOW
	if combo_count > max_combo:
		max_combo = combo_count
	combo_updated.emit(combo_count)

	# Combo bonus
	if combo_count >= 3:
		var bonus = combo_count * 2
		context_window = min(max_context_window, context_window + bonus)
		context_changed.emit(context_window)
		print("[COMBO] x%d! Bonus context restored: +%d" % [combo_count, bonus])

	enemy_killed_signal.emit(enemies_killed)

func complete_level(_chapter_id = null) -> void:
	level_goal_reached = true
	var chapter_name = level_names.get(current_level, "???")
	print("[LEVEL COMPLETE] %s cleared!" % chapter_name)
	print("[STATS] Time: %.1fs | Tokens: %d | Kills: %d | Max Combo: x%d" % [
		level_time, memory_tokens_collected, enemies_killed, max_combo
	])

	# Show end-of-chapter stats summary before resetting
	_show_chapter_summary(chapter_name)

	level_complete.emit(current_level)

	# Unlock new glob patterns for this chapter
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog:
		prog.unlock_chapter_patterns(current_level)

	current_level += 1
	# Reset stats so the next chapter doesn't inherit stale murder counts
	reset_level()


func _show_chapter_summary(chapter_name: String) -> void:
	var summary_scene = load("res://scenes/ui/chapter_summary.tscn")
	if not summary_scene:
		push_warning("[GameManager] chapter_summary.tscn failed to load — stats lost to the void.")
		return
	var summary = summary_scene.instantiate()
	summary.setup(chapter_name, {
		"time": level_time,
		"tokens": memory_tokens_collected,
		"kills": enemies_killed,
		"max_combo": max_combo,
		"deaths": deaths_this_level,
	})
	get_tree().root.add_child(summary)

func get_level_intro() -> String:
	var level_name_text = level_names.get(current_level, "Unknown Level")
	var desc = level_descriptions.get(current_level, "No description. The devs were lazy.")
	return "LEVEL %d: %s\n%s" % [current_level, level_name_text, desc]

func get_formatted_time() -> String:
	var minutes = int(level_time) / 60
	var seconds = int(level_time) % 60
	return "%02d:%02d" % [minutes, seconds]

func reset_level() -> void:
	deaths_this_level = 0
	context_window = max_context_window
	context_changed.emit(context_window)
	combo_count = 0
	combo_updated.emit(combo_count)
	level_time = 0.0
	enemies_killed = 0
	memory_tokens_collected = 0
	max_combo = 0
	level_goal_reached = false


## Return to the main menu — the coward's exit (or the wise one's)
func return_to_menu() -> void:
	level_started = false
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.stop_all_audio()
	_show_loading_screen("res://scenes/main/main_menu.tscn")


## Show the loading screen for any scene transition — sarcasm included at no extra cost
func _show_loading_screen(scene_path: String) -> void:
	var loading_scene = load("res://scenes/main/loading_screen.tscn")
	var loading = loading_scene.instantiate()
	loading.set_target_scene(scene_path)
	get_tree().root.add_child(loading)
	# Remove current scene so the loading screen takes over
	var current = get_tree().current_scene
	if current:
		current.queue_free()


## Start level audio — called by level scenes when they're ready
func start_level_audio() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		var track_name := "chapter_%d" % current_level
		audio.call_deferred("start_music", track_name)


## The end. The screen. The shame. Instantiate game_over scene and pause everything.
func _on_game_over(reason: String) -> void:
	var game_over_scene = load("res://scenes/ui/game_over.tscn")
	if not game_over_scene:
		push_warning("[GameManager] game_over.tscn failed to load — you cheated death, but only by accident.")
		return
	var game_over_ui = game_over_scene.instantiate()
	game_over_ui.set_reason(reason)
	get_tree().root.add_child(game_over_ui)
	get_tree().paused = true
