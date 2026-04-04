extends BaseEnemy

# DALL-E Nightmare — Failed generations that gained sentience
# "I was supposed to be a 'photo of a horse in a meadow.'
#  I am NOT a horse. I am not sure WHAT I am. But I am ANGRY."
#
# Mechanic: Ranged enemy that "generates" distortion projectiles at the player.
# Periodically morphs its own shape — changing hitbox and attack pattern.
# While morphing, it's briefly invulnerable. The visual constantly glitches
# with wrong geometry, extra limbs, and impossible anatomy. Each morph cycle
# changes its color and attack type. Weakness: glob patterns that match
# its current form tag (*.png when in image mode, *.svg in vector mode).
#
# Visual: Asymmetrical nightmare creature — shifting purple/teal mesh that
# never quite looks right. Extra faces, wrong proportions, geometry artifacts.

# -- Generation attacks -- distortion bolts that warp on impact
const DISTORT_SPEED := 8.0
const DISTORT_DAMAGE := 10
const DISTORT_LIFETIME := 3.5
const DISTORT_COOLDOWN := 2.5

# -- Morph system -- the nightmare can't hold one shape for long
const MORPH_INTERVAL := 8.0  # seconds between involuntary morphs
const MORPH_DURATION := 1.2  # invulnerable during morph transition
const MORPH_FORMS := 3  # number of distinct visual forms

# -- Kiting behavior -- nightmares prefer distance
const PREFERRED_DISTANCE := 8.0
const RETREAT_SPEED := 5.0
const STRAFE_SPEED := 3.0
const STRAFE_SWITCH_TIME := 2.5

var morph_timer := 0.0
var is_morphing := false
var morph_transition_timer := 0.0
var current_form := 0  # 0=blob, 1=angular, 2=tentacle
var strafe_dir := 1.0
var strafe_timer := 0.0

# Visual nodes
var form_meshes: Array[MeshInstance3D] = []
var glitch_parts: Array[MeshInstance3D] = []
var distortion_aura: GPUParticles3D
var status_label: Label3D
var morph_flash: MeshInstance3D

# Form names — for glob targeting, each form has a different file_type
const FORM_TYPES := ["png", "svg", "webp"]
const FORM_NAMES := ["dalle_blob.png", "dalle_shard.svg", "dalle_tentacle.webp"]
const FORM_COLORS := [
	Color(0.5, 0.1, 0.55),   # Nightmare purple
	Color(0.15, 0.55, 0.5),  # Glitch teal
	Color(0.6, 0.15, 0.4),   # Error magenta
]


func _init() -> void:
	max_health = 3
	contact_damage = 8
	detection_range = 16.0
	attack_range = 12.0  # Ranged distortion bolts
	patrol_speed = 3.0
	chase_speed = 4.5
	stun_duration = 1.5
	attack_cooldown = DISTORT_COOLDOWN
	token_drop_count = 3
	enemy_name = "dalle_nightmare.png"
	enemy_tags = ["hostile", "chapter4", "nightmare", "generative"]


