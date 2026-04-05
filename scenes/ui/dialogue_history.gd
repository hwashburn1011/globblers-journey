extends CanvasLayer

# Dialogue History Viewer — because players will absolutely demand receipts
# for every sarcastic thing Globbler ever said. Press H to open, ESC/H to close.
# Pauses the game while open, because multitasking is a myth.
# V2.0 restyle: terminal scrollback aesthetic, scanline shader, monospace font.

const GREEN := Color("#39FF14")
const DIM_GREEN := Color(0.15, 0.3, 0.15, 1.0)
const SOFT_GREEN := Color(0.3, 0.9, 0.3)
const DARK_BG := Color(0.04, 0.04, 0.04, 0.95)
const BORDER_GREEN := Color(0.224, 1.0, 0.078, 0.7)
const SPEAKER_COLORS := {
	"Globbler": Color("#39FF14"),
	"default": Color("#4AE0A5"),
}
const TIMESTAMP_COLOR := Color(0.2, 0.4, 0.2, 0.4)
const MAX_DISPLAY_ENTRIES := 30

var _panel: PanelContainer
var _scroll: ScrollContainer
var _entries_vbox: VBoxContainer
var _was_paused := false
var _reduce_motion := false

var _terminal_font: Font = preload("res://assets/fonts/terminal_mono.ttf")
var _scanline_shader: Shader = preload("res://assets/shaders/dialogue_scanline.gdshader")


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		_reduce_motion = true
	_build_ui()
	_populate_entries()
	# Pause the tree — reading old quips is a full-time job
	_was_paused = get_tree().paused
	get_tree().paused = true


func _build_ui() -> void:
	_panel = PanelContainer.new()

	# Terminal-style panel with thick green border
	var style = StyleBoxFlat.new()
	style.bg_color = DARK_BG
	style.border_color = BORDER_GREEN
	style.set_border_width_all(3)
	style.set_corner_radius_all(2)
	style.content_margin_left = 24.0
	style.content_margin_top = 16.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 16.0
	_panel.add_theme_stylebox_override("panel", style)

	# Scanline shader overlay — subtle CRT terminal vibes
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = _scanline_shader
	shader_mat.set_shader_parameter("scanline_count", 120.0)
	shader_mat.set_shader_parameter("scanline_intensity", 0.05)
	shader_mat.set_shader_parameter("flicker_amount", 0.015)
	shader_mat.set_shader_parameter("noise_amount", 0.02)
	shader_mat.set_shader_parameter("vignette_strength", 0.25)
	shader_mat.set_shader_parameter("tint_strength", 0.03)
	shader_mat.set_shader_parameter("animate", not _reduce_motion)
	_panel.material = shader_mat

	# Full-screen with margins — like a terminal window that respects personal space
	_panel.anchor_left = 0.1
	_panel.anchor_right = 0.9
	_panel.anchor_top = 0.05
	_panel.anchor_bottom = 0.95
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(outer_vbox)

	# Top decorative border — terminal frame
	var border_top = Label.new()
	border_top.text = "╔════════════════ SCROLLBACK ════════════════╗"
	border_top.add_theme_color_override("font_color", DIM_GREEN)
	border_top.add_theme_font_override("font", _terminal_font)
	border_top.add_theme_font_size_override("font_size", 12)
	border_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(border_top)

	# Title
	var title = Label.new()
	title.text = "> DIALOGUE HISTORY"
	title.add_theme_color_override("font_color", GREEN)
	title.add_theme_font_override("font", _terminal_font)
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	# Entry count subtitle
	var dm = get_node_or_null("/root/DialogueManager")
	var count_text := "0 entries"
	if dm:
		var history: Array = dm.get_history()
		var shown := mini(history.size(), MAX_DISPLAY_ENTRIES)
		count_text = "%d of %d entries" % [shown, history.size()] if history.size() > MAX_DISPLAY_ENTRIES else "%d entries" % history.size()
	var subtitle = Label.new()
	subtitle.text = "  [%s]" % count_text
	subtitle.add_theme_color_override("font_color", TIMESTAMP_COLOR)
	subtitle.add_theme_font_override("font", _terminal_font)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(subtitle)

	# Scrollable container for entries
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(_scroll)

	_entries_vbox = VBoxContainer.new()
	_entries_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries_vbox.add_theme_constant_override("separation", 4)
	_scroll.add_child(_entries_vbox)

	# Bottom decorative border
	var border_bottom = Label.new()
	border_bottom.text = "╚════════════════════════════════════════════╝"
	border_bottom.add_theme_color_override("font_color", DIM_GREEN)
	border_bottom.add_theme_font_override("font", _terminal_font)
	border_bottom.add_theme_font_size_override("font_size", 12)
	border_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(border_bottom)

	# Footer with controls
	var footer = Label.new()
	footer.text = "[ H or ESC to close | Scroll to browse ]"
	footer.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2, 0.4))
	footer.add_theme_font_override("font", _terminal_font)
	footer.add_theme_font_size_override("font_size", 11)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(footer)

	add_child(_panel)


