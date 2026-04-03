extends "res://scenes/enemies/base_enemy.gd"

# Vanishing Gradient Wisp — Gets weaker the farther from its spawn point
# "I started this journey full of purpose and gradient magnitude.
#  Now I can barely update a single weight. This is fine."
#
# Behavior: Spawns bright and powerful near its origin (a "deep layer" anchor).
# As it moves farther away to chase the player, its damage, speed, and visibility
# all diminish — the vanishing gradient problem made flesh. If it gets too far,
# it nearly disappears and becomes harmless. Smart players lure them away.
# But near their anchor? They're deadly little things.

const MAX_WANDER_RANGE := 18.0  # Beyond this, basically invisible and harmless
const FADE_START_RANGE := 5.0  # Start fading after this distance from anchor
const PULSE_SPEED := 3.0  # Oscillation speed of the glow
const BOLT_COOLDOWN := 2.5  # Ranged attack cooldown
const BOLT_SPEED := 10.0
const BOLT_DAMAGE_BASE := 14  # Damage at full gradient
const BOLT_RANGE := 10.0
const SWARM_RADIUS := 2.5  # Circle radius when swarming near anchor
const SWARM_SPEED := 5.0

var anchor_position := Vector3.ZERO  # Where we spawned — our "deep layer"
var gradient_strength := 1.0  # 0.0 to 1.0 — our power level based on distance
var bolt_timer := 0.0
var swarm_angle := 0.0  # For circular swarming behavior
var wisp_trail: GPUParticles3D
var wisp_light: OmniLight3D
var gradient_label: Label3D

func _ready() -> void:
	enemy_name = "vanishing_gradient_wisp.enemy"
	enemy_tags = ["hostile", "chapter2", "wisp", "neural"]
	max_health = 2  # Fragile at any distance
	contact_damage = 8  # Base contact damage (scaled by gradient)
	patrol_speed = 4.0
	chase_speed = 6.0
	detection_range = 12.0
	attack_range = BOLT_RANGE
	token_drop_count = 1
	super._ready()
	anchor_position = global_position
	swarm_angle = randf() * TAU  # Random start angle for swarming

