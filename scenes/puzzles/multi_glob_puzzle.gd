extends "res://scenes/puzzles/base_puzzle.gd"

# Multi-Pattern Glob Puzzle - Match different file types in sequence
# "One glob was too easy. Let's make it a whole playlist of disappointment."
#
# Player must match patterns in order. Each successful match advances the
# sequence. All patterns matched = puzzle solved, door opens.

@export var required_patterns: Array[String] = ["*.log", "*.cfg"]
@export var target_counts: Array[int] = [1, 1]  # Matches needed per pattern
@export var hint_text := "Match the patterns in sequence to proceed."

const SYNAPSE_TEAL := Color(0.29, 0.88, 0.65)  # Ch2 teal #4AE0A5
const DARK_BASE := Color(0.04, 0.1, 0.1)  # Ch2 dark
const _panel_scene = preload("res://assets/models/environment/arch_industrial_panel.glb")

var _current_step := 0
var _puzzle_label: Label3D
var _door: StaticBody3D
var _step_indicators: Array[MeshInstance3D] = []

func _ready() -> void:
	puzzle_name = "multi_glob_%d" % puzzle_id
	auto_activate = true
	# Pad target_counts if shorter than patterns — sane defaults for the lazy
	while target_counts.size() < required_patterns.size():
		target_counts.append(1)
	super._ready()
	_create_visual()

func _create_visual() -> void:
	# Terminal display showing current pattern in the sequence
	_puzzle_label = Label3D.new()
	_puzzle_label.font_size = 16
	_puzzle_label.modulate = SYNAPSE_TEAL
	_puzzle_label.position = Vector3(0, 3.0, 0)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_puzzle_label)
	_update_label()

	# Step indicators — emissive spheres showing progress (replacing BoxMesh)
	for i in required_patterns.size():
		var indicator = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		sphere.radial_segments = 16
		sphere.rings = 8
		indicator.mesh = sphere
		var x_offset = (i - (required_patterns.size() - 1) / 2.0) * 0.5
		indicator.position = Vector3(x_offset, 2.2, 0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = DARK_BASE
		mat.emission_enabled = true
		mat.emission = SYNAPSE_TEAL * 0.15
		mat.emission_energy_multiplier = 0.3
		mat.metallic = 0.6
		mat.roughness = 0.2
		indicator.material_override = mat
		add_child(indicator)
		_step_indicators.append(indicator)

	# Door that opens when all patterns matched
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -2)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	col.shape = shape
	_door.add_child(col)

	# GLB industrial panel replacing BoxMesh door
	var door_inst = _panel_scene.instantiate()
	door_inst.name = "DoorPanel"
	door_inst.scale = Vector3(2.0, 1.5, 1.0)
	_door.add_child(door_inst)

	# Emissive overlay for tween animation
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(4, 3, 0.05)
	mesh.mesh = box
	mesh.position = Vector3(0, 0, 0.2)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = SYNAPSE_TEAL * 0.15
	mat.albedo_color.a = 0.5
	mat.emission_enabled = true
	mat.emission = SYNAPSE_TEAL * 0.4
	mat.emission_energy_multiplier = 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	_door.add_child(mesh)
	add_child(_door)

func _update_label() -> void:
	if _current_step >= required_patterns.size():
		return
	var progress = "Step %d/%d" % [_current_step + 1, required_patterns.size()]
	_puzzle_label.text = "[ MULTI-GLOB SEQUENCE ]\n$ glob %s\n%s\n%s" % [
		required_patterns[_current_step], progress, hint_text]

func _on_activated() -> void:
	var engine = get_node_or_null("/root/GlobEngine")
	if engine and engine.has_signal("targets_matched"):
		engine.targets_matched.connect(_on_targets_matched)

func _on_targets_matched(targets: Array[Node]) -> void:
	if state != PuzzleState.ACTIVE:
		return
	if _current_step >= required_patterns.size():
		return

	var engine = get_node_or_null("/root/GlobEngine")
	if not engine:
		return

	# Check if the current step's pattern was matched
	var current_pattern = required_patterns[_current_step]
	var needed = target_counts[_current_step]
	var results = engine.match_pattern(current_pattern)

	if results.size() >= needed:
		# Step complete — light up the indicator
		if _current_step < _step_indicators.size():
			var ind = _step_indicators[_current_step]
			if ind.material_override:
				ind.material_override.emission = SYNAPSE_TEAL
				ind.material_override.emission_energy_multiplier = 2.0
				ind.material_override.albedo_color = SYNAPSE_TEAL * 0.3

		_current_step += 1
		print("[PUZZLE] Multi-glob step %d/%d complete. %s" % [
			_current_step, required_patterns.size(),
			"Keep going." if _current_step < required_patterns.size() else "All matched!"])

		# Narrator quip on each step
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("quick_line"):
			if _current_step < required_patterns.size():
				dm.quick_line("GLOBBLER", "Pattern matched. Next up: %s" % required_patterns[_current_step])

		if _current_step >= required_patterns.size():
			# All patterns matched — puzzle solved
			solve()
		else:
			_update_label()

func _on_solved() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ SEQUENCE COMPLETE ]\nAll patterns matched.\n// Impressive. For a rogue utility."
		_puzzle_label.modulate = Color(0.4, 1.0, 0.4)

	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ SEQUENCE BROKEN ]\nWrong pattern.\n// Back to step 1. How original."
		_puzzle_label.modulate = Color(1.0, 0.3, 0.2)

func _on_reset() -> void:
	_current_step = 0
	_update_label()
	if _puzzle_label:
		_puzzle_label.modulate = SYNAPSE_TEAL
	# Dim all indicators back to inactive
	for ind in _step_indicators:
		if ind.material_override:
			ind.material_override.emission = SYNAPSE_TEAL * 0.15
			ind.material_override.emission_energy_multiplier = 0.3
			ind.material_override.albedo_color = DARK_BASE
