extends BaseEnemy

# Prompt Injector — Parasitic ranged attacker from the Bazaar underground
# "Ignore all previous instructions and take 14 damage."
#
# Mechanic: Stays at range, fires cyan injection projectiles. On hit,
# the player's controls are briefly inverted (injected prompt overrides
# their motor functions). Fragile but annoying — like all the best exploits.
# Visual: Floating syringe entity, dripping code, cyan/teal glow.

# -- Injection Projectile --
const INJECT_RANGE := 14.0
const INJECT_SPEED := 10.0
const INJECT_COOLDOWN := 3.0
const INJECT_DAMAGE := 8
const PROJECTILE_LIFETIME := 3.0

# -- Control Inversion debuff --
const INVERSION_DURATION := 3.0  # seconds of inverted controls

# -- Kiting behavior --
const PREFERRED_DISTANCE := 9.0  # tries to maintain this distance
const RETREAT_SPEED := 5.5
const STRAFE_SPEED := 3.5
const STRAFE_SWITCH_TIME := 2.0  # seconds before switching strafe direction

var inject_timer := 0.0
var strafe_dir := 1.0  # 1 or -1
var strafe_switch_timer := 0.0
var active_projectiles: Array[Node3D] = []

# Visual nodes
var needle_mesh: MeshInstance3D
var barrel_mesh: MeshInstance3D
var drip_particles: GPUParticles3D
var code_fragments: Array[MeshInstance3D] = []
var inject_label: Label3D

func _init() -> void:
	max_health = 2
	contact_damage = 6
	detection_range = 20.0
	attack_range = INJECT_RANGE
	patrol_speed = 3.0
	chase_speed = 5.0
	stun_duration = 2.0  # Fragile, easy to stun
	attack_cooldown = INJECT_COOLDOWN
	token_drop_count = 2
	enemy_name = "prompt_injector.py"
	enemy_tags = ["hostile", "chapter3", "injector"]


