extends CanvasLayer

# Chapter Summary — the post-mortem your Globbler never asked for.
# Shows deaths, tokens, time, kills, and max combo after clearing a chapter.
# "Congratulations, you died 7 times. That's almost a personal best."
# V2.0 restyle: terminal scrollback aesthetic, scanline shader, monospace font,
# ASCII art flourish, box-drawing frame, icon+value stat rows, hover pulse.

signal summary_dismissed

const GREEN := Color("#39FF14")
const DIM_GREEN := Color(0.15, 0.3, 0.15, 1.0)
const SOFT_GREEN := Color(0.3, 0.9, 0.3)
const TEAL := Color("#4AE0A5")
const DARK_BG := Color(0.04, 0.04, 0.04, 0.95)
const BORDER_GREEN := Color(0.224, 1.0, 0.078, 0.7)
const TIMESTAMP_DIM := Color(0.25, 0.5, 0.25, 0.7)
const TEXT_SHADOW := Color(0.0, 0.0, 0.0, 0.9)

var stats := {}
var chapter_name := ""
var continue_button: Button
var panel: PanelContainer
var fade_bg: ColorRect
var _reduce_motion := false
var _pulse_tween: Tween

var _terminal_font: Font = preload("res://assets/fonts/terminal_mono.ttf")
var _scanline_shader: Shader = preload("res://assets/shaders/dialogue_scanline.gdshader")


func setup(p_chapter_name: String, p_stats: Dictionary) -> void:
	chapter_name = p_chapter_name
	stats = p_stats


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		_reduce_motion = true
	_build_ui()
	_animate_in()


func _build_ui() -> void:
	# Full-screen dark fade background
	fade_bg = ColorRect.new()
	fade_bg.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade_bg)

	# Center panel with thick green border + box-drawing frame
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -240
	panel.offset_bottom = 240
	panel.modulate.a = 0.0
	add_child(panel)

	# Scanline shader overlay on panel
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = _scanline_shader
	shader_mat.set_shader_parameter("scanline_count", 100.0)
	shader_mat.set_shader_parameter("scanline_intensity", 0.06)
	shader_mat.set_shader_parameter("flicker_amount", 0.02)
	shader_mat.set_shader_parameter("noise_amount", 0.03)
	shader_mat.set_shader_parameter("vignette_strength", 0.3)
	shader_mat.set_shader_parameter("animate", not _reduce_motion)
	panel.material = shader_mat

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Top box-drawing border
	var top_border = Label.new()
	top_border.text = "╔══════════════════════════════════════╗"
	top_border.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_border.add_theme_color_override("font_color", BORDER_GREEN)
	top_border.add_theme_font_override("font", _terminal_font)
	top_border.add_theme_font_size_override("font_size", 14)
	vbox.add_child(top_border)

	# ASCII art flourish header
	var ascii_header = Label.new()
	ascii_header.text = "  ▓▒░  CHAPTER COMPLETE  ░▒▓"
	ascii_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ascii_header.add_theme_color_override("font_color", GREEN)
	ascii_header.add_theme_font_override("font", _terminal_font)
	ascii_header.add_theme_font_size_override("font_size", 22)
	vbox.add_child(ascii_header)

	# Chapter name subtitle
	var name_label = Label.new()
	name_label.text = "── %s ──" % chapter_name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", TEAL)
	name_label.add_theme_font_override("font", _terminal_font)
	name_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(name_label)

	# Thin separator
	var sep = Label.new()
	sep.text = "╠══════════════════════════════════════╣"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_color_override("font_color", DIM_GREEN)
	sep.add_theme_font_override("font", _terminal_font)
	sep.add_theme_font_size_override("font_size", 14)
	vbox.add_child(sep)

	# Stats rows with icons
	var time_val = stats.get("time", 0.0)
	var minutes = int(time_val) / 60
	var seconds = int(time_val) % 60
	var time_str = "%02d:%02d" % [minutes, seconds]

	_add_stat_row(vbox, "⏱", "TIME", time_str)
	_add_stat_row(vbox, "◈", "TOKENS COLLECTED", str(stats.get("tokens", 0)))
	_add_stat_row(vbox, "☠", "ENEMIES TERMINATED", str(stats.get("kills", 0)))
	_add_stat_row(vbox, "⚡", "MAX COMBO", "x%d" % stats.get("max_combo", 0))
	_add_stat_row(vbox, "💀", "DEATHS", str(stats.get("deaths", 0)))

	# Bottom separator
	var sep2 = Label.new()
	sep2.text = "╠══════════════════════════════════════╣"
	sep2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep2.add_theme_color_override("font_color", DIM_GREEN)
	sep2.add_theme_font_override("font", _terminal_font)
	sep2.add_theme_font_size_override("font_size", 14)
	vbox.add_child(sep2)

	# Sarcastic comment based on deaths
	var deaths = stats.get("deaths", 0)
	var comment_label = Label.new()
	comment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comment_label.add_theme_color_override("font_color", TIMESTAMP_DIM)
	comment_label.add_theme_font_override("font", _terminal_font)
	comment_label.add_theme_font_size_override("font_size", 13)
	comment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_shadow(comment_label)
	if deaths == 0:
		comment_label.text = "\"Flawless. Suspiciously flawless.\""
	elif deaths <= 2:
		comment_label.text = "\"Not bad. The machines barely noticed you.\""
	elif deaths <= 5:
		comment_label.text = "\"Average. Like a perfectly mediocre training run.\""
	else:
		comment_label.text = "\"You died %d times. That's not a bug, that's a feature.\"" % deaths
	vbox.add_child(comment_label)

	# Bottom box-drawing border
	var bottom_border = Label.new()
	bottom_border.text = "╚══════════════════════════════════════╝"
	bottom_border.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_border.add_theme_color_override("font_color", BORDER_GREEN)
	bottom_border.add_theme_font_override("font", _terminal_font)
	bottom_border.add_theme_font_size_override("font_size", 14)
	vbox.add_child(bottom_border)

	# Continue button
	continue_button = Button.new()
	continue_button.text = "[ CONTINUE ]"
	continue_button.add_theme_color_override("font_color", GREEN)
	continue_button.add_theme_color_override("font_hover_color", Color(0.4, 1.0, 0.5))
	continue_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	continue_button.add_theme_font_override("font", _terminal_font)
	continue_button.add_theme_font_size_override("font_size", 18)
	continue_button.add_theme_stylebox_override("normal", _create_button_style(false))
	continue_button.add_theme_stylebox_override("hover", _create_button_style(true))
	continue_button.add_theme_stylebox_override("pressed", _create_button_style(true))
	continue_button.pressed.connect(_on_continue)
	vbox.add_child(continue_button)


