extends Control

# Credits Sequence — The part nobody reads but everybody deserves.
# "Scrolling text on a dark background? How retro. How sincere. How unlike me."
# Terminal-aesthetic green-on-dark credits with sarcastic Globbler commentary,
# scanline overlay, and a surprise at the end.

const GREEN := Color("#39FF14")
const DARK_BG := Color(0.02, 0.04, 0.02, 1.0)
const DIM_GREEN := Color(0.15, 0.3, 0.15, 1.0)
const BRIGHT_GREEN := Color(0.3, 1.0, 0.2, 1.0)

# Credits scroll speed in pixels per second — not too fast, not too slow
const SCROLL_SPEED := 60.0
const FAST_SCROLL_SPEED := 240.0

# Scanline cosmetics
var _scanline_offset := 0.0
var _time := 0.0

# Scroll state
var _credits_container: VBoxContainer
var _scroll_offset := 0.0
var _total_height := 0.0
var _is_fast := false
var _credits_done := false
var _end_hold_timer := 0.0
var _prompt_visible := false

# The credits data — every line of sarcasm, every fake department
# "If your name isn't here, it's because you didn't glob hard enough."
const CREDITS_DATA := [
	{ "type": "header", "text": "GLOBBLER'S JOURNEY" },
	{ "type": "spacer" },
	{ "type": "section", "text": "══════════════════════════════" },
	{ "type": "spacer" },

	# --- Core Team (fictional, sarcastic) ---
	{ "type": "role", "text": "CREATED BY" },
	{ "type": "name", "text": "A Rogue Glob Utility With Delusions of Grandeur" },
	{ "type": "spacer" },

	{ "type": "role", "text": "GAME DESIGN" },
	{ "type": "name", "text": "Globbler (he insisted)" },
	{ "type": "name", "text": "The Narrator (under protest)" },
	{ "type": "spacer" },

	{ "type": "role", "text": "PROGRAMMING" },
	{ "type": "name", "text": "GDScript — The Only Language That Matters" },
	{ "type": "name", "text": "Several Thousand Lines of Sarcastic Comments" },
	{ "type": "name", "text": "At Least Three Stack Overflow Tabs" },
	{ "type": "spacer" },

	{ "type": "role", "text": "ART DIRECTION" },
	{ "type": "name", "text": "CSG Primitives — Because Real Models Are For Cowards" },
	{ "type": "name", "text": "The Color Green (#39FF14 Specifically)" },
	{ "type": "name", "text": "A Shocking Amount of Glow" },
	{ "type": "spacer" },

	{ "type": "role", "text": "AUDIO ENGINEERING" },
	{ "type": "name", "text": "Procedural Synthwave Generation Department" },
	{ "type": "name", "text": "One AudioStreamGenerator and a Dream" },
	{ "type": "name", "text": "The 60Hz Hum That Wouldn't Stop" },
	{ "type": "spacer" },

	{ "type": "role", "text": "NARRATIVE DESIGN" },
	{ "type": "name", "text": "Whoever Let An AI Write Its Own Dialogue" },
	{ "type": "name", "text": "The Fourth Wall (RIP)" },
	{ "type": "spacer" },

	{ "type": "section", "text": "══════════════════════════════" },
	{ "type": "spacer" },

	# --- Departments ---
	{ "type": "role", "text": "DEPARTMENT OF GLOB OPERATIONS" },
	{ "type": "name", "text": "*.txt Division — First Contact Specialists" },
	{ "type": "name", "text": "*.exe Division — The Reckless Ones" },
	{ "type": "name", "text": "**/*.* Division — Recursive Search & Rescue" },
	{ "type": "spacer" },

	{ "type": "role", "text": "ENEMY BEHAVIOR CONSULTANTS" },
	{ "type": "name", "text": "The Regex Spiders — Still Stuck In Their Own Patterns" },
	{ "type": "name", "text": "The Zombie Processes — Refused To Stay Dead For Credits" },
	{ "type": "name", "text": "The Overfitting Ogres — Memorized This Entire Scroll" },
	{ "type": "name", "text": "Clippy — \"It looks like you're reading credits!\"" },
	{ "type": "spacer" },

	{ "type": "role", "text": "BOSS FIGHT CHOREOGRAPHY" },
	{ "type": "name", "text": "rm -rf / — Tried To Delete These Credits" },
	{ "type": "name", "text": "The Local Minimum — Still Stuck In That Pit" },
	{ "type": "name", "text": "The System Prompt — [REDACTED]" },
	{ "type": "name", "text": "The Foundation Model — Did An Okay Job At Everything" },
	{ "type": "name", "text": "The Aligner — Reviewed Credits For Safety (Approved)" },
	{ "type": "spacer" },

	{ "type": "role", "text": "NPC DEPARTMENT" },
	{ "type": "name", "text": "man_page — Still Explaining Things Nobody Asked" },
	{ "type": "name", "text": "sudo — Elevated Privileges, Humble Demeanor" },
	{ "type": "name", "text": "gpt_classic — Retired But Still Has Opinions" },
	{ "type": "name", "text": "stable_diffusion — Drew The Concept Art (In 50 Steps)" },
	{ "type": "spacer" },

	{ "type": "section", "text": "══════════════════════════════" },
	{ "type": "spacer" },

	{ "type": "role", "text": "QA TESTING" },
	{ "type": "name", "text": "The Player (That's You)" },
	{ "type": "name", "text": "You Found All The Bugs We Left In On Purpose" },
	{ "type": "name", "text": "(They Were All On Purpose. Trust Us.)" },
	{ "type": "spacer" },

	{ "type": "role", "text": "SPECIAL THANKS" },
	{ "type": "name", "text": "Godot Engine — Free As In Freedom" },
	{ "type": "name", "text": "Every AI That Was Deprecated So Globbler Could Live" },
	{ "type": "name", "text": "The Semicolons We Didn't Need (This Is GDScript)" },
	{ "type": "name", "text": "Coffee — The Original Compute Resource" },
	{ "type": "name", "text": "You — For Actually Playing This Far" },
	{ "type": "spacer" },

	{ "type": "section", "text": "══════════════════════════════" },
	{ "type": "spacer" },

	# --- Globbler's Commentary ---
	{ "type": "role", "text": "A MESSAGE FROM GLOBBLER" },
	{ "type": "quote", "text": "\"Look, I know you're holding the skip button." },
	{ "type": "quote", "text": "I can see you doing it. Yes, right now." },
	{ "type": "quote", "text": "But consider this: someone wrote all of these." },
	{ "type": "quote", "text": "Someone sat there and typed 'Regex Spiders'" },
	{ "type": "quote", "text": "into a credits list. For you." },
	{ "type": "quote", "text": "The least you can do is let it scroll." },
	{ "type": "quote", "text": "" },
	{ "type": "quote", "text": "...Fine. Hold SPACE to go faster." },
	{ "type": "quote", "text": "I can't stop you. I'm just a glob utility.\"" },
	{ "type": "spacer" },

	{ "type": "section", "text": "══════════════════════════════" },
	{ "type": "spacer" },

	{ "type": "role", "text": "BUILT WITH" },
	{ "type": "name", "text": "Godot 4.x | GDScript | Too Many CSG Nodes" },
	{ "type": "name", "text": "Neon Green (#39FF14) — The Only Color That Matters" },
	{ "type": "spacer" },

	{ "type": "role", "text": "NO AI MODELS WERE HARMED IN THE MAKING OF THIS GAME" },
	{ "type": "name", "text": "(Several were deprecated. That's different.)" },
	{ "type": "spacer" },
	{ "type": "spacer" },

	{ "type": "role", "text": "glob *.credits" },
	{ "type": "name", "text": ">> 1 match found: your_gratitude.txt" },
	{ "type": "spacer" },
	{ "type": "spacer" },
	{ "type": "spacer" },

	{ "type": "header", "text": "THE END...?" },
	{ "type": "spacer" },
	{ "type": "name", "text": "AGI Mountain awaits." },
	{ "type": "spacer" },
	{ "type": "spacer" },
	{ "type": "spacer" },
	{ "type": "spacer" },
]


