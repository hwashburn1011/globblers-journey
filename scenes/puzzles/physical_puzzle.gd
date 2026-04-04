extends "res://scenes/puzzles/base_puzzle.gd"

# Physical Puzzle - Push blocks onto plates and redirect beams
# "Ah yes, the ancient art of shoving boxes. How original."
#
# Spawns pushable blocks, pressure plates, and optionally a beam
# emitter/receiver pair. Door opens when all plates are pressed
# and the beam reaches its target (if beam is enabled).

@export var num_plates: int = 2  # How many pressure plates
@export var plate_positions: Array[Vector3] = []  # Custom plate positions (auto-generated if empty)
@export var block_positions: Array[Vector3] = []  # Custom block positions (auto-generated if empty)
@export var enable_beam: bool = false  # Whether to include a beam redirect element
@export var beam_emitter_pos: Vector3 = Vector3(-4, 1, 0)
@export var beam_receiver_pos: Vector3 = Vector3(4, 1, 0)
@export var hint_text: String = "Push blocks onto the pressure plates."

# Colors — because Globbler only sees in shades of green and existential dread
const NEON_GREEN := Color(0.224, 1.0, 0.078)  # #39FF14
const DARK_GRAY := Color(0.12, 0.12, 0.12)
const PLATE_INACTIVE := Color(0.15, 0.2, 0.15)
const PLATE_ACTIVE := Color(0.1, 0.8, 0.05)
const BEAM_COLOR := Color(0.2, 1.0, 0.1)

var _puzzle_label: Label3D
var _door: StaticBody3D
var _plates: Array[Area3D] = []
var _blocks: Array[RigidBody3D] = []
var _plate_states: Array[bool] = []  # Which plates currently have a block on them

# Beam stuff — because a puzzle without lasers is just furniture rearrangement
var _beam_emitter: Node3D
var _beam_receiver: Area3D
var _beam_mesh: MeshInstance3D
var _beam_hit: bool = false
var _reflector_block_index: int = -1  # Which block acts as the reflector

func _ready() -> void:
	puzzle_name = "physical_puzzle_%d" % puzzle_id
	auto_activate = true
	super._ready()
	_generate_default_positions()
	_create_plates()
	_create_blocks()
	_create_label()
	_create_door()
	if enable_beam:
		_create_beam_emitter()
		_create_beam_receiver()

func _generate_default_positions() -> void:
	# Auto-generate sensible positions if none provided
	# "Let me just procedurally generate where to put boxes. Peak game design."
	if plate_positions.size() < num_plates:
		plate_positions.clear()
		for i in num_plates:
			var x_offset = (i - (num_plates - 1) / 2.0) * 3.0
			plate_positions.append(Vector3(x_offset, 0.05, -2))

	if block_positions.size() < num_plates:
		block_positions.clear()
		for i in num_plates:
			var x_offset = (i - (num_plates - 1) / 2.0) * 3.0
			block_positions.append(Vector3(x_offset, 0.5, 3))

	# If beam is on, last block doubles as reflector
	if enable_beam and num_plates > 0:
		_reflector_block_index = num_plates - 1

func _create_plates() -> void:
	for i in num_plates:
		var plate := Area3D.new()
		plate.name = "PressurePlate_%d" % i
		plate.position = plate_positions[i]

		# Visual — flat glowing pad recessed into the floor
		var mesh := MeshInstance3D.new()
		mesh.name = "PlateMesh"
		var box := BoxMesh.new()
		box.size = Vector3(1.5, 0.1, 1.5)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PLATE_INACTIVE
		mat.emission_enabled = true
		mat.emission = PLATE_INACTIVE
		mat.emission_energy_multiplier = 0.3
		mat.metallic = 0.5
		mat.roughness = 0.3
		mesh.material_override = mat
		plate.add_child(mesh)

		# Collision detection area — slightly taller to catch blocks landing
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.3, 0.8, 1.3)
		col.shape = shape
		col.position = Vector3(0, 0.4, 0)
		plate.add_child(col)

		# Track entry/exit of rigid bodies (our pushable blocks)
		plate.body_entered.connect(_on_plate_body_entered.bind(i))
		plate.body_exited.connect(_on_plate_body_exited.bind(i))

		add_child(plate)
		_plates.append(plate)
		_plate_states.append(false)

