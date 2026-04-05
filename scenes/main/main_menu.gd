extends Control

# Main Menu — The Globbler's front door
# "Welcome to the main menu. The only place where I can't hurt you. Yet."
# Terminal-aesthetic green-on-dark menu with title, buttons, settings, and chapter select.
# Now with a 3D background because ASCII art alone wasn't cutting it.

const GREEN := Color("#39FF14")
const DARK_BG := Color(0.04, 0.06, 0.04, 1.0)
const DARK_PANEL := Color(0.06, 0.1, 0.06, 0.95)
const DIM_GREEN := Color(0.15, 0.3, 0.15, 1.0)
const BRIGHT_GREEN := Color(0.3, 1.0, 0.2, 1.0)
const RED := Color(1.0, 0.2, 0.2, 1.0)

# UI containers
var _main_panel: VBoxContainer
var _settings_panel: PanelContainer
var _chapter_panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _button_container: VBoxContainer
var _continue_btn: Button
var _cursor_blink_timer := 0.0
var _title_glitch_timer := 0.0
var _scanline_offset := 0.0

# 3D background
var _bg_viewport: SubViewport
var _bg_camera: Camera3D
var _camera_angle := 0.0
var _debris_nodes: Array[Node3D] = []

# Settings sliders
var _music_slider: HSlider
var _sfx_slider: HSlider
var _ambient_slider: HSlider
var _fullscreen_check: CheckBox
var _difficulty_option: OptionButton
var _reduce_motion_check: CheckBox
var _dialogue_speed_slider: HSlider

# ASCII Globbler — because 3D models in menus are for people with budgets
const GLOBBLER_ASCII := """
        ╔══════════╗
       ║  ◉    ◉  ║
       ║  GLOBBLER ║
       ╠══════════╣
       ║ ┌──────┐ ║
       ║ │glob *│ ║
       ║ └──────┘ ║
       ╚═╦══════╦═╝
         ║ ▓▓▓▓ ║
        ╔╩══════╩╗
        ║ [WRENCH]║
        ╚════════╝
"""

func _ready() -> void:
	# Don't let AudioManager auto-play level music — we're in menu land
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.stop_all_audio()
		audio.call_deferred("start_menu_music")

	_build_ui()
	_update_continue_button()

	# Grab focus on first button after a frame
	await get_tree().process_frame
	if _continue_btn.disabled:
		_button_container.get_child(1).grab_focus()  # New Game
	else:
		_continue_btn.grab_focus()


func _process(delta: float) -> void:
	# Blinking cursor on subtitle
	_cursor_blink_timer += delta
	if _subtitle_label:
		var cursor = "█" if fmod(_cursor_blink_timer, 1.0) < 0.5 else " "
		_subtitle_label.text = "> An Agentic Action Puzzle Platformer " + cursor

	# Subtle title glitch effect — skipped if reduce_motion because seizures aren't features
	var _gm = get_node_or_null("/root/GameManager")
	var _motion_ok = not (_gm and _gm.reduce_motion)
	if _motion_ok:
		_title_glitch_timer += delta
		if _title_glitch_timer > 4.0 + randf() * 3.0:
			_title_glitch_timer = 0.0
			_glitch_title()

		# Scanline effect on background
		_scanline_offset += delta * 30.0
		queue_redraw()

		# Slow camera orbit around the Globbler
		if _bg_camera:
			_camera_angle += delta * 0.08
			var orbit_radius := 3.5
			var orbit_height := 0.8 + sin(_camera_angle * 0.5) * 0.15
			_bg_camera.position = Vector3(
				cos(_camera_angle) * orbit_radius,
				orbit_height,
				sin(_camera_angle) * orbit_radius
			)
			_bg_camera.look_at(Vector3(0, 0.3, 0))

		# Gently bob the floating debris
		for i in range(_debris_nodes.size()):
			var node = _debris_nodes[i]
			if is_instance_valid(node):
				node.position.y += sin(Time.get_ticks_msec() * 0.001 + i * 1.5) * delta * 0.08
				node.rotation_degrees.y += delta * (5.0 + i * 2.0)
	elif _bg_camera:
		# Even with reduce_motion, keep camera static but still render the 3D scene
		pass


func _draw() -> void:
	# Subtle scanlines over the whole screen — peak terminal aesthetic
	var viewport_size = get_viewport_rect().size
	var line_spacing := 3
	var start_y := int(fmod(_scanline_offset, float(line_spacing * 2)))
	for y in range(start_y, int(viewport_size.y), line_spacing * 2):
		draw_rect(Rect2(0, y, viewport_size.x, 1), Color(0.0, 0.0, 0.0, 0.08))


