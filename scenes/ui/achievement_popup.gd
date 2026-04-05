extends CanvasLayer
# Achievement popup — slides in from bottom-right, lingers 3s, slides out

const TERMINAL_GREEN := Color("#39FF14")
const DIM_GREEN := Color(0.15, 0.3, 0.15, 1.0)
const BG_COLOR := Color(0.02, 0.04, 0.02, 0.95)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.9)

const SLIDE_DURATION := 0.4
const DISPLAY_DURATION := 3.0

var _panel: PanelContainer
var _queue: Array = []  # queued achievements if multiple fire at once
var _showing := false

func _ready() -> void:
	layer = 110  # Above everything
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(_id: String, title: String, desc: String) -> void:
	_queue.append({ "title": title, "desc": desc })
	if not _showing:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var data = _queue.pop_front()
	_build_popup(data["title"], data["desc"])

func _build_popup(title: String, desc: String) -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 80)
	var style = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = DIM_GREEN
	style.set_border_width_all(2)
	style.border_color = TERMINAL_GREEN
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)

	# Anchor bottom-right
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -340
	_panel.offset_top = -100
	_panel.offset_right = -20
	_panel.offset_bottom = -20

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	_panel.add_child(hbox)

	# Trophy icon
	var icon_label = Label.new()
	icon_label.text = "★"
	icon_label.add_theme_color_override("font_color", TERMINAL_GREEN)
	icon_label.add_theme_font_size_override("font_size", 28)
	icon_label.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	icon_label.add_theme_constant_override("shadow_outline_size", 2)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var title_label = Label.new()
	title_label.text = "ACHIEVEMENT: %s" % title
	title_label.add_theme_color_override("font_color", TERMINAL_GREEN)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	title_label.add_theme_constant_override("shadow_outline_size", 2)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title_label)

	var desc_label = Label.new()
	desc_label.text = desc
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.5, 0.85))
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	desc_label.add_theme_constant_override("shadow_outline_size", 2)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	add_child(_panel)

	# Play UI sound
	if AudioManager:
		AudioManager.play_sfx("ui_click")

	# Slide in from below, display, slide out
	_panel.modulate.a = 0.0
	var start_offset = _panel.offset_bottom + 100
	_panel.offset_top += 100
	_panel.offset_bottom += 100

	var tween = create_tween()
	# Slide in
	tween.set_parallel(true)
	tween.tween_property(_panel, "offset_top", start_offset - 100 - 80, SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "offset_bottom", start_offset - 100, SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "modulate:a", 1.0, SLIDE_DURATION * 0.5)
	tween.set_parallel(false)
	# Hold
	tween.tween_interval(DISPLAY_DURATION)
	# Slide out
	tween.set_parallel(true)
	tween.tween_property(_panel, "offset_top", start_offset, SLIDE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_panel, "offset_bottom", start_offset + 80, SLIDE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_panel, "modulate:a", 0.0, SLIDE_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(_on_popup_done)

func _on_popup_done() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	_show_next()
