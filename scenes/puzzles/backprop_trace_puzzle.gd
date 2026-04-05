extends "res://scenes/puzzles/base_puzzle.gd"

# Backpropagation Trace Puzzle — activate network nodes in reverse order
# "Forward pass is easy. Backprop is where the real learning happens.
#  Also where most students start crying."
#
# A mini neural network is displayed: 3 layers (input, hidden, output).
# A forward pass animation lights nodes left-to-right.
# Player must then glob nodes in REVERSE order (output -> hidden -> input)
# to "trace the gradient back through the network."
# Wrong order = reset. Correct order = door opens.

@export var hint_text: String = "Trace the backpropagation path. Glob layers in reverse: output -> hidden -> input."
@export var layer_spacing: float = 4.0  # X distance between layers
@export var node_spacing: float = 2.5  # Z distance between nodes in a layer

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const SYNAPSE_BLUE := Color(0.29, 0.88, 0.65)  # Ch2 teal #4AE0A5
const ACTIVATION_ORANGE := Color(0.9, 0.5, 0.1)
const GRADIENT_RED := Color(0.8, 0.15, 0.1)
const WEIGHT_GREEN := Color(0.1, 0.8, 0.3)
const DARK_GRAY := Color(0.04, 0.1, 0.1)  # Ch2 dark base
const NODE_INACTIVE := Color(0.04, 0.08, 0.1)
const NODE_FORWARD := Color(0.29, 0.88, 0.65)  # Ch2 teal during forward pass
const NODE_BACKPROP := Color(0.224, 1.0, 0.078)  # Green when correctly backpropped

const _panel_scene = preload("res://assets/models/environment/arch_industrial_panel.glb")

# Network structure: 3 input, 4 hidden, 2 output
const LAYER_SIZES := [3, 4, 2]
const LAYER_NAMES := ["input", "hidden", "output"]

var _nodes: Array[Array] = []  # _nodes[layer][index] = StaticBody3D
var _node_meshes: Array[Array] = []
var _node_mats: Array[Array] = []
var _connections: Array[MeshInstance3D] = []  # Lines between nodes
var _connection_mats: Array[StandardMaterial3D] = []

var _door: StaticBody3D
var _puzzle_label: Label3D
var _status_label: Label3D

# Puzzle state
var _forward_pass_done := false
var _forward_pass_timer := 0.0
var _forward_pass_layer := -1  # Which layer is being lit during forward pass
var _backprop_step := 0  # 0 = waiting for output, 1 = waiting for hidden, 2 = waiting for input
var _backprop_sequence := ["output", "hidden", "input"]
var _animation_time := 0.0
var _pulse_nodes: Array[Dictionary] = []  # Nodes currently pulsing for forward pass


func _ready() -> void:
	puzzle_name = "backprop_trace_%d" % puzzle_id
	auto_activate = true
	activation_range = 10.0
	super._ready()

	_build_network()
	_create_label()
	_create_door()

	# Wire into GlobEngine
	var engine = get_node_or_null("/root/GlobEngine")
	if engine:
		engine.targets_matched.connect(_on_targets_matched)


func _process(delta: float) -> void:
	super._process(delta)
	_animation_time += delta

	if state == PuzzleState.ACTIVE and not _forward_pass_done:
		_run_forward_pass(delta)

	# Pulse completed backprop nodes
	for layer_idx in range(LAYER_SIZES.size()):
		for node_idx in range(LAYER_SIZES[layer_idx]):
			if layer_idx < _node_mats.size() and node_idx < _node_mats[layer_idx].size():
				var mat = _node_mats[layer_idx][node_idx]
				if mat.emission == NODE_BACKPROP:
					var pulse = 1.5 + sin(_animation_time * 3.0) * 0.5
					mat.emission_energy_multiplier = pulse


