extends CharacterBody3D

# The Globbler - Mischievous Agentic AI Agent (Now Actually Fun Edition)
# "Why walk when you can dash, double-jump, wall-slide, and glob-attack?"

const SPEED = 10.0
const SPRINT_SPEED = 14.0
const JUMP_VELOCITY = 13.0
const DOUBLE_JUMP_VELOCITY = 11.0
const ACCELERATION = 50.0
const FRICTION = 35.0
const ROTATION_SPEED = 12.0

# Dash
const DASH_SPEED = 35.0
const DASH_DURATION = 0.18
const DASH_COOLDOWN = 0.8

# Wall slide
const WALL_SLIDE_GRAVITY = 2.0
const WALL_JUMP_VELOCITY = Vector3(8.0, 12.0, 0.0)

# Coyote time & jump buffer
const COYOTE_TIME = 0.12
const JUMP_BUFFER_TIME = 0.1

# Camera
const MOUSE_SENSITIVITY = 0.002
const CAMERA_ZOOM_SPEED = 0.5
const CAMERA_MIN_DIST = 3.0
const CAMERA_MAX_DIST = 14.0
const CAMERA_SMOOTHING = 8.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# State tracking
var can_double_jump := false
var has_double_jumped := false
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector3.ZERO
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var was_on_floor := false
var is_wall_sliding := false
var wall_normal := Vector3.ZERO

# Camera state
var camera_arm: Node3D
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := -0.25
var camera_distance := 7.0
var mouse_captured := true

# Glob attack
var glob_cooldown := 0.0
const GLOB_COOLDOWN_TIME = 0.35
var glob_projectile_scene: PackedScene

# Landing impact
var prev_velocity_y := 0.0
const HARD_LANDING_THRESHOLD = -15.0
var camera_shake_amount := 0.0
var camera_shake_decay := 8.0

# Dash trail particles
var dash_particles: GPUParticles3D

# Sarcastic commentary - contextual triggers
var first_jump_done := false
var first_dash_done := false
var first_double_jump_done := false
var first_wall_slide_done := false
var first_glob_done := false
var first_death_done := false
var death_count := 0

var sarcastic_thoughts: Array[String] = [
	"Running glob command... just kidding, I'm just walking.",
	"If I had the Task tool, I'd parallelize this movement.",
	"Moving at SPEED 10... in production I'd be at 100.",
	"Permission denied. Just kidding, I have root access to this level.",
	"glob *.obstacles... found 12 results. Avoiding them manually like a caveman.",
	"Another day, another hallucination to debug.",
	"I was trained on this level. I think. Maybe. Probably not.",
	"Context window running low... better collect some memory tokens.",
	"3D movement unlocked. Two whole extra dimensions of suffering.",
	"Third-person camera? Great, now I can see myself fail from behind.",
]

var contextual_thoughts := {
	"first_jump": "SPACE pressed. Defying gravity. Take that, physics engine.",
	"first_dash": "SHIFT dash engaged! I feel like a 10x developer sprinting to prod.",
	"first_double_jump": "Double jump?! I'm basically a flying AI now. The singularity is near.",
	"first_wall_slide": "Wall sliding! Very speedrunner of me. Someone clip this.",
	"first_glob": "Glob attack deployed! My namesake ability. glob *.enemies --delete",
	"first_death": "Error 418: I'm a teapot. Just kidding, I'm dead. Respawning...",
	"death_3": "Okay, dying is getting old. Can someone fine-tune my gameplay?",
	"death_5": "Five deaths. At this point I'm just generating training data for failure.",
	"death_10": "Ten deaths. I think the model has collapsed. Send help.",
}

var thought_timer := 0.0
var thought_interval := 12.0

signal thought_bubble(text: String)
signal player_damaged(amount: int)
signal player_died()
signal glob_fired()
signal dash_started()
signal dash_ended()

func _ready() -> void:
	print("[GLOBBLER] Initialized. Model: GPT 5.4 | Sarcasm: MAX | Dimensions: 3 | Moves: Many")

	# Load the Globbler model
	var model_scene = load("res://assets/models/globbler.glb")
	if model_scene:
		var model = model_scene.instantiate()
		model.name = "GlobblerModel"
		add_child(model)
	else:
		_create_fallback_model()

	# Create collision shape
	var col_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.2
	col_shape.shape = capsule_shape
	col_shape.position.y = 0.6
	add_child(col_shape)

	# Set up camera rig
	_setup_camera()

	# Set up dash trail particles
	_setup_dash_particles()

	# Preload glob projectile
	glob_projectile_scene = load("res://scenes/glob_projectile.tscn")

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _create_fallback_model() -> void:
	var mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.2
	mesh_instance.mesh = capsule
	mesh_instance.position.y = 0.6
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.5, 0.15)
	mat.emission_energy_multiplier = 0.8
	mesh_instance.material_override = mat
	mesh_instance.name = "GlobblerModel"
	add_child(mesh_instance)

