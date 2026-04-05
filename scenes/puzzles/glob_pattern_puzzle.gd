extends "res://scenes/puzzles/base_puzzle.gd"

# Glob Pattern Puzzle - Terminal shows a pattern, player must glob the correct objects
# "Match the pattern, open the door. It's like regex but fun. Almost."

@export var required_pattern := "*.txt"
@export var target_count := 1  # How many targets should be matched
@export var hint_text := "Glob the correct objects to proceed."

var _matched := false
var _puzzle_label: Label3D
var _door: StaticBody3D

func _ready() -> void:
	puzzle_name = "glob_pattern_%d" % puzzle_id
	auto_activate = true
	super._ready()
	_create_visual()

func _create_visual() -> void:
	# Wall terminal GLB as visual backing for the puzzle display
	var terminal_scene = preload("res://assets/models/environment/arch_wall_terminal.glb")
	var terminal_inst = terminal_scene.instantiate()
	terminal_inst.name = "TerminalProp"
	terminal_inst.position = Vector3(0, 1.0, 0.2)
	terminal_inst.scale = Vector3(1.2, 1.2, 1.2)
	add_child(terminal_inst)

	# CRT scanline screen quad overlaid on the terminal face
	var screen_mesh = MeshInstance3D.new()
	screen_mesh.name = "CRTScreen"
	var quad = QuadMesh.new()
	quad.size = Vector2(1.0, 0.8)
	screen_mesh.mesh = quad
	screen_mesh.position = Vector3(0, 1.6, 0.45)
	var crt_mat = ShaderMaterial.new()
	crt_mat.shader = preload("res://assets/shaders/crt_scanline.gdshader")
	crt_mat.set_shader_parameter("screen_color", Color(0.224, 1.0, 0.078))
	crt_mat.set_shader_parameter("bg_color", Color(0.01, 0.03, 0.01))
	crt_mat.set_shader_parameter("scanline_count", 60.0)
	crt_mat.set_shader_parameter("glow_energy", 2.0)
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		crt_mat.set_shader_parameter("flicker_amount", 0.0)
		crt_mat.set_shader_parameter("scroll_speed", 0.0)
	screen_mesh.material_override = crt_mat
	add_child(screen_mesh)

	# Terminal display showing the pattern (floating above CRT screen)
	_puzzle_label = Label3D.new()
	_puzzle_label.text = "[ GLOB PUZZLE ]\n$ glob %s\n%s" % [required_pattern, hint_text]
	_puzzle_label.font_size = 16
	_puzzle_label.modulate = Color(0.224, 1.0, 0.078)
	_puzzle_label.position = Vector3(0, 2.5, 0)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_puzzle_label)

	# Door that opens on solve — uses industrial panel GLB for visual
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -2)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	col.shape = shape
	_door.add_child(col)

	var door_scene = preload("res://assets/models/environment/arch_industrial_panel.glb")
	var door_inst = door_scene.instantiate()
	door_inst.name = "DoorMesh"
	door_inst.scale = Vector3(2.0, 1.5, 1.0)
	_door.add_child(door_inst)
	add_child(_door)

func _on_activated() -> void:
	# Listen for glob matches from the GlobEngine
	var engine = get_node_or_null("/root/GlobEngine")
	if engine and engine.has_signal("targets_matched"):
		engine.targets_matched.connect(_on_targets_matched)

func _on_targets_matched(targets: Array[Node]) -> void:
	if state != PuzzleState.ACTIVE or _matched:
		return

	# Check if the matched targets satisfy the puzzle
	var engine = get_node_or_null("/root/GlobEngine")
	if not engine:
		return

	# Re-run pattern to verify
	var results = engine.match_pattern(required_pattern)
	if results.size() >= target_count:
		_matched = true
		solve()

func _on_solved() -> void:
	# Open the door
	if _puzzle_label:
		_puzzle_label.text = "[ ACCESS GRANTED ]\n$ glob %s\nDoor unlocked." % required_pattern
		_puzzle_label.modulate = Color(0.4, 1.0, 0.4)

	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ ACCESS DENIED ]\n$ glob %s\nTry again." % required_pattern
		_puzzle_label.modulate = Color(1.0, 0.3, 0.2)

func _on_reset() -> void:
	_matched = false
	if _puzzle_label:
		_puzzle_label.text = "[ GLOB PUZZLE ]\n$ glob %s\n%s" % [required_pattern, hint_text]
		_puzzle_label.modulate = Color(0.224, 1.0, 0.078)