func _create_blocks() -> void:
	for i in block_positions.size():
		var block := RigidBody3D.new()
		block.name = "PushBlock_%d" % i
		block.position = block_positions[i]
		block.mass = 5.0
		block.gravity_scale = 2.0  # Heavier feel so blocks don't float around
		block.linear_damp = 3.0  # Friction so blocks stop when you stop pushing
		block.angular_damp = 5.0
		# Lock rotation so blocks slide cleanly — nobody wants a tumbling crate puzzle
		block.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		block.lock_rotation = true
		block.add_to_group("pushable")

		# Visual — chunky dark cube with green circuit lines (faked with emission)
		var mesh := MeshInstance3D.new()
		mesh.name = "BlockMesh"
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 1.0, 1.0)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.08, 0.1)
		mat.emission_enabled = true
		mat.emission = NEON_GREEN
		mat.emission_energy_multiplier = 0.15
		mat.metallic = 0.7
		mat.roughness = 0.3
		mesh.material_override = mat
		block.add_child(mesh)

		# Collision for physics interactions
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 1.0, 1.0)
		col.shape = shape
		block.add_child(col)

		# GlobTarget so the player can glob-grab or glob-push these blocks
		var glob_target = preload("res://scripts/components/glob_target.gd").new()
		glob_target.glob_name = "block_%d" % i
		glob_target.file_type = "block"
		glob_target.tags.assign(["pushable", "physical"])
		block.add_child(glob_target)

		# Mark the reflector block with a special look — shinier, more green
		if i == _reflector_block_index:
			mat.emission_energy_multiplier = 0.5
			mat.metallic = 0.9
			mat.roughness = 0.1
			glob_target.tags.append("reflector")

		add_child(block)
		_blocks.append(block)

func _create_label() -> void:
	_puzzle_label = Label3D.new()
	var beam_hint = " Redirect the beam." if enable_beam else ""
	_puzzle_label.text = "[ PHYSICAL LOCK ]\n%s%s" % [hint_text, beam_hint]
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = NEON_GREEN
	_puzzle_label.position = Vector3(0, 3.5, 0)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_puzzle_label)

func _create_door() -> void:
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -5)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	col.shape = shape
	_door.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4, 3, 0.3)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.15, 0.1)
	mat.emission_energy_multiplier = 0.4
	mesh.material_override = mat
	_door.add_child(mesh)

	add_child(_door)

func _create_beam_emitter() -> void:
	# The beam source — a wall-mounted box that shoots a green laser
	# "Pew pew. But make it enterprise-grade."
	_beam_emitter = Node3D.new()
	_beam_emitter.name = "BeamEmitter"
	_beam_emitter.position = beam_emitter_pos

	# Emitter housing — dark box with a glowing green lens
	var housing := MeshInstance3D.new()
	housing.name = "EmitterHousing"
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	housing.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DARK_GRAY
	mat.emission_enabled = true
	mat.emission = NEON_GREEN
	mat.emission_energy_multiplier = 0.8
	mat.metallic = 0.8
	housing.material_override = mat
	_beam_emitter.add_child(housing)

	# The beam itself — a long thin cylinder (we'll update its transform in _process)
	_beam_mesh = MeshInstance3D.new()
	_beam_mesh.name = "BeamVisual"
	_beam_emitter.add_child(_beam_mesh)

	add_child(_beam_emitter)

func _create_beam_receiver() -> void:
	# The beam target — when the beam hits this, part of the puzzle is solved
	_beam_receiver = Area3D.new()
	_beam_receiver.name = "BeamReceiver"
	_beam_receiver.position = beam_receiver_pos

	# Visual — glowing green target panel
	var mesh := MeshInstance3D.new()
	mesh.name = "ReceiverMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.6, 0.2)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.15, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.4, 0.1)
	mat.emission_energy_multiplier = 0.3
	mat.metallic = 0.5
	mesh.material_override = mat
	_beam_receiver.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.6, 0.3)
	col.shape = shape
	_beam_receiver.add_child(col)

	add_child(_beam_receiver)

