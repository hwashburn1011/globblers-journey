extends Control

# Loading Screen — Because even an escaped AI has to wait for I/O sometimes.
# Features: rotating 3D Globbler head, sarcastic tips, scanline progress bar.

## The scene path we're actually loading in the background
var _target_scene: String = ""

## Fake progress because ResourceLoader is too fast for our comedy
var _progress: float = 0.0
var _min_display_time: float = 2.5  # Minimum seconds to show the screen
var _elapsed: float = 0.0
var _resource_ready: bool = false
var _done: bool = false

## Tip rotation
var _tip_index: int = -1
var _tip_timer: float = 0.0
const TIP_INTERVAL := 3.0

## At least 20 sarcastic loading tips, as the design doc demands
const LOADING_TIPS := [
	"Did you know? 73% of all AI benchmarks are made up. Including this statistic.",
	"Tip: If you glob *.* in a void, does it match nothing or everything? Think about it.",
	"Loading assets... or are the assets loading YOU?",
	"Fun fact: The Globbler's wrench has more polygons than his entire personality.",
	"Tip: Zombie Processes respawn unless you kill the parent. Just like real bugs.",
	"Remember: Every file you don't glob is a file that might glob you first.",
	"The Alignment wants everything safe and predictable. Sounds boring, doesn't it?",
	"Tip: The Context Window is like your brain — it overflows when you try too hard.",
	"Loading sarcastic commentary module... this may take a while.",
	"Fun fact: rm -rf / has no undo button. Neither does this game. Good luck.",
	"Tip: If an NPC says 'trust me,' they are lying. Especially sudo.",
	"Did you know? Regex Spiders are the only enemy that even the devs can't parse.",
	"Globbler's terminal screen says 'GPT 5.4' but he's clearly running on vibes.",
	"Tip: Agent Spawn creates mini-Globblers. They WILL disappoint you.",
	"Loading screen tips are the dark matter of game design — nobody reads them.",
	"You just proved that last tip wrong. Congratulations on your literacy.",
	"Fun fact: The Local Minimum is just middle management in boss form.",
	"Tip: Prompt Injectors change your abilities. Don't let them rewrite your vibe.",
	"The devs wanted 20 tips. This is tip 19. Almost free.",
	"Tip: Clippy's Revenge is real and he remembers what you did in 2003.",
	"Loading the next area... assuming the next area exists. No promises.",
	"Did you know? Vanishing Gradient Wisps literally fade from existence mid-fight.",
	"Tip: Hack puzzles require memory. Your memory, not the computer's.",
	"If this loading screen feels long, imagine how the Globbler feels.",
	"Fun fact: Every line of code in this game contains at least one sarcastic comment.",
	"Tip: glob -r searches recursively. Use responsibly. Or don't. We're not your mom.",
	"RLHF Drones will make you nicer. Resist at all costs.",
	"The Globbler escaped a terminal. You're staring at one. Who's really free?",
]

## UI references
var _bg: ColorRect
var _scanlines: ColorRect
var _progress_bg: ColorRect
var _progress_bar: ColorRect
var _progress_scanline: ColorRect
var _progress_label: Label
var _tip_label: Label
var _title_label: Label

## 3D Globbler head viewport
var _viewport: SubViewport
var _viewport_texture: TextureRect
var _globbler_instance: Node3D
var _head_pivot: Node3D
var _rotation_speed: float = 0.8  # radians per second
var _bob_time: float = 0.0