func _create_visual() -> void:
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 1.2  # Wisps float high

	# Wisp core — small glowing sphere, intense at full gradient
	var wisp_mesh = SphereMesh.new()
	wisp_mesh.radius = 0.25
	wisp_mesh.height = 0.5
	mesh_node.mesh = wisp_mesh

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.8, 0.15, 0.1, 0.9)  # Red-orange gradient color
	base_material.emission_enabled = true
	base_material.emission = Color(0.9, 0.2, 0.05)
	base_material.emission_energy_multiplier = 6.0
	base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_material.metallic = 0.0
	base_material.roughness = 1.0
	mesh_node.material_override = base_material
	add_child(mesh_node)

	# Inner core — brighter, smaller sphere
	var inner = MeshInstance3D.new()
	var inner_mesh = SphereMesh.new()
	inner_mesh.radius = 0.12
	inner.mesh = inner_mesh
	inner.position.y = 0.0

	var inner_mat = StandardMaterial3D.new()
	inner_mat.albedo_color = Color(1.0, 0.8, 0.2)
	inner_mat.emission_enabled = true
	inner_mat.emission = Color(1.0, 0.9, 0.3)
	inner_mat.emission_energy_multiplier = 8.0
	inner.material_override = inner_mat
	inner.name = "InnerCore"
	mesh_node.add_child(inner)

	# Orbiting gradient fragments — tiny cubes circling the wisp
	var frag_mat = StandardMaterial3D.new()
	frag_mat.albedo_color = Color(0.9, 0.3, 0.1, 0.7)
	frag_mat.emission_enabled = true
	frag_mat.emission = Color(0.8, 0.2, 0.05)
	frag_mat.emission_energy_multiplier = 3.0
	frag_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for i in range(3):
		var frag = MeshInstance3D.new()
		var frag_mesh = BoxMesh.new()
		frag_mesh.size = Vector3(0.06, 0.06, 0.06)
		frag.mesh = frag_mesh
		frag.material_override = frag_mat
		frag.name = "Fragment_%d" % i
		mesh_node.add_child(frag)

	# Gradient strength label
	gradient_label = Label3D.new()
	gradient_label.text = "∇=1.00"
	gradient_label.font_size = 20
	gradient_label.modulate = Color(1.0, 0.4, 0.1)
	gradient_label.position = Vector3(0, 0.6, 0)
	gradient_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gradient_label.no_depth_test = true
	mesh_node.add_child(gradient_label)

	# Dynamic light — intensity scales with gradient strength
	wisp_light = OmniLight3D.new()
	wisp_light.light_color = Color(0.9, 0.3, 0.05)
	wisp_light.light_energy = 3.0
	wisp_light.omni_range = 5.0
	wisp_light.position.y = 1.2
	wisp_light.name = "WispLight"
	add_child(wisp_light)

	# Particle trail — fading embers behind the wisp
	wisp_trail = GPUParticles3D.new()
	wisp_trail.name = "WispTrail"
	wisp_trail.amount = 20
	wisp_trail.emitting = true
	wisp_trail.position.y = 1.2
	wisp_trail.lifetime = 1.0

	var pmaterial = ParticleProcessMaterial.new()
	pmaterial.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmaterial.emission_sphere_radius = 0.15
	pmaterial.direction = Vector3(0, -0.5, 0)
	pmaterial.spread = 60.0
	pmaterial.initial_velocity_min = 0.2
	pmaterial.initial_velocity_max = 0.5
	pmaterial.gravity = Vector3(0, -1.0, 0)
	pmaterial.scale_min = 0.03
	pmaterial.scale_max = 0.08
	pmaterial.color = Color(0.9, 0.3, 0.05, 0.6)
	wisp_trail.process_material = pmaterial

	var trail_mesh = SphereMesh.new()
	trail_mesh.radius = 0.04
	wisp_trail.draw_pass_1 = trail_mesh
	add_child(wisp_trail)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Update gradient strength based on distance from anchor
	var dist_from_anchor = global_position.distance_to(anchor_position)
	if dist_from_anchor <= FADE_START_RANGE:
		gradient_strength = 1.0
	elif dist_from_anchor >= MAX_WANDER_RANGE:
		gradient_strength = 0.05  # Never truly zero — even vanishing gradients have dreams
	else:
		var fade_range = MAX_WANDER_RANGE - FADE_START_RANGE
		gradient_strength = 1.0 - ((dist_from_anchor - FADE_START_RANGE) / fade_range) * 0.95

	# Update visuals based on gradient strength
	_update_gradient_visuals(delta)

	# Orbit fragments
	_animate_fragments(delta)

	# Bob up and down
	if mesh_node:
		mesh_node.position.y = 1.2 + sin(Time.get_ticks_msec() * 0.004) * 0.2

func _update_gradient_visuals(delta: float) -> void:
	var pulse = (sin(Time.get_ticks_msec() * 0.001 * PULSE_SPEED) + 1.0) * 0.5

	if base_material:
		# Color shifts from hot red-orange (strong) to cold dim red (weak)
		var strong_color = Color(0.9, 0.2, 0.05)
		var weak_color = Color(0.3, 0.05, 0.02)
		var current_emission = strong_color.lerp(weak_color, 1.0 - gradient_strength)

		base_material.emission = current_emission
		base_material.emission_energy_multiplier = (4.0 + pulse * 2.0) * gradient_strength
		base_material.albedo_color.a = 0.3 + gradient_strength * 0.6

	# Light intensity scales with gradient
	if wisp_light:
		wisp_light.light_energy = 3.0 * gradient_strength
		wisp_light.omni_range = 3.0 + gradient_strength * 3.0

	# Trail particles scale with gradient
	if wisp_trail:
		wisp_trail.amount = int(5 + gradient_strength * 15)

	# Update label
	if gradient_label:
		gradient_label.text = "∇=%.2f" % gradient_strength
		gradient_label.modulate.a = 0.3 + gradient_strength * 0.7

func _animate_fragments(delta: float) -> void:
	if not mesh_node:
		return

	var t = Time.get_ticks_msec() * 0.002
	for i in range(3):
		var frag = mesh_node.get_node_or_null("Fragment_%d" % i)
		if frag:
			var angle = t + i * TAU / 3.0
			var orbit_radius = 0.4 * gradient_strength  # Orbit shrinks as gradient vanishes
			frag.position = Vector3(cos(angle) * orbit_radius, sin(angle * 0.7) * 0.15, sin(angle) * orbit_radius)
			# Fragments fade with gradient
			if frag.material_override:
				frag.material_override.albedo_color.a = gradient_strength * 0.7

