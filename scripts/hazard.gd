extends Node3D

# Hazards - Various environmental dangers in the digital landscape
# "The firewall is not a suggestion."

enum HazardType {
	FIREWALL,          # Vertical energy wall - damages on contact
	CORRUPTION_ZONE,   # Floor area that drains context over time
	FALLING_404,       # Blocks that fall from above periodically
}

@export var hazard_type: HazardType = HazardType.FIREWALL
@export var damage_per_hit := 10
@export var damage_per_second := 5  # For corruption zones
@export var pulse_on_off := false   # Firewall pulses on/off
@export var pulse_interval := 2.0
@export var moves := false          # Firewall moves back and forth
@export var move_distance := 5.0
@export var move_speed := 2.0

# Firewall state
var is_active := true
var pulse_timer := 0.0
var move_start_pos := Vector3.ZERO
var move_time := 0.0

# Falling 404 state
var fall_timer := 0.0
var fall_interval := 3.0
var falling_blocks: Array[Node3D] = []

# Corruption zone
var bodies_in_zone: Array[Node3D] = []
var corruption_timer := 0.0

var area_node: Area3D
var visual_node: Node3D

func _ready() -> void:
	move_start_pos = global_position
	match hazard_type:
		HazardType.FIREWALL:
			_create_firewall()
		HazardType.CORRUPTION_ZONE:
			_create_corruption_zone()
		HazardType.FALLING_404:
			_create_falling_404_spawner()

func _create_firewall() -> void:
	area_node = Area3D.new()
	area_node.name = "FirewallArea"
	area_node.monitoring = true

	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(4.0, 4.0, 0.5)
	col.shape = box_shape
	col.position.y = 2.0
	area_node.add_child(col)
	add_child(area_node)

	# Visual: glowing wall
	visual_node = MeshInstance3D.new()
	visual_node.name = "FirewallMesh"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(4.0, 4.0, 0.3)
	visual_node.mesh = box_mesh
	visual_node.position.y = 2.0

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.1, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.05)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual_node.material_override = mat
	add_child(visual_node)

	# Label
	var label = Label3D.new()
	label.text = ">>> FIREWALL <<<"
	label.font_size = 24
	label.modulate = Color(1.0, 0.4, 0.1)
	label.position.y = 4.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	area_node.body_entered.connect(_on_firewall_body_entered)

func _create_corruption_zone() -> void:
	area_node = Area3D.new()
	area_node.name = "CorruptionArea"
	area_node.monitoring = true

	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(6.0, 1.0, 6.0)
	col.shape = box_shape
	col.position.y = 0.5
	area_node.add_child(col)
	add_child(area_node)

	# Visual: toxic floor
	visual_node = MeshInstance3D.new()
	visual_node.name = "CorruptionMesh"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(6.0, 0.15, 6.0)
	visual_node.mesh = box_mesh
	visual_node.position.y = 0.08

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.1, 0.6, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.05, 0.5)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual_node.material_override = mat
	add_child(visual_node)

	# Corruption particles
	var particles = GPUParticles3D.new()
	particles.amount = 20
	particles.lifetime = 1.5
	particles.position.y = 0.5

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 45.0
	pmat.initial_velocity_min = 0.5
	pmat.initial_velocity_max = 1.5
	pmat.gravity = Vector3(0, -0.5, 0)
	pmat.scale_min = 0.03
	pmat.scale_max = 0.08
	pmat.color = Color(0.7, 0.1, 0.7, 0.6)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(3.0, 0.1, 3.0)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.05
	pmesh.height = 0.1
	particles.draw_pass_1 = pmesh
	add_child(particles)

	# Label
	var label = Label3D.new()
	label.text = "! DATA CORRUPTION !"
	label.font_size = 20
	label.modulate = Color(0.8, 0.2, 0.8)
	label.position.y = 1.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	area_node.body_entered.connect(_on_corruption_entered)
	area_node.body_exited.connect(_on_corruption_exited)

func _create_falling_404_spawner() -> void:
	# Warning sign
	var label = Label3D.new()
	label.text = "!! 404 ZONE !!"
	label.font_size = 24
	label.modulate = Color(1.0, 0.8, 0.2)
	label.position.y = 8.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	# Warning floor area
	visual_node = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(6, 6)
	visual_node.mesh = plane
	visual_node.position.y = 0.02

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.6, 0.1, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.4, 0.05)
	mat.emission_energy_multiplier = 1.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual_node.material_override = mat
	add_child(visual_node)

func _process(delta: float) -> void:
	match hazard_type:
		HazardType.FIREWALL:
			_process_firewall(delta)
		HazardType.CORRUPTION_ZONE:
			_process_corruption(delta)
		HazardType.FALLING_404:
			_process_falling_404(delta)

func _process_firewall(delta: float) -> void:
	# Pulse on/off
	if pulse_on_off:
		pulse_timer += delta
		if pulse_timer >= pulse_interval:
			pulse_timer = 0.0
			is_active = not is_active
			if visual_node:
				visual_node.visible = is_active
			if area_node:
				area_node.monitoring = is_active

	# Move back and forth
	if moves:
		move_time += delta
		var offset = sin(move_time * move_speed) * move_distance
		global_position = move_start_pos + Vector3(offset, 0, 0)

func _process_corruption(delta: float) -> void:
	corruption_timer += delta
	if corruption_timer >= 1.0:
		corruption_timer = 0.0
		for body in bodies_in_zone:
			if body and is_instance_valid(body) and body.has_method("take_damage"):
				body.take_damage(damage_per_second)

	# Pulse visual
	if visual_node and visual_node.material_override:
		var pulse = 0.3 + abs(sin(Time.get_ticks_msec() * 0.003)) * 0.3
		visual_node.material_override.albedo_color.a = pulse

func _process_falling_404(delta: float) -> void:
	fall_timer += delta
	if fall_timer >= fall_interval:
		fall_timer = 0.0
		_spawn_falling_block()

	# Clean up landed blocks
	var to_remove: Array[int] = []
	for i in falling_blocks.size():
		if not is_instance_valid(falling_blocks[i]):
			to_remove.append(i)
	to_remove.reverse()
	for idx in to_remove:
		falling_blocks.remove_at(idx)

func _spawn_falling_block() -> void:
	var block = Area3D.new()
	block.monitoring = true

	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.5, 1.5, 1.5)
	col.shape = box_shape
	block.add_child(col)

	var mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.5, 1.5, 1.5)
	mesh.mesh = box_mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.3, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.2, 0.05)
	mat.emission_energy_multiplier = 1.5
	mesh.material_override = mat
	block.add_child(mesh)

	# 404 label on block
	var label = Label3D.new()
	label.text = "404"
	label.font_size = 48
	label.modulate = Color(1.0, 0.5, 0.1)
	label.position.z = 0.8
	block.add_child(label)

	var rand_x = randf_range(-2.5, 2.5)
	var rand_z = randf_range(-2.5, 2.5)
	block.global_position = global_position + Vector3(rand_x, 12.0, rand_z)
	add_child(block)
	falling_blocks.append(block)

	block.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage_per_hit)
	)

	# Animate falling
	var tween = block.create_tween()
	tween.tween_property(block, "position:y", block.position.y - 12.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_interval(1.5)
	tween.tween_property(block, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tween.tween_callback(block.queue_free)

func _on_firewall_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage_per_hit)

func _on_corruption_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		bodies_in_zone.append(body)

func _on_corruption_exited(body: Node3D) -> void:
	bodies_in_zone.erase(body)
