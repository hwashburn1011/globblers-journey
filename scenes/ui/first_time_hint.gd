extends CanvasLayer

# First-Time Hint Toast — because apparently players need instructions.
# Slides in from the top like an unsolicited notification from your OS.
# Auto-dismisses after 4 seconds because your attention span is... oh look, a butterfly.

const GREEN := Color("#39FF14")
const DIM_GREEN := Color(0.15, 0.3, 0.15, 1.0)
const DARK_BG := Color(0.04, 0.04, 0.04, 0.95)
const BORDER_GREEN := Color(0.224, 1.0, 0.078, 0.7)

const SLIDE_DURATION := 0.4
const DISPLAY_DURATION := 4.0

var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _dismiss_timer: SceneTreeTimer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_hint(title: String, body: String) -> void:
	# Build fresh each time — hints are one-shot throwaways
	_build_ui(title, body)
	_slide_in()


func _build_ui(title: String, body: String) -> void:
	# Kill any existing hint panel — only one toast at a time, we're not a bakery
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null

	_panel = PanelContainer.new()

	# Terminal-style panel styling
	var style = StyleBoxFlat.new()
	style.bg_color = DARK_BG
	style.border_color = BORDER_GREEN
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 20.0
	style.content_margin_top = 12.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", style)

	# Anchor at top center, offset above screen for slide-in
	_panel.anchor_left = 0.2
	_panel.anchor_right = 0.8
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_top = -200
	_panel.offset_bottom = -10
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# Top decorative border
	var border_top = Label.new()
	border_top.text = "══════════ HINT ══════════"
	border_top.add_theme_color_override("font_color", DIM_GREEN)
	border_top.add_theme_font_size_override("font_size", 12)
	border_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(border_top)

	# Title
	_title_label = Label.new()
	_title_label.text = "> %s" % title
	_title_label.add_theme_color_override("font_color", GREEN)
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Body text
	_body_label = Label.new()
	_body_label.text = body
	_body_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_body_label)

	# Footer
	var footer = Label.new()
	footer.text = "[ press any key to dismiss ]"
	footer.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2, 0.5))
	footer.add_theme_font_size_override("font_size", 12)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(footer)

	add_child(_panel)


func _slide_in() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel, "offset_top", 20.0, SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Auto-dismiss timer — you had your chance to read it
	_dismiss_timer = get_tree().create_timer(DISPLAY_DURATION + SLIDE_DURATION)
	_dismiss_timer.timeout.connect(_slide_out)


func _slide_out() -> void:
	if not _panel or not is_instance_valid(_panel):
		return
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel, "offset_top", -200.0, SLIDE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(_cleanup)


func _cleanup() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	# Any key press dismisses early — we respect your impatience
	if event is InputEventKey and event.pressed and not event.echo:
		_dismiss_early()
	elif event is InputEventMouseButton and event.pressed:
		_dismiss_early()
	elif event is InputEventJoypadButton and event.pressed:
		_dismiss_early()


func _dismiss_early() -> void:
	if _dismiss_timer:
		# Can't cancel a SceneTreeTimer, but we can just slide out now
		_dismiss_timer = null
	_slide_out()
