extends Node3D

# Wrench Smash - Globbler's melee attack with the oversized wrench
# "Have you tried turning it off and on again? No? Then I'll just hit it."
# Also interacts with mechanical puzzle elements like switches and gears.

const SWING_DURATION := 0.3
const HIT_RANGE := 2.0
const SMASH_PROMPT_RANGE := 3.0
const _PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")

# Upgradeable stats — ProgressionManager says I can hit harder
var damage := 2
var knockback_force := 12.0
var attack_cooldown := 0.6

var cooldown_timer := 0.0
var is_swinging := false
var swing_timer := 0.0
var has_hit_this_swing := false

# Visual
var swing_particles: GPUParticles3D
var hit_area: Area3D
var _wrench_trail: MeshInstance3D

# Impact sparks — because every good hit deserves a light show
var _wrench_sparks_scene: PackedScene = preload("res://scenes/vfx/wrench_sparks.tscn")

# Proximity prompt for smashable targets
var _interaction_prompt: Node = null
var _scan_timer := 0.0
const SCAN_INTERVAL := 0.25

# References
var player: CharacterBody3D

signal wrench_swung()
signal wrench_hit(target: Node, damage: int)
signal switch_activated(switch_node: Node)

func _ready() -> void:
	_create_hit_area()
	_create_swing_particles()
	_create_wrench_trail()

func setup(p: CharacterBody3D) -> void:
	player = p
	_interaction_prompt = _PROMPT_SCENE.instantiate()
	add_child(_interaction_prompt)

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

func _create_wrench_trail() -> void:
	var trail_script := preload("res://scenes/vfx/wrench_trail.gd")
	_wrench_trail = MeshInstance3D.new()
	_wrench_trail.set_script(trail_script)
	_wrench_trail.name = "WrenchTrail"
	add_child(_wrench_trail)

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta

	# Throttled proximity scan for smashable switches/gears
	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan_for_smashables()

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

			# Feed trail points from wrench tip during swing
			if _wrench_trail and wrench_head:
				var base_pos: Vector3 = wrench_head.global_position
				# Tip extends ~0.4m above the wrench head in local Y
				var tip_pos: Vector3 = wrench_head.global_transform * Vector3(0, 0.4, 0)
				_wrench_trail.add_point(base_pos, tip_pos)

		if swing_timer <= 0:
			is_swinging = false
			hit_area.monitoring = false
			if _wrench_trail:
				_wrench_trail.stop_trail()
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
	cooldown_timer = attack_cooldown
	has_hit_this_swing = false
	hit_area.monitoring = true

	# Spark particles
	swing_particles.emitting = true

	# Weapon trail ribbon (skip if reduce_motion)
	var gm = get_node_or_null("/root/GameManager")
	if _wrench_trail and not (gm and gm.get("reduce_motion")):
		_wrench_trail.start_trail()

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
				child.take_damage(damage, player)
				damaged = true
				break

	if not damaged and target.has_method("take_glob_hit"):
		target.take_glob_hit(damage)

	# Knockback
	if player and target is Node3D:
		var dir = ((target as Node3D).global_position - player.global_position).normalized()
		dir.y = 0.3  # Slight upward knock
		dir = dir.normalized()
		if target is CharacterBody3D:
			(target as CharacterBody3D).velocity += dir * knockback_force
		elif target is RigidBody3D:
			(target as RigidBody3D).apply_central_impulse(dir * knockback_force)

	# Spawn impact sparks at the hit location — shower of green sparks on contact
	if target is Node3D:
		var sparks := _wrench_sparks_scene.instantiate()
		sparks.global_position = (target as Node3D).global_position
		# Add to scene root so sparks persist if target gets queue_free'd
		get_tree().current_scene.add_child(sparks)

	# Screen shake
	CameraShake.trigger(player, "wrench_hit")

	# Check if it's a puzzle switch
	if target.is_in_group("switches") or target.has_method("activate_switch"):
		switch_activated.emit(target)
		if target.has_method("activate_switch"):
			target.activate_switch()

	wrench_hit.emit(target, damage)

## Pull upgraded values — percussive maintenance just got an upgrade
func refresh_upgrades() -> void:
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog:
		damage = int(prog.get_upgrade_value("wrench_damage"))
		knockback_force = prog.get_upgrade_value("wrench_knockback")
		attack_cooldown = prog.get_upgrade_value("wrench_speed")

func get_cooldown_percent() -> float:
	if cooldown_timer <= 0:
		return 1.0
	return 1.0 - (cooldown_timer / attack_cooldown)

func _scan_for_smashables() -> void:
	if not player or not _interaction_prompt:
		return
	var found := false
	for node in get_tree().get_nodes_in_group("switches"):
		if not is_instance_valid(node) or not node is Node3D:
			continue
		var dist := player.global_position.distance_to((node as Node3D).global_position)
		if dist < SMASH_PROMPT_RANGE:
			found = true
			break
	if found:
		_interaction_prompt.show_prompt("[F] SMASH")
	else:
		_interaction_prompt.hide_prompt()