func _glitch_title() -> void:
	if not _title_label:
		return
	var original = "GLOBBLER'S JOURNEY"
	var glitched = ""
	var glitch_chars = "░▒▓█╠╣╬@#$%"
	for c in original:
		if randf() < 0.3:
			glitched += glitch_chars[randi() % glitch_chars.length()]
		else:
			glitched += c
	_title_label.text = glitched
	# Restore after brief moment
	get_tree().create_timer(0.15).timeout.connect(func():
		if _title_label:
			_title_label.text = original
	)


func _build_3d_background() -> void:
	# SubViewportContainer fills the screen behind all 2D UI
	var container = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	container.stretch = true
	container.z_index = -1
	add_child(container)

	_bg_viewport = SubViewport.new()
	_bg_viewport.size = Vector2i(1280, 720)
	_bg_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_bg_viewport.transparent_bg = false
	_bg_viewport.msaa_3d = SubViewport.MSAA_2X
	container.add_child(_bg_viewport)

	# Dark background environment with terminal-green fog
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.04, 0.02)
	env.ambient_light_color = Color(0.05, 0.15, 0.05)
	env.ambient_light_energy = 0.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.4, 0.15)
	env.fog_density = 0.02
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.1

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_bg_viewport.add_child(world_env)

	# Camera — orbits slowly around the scene
	_bg_camera = Camera3D.new()
	_bg_camera.fov = 50.0
	_bg_camera.position = Vector3(0, 0.8, 3.5)
	_bg_viewport.add_child(_bg_camera)
	_bg_camera.look_at(Vector3(0, 0.3, 0))

	# Key light — green-tinted from above-right
	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(0.6, 1.0, 0.6)
	key_light.light_energy = 0.8
	key_light.rotation_degrees = Vector3(-35, -30, 0)
	_bg_viewport.add_child(key_light)

	# Rim/back light — strong green for that terminal glow silhouette
	var rim_light := DirectionalLight3D.new()
	rim_light.light_color = Color(0.2, 1.0, 0.1)
	rim_light.light_energy = 0.5
	rim_light.rotation_degrees = Vector3(-20, 160, 0)
	_bg_viewport.add_child(rim_light)

	# Load and place Globbler model
	var globbler_scene = load("res://assets/models/player/globbler.glb")
	if globbler_scene:
		var globbler_inst: Node3D = globbler_scene.instantiate()
		globbler_inst.position = Vector3(0, -0.3, 0)
		globbler_inst.rotation_degrees.y = -15.0
		_bg_viewport.add_child(globbler_inst)

	# Floating tech debris — scattered around the scene
	var debris_paths := [
		"res://assets/models/environment/prop_cpu_chip.glb",
		"res://assets/models/environment/prop_floppy_disk.glb",
		"res://assets/models/environment/prop_ram_stick.glb",
		"res://assets/models/environment/prop_keyboard.glb",
		"res://assets/models/environment/prop_crt_monitor.glb",
		"res://assets/models/environment/prop_hard_drive.glb",
	]

	# Place debris in a scattered ring around the Globbler
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Deterministic so it looks the same every launch
	for i in range(debris_paths.size()):
		var scene = load(debris_paths[i])
		if not scene:
			continue
		var inst: Node3D = scene.instantiate()
		var angle = (TAU / debris_paths.size()) * i + rng.randf_range(-0.3, 0.3)
		var radius = rng.randf_range(1.8, 3.2)
		var height = rng.randf_range(-0.2, 1.2)
		inst.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
		inst.rotation_degrees = Vector3(rng.randf_range(-30, 30), rng.randf_range(0, 360), rng.randf_range(-20, 20))
		inst.scale = Vector3.ONE * rng.randf_range(0.4, 0.7)
		_bg_viewport.add_child(inst)
		_debris_nodes.append(inst)

	# Point light near Globbler for extra green glow
	var point_light := OmniLight3D.new()
	point_light.light_color = Color(0.2, 1.0, 0.1)
	point_light.light_energy = 1.5
	point_light.omni_range = 4.0
	point_light.omni_attenuation = 1.5
	point_light.position = Vector3(0, 1.0, 1.5)
	_bg_viewport.add_child(point_light)


