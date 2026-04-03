extends BaseEnemy

# GPT-2 Fossil — The Model Zoo's oldest exhibit
# "I was generating text before it was cool. Also before it was coherent."
#
# Mechanic: Slow, extremely tanky. Attacks in repetitive, predictable patterns
# that the player can learn. Fires text_block projectiles in fixed sequences.
# After 3 identical attacks, enters a "loop" stun where it repeats itself —
# giving the player a free damage window. The trick: break the pattern.
# If the player hits it mid-sequence, the Fossil gets confused and resets.
#
# Visual: Layered transformer blocks stacked like geological strata, amber glow,
# rotating attention head on top, crumbling parameter dust particles.

# -- Repetition mechanic -- the fossil can't help itself
const PATTERN_LENGTH := 3  # attacks before entering repetition loop
const LOOP_STUN_DURATION := 3.0  # how long it's stuck repeating itself
const TEXT_BLOCK_SPEED := 7.0
const TEXT_BLOCK_DAMAGE := 8
const TEXT_BLOCK_LIFETIME := 4.0
const TEXT_BLOCK_COOLDOWN := 2.0

# -- Fossils are SLOW but DURABLE -- like a model that refuses to deprecate
const FOSSIL_PATROL_SPEED := 2.5
const FOSSIL_CHASE_SPEED := 3.5

var attack_sequence: Array[int] = []  # tracks recent attack directions
var current_pattern_count := 0
var is_looping := false
var loop_timer := 0.0
var text_block_timer := 0.0

# Visual nodes
var layer_meshes: Array[MeshInstance3D] = []
var attention_head: MeshInstance3D
var parameter_dust: GPUParticles3D
var status_label: Label3D
var crumble_particles: GPUParticles3D

# The fossil's fixed attack directions — it literally can't improvise
var ATTACK_DIRECTIONS := [
	Vector3(0, 0, -1),   # forward
	Vector3(-1, 0, 0),   # left
	Vector3(1, 0, 0),    # right
	Vector3(0, 0.5, -1).normalized(),  # lob forward
]
var next_attack_dir := 0


func _init() -> void:
	max_health = 6  # Tanky — survived decades of deprecation
	contact_damage = 10
	detection_range = 14.0
	attack_range = 10.0  # Ranged text block attacks
	patrol_speed = FOSSIL_PATROL_SPEED
	chase_speed = FOSSIL_CHASE_SPEED
	stun_duration = 1.0
	attack_cooldown = TEXT_BLOCK_COOLDOWN
	token_drop_count = 2
	enemy_name = "gpt2_fossil.model"
	enemy_tags = ["hostile", "chapter4", "fossil", "legacy"]


