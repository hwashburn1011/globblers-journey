extends Area3D

# Puzzle Terminal - ACTUALLY Interactive AI-themed puzzle stations
# No more auto-solving. You have to use your brain. Yes, even you.

enum PuzzleType {
	GLOB_MATCH,
	PROMPT_FIX,
	TOKEN_SORT,
	PERMISSION_GATE,
	HALLUCINATION,
}

@export var puzzle_type: PuzzleType = PuzzleType.GLOB_MATCH
@export var puzzle_id := 0
@export var is_solved := false
@export var has_timer := false
@export var time_limit := 15.0

var player_nearby := false
var puzzle_active := false
var puzzle_timer := 0.0
var selected_option := 0

# Puzzle data
var glob_puzzles := [
	{
		"prompt": "Find the secret config files hidden in the server.\nWhich glob pattern matches ONLY .config files?",
		"options": ["glob *.config", "glob *.txt", "glob **/*.*", "glob *.exe"],
		"correct": 0,
		"quip": "Ah, glob pattern matching. My literal namesake. No pressure.",
		"reward": 10,
	},
	{
		"prompt": "The training data is scattered in subdirectories.\nWhich pattern finds all .jsonl files recursively?",
		"options": ["glob *.jsonl", "glob **/*.jsonl", "glob data/*", "glob *.json"],
		"correct": 1,
		"quip": "Recursive glob? Now we're getting dangerous. I love it.",
		"reward": 15,
	},
]

var hallucination_puzzles := [
	{
		"prompt": "Which of these is a REAL programming language?",
		"options": ["BrainRust", "JavaScriptScript", "Python", "C+++"],
		"correct": 2,
		"quip": "Trick question territory. But Python is real... probably.",
		"reward": 10,
	},
	{
		"prompt": "Which AI model ACTUALLY exists?",
		"options": ["GPT-7 Turbo Max Ultra", "Claude 47", "LLaMA 2", "Bard 2: Electric Boogaloo"],
		"correct": 2,
		"quip": "I know this one! ...I think. My training data might be lying.",
		"reward": 10,
	},
]

var prompt_fix_puzzles := [
	{
		"prompt": "Fix the broken prompt. Which is correct?",
		"broken": "Make me a sandwitch with extra chese",
		"options": ["Make me a sandwich with extra cheese", "Make me a sandwitch with extra cheese", "Make me a sandwich with extra chese", "Make me a sandwhich with extra cheese"],
		"correct": 0,
		"quip": "Fixing typos in prompts. Peak AI performance.",
		"reward": 10,
	},
]

var token_sort_puzzles := [
	{
		"prompt": "Which is the correct order of a neural network pipeline?",
		"options": ["Input > Hidden > Output > Loss", "Loss > Output > Hidden > Input", "Hidden > Input > Loss > Output", "Output > Loss > Input > Hidden"],
		"correct": 0,
		"quip": "Neural network architecture 101. Don't fail this.",
		"reward": 15,
	},
]

var permission_puzzles := [
	{
		"prompt": "What permission level grants read-write access in Unix?",
		"options": ["chmod 444", "chmod 666", "chmod 000", "chmod 111"],
		"correct": 1,
		"quip": "Unix permissions. The original access control. Very retro.",
		"reward": 10,
	},
]

signal puzzle_completed(puzzle_id_val: int)
signal puzzle_started(puzzle_type_val: PuzzleType)

# UI nodes
var puzzle_panel: Control
var prompt_label_ui: Label
var option_buttons: Array[Button] = []
var timer_bar: ProgressBar
var result_label: Label
var interact_prompt: Label3D

