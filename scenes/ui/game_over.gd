extends CanvasLayer

# Game Over Screen — "CONTEXT TERMINATED"
# The final insult: a beautiful death screen you'll see way too often.
# Pauses the game because you clearly need a moment to reflect on your choices.

const GREEN := Color("#39FF14")
const BRIGHT_GREEN := Color(0.3, 1.0, 0.2, 1.0)
const DIM_GREEN := Color(0.15, 0.3, 0.15, 1.0)
const RED := Color(1.0, 0.15, 0.1, 1.0)
const DIM_RED := Color(0.5, 0.1, 0.08, 1.0)
const DARK_BG := Color(0.02, 0.02, 0.02, 0.95)
const TEXT_SHADOW := Color(0.0, 0.0, 0.0, 0.9)

var _reason_label: Label
var _scanline_offset := 0.0
var _glitch_timer := 0.0
var _title_label: Label
var _bg: ColorRect
var _death_count_label: Label

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
	# (unless reduce_motion says otherwise — your failure can still be dignified)
	var _gm = get_node_or_null("/root/GameManager")
	if not (_gm and _gm.reduce_motion):
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
	_bg.draw.connect(_draw_scanlines)
	add_child(_bg)

	# Terminal-bordered center panel — consistent with pause menu style
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480, 500)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.01, 0.01, 0.95)
	panel_style.border_color = DIM_RED
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(3)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	_bg.add_child(panel)

	var center = VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 12)
	panel.add_child(center)

	# ASCII box-drawing top border
	var top_border = Label.new()
	top_border.text = "╔══════════════════════════════════╗"
	top_border.add_theme_color_override("font_color", DIM_RED)
	top_border.add_theme_font_size_override("font_size", 14)
	top_border.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(top_border)

	# Title: CONTEXT TERMINATED — in angry red
	_title_label = Label.new()
	_title_label.text = "║  CONTEXT TERMINATED  ║"
	_title_label.add_theme_color_override("font_color", RED)
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_title_label)

	# Bottom border
	var bot_border = Label.new()
	bot_border.text = "╚══════════════════════════════════╝"
	bot_border.add_theme_color_override("font_color", DIM_RED)
	bot_border.add_theme_font_size_override("font_size", 14)
	bot_border.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(bot_border)

	# Error message subtitle
	var error_line = Label.new()
	error_line.text = "> ERR_FATAL: Process terminated with exit code 1_"
	error_line.add_theme_color_override("font_color", Color(0.7, 0.2, 0.15))
	error_line.add_theme_font_size_override("font_size", 13)
	error_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_shadow(error_line)
	center.add_child(error_line)

	# ASCII tombstone — because subtlety is overrated
	var skull_label = Label.new()
	skull_label.text = "     ┌─────────┐\n     │  ╔═══╗  │\n     │  ║ X X ║  │\n     │  ║  ▽  ║  │\n     │  ╚═══╝  │\n     │  R.I.P  │\n     └────┬────┘\n        ▓▓▓▓▓"
	skull_label.add_theme_color_override("font_color", Color(0.2, 0.45, 0.2))
	skull_label.add_theme_font_size_override("font_size", 12)
	skull_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_shadow(skull_label)
	center.add_child(skull_label)

	# Reason label — the sarcastic explanation for your demise
	_reason_label = Label.new()
	_reason_label.text = "Fatal error: existence."
	_reason_label.add_theme_color_override("font_color", GREEN)
	_reason_label.add_theme_font_size_override("font_size", 18)
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_reason_label)

	# Death count — salt in the wound
	_death_count_label = Label.new()
	var gm = get_node_or_null("/root/GameManager")
	var deaths := 0
	if gm and "deaths_this_level" in gm:
		deaths = gm.deaths_this_level
	_death_count_label.text = "> Deaths this level: %d" % deaths
	_death_count_label.add_theme_color_override("font_color", Color(0.2, 0.45, 0.2))
	_death_count_label.add_theme_font_size_override("font_size", 13)
	_death_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_shadow(_death_count_label)
	center.add_child(_death_count_label)

	# Spacer before buttons
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)

	# Button container
	var btn_box = VBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 8)
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

	# Input hint
	var hint = Label.new()
	hint.text = "[R] Retry  ·  [ESC] Menu"
	hint.add_theme_color_override("font_color", Color(0.2, 0.45, 0.2))
	hint.add_theme_font_size_override("font_size", 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_shadow(hint)
	center.add_child(hint)


func _apply_shadow(lbl: Label) -> void:
	lbl.add_theme_color_override("font_shadow_color", TEXT_SHADOW)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_constant_override("shadow_outline_size", 2)


func _create_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(320, 44)
	btn.add_theme_color_override("font_color", GREEN)
	btn.add_theme_color_override("font_hover_color", BRIGHT_GREEN)
	btn.add_theme_color_override("font_focus_color", BRIGHT_GREEN)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 18)

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

	# Hover SFX — consistent with pause menu
	btn.mouse_entered.connect(func():
		var am = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx("ui_hover")
	)

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
	ChapterTransition.transition_to(get_tree(), scene_path)
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
	ChapterTransition.transition_to(get_tree(), "res://scenes/main/main_menu.tscn")
	queue_free()


func _glitch_title() -> void:
	if not _title_label:
		return
	var original = "║  CONTEXT TERMINATED  ║"
	var glitched = ""
	var glitch_chars = "░▒▓█╠╣╬@#$%&!?"
	for c in original:
		if c in "║ ":
			glitched += c
		elif randf() < 0.3:
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