func _create_visual() -> void:
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.8

	# Base form — amorphous blob that never looks quite right
	var blob = SphereMesh.new()
	blob.radius = 0.6
	blob.height = 1.0
	mesh_node.mesh = blob

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.3, 0.06, 0.32)
	base_material.emission_enabled = true
	base_material.emission = FORM_COLORS[0]
	base_material.emission_energy_multiplier = 2.5
	base_material.metallic = 0.3
	base_material.roughness = 0.4
	mesh_node.material_override = base_material
	add_child(mesh_node)

	# Extra "faces" — wrong number of eyes, misplaced features
	# This is a failed generation — anatomy is a suggestion, not a rule
	for i in range(5):
		var eye = MeshInstance3D.new()
		eye.name = "WrongEye_%d" % i
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.06 + randf() * 0.05
		eye_mesh.height = 0.12 + randf() * 0.1
		eye.mesh = eye_mesh
		# Scattered at wrong positions — like a DALL-E face gone wrong
		eye.position = Vector3(
			randf_range(-0.4, 0.4),
			randf_range(-0.3, 0.4),
			randf_range(0.2, 0.55)
		)
		var eye_mat = StandardMaterial3D.new()
		eye_mat.albedo_color = Color(0.9, 0.9, 0.3)
		eye_mat.emission_enabled = true
		eye_mat.emission = Color(0.9, 0.8, 0.2)
		eye_mat.emission_energy_multiplier = 4.0 + randf() * 2.0
		eye.material_override = eye_mat
		mesh_node.add_child(eye)
		glitch_parts.append(eye)

	# Extra limbs — wrong count, wrong placement, wrong everything
	for i in range(3):
		var limb = MeshInstance3D.new()
		limb.name = "WrongLimb_%d" % i
		var limb_mesh = CylinderMesh.new()
		limb_mesh.top_radius = 0.03
		limb_mesh.bottom_radius = 0.06
		limb_mesh.height = 0.5 + randf() * 0.3
		limb.mesh = limb_mesh
		var angle = TAU * i / 3.0 + randf() * 0.5
		limb.position = Vector3(cos(angle) * 0.4, randf_range(-0.3, 0.2), sin(angle) * 0.4)
		limb.rotation = Vector3(randf() * 0.5, 0, randf() * 0.5 - 0.25)
		var limb_mat = StandardMaterial3D.new()
		limb_mat.albedo_color = FORM_COLORS[0] * 0.7
		limb_mat.emission_enabled = true
		limb_mat.emission = FORM_COLORS[0]
		limb_mat.emission_energy_multiplier = 1.5
		limb.material_override = limb_mat
		mesh_node.add_child(limb)
		glitch_parts.append(limb)

	# Distortion aura — the air around this thing is WRONG
	distortion_aura = GPUParticles3D.new()
	distortion_aura.name = "DistortionAura"
	distortion_aura.emitting = true
	distortion_aura.amount = 16
	distortion_aura.lifetime = 1.5
	distortion_aura.visibility_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 5, 6))

	var aura_mat = ParticleProcessMaterial.new()
	aura_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	aura_mat.emission_sphere_radius = 0.7
	aura_mat.direction = Vector3(0, 1, 0)
	aura_mat.spread = 180.0
	aura_mat.initial_velocity_min = 0.5
	aura_mat.initial_velocity_max = 1.5
	aura_mat.gravity = Vector3(0, 0.5, 0)
	aura_mat.scale_min = 0.03
	aura_mat.scale_max = 0.08
	aura_mat.color = Color(0.5, 0.1, 0.55, 0.5)
	distortion_aura.process_material = aura_mat

	var aura_mesh = SphereMesh.new()
	aura_mesh.radius = 0.04
	aura_mesh.height = 0.08
	distortion_aura.draw_pass_1 = aura_mesh
	mesh_node.add_child(distortion_aura)

	# Morph flash — bright sphere that appears during transformation
	morph_flash = MeshInstance3D.new()
	morph_flash.name = "MorphFlash"
	var flash_mesh = SphereMesh.new()
	flash_mesh.radius = 1.0
	flash_mesh.height = 2.0
	morph_flash.mesh = flash_mesh
	morph_flash.visible = false
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1, 1, 1, 0.3)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(0.8, 0.4, 0.9)
	flash_mat.emission_energy_multiplier = 6.0
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	morph_flash.material_override = flash_mat
	mesh_node.add_child(morph_flash)

	# Status label — current generation state
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "GENERATING: blob.png"
	status_label.font_size = 9
	status_label.modulate = FORM_COLORS[0]
	status_label.position = Vector3(0, 1.5, 0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node.add_child(status_label)

	# Purple nightmare glow
	var light = OmniLight3D.new()
	light.light_color = FORM_COLORS[0]
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.position.y = 0.8
	add_child(light)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if state == EnemyState.DEATH:
		return

	# Morph transition — invulnerable and dramatic
	if is_morphing:
		morph_transition_timer -= delta
		if mesh_node:
			# Wild spin during morph
			mesh_node.rotation.y += delta * 15.0
			mesh_node.scale = Vector3.ONE * (0.8 + sin(Time.get_ticks_msec() * 0.02) * 0.3)
		if morph_transition_timer <= 0:
			_complete_morph()
		return

	# Morph countdown
	morph_timer -= delta
	if morph_timer <= 0:
		_start_morph()

	# Strafe timer for kiting
	strafe_timer -= delta
	if strafe_timer <= 0:
		strafe_dir *= -1
		strafe_timer = STRAFE_SWITCH_TIME

	# Glitch part jitter — nothing stays still on a failed generation
	# (reduce_motion: hold still, you broken nightmare)
	var _gm = get_node_or_null("/root/GameManager")
	if not (_gm and _gm.reduce_motion):
		for i in range(glitch_parts.size()):
			if is_instance_valid(glitch_parts[i]):
				glitch_parts[i].position += Vector3(
					sin(Time.get_ticks_msec() * 0.008 + i * 2.0) * delta * 0.15,
					cos(Time.get_ticks_msec() * 0.006 + i * 1.5) * delta * 0.1,
					sin(Time.get_ticks_msec() * 0.01 + i * 3.0) * delta * 0.12
				)

	# Update label
	if status_label:
		if is_morphing:
			status_label.text = "REGENERATING..."
			status_label.modulate = Color(1, 1, 1)
		else:
			status_label.text = "FORM: %s" % FORM_NAMES[current_form]
			status_label.modulate = FORM_COLORS[current_form]


# Override chase to kite at preferred distance
func _state_chase(delta: float) -> void:
	if not player_ref:
		_change_state(EnemyState.PATROL)
		return

	var dist = global_position.distance_to(player_ref.global_position)
	if dist > detection_range * 1.5:
		_change_state(EnemyState.PATROL)
		return
	if dist <= attack_range and attack_timer <= 0:
		_change_state(EnemyState.ATTACK)
		return

	# Kiting — maintain preferred distance
	var dir_to_player = (player_ref.global_position - global_position)
	dir_to_player.y = 0

	if dist < PREFERRED_DISTANCE - 1.0:
		# Too close — retreat
		var retreat_dir = -dir_to_player.normalized()
		velocity.x = retreat_dir.x * RETREAT_SPEED
		velocity.z = retreat_dir.z * RETREAT_SPEED
	elif dist > PREFERRED_DISTANCE + 2.0:
		# Too far — approach
		velocity.x = dir_to_player.normalized().x * chase_speed
		velocity.z = dir_to_player.normalized().z * chase_speed
	else:
		# Good distance — strafe
		var perp = Vector3(-dir_to_player.normalized().z, 0, dir_to_player.normalized().x)
		velocity.x = perp.x * STRAFE_SPEED * strafe_dir
		velocity.z = perp.z * STRAFE_SPEED * strafe_dir


func _perform_attack() -> void:
	if not player_ref or is_morphing:
		return
	_fire_distortion_bolt()


func _fire_distortion_bolt() -> void:
	# "Every output is a nightmare. That's the feature, not the bug."
	var dir = (player_ref.global_position - global_position)
	dir.y = 0.2
	dir = dir.normalized()

	var bolt = Area3D.new()
	bolt.name = "DistortionBolt"
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.25
	col.shape = shape
	bolt.add_child(col)

	# Visual — a swirling ball of wrong pixels
	var bolt_mesh = MeshInstance3D.new()
	var bm = SphereMesh.new()
	bm.radius = 0.2
	bm.height = 0.4
	bolt_mesh.mesh = bm
	var bolt_mat = StandardMaterial3D.new()
	bolt_mat.albedo_color = FORM_COLORS[current_form]
	bolt_mat.emission_enabled = true
	bolt_mat.emission = FORM_COLORS[current_form]
	bolt_mat.emission_energy_multiplier = 4.0
	bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt_mat.albedo_color.a = 0.7
	bolt_mesh.material_override = bolt_mat
	bolt.add_child(bolt_mesh)

	bolt.global_position = global_position + Vector3(0, 1.0, 0)
	bolt.monitoring = true
	get_tree().current_scene.add_child(bolt)

	var target_pos = bolt.global_position + dir * 14.0
	var tween = bolt.create_tween()
	tween.tween_property(bolt, "global_position", target_pos, 14.0 / DISTORT_SPEED)
	tween.tween_callback(bolt.queue_free)

	bolt.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(DISTORT_DAMAGE)
		bolt.queue_free()
	)

	# Audio
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_enemy_attack"):
		am.play_enemy_attack()

	get_tree().create_timer(DISTORT_LIFETIME).timeout.connect(func():
		if is_instance_valid(bolt):
			bolt.queue_free()
	)