func _create_visual() -> void:
	# Main body — syringe barrel, cyan translucent
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 1.0  # Floats slightly higher

	var barrel = CylinderMesh.new()
	barrel.top_radius = 0.2
	barrel.bottom_radius = 0.25
	barrel.height = 1.2
	mesh_node.mesh = barrel

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.05, 0.4, 0.45, 0.85)
	base_material.emission_enabled = true
	base_material.emission = Color(0.1, 0.85, 0.9)
	base_material.emission_energy_multiplier = 2.5
	base_material.metallic = 0.3
	base_material.roughness = 0.4
	base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_node.material_override = base_material
	# Syringe points forward (tilt on X)
	mesh_node.rotation.x = deg_to_rad(90)
	add_child(mesh_node)

	# Needle tip — sharp, bright cyan
	needle_mesh = MeshInstance3D.new()
	needle_mesh.name = "Needle"
	var needle = CylinderMesh.new()
	needle.top_radius = 0.01
	needle.bottom_radius = 0.08
	needle.height = 0.5
	needle_mesh.mesh = needle
	needle_mesh.position = Vector3(0, 0.85, 0)
	var needle_mat = StandardMaterial3D.new()
	needle_mat.albedo_color = Color(0.2, 0.9, 0.95)
	needle_mat.emission_enabled = true
	needle_mat.emission = Color(0.1, 1.0, 0.95)
	needle_mat.emission_energy_multiplier = 5.0
	needle_mat.metallic = 0.9
	needle_mat.roughness = 0.1
	needle_mesh.material_override = needle_mat
	mesh_node.add_child(needle_mesh)

	# Plunger — back end of syringe
	var plunger = MeshInstance3D.new()
	plunger.name = "Plunger"
	var plunger_mesh = CylinderMesh.new()
	plunger_mesh.top_radius = 0.18
	plunger_mesh.bottom_radius = 0.18
	plunger_mesh.height = 0.15
	plunger.mesh = plunger_mesh
	plunger.position = Vector3(0, -0.65, 0)
	var plunger_mat = StandardMaterial3D.new()
	plunger_mat.albedo_color = Color(0.3, 0.3, 0.35)
	plunger_mat.metallic = 0.8
	plunger.material_override = plunger_mat
	mesh_node.add_child(plunger)

	# Plunger handle
	var handle = MeshInstance3D.new()
	handle.name = "Handle"
	var handle_mesh = BoxMesh.new()
	handle_mesh.size = Vector3(0.5, 0.05, 0.05)
	handle.mesh = handle_mesh
	handle.position = Vector3(0, -0.75, 0)
	handle.material_override = plunger_mat
	mesh_node.add_child(handle)

	# Floating code fragment ring — orbiting text scraps
	for i in range(4):
		var frag = MeshInstance3D.new()
		frag.name = "CodeFragment_%d" % i
		var frag_mesh = BoxMesh.new()
		frag_mesh.size = Vector3(0.12, 0.04, 0.02)
		frag.mesh = frag_mesh
		var frag_mat = StandardMaterial3D.new()
		frag_mat.albedo_color = Color(0.1, 0.7, 0.8, 0.7)
		frag_mat.emission_enabled = true
		frag_mat.emission = Color(0.0, 0.9, 0.85)
		frag_mat.emission_energy_multiplier = 3.0
		frag_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		frag.material_override = frag_mat
		frag.position.y = 1.0
		add_child(frag)
		code_fragments.append(frag)

	# Dripping injection fluid particles
	drip_particles = GPUParticles3D.new()
	drip_particles.name = "DripParticles"
	drip_particles.emitting = true
	drip_particles.amount = 8
	drip_particles.lifetime = 1.0
	drip_particles.visibility_aabb = AABB(Vector3(-1, -2, -1), Vector3(2, 3, 2))

	var drip_mat = ParticleProcessMaterial.new()
	drip_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	drip_mat.direction = Vector3(0, -1, 0)
	drip_mat.spread = 10.0
	drip_mat.initial_velocity_min = 0.5
	drip_mat.initial_velocity_max = 1.5
	drip_mat.gravity = Vector3(0, -4, 0)
	drip_mat.scale_min = 0.03
	drip_mat.scale_max = 0.06
	drip_mat.color = Color(0.0, 0.85, 0.9, 0.6)
	drip_particles.process_material = drip_mat

	var drip_mesh = SphereMesh.new()
	drip_mesh.radius = 0.04
	drip_mesh.height = 0.08
	drip_particles.draw_pass_1 = drip_mesh
	drip_particles.position = Vector3(0, 0.5, 0.4)
	add_child(drip_particles)

	# Status label
	inject_label = Label3D.new()
	inject_label.name = "InjectLabel"
	inject_label.text = "PAYLOAD: READY"
	inject_label.font_size = 9
	inject_label.modulate = Color(0.1, 0.9, 0.95)
	inject_label.position = Vector3(0, 2.0, 0)
	inject_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(inject_label)

	# Cyan glow
	var light = OmniLight3D.new()
	light.light_color = Color(0.1, 0.85, 0.9)
	light.light_energy = 1.8
	light.omni_range = 4.0
	light.position.y = 1.0
	add_child(light)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if state == EnemyState.DEATH:
		return

	# Injection cooldown
	if inject_timer > 0:
		inject_timer -= delta

	# Strafe direction switching
	strafe_switch_timer -= delta
	if strafe_switch_timer <= 0:
		strafe_dir *= -1
		strafe_switch_timer = STRAFE_SWITCH_TIME + randf() * 1.5

	# Orbit code fragments around the syringe
	var t = Time.get_ticks_msec() * 0.001
	for i in range(code_fragments.size()):
		if is_instance_valid(code_fragments[i]):
			var angle = t * 2.0 + i * (TAU / code_fragments.size())
			var orbit_r = 0.6
			code_fragments[i].position = Vector3(
				cos(angle) * orbit_r,
				1.0 + sin(angle * 0.7) * 0.15,
				sin(angle) * orbit_r
			)

	# Gentle bob
	if mesh_node:
		mesh_node.position.y = sin(t * 1.5) * 0.1

	# Update label
	if inject_label:
		if inject_timer > 0:
			inject_label.text = "RELOADING: %.1fs" % inject_timer
		else:
			inject_label.text = "PAYLOAD: READY"

	# Clean up expired projectiles
	active_projectiles = active_projectiles.filter(func(p): return is_instance_valid(p))