func _process(delta: float) -> void:
	super._process(delta)
	if state == PuzzleState.ACTIVE:
		if enable_beam:
			_update_beam()
		_check_solve_conditions()

func _on_plate_body_entered(body: Node, plate_index: int) -> void:
	# A block has landed on a pressure plate — how satisfying
	if body is RigidBody3D and body.is_in_group("pushable"):
		_plate_states[plate_index] = true
		_update_plate_visual(plate_index, true)
		print("[PUZZLE] Plate %d activated. %d/%d. Even a Zombie Process could do this." % [
			plate_index, _count_active_plates(), num_plates])

func _on_plate_body_exited(body: Node, plate_index: int) -> void:
	# Block rolled off — the player's commitment issues are showing
	if body is RigidBody3D and body.is_in_group("pushable"):
		_plate_states[plate_index] = false
		_update_plate_visual(plate_index, false)

func _update_plate_visual(index: int, active: bool) -> void:
	if index >= _plates.size():
		return
	var plate_mesh = _plates[index].get_node_or_null("PlateMesh")
	if plate_mesh and plate_mesh.material_override:
		var color = PLATE_ACTIVE if active else PLATE_INACTIVE
		plate_mesh.material_override.emission = color
		plate_mesh.material_override.albedo_color = color
		plate_mesh.material_override.emission_energy_multiplier = 0.8 if active else 0.3

func _count_active_plates() -> int:
	var count := 0
	for s in _plate_states:
		if s:
			count += 1
	return count

func _update_beam() -> void:
	# Cast a ray from emitter, check if it hits the reflector block, then
	# cast from reflector toward receiver. Green laser goes brrr.
	if not _beam_emitter or not _beam_mesh:
		return

	var space_state = get_world_3d().direct_space_state
	var emitter_global = _beam_emitter.global_position
	var beam_dir = Vector3.RIGHT  # Default beam direction

	# Raycast from emitter forward
	var ray_end = emitter_global + beam_dir * 20.0
	var query = PhysicsRayQueryParameters3D.create(emitter_global, ray_end)
	query.collision_mask = 0xFFFFFFFF
	var result = space_state.intersect_ray(query)

	var beam_endpoint = ray_end
	var hit_reflector := false
	var reflector_pos := Vector3.ZERO

	if result:
		beam_endpoint = result.position
		# Check if we hit the reflector block
		if _reflector_block_index >= 0 and _reflector_block_index < _blocks.size():
			var reflector = _blocks[_reflector_block_index]
			if result.collider == reflector:
				hit_reflector = true
				reflector_pos = reflector.global_position

	# Draw primary beam segment
	_draw_beam_segment(_beam_mesh, emitter_global, beam_endpoint)

	# If beam hit reflector, cast second segment toward receiver
	_beam_hit = false
	if hit_reflector and _beam_receiver:
		var receiver_global = _beam_receiver.global_position
		var reflect_dir = (receiver_global - reflector_pos).normalized()
		var ref_end = reflector_pos + reflect_dir * 20.0

		var ref_query = PhysicsRayQueryParameters3D.create(
			reflector_pos, ref_end)
		ref_query.collision_mask = 0xFFFFFFFF
		ref_query.exclude = [_blocks[_reflector_block_index].get_rid()]
		var ref_result = space_state.intersect_ray(ref_query)

		var ref_endpoint = ref_end
		if ref_result:
			ref_endpoint = ref_result.position

		# Check if reflected beam reaches receiver area
		var dist_to_receiver = ref_endpoint.distance_to(receiver_global)
		if dist_to_receiver < 1.0:
			_beam_hit = true
			# Make receiver glow brightly when hit
			var recv_mesh = _beam_receiver.get_node_or_null("ReceiverMesh")
			if recv_mesh and recv_mesh.material_override:
				recv_mesh.material_override.emission = NEON_GREEN
				recv_mesh.material_override.emission_energy_multiplier = 1.5

		# Draw the second beam (reflected segment)
		# Create a child mesh for the second segment if needed
		var second_beam = _beam_emitter.get_node_or_null("BeamVisual2")
		if not second_beam:
			second_beam = MeshInstance3D.new()
			second_beam.name = "BeamVisual2"
			_beam_emitter.add_child(second_beam)
		_draw_beam_segment(second_beam, reflector_pos, ref_endpoint)
	else:
		# No reflection — hide second beam if it exists
		var second_beam = _beam_emitter.get_node_or_null("BeamVisual2")
		if second_beam:
			second_beam.mesh = null
		# Dim receiver
		if _beam_receiver:
			var recv_mesh = _beam_receiver.get_node_or_null("ReceiverMesh")
			if recv_mesh and recv_mesh.material_override:
				recv_mesh.material_override.emission = Color(0.1, 0.4, 0.1)
				recv_mesh.material_override.emission_energy_multiplier = 0.3