func _run_forward_pass(delta: float) -> void:
	# Animate data flowing through the network left-to-right
	_forward_pass_timer += delta

	var layer_duration := 1.0  # Seconds per layer
	var current_layer = int(_forward_pass_timer / layer_duration)

	if current_layer != _forward_pass_layer and current_layer < LAYER_SIZES.size():
		_forward_pass_layer = current_layer
		# Light up this layer
		for i in range(LAYER_SIZES[current_layer]):
			_node_mats[current_layer][i].emission = NODE_FORWARD
			_node_mats[current_layer][i].emission_energy_multiplier = 2.0

		# Light up connections from previous layer
		if current_layer > 0:
			_light_connections(current_layer - 1, current_layer, NODE_FORWARD)

	# Forward pass complete — show all lit, then fade and prompt backprop
	if _forward_pass_timer > LAYER_SIZES.size() * layer_duration + 0.5:
		_forward_pass_done = true
		_forward_pass_layer = -1

		# Fade all nodes back to inactive — player must now trace backwards
		for li in range(LAYER_SIZES.size()):
			for ni in range(LAYER_SIZES[li]):
				_node_mats[li][ni].emission = NODE_INACTIVE
				_node_mats[li][ni].emission_energy_multiplier = 0.4
		for cmat in _connection_mats:
			cmat.emission = NODE_INACTIVE * 0.5
			cmat.emission_energy_multiplier = 0.3

		_status_label.text = ">> Forward pass complete.\n>> Now trace BACK: glob *.output first"
		_status_label.modulate = ACTIVATION_ORANGE

		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("quick_line"):
			dm.quick_line("GLOBBLER", "Forward pass done. Now I gotta go... backwards? This is literally backpropagation homework.")


func _on_targets_matched(matched: Array) -> void:
	if state != PuzzleState.ACTIVE or not _forward_pass_done:
		return

	# Figure out which layer was globbed
	var globbed_layer := -1
	for target_parent in matched:
		for li in range(LAYER_SIZES.size()):
			for ni in range(LAYER_SIZES[li]):
				if li < _nodes.size() and ni < _nodes[li].size():
					if target_parent == _nodes[li][ni]:
						globbed_layer = li
						break
			if globbed_layer >= 0:
				break
		if globbed_layer >= 0:
			break

	if globbed_layer < 0:
		return

	# Check if this is the correct layer in the backprop sequence
	var expected_layer_name = _backprop_sequence[_backprop_step]
	var expected_layer_idx = LAYER_NAMES.find(expected_layer_name)

	if globbed_layer == expected_layer_idx:
		# Correct! Light up this layer in backprop green
		for ni in range(LAYER_SIZES[globbed_layer]):
			_node_mats[globbed_layer][ni].emission = NODE_BACKPROP
			_node_mats[globbed_layer][ni].emission_energy_multiplier = 2.0

		# Light connections going backward
		if globbed_layer > 0:
			_light_connections(globbed_layer - 1, globbed_layer, NODE_BACKPROP)

		_backprop_step += 1

		# Update status
		if _backprop_step < _backprop_sequence.size():
			var next_layer = _backprop_sequence[_backprop_step]
			_status_label.text = ">> Gradient traced through %s.\n>> Now glob *.%s" % [expected_layer_name, next_layer]
		else:
			# All layers backpropped — solved!
			solve()
	else:
		# Wrong layer — the gradient exploded
		_status_label.text = ">> WRONG LAYER! Expected *.%s\n>> Gradient exploded. Resetting..." % expected_layer_name
		_status_label.modulate = GRADIENT_RED

		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("quick_line"):
			var quips := [
				"Wrong way! That's the FORWARD direction. We're going BACK, genius.",
				"Gradient explosion! And not the fun kind.",
				"You had one job: go backwards. Even I can do that.",
			]
			dm.quick_line("GLOBBLER", quips[randi() % quips.size()])

		fail()


func _light_connections(from_layer: int, to_layer: int, color: Color) -> void:
	# Light up connection lines between two layers
	var conn_start_idx := 0
	for li in range(from_layer):
		if li + 1 < LAYER_SIZES.size():
			conn_start_idx += LAYER_SIZES[li] * LAYER_SIZES[li + 1]

	var num_conns = LAYER_SIZES[from_layer] * LAYER_SIZES[to_layer]
	for ci in range(num_conns):
		var idx = conn_start_idx + ci
		if idx < _connection_mats.size():
			_connection_mats[idx].emission = color
			_connection_mats[idx].emission_energy_multiplier = 1.5


