extends "res://scenes/puzzles/base_puzzle.gd"

# Hack Puzzle - Terminal that must be hacked to proceed
# "sudo open_door — permission denied. Fine, we'll do it the fun way."
#
# Player approaches a hackable terminal, completes the sequence memory
# minigame via terminal_hack.gd, and the puzzle door opens on success.

@export var hack_difficulty: int = 1  # 1-5, longer sequences = harder
@export var terminal_prompt: String = "ENCRYPTED LOCK"
@export var hint_text: String = "Hack this terminal to proceed."

var _puzzle_label: Label3D
var _door: StaticBody3D
var _hackable_terminal: StaticBody3D
var _hackable_comp: Node  # The Hackable component

func _ready() -> void:
	puzzle_name = "hack_puzzle_%d" % puzzle_id
	auto_activate = true
	super._ready()
	_create_terminal()
	_create_door()

func _create_terminal() -> void:
	# The hackable terminal object — wall terminal GLB with CRT screen
	_hackable_terminal = StaticBody3D.new()
	_hackable_terminal.name = "HackTerminal"
	_hackable_terminal.position = Vector3(0, 0, 0)
	_hackable_terminal.add_to_group("hackable")

	# Collision so player can't walk through it
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.5, 2.0, 0.5)
	col.shape = shape
	col.position = Vector3(0, 1.0, 0)
	_hackable_terminal.add_child(col)

	# Terminal body — wall terminal GLB prop replacing BoxMesh slab
	var terminal_scene = preload("res://assets/models/environment/arch_wall_terminal.glb")
	var terminal_inst = terminal_scene.instantiate()
	terminal_inst.name = "TerminalBody"
	terminal_inst.position = Vector3(0, 0.0, 0)
	terminal_inst.scale = Vector3(1.3, 1.3, 1.3)
	_hackable_terminal.add_child(terminal_inst)

	# Screen face — CRT scanline shader on a quad overlaid on terminal front
	var screen_mesh = MeshInstance3D.new()
	screen_mesh.name = "Screen"
	var screen_quad = QuadMesh.new()
	screen_quad.size = Vector2(1.0, 0.9)
	screen_mesh.mesh = screen_quad
	screen_mesh.position = Vector3(0, 1.2, 0.35)
	var crt_mat = ShaderMaterial.new()
	crt_mat.shader = preload("res://assets/shaders/crt_scanline.gdshader")
	crt_mat.set_shader_parameter("screen_color", Color(0.224, 1.0, 0.078))
	crt_mat.set_shader_parameter("bg_color", Color(0.02, 0.08, 0.02))
	crt_mat.set_shader_parameter("scanline_count", 80.0)
	crt_mat.set_shader_parameter("glow_energy", 2.5)
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		crt_mat.set_shader_parameter("flicker_amount", 0.0)
		crt_mat.set_shader_parameter("scroll_speed", 0.0)
	screen_mesh.material_override = crt_mat
	_hackable_terminal.add_child(screen_mesh)

	# Attach the Hackable component — this is what terminal_hack.gd looks for
	_hackable_comp = preload("res://scripts/components/hackable.gd").new()
	_hackable_comp.hack_difficulty = hack_difficulty
	_hackable_comp.interaction_range = activation_range
	_hackable_comp.hack_prompt = "Press T to hack"
	_hackable_comp.success_message = "DECRYPTED — Door unlocked."
	_hackable_comp.failure_message = "DECRYPTION FAILED — Try again."
	_hackable_terminal.add_child(_hackable_comp)

	add_child(_hackable_terminal)

	# Floating label above the terminal
	_puzzle_label = Label3D.new()
	_puzzle_label.text = "[ %s ]\nDifficulty: %d/5\n%s" % [terminal_prompt, hack_difficulty, hint_text]
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = Color(0.224, 1.0, 0.078)
	_puzzle_label.position = Vector3(0, 2.8, 0)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_puzzle_label)

func _create_door() -> void:
	# Door that blocks passage until hack is complete
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -3)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	col.shape = shape
	_door.add_child(col)

	# Industrial panel GLB replacing BoxMesh door visual
	var door_scene = preload("res://assets/models/environment/arch_industrial_panel.glb")
	var door_inst = door_scene.instantiate()
	door_inst.name = "DoorMesh"
	door_inst.scale = Vector3(2.0, 1.5, 1.0)
	_door.add_child(door_inst)

	add_child(_door)

func _on_activated() -> void:
	# Wire up the Hackable component signals so we know when hack succeeds/fails
	if _hackable_comp:
		if not _hackable_comp.is_connected("hack_completed", _on_hack_completed):
			_hackable_comp.hack_completed.connect(_on_hack_completed)
		if not _hackable_comp.is_connected("hack_failed", _on_hack_failed):
			_hackable_comp.hack_failed.connect(_on_hack_failed)

func _on_hack_completed() -> void:
	# "Permission granted. Was that so hard? ...Don't answer that."
	if state == PuzzleState.ACTIVE:
		solve()

func _on_hack_failed() -> void:
	# "Access denied. Your typing is almost as bad as your fashion sense."
	if state == PuzzleState.ACTIVE:
		fail()

func _on_solved() -> void:
	# Update label to show success
	if _puzzle_label:
		_puzzle_label.text = "[ ACCESS GRANTED ]\nDoor unlocked.\n// You're basically a hacker now."
		_puzzle_label.modulate = Color(0.4, 1.0, 0.4)

	# Make screen glow brighter on success
	if _hackable_terminal:
		var screen = _hackable_terminal.get_node_or_null("Screen")
		if screen and screen.material_override:
			screen.material_override.set_shader_parameter("glow_energy", 4.5)
			screen.material_override.set_shader_parameter("screen_color", Color(0.4, 1.0, 0.4))

	# Open the door — slide it up and free it
	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ ACCESS DENIED ]\nSequence incorrect.\n// Even Clippy could do better."
		_puzzle_label.modulate = Color(1.0, 0.3, 0.2)

	# Flash screen red briefly via CRT shader color swap
	if _hackable_terminal:
		var screen = _hackable_terminal.get_node_or_null("Screen")
		if screen and screen.material_override:
			var orig_color = screen.material_override.get_shader_parameter("screen_color")
			screen.material_override.set_shader_parameter("screen_color", Color(1.0, 0.1, 0.05))
			screen.material_override.set_shader_parameter("glow_energy", 3.5)
			get_tree().create_timer(1.5).timeout.connect(func():
				if screen and screen.material_override:
					screen.material_override.set_shader_parameter("screen_color", orig_color)
					screen.material_override.set_shader_parameter("glow_energy", 2.5)
			)

func _on_reset() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ %s ]\nDifficulty: %d/5\n%s" % [terminal_prompt, hack_difficulty, hint_text]
		_puzzle_label.modulate = Color(0.224, 1.0, 0.078)
