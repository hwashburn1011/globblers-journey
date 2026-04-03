extends "res://scenes/enemies/base_enemy.gd"

# Dropout Ghost — Randomly vanishes and reappears somewhere else
# "Now you see me, now you — oh wait, I dropped out again.
#  Regularization is just socially acceptable ghosting."
#
# Behavior: Periodically "drops out" (vanishes with transparency tween),
# teleports to a new position near the player, then fades back in.
# While invisible, it's invulnerable. While visible, it's fragile.
# Mirrors the dropout regularization technique — random deactivation.

const DROPOUT_INTERVAL_MIN := 3.0  # Min time between dropout events
const DROPOUT_INTERVAL_MAX := 6.0  # Max time between dropout events
const DROPOUT_DURATION := 1.8  # How long we stay invisible
const FADE_TIME := 0.4  # Fade in/out duration
const TELEPORT_RANGE_MIN := 4.0  # Min teleport distance from player
const TELEPORT_RANGE_MAX := 8.0  # Max teleport distance from player
const LUNGE_SPEED := 12.0  # Speed of surprise attack after reappearing
const LUNGE_DURATION := 0.5  # How long the lunge lasts
const LUNGE_DAMAGE := 12

var dropout_timer := 0.0
var is_dropped_out := false  # Currently invisible
var is_fading := false  # Mid-transition
var lunge_timer := 0.0
var is_lunging := false
var lunge_direction := Vector3.ZERO
var original_y := 0.0
var ghost_particles: GPUParticles3D  # Residual particles when dropped out
var body_opacity := 1.0

func _ready() -> void:
	enemy_name = "dropout_ghost.enemy"
	enemy_tags = ["hostile", "chapter2", "ghost", "neural"]
	max_health = 2  # Fragile when visible — that's the tradeoff
	contact_damage = LUNGE_DAMAGE
	patrol_speed = 3.0
	chase_speed = 4.5  # Normal chase is slow — the lunge is the real threat
	detection_range = 16.0  # Can see far — ghosts have great perception
	attack_range = 2.0
	token_drop_count = 2
	super._ready()
	original_y = global_position.y
	dropout_timer = randf_range(DROPOUT_INTERVAL_MIN, DROPOUT_INTERVAL_MAX)

func _create_visual() -> void:
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.8

	# Ghost body — elongated sphere, ethereal and wispy
	var ghost_mesh = SphereMesh.new()
	ghost_mesh.radius = 0.5
	ghost_mesh.height = 1.3
	mesh_node.mesh = ghost_mesh

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.15, 0.3, 0.8, 0.75)  # Translucent blue
	base_material.emission_enabled = true
	base_material.emission = Color(0.1, 0.3, 0.9)
	base_material.emission_energy_multiplier = 3.0
	base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_material.metallic = 0.1
	base_material.roughness = 0.8
	mesh_node.material_override = base_material
	add_child(mesh_node)

	# Hollow "eyes" — dark voids in the ghost face
	var void_mat = StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.9)
	void_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	void_mat.emission_enabled = true
	void_mat.emission = Color(0.0, 0.1, 0.3)
	void_mat.emission_energy_multiplier = 1.0

	for side in [-1, 1]:
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.08
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.15, 0.15, 0.42)
		eye.material_override = void_mat
		mesh_node.add_child(eye)

	# Wispy tail — tapered cylinder hanging below
	var tail = MeshInstance3D.new()
	var tail_mesh = CylinderMesh.new()
	tail_mesh.top_radius = 0.3
	tail_mesh.bottom_radius = 0.05
	tail_mesh.height = 0.7
	tail.mesh = tail_mesh
	tail.position.y = -0.7

	var tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.1, 0.2, 0.7, 0.5)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(0.1, 0.25, 0.8)
	tail_mat.emission_energy_multiplier = 2.0
	tail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tail.material_override = tail_mat
	mesh_node.add_child(tail)

	# "Probability" text floating nearby — shows dropout chance
	var prob_label = Label3D.new()
	prob_label.text = "p=0.35"
	prob_label.font_size = 24
	prob_label.modulate = Color(0.3, 0.5, 1.0, 0.6)
	prob_label.position = Vector3(0, 1.0, 0)
	prob_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prob_label.no_depth_test = true
	mesh_node.add_child(prob_label)

	# Spectral glow
	var light = OmniLight3D.new()
	light.light_color = Color(0.1, 0.3, 0.9)
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.position.y = 0.8
	light.name = "GhostLight"
	add_child(light)

	# Residual particles — faint sparkles that remain when dropped out (breadcrumbs)
	ghost_particles = GPUParticles3D.new()
	ghost_particles.name = "DropoutParticles"
	ghost_particles.amount = 12
	ghost_particles.emitting = false
	ghost_particles.position.y = 0.8

	var pmaterial = ParticleProcessMaterial.new()
	pmaterial.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmaterial.emission_sphere_radius = 0.5
	pmaterial.direction = Vector3(0, 1, 0)
	pmaterial.spread = 180.0
	pmaterial.initial_velocity_min = 0.3
	pmaterial.initial_velocity_max = 0.8
	pmaterial.gravity = Vector3(0, -0.5, 0)
	pmaterial.scale_min = 0.05
	pmaterial.scale_max = 0.12
	pmaterial.color = Color(0.2, 0.4, 1.0, 0.5)
	ghost_particles.process_material = pmaterial

	var spark_mesh = SphereMesh.new()
	spark_mesh.radius = 0.05
	ghost_particles.draw_pass_1 = spark_mesh
	add_child(ghost_particles)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Handle lunge attack
	if is_lunging:
		lunge_timer -= delta
		velocity.x = lunge_direction.x * LUNGE_SPEED
		velocity.z = lunge_direction.z * LUNGE_SPEED
		if lunge_timer <= 0:
			is_lunging = false

	# Gentle bob when visible — ghosts float, obviously
	if mesh_node and not is_dropped_out:
		mesh_node.position.y = 0.8 + sin(Time.get_ticks_msec() * 0.003) * 0.15

	# Dropout timer — the core mechanic
	if not is_dropped_out and not is_fading and current_state != EnemyState.DEATH:
		dropout_timer -= delta
		if dropout_timer <= 0:
			_dropout()