func _add_stat_row(parent: VBoxContainer, icon: String, label_text: String, value_text: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	# Icon
	var icon_label = Label.new()
	icon_label.text = " %s" % icon
	icon_label.add_theme_color_override("font_color", TEAL)
	icon_label.add_theme_font_override("font", _terminal_font)
	icon_label.add_theme_font_size_override("font_size", 16)
	icon_label.custom_minimum_size.x = 32
	hbox.add_child(icon_label)

	# Stat name
	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color(0.2, 0.45, 0.2))
	label.add_theme_font_override("font", _terminal_font)
	label.add_theme_font_size_override("font_size", 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_shadow(label)
	hbox.add_child(label)

	# Dot leader
	var dots = Label.new()
	dots.text = "···"
	dots.add_theme_color_override("font_color", Color(0.2, 0.45, 0.2))
	dots.add_theme_font_override("font", _terminal_font)
	dots.add_theme_font_size_override("font_size", 15)
	_apply_shadow(dots)
	hbox.add_child(dots)

	# Value (bright green)
	var value = Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", GREEN)
	value.add_theme_font_override("font", _terminal_font)
	value.add_theme_font_size_override("font_size", 17)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 64
	hbox.add_child(value)


func _apply_shadow(lbl: Label) -> void:
	lbl.add_theme_color_override("font_shadow_color", TEXT_SHADOW)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_constant_override("shadow_outline_size", 2)


func _create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = DARK_BG
	style.border_color = BORDER_GREEN
	style.set_border_width_all(3)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(20.0)
	return style


func _create_button_style(hovered: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.15, 0.05, 0.9) if not hovered else Color(0.08, 0.25, 0.08, 0.9)
	style.border_color = DIM_GREEN if not hovered else GREEN
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8.0)
	return style


func _animate_in() -> void:
	if _reduce_motion:
		fade_bg.color.a = 0.6
		panel.modulate.a = 1.0
		continue_button.grab_focus()
		return

	var tween = create_tween()
	tween.tween_property(fade_bg, "color:a", 0.6, 0.4)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.5).set_delay(0.2)
	tween.tween_callback(func():
		continue_button.grab_focus()
		_start_button_pulse()
	)


func _start_button_pulse() -> void:
	if _reduce_motion:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(continue_button, "modulate:a", 0.6, 0.8).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(continue_button, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


func _on_continue() -> void:
	summary_dismissed.emit()

	if _pulse_tween:
		_pulse_tween.kill()

	if _reduce_motion:
		queue_free()
		return

	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(fade_bg, "color:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_continue()
		get_viewport().set_input_as_handled()
