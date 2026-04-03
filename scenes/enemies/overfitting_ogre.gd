extends "res://scenes/enemies/base_enemy.gd"

# Overfitting Ogre — Memorizes your moves, then exploits the pattern
# "I've seen your last 10 actions. You're painfully predictable.
#  ...wait, you changed? THAT'S NOT IN MY TRAINING DATA!"
#
# Behavior: Tracks player movement history. Becomes deadly accurate at
# predicting and intercepting — but if the player changes tactics,
# the ogre gets confused and becomes vulnerable (stunned).
# Neural network enemy that literally overfits to your playstyle.

const MEMORY_SIZE := 8  # How many player positions we memorize
const MEMORY_INTERVAL := 0.6  # Sample player position every N seconds
const PREDICTION_ACCURACY := 0.85  # How well we predict (decreases when confused)
const CONFUSION_THRESHOLD := 4.0  # Distance delta that triggers confusion
const CONFUSION_DURATION := 2.5  # How long we're stunned when confused
const SLAM_COOLDOWN := 3.5  # Ground slam attack cooldown
const SLAM_RANGE := 3.5  # Range of ground slam
const SLAM_DAMAGE := 15  # Ogres hit hard but not boss-hard
const MEMORIZE_INDICATOR_DURATION := 0.3  # Flash duration when memorizing

var player_memory: Array[Vector3] = []  # Recorded player positions
var memory_timer := 0.0
var slam_timer := 0.0
var predicted_position := Vector3.ZERO
var confidence := 0.0  # 0.0 to 1.0 — how sure we are about the prediction
var times_confused := 0  # Gets easier to confuse over time (catastrophic forgetting)
var memorize_flash_timer := 0.0
var confidence_label: Label3D

func _ready() -> void:
	enemy_name = "overfitting_ogre.enemy"
	enemy_tags = ["hostile", "chapter2", "ogre", "neural"]
	max_health = 5  # Beefy boy — he memorized the gym routine too
	contact_damage = 12  # He's predictable, not a wrecking ball
	patrol_speed = 2.5  # Slow and lumbering
	chase_speed = 5.0  # Surprisingly fast when he knows where you're going
	detection_range = 14.0
	attack_range = SLAM_RANGE
	attack_cooldown = SLAM_COOLDOWN
	token_drop_count = 3
	stun_duration = CONFUSION_DURATION
	super._ready()