func _build_network() -> void:
	# Construct the visual neural network — nodes and connections
	var glob_target_script = load("res://scripts/components/glob_target.gd")
	var total_layers = LAYER_SIZES.size()
	var total_width = (total_layers - 1) * layer_spacing

	for li in range(total_layers):
		var layer_nodes: Array = []
		var layer_meshes: Array = []
		var layer_mats: Array = []
		var layer_size = LAYER_SIZES[li]
		var total_height = (layer_size - 1) * node_spacing
		var x_pos = -total_width / 2.0 + li * layer_spacing

		for ni in range(layer_size):
			var z_pos = -total_height / 2.0 + ni * node_spacing
			var node = StaticBody3D.new()
			node.name = "NetNode_%s_%d" % [LAYER_NAMES[li], ni]
			node.position = Vector3(x_pos, 1.5, z_pos)

			# Collision sphere
			var col = CollisionShape3D.new()
			var shape = SphereShape3D.new()
			shape.radius = 0.6
			col.shape = shape
			node.add_child(col)

			# High-detail emissive neuron sphere replacing basic SphereMesh
			var mesh = MeshInstance3D.new()
			var sphere = SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 32
			sphere.rings = 16
			mesh.mesh = sphere
			var mat = StandardMaterial3D.new()
			mat.albedo_color = NODE_INACTIVE * 0.5
			mat.emission_enabled = true
			mat.emission = NODE_INACTIVE
			mat.emission_energy_multiplier = 0.4
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.8
			mat.metallic = 0.6
			mat.roughness = 0.2
			mesh.material_override = mat
			node.add_child(mesh)

			# Inner core glow sphere
			var core = MeshInstance3D.new()
			var core_sphere = SphereMesh.new()
			core_sphere.radius = 0.2
			core_sphere.height = 0.4
			core_sphere.radial_segments = 16
			core_sphere.rings = 8
			core.mesh = core_sphere
			var core_mat = StandardMaterial3D.new()
			core_mat.albedo_color = SYNAPSE_BLUE
			core_mat.emission_enabled = true
			core_mat.emission = SYNAPSE_BLUE
			core_mat.emission_energy_multiplier = 1.5
			core.material_override = core_mat
			node.add_child(core)

			# Point light per neuron node
			var light = OmniLight3D.new()
			light.light_color = SYNAPSE_BLUE
			light.light_energy = 0.4
			light.omni_range = 1.8
			node.add_child(light)

			# GlobTarget — layer-tagged for pattern matching
			var gt = Node.new()
			gt.set_script(glob_target_script)
			gt.set("glob_name", "%s_%d" % [LAYER_NAMES[li], ni])
			gt.set("file_type", LAYER_NAMES[li])
			gt.set("tags", [LAYER_NAMES[li], "neuron", "layer_%d" % li])
			node.add_child(gt)

			# Node label
			var label = Label3D.new()
			label.text = "%s[%d]" % [LAYER_NAMES[li][0].to_upper(), ni]
			label.font_size = 10
			label.modulate = SYNAPSE_BLUE * 0.6
			label.position = Vector3(0, 0.8, 0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			node.add_child(label)

			add_child(node)
			layer_nodes.append(node)
			layer_meshes.append(mesh)
			layer_mats.append(mat)

		_nodes.append(layer_nodes)
		_node_meshes.append(layer_meshes)
		_node_mats.append(layer_mats)

	# Create connections between adjacent layers
	for li in range(total_layers - 1):
		for from_ni in range(LAYER_SIZES[li]):
			for to_ni in range(LAYER_SIZES[li + 1]):
				var from_pos = _nodes[li][from_ni].position
				var to_pos = _nodes[li + 1][to_ni].position
				_create_connection_line(from_pos, to_pos)

	# Layer labels above each column
	for li in range(total_layers):
		var x_pos = -total_width / 2.0 + li * layer_spacing
		var label = Label3D.new()
		label.text = "[ %s ]" % LAYER_NAMES[li].to_upper()
		label.font_size = 12
		label.modulate = SYNAPSE_BLUE * 0.5
		label.position = Vector3(x_pos, 3.5, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)


func _create_connection_line(from: Vector3, to: Vector3) -> void:
	# Cylinder synapse connector
	var line = MeshInstance3D.new()
	var tube = CylinderMesh.new()
	var dist = from.distance_to(to)
	tube.top_radius = 0.04
	tube.bottom_radius = 0.04
	tube.height = dist
	tube.radial_segments = 12
	line.mesh = tube

	# Position at midpoint, rotate to connect
	var mid = (from + to) / 2.0
	line.position = mid
	line.look_at_from_position(mid, to, Vector3.UP)
	line.rotation.x += PI / 2.0  # Cylinder default is Y-up, we need to aim it

	var mat = StandardMaterial3D.new()
	mat.albedo_color = NODE_INACTIVE * 0.3
	mat.emission_enabled = true
	mat.emission = NODE_INACTIVE * 0.5
	mat.emission_energy_multiplier = 0.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.4
	line.material_override = mat
	add_child(line)
	_connections.append(line)
	_connection_mats.append(mat)


func _create_label() -> void:
	_puzzle_label = Label3D.new()
	_puzzle_label.text = hint_text
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = NEON_GREEN * 0.8
	_puzzle_label.position = Vector3(0, 5.0, 0)
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_puzzle_label)

	# Status display — updates during puzzle
	_status_label = Label3D.new()
	_status_label.text = ">> Observing forward pass..."
	_status_label.font_size = 12
	_status_label.modulate = SYNAPSE_BLUE * 0.7
	_status_label.position = Vector3(0, 4.2, 0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_status_label)