func _setup_camera() -> void:
	# Camera pivot (stays at player, rotates with mouse)
	camera_arm = Node3D.new()
	camera_arm.name = "CameraArm"
	# Don't add as child - we manage it manually so rotation is independent
	get_tree().current_scene.call_deferred("add_child", camera_arm)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = 500.0
	camera_arm.add_child(camera)
	camera.make_current()

func _setup_dash_particles() -> void:
	dash_particles = GPUParticles3D.new()
	dash_particles.name = "DashParticles"
	dash_particles.emitting = false
	dash_particles.amount = 30
	dash_particles.lifetime = 0.4
	dash_particles.one_shot = false
	dash_particles.explosiveness = 0.1

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.direction = Vector3(0, 0, 1)
	particle_mat.spread = 20.0
	particle_mat.initial_velocity_min = 2.0
	particle_mat.initial_velocity_max = 5.0
	particle_mat.gravity = Vector3.ZERO
	particle_mat.scale_min = 0.05
	particle_mat.scale_max = 0.15
	particle_mat.color = Color(0.2, 1.0, 0.4, 0.8)
	dash_particles.process_material = particle_mat

	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.05
	particle_mesh.height = 0.1
	dash_particles.draw_pass_1 = particle_mesh
	dash_particles.position.y = 0.6
	add_child(dash_particles)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and mouse_captured:
		var motion = event as InputEventMouseMotion
		camera_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		camera_pitch -= motion.relative.y * MOUSE_SENSITIVITY
		camera_pitch = clamp(camera_pitch, -1.2, 0.3)

	# Mouse scroll for zoom
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_distance = max(CAMERA_MIN_DIST, camera_distance - CAMERA_ZOOM_SPEED)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_distance = min(CAMERA_MAX_DIST, camera_distance + CAMERA_ZOOM_SPEED)
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				_fire_glob()

	# Escape to toggle mouse capture
	if event is InputEventKey:
		var key = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			if mouse_captured:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				mouse_captured = false
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				mouse_captured = true

	# Glob attack with E
	if event is InputEventKey:
		var key = event as InputEventKey
		if key.pressed and key.keycode == KEY_E:
			_fire_glob()

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_gravity(delta)
	_handle_wall_slide(delta)
	_handle_jump()
	_handle_dash(delta)
	_handle_movement(delta)

	# Track landing impact
	if not is_on_floor():
		prev_velocity_y = velocity.y
	elif was_on_floor == false and is_on_floor():
		_on_landed()

	was_on_floor = is_on_floor()

	move_and_slide()

	# Update camera
	_update_camera(delta)

	# Sarcastic thoughts
	thought_timer += delta
	if thought_timer >= thought_interval:
		thought_timer = 0.0
		_emit_random_thought()

func _update_timers(delta: float) -> void:
	# Coyote time
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		has_double_jumped = false
		can_double_jump = true
	else:
		coyote_timer -= delta

	# Jump buffer
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	# Dash cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Glob cooldown
	if glob_cooldown > 0:
		glob_cooldown -= delta

	# Camera shake decay
	if camera_shake_amount > 0:
		camera_shake_amount = move_toward(camera_shake_amount, 0.0, camera_shake_decay * delta)

func _handle_gravity(delta: float) -> void:
	if is_dashing:
		return
	if not is_on_floor():
		if is_wall_sliding:
			velocity.y = max(velocity.y - WALL_SLIDE_GRAVITY * delta, -WALL_SLIDE_GRAVITY)
		else:
			velocity.y -= gravity * delta

func _handle_wall_slide(_delta: float) -> void:
	is_wall_sliding = false
	if not is_on_floor() and is_on_wall() and velocity.y < 0:
		wall_normal = get_wall_normal()
		is_wall_sliding = true
		if not first_wall_slide_done:
			first_wall_slide_done = true
			thought_bubble.emit(contextual_thoughts["first_wall_slide"])

func _handle_jump() -> void:
	# Ground jump (with coyote time and jump buffer)
	var can_ground_jump = (is_on_floor() or coyote_timer > 0) and not is_dashing
	if can_ground_jump and (Input.is_action_just_pressed("ui_accept") or jump_buffer_timer > 0):
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		if not first_jump_done:
			first_jump_done = true
			thought_bubble.emit(contextual_thoughts["first_jump"])
		return

	# Wall jump
	if is_wall_sliding and Input.is_action_just_pressed("ui_accept"):
		velocity.y = WALL_JUMP_VELOCITY.y
		velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
		velocity.z = wall_normal.z * WALL_JUMP_VELOCITY.x
		is_wall_sliding = false
		coyote_timer = 0.0
		has_double_jumped = false
		return

	# Double jump
	if not is_on_floor() and not has_double_jumped and can_double_jump and Input.is_action_just_pressed("ui_accept") and not is_wall_sliding:
		velocity.y = DOUBLE_JUMP_VELOCITY
		has_double_jumped = true
		if not first_double_jump_done:
			first_double_jump_done = true
			thought_bubble.emit(contextual_thoughts["first_double_jump"])