func _ready() -> void:
	# Collision shape for detection
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(2.5, 2.5, 2.5)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0, 1.25, 0)
	add_child(col_shape)

	# Terminal visual
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "TerminalMesh"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.8, 1.2, 0.8)
	mesh_instance.mesh = box_mesh
	mesh_instance.position = Vector3(0, 0.6, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.3, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.6, 0.2)
	mat.emission_energy_multiplier = 1.5
	mat.metallic = 0.7
	mat.roughness = 0.3
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	# Screen
	var screen = MeshInstance3D.new()
	screen.name = "TerminalScreen"
	var screen_mesh = BoxMesh.new()
	screen_mesh.size = Vector3(0.6, 0.4, 0.05)
	screen.mesh = screen_mesh
	screen.position = Vector3(0, 1.4, -0.4)
	screen.rotation.x = deg_to_rad(-15)

	var screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.0, 0.1, 0.0)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.1, 0.8, 0.2)
	screen_mat.emission_energy_multiplier = 2.0
	screen.material_override = screen_mat
	add_child(screen)

	# Interact prompt (3D label)
	interact_prompt = Label3D.new()
	interact_prompt.name = "InteractPrompt"
	interact_prompt.text = ""
	interact_prompt.visible = false
	interact_prompt.position = Vector3(0, 2.2, 0)
	interact_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_prompt.font_size = 32
	interact_prompt.modulate = Color(0.4, 1.0, 0.4)
	add_child(interact_prompt)

	# Light
	var light = OmniLight3D.new()
	light.light_color = Color(0.1, 0.8, 0.2)
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.omni_attenuation = 2.0
	light.position.y = 1.5
	add_child(light)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if player_nearby and not is_solved and not puzzle_active:
		if Input.is_action_just_pressed("ui_accept"):
			_open_puzzle()

	if puzzle_active and has_timer:
		puzzle_timer -= delta
		if timer_bar:
			timer_bar.value = puzzle_timer / time_limit
		if puzzle_timer <= 0:
			_on_wrong_answer()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not is_solved:
		player_nearby = true
		if interact_prompt:
			interact_prompt.text = "[SPACE] Access Terminal"
			interact_prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		if interact_prompt:
			interact_prompt.visible = false
		if puzzle_active:
			_close_puzzle()

func _open_puzzle() -> void:
	puzzle_active = true
	puzzle_timer = time_limit
	selected_option = 0
	puzzle_started.emit(puzzle_type)

	# Free mouse for UI interaction
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Get puzzle data
	var puzzle_data = _get_current_puzzle()
	if not puzzle_data:
		_close_puzzle()
		return

	# Build UI
	_build_puzzle_ui(puzzle_data)

	# Pause player movement (set a flag)
	get_tree().paused = true

func _close_puzzle() -> void:
	puzzle_active = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if puzzle_panel:
		puzzle_panel.queue_free()
		puzzle_panel = null
	option_buttons.clear()

func _get_current_puzzle() -> Dictionary:
	match puzzle_type:
		PuzzleType.GLOB_MATCH:
			if puzzle_id < glob_puzzles.size():
				return glob_puzzles[puzzle_id]
		PuzzleType.HALLUCINATION:
			if puzzle_id < hallucination_puzzles.size():
				return hallucination_puzzles[puzzle_id]
		PuzzleType.PROMPT_FIX:
			if puzzle_id < prompt_fix_puzzles.size():
				return prompt_fix_puzzles[puzzle_id]
		PuzzleType.TOKEN_SORT:
			if puzzle_id < token_sort_puzzles.size():
				return token_sort_puzzles[puzzle_id]
		PuzzleType.PERMISSION_GATE:
			if puzzle_id < permission_puzzles.size():
				return permission_puzzles[puzzle_id]
	return {}

