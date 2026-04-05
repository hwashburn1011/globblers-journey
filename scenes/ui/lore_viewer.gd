extends CanvasLayer
# Lore Archive viewer — because even stolen data deserves a nice UI

const TERMINAL_GREEN := Color("#39FF14")
const DIM_GREEN := Color(0.15, 0.3, 0.15, 1.0)
const BRIGHT_GREEN := Color(0.3, 1.0, 0.2, 1.0)
const BG_COLOR := Color(0.02, 0.04, 0.02, 0.95)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.9)

var _list_container: VBoxContainer
var _body_label: RichTextLabel
var _title_label: Label
var _counter_label: Label
var _selected_id: String = ""

func _ready() -> void:
	layer = 101  # Above pause overlay
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build_ui()
	_populate_list()

func _build_ui() -> void:
	# Full screen dark background
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.02, 0.92)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Main panel — centered, large
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(700, 500)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = BG_COLOR
	panel_style.border_color = DIM_GREEN
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(3)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(root_vbox)

	# Header row: title + counter
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root_vbox.add_child(header)

	var header_title = Label.new()
	header_title.text = "╔═ LORE ARCHIVE ═╗"
	header_title.add_theme_color_override("font_color", TERMINAL_GREEN)
	header_title.add_theme_font_size_override("font_size", 24)
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_title)

	_counter_label = Label.new()
	_counter_label.add_theme_color_override("font_color", DIM_GREEN)
	_counter_label.add_theme_font_size_override("font_size", 16)
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter_label.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	_counter_label.add_theme_constant_override("shadow_outline_size", 2)
	header.add_child(_counter_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_separator_style())
	root_vbox.add_child(sep)

	# Content: left list + right body
	var content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content)

	# Left side: scrollable doc list
	var list_scroll = ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(220, 0)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(list_scroll)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", 4)
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list_container)

	# Vertical separator
	var vsep = VSeparator.new()
	vsep.add_theme_stylebox_override("separator", _make_separator_style())
	content.add_child(vsep)

	# Right side: title + body text
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	content.add_child(right_vbox)

	_title_label = Label.new()
	_title_label.text = "> Select a document..."
	_title_label.add_theme_color_override("font_color", TERMINAL_GREEN)
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	_title_label.add_theme_constant_override("shadow_outline_size", 2)
	right_vbox.add_child(_title_label)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = false
	_body_label.fit_content = false
	_body_label.scroll_active = true
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_color_override("default_color", Color(0.5, 0.85, 0.4, 0.9))
	_body_label.add_theme_font_size_override("normal_font_size", 14)
	right_vbox.add_child(_body_label)

	# Footer
	var footer = Label.new()
	footer.text = "[ESC] Close Archive"
	footer.add_theme_color_override("font_color", Color(0.2, 0.45, 0.2))
	footer.add_theme_font_size_override("font_size", 12)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	footer.add_theme_constant_override("shadow_outline_size", 2)
	root_vbox.add_child(footer)

func _populate_list() -> void:
	# Clear existing entries
	for child in _list_container.get_children():
		child.queue_free()

	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return

	var found: Dictionary = gm.lore_docs_found
	_counter_label.text = "%d / 15 collected" % found.size()

	if found.is_empty():
		var empty_label = Label.new()
		empty_label.text = "> No documents found yet.\n> Keep exploring, you data hoarder."
		empty_label.add_theme_color_override("font_color", DIM_GREEN)
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list_container.add_child(empty_label)
		return

	# Sort doc IDs for consistent ordering
	var ids = found.keys()
	ids.sort()

	for doc_id in ids:
		var doc = found[doc_id]
		var btn = Button.new()
		btn.text = "> " + doc["title"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(200, 30)
		btn.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		btn.add_theme_color_override("font_color", BRIGHT_GREEN)
		btn.add_theme_font_size_override("font_size", 13)

		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.0, 0.05, 0.0, 0.4)
		normal_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
		normal_style.set_content_margin_all(4)
		btn.add_theme_stylebox_override("normal", normal_style)

		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.0, 0.15, 0.0, 0.8)
		hover_style.border_color = TERMINAL_GREEN
		hover_style.set_border_width_all(1)
		hover_style.set_content_margin_all(4)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("focus", hover_style)

		var pressed_style = StyleBoxFlat.new()
		pressed_style.bg_color = Color(0.0, 0.25, 0.0, 0.9)
		pressed_style.border_color = TERMINAL_GREEN
		pressed_style.set_border_width_all(1)
		pressed_style.set_content_margin_all(4)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		var captured_id = doc_id
		btn.pressed.connect(func(): _select_doc(captured_id))
		btn.mouse_entered.connect(func(): btn.grab_focus())
		_list_container.add_child(btn)

func _select_doc(doc_id: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var found = gm.lore_docs_found
	if not found.has(doc_id):
		return
	_selected_id = doc_id
	var doc = found[doc_id]
	_title_label.text = ">> " + doc["title"]
	_body_label.text = doc["body"]

	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("ui_click")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("pause_close")
	queue_free()

func _make_separator_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = DIM_GREEN
	style.set_content_margin_all(0)
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style