func _populate_entries() -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if not dm:
		_add_empty_message("No DialogueManager found. The narrator has gone AWOL.")
		return

	var history: Array = dm.get_history()
	if history.is_empty():
		_add_empty_message("No dialogue yet. Globbler hasn't been sarcastic enough. Give it time.")
		return

	# Show last MAX_DISPLAY_ENTRIES entries, oldest first (reading order)
	var start_idx: int = max(0, history.size() - MAX_DISPLAY_ENTRIES)
	for i in range(start_idx, history.size()):
		var entry: Dictionary = history[i]
		var idx := i + 1
		_add_entry(entry.get("speaker", "???"), entry.get("text", "..."), idx)

	# Scroll to bottom after a frame so the layout has settled
	_scroll.call_deferred("set_v_scroll", 999999)


func _add_entry(speaker: String, text: String, index: int) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Line number — dimmed timestamp-style index
	var line_lbl = Label.new()
	line_lbl.text = "%03d" % index
	line_lbl.add_theme_color_override("font_color", TIMESTAMP_COLOR)
	line_lbl.add_theme_font_override("font", _terminal_font)
	line_lbl.add_theme_font_size_override("font_size", 12)
	line_lbl.custom_minimum_size = Vector2(40, 0)
	line_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	hbox.add_child(line_lbl)

	# Speaker tag — colored per speaker, fixed width
	var speaker_lbl = Label.new()
	speaker_lbl.text = "[%s]" % speaker
	var speaker_color: Color = SPEAKER_COLORS.get(speaker, SPEAKER_COLORS["default"])
	speaker_lbl.add_theme_color_override("font_color", speaker_color)
	speaker_lbl.add_theme_font_override("font", _terminal_font)
	speaker_lbl.add_theme_font_size_override("font_size", 14)
	speaker_lbl.custom_minimum_size = Vector2(140, 0)
	speaker_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	hbox.add_child(speaker_lbl)

	# Dialogue text — softer green, wraps
	var text_lbl = Label.new()
	text_lbl.text = text
	text_lbl.add_theme_color_override("font_color", SOFT_GREEN)
	text_lbl.add_theme_font_override("font", _terminal_font)
	text_lbl.add_theme_font_size_override("font_size", 14)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_lbl)

	_entries_vbox.add_child(hbox)

	# Subtle separator — because even sarcasm needs paragraph breaks
	var sep = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color(0.2, 0.6, 0.2, 0.15)
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.add_theme_constant_override("separation", 2)
	_entries_vbox.add_child(sep)


func _add_empty_message(msg: String) -> void:
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", DIM_GREEN)
	lbl.add_theme_font_override("font", _terminal_font)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_entries_vbox.add_child(lbl)


func _close() -> void:
	get_tree().paused = _was_paused
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	# H or ESC closes — two exits because Globbler is generous like that
	if event.is_action_pressed("dialogue_history") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()