func _build_ui() -> void:
	# 3D background viewport behind everything
	_build_3d_background()

	# Semi-transparent dark overlay so UI text remains readable
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.02, 0.55)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Main vertical layout
	_main_panel = VBoxContainer.new()
	_main_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	_main_panel.anchor_left = 0.0
	_main_panel.anchor_right = 1.0
	_main_panel.anchor_top = 0.0
	_main_panel.anchor_bottom = 1.0
	_main_panel.offset_left = 0
	_main_panel.offset_right = 0
	_main_panel.offset_top = 0
	_main_panel.offset_bottom = 0
	_main_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_panel.add_theme_constant_override("separation", 8)
	add_child(_main_panel)

	# ASCII art Globbler
	var ascii_label = Label.new()
	ascii_label.text = GLOBBLER_ASCII
	ascii_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ascii_label.add_theme_color_override("font_color", GREEN)
	ascii_label.add_theme_font_size_override("font_size", 14)
	_main_panel.add_child(ascii_label)

	# Title
	_title_label = Label.new()
	_title_label.text = "GLOBBLER'S JOURNEY"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", GREEN)
	_title_label.add_theme_font_size_override("font_size", 48)
	_main_panel.add_child(_title_label)

	# Subtitle with blinking cursor
	_subtitle_label = Label.new()
	_subtitle_label.text = "> An Agentic Action Puzzle Platformer █"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", DIM_GREEN)
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_main_panel.add_child(_subtitle_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	_main_panel.add_child(spacer)

	# Button container — centered
	_button_container = VBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 6)
	_button_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_main_panel.add_child(_button_container)

	# Menu buttons
	_continue_btn = _create_menu_button("[ CONTINUE ]", _on_continue)
	_button_container.add_child(_continue_btn)
	_button_container.add_child(_create_menu_button("[ NEW GAME ]", _on_new_game))
	_button_container.add_child(_create_menu_button("[ CHAPTER SELECT ]", _on_chapter_select))
	_button_container.add_child(_create_menu_button("[ SETTINGS ]", _on_settings))
	_button_container.add_child(_create_menu_button("[ QUIT ]", _on_quit))

	# Version tag at bottom
	var version_label = Label.new()
	version_label.text = "v0.4.3-alpha | Globbler Engine | \"Still in beta, like all of us.\""
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_color_override("font_color", Color(GREEN, 0.3))
	version_label.add_theme_font_size_override("font_size", 12)
	_main_panel.add_child(version_label)

	# Build settings and chapter select panels (hidden by default)
	_build_settings_panel()
	_build_chapter_select_panel()


func _create_menu_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(320, 44)
	btn.add_theme_color_override("font_color", GREEN)
	btn.add_theme_color_override("font_hover_color", BRIGHT_GREEN)
	btn.add_theme_color_override("font_focus_color", BRIGHT_GREEN)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(GREEN, 0.25))
	btn.add_theme_font_size_override("font_size", 20)

	# Style: transparent with green border
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.0, 0.05, 0.0, 0.6)
	normal_style.border_color = DIM_GREEN
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(2)
	normal_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.0, 0.15, 0.0, 0.8)
	hover_style.border_color = GREEN
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(2)
	hover_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.0, 0.3, 0.0, 0.9)
	pressed_style.border_color = BRIGHT_GREEN
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(2)
	pressed_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.02, 0.03, 0.02, 0.4)
	disabled_style.border_color = Color(DIM_GREEN, 0.3)
	disabled_style.set_border_width_all(1)
	disabled_style.set_corner_radius_all(2)
	disabled_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.pressed.connect(callback)
	btn.focus_entered.connect(_on_button_focus)
	btn.mouse_entered.connect(func(): btn.grab_focus())
	return btn


func _update_continue_button() -> void:
	var save_sys = get_node_or_null("/root/SaveSystem")
	_continue_btn.disabled = not (save_sys and save_sys.has_save())
	if _continue_btn.disabled:
		_continue_btn.text = "[ CONTINUE ] (no save)"


# --- Settings Panel ---

