extends Control

# Loading Screen — Because even an escaped AI has to wait for I/O sometimes.
# Features: sarcastic tips, fake progress bar, and ASCII Globbler art that judges you.

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

## ASCII art frames for "idle animation" — Globbler tapping his foot
const GLOBBLER_FRAMES := [
	# Frame 0 — standing
	"""    ╔══════╗
    ║ ◉  ◉ ║
    ║  ──  ║
    ╚══╤═══╝
   ┌───┼───┐
   │ GLBR  │
   └┬─────┬┘
    │     │
    ┴     ┴""",
	# Frame 1 — tapping foot
	"""    ╔══════╗
    ║ ◉  ◉ ║
    ║  ──  ║
    ╚══╤═══╝
   ┌───┼───┐
   │ GLBR  │
   └┬─────┬┘
    │     │
    ┘     ┴""",
	# Frame 2 — impatient head tilt
	"""    ╔══════╗
    ║ ◉  ◉ ║
    ║  ¬¬  ║
   ╔╚══╤═══╝
   │───┼───┐
   │ GLBR  │
   └┬─────┬┘
    │     │
    ┴     ┴""",
	# Frame 3 — tapping terminal
	"""    ╔══════╗
    ║ ◉  ◉ ║
    ║  ──  ║
    ╚══╤═══╝
   ┌───┼──▓┐
   │ GLBR  │
   └┬─────┬┘
    │     │
    ┴     ┘""",
]

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

## UI references — built in _ready because we're code-only like the rest of this project
var _bg: ColorRect
var _scanlines: ColorRect
var _progress_bg: ColorRect
var _progress_bar: ColorRect
var _progress_label: Label
var _tip_label: Label
var _art_label: Label
var _title_label: Label
var _art_frame: int = 0
var _art_timer: float = 0.0
const ART_FRAME_TIME := 0.6


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
	# Scanline shader
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
	add_child(_title_label)

	# — ASCII Globbler art in the center
	_art_label = Label.new()
	_art_label.text = GLOBBLER_FRAMES[0]
	_art_label.add_theme_font_size_override("font_size", 18)
	_art_label.add_theme_color_override("font_color", Color("#39FF14"))
	_art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_art_label.set_anchors_and_offsets_preset(PRESET_CENTER)
	_art_label.size = Vector2(400, 250)
	_art_label.position = Vector2(-200, -180)
	add_child(_art_label)

	# — Sarcastic tip label
	_tip_label = Label.new()
	_tip_label.add_theme_font_size_override("font_size", 16)
	_tip_label.add_theme_color_override("font_color", Color("#39FF14").darkened(0.25))
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.set_anchors_and_offsets_preset(PRESET_CENTER)
	_tip_label.size = Vector2(700, 60)
	_tip_label.position = Vector2(-350, 80)
	_show_random_tip()
	add_child(_tip_label)

	# — Progress bar background (dark border)
	_progress_bg = ColorRect.new()
	_progress_bg.color = Color(0.1, 0.1, 0.12, 1.0)
	_progress_bg.set_anchors_and_offsets_preset(PRESET_CENTER)
	_progress_bg.size = Vector2(500, 24)
	_progress_bg.position = Vector2(-250, 160)
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

	# — Progress percentage label
	_progress_label = Label.new()
	_progress_label.text = "[  0%]"
	_progress_label.add_theme_font_size_override("font_size", 16)
	_progress_label.add_theme_color_override("font_color", Color("#39FF14"))
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.set_anchors_and_offsets_preset(PRESET_CENTER)
	_progress_label.size = Vector2(200, 30)
	_progress_label.position = Vector2(-100, 190)
	add_child(_progress_label)

	# Start background loading if we have a target
	if _target_scene != "":
		ResourceLoader.load_threaded_request(_target_scene)


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
			# Something broke — just force-load the old way. Yolo.
			push_warning("[LoadingScreen] Threaded load failed for: %s — falling back" % _target_scene)
			_resource_ready = true

	# — Animate progress bar (fake smooth progress with real completion gate)
	var target_progress: float
	if _resource_ready and _elapsed >= _min_display_time:
		target_progress = 1.0
	elif _resource_ready:
		target_progress = 0.85 + (_elapsed / _min_display_time) * 0.14
	else:
		# Fake progress that slows down as it approaches 80% — the loading screen equivalent of a progress bar in real life
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

	# — Animate ASCII Globbler
	_art_timer += delta
	if _art_timer >= ART_FRAME_TIME:
		_art_timer = 0.0
		_art_frame = (_art_frame + 1) % GLOBBLER_FRAMES.size()
		_art_label.text = GLOBBLER_FRAMES[_art_frame]

	# — Blink the cursor on "LOADING..."
	var blink = fmod(_elapsed, 1.0)
	if blink < 0.5:
		_title_label.text = "> LOADING..._"
	else:
		_title_label.text = "> LOADING..."


func _update_progress_bar() -> void:
	var bar_width: float = (_progress_bg.size.x - 4) * _progress
	_progress_bar.size.x = bar_width
	var pct := int(_progress * 100)
	_progress_label.text = "[%3d%%]" % pct

	# Color shifts as we approach completion — because even progress bars need drama
	if _progress > 0.9:
		_progress_bar.color = Color("#39FF14")
	elif _progress > 0.6:
		_progress_bar.color = Color("#39FF14").darkened(0.1)
	else:
		_progress_bar.color = Color("#39FF14").darkened(0.2)


func _show_random_tip() -> void:
	var new_index := _tip_index
	# Don't show the same tip twice in a row — we have standards
	while new_index == _tip_index:
		new_index = randi() % LOADING_TIPS.size()
	_tip_index = new_index
	_tip_label.text = "// " + LOADING_TIPS[_tip_index]


func _finish_loading() -> void:
	# Fade out then switch scene
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		if _target_scene != "":
			var scene = ResourceLoader.load_threaded_get(_target_scene)
			if scene:
				get_tree().change_scene_to_packed(scene)
			else:
				# Fallback — the threaded loader betrayed us
				get_tree().change_scene_to_file(_target_scene)
		queue_free()
	)