func _state_chase(delta: float) -> void:
	if not player_ref:
		_change_state(EnemyState.PATROL)
		return

	# Can't chase while dropped out — we're in the void, man
	if is_dropped_out or is_fading:
		velocity.x = 0
		velocity.z = 0
		return

	if is_lunging:
		return  # Lunge handles its own movement

	var dist = global_position.distance_to(player_ref.global_position)
	if dist > detection_range * 1.5:
		_change_state(EnemyState.PATROL)
		return

	# Float toward player at normal pace
	_move_toward_player(delta)

	# Attack when close
	if dist < attack_range:
		_change_state(EnemyState.ATTACK)

func _state_patrol(delta: float) -> void:
	if is_dropped_out or is_fading:
		velocity.x = 0
		velocity.z = 0
		return

	if _can_see_player():
		_change_state(EnemyState.ALERT)
		return

	_move_along_patrol(delta)

func _perform_attack() -> void:
	if not player_ref or is_dropped_out:
		return

	# Lunge attack — ghost charges forward after reappearing
	enemy_attacked.emit(self, player_ref)
	var dir = (player_ref.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.1:
		lunge_direction = dir.normalized()
	else:
		lunge_direction = Vector3.FORWARD
	is_lunging = true
	lunge_timer = LUNGE_DURATION

func _dropout() -> void:
	# Phase out — become invisible and invulnerable
	if is_dropped_out or is_fading:
		return

	is_fading = true

	# Fade out
	var tween = create_tween()
	tween.tween_method(_set_opacity, 1.0, 0.0, FADE_TIME)
	tween.tween_callback(func():
		is_dropped_out = true
		is_fading = false

		# Leave residual particles at last position
		ghost_particles.emitting = true

		# Make actually invulnerable — can't hit what's been regularized
		var health_comp = get_node_or_null("HealthComponent")
		if health_comp:
			health_comp.set("_invincible", true)

		# Teleport near player after a beat
		get_tree().create_timer(DROPOUT_DURATION * 0.6).timeout.connect(func():
			if is_instance_valid(self) and player_ref:
				_teleport_near_player()
		)

		# Reappear after duration
		get_tree().create_timer(DROPOUT_DURATION).timeout.connect(func():
			if is_instance_valid(self):
				_dropout_return()
		)
	)

func _dropout_return() -> void:
	# Phase back in — time to be fragile again
	is_fading = true
	ghost_particles.emitting = false

	var health_comp = get_node_or_null("HealthComponent")
	if health_comp:
		health_comp.set("_invincible", false)

	var tween = create_tween()
	tween.tween_method(_set_opacity, 0.0, 0.75, FADE_TIME)  # 0.75 because ghost is translucent
	tween.tween_callback(func():
		is_dropped_out = false
		is_fading = false
		dropout_timer = randf_range(DROPOUT_INTERVAL_MIN, DROPOUT_INTERVAL_MAX)

		# Surprise lunge toward player on reappear
		if player_ref and current_state == EnemyState.CHASE:
			_perform_attack()
	)

func _teleport_near_player() -> void:
	if not player_ref:
		return

	# Pick a random position around the player — appearing behind them is peak ghost behavior
	var angle = randf() * TAU
	var dist = randf_range(TELEPORT_RANGE_MIN, TELEPORT_RANGE_MAX)
	var new_pos = player_ref.global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	new_pos.y = original_y

	global_position = new_pos

func _set_opacity(value: float) -> void:
	body_opacity = value
	if base_material:
		base_material.albedo_color.a = value * 0.75  # Max is translucent, not opaque

	# Also fade the ghost light
	var light = get_node_or_null("GhostLight")
	if light:
		light.light_energy = value * 1.5

	# Fade mesh children too
	if mesh_node:
		for child in mesh_node.get_children():
			if child is MeshInstance3D and child.material_override:
				child.material_override.albedo_color.a = value * 0.7