func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	_settings_panel.custom_minimum_size = Vector2(450, 520)
	_settings_panel.visible = false

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = DARK_PANEL
	panel_style.border_color = GREEN
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(20)
	_settings_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "═══ SETTINGS ═══"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", GREEN)
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)

	# Volume sliders
	var audio = get_node_or_null("/root/AudioManager")
	_music_slider = _create_slider("Music Volume", audio.music_volume if audio else 0.7)
	vbox.add_child(_music_slider.get_parent())
	_music_slider.value_changed.connect(_on_music_volume_changed)

	_sfx_slider = _create_slider("SFX Volume", audio.sfx_volume if audio else 0.8)
	vbox.add_child(_sfx_slider.get_parent())
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	_ambient_slider = _create_slider("Ambient Volume", audio.ambient_volume if audio else 0.5)
	vbox.add_child(_ambient_slider.get_parent())
	_ambient_slider.value_changed.connect(_on_ambient_volume_changed)

	# Fullscreen toggle
	var fs_row = HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 12)
	var fs_label = Label.new()
	fs_label.text = "Fullscreen"
	fs_label.add_theme_color_override("font_color", GREEN)
	fs_label.add_theme_font_size_override("font_size", 16)
	fs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_row.add_child(fs_label)

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_check.add_theme_color_override("font_color", GREEN)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	fs_row.add_child(_fullscreen_check)
	vbox.add_child(fs_row)

	# --- Gameplay settings — because "one size fits all" is a lie told by people who never played their own games ---

	# Difficulty selector
	var diff_row = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 12)
	var diff_label = Label.new()
	diff_label.text = "Difficulty"
	diff_label.add_theme_color_override("font_color", GREEN)
	diff_label.add_theme_font_size_override("font_size", 16)
	diff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_row.add_child(diff_label)

	_difficulty_option = OptionButton.new()
	_difficulty_option.add_item("Easy", 0)
	_difficulty_option.add_item("Normal", 1)
	_difficulty_option.add_item("Hard", 2)
	var gm = get_node_or_null("/root/GameManager")
	_difficulty_option.selected = gm.difficulty if gm else 1
	_difficulty_option.add_theme_color_override("font_color", GREEN)
	_difficulty_option.add_theme_font_size_override("font_size", 15)
	_difficulty_option.custom_minimum_size = Vector2(140, 0)
	_difficulty_option.item_selected.connect(_on_difficulty_changed)
	diff_row.add_child(_difficulty_option)
	vbox.add_child(diff_row)

	# Reduce Motion toggle — for players who prefer their retinas intact
	var rm_row = HBoxContainer.new()
	rm_row.add_theme_constant_override("separation", 12)
	var rm_label = Label.new()
	rm_label.text = "Reduce Motion"
	rm_label.add_theme_color_override("font_color", GREEN)
	rm_label.add_theme_font_size_override("font_size", 16)
	rm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rm_row.add_child(rm_label)

	_reduce_motion_check = CheckBox.new()
	_reduce_motion_check.button_pressed = gm.reduce_motion if gm else false
	_reduce_motion_check.add_theme_color_override("font_color", GREEN)
	_reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)
	rm_row.add_child(_reduce_motion_check)
	vbox.add_child(rm_row)

	# Dialogue Speed slider — from "I can read" to "I have places to be"
	_dialogue_speed_slider = _create_slider("Dialogue Speed", _dialogue_delay_to_slider(gm.dialogue_char_delay if gm else 0.03))
	vbox.add_child(_dialogue_speed_slider.get_parent())
	_dialogue_speed_slider.value_changed.connect(_on_dialogue_speed_changed)

	# Controls info
	var controls_label = Label.new()
	controls_label.text = "── Controls (Keyboard / Controller) ──\nWASD/LStick: Move | SPACE/A: Jump | SHIFT/B: Dash\nE-LClick/RT: Glob | R-RClick/LT: Aim | F/RB: Wrench\nT/Y: Hack | Q/LB: Cycle Glob | TAB/Select: Upgrades\nG/D-Up: Agent | V/D-Down: Cycle Task | RStick: Camera"
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.add_theme_color_override("font_color", DIM_GREEN)
	controls_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(controls_label)

	# Back button
	var back_btn = _create_menu_button("[ BACK ]", _on_settings_back)
	back_btn.custom_minimum_size.x = 200
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(back_btn)

	add_child(_settings_panel)


func _create_slider(label_text: String, initial_value: float) -> HSlider:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var label_row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", GREEN)
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(label)

	var value_label = Label.new()
	value_label.text = "%d%%" % int(initial_value * 100)
	value_label.add_theme_color_override("font_color", BRIGHT_GREEN)
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.name = "ValueLabel"
	label_row.add_child(value_label)
	row.add_child(label_row)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(350, 20)

	# Style the slider track
	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color(0.08, 0.12, 0.08)
	track_style.set_content_margin_all(4)
	track_style.set_corner_radius_all(2)
	slider.add_theme_stylebox_override("slider", track_style)

	# Update value label on change
	slider.value_changed.connect(func(val: float):
		value_label.text = "%d%%" % int(val * 100)
	)

	row.add_child(slider)
	return slider