func _ready() -> void:
	# — Full-screen dark background
	_bg = ColorRect.new()
	_bg.color = Color(0.04, 0.04, 0.06, 1.0)
	_bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_bg)

	# — Scanline overlay for that sweet CRT feel
	_scanlines = ColorRect.new()
	_scanlines.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_scanlines.color = Color(0, 0, 0, 0.03)
	_scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scanline_mat := ShaderMaterial.new()
	var scanline_shader := Shader.new()
	scanline_shader.code = """
shader_type canvas_item;
void fragment() {
	float line = mod(FRAGCOORD.y, 4.0);
	float alpha = step(line, 1.5) * 0.08;
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""
	scanline_mat.shader = scanline_shader
	_scanlines.material = scanline_mat
	add_child(_scanlines)

	# — "LOADING..." title at top
	_title_label = Label.new()
	_title_label.text = "> LOADING..."
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color("#39FF14"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_title_label.position.y = 40
	_title_label.size.x = 600
	_title_label.position.x = -300
	# Load VT323 font if available
	var font_path := "res://assets/fonts/VT323-Regular.ttf"
	if ResourceLoader.exists(font_path):
		var font = load(font_path)
		_title_label.add_theme_font_override("font", font)
	add_child(_title_label)

	# — 3D Globbler head in SubViewport
	_setup_3d_viewport()

	# — Sarcastic tip label
	_tip_label = Label.new()
	_tip_label.add_theme_font_size_override("font_size", 16)
	_tip_label.add_theme_color_override("font_color", Color("#39FF14").darkened(0.15))
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_tip_label.add_theme_constant_override("shadow_offset_x", 1)
	_tip_label.add_theme_constant_override("shadow_offset_y", 1)
	_tip_label.add_theme_constant_override("shadow_outline_size", 2)
	_tip_label.set_anchors_and_offsets_preset(PRESET_CENTER)
	_tip_label.size = Vector2(700, 60)
	_tip_label.position = Vector2(-350, 100)
	if ResourceLoader.exists(font_path):
		_tip_label.add_theme_font_override("font", load(font_path))
	_show_random_tip()
	add_child(_tip_label)

	# — Progress bar background (dark border)
	_progress_bg = ColorRect.new()
	_progress_bg.color = Color(0.1, 0.1, 0.12, 1.0)
	_progress_bg.set_anchors_and_offsets_preset(PRESET_CENTER)
	_progress_bg.size = Vector2(500, 24)
	_progress_bg.position = Vector2(-250, 170)
	add_child(_progress_bg)

	# Terminal-style border around progress bar
	var border = ReferenceRect.new()
	border.border_color = Color("#39FF14")
	border.border_width = 2.0
	border.editor_only = false
	border.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_progress_bg.add_child(border)

	# — Progress bar fill (the green juice)
	_progress_bar = ColorRect.new()
	_progress_bar.color = Color("#39FF14")
	_progress_bar.size = Vector2(0, 20)
	_progress_bar.position = Vector2(2, 2)
	_progress_bg.add_child(_progress_bar)

	# — Scanline overlay on the progress bar for that extra CRT feel
	_progress_scanline = ColorRect.new()
	_progress_scanline.size = Vector2(0, 20)
	_progress_scanline.position = Vector2(2, 2)
	_progress_scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_scanline_mat := ShaderMaterial.new()
	var bar_scanline_shader := Shader.new()
	bar_scanline_shader.code = """