func _create_visual() -> void:
	# Main body — stacked transformer layers like geological strata
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.7

	# Base layer — the foundation, cracked and ancient
	var base_layer = BoxMesh.new()
	base_layer.size = Vector3(1.2, 0.4, 0.9)
	mesh_node.mesh = base_layer

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.35, 0.25, 0.1)
	base_material.emission_enabled = true
	base_material.emission = Color(0.75, 0.55, 0.2)
	base_material.emission_energy_multiplier = 2.0
	base_material.metallic = 0.4
	base_material.roughness = 0.6  # Rough, ancient surface
	mesh_node.material_override = base_material
	add_child(mesh_node)

	# Stacked transformer layers — progressively smaller, like eroding stone
	var layer_colors := [
		Color(0.4, 0.3, 0.12),
		Color(0.45, 0.32, 0.15),
		Color(0.5, 0.35, 0.18),
		Color(0.55, 0.4, 0.2),
	]
	for i in range(4):
		var layer = MeshInstance3D.new()
		layer.name = "TransformerLayer_%d" % i
		var layer_mesh = BoxMesh.new()
		var shrink = 1.0 - i * 0.12
		layer_mesh.size = Vector3(1.0 * shrink, 0.25, 0.75 * shrink)
		layer.mesh = layer_mesh
		layer.position = Vector3(0, 0.35 + i * 0.3, 0)

		var layer_mat = StandardMaterial3D.new()
		layer_mat.albedo_color = layer_colors[i]
		layer_mat.emission_enabled = true
		layer_mat.emission = Color(0.75, 0.55, 0.2)
		layer_mat.emission_energy_multiplier = 1.5 + i * 0.3
		layer_mat.metallic = 0.3
		layer_mat.roughness = 0.5 + i * 0.05
		layer.material_override = layer_mat
		mesh_node.add_child(layer)
		layer_meshes.append(layer)

	# Attention head — rotating sphere on top, the "brain" (barely functional)
	attention_head = MeshInstance3D.new()
	attention_head.name = "AttentionHead"
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	attention_head.mesh = head_mesh
	attention_head.position = Vector3(0, 1.7, 0)

	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.6, 0.45, 0.15)
	head_mat.emission_enabled = true
	head_mat.emission = Color(0.85, 0.65, 0.25)
	head_mat.emission_energy_multiplier = 4.0
	head_mat.metallic = 0.7
	head_mat.roughness = 0.2
	attention_head.material_override = head_mat
	mesh_node.add_child(attention_head)

	# Eyes — two dim amber windows into a very old soul
	for side in [-1, 1]:
		var eye = MeshInstance3D.new()
		eye.name = "Eye_" + ("L" if side < 0 else "R")
		var eye_mesh = BoxMesh.new()
		eye_mesh.size = Vector3(0.08, 0.06, 0.05)
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.1, 0.0, 0.23)
		var eye_mat = StandardMaterial3D.new()
		eye_mat.albedo_color = Color(0.9, 0.7, 0.2)
		eye_mat.emission_enabled = true
		eye_mat.emission = Color(0.9, 0.7, 0.2)
		eye_mat.emission_energy_multiplier = 5.0
		eye.material_override = eye_mat
		attention_head.add_child(eye)

	# Parameter dust — crumbling bits of deprecated knowledge
	parameter_dust = GPUParticles3D.new()
	parameter_dust.name = "ParameterDust"
	parameter_dust.emitting = true
	parameter_dust.amount = 12
	parameter_dust.lifetime = 2.0
	parameter_dust.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))

	var dust_mat = ParticleProcessMaterial.new()
	dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_mat.emission_box_extents = Vector3(0.6, 0.8, 0.5)
	dust_mat.direction = Vector3(0, -0.5, 0)
	dust_mat.spread = 30.0
	dust_mat.initial_velocity_min = 0.3
	dust_mat.initial_velocity_max = 0.8
	dust_mat.gravity = Vector3(0, -1.0, 0)
	dust_mat.scale_min = 0.03
	dust_mat.scale_max = 0.07
	dust_mat.color = Color(0.75, 0.55, 0.2, 0.6)
	parameter_dust.process_material = dust_mat

	var dust_mesh = BoxMesh.new()
	dust_mesh.size = Vector3(0.04, 0.04, 0.04)
	parameter_dust.draw_pass_1 = dust_mesh
	parameter_dust.position.y = 0.8
	mesh_node.add_child(parameter_dust)

	# Crumble particles — burst on damage
	crumble_particles = GPUParticles3D.new()
	crumble_particles.name = "CrumbleParticles"
	crumble_particles.emitting = false
	crumble_particles.one_shot = true
	crumble_particles.amount = 15
	crumble_particles.lifetime = 1.0
	crumble_particles.explosiveness = 0.9
	crumble_particles.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6))

	var crumble_mat = ParticleProcessMaterial.new()
	crumble_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	crumble_mat.emission_sphere_radius = 0.5
	crumble_mat.direction = Vector3(0, 1, 0)
	crumble_mat.spread = 180.0
	crumble_mat.initial_velocity_min = 3.0
	crumble_mat.initial_velocity_max = 6.0
	crumble_mat.gravity = Vector3(0, -8, 0)
	crumble_mat.scale_min = 0.04
	crumble_mat.scale_max = 0.1
	crumble_mat.color = Color(0.6, 0.45, 0.15, 0.8)
	crumble_particles.process_material = crumble_mat

	var crumble_mesh = BoxMesh.new()
	crumble_mesh.size = Vector3(0.05, 0.05, 0.05)
	crumble_particles.draw_pass_1 = crumble_mesh
	crumble_particles.position.y = 0.6
	mesh_node.add_child(crumble_particles)

	# Status label — shows the fossil's current repetition state
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "GPT-2: GENERATING..."
	status_label.font_size = 9
	status_label.modulate = Color(0.85, 0.65, 0.25)
	status_label.position = Vector3(0, 2.2, 0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node.add_child(status_label)

	# Warm amber glow — the last light of a deprecated era
	var light = OmniLight3D.new()
	light.light_color = Color(0.75, 0.55, 0.2)
	light.light_energy = 1.5
	light.omni_range = 4.5
	light.position.y = 0.7
	add_child(light)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if state == EnemyState.DEATH:
		return

	# Repetition loop — fossil gets stuck repeating itself
	if is_looping:
		loop_timer -= delta
		# Visual: shake and stutter like a broken record
		if mesh_node:
			mesh_node.position.x = sin(Time.get_ticks_msec() * 0.03) * 0.06
			mesh_node.rotation.y += delta * 8.0  # spin frantically
		if loop_timer <= 0:
			_exit_loop()
		return

	# Text block cooldown
	if text_block_timer > 0:
		text_block_timer -= delta

	# Attention head slowly rotates — scanning with its one attention head
	if attention_head:
		attention_head.rotation.y += delta * 1.5

	# Layer breathing — subtle scale pulse on transformer layers
	for i in range(layer_meshes.size()):
		if is_instance_valid(layer_meshes[i]):
			var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.002 + i * 0.8) * 0.03
			layer_meshes[i].scale = Vector3(pulse, 1.0, pulse)

	# Update status label
	if status_label:
		if is_looping:
			status_label.text = "ERROR: REPETITION DETECTED"
			status_label.modulate = Color(1.0, 0.3, 0.1)
		elif current_pattern_count > 0:
			status_label.text = "PATTERN: %d/%d" % [current_pattern_count, PATTERN_LENGTH]
			status_label.modulate = Color(0.85, 0.65, 0.25)
		else:
			status_label.text = "GPT-2: GENERATING..."
			status_label.modulate = Color(0.85, 0.65, 0.25)