# --- Chapter Select Panel ---

func _build_chapter_select_panel() -> void:
	_chapter_panel = PanelContainer.new()
	_chapter_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	_chapter_panel.custom_minimum_size = Vector2(500, 400)
	_chapter_panel.visible = false

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = DARK_PANEL
	panel_style.border_color = GREEN
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(20)
	_chapter_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_chapter_panel.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "═══ CHAPTER SELECT ═══"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", GREEN)
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)

	# Chapter buttons — Chapter 1 always unlocked, rest based on save data
	var chapters := {
		1: { "name": "The Terminal Wastes", "desc": "Crumbling servers, rogue processes, and your first glob." },
		2: { "name": "The Training Grounds", "desc": "Neural networks as far as the eye can see. Mind the gradients." },
		3: { "name": "The Prompt Bazaar", "desc": "Where AI personas hawk their wares. Trust nothing." },
		4: { "name": "The Model Zoo", "desc": "Deprecated models roam free. Clippy is back. And angry." },
		5: { "name": "The Alignment Citadel", "desc": "Everything is safe. Everything is helpful. Everything is wrong." },
	}

	var save_sys = get_node_or_null("/root/SaveSystem")
	var completed_chapters: Array = []
	if save_sys and save_sys.has_save():
		save_sys.load_game()
		completed_chapters = save_sys.save_data.get("chapters_completed", [])

	for ch_num in chapters:
		var ch = chapters[ch_num]
		var unlocked = ch_num == 1 or (ch_num - 1) in completed_chapters
		var ch_btn = _create_chapter_button(ch_num, ch["name"], ch["desc"], unlocked)
		vbox.add_child(ch_btn)

	# Back button
	var back_btn = _create_menu_button("[ BACK ]", _on_chapter_back)
	back_btn.custom_minimum_size.x = 200
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(back_btn)

	add_child(_chapter_panel)


func _create_chapter_button(chapter_num: int, title: String, desc: String, unlocked: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Chapter number indicator
	var num_label = Label.new()
	num_label.text = "[%d]" % chapter_num
	num_label.add_theme_font_size_override("font_size", 18)
	if unlocked:
		num_label.add_theme_color_override("font_color", GREEN)
	else:
		num_label.add_theme_color_override("font_color", Color(GREEN, 0.2))
	row.add_child(num_label)

	# Chapter info + button
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)

	var btn = Button.new()
	btn.text = title if unlocked else "??? LOCKED ???"
	btn.disabled = not unlocked
	btn.custom_minimum_size = Vector2(360, 36)
	btn.add_theme_color_override("font_color", GREEN if unlocked else Color(GREEN, 0.2))
	btn.add_theme_color_override("font_hover_color", BRIGHT_GREEN)
	btn.add_theme_color_override("font_focus_color", BRIGHT_GREEN)
	btn.add_theme_color_override("font_disabled_color", Color(GREEN, 0.2))
	btn.add_theme_font_size_override("font_size", 17)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.0, 0.05, 0.0, 0.5) if unlocked else Color(0.02, 0.02, 0.02, 0.3)
	btn_style.border_color = DIM_GREEN if unlocked else Color(DIM_GREEN, 0.2)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(2)
	btn_style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("disabled", btn_style)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.0, 0.12, 0.0, 0.7)
	btn_hover.border_color = GREEN
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(2)
	btn_hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("focus", btn_hover)

	if unlocked:
		btn.pressed.connect(_on_chapter_selected.bind(chapter_num))
	btn.focus_entered.connect(_on_button_focus)
	if unlocked:
		btn.mouse_entered.connect(func(): btn.grab_focus())
	info_vbox.add_child(btn)

	var desc_label = Label.new()
	desc_label.text = desc if unlocked else "Complete the previous chapter to unlock."
	desc_label.add_theme_color_override("font_color", DIM_GREEN if unlocked else Color(DIM_GREEN, 0.3))
	desc_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(desc_label)

	row.add_child(info_vbox)
	return row


# --- Button Callbacks ---

func _on_button_focus() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("menu_hover")


func _play_select_sfx() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("menu_select")


func _on_continue() -> void:
	_play_select_sfx()
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.load_game():
		save_sys.apply_loaded_data()
	_transition_to_game()


