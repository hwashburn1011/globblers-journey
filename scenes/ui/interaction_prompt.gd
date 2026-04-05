extends CanvasLayer

# Interaction Prompt — context-sensitive "[KEY] ACTION" label near interactables
# "Press the blinking button. What could possibly go wrong?"

const PULSE_SPEED := 3.0
const PULSE_MIN_ALPHA := 0.5

var _label: Label
var _panel: PanelContainer
var _active := false
var _current_text := ""

# Reduce-motion: skip pulsing
var _reduce_motion := false


func _ready() -> void:
	layer = 5
	_build_ui()
	_set_visible(false)

	var gm = get_node_or_null("/root/GameManager")
	if gm and "reduce_motion" in gm:
		_reduce_motion = gm.reduce_motion


func _build_ui() -> void:
	var control := Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Anchor to bottom-center, above the player's head area
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.65
	_panel.anchor_bottom = 0.65
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.02, 0.85)
	style.border_color = Color(0.224, 1.0, 0.078, 0.7)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 16.0
	style.content_margin_top = 6.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 6.0
	_panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.name = "PromptLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(0.224, 1.0, 0.078))
	_label.add_theme_font_size_override("font_size", 18)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Use terminal mono font if available
	var font_path := "res://assets/fonts/terminal_mono.ttf"
	if ResourceLoader.exists(font_path):
		var font := load(font_path) as Font
		if font:
			_label.add_theme_font_override("font", font)

	_panel.add_child(_label)
	control.add_child(_panel)


func _process(delta: float) -> void:
	if not _active:
		return

	# Pulse alpha for attention
	if _reduce_motion:
		_panel.modulate.a = 1.0
	else:
		var pulse := (sin(Time.get_ticks_msec() * 0.001 * PULSE_SPEED) + 1.0) * 0.5
		_panel.modulate.a = lerpf(PULSE_MIN_ALPHA, 1.0, pulse)


func show_prompt(text: String) -> void:
	if _active and _current_text == text:
		return
	_current_text = text
	_label.text = text
	_set_visible(true)


func hide_prompt() -> void:
	if not _active:
		return
	_current_text = ""
	_set_visible(false)


func _set_visible(vis: bool) -> void:
	_active = vis
	_panel.visible = vis
	if not vis:
		_panel.modulate.a = 1.0
