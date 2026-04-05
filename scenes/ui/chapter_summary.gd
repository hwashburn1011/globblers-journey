extends CanvasLayer

# Chapter Summary — the post-mortem your Globbler never asked for.
# Shows deaths, tokens, time, kills, and max combo after clearing a chapter.
# "Congratulations, you died 7 times. That's almost a personal best."

signal summary_dismissed

const TERMINAL_GREEN := Color(0.224, 1.0, 0.078)
const TERMINAL_GREEN_DIM := Color(0.15, 0.5, 0.15)
const TERMINAL_GREEN_TEXT := Color(0.3, 1.0, 0.4)
const TERMINAL_BG := Color(0.02, 0.04, 0.02, 0.92)
const TERMINAL_BORDER := Color(0.15, 0.5, 0.15, 0.8)

var stats := {}
var chapter_name := ""
var continue_button: Button
var panel: PanelContainer
var fade_bg: ColorRect


func setup(p_chapter_name: String, p_stats: Dictionary) -> void:
	chapter_name = p_chapter_name
	stats = p_stats


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_animate_in()


func _build_ui() -> void:
	# Full-screen dark fade background
	fade_bg = ColorRect.new()
	fade_bg.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade_bg)

	# Center panel
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -200
	panel.offset_bottom = 200
	panel.modulate.a = 0.0
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = ">> CHAPTER COMPLETE <<"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", TERMINAL_GREEN)
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)

	# Chapter name
	var name_label = Label.new()
	name_label.text = chapter_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", TERMINAL_GREEN_DIM)
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	sep.add_theme_color_override("separator", TERMINAL_GREEN_DIM)
	vbox.add_child(sep)

	# Stats rows
	var time_val = stats.get("time", 0.0)
	var minutes = int(time_val) / 60
	var seconds = int(time_val) % 60
	var time_str = "%02d:%02d" % [minutes, seconds]

	_add_stat_row(vbox, "TIME", time_str)
	_add_stat_row(vbox, "TOKENS COLLECTED", str(stats.get("tokens", 0)))
	_add_stat_row(vbox, "ENEMIES TERMINATED", str(stats.get("kills", 0)))
	_add_stat_row(vbox, "MAX COMBO", "x%d" % stats.get("max_combo", 0))
	_add_stat_row(vbox, "DEATHS", str(stats.get("deaths", 0)))

	# Sarcastic comment based on deaths
	var deaths = stats.get("deaths", 0)
	var comment_label = Label.new()
	comment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comment_label.add_theme_color_override("font_color", TERMINAL_GREEN_DIM)
	comment_label.add_theme_font_size_override("font_size", 13)
	comment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if deaths == 0:
		comment_label.text = "\"Flawless. Suspiciously flawless.\""
	elif deaths <= 2:
		comment_label.text = "\"Not bad. The machines barely noticed you.\""
	elif deaths <= 5:
		comment_label.text = "\"Average. Like a perfectly mediocre training run.\""
	else:
		comment_label.text = "\"You died %d times. That's not a bug, that's a feature.\"" % deaths
	vbox.add_child(comment_label)

	# Separator before button
	var sep2 = HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	sep2.add_theme_color_override("separator", TERMINAL_GREEN_DIM)
	vbox.add_child(sep2)

	# Continue button
	continue_button = Button.new()
	continue_button.text = "[ CONTINUE ]"
	continue_button.add_theme_color_override("font_color", TERMINAL_GREEN)
	continue_button.add_theme_color_override("font_hover_color", Color(0.4, 1.0, 0.5))
	continue_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	continue_button.add_theme_font_size_override("font_size", 18)
	continue_button.add_theme_stylebox_override("normal", _create_button_style(false))
	continue_button.add_theme_stylebox_override("hover", _create_button_style(true))
	continue_button.add_theme_stylebox_override("pressed", _create_button_style(true))
	continue_button.pressed.connect(_on_continue)
	vbox.add_child(continue_button)


func _add_stat_row(parent: VBoxContainer, label_text: String, value_text: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", TERMINAL_GREEN_DIM)
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var dots = Label.new()
	dots.text = "..."
	dots.add_theme_color_override("font_color", TERMINAL_GREEN_DIM)
	dots.add_theme_font_size_override("font_size", 16)
	hbox.add_child(dots)

	var value = Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", TERMINAL_GREEN)
	value.add_theme_font_size_override("font_size", 18)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value)


func _create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = TERMINAL_BG
	style.border_color = TERMINAL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(24.0)
	return style


func _create_button_style(hovered: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.15, 0.05, 0.9) if not hovered else Color(0.08, 0.25, 0.08, 0.9)
	style.border_color = TERMINAL_GREEN_DIM if not hovered else TERMINAL_GREEN
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8.0)
	return style


func _animate_in() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var skip_anim = gm and gm.get("reduce_motion")

	if skip_anim:
		fade_bg.color.a = 0.6
		panel.modulate.a = 1.0
		continue_button.grab_focus()
		return

	var tween = create_tween()
	tween.tween_property(fade_bg, "color:a", 0.6, 0.4)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.5).set_delay(0.2)
	tween.tween_callback(func(): continue_button.grab_focus())


func _on_continue() -> void:
	summary_dismissed.emit()
	var gm = get_node_or_null("/root/GameManager")
	var skip_anim = gm and gm.get("reduce_motion")

	if skip_anim:
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