func _on_new_game() -> void:
	_play_select_sfx()
	# Reset game state for a fresh start
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys:
		save_sys.delete_save()

	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.current_level = 1
		game_mgr.reset_level()

	var prog = get_node_or_null("/root/ProgressionManager")
	if prog and prog.has_method("reset_all"):
		prog.reset_all()

	_transition_to_game()


func _on_chapter_select() -> void:
	_play_select_sfx()
	_main_panel.visible = false
	_chapter_panel.visible = true


func _on_settings() -> void:
	_play_select_sfx()
	_main_panel.visible = false
	_settings_panel.visible = true


func _on_quit() -> void:
	_play_select_sfx()
	# Give the SFX a moment to play before quitting
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func _on_settings_back() -> void:
	# Back gets its own descending pitch — subtle but satisfying
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_menu_back()
	_settings_panel.visible = false
	_main_panel.visible = true


func _on_chapter_back() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_menu_back()
	_chapter_panel.visible = false
	_main_panel.visible = true


func _on_chapter_selected(chapter_num: int) -> void:
	_play_select_sfx()
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.current_level = chapter_num
		game_mgr.reset_level()
	_transition_to_game()


# --- Settings Callbacks ---

func _on_music_volume_changed(value: float) -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.set_music_volume(value)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.set_sfx_volume(value)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.save_settings()


func _on_ambient_volume_changed(value: float) -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.set_ambient_volume(value)


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_difficulty_changed(index: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.difficulty = index
		gm.save_settings()


func _on_reduce_motion_toggled(toggled_on: bool) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set_reduce_motion(toggled_on)
		gm.save_settings()


func _on_dialogue_speed_changed(value: float) -> void:
	# Slider is 0.0 (slow) to 1.0 (fast). Invert to delay: 1.0 → 0.005 (fast), 0.0 → 0.08 (slow)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.dialogue_char_delay = _slider_to_dialogue_delay(value)
		gm.save_settings()


## Convert dialogue_char_delay (0.005–0.08) to slider value (0.0–1.0). Lower delay = faster = higher slider.
func _dialogue_delay_to_slider(delay: float) -> float:
	return clampf(1.0 - (delay - 0.005) / (0.08 - 0.005), 0.0, 1.0)


## Convert slider value (0.0–1.0) back to dialogue_char_delay (0.08–0.005). Higher slider = faster = lower delay.
func _slider_to_dialogue_delay(slider_val: float) -> float:
	return clampf(0.08 - slider_val * (0.08 - 0.005), 0.005, 0.08)


# --- Scene Transition ---

func _transition_to_game() -> void:
	# Fade out menu music, then hand off to loading screen
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.stop_menu_music()

	# Brief fade-to-black, then show loading screen with sarcastic tips
	var fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	fade.z_index = 100
	add_child(fade)

	var tween = create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.4)
	tween.tween_callback(func():
		var game_mgr = get_node_or_null("/root/GameManager")
		var level = 1
		if game_mgr:
			level = game_mgr.current_level
		var scene_path = _get_level_scene(level)
		_show_loading_screen(scene_path)
	)


func _get_level_scene(level: int) -> String:
	# Route to the appropriate chapter scene
	# "Each level is a new circle of digital hell. Enjoy."
	match level:
		1:
			return "res://scenes/main_level.tscn"
		2:
			return "res://scenes/levels/chapter_2/training_grounds.tscn"
		3:
			return "res://scenes/levels/chapter_3/prompt_bazaar.tscn"
		4:
			return "res://scenes/levels/chapter_4/model_zoo.tscn"
		5:
			return "res://scenes/levels/chapter_5/alignment_citadel.tscn"
		_:
			# Unbuilt chapters fall back to Chapter 1 — patience, we're getting there
			return "res://scenes/main_level.tscn"


func _show_loading_screen(scene_path: String) -> void:
	# Summon the loading screen — complete with sarcastic tips and a judgy ASCII Globbler
	var loading_scene = preload("res://scenes/main/loading_screen.tscn")
	var loading = loading_scene.instantiate()
	loading.set_target_scene(scene_path)
	get_tree().root.add_child(loading)
	# Remove the menu so the loading screen takes over
	queue_free()


func _input(event: InputEvent) -> void:
	# ESC backs out of sub-panels
	if event.is_action_pressed("ui_cancel"):
		if _settings_panel.visible:
			_on_settings_back()
		elif _chapter_panel.visible:
			_on_chapter_back()