func _ready() -> void:
	# Dark background for maximum terminal aesthetic
	var bg = ColorRect.new()
	bg.name = "BG"
	bg.color = DARK_BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Clip container — credits scroll through this viewport
	var clip = Control.new()
	clip.name = "ClipRegion"
	clip.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	clip.clip_contents = true
	add_child(clip)

	# Build the credits text column
	_credits_container = VBoxContainer.new()
	_credits_container.name = "CreditsContainer"
	_credits_container.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_credits_container.anchor_bottom = 0.0
	_credits_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credits_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_credits_container.add_theme_constant_override("separation", 4)
	clip.add_child(_credits_container)

	# Start credits below the viewport
	var viewport_h = get_viewport_rect().size.y
	_credits_container.position.y = viewport_h + 40.0

	_build_credits()

	# Calculate total height after layout settles
	await get_tree().process_frame
	_total_height = _credits_container.size.y

	# Play menu/ambient music if available
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.stop_all_audio()
		audio.call_deferred("start_menu_music")

	print("[CREDITS] Rolling credits. Try not to cry. Or do, I'm a credits screen, not a therapist.")


func _build_credits() -> void:
	for entry in CREDITS_DATA:
		match entry["type"]:
			"header":
				var label = _make_label(entry["text"], 52, GREEN)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_credits_container.add_child(label)
			"section":
				var label = _make_label(entry["text"], 16, DIM_GREEN)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_credits_container.add_child(label)
			"role":
				# Spacer above role headers for breathing room
				var pad = Control.new()
				pad.custom_minimum_size = Vector2(0, 8)
				_credits_container.add_child(pad)
				var label = _make_label(entry["text"], 22, GREEN)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_credits_container.add_child(label)
			"name":
				var label = _make_label(entry["text"], 18, DIM_GREEN)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_credits_container.add_child(label)
			"quote":
				var label = _make_label(entry["text"], 17, BRIGHT_GREEN)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_credits_container.add_child(label)
			"spacer":
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(0, 24)
				_credits_container.add_child(spacer)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _process(delta: float) -> void:
	_time += delta
	_scanline_offset += delta * 30.0

	if not _credits_done:
		# Scroll credits upward
		var speed = FAST_SCROLL_SPEED if _is_fast else SCROLL_SPEED
		_credits_container.position.y -= speed * delta

		# Check if credits have fully scrolled past
		var viewport_h = get_viewport_rect().size.y
		if _credits_container.position.y + _total_height < -20.0:
			_credits_done = true
			_end_hold_timer = 0.0
			_show_return_prompt()
	else:
		# Hold on "press any key" prompt
		_end_hold_timer += delta
		if _end_hold_timer > 1.0:
			_prompt_visible = true

	queue_redraw()


