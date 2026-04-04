extends CanvasLayer

# Dialogue History Viewer — because players will absolutely demand receipts
# for every sarcastic thing Globbler ever said. Press H to open, ESC/H to close.
# Pauses the game while open, because multitasking is a myth.

const GREEN := Color("#39FF14")
const DIM_GREEN := Color(0.15, 0.3, 0.15, 1.0)
const SOFT_GREEN := Color(0.3, 0.9, 0.3)
const DARK_BG := Color(0.04, 0.04, 0.04, 0.95)
const BORDER_GREEN := Color(0.224, 1.0, 0.078, 0.7)
const MAX_DISPLAY_ENTRIES := 30

var _panel: PanelContainer
var _scroll: ScrollContainer
var _entries_vbox: VBoxContainer
var _was_paused := false


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_populate_entries()
	# Pause the tree — reading old quips is a full-time job
	_was_paused = get_tree().paused
	get_tree().paused = true


func _build_ui() -> void:
	_panel = PanelContainer.new()

	var style = StyleBoxFlat.new()
	style.bg_color = DARK_BG
	style.border_color = BORDER_GREEN
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 20.0
	style.content_margin_top = 16.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 16.0
	_panel.add_theme_stylebox_override("panel", style)

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

	# Header
	var header = Label.new()
	header.text = "══════════ DIALOGUE BACKLOG ══════════"
	header.add_theme_color_override("font_color", DIM_GREEN)
	header.add_theme_font_size_override("font_size", 14)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(header)

	var title = Label.new()
	title.text = "> DIALOGUE HISTORY"
	title.add_theme_color_override("font_color", GREEN)
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	# Scrollable container for entries
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(_scroll)

	_entries_vbox = VBoxContainer.new()
	_entries_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries_vbox.add_theme_constant_override("separation", 4)
	_scroll.add_child(_entries_vbox)

	# Footer with controls
	var footer = Label.new()
	footer.text = "[ H or ESC to close | Scroll to browse ]"
	footer.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2, 0.5))
	footer.add_theme_font_size_override("font_size", 12)
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
		_add_entry(entry.get("speaker", "???"), entry.get("text", "..."))

	# Scroll to bottom after a frame so the layout has settled
	_scroll.call_deferred("set_v_scroll", 999999)


func _add_entry(speaker: String, text: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Speaker tag — bright green, fixed width vibe
	var speaker_lbl = Label.new()
	speaker_lbl.text = "[%s]" % speaker
	speaker_lbl.add_theme_color_override("font_color", GREEN)
	speaker_lbl.add_theme_font_size_override("font_size", 14)
	speaker_lbl.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(speaker_lbl)

	# Dialogue text — softer green, wraps
	var text_lbl = Label.new()
	text_lbl.text = text
	text_lbl.add_theme_color_override("font_color", SOFT_GREEN)
	text_lbl.add_theme_font_size_override("font_size", 14)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_lbl)

	_entries_vbox.add_child(hbox)

	# Subtle separator — because even sarcasm needs paragraph breaks
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	sep.add_theme_constant_override("separation", 2)
	sep.modulate = Color(0.2, 0.6, 0.2, 0.2)
	_entries_vbox.add_child(sep)


func _add_empty_message(msg: String) -> void:
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", DIM_GREEN)
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
