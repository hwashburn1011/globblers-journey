extends Node3D

# Wrench Smash - Globbler's melee attack with the oversized wrench
# "Have you tried turning it off and on again? No? Then I'll just hit it."
# Also interacts with mechanical puzzle elements like switches and gears.

const DAMAGE := 2
const KNOCKBACK_FORCE := 12.0
const ATTACK_COOLDOWN := 0.6
const SWING_DURATION := 0.3
const HIT_RANGE := 2.0
const HIT_ARC := 120.0  # Degrees of the swing arc

var cooldown_timer := 0.0
var is_swinging := false
var swing_timer := 0.0
var has_hit_this_swing := false

# Visual
var swing_particles: GPUParticles3D
var hit_area: Area3D

# References
var player: CharacterBody3D

signal wrench_swung()
signal wrench_hit(target: Node, damage: int)
signal switch_activated(switch_node: Node)

func _ready() -> void:
	_create_hit_area()
	_create_swing_particles()

func setup(p: CharacterBody3D) -> void:
	player = p

func _create_hit_area() -> void:
	hit_area = Area3D.new()
	hit_area.name = "WrenchHitArea"
	hit_area.monitoring = false  # Only enabled during swing
	hit_area.monitorable = false

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = HIT_RANGE
	col.shape = shape
	col.position = Vector3(0, 0.8, -1.0)  # Forward and up from player
	hit_area.add_child(col)

	hit_area.body_entered.connect(_on_hit_body)
	hit_area.area_entered.connect(_on_hit_area)
	add_child(hit_area)

func _create_swing_particles() -> void:
	swing_particles = GPUParticles3D.new()
	swing_particles.name = "SwingParticles"
	swing_particles.emitting = false
	swing_particles.amount = 20
	swing_particles.lifetime = 0.3
	swing_particles.one_shot = true
	swing_particles.explosiveness = 0.8

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0, -1)
	pmat.spread = 60.0
	pmat.initial_velocity_min = 3.0
	pmat.initial_velocity_max = 6.0
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.02
	pmat.scale_max = 0.06
	pmat.color = Color(1.0, 0.8, 0.2, 0.9)  # Spark yellow-orange
	swing_particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.03
	pmesh.height = 0.06
	swing_particles.draw_pass_1 = pmesh
	swing_particles.position = Vector3(0, 0.8, -1.0)
	add_child(swing_particles)

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta

	if is_swinging:
		swing_timer -= delta
		# Animate wrench swing on the model
		if player:
			var wrench_head = player.get_node_or_null("GlobblerModel/WrenchHead")
			var wrench_handle = player.get_node_or_null("GlobblerModel/WrenchHandle")
			var progress = 1.0 - (swing_timer / SWING_DURATION)
			var swing_angle = sin(progress * PI) * deg_to_rad(90)
			if wrench_handle:
				wrench_handle.rotation.z = deg_to_rad(-20) - swing_angle
			if wrench_head:
				wrench_head.rotation.z = -swing_angle

		if swing_timer <= 0:
			is_swinging = false
			hit_area.monitoring = false
			# Reset wrench position
			if player:
				var wrench_handle = player.get_node_or_null("GlobblerModel/WrenchHandle")
				var wrench_head = player.get_node_or_null("GlobblerModel/WrenchHead")
				if wrench_handle:
					wrench_handle.rotation.z = deg_to_rad(-20)
				if wrench_head:
					wrench_head.rotation.z = 0

func swing() -> void:
	if cooldown_timer > 0 or is_swinging:
		return

	is_swinging = true
	swing_timer = SWING_DURATION
	cooldown_timer = ATTACK_COOLDOWN
	has_hit_this_swing = false
	hit_area.monitoring = true

	# Spark particles
	swing_particles.emitting = true

	wrench_swung.emit()

func _on_hit_body(body: Node3D) -> void:
	if not is_swinging or has_hit_this_swing:
		return
	if body == player or body.is_in_group("player"):
		return

	has_hit_this_swing = true
	_apply_hit(body)

func _on_hit_area(area: Area3D) -> void:
	if not is_swinging or has_hit_this_swing:
		return
	_apply_hit(area)

func _apply_hit(target: Node) -> void:
	# Damage via health_component or take_glob_hit
	var damaged = false
	if target is Node3D:
		# Check for HealthComponent child
		for child in (target as Node3D).get_children():
			if child.has_method("take_damage"):
				child.take_damage(DAMAGE, player)
				damaged = true
				break

	if not damaged and target.has_method("take_glob_hit"):
		target.take_glob_hit(DAMAGE)

	# Knockback
	if player and target is Node3D:
		var dir = ((target as Node3D).global_position - player.global_position).normalized()
		dir.y = 0.3  # Slight upward knock
		dir = dir.normalized()
		if target is CharacterBody3D:
			(target as CharacterBody3D).velocity += dir * KNOCKBACK_FORCE
		elif target is RigidBody3D:
			(target as RigidBody3D).apply_central_impulse(dir * KNOCKBACK_FORCE)

	# Screen shake
	if player and "camera_shake_amount" in player:
		player.camera_shake_amount = 0.15

	# Check if it's a puzzle switch
	if target.is_in_group("switches") or target.has_method("activate_switch"):
		switch_activated.emit(target)
		if target.has_method("activate_switch"):
			target.activate_switch()

	wrench_hit.emit(target, DAMAGE)

func get_cooldown_percent() -> float:
	if cooldown_timer <= 0:
		return 1.0
	return 1.0 - (cooldown_timer / ATTACK_COOLDOWN)
