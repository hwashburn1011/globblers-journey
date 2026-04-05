extends PanelContainer

# Dialogue Box - Terminal-style text display for story and quips
# "Dark background, green text, typing animation. Peak hacker aesthetic."
# Looks like a retro terminal window because Globbler refuses to use modern UI.

const DEFAULT_TYPING_SPEED := 0.03  # Fallback if GameManager is AWOL
const FAST_TYPING_SPEED := 0.005  # When player is mashing through
const TYPE_SFX_INTERVAL := 3  # Play a typing blip every N characters — not every one, we're not a typewriter factory

var _full_text := ""
var _displayed_chars := 0
var _typing := false
var _typing_timer := 0.0
var _fast_mode := false

var speaker_label: Label
var text_label: RichTextLabel
var advance_hint: Label
var scanline_overlay: ColorRect

signal typing_finished()
signal advanced()

func _ready() -> void:
	visible = false
	_build_ui()
	# Wire up to DialogueManager signals — the typing animation was built but never plugged in.
	# Classic "the code exists but nobody told it to run" situation.
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		dm.dialogue_started.connect(show_line)
		dm.dialogue_ended.connect(hide_box)

func _build_ui() -> void:
	# Terminal-style panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.04, 0.04, 0.95)
	panel_style.border_color = Color(0.224, 1.0, 0.078, 0.7)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", panel_style)

	# Anchoring at bottom center
	anchors_preset = Control.PRESET_CENTER_BOTTOM
	anchor_left = 0.1
	anchor_top = 0.75
	anchor_right = 0.9
	anchor_bottom = 0.95
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	# VBox for layout
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Speaker name
	speaker_label = Label.new()
	speaker_label.name = "SpeakerLabel"
	speaker_label.text = ""
	speaker_label.add_theme_color_override("font_color", Color(0.224, 1.0, 0.078))
	speaker_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(speaker_label)

	# Main text — RichTextLabel for typing effect
	text_label = RichTextLabel.new()
	text_label.name = "TextLabel"
	text_label.bbcode_enabled = true
	text_label.text = ""
	text_label.add_theme_color_override("default_color", Color(0.3, 0.9, 0.3))
	text_label.add_theme_font_size_override("normal_font_size", 18)
	text_label.custom_minimum_size = Vector2(0, 60)
	text_label.scroll_active = false
	text_label.fit_content = true
	vbox.add_child(text_label)

	# "Click to continue" hint
	advance_hint = Label.new()
	advance_hint.name = "AdvanceHint"
	advance_hint.text = "> click / SPACE / A button to continue..."
	advance_hint.add_theme_color_override("font_color", Color(0.25, 0.65, 0.25, 0.8))
	advance_hint.add_theme_font_size_override("font_size", 12)
	advance_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	advance_hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	advance_hint.add_theme_constant_override("shadow_offset_x", 1)
	advance_hint.add_theme_constant_override("shadow_offset_y", 1)
	advance_hint.add_theme_constant_override("shadow_outline_size", 2)
	advance_hint.visible = false
	vbox.add_child(advance_hint)

	# Scanline + flicker overlay — CRT aesthetic for the dialogue panel
	scanline_overlay = ColorRect.new()
	scanline_overlay.name = "ScanlineOverlay"
	scanline_overlay.color = Color(1, 1, 1, 1)
	scanline_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanline_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader_res = load("res://assets/shaders/dialogue_scanline.gdshader")
	if shader_res:
		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		scanline_overlay.material = mat
		# Respect reduce_motion toggle
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.get("reduce_motion"):
			mat.set_shader_parameter("animate", false)
	add_child(scanline_overlay)

func show_line(speaker: String, text: String) -> void:
	visible = true
	_full_text = text
	_displayed_chars = 0
	_typing = true
	_typing_timer = 0.0
	_fast_mode = false

	if speaker_label:
		speaker_label.text = "[%s]" % speaker if speaker != "" else ""
	if text_label:
		text_label.text = ""
	if advance_hint:
		advance_hint.visible = false

func hide_box() -> void:
	visible = false
	_typing = false

func _process(delta: float) -> void:
	if not _typing:
		return

	var base_speed := DEFAULT_TYPING_SPEED
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		base_speed = gm.dialogue_char_delay
	var speed = FAST_TYPING_SPEED if _fast_mode else base_speed
	_typing_timer += delta
	while _typing_timer >= speed and _displayed_chars < _full_text.length():
		_typing_timer -= speed
		_displayed_chars += 1
		if text_label:
			text_label.text = "> " + _full_text.substr(0, _displayed_chars)
		# Periodic typing blip — every few chars, skip spaces for that authentic terminal feel
		if not _fast_mode and _displayed_chars % TYPE_SFX_INTERVAL == 0:
			var ch = _full_text[_displayed_chars - 1]
			if ch != " " and ch != "\n":
				var audio = get_node_or_null("/root/AudioManager")
				if audio and audio.has_method("play_sfx"):
					audio.play_sfx("dialogue_type")

	if _displayed_chars >= _full_text.length():
		_typing = false
		if advance_hint:
			advance_hint.visible = true
		typing_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# ESC during dialogue = skip the ENTIRE sequence, not just this line
	# Consume the event so it doesn't also toggle the pause menu — Globbler's monologues are bad enough without freezing mid-sentence
	if event.is_action_pressed("pause"):
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.is_dialogue_active():
			dm.skip_all()
			get_viewport().set_input_as_handled()
			return

	# Advance dialogue: SPACE / Enter / LClick / A button — all roads lead to "next line"
	var clicked = event.is_action_pressed("dialogue_advance")

	if clicked:
		if _typing:
			# Skip typing animation
			_fast_mode = true
		else:
			# Advance to next line
			advanced.emit()
			var dm = get_node_or_null("/root/DialogueManager")
			if dm:
				dm.advance()

func is_typing() -> bool:
	return _typing