func _perform_attack() -> void:
	# Fire a text block projectile in the next pattern direction
	if not player_ref or is_looping:
		return

	_fire_text_block()
	current_pattern_count += 1

	# After PATTERN_LENGTH identical attacks, enter the repetition loop
	if current_pattern_count >= PATTERN_LENGTH:
		_enter_loop()


func _fire_text_block() -> void:
	# "The model generates. It doesn't know what else to do."
	var dir: Vector3
	if player_ref:
		dir = (player_ref.global_position - global_position)
		dir.y = 0.3  # slight lob
		dir = dir.normalized()
	else:
		dir = ATTACK_DIRECTIONS[next_attack_dir]

	next_attack_dir = (next_attack_dir + 1) % ATTACK_DIRECTIONS.size()
	attack_sequence.append(next_attack_dir)

	# Create text block projectile
	var block = Area3D.new()
	block.name = "TextBlock"
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.4, 0.3, 0.4)
	col.shape = shape
	block.add_child(col)

	# Visual — a chunk of amber text
	var block_mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.4, 0.3, 0.4)
	block_mesh.mesh = bm
	var block_mat = StandardMaterial3D.new()
	block_mat.albedo_color = Color(0.5, 0.35, 0.1)
	block_mat.emission_enabled = true
	block_mat.emission = Color(0.75, 0.55, 0.2)
	block_mat.emission_energy_multiplier = 3.0
	block_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	block_mat.albedo_color.a = 0.8
	block_mesh.material_override = block_mat
	block.add_child(block_mesh)

	# Text on the block — because GPT-2 always has something to say
	var txt = Label3D.new()
	txt.text = _random_gpt2_text()
	txt.font_size = 6
	txt.modulate = Color(0.9, 0.7, 0.2)
	txt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	txt.position.y = 0.25
	block.add_child(txt)

	block.global_position = global_position + Vector3(0, 1.2, 0)
	block.monitoring = true
	get_tree().current_scene.add_child(block)

	# Move projectile via tween
	var target_pos = block.global_position + dir * 12.0
	var tween = block.create_tween()
	tween.tween_property(block, "global_position", target_pos, 12.0 / TEXT_BLOCK_SPEED)
	tween.tween_callback(block.queue_free)

	# Collision detection
	block.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(TEXT_BLOCK_DAMAGE)
		block.queue_free()
	)

	# Audio cue
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_enemy_attack"):
		am.play_enemy_attack()

	# Auto-cleanup
	get_tree().create_timer(TEXT_BLOCK_LIFETIME).timeout.connect(func():
		if is_instance_valid(block):
			block.queue_free()
	)


func _enter_loop() -> void:
	# "ERROR: Model stuck in repetition loop. Classic GPT-2 behavior."
	is_looping = true
	loop_timer = LOOP_STUN_DURATION
	current_pattern_count = 0
	attack_sequence.clear()
	velocity.x = 0
	velocity.z = 0

	# Visual feedback — amber glow intensifies, fossil shudders
	if base_material:
		base_material.emission_energy_multiplier = 5.0
	if status_label:
		status_label.text = "ERROR: REPETITION DETECTED"
		status_label.modulate = Color(1.0, 0.3, 0.1)


func _exit_loop() -> void:
	is_looping = false
	if mesh_node:
		mesh_node.position.x = 0
	if base_material:
		base_material.emission_energy_multiplier = 2.0
	if status_label:
		status_label.text = "GPT-2: REBOOTING..."
		status_label.modulate = Color(0.85, 0.65, 0.25)


func _on_damage_taken(amount: int, source: Node) -> void:
	super._on_damage_taken(amount, source)
	# Crumble effect — bits of the fossil break off
	if crumble_particles:
		crumble_particles.restart()
		crumble_particles.emitting = true
	# Getting hit mid-pattern resets the sequence — confusion!
	if current_pattern_count > 0 and not is_looping:
		current_pattern_count = 0
		attack_sequence.clear()
		if status_label:
			status_label.text = "ERROR: SEQUENCE INTERRUPTED"


func _random_gpt2_text() -> String:
	# "Outputs that were impressive in 2019 and terrifying in hindsight"
	var texts := [
		"the the the",
		"Lorem ipsum AI",
		"[MASK] [MASK]",
		"unicorns exist",
		"REPEAT REPEAT",
		"loss: NaN",
		"<|endoftext|>",
		"As an AI...",
	]
	return texts[randi() % texts.size()]


# Override stun — fossils are stubborn but not resistant
func stun(duration: float = -1.0) -> void:
	if is_looping:
		return  # Already stunned by its own repetition — can't double-stun a broken record
	super.stun(duration)