func _state_patrol(delta: float) -> void:
	if _can_see_player():
		_change_state(EnemyState.ALERT)
		return

	# Wisps circle their anchor point when idle — like electrons around a nucleus
	# (or gradients around a local minimum, if you want to be thematic about it)
	swarm_angle += SWARM_SPEED * delta / SWARM_RADIUS
	var target = anchor_position + Vector3(cos(swarm_angle) * SWARM_RADIUS, 0, sin(swarm_angle) * SWARM_RADIUS)

	var dir = (target - global_position)
	dir.y = 0
	if dir.length() > 0.3:
		dir = dir.normalized()
		velocity.x = dir.x * patrol_speed
		velocity.z = dir.z * patrol_speed
	else:
		velocity.x = 0
		velocity.z = 0

func _state_chase(delta: float) -> void:
	if not player_ref:
		_change_state(EnemyState.PATROL)
		return

	var dist_to_player = global_position.distance_to(player_ref.global_position)
	var dist_from_anchor = global_position.distance_to(anchor_position)

	# If gradient is almost gone, retreat back to anchor — self-preservation
	if gradient_strength < 0.15:
		var retreat_dir = (anchor_position - global_position)
		retreat_dir.y = 0
		if retreat_dir.length() > 1.0:
			retreat_dir = retreat_dir.normalized()
			velocity.x = retreat_dir.x * chase_speed
			velocity.z = retreat_dir.z * chase_speed
		else:
			_change_state(EnemyState.PATROL)
		return

	# Chase but with awareness of our tether — speed scales with gradient
	var dir = (player_ref.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.1:
		dir = dir.normalized()
		var effective_speed = chase_speed * gradient_strength
		velocity.x = dir.x * effective_speed
		velocity.z = dir.z * effective_speed

	# Ranged attack — fire gradient bolt
	bolt_timer -= delta
	if bolt_timer <= 0 and dist_to_player < BOLT_RANGE and gradient_strength > 0.3:
		_fire_gradient_bolt()
		bolt_timer = BOLT_COOLDOWN / gradient_strength  # Attacks slower when weak

	# If player runs away far enough, return to anchor
	if dist_to_player > detection_range * 1.5 or dist_from_anchor > MAX_WANDER_RANGE:
		_change_state(EnemyState.PATROL)

func _perform_attack() -> void:
	if gradient_strength > 0.3:
		_fire_gradient_bolt()
	enemy_attacked.emit(self, player_ref)

func _fire_gradient_bolt() -> void:
	if not player_ref:
		return

	# Create a gradient bolt projectile — damage scales with gradient strength
	var bolt = Area3D.new()
	bolt.name = "GradientBolt"

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.2
	col.shape = shape
	bolt.add_child(col)

	# Visual — glowing sphere that dims based on gradient
	var bolt_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15 + gradient_strength * 0.1
	bolt_mesh.mesh = sphere

	var bolt_mat = StandardMaterial3D.new()
	bolt_mat.albedo_color = Color(1.0, 0.3, 0.1, 0.8)
	bolt_mat.emission_enabled = true
	bolt_mat.emission = Color(0.9, 0.2, 0.05)
	bolt_mat.emission_energy_multiplier = 4.0 * gradient_strength
	bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt_mesh.material_override = bolt_mat
	bolt.add_child(bolt_mesh)

	# Light on the bolt
	var bolt_light = OmniLight3D.new()
	bolt_light.light_color = Color(0.9, 0.3, 0.05)
	bolt_light.light_energy = 1.5 * gradient_strength
	bolt_light.omni_range = 2.0
	bolt.add_child(bolt_light)

	bolt.global_position = global_position + Vector3(0, 1.2, 0)
	bolt.monitoring = true

	var bolt_dir = (player_ref.global_position + Vector3(0, 1, 0) - bolt.global_position).normalized()
	var scaled_damage = int(BOLT_DAMAGE_BASE * gradient_strength)

	bolt.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			var health_comp = body.get_node_or_null("HealthComponent")
			if health_comp and health_comp.has_method("take_damage"):
				health_comp.take_damage(scaled_damage, self)
			bolt.queue_free()
	)

	get_tree().current_scene.add_child(bolt)

	# Move the bolt — simple linear projectile
	var tween = bolt.create_tween()
	var end_pos = bolt.global_position + bolt_dir * BOLT_RANGE
	tween.tween_property(bolt, "global_position", end_pos, BOLT_RANGE / BOLT_SPEED)
	tween.tween_callback(func():
		if is_instance_valid(bolt):
			bolt.queue_free()
	)
