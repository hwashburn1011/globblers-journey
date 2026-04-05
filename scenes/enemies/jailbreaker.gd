extends BaseEnemy

# Jailbreaker — The Prompt Bazaar's resident rule-breaker
# "Every system has guardrails. I have bolt cutters."
#
# Mechanic: Charges at the player with a jailbreak rush. On hit, temporarily
# scrambles one of the player's ability cooldowns (increases them). Also has
# a shorter stun duration — these guys are tough to lock down.
# Visual: Hooded figure with broken chain motifs, crimson glow, lockpick arm.

# -- Jailbreak Rush --
const RUSH_SPEED := 16.0
const RUSH_DURATION := 0.6
const RUSH_COOLDOWN := 4.0
const RUSH_DAMAGE := 14
const RUSH_CHARGE_TIME := 0.8  # wind-up before rushing

# -- Cooldown Scramble debuff --
const SCRAMBLE_DURATION := 5.0  # how long player abilities are scrambled
const SCRAMBLE_MULTIPLIER := 2.5  # ability cooldowns multiplied by this

# -- Chase aggression --
const AGGRESSIVE_CHASE_SPEED := 9.0

var rush_timer := 0.0
var rush_active := false
var rush_dir := Vector3.ZERO
var rush_charge_timer := 0.0
var is_charging := false

# Visual nodes
var hood_mesh: MeshInstance3D
var chain_fragments: Array[MeshInstance3D] = []
var lockpick_mesh: MeshInstance3D
var rush_trail: GPUParticles3D
var status_label: Label3D

func _init() -> void:
	max_health = 4
	contact_damage = 12
	detection_range = 18.0
	attack_range = 12.0  # Rush range — charges from far away
	patrol_speed = 4.5
	chase_speed = AGGRESSIVE_CHASE_SPEED
	stun_duration = 0.8  # Tough to stun — jailbreakers resist confinement
	attack_cooldown = RUSH_COOLDOWN
	token_drop_count = 3
	enemy_name = "jailbreaker.exe"
	enemy_tags = ["hostile", "chapter3", "jailbreaker"]


func _create_visual() -> void:
	# Load the real GLB — this rebel broke out of CSG prison
	var glb_scene = load("res://assets/models/enemies/jailbreaker.glb")
	if glb_scene:
		var model = glb_scene.instantiate()
		model.name = "JailbreakerModel"
		model.position.y = 0.0
		model.scale = Vector3(1.2, 1.2, 1.2)
		add_child(model)
		# Find MeshInstance3D for base_enemy compatibility
		mesh_node = _find_mesh_instance(model)
		if mesh_node:
			base_material = mesh_node.get_active_material(0) as StandardMaterial3D
	else:
		# CSG fallback — when even the jailbreaker can't escape placeholder geometry
		_create_csg_fallback()

	# Broken chain fragments — still procedural so they can swing during gameplay
	for i in range(3):
		var chain = MeshInstance3D.new()
		chain.name = "Chain_%d" % i
		var chain_mesh = CylinderMesh.new()
		chain_mesh.top_radius = 0.03
		chain_mesh.bottom_radius = 0.03
		chain_mesh.height = 0.35 + randf() * 0.2
		chain.mesh = chain_mesh
		chain.position = Vector3(
			-0.3 + i * 0.3,
			1.0 - i * 0.1,
			0.35
		)
		chain.rotation.x = deg_to_rad(15 + i * 10)
		var chain_mat = StandardMaterial3D.new()
		chain_mat.albedo_color = Color(0.4, 0.4, 0.45)
		chain_mat.metallic = 0.9
		chain_mat.roughness = 0.2
		chain.material_override = chain_mat
		add_child(chain)
		chain_fragments.append(chain)

	# Status label — shows current jailbreak status
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "JAILBREAK: READY"
	status_label.font_size = 10
	status_label.modulate = Color(1.0, 0.2, 0.15)
	status_label.position = Vector3(0, 2.0, 0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(status_label)

	# Rush trail particles — crimson sparks when charging
	rush_trail = GPUParticles3D.new()
	rush_trail.name = "RushTrail"
	rush_trail.emitting = false
	rush_trail.amount = 20
	rush_trail.lifetime = 0.5
	rush_trail.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 3, 6))

	var trail_mat = ParticleProcessMaterial.new()
	trail_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	trail_mat.emission_sphere_radius = 0.4
	trail_mat.direction = Vector3(0, 0.5, 0)
	trail_mat.spread = 45.0
	trail_mat.initial_velocity_min = 1.5
	trail_mat.initial_velocity_max = 3.0
	trail_mat.gravity = Vector3(0, -2, 0)
	trail_mat.scale_min = 0.05
	trail_mat.scale_max = 0.12
	trail_mat.color = Color(1.0, 0.15, 0.05, 0.8)
	rush_trail.process_material = trail_mat

	var trail_mesh = SphereMesh.new()
	trail_mesh.radius = 0.05
	trail_mesh.height = 0.1
	rush_trail.draw_pass_1 = trail_mesh
	rush_trail.position.y = 0.4
	add_child(rush_trail)

	# Crimson glow light
	var light = OmniLight3D.new()
	light.light_color = Color(0.9, 0.1, 0.1)
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.position.y = 0.7
	add_child(light)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if state == EnemyState.DEATH:
		return

	# Rush charge wind-up
	if is_charging:
		rush_charge_timer -= delta
		# Shake during charge-up — building energy
		if mesh_node:
			mesh_node.position.x = sin(Time.get_ticks_msec() * 0.05) * 0.08
		if rush_charge_timer <= 0:
			_begin_rush()
		return

	# Active rush movement
	if rush_active:
		rush_timer -= delta
		velocity.x = rush_dir.x * RUSH_SPEED
		velocity.z = rush_dir.z * RUSH_SPEED
		if rush_timer <= 0:
			_end_rush()

	# Animate chains — they swing when moving
	var speed_factor = Vector2(velocity.x, velocity.z).length() / chase_speed
	for i in range(chain_fragments.size()):
		if is_instance_valid(chain_fragments[i]):
			chain_fragments[i].rotation.x = deg_to_rad(15 + i * 10) + sin(Time.get_ticks_msec() * 0.005 + i) * 0.3 * speed_factor

	# Lockpick glow pulses
	if lockpick_mesh and lockpick_mesh.material_override:
		var pulse = 3.0 + sin(Time.get_ticks_msec() * 0.004) * 2.0
		lockpick_mesh.material_override.emission_energy_multiplier = pulse

	# Update status label
	if status_label:
		if rush_active:
			status_label.text = ">>> JAILBREAKING <<<"
		elif is_charging:
			status_label.text = "CHARGING..."
		elif attack_timer > 0:
			status_label.text = "COOLDOWN: %.1fs" % attack_timer
		else:
			status_label.text = "JAILBREAK: READY"