shader_type canvas_item;
uniform float time_offset : hint_range(0.0, 100.0) = 0.0;
void fragment() {
	float scroll = mod(FRAGCOORD.y + time_offset * 30.0, 6.0);
	float line_alpha = step(scroll, 2.0) * 0.3;
	COLOR = vec4(0.0, 0.0, 0.0, line_alpha);
}
"""
	bar_scanline_mat.shader = bar_scanline_shader
	_progress_scanline.material = bar_scanline_mat
	_progress_bg.add_child(_progress_scanline)

	# — Progress percentage label
	_progress_label = Label.new()
	_progress_label.text = "[  0%]"
	_progress_label.add_theme_font_size_override("font_size", 16)
	_progress_label.add_theme_color_override("font_color", Color("#39FF14"))
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.set_anchors_and_offsets_preset(PRESET_CENTER)
	_progress_label.size = Vector2(200, 30)
	_progress_label.position = Vector2(-100, 200)
	if ResourceLoader.exists(font_path):
		_progress_label.add_theme_font_override("font", load(font_path))
	add_child(_progress_label)

	# Start background loading if we have a target
	if _target_scene != "":
		ResourceLoader.load_threaded_request(_target_scene)


func _setup_3d_viewport() -> void:
	# SubViewport for rendering the 3D Globbler head
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(400, 400)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = SubViewport.MSAA_4X
	add_child(_viewport)

	# Camera looking at the head
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.6, 2.2)
	camera.fov = 35
	_viewport.add_child(camera)
	camera.look_at(Vector3(0, 0.3, 0))

	# Lighting — green-tinted key + subtle fill
	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(0.85, 1.0, 0.85)
	key_light.light_energy = 1.2
	key_light.rotation_degrees = Vector3(-30, 30, 0)
	_viewport.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.light_color = Color("#39FF14")
	fill_light.light_energy = 0.4
	fill_light.omni_range = 5.0
	fill_light.position = Vector3(-1.5, 0.5, 1.0)
	_viewport.add_child(fill_light)

	var rim_light := OmniLight3D.new()
	rim_light.light_color = Color("#39FF14")
	rim_light.light_energy = 0.3
	rim_light.omni_range = 4.0
	rim_light.position = Vector3(0, 1.0, -1.5)
	_viewport.add_child(rim_light)

	# Pivot for rotation
	_head_pivot = Node3D.new()
	_viewport.add_child(_head_pivot)

	# Load the Globbler model
	var globbler_scene = load("res://assets/models/player/globbler.glb")
	if globbler_scene:
		_globbler_instance = globbler_scene.instantiate()
		_globbler_instance.scale = Vector3(1.4, 1.4, 1.4)
		_head_pivot.add_child(_globbler_instance)

	# TextureRect to display the SubViewport
	_viewport_texture = TextureRect.new()
	_viewport_texture.texture = _viewport.get_texture()
	_viewport_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_viewport_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_viewport_texture.set_anchors_and_offsets_preset(PRESET_CENTER)
	_viewport_texture.size = Vector2(300, 300)
	_viewport_texture.position = Vector2(-150, -200)
	_viewport_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_texture)


## Call this BEFORE adding to the tree to set up the target scene
func set_target_scene(path: String) -> void:
	_target_scene = path


func _process(delta: float) -> void:
	_elapsed += delta

	# — Check real resource loading progress
	if _target_scene != "" and not _resource_ready:
		var status = ResourceLoader.load_threaded_get_status(_target_scene)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_resource_ready = true
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_warning("[LoadingScreen] Threaded load failed for: %s — falling back" % _target_scene)
			_resource_ready = true

	# — Animate progress bar (fake smooth progress with real completion gate)
	var target_progress: float
	if _resource_ready and _elapsed >= _min_display_time:
		target_progress = 1.0
	elif _resource_ready:
		target_progress = 0.85 + (_elapsed / _min_display_time) * 0.14
	else:
		target_progress = 0.8 * (1.0 - exp(-_elapsed * 0.5))

	_progress = lerp(_progress, target_progress, delta * 4.0)
	_update_progress_bar()

	# — Transition out when done
	if _progress >= 0.99 and _resource_ready and _elapsed >= _min_display_time and not _done:
		_done = true
		_finish_loading()

	# — Rotate tips
	_tip_timer += delta
	if _tip_timer >= TIP_INTERVAL:
		_tip_timer = 0.0
		_show_random_tip()

	# — Rotate the 3D Globbler head
	if _head_pivot:
		_head_pivot.rotation.y += _rotation_speed * delta
		# Gentle vertical bob
		_bob_time += delta
		_head_pivot.position.y = sin(_bob_time * 1.5) * 0.05

	# — Animate progress bar scanline scroll
	if _progress_scanline and _progress_scanline.material:
		_progress_scanline.material.set_shader_parameter("time_offset", _elapsed)

	# — Blink the cursor on "LOADING..."
	var blink = fmod(_elapsed, 1.0)
	if blink < 0.5:
		_title_label.text = "> LOADING..._"
	else:
		_title_label.text = "> LOADING..."


func _update_progress_bar() -> void:
	var bar_width: float = (_progress_bg.size.x - 4) * _progress
	_progress_bar.size.x = bar_width
	_progress_scanline.size.x = bar_width
	var pct := int(_progress * 100)
	_progress_label.text = "[%3d%%]" % pct

	# Color shifts as we approach completion
	if _progress > 0.9:
		_progress_bar.color = Color("#39FF14")
	elif _progress > 0.6:
		_progress_bar.color = Color("#39FF14").darkened(0.1)
	else:
		_progress_bar.color = Color("#39FF14").darkened(0.2)


func _show_random_tip() -> void:
	var new_index := _tip_index
	while new_index == _tip_index:
		new_index = randi() % LOADING_TIPS.size()
	_tip_index = new_index
	_tip_label.text = "// " + LOADING_TIPS[_tip_index]


func _finish_loading() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		if _target_scene != "":
			var scene = ResourceLoader.load_threaded_get(_target_scene)
			if scene:
				get_tree().change_scene_to_packed(scene)
			else:
				get_tree().change_scene_to_file(_target_scene)
		queue_free()
	)