func _create_visual() -> void:
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.9

	# Ogre body — big chunky box because overfitting is blunt force
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(1.2, 1.4, 1.0)
	mesh_node.mesh = body_mesh

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.5, 0.2, 0.05)  # Deep bronze-brown
	base_material.emission_enabled = true
	base_material.emission = Color(0.6, 0.3, 0.05)  # Orange-amber glow
	base_material.emission_energy_multiplier = 1.5
	base_material.metallic = 0.6
	base_material.roughness = 0.4
	mesh_node.material_override = base_material
	add_child(mesh_node)

	# Head — slightly smaller box on top with "brain" pattern
	var head = MeshInstance3D.new()
	var head_mesh = BoxMesh.new()
	head_mesh.size = Vector3(0.8, 0.7, 0.7)
	head.mesh = head_mesh
	head.position.y = 1.0

	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.4, 0.15, 0.05)
	head_mat.emission_enabled = true
	head_mat.emission = Color(0.7, 0.4, 0.1)
	head_mat.emission_energy_multiplier = 2.0
	head.material_override = head_mat
	mesh_node.add_child(head)

	# Eyes — two amber squares (memorizing everything they see)
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.6, 0.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.6, 0.0)
	eye_mat.emission_energy_multiplier = 5.0

	for side in [-1, 1]:
		var eye = MeshInstance3D.new()
		var eye_mesh = BoxMesh.new()
		eye_mesh.size = Vector3(0.15, 0.12, 0.05)
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.2, 1.1, 0.35)
		eye.material_override = eye_mat
		mesh_node.add_child(eye)

	# Arms — thick cylinders, this guy lifts (training data)
	var arm_mat = StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.45, 0.18, 0.05)
	arm_mat.emission_enabled = true
	arm_mat.emission = Color(0.5, 0.25, 0.05)
	arm_mat.emission_energy_multiplier = 1.0

	for side in [-1, 1]:
		var arm = MeshInstance3D.new()
		var arm_mesh = CylinderMesh.new()
		arm_mesh.radius = 0.18
		arm_mesh.height = 0.9
		arm.mesh = arm_mesh
		arm.position = Vector3(side * 0.75, 0.3, 0)
		arm.rotation.z = side * deg_to_rad(15)
		arm.material_override = arm_mat
		mesh_node.add_child(arm)

	# "Memory bank" on back — small glowing cubes representing stored patterns
	var mem_mat = StandardMaterial3D.new()
	mem_mat.albedo_color = Color(0.224, 1.0, 0.078)
	mem_mat.emission_enabled = true
	mem_mat.emission = Color(0.224, 1.0, 0.078)
	mem_mat.emission_energy_multiplier = 3.0

	for i in range(4):
		for j in range(2):
			var mem_cube = MeshInstance3D.new()
			var cube_mesh = BoxMesh.new()
			cube_mesh.size = Vector3(0.12, 0.12, 0.08)
			mem_cube.mesh = cube_mesh
			mem_cube.position = Vector3(-0.2 + i * 0.14, 0.5 + j * 0.15, -0.52)
			mem_cube.material_override = mem_mat
			mesh_node.add_child(mem_cube)

	# Confidence display floating above head
	confidence_label = Label3D.new()
	confidence_label.text = "CONFIDENCE: 0%"
	confidence_label.font_size = 32
	confidence_label.modulate = Color(1.0, 0.6, 0.0)
	confidence_label.position = Vector3(0, 2.2, 0)
	confidence_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	confidence_label.no_depth_test = true
	mesh_node.add_child(confidence_label)

	# Amber glow light
	var light = OmniLight3D.new()
	light.light_color = Color(0.8, 0.4, 0.05)
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.position.y = 1.0
	add_child(light)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Update memorize flash
	if memorize_flash_timer > 0:
		memorize_flash_timer -= delta
		if base_material:
			base_material.emission_energy_multiplier = 4.0 if memorize_flash_timer > 0 else 1.5

	# Update confidence display
	if confidence_label:
		confidence_label.text = "CONF: %d%%" % int(confidence * 100)
		if confidence > 0.7:
			confidence_label.modulate = Color(1.0, 0.2, 0.0)  # Red = dangerous
		elif confidence > 0.4:
			confidence_label.modulate = Color(1.0, 0.6, 0.0)  # Orange = learning
		else:
			confidence_label.modulate = Color(0.3, 0.8, 0.3)  # Green = confused/safe

func _state_patrol(delta: float) -> void:
	# Even while patrolling, we're memorizing — ogres never stop learning
	_update_memory(delta)

	if _can_see_player():
		_change_state(EnemyState.ALERT)
		return

	_move_along_patrol(delta)

func _state_chase(delta: float) -> void:
	if not player_ref:
		_change_state(EnemyState.PATROL)
		return

	var dist = global_position.distance_to(player_ref.global_position)
	if dist > detection_range * 1.5:
		player_memory.clear()
		confidence = 0.0
		_change_state(EnemyState.PATROL)
		return

	# Keep memorizing — overfitting intensifies
	_update_memory(delta)

	# Predict where the player will be
	_update_prediction()

	# If confident, move toward predicted position (intercepting)
	# If not confident, move toward actual position (standard chase)
	var target_pos: Vector3
	if confidence > 0.6:
		target_pos = predicted_position
	else:
		target_pos = player_ref.global_position

	var dir = (target_pos - global_position)
	dir.y = 0
	if dir.length() > 0.1:
		dir = dir.normalized()
		# Speed scales with confidence — more sure = faster intercept
		var speed = chase_speed * (1.0 + confidence * 0.5)
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed

	# Attack when in range
	slam_timer -= delta
	if dist < SLAM_RANGE and slam_timer <= 0:
		_change_state(EnemyState.ATTACK)

