extends VBoxContainer

# Context Window Bar - Visual representation of Globbler's memory/health
# "Watch it fill, watch it drain. The existential dread of a finite context window."

@onready var bar: ProgressBar
@onready var label: Label
@onready var value_label: Label

var _target_value := 100.0
var _current_display := 100.0
const LERP_SPEED := 5.0

func _ready() -> void:
	_build_ui()

	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.context_changed.connect(_on_context_changed)
		_target_value = float(game_mgr.context_window)
		_current_display = _target_value

func _build_ui() -> void:
	add_theme_constant_override("separation", 2)
	custom_minimum_size = Vector2(240, 0)

	# Label
	label = Label.new()
	label.name = "ContextLabel"
	label.text = "CONTEXT WINDOW"
	label.add_theme_color_override("font_color", Color(0.224, 1.0, 0.078))
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)

	# The bar itself
	bar = ProgressBar.new()
	bar.name = "ContextBar"
	bar.max_value = 100
	bar.value = 100
	bar.custom_minimum_size = Vector2(240, 24)
	bar.show_percentage = false

	# Green fill
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.1, 0.5, 0.15)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)

	# Dark background
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.06, 0.03)
	bg.border_color = Color(0.15, 0.5, 0.15)
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)
	add_child(bar)

	# Numeric value
	value_label = Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "100 / 100"
	value_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 0.7))
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(value_label)

func _process(delta: float) -> void:
	# Smooth bar animation
	_current_display = lerp(_current_display, _target_value, LERP_SPEED * delta)
	if bar:
		bar.value = _current_display

	# Color shifts based on health
	var fill = bar.get_theme_stylebox("fill") as StyleBoxFlat if bar else null
	if fill:
		if _target_value < 25:
			fill.bg_color = Color(0.9, 0.1, 0.1)  # Critical red
		elif _target_value < 50:
			fill.bg_color = Color(0.9, 0.5, 0.1)  # Warning orange
		else:
			fill.bg_color = Color(0.1, 0.5, 0.15)  # Healthy green

func _on_context_changed(new_value: int) -> void:
	_target_value = float(new_value)
	var game_mgr = get_node_or_null("/root/GameManager")
	var max_ctx = 100
	if game_mgr:
		max_ctx = game_mgr.max_context_window
	if bar:
		bar.max_value = max_ctx
	if value_label:
		value_label.text = "%d / %d" % [new_value, max_ctx]