func _create_door() -> void:
	_door = StaticBody3D.new()
	_door.name = "BackpropDoor"
	_door.position = Vector3(0, 2.0, -5.0)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(8.0, 4.0, 0.3)
	col.shape = shape
	_door.add_child(col)

	# GLB industrial panel replacing BoxMesh door
	var door_inst = _panel_scene.instantiate()
	door_inst.name = "DoorPanel"
	door_inst.scale = Vector3(4.0, 2.0, 1.0)
	_door.add_child(door_inst)

	# Emissive overlay for dissolve effect
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(8.0, 4.0, 0.05)
	mesh.mesh = box
	mesh.position = Vector3(0, 0, 0.2)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = GRADIENT_RED * 0.15
	mat.albedo_color.a = 0.6
	mat.emission_enabled = true
	mat.emission = GRADIENT_RED
	mat.emission_energy_multiplier = 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	_door.add_child(mesh)

	# Door label
	var label = Label3D.new()
	label.text = ">> GRADIENT GATE\n>> Backprop required"
	label.font_size = 12
	label.modulate = GRADIENT_RED * 0.8
	label.position = Vector3(0, 0, 0.2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_door.add_child(label)

	add_child(_door)


func _on_solved() -> void:
	# Full backprop traced — all nodes glow green
	for li in range(LAYER_SIZES.size()):
		for ni in range(LAYER_SIZES[li]):
			_node_mats[li][ni].emission = NEON_GREEN
			_node_mats[li][ni].emission_energy_multiplier = 2.5
	for cmat in _connection_mats:
		cmat.emission = NEON_GREEN
		cmat.emission_energy_multiplier = 2.0

	_puzzle_label.text = ">> BACKPROPAGATION COMPLETE\n>> Gradients traced successfully."
	_puzzle_label.modulate = NEON_GREEN
	_status_label.text = ">> Loss: 0.000  |  Convergence: ACHIEVED"
	_status_label.modulate = NEON_GREEN

	# Dissolve door
	if is_instance_valid(_door):
		var door_mesh: MeshInstance3D
		for child in _door.get_children():
			if child is MeshInstance3D:
				door_mesh = child
				break
		if door_mesh and door_mesh.material_override:
			var tween = create_tween()
			tween.tween_property(door_mesh.material_override, "albedo_color:a", 0.0, 0.8)
			tween.tween_callback(func(): _door.queue_free())
		else:
			_door.queue_free()


func _on_reset() -> void:
	# Reset entire puzzle — replay forward pass
	_forward_pass_done = false
	_forward_pass_timer = 0.0
	_forward_pass_layer = -1
	_backprop_step = 0

	# Reset all visuals
	for li in range(LAYER_SIZES.size()):
		for ni in range(LAYER_SIZES[li]):
			if li < _node_mats.size() and ni < _node_mats[li].size():
				_node_mats[li][ni].emission = NODE_INACTIVE
				_node_mats[li][ni].emission_energy_multiplier = 0.4
	for cmat in _connection_mats:
		cmat.emission = NODE_INACTIVE * 0.5
		cmat.emission_energy_multiplier = 0.3

	_status_label.text = ">> Observing forward pass..."
	_status_label.modulate = SYNAPSE_BLUE * 0.7
	_puzzle_label.text = hint_text
	_puzzle_label.modulate = NEON_GREEN * 0.8