func _perform_attack() -> void:
	# Ground slam — the ogre's signature "I PREDICTED THIS" move
	enemy_attacked.emit(self, player_ref)
	slam_timer = SLAM_COOLDOWN

	# Create shockwave area
	var shockwave = Area3D.new()
	shockwave.name = "OgreSlam"
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = SLAM_RANGE
	shape.height = 1.0
	col.shape = shape
	shockwave.add_child(col)

	# Shockwave visual — expanding orange ring
	var ring = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.1
	ring_mesh.outer_radius = SLAM_RANGE
	ring.mesh = ring_mesh
	ring.rotation.x = deg_to_rad(90)

	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.5, 0.0, 0.7)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.4, 0.0)
	ring_mat.emission_energy_multiplier = 4.0
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	shockwave.add_child(ring)

	shockwave.global_position = global_position
	shockwave.monitoring = true

	shockwave.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			var health_comp = body.get_node_or_null("HealthComponent")
			if health_comp and health_comp.has_method("take_damage"):
				health_comp.take_damage(SLAM_DAMAGE, self)
	)

	get_tree().current_scene.add_child(shockwave)

	# Animate and clean up shockwave
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(shockwave):
			shockwave.queue_free()
	)

func _update_memory(delta: float) -> void:
	if not player_ref:
		return

	memory_timer -= delta
	if memory_timer <= 0:
		memory_timer = MEMORY_INTERVAL
		player_memory.append(player_ref.global_position)
		memorize_flash_timer = MEMORIZE_INDICATOR_DURATION

		# Keep memory bounded — like a context window, but dumber
		if player_memory.size() > MEMORY_SIZE:
			player_memory.pop_front()

		# Check if player broke the pattern (confusion trigger)
		_check_for_surprise()

func _update_prediction() -> void:
	if player_memory.size() < 3:
		confidence = 0.0
		return

	# Simple velocity-based prediction from last few positions
	var recent = player_memory.slice(-3)
	var vel1 = recent[1] - recent[0]
	var vel2 = recent[2] - recent[1]

	# If movement is consistent, confidence goes up
	var vel_diff = vel1.distance_to(vel2)
	if vel_diff < 2.0:
		confidence = minf(confidence + 0.15, 1.0)
	else:
		confidence = maxf(confidence - 0.1, 0.0)

	# Extrapolate — predict where they'll be next
	var avg_vel = (vel1 + vel2) * 0.5
	predicted_position = player_memory[-1] + avg_vel * 2.0
	predicted_position.y = player_ref.global_position.y  # Don't predict vertical

func _check_for_surprise() -> void:
	# If we have enough memory and the player suddenly changes behavior,
	# we get confused — because we overfit to the old pattern
	if player_memory.size() < MEMORY_SIZE:
		return

	# Calculate average direction from first half vs second half
	var half = player_memory.size() / 2
	var first_dir = (player_memory[half - 1] - player_memory[0]).normalized()
	var second_dir = (player_memory[-1] - player_memory[half]).normalized()

	var direction_change = first_dir.distance_to(second_dir)
	var confusion_scale = 1.0 - (times_confused * 0.1)  # Gets easier to confuse (catastrophic forgetting)

	if direction_change > CONFUSION_THRESHOLD * maxf(confusion_scale, 0.3):
		# CONFUSION! Player broke our beautiful overfit model
		times_confused += 1
		confidence = 0.0
		player_memory.clear()
		stun(CONFUSION_DURATION)

		# Flash green — the ogre's brain is rebooting
		if base_material:
			base_material.emission = Color(0.224, 1.0, 0.078)
			base_material.emission_energy_multiplier = 6.0
			get_tree().create_timer(CONFUSION_DURATION * 0.8).timeout.connect(func():
				if is_instance_valid(self) and base_material:
					base_material.emission = Color(0.6, 0.3, 0.05)
					base_material.emission_energy_multiplier = 1.5
			)