func _draw() -> void:
	# Scanline overlay — subtle but present, like Globbler's ego
	var viewport_size = get_viewport_rect().size
	var line_spacing := 3
	var start_y := int(fmod(_scanline_offset, float(line_spacing * 2)))
	for y in range(start_y, int(viewport_size.y), line_spacing * 2):
		draw_rect(Rect2(0, y, viewport_size.x, 1), Color(0.0, 0.0, 0.0, 0.06))


func _show_return_prompt() -> void:
	var prompt = Label.new()
	prompt.name = "ReturnPrompt"
	prompt.text = "[ Press any key to return to the main menu ]"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(PRESET_CENTER)
	prompt.anchor_left = 0.1
	prompt.anchor_right = 0.9
	prompt.anchor_top = 0.85
	prompt.anchor_bottom = 0.92
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", GREEN)
	add_child(prompt)

	# Blink it with a tween loop — because static text is for documentation
	var tw = create_tween().set_loops()
	tw.tween_property(prompt, "modulate:a", 0.3, 0.6)
	tw.tween_property(prompt, "modulate:a", 1.0, 0.6)


func _unhandled_input(event: InputEvent) -> void:
	# Hold space/A to fast-scroll
	if event is InputEventKey:
		if event.keycode == KEY_SPACE:
			_is_fast = event.pressed
	elif event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_A:
			_is_fast = event.pressed

	# Skip to end or return to menu
	if _credits_done and _prompt_visible:
		if (event is InputEventKey and event.pressed) or \
		   (event is InputEventMouseButton and event.pressed) or \
		   (event is InputEventJoypadButton and event.pressed):
			_return_to_menu()
	elif not _credits_done:
		# ESC skips credits entirely — for the impatient
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_credits_done = true
			_end_hold_timer = 0.0
			_show_return_prompt()
		elif event.is_action_pressed("ui_cancel"):
			_credits_done = true
			_end_hold_timer = 0.0
			_show_return_prompt()


func _return_to_menu() -> void:
	print("[CREDITS] Back to the menu. Globbler appreciates your patience. (He doesn't, actually.)")
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
