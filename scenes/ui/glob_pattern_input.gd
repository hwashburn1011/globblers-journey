extends PanelContainer

# Glob Pattern Input - Terminal-style display showing current glob pattern
# "$ glob _" — the blinking cursor of destruction

var _current_pattern := ""
var _blink_timer := 0.0
var _cursor_visible := true

@onready var pattern_label: Label
@onready var result_label: Label

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	# Dark terminal style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.02, 0.9)
	style.border_color = Color(0.224, 1.0, 0.078, 0.5)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)

	# Position top center
	anchor_left = 0.3
	anchor_top = 0.02
	anchor_right = 0.7
	anchor_bottom = 0.08

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	pattern_label = Label.new()
	pattern_label.name = "PatternLabel"
	pattern_label.text = "$ glob "
	pattern_label.add_theme_color_override("font_color", Color(0.224, 1.0, 0.078))
	pattern_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(pattern_label)

	result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.text = ""
	result_label.add_theme_color_override("font_color", Color(0.25, 0.75, 0.25, 0.85))
	result_label.add_theme_font_size_override("font_size", 13)
	result_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	result_label.add_theme_constant_override("shadow_offset_x", 1)
	result_label.add_theme_constant_override("shadow_offset_y", 1)
	result_label.add_theme_constant_override("shadow_outline_size", 2)
	vbox.add_child(result_label)

func _process(delta: float) -> void:
	if not visible:
		return
	# Blinking cursor
	_blink_timer += delta
	if _blink_timer >= 0.5:
		_blink_timer = 0.0
		_cursor_visible = not _cursor_visible
	if pattern_label:
		var cursor = "_" if _cursor_visible else " "
		pattern_label.text = "$ glob %s%s" % [_current_pattern, cursor]

func show_pattern(pattern: String) -> void:
	_current_pattern = pattern
	visible = true
	if result_label:
		result_label.text = ""

func show_result(count: int) -> void:
	if result_label:
		if count > 0:
			result_label.text = "matched %d target%s" % [count, "s" if count != 1 else ""]
		else:
			result_label.text = "no matches found"

func hide_input() -> void:
	visible = false
	_current_pattern = ""