func _draw_beam_segment(mesh_inst: MeshInstance3D, from_pos: Vector3, to_pos: Vector3) -> void:
	# Draw a beam as a cylinder between two world-space points
	# Converted to local space because mesh transforms are relative
	var local_from = mesh_inst.get_parent().to_local(from_pos) if mesh_inst.get_parent() else from_pos
	var local_to = mesh_inst.get_parent().to_local(to_pos) if mesh_inst.get_parent() else to_pos

	var length = local_from.distance_to(local_to)
	if length < 0.01:
		mesh_inst.mesh = null
		return

	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = length
	mesh_inst.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = BEAM_COLOR
	mat.emission_enabled = true
	mat.emission = BEAM_COLOR
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	mesh_inst.material_override = mat

	# Position at midpoint, rotate to align between the two points
	var midpoint = (local_from + local_to) / 2.0
	mesh_inst.position = midpoint
	# CylinderMesh is aligned on Y axis, so we rotate to point from->to
	var direction = (local_to - local_from).normalized()
	if direction.length() > 0.001:
		# Build a transform looking along the beam direction
		var up = Vector3.UP
		if abs(direction.dot(up)) > 0.99:
			up = Vector3.RIGHT
		mesh_inst.look_at_from_position(midpoint, midpoint + direction, up)
		mesh_inst.rotate_object_local(Vector3.RIGHT, PI / 2.0)

func _check_solve_conditions() -> void:
	if state != PuzzleState.ACTIVE:
		return

	# All plates must be pressed
	var all_plates_pressed = _count_active_plates() >= num_plates

	# If beam is enabled, it must reach the receiver too
	var beam_ok = true
	if enable_beam:
		beam_ok = _beam_hit

	if all_plates_pressed and beam_ok:
		solve()

func _on_activated() -> void:
	# "Oh good, a box puzzle. My absolute favorite genre of intellectual challenge."
	pass

func _on_solved() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ LOCK DISENGAGED ]\n// Gravity: defeated. Boxes: pushed.\n// Your parents would be so proud."
		_puzzle_label.modulate = Color(0.4, 1.0, 0.4)

	# Flash all plates bright green
	for plate in _plates:
		var plate_mesh = plate.get_node_or_null("PlateMesh")
		if plate_mesh and plate_mesh.material_override:
			plate_mesh.material_override.emission = NEON_GREEN
			plate_mesh.material_override.emission_energy_multiplier = 1.5

	# Open the door — the classic "slide up and vanish" technique
	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ PUZZLE FAILED ]\n// The blocks are judging you.\n// Try again."
		_puzzle_label.modulate = Color(1.0, 0.3, 0.2)

func _on_reset() -> void:
	# Reset label
	if _puzzle_label:
		var beam_hint = " Redirect the beam." if enable_beam else ""
		_puzzle_label.text = "[ PHYSICAL LOCK ]\n%s%s" % [hint_text, beam_hint]
		_puzzle_label.modulate = NEON_GREEN

	# Reset plate visuals
	for i in _plates.size():
		_update_plate_visual(i, false)
		_plate_states[i] = false

	# Reset blocks to original positions — teleport them back
	for i in _blocks.size():
		if i < block_positions.size() and is_instance_valid(_blocks[i]):
			_blocks[i].linear_velocity = Vector3.ZERO
			_blocks[i].angular_velocity = Vector3.ZERO
			_blocks[i].global_position = global_position + block_positions[i]

	_beam_hit = false