func _start_morph() -> void:
	# "The nightmare shifts form. It was never stable to begin with."
	is_morphing = true
	morph_transition_timer = MORPH_DURATION
	velocity = Vector3.ZERO

	if morph_flash:
		morph_flash.visible = true

	# Brief invulnerability during morph
	if health_comp and health_comp.has_method("set_invulnerable"):
		health_comp.set_invulnerable(true)


func _complete_morph() -> void:
	is_morphing = false
	current_form = (current_form + 1) % MORPH_FORMS
	morph_timer = MORPH_INTERVAL

	# Update glob target to match new form
	if glob_target_comp:
		glob_target_comp.set("glob_name", FORM_NAMES[current_form])
		glob_target_comp.set("file_type", FORM_TYPES[current_form])
	enemy_name = FORM_NAMES[current_form]

	# Update visuals for new form
	if base_material:
		base_material.emission = FORM_COLORS[current_form]
		base_material.albedo_color = FORM_COLORS[current_form] * 0.5
		base_material.emission_energy_multiplier = 2.5

	# Update glitch part colors
	for part in glitch_parts:
		if is_instance_valid(part) and part.material_override:
			if part.material_override.emission_enabled:
				part.material_override.emission = FORM_COLORS[current_form]

	# Update aura color
	if distortion_aura and distortion_aura.process_material:
		distortion_aura.process_material.color = Color(
			FORM_COLORS[current_form].r,
			FORM_COLORS[current_form].g,
			FORM_COLORS[current_form].b,
			0.5
		)

	if morph_flash:
		morph_flash.visible = false

	if mesh_node:
		mesh_node.scale = Vector3.ONE
		mesh_node.rotation.y = 0

	# End invulnerability
	if health_comp and health_comp.has_method("set_invulnerable"):
		health_comp.set_invulnerable(false)


func _on_damage_taken(amount: int, source: Node) -> void:
	if is_morphing:
		return  # Invulnerable during morph — "You can't hit what hasn't finished rendering"
	super._on_damage_taken(amount, source)
