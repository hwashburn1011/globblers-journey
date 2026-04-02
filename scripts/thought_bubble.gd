extends Label

# Floating sarcastic thought bubble for The Globbler
# DEPRECATED: This script is unused. The HUD handles thought display now.
# Kept around for sentimental reasons. Like deprecated APIs that refuse to die.

var display_time := 3.0
var fade_timer := 0.0
var is_showing := false

func _ready() -> void:
	text = ""
	modulate.a = 0.0
	add_theme_font_size_override("font_size", 14)

func show_thought(thought: String) -> void:
	text = thought
	modulate.a = 1.0
	fade_timer = display_time
	is_showing = true

func _process(delta: float) -> void:
	if is_showing:
		fade_timer -= delta
		if fade_timer <= 1.0:
			modulate.a = max(0.0, fade_timer)
		if fade_timer <= 0.0:
			is_showing = false
			text = ""