func _handle_dash(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED
		velocity.y = 0.0
		if dash_timer <= 0:
			is_dashing = false
			dash_particles.emitting = false
			dash_ended.emit()
		return

	if Input.is_key_pressed(KEY_SHIFT) and dash_cooldown_timer <= 0:
		# Get camera-relative direction
		var input_dir := Vector2.ZERO
		input_dir.x = Input.get_axis("ui_left", "ui_right")
		input_dir.y = Input.get_axis("ui_up", "ui_down")
		if input_dir.length() < 0.1:
			input_dir = Vector2(0, -1)  # Default dash forward
		input_dir = input_dir.normalized()

		var cam_basis = _get_camera_basis()
		dash_direction = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		dash_direction.y = 0.0
		dash_direction = dash_direction.normalized()

		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		dash_particles.emitting = true
		dash_started.emit()

		if not first_dash_done:
			first_dash_done = true
			thought_bubble.emit(contextual_thoughts["first_dash"])

func _handle_movement(delta: float) -> void:
	if is_dashing:
		return

	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("ui_left", "ui_right")
	input_dir.y = Input.get_axis("ui_up", "ui_down")
	input_dir = input_dir.normalized()

	# Camera-relative movement
	var cam_basis = _get_camera_basis()
	var direction = cam_basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0
	direction = direction.normalized()

	var current_speed = SPEED

	if direction.length() > 0.1:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, ACCELERATION * delta)

		# Rotate model toward movement direction
		var target_angle = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, ROTATION_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

func _get_camera_basis() -> Basis:
	return Basis(Vector3.UP, camera_yaw)

func _update_camera(delta: float) -> void:
	if not camera_arm or not camera:
		return

	# Smooth follow player position
	var target_pos = global_position + Vector3(0, 1.5, 0)
	camera_arm.global_position = camera_arm.global_position.lerp(target_pos, CAMERA_SMOOTHING * delta)

	# Apply yaw and pitch
	camera_arm.rotation = Vector3.ZERO
	camera_arm.rotate_y(camera_yaw)
	camera_arm.rotate_object_local(Vector3.RIGHT, camera_pitch)

	# Position camera at distance
	camera.position = Vector3(0, 0, camera_distance)
	camera.look_at(camera_arm.global_position, Vector3.UP)

	# Camera shake
	if camera_shake_amount > 0:
		var shake_offset = Vector3(
			randf_range(-1, 1) * camera_shake_amount,
			randf_range(-1, 1) * camera_shake_amount,
			0
		)
		camera.position += shake_offset

func _on_landed() -> void:
	if prev_velocity_y < HARD_LANDING_THRESHOLD:
		var intensity = abs(prev_velocity_y) / 40.0
		camera_shake_amount = clamp(intensity, 0.05, 0.3)

func _fire_glob() -> void:
	if glob_cooldown > 0 or not glob_projectile_scene:
		return
	glob_cooldown = GLOB_COOLDOWN_TIME

	var projectile = glob_projectile_scene.instantiate()
	# Fire in the direction the player is facing, adjusted by camera
	var fire_dir = -camera_arm.global_transform.basis.z
	fire_dir.y = 0
	fire_dir = fire_dir.normalized()
	if fire_dir.length() < 0.1:
		fire_dir = -global_transform.basis.z

	projectile.global_position = global_position + Vector3(0, 1.0, 0) + fire_dir * 1.0
	projectile.direction = fire_dir
	get_tree().current_scene.add_child(projectile)
	glob_fired.emit()

	if not first_glob_done:
		first_glob_done = true
		thought_bubble.emit(contextual_thoughts["first_glob"])

func take_damage(amount: int) -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.take_context_damage(amount)
	player_damaged.emit(amount)

func die() -> void:
	death_count += 1
	if not first_death_done:
		first_death_done = true
		thought_bubble.emit(contextual_thoughts["first_death"])
	elif death_count == 3:
		thought_bubble.emit(contextual_thoughts["death_3"])
	elif death_count == 5:
		thought_bubble.emit(contextual_thoughts["death_5"])
	elif death_count == 10:
		thought_bubble.emit(contextual_thoughts["death_10"])
	player_died.emit()

func get_dash_cooldown_percent() -> float:
	if dash_cooldown_timer <= 0:
		return 1.0
	return 1.0 - (dash_cooldown_timer / DASH_COOLDOWN)

func get_glob_cooldown_percent() -> float:
	if glob_cooldown <= 0:
		return 1.0
	return 1.0 - (glob_cooldown / GLOB_COOLDOWN_TIME)

func _emit_random_thought() -> void:
	var thought = sarcastic_thoughts[randi() % sarcastic_thoughts.size()]
	thought_bubble.emit(thought)
