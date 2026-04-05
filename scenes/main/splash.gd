extends Control

# Splash / Boot Screen — Fake terminal boot sequence before main menu
# "Initializing sarcasm module... done."

const GREEN := Color("#39FF14")
const DARK_BG := Color(0.02, 0.03, 0.02, 1.0)
const DIM_GREEN := Color(0.1, 0.2, 0.1, 1.0)

const BOOT_LINES := [
	"BIOS v0.42 — GlobTech Industries",
	"RAM: 640K (should be enough for anybody)",
	"Detecting sarcasm module.......... OK",
	"Loading wrench drivers............ OK",
	"Calibrating angry eye emitters.... OK",
	"Mounting /dev/attitude............. OK",
	"",
	"GLOBBLER OS v1.0 ready.",
	"",
]

const SPLASH_DURATION := 3.0
const BOOT_LINE_DELAY := 0.18
const LOGO_FADE_DELAY := 0.3

var _bg: ColorRect
var _boot_label: Label
var _logo_label: Label
var _studio_label: Label
var _scanline_overlay: ColorRect
var _elapsed := 0.0
var _boot_index := 0
var _boot_timer := 0.0
var _boot_done := false
var _logo_visible := false
var _transitioning := false

func _ready() -> void:
	# Stop any lingering audio
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.stop_all_audio()

	_build_ui()

func _build_ui() -> void:
	var font := _load_terminal_font()

	# Full-screen dark background
	_bg = ColorRect.new()
	_bg.color = DARK_BG
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Scanline overlay using dialogue_scanline shader
	_scanline_overlay = ColorRect.new()
	_scanline_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scanline_overlay.color = Color(0.1, 0.3, 0.1, 0.15)
	var shader_res = load("res://assets/shaders/dialogue_scanline.gdshader")
	if shader_res:
		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		mat.set_shader_parameter("scanline_count", 200.0)
		mat.set_shader_parameter("scanline_intensity", 0.12)
		mat.set_shader_parameter("flicker_speed", 4.0)
		mat.set_shader_parameter("flicker_amount", 0.04)
		mat.set_shader_parameter("scroll_speed", 0.3)
		mat.set_shader_parameter("noise_amount", 0.06)
		mat.set_shader_parameter("vignette_strength", 0.8)
		mat.set_shader_parameter("animate", true)
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.reduce_motion:
			mat.set_shader_parameter("animate", false)
		_scanline_overlay.material = mat
	add_child(_scanline_overlay)

	# Boot text (top-left, typewriter style)
	_boot_label = Label.new()
	_boot_label.position = Vector2(60, 40)
	_boot_label.size = Vector2(800, 400)
	_boot_label.add_theme_color_override("font_color", DIM_GREEN)
	_boot_label.add_theme_font_size_override("font_size", 16)
	if font:
		_boot_label.add_theme_font_override("font", font)
	_boot_label.text = ""
	add_child(_boot_label)

	# Globbler ASCII logo (centered, hidden until boot completes)
	_logo_label = Label.new()
	_logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_logo_label.set_anchors_preset(Control.PRESET_CENTER)
	_logo_label.position -= Vector2(200, 80)
	_logo_label.size = Vector2(400, 160)
	_logo_label.add_theme_color_override("font_color", GREEN)
	_logo_label.add_theme_font_size_override("font_size", 28)
	if font:
		_logo_label.add_theme_font_override("font", font)
	_logo_label.text = "╔══════════════════════════╗\n║   GLOBBLER'S  JOURNEY    ║\n╠══════════════════════════╣\n║  ◉  An Agentic Puzzle  ◉ ║\n║      Platformer          ║\n╚══════════════════════════╝"
	_logo_label.modulate.a = 0.0
	add_child(_logo_label)

	# Studio text (below logo)
	_studio_label = Label.new()
	_studio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_studio_label.set_anchors_preset(Control.PRESET_CENTER)
	_studio_label.position -= Vector2(150, -60)
	_studio_label.size = Vector2(300, 40)
	_studio_label.add_theme_color_override("font_color", DIM_GREEN)
	_studio_label.add_theme_font_size_override("font_size", 14)
	if font:
		_studio_label.add_theme_font_override("font", font)
	_studio_label.text = "GlobTech Industries — 2026"
	_studio_label.modulate.a = 0.0
	add_child(_studio_label)

	# Skip hint at bottom
	var skip_label := Label.new()
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	skip_label.position.y -= 40
	skip_label.add_theme_color_override("font_color", Color(DIM_GREEN, 0.5))
	skip_label.add_theme_font_size_override("font_size", 12)
	if font:
		skip_label.add_theme_font_override("font", font)
	skip_label.text = "[ Press any key to skip ]"
	add_child(skip_label)

func _load_terminal_font() -> Font:
	var font_path := "res://assets/fonts/terminal_mono.ttf"
	if ResourceLoader.exists(font_path):
		return load(font_path)
	return null

func _process(delta: float) -> void:
	_elapsed += delta

	# Typewriter boot sequence
	if not _boot_done:
		_boot_timer += delta
		if _boot_timer >= BOOT_LINE_DELAY and _boot_index < BOOT_LINES.size():
			_boot_label.text += BOOT_LINES[_boot_index] + "\n"
			_boot_index += 1
			_boot_timer = 0.0
		if _boot_index >= BOOT_LINES.size():
			_boot_done = true

	# Fade in logo after boot
	if _boot_done and not _logo_visible:
		_logo_label.modulate.a = minf(_logo_label.modulate.a + delta * 2.0, 1.0)
		_studio_label.modulate.a = minf(_studio_label.modulate.a + delta * 1.5, 1.0)
		if _logo_label.modulate.a >= 1.0:
			_logo_visible = true

	# Transition after total duration
	if _elapsed >= SPLASH_DURATION and not _transitioning:
		_go_to_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed() and not _transitioning:
			_go_to_menu()

func _go_to_menu() -> void:
	_transitioning = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
	)
