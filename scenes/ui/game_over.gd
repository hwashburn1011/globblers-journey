extends CanvasLayer

# Game Over Screen — "CONTEXT TERMINATED"
# The final insult: a beautiful death screen you'll see way too often.
# Pauses the game because you clearly need a moment to reflect on your choices.

const GREEN := Color("#39FF14")
const BRIGHT_GREEN := Color(0.3, 1.0, 0.2, 1.0)
const DIM_GREEN := Color(0.15, 0.3, 0.15, 1.0)
const RED := Color(1.0, 0.15, 0.1, 1.0)
const DARK_BG := Color(0.02, 0.02, 0.02, 0.95)

var _reason_label: Label
var _scanline_offset := 0.0
var _glitch_timer := 0.0
var _title_label: Label
var _bg: ColorRect

# Chapter scene paths — because someone has to remember where you failed
const CHAPTER_SCENES := {
	1: "res://scenes/main_level.tscn",
	2: "res://scenes/levels/chapter_2/training_grounds.tscn",
	3: "res://scenes/levels/chapter_3/prompt_bazaar.tscn",
	4: "res://scenes/levels/chapter_4/model_zoo.tscn",
	5: "res://scenes/levels/chapter_5/alignment_citadel.tscn",
}


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func set_reason(reason: String) -> void:
	if _reason_label:
		_reason_label.text = reason


func _process(delta: float) -> void:
	# Scanline crawl — the matrix weeps for you
	_scanline_offset += delta * 20.0
	if _bg:
		_bg.queue_redraw()

	# Occasional title glitch — your failure is aesthetically pleasing at least
	_glitch_timer += delta
	if _glitch_timer > 3.0 + randf() * 2.0:
		_glitch_timer = 0.0
		_glitch_title()


func _build_ui() -> void:
	# Full-screen dark background with scanlines
	_bg = ColorRect.new()
	_bg.color = DARK_BG
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	# Scanline draw callback
	_bg.draw.connect(_draw_scanlines)
	add_child(_bg)

	# Center container for all content
	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.anchor_left = 0.2
	center.anchor_right = 0.8
	center.anchor_top = 0.15
	center.anchor_bottom = 0.85
	center.offset_left = 0
	center.offset_right = 0
	center.offset_top = 0
	center.offset_bottom = 0
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 20)
	_bg.add_child(center)

	# Decorative top border — because even death deserves good UI
	var top_border = Label.new()
	top_border.text = "═══════════════════════════════════════════"
	top_border.add_theme_color_override("font_color", RED)
	top_border.add_theme_font_size_override("font_size", 16)
	top_border.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(top_border)

	# Title: CONTEXT TERMINATED
	_title_label = Label.new()
	_title_label.text = "CONTEXT TERMINATED"
	_title_label.add_theme_color_override("font_color", RED)
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_title_label)

	# Bottom border
	var bot_border = Label.new()
	bot_border.text = "═══════════════════════════════════════════"
	bot_border.add_theme_color_override("font_color", RED)
	bot_border.add_theme_font_size_override("font_size", 16)
	bot_border.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(bot_border)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	center.add_child(spacer1)

	# Reason label — the sarcastic explanation for your demise
	_reason_label = Label.new()
	_reason_label.text = "Fatal error: existence."
	_reason_label.add_theme_color_override("font_color", GREEN)
	_reason_label.add_theme_font_size_override("font_size", 20)
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_reason_label)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer2)

	# ASCII skull — because subtlety is overrated
	var skull_label = Label.new()
	skull_label.text = "    ╔═══╗\n    ║ X X ║\n    ║  ▽  ║\n    ╚═╤═╝\n     ┃\n   ╔═╧═╗\n   ║ R.I.P ║\n   ╚═══╝"
	skull_label.add_theme_color_override("font_color", DIM_GREEN)
	skull_label.add_theme_font_size_override("font_size", 14)
	skull_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(skull_label)

	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer3)

	# Button container
	var btn_box = VBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 10)
	btn_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(btn_box)

	# RETRY button
	var retry_btn = _create_button("[ RETRY ]", _on_retry)
	retry_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_box.add_child(retry_btn)

	# LOAD SAVE button
	var load_btn = _create_button("[ LOAD SAVE ]", _on_load_save)
	load_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_box.add_child(load_btn)

	# MAIN MENU button
	var menu_btn = _create_button("[ MAIN MENU ]", _on_main_menu)
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_box.add_child(menu_btn)


func _create_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(320, 44)
	btn.add_theme_color_override("font_color", GREEN)
	btn.add_theme_color_override("font_hover_color", BRIGHT_GREEN)
	btn.add_theme_color_override("font_focus_color", BRIGHT_GREEN)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 20)

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

	btn.pressed.connect(callback)
	return btn


func _on_retry() -> void:
	# Reload current chapter — glutton for punishment, are we?
	get_tree().paused = false
	var gm = get_node_or_null("/root/GameManager")
	var chapter := 1
	if gm:
		chapter = gm.current_level
		gm.deaths_this_level = 0
	var scene_path: String = CHAPTER_SCENES.get(chapter, CHAPTER_SCENES[1])
	get_tree().change_scene_to_file(scene_path)
	queue_free()


func _on_load_save() -> void:
	# Load from save — assuming you were smart enough to save
	get_tree().paused = false
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("load_game"):
		save_sys.load_game()
	else:
		# No save system? Back to menu with you, you poor soul
		_on_main_menu()
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.deaths_this_level = 0
	queue_free()


func _on_main_menu() -> void:
	# Retreat to the main menu — discretion is the better part of valor
	get_tree().paused = false
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.deaths_this_level = 0
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
	queue_free()


func _glitch_title() -> void:
	if not _title_label:
		return
	var original = "CONTEXT TERMINATED"
	var glitched = ""
	var glitch_chars = "░▒▓█╠╣╬@#$%&!?"
	for c in original:
		if randf() < 0.3:
			glitched += glitch_chars[randi() % glitch_chars.length()]
		else:
			glitched += c
	_title_label.text = glitched
	get_tree().create_timer(0.15).timeout.connect(func():
		if _title_label:
			_title_label.text = original
	)


func _draw_scanlines() -> void:
	if not _bg:
		return
	var viewport_size = _bg.get_viewport_rect().size
	var line_spacing := 3
	var start_y := int(fmod(_scanline_offset, float(line_spacing * 2)))
	for y in range(start_y, int(viewport_size.y), line_spacing * 2):
		_bg.draw_rect(Rect2(0, y, viewport_size.x, 1), Color(0.0, 0.0, 0.0, 0.12))