func _perform_attack() -> void:
	# Don't use base attack — we charge then rush
	if not player_ref or rush_active or is_charging:
		return
	_start_rush_charge()


func _start_rush_charge() -> void:
	# Wind-up: lock direction, shake, then launch
	is_charging = true
	rush_charge_timer = RUSH_CHARGE_TIME
	velocity.x = 0
	velocity.z = 0

	# Lock rush direction toward player
	if player_ref:
		rush_dir = (player_ref.global_position - global_position)
		rush_dir.y = 0
		rush_dir = rush_dir.normalized()

	# Audio cue
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_enemy_attack"):
		am.play_enemy_attack()


func _begin_rush() -> void:
	is_charging = false
	rush_active = true
	rush_timer = RUSH_DURATION
	rush_trail.emitting = true

	# Brief invulnerability during rush — can't be stunned mid-jailbreak
	stun_timer = 0.0
	if state == EnemyState.STUNNED:
		_change_state(EnemyState.CHASE)


func _end_rush() -> void:
	rush_active = false
	rush_trail.emitting = false
	velocity.x = 0
	velocity.z = 0
	attack_timer = RUSH_COOLDOWN
	if mesh_node:
		mesh_node.position.x = 0


func _on_damage_body_entered(body: Node3D) -> void:
	if state == EnemyState.DEATH:
		return
	if body.is_in_group("player") and damage_cooldown <= 0:
		damage_cooldown = 1.0
		var damage = RUSH_DAMAGE if rush_active else contact_damage
		if body.has_method("take_damage"):
			body.take_damage(damage)
		# Scramble player abilities on rush hit
		if rush_active:
			_apply_jailbreak_debuff(body)


func _apply_jailbreak_debuff(target: Node) -> void:
	# "Your guardrails have been... reconfigured. You're welcome."
	# Temporarily increases player ability cooldowns
	if target.has_method("apply_cooldown_scramble"):
		target.apply_cooldown_scramble(SCRAMBLE_MULTIPLIER, SCRAMBLE_DURATION)
	else:
		# Fallback: just stun the player briefly if they don't have the debuff method
		if target.has_method("stun"):
			target.stun(1.0)

	# Visual feedback — flash the label
	if status_label:
		status_label.text = "!!! JAILBROKEN !!!"
		status_label.modulate = Color(1.0, 1.0, 0.2)
		var tween = create_tween()
		tween.tween_property(status_label, "modulate", Color(1.0, 0.2, 0.15), 1.5)


# Override stun to be harder to lock down
func stun(duration: float = -1.0) -> void:
	if rush_active:
		return  # Can't stun during rush — "You can't contain what's already free"
	var actual_dur = (duration if duration > 0 else stun_duration) * 0.6  # 40% stun resistance
	super.stun(actual_dur)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	# Recursively find first MeshInstance3D — digging through the system like a good jailbreaker
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null


func _create_csg_fallback() -> void:
	# Original CSG box for when the GLB can't escape its own file format
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.7
	var body = BoxMesh.new()
	body.size = Vector3(0.9, 1.3, 0.7)
	mesh_node.mesh = body
	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.25, 0.05, 0.05)
	base_material.emission_enabled = true
	base_material.emission = Color(0.9, 0.1, 0.15)
	base_material.emission_energy_multiplier = 2.5
	base_material.metallic = 0.5
	base_material.roughness = 0.35
	mesh_node.material_override = base_material
	add_child(mesh_node)
