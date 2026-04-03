extends "res://scenes/puzzles/base_puzzle.gd"

# Weight Path Puzzle — Adjust neural network weights to build a walkable path
# "Gradient descent is just fancy hill-walking. This is literal hill-building."
#
# The puzzle presents a series of bridge segments at wrong heights.
# Each segment has a "weight node" (GlobTarget) that can be globbed.
# Globbing a weight node toggles it between low/high states.
# When the right combination is active, all segments align into a walkable path.
# Door opens when the path is complete.

@export var num_segments: int = 4
@export var segment_spacing: float = 3.0
@export var target_height: float = 1.5  # The height all segments must reach
@export var hint_text: String = "Adjust the weights to align the path. Glob weight nodes to toggle them."
# Which segments need to be toggled ON (indices). Others must stay OFF.
@export var solution_indices: Array[int] = [0, 2, 3]

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const WEIGHT_GREEN := Color(0.1, 0.8, 0.3)
const SYNAPSE_BLUE := Color(0.1, 0.4, 0.9)
const DARK_GRAY := Color(0.08, 0.08, 0.12)
const ACTIVE_COLOR := Color(0.15, 0.9, 0.3)
const INACTIVE_COLOR := Color(0.6, 0.15, 0.1)

var _segments: Array[StaticBody3D] = []
var _segment_meshes: Array[MeshInstance3D] = []
var _segment_mats: Array[StandardMaterial3D] = []
var _weight_nodes: Array[StaticBody3D] = []
var _weight_labels: Array[Label3D] = []
var _weight_states: Array[bool] = []  # true = high (toggled on), false = low
var _door: StaticBody3D
var _puzzle_label: Label3D
var _check_timer: float = 0.0

# Heights when toggled on vs off — wrong weight = wrong height
var _height_on: float = 1.5
var _height_off_values: Array[float] = []  # Random wrong heights per segment


func _ready() -> void:
	puzzle_name = "weight_path_%d" % puzzle_id
	auto_activate = true
	activation_range = 8.0
	super._ready()

	_height_on = target_height

	# Generate random "wrong" heights for off-state segments
	for i in range(num_segments):
		# Wrong heights: either too high or too low, never matching target
		var wrong = target_height + [-2.0, -1.5, 1.5, 2.5][i % 4]
		_height_off_values.append(wrong)

	_create_segments()
	_create_weight_nodes()
	_create_label()
	_create_door()

	# Wire into GlobEngine for weight node selection
	var engine = get_node_or_null("/root/GlobEngine")
	if engine:
		engine.targets_matched.connect(_on_targets_matched)


func _process(delta: float) -> void:
	super._process(delta)
	if state != PuzzleState.ACTIVE:
		return

	# Smooth segment height animation — weights don't snap, they lerp like proper gradients
	for i in range(_segments.size()):
		var goal_y = _height_on if _weight_states[i] else _height_off_values[i]
		var seg = _segments[i]
		seg.position.y = lerp(seg.position.y, goal_y, delta * 4.0)

		# Update material color based on alignment
		var dist_from_target = abs(seg.position.y - _height_on)
		if dist_from_target < 0.15:
			_segment_mats[i].emission = ACTIVE_COLOR
			_segment_mats[i].emission_energy_multiplier = 1.5
		else:
			_segment_mats[i].emission = INACTIVE_COLOR * 0.5
			_segment_mats[i].emission_energy_multiplier = 0.6

	# Check solution periodically (not every frame, we're not barbarians)
	_check_timer -= delta
	if _check_timer <= 0:
		_check_timer = 0.3
		_check_solution()


func _on_targets_matched(matched: Array) -> void:
	if state != PuzzleState.ACTIVE:
		return

	# Toggle any weight nodes that were globbed
	for target_parent in matched:
		for i in range(_weight_nodes.size()):
			if target_parent == _weight_nodes[i]:
				_toggle_weight(i)