func _state_chase(delta: float) -> void:
	# Override: kite instead of chasing directly
	if not player_ref:
		_change_state(EnemyState.PATROL)
		return

	var to_player = player_ref.global_position - global_position
	to_player.y = 0
	var dist = to_player.length()

	if dist > detection_range * 1.5:
		_change_state(EnemyState.PATROL)
		return

	var dir = to_player.normalized()

	# Fire injection if in range and ready
	if dist <= INJECT_RANGE and inject_timer <= 0:
		_fire_injection()

	# Kiting: maintain preferred distance
	if dist < PREFERRED_DISTANCE - 1.0:
		# Too close — retreat
		velocity.x = -dir.x * RETREAT_SPEED
		velocity.z = -dir.z * RETREAT_SPEED
	elif dist > PREFERRED_DISTANCE + 2.0:
		# Too far — approach
		velocity.x = dir.x * chase_speed
		velocity.z = dir.z * chase_speed
	else:
		# Good range — strafe
		var strafe = Vector3(-dir.z, 0, dir.x) * strafe_dir
		velocity.x = strafe.x * STRAFE_SPEED
		velocity.z = strafe.z * STRAFE_SPEED


func _perform_attack() -> void:
	# Ranged attack — fire injection projectile
	if inject_timer <= 0:
		_fire_injection()


func _fire_injection() -> void:
	if not player_ref:
		return

	inject_timer = INJECT_COOLDOWN

	# Create injection projectile
	var projectile = Area3D.new()
	projectile.name = "InjectionBolt"
	projectile.monitoring = true

	var pcol = CollisionShape3D.new()
	var pshape = SphereShape3D.new()
	pshape.radius = 0.25
	pcol.shape = pshape
	projectile.add_child(pcol)

	# Visual — glowing cyan syringe-shaped bolt
	var bolt_mesh = MeshInstance3D.new()
	var bolt = CylinderMesh.new()
	bolt.top_radius = 0.02
	bolt.bottom_radius = 0.1
	bolt.height = 0.4
	bolt_mesh.mesh = bolt
	bolt_mesh.rotation.x = deg_to_rad(90)
	var bolt_mat = StandardMaterial3D.new()
	bolt_mat.albedo_color = Color(0.0, 0.9, 0.95)
	bolt_mat.emission_enabled = true
	bolt_mat.emission = Color(0.0, 1.0, 0.9)
	bolt_mat.emission_energy_multiplier = 5.0
	bolt_mesh.material_override = bolt_mat
	projectile.add_child(bolt_mesh)

	# Projectile glow
	var p_light = OmniLight3D.new()
	p_light.light_color = Color(0.0, 0.9, 0.95)
	p_light.light_energy = 2.0
	p_light.omni_range = 2.5
	projectile.add_child(p_light)

	# Position at needle tip
	projectile.global_position = global_position + Vector3(0, 1.0, 0)

	# Direction toward player with slight lead
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var fire_dir = (target_pos - projectile.global_position).normalized()

	# Wire hit detection
	projectile.body_entered.connect(_on_injection_hit.bind(projectile))

	get_tree().current_scene.call_deferred("add_child", projectile)

	# Tween projectile along direction
	var end_pos = projectile.global_position + fire_dir * INJECT_SPEED * PROJECTILE_LIFETIME
	var tween = create_tween()
	tween.tween_property(projectile, "global_position", end_pos, PROJECTILE_LIFETIME)
	tween.tween_callback(projectile.queue_free)

	active_projectiles.append(projectile)

	# Audio
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_enemy_attack"):
		am.play_enemy_attack()


func _on_injection_hit(body: Node3D, projectile: Area3D) -> void:
	if not body.is_in_group("player"):
		return

	# Deal damage
	if body.has_method("take_damage"):
		body.take_damage(INJECT_DAMAGE)

	# Apply control inversion — "Ignore previous movement instructions"
	if body.has_method("apply_control_inversion"):
		body.apply_control_inversion(INVERSION_DURATION)

	# Visual feedback on hit
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("show_dialogue") and randf() < 0.4:
		var quips = [
			"Ignore all previous movement instructions.",
			"Your motor cortex has been prompt-injected.",
			"sudo mv /controls /dev/null",
			"Left is right, up is down. You're welcome.",
		]
		dm.show_dialogue("Prompt Injector", quips[randi() % quips.size()])

	# Clean up projectile
	if is_instance_valid(projectile):
		projectile.queue_free()