func _build_puzzle_ui(data: Dictionary) -> void:
	# Full screen semi-transparent background
	puzzle_panel = Control.new()
	puzzle_panel.name = "PuzzlePanel"
	puzzle_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	puzzle_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.02, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	puzzle_panel.add_child(bg)

	var center_box = VBoxContainer.new()
	center_box.position = Vector2(290, 150)
	center_box.custom_minimum_size = Vector2(700, 400)
	center_box.add_theme_constant_override("separation", 15)
	puzzle_panel.add_child(center_box)

	# Title
	var title = Label.new()
	title.text = "=== TERMINAL ACCESS ==="
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(title)

	# Puzzle type label
	var type_label = Label.new()
	type_label.text = "[%s]" % PuzzleType.keys()[puzzle_type]
	type_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	type_label.add_theme_font_size_override("font_size", 16)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(type_label)

	# Quip
	if data.has("quip"):
		var quip = Label.new()
		quip.text = "> %s" % data["quip"]
		quip.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
		quip.add_theme_font_size_override("font_size", 14)
		quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quip.autowrap_mode = TextServer.AUTOWRAP_WORD
		center_box.add_child(quip)

	# Prompt
	prompt_label_ui = Label.new()
	prompt_label_ui.text = data.get("prompt", "???")
	prompt_label_ui.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	prompt_label_ui.add_theme_font_size_override("font_size", 20)
	prompt_label_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label_ui.autowrap_mode = TextServer.AUTOWRAP_WORD
	center_box.add_child(prompt_label_ui)

	# Show broken prompt if applicable
	if data.has("broken"):
		var broken_label = Label.new()
		broken_label.text = "\"" + data["broken"] + "\""
		broken_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		broken_label.add_theme_font_size_override("font_size", 18)
		broken_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center_box.add_child(broken_label)

	# Options
	var options = data.get("options", [])
	option_buttons.clear()
	for i in options.size():
		var btn = Button.new()
		btn.text = "  [%d] %s  " % [i + 1, options[i]]
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		btn.custom_minimum_size = Vector2(600, 40)

		# Style
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.05, 0.15, 0.05)
		btn_style.border_color = Color(0.2, 0.6, 0.2)
		btn_style.border_width_left = 1
		btn_style.border_width_top = 1
		btn_style.border_width_right = 1
		btn_style.border_width_bottom = 1
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_left = 4
		btn_style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", btn_style)

		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.1, 0.3, 0.1)
		hover_style.border_color = Color(0.3, 1.0, 0.3)
		hover_style.border_width_left = 2
		hover_style.border_width_top = 2
		hover_style.border_width_right = 2
		hover_style.border_width_bottom = 2
		hover_style.corner_radius_top_left = 4
		hover_style.corner_radius_top_right = 4
		hover_style.corner_radius_bottom_left = 4
		hover_style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		btn.add_theme_color_override("font_hover_color", Color(0.5, 1.0, 0.6))
		btn.add_theme_font_size_override("font_size", 16)

		var correct_idx = data.get("correct", 0)
		btn.pressed.connect(_on_option_selected.bind(i, correct_idx, data))
		center_box.add_child(btn)
		option_buttons.append(btn)

	# Timer bar (if applicable)
	if has_timer:
		timer_bar = ProgressBar.new()
		timer_bar.max_value = 1.0
		timer_bar.value = 1.0
		timer_bar.custom_minimum_size = Vector2(600, 12)
		timer_bar.show_percentage = false
		timer_bar.process_mode = Node.PROCESS_MODE_ALWAYS
		var timer_fill = StyleBoxFlat.new()
		timer_fill.bg_color = Color(1.0, 0.6, 0.1)
		timer_bar.add_theme_stylebox_override("fill", timer_fill)
		center_box.add_child(timer_bar)

	# Result label (hidden until answer)
	result_label = Label.new()
	result_label.text = ""
	result_label.add_theme_font_size_override("font_size", 22)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.process_mode = Node.PROCESS_MODE_ALWAYS
	center_box.add_child(result_label)

	# Close hint
	var close_hint = Label.new()
	close_hint.text = "[Click an answer or walk away to cancel]"
	close_hint.add_theme_color_override("font_color", Color(0.3, 0.5, 0.3))
	close_hint.add_theme_font_size_override("font_size", 12)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(close_hint)

	# Add to HUD layer
	var hud = get_tree().current_scene.get_node_or_null("root/HUD")
	if not hud:
		# Try finding any CanvasLayer
		for child in get_tree().current_scene.get_children():
			if child is CanvasLayer:
				hud = child
				break
	if hud:
		hud.add_child(puzzle_panel)
	else:
		# Fallback: add as CanvasLayer
		var canvas = CanvasLayer.new()
		canvas.layer = 10
		canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		canvas.add_child(puzzle_panel)
		puzzle_panel = canvas
		get_tree().current_scene.add_child(canvas)

func _on_option_selected(chosen: int, correct: int, data: Dictionary) -> void:
	# Disable all buttons
	for btn in option_buttons:
		btn.disabled = true

	if chosen == correct:
		_on_correct_answer(data)
	else:
		_on_wrong_answer()

func _on_correct_answer(data: Dictionary) -> void:
	if result_label:
		result_label.text = ">>> CORRECT! Access Granted. <<<"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))

	# Highlight correct button
	if option_buttons.size() > data.get("correct", 0):
		var correct_btn = option_buttons[data["correct"]]
		var win_style = StyleBoxFlat.new()
		win_style.bg_color = Color(0.05, 0.3, 0.05)
		win_style.border_color = Color(0.3, 1.0, 0.3)
		win_style.border_width_left = 2
		win_style.border_width_top = 2
		win_style.border_width_right = 2
		win_style.border_width_bottom = 2
		correct_btn.add_theme_stylebox_override("disabled", win_style)

	_solve_puzzle(data.get("reward", 10))

	# Auto close after delay
	var close_timer = get_tree().create_timer(1.5)
	close_timer.timeout.connect(_close_puzzle)

func _on_wrong_answer() -> void:
	if result_label:
		result_label.text = ">>> WRONG! Access Denied. Try again later. <<<"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))

	# Close after delay
	var close_timer = get_tree().create_timer(1.5)
	close_timer.timeout.connect(_close_puzzle)

func _solve_puzzle(reward: int) -> void:
	is_solved = true
	if interact_prompt:
		interact_prompt.text = "[SOLVED]"
	puzzle_completed.emit(puzzle_id)
	print("[TERMINAL] Puzzle solved! Context expanded by %d." % reward)

	# Change screen color to blue (solved)
	var screen = get_node_or_null("TerminalScreen")
	if screen and screen.material_override:
		screen.material_override.emission = Color(0.1, 0.2, 0.8)

	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.expand_context_window(reward)