func _toggle_weight(index: int) -> void:
	_weight_states[index] = not _weight_states[index]
	var w_label = _weight_labels[index]

	if _weight_states[index]:
		w_label.text = "w%d = 1.0\n[ACTIVE]" % index
		w_label.modulate = NEON_GREEN
	else:
		w_label.text = "w%d = 0.0\n[inactive]" % index
		w_label.modulate = INACTIVE_COLOR

	# Play a satisfying click sound
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_puzzle_activate"):
		am.play_puzzle_activate()

	# Quip on first toggle
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line") and randf() < 0.3:
		var quips := [
			"Adjusting weights manually. This is basically SGD with extra steps.",
			"Weight goes up, weight goes down. I'm a human optimizer now.",
			"If only real neural networks were this easy to tune.",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _check_solution() -> void:
	# All segments at target height = solved
	for i in range(num_segments):
		var should_be_on = i in solution_indices
		if _weight_states[i] != should_be_on:
			return  # Not solved yet

	# Path aligned — the gradient has converged
	solve()


func _create_segments() -> void:
	# Bridge segments spanning across a gap — each at a different height
	var total_width = (num_segments - 1) * segment_spacing
	var start_x = -total_width / 2.0

	for i in range(num_segments):
		var seg = StaticBody3D.new()
		seg.name = "WeightSegment_%d" % i
		var x_pos = start_x + i * segment_spacing
		# Start at the "wrong" height
		var start_y = _height_off_values[i] if i < _height_off_values.size() else 0.0
		seg.position = Vector3(x_pos, start_y, 0)

		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(2.5, 0.4, 3.0)
		col.shape = shape
		seg.add_child(col)

		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(2.5, 0.4, 3.0)
		mesh.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = DARK_GRAY
		mat.emission_enabled = true
		mat.emission = INACTIVE_COLOR * 0.5
		mat.emission_energy_multiplier = 0.6
		mat.metallic = 0.7
		mat.roughness = 0.4
		mesh.material_override = mat
		seg.add_child(mesh)

		# Weight value display on the segment
		var val_label = Label3D.new()
		val_label.text = "w%d" % i
		val_label.font_size = 14
		val_label.modulate = SYNAPSE_BLUE * 0.6
		val_label.position = Vector3(0, 0.3, 0)
		val_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		seg.add_child(val_label)

		add_child(seg)
		_segments.append(seg)
		_segment_meshes.append(mesh)
		_segment_mats.append(mat)
		_weight_states.append(false)


func _create_weight_nodes() -> void:
	# Interactive weight terminals alongside each segment — glob these to toggle
	var total_width = (num_segments - 1) * segment_spacing
	var start_x = -total_width / 2.0
	var glob_target_script = load("res://scripts/components/glob_target.gd")

	for i in range(num_segments):
		var node = StaticBody3D.new()
		node.name = "WeightNode_%d" % i
		var x_pos = start_x + i * segment_spacing
		node.position = Vector3(x_pos, 0.0, -2.5)

		# Collision
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.8, 1.5, 0.8)
		col.shape = shape
		node.add_child(col)

		# Visual — glowing terminal pillar
		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.8, 1.5, 0.8)
		mesh.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = SYNAPSE_BLUE * 0.2
		mat.emission_enabled = true
		mat.emission = SYNAPSE_BLUE
		mat.emission_energy_multiplier = 1.0
		mat.metallic = 0.8
		mat.roughness = 0.3
		mesh.material_override = mat
		node.add_child(mesh)

		# GlobTarget component — makes it selectable
		var gt = Node.new()
		gt.set_script(glob_target_script)
		gt.set("glob_name", "weight_%d" % i)
		gt.set("file_type", "weight")
		gt.set("tags", ["weight", "adjustable", "w%d" % i])
		node.add_child(gt)

		# Label showing current weight state
		var label = Label3D.new()
		label.text = "w%d = 0.0\n[inactive]" % i
		label.font_size = 12
		label.modulate = INACTIVE_COLOR
		label.position = Vector3(0, 1.2, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.add_child(label)

		add_child(node)
		_weight_nodes.append(node)
		_weight_labels.append(label)


func _create_label() -> void:
	_puzzle_label = Label3D.new()
	_puzzle_label.text = hint_text
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = NEON_GREEN * 0.8
	_puzzle_label.position = Vector3(0, 3.5, -3.5)
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_puzzle_label)

	# Pattern hint below
	var hint = Label3D.new()
	hint.text = ">> glob weight_* to toggle\n>> Align all segments to open the path"
	hint.font_size = 10
	hint.modulate = SYNAPSE_BLUE * 0.6
	hint.position = Vector3(0, 2.8, -3.5)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(hint)


func _create_door() -> void:
	# Barrier blocking the path forward — dissolves when weights are correct
	_door = StaticBody3D.new()
	_door.name = "WeightDoor"
	var total_width = (num_segments - 1) * segment_spacing + 3.0
	_door.position = Vector3(0, 2.0, 2.5)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(total_width, 4.0, 0.3)
	col.shape = shape
	_door.add_child(col)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(total_width, 4.0, 0.3)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = WEIGHT_GREEN * 0.15
	mat.emission_enabled = true
	mat.emission = WEIGHT_GREEN
	mat.emission_energy_multiplier = 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.6
	mesh.material_override = mat
	_door.add_child(mesh)

	add_child(_door)


func _on_solved() -> void:
	# All weights aligned — the path is complete
	for mat in _segment_mats:
		mat.emission = NEON_GREEN
		mat.emission_energy_multiplier = 2.0

	_puzzle_label.text = ">> WEIGHTS CONVERGED\n>> Path aligned."
	_puzzle_label.modulate = NEON_GREEN

	# Dissolve the door with style
	if is_instance_valid(_door):
		var door_mesh = _door.get_node_or_null("MeshInstance3D")
		if not door_mesh:
			for child in _door.get_children():
				if child is MeshInstance3D:
					door_mesh = child
					break
		if door_mesh and door_mesh.material_override:
			var tween = create_tween()
			tween.tween_property(door_mesh.material_override, "albedo_color:a", 0.0, 0.8)
			tween.tween_callback(_door.queue_free)
		else:
			_door.queue_free()


func _on_reset() -> void:
	# Reset all weights to off
	for i in range(num_segments):
		_weight_states[i] = false
		_weight_labels[i].text = "w%d = 0.0\n[inactive]" % i
		_weight_labels[i].modulate = INACTIVE_COLOR

	_puzzle_label.text = hint_text
	_puzzle_label.modulate = NEON_GREEN * 0.8
