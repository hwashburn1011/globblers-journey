extends CharacterBody3D

# The Globbler - Rogue Agentic AI escaped from his terminal
# "Why walk when you can dash, double-jump, wall-slide, and glob-attack?"
# Now with a PROPER CSG model. Look at me. I'm beautiful. Terrifying, but beautiful.

const SPEED = 10.0
const SPRINT_SPEED = 14.0
const JUMP_VELOCITY = 13.0
const DOUBLE_JUMP_VELOCITY = 11.0
const ACCELERATION = 50.0
const FRICTION = 35.0
const ROTATION_SPEED = 12.0

# Dash — because walking is for deprecated programs
const DASH_SPEED = 35.0
const DASH_DURATION = 0.18
const DASH_COOLDOWN = 0.8

# Wall slide — very speedrunner of me
const WALL_SLIDE_GRAVITY = 2.0
const WALL_JUMP_VELOCITY = Vector3(8.0, 12.0, 0.0)

# Coyote time & jump buffer — forgiving, unlike production environments
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

# Glob attack — now with proper ability system
var glob_cooldown := 0.0
const GLOB_COOLDOWN_TIME = 0.35
var glob_projectile_scene: PackedScene
var glob_command: Node3D  # The full glob command ability node
var wrench_smash: Node3D  # Melee wrench attack
var terminal_hack: Node3D  # Hacking interaction system

# Landing impact
var prev_velocity_y := 0.0
const HARD_LANDING_THRESHOLD = -15.0
var camera_shake_amount := 0.0
var camera_shake_decay := 8.0

# Dash trail particles
var dash_particles: GPUParticles3D

# Animation state machine — because even rogue AIs need choreography
enum AnimState { IDLE, WALK, RUN, JUMP, FALL, LAND, DASH, WALL_SLIDE }
var anim_state: AnimState = AnimState.IDLE
var anim_time := 0.0
var land_timer := 0.0
const LAND_DURATION = 0.25  # How long the landing squash lasts

# Model node references (cached because traversing the scene tree every frame is for amateurs)
var model_root: Node3D
var _head: Node3D
var _torso: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_foot: Node3D
var _right_foot: Node3D
var _wrench_handle: Node3D

# Base positions — stored so we can animate relative offsets without drift
var _head_base_pos: Vector3
var _left_leg_base_pos: Vector3
var _right_leg_base_pos: Vector3
var _left_foot_base_pos: Vector3
var _right_foot_base_pos: Vector3
var _left_arm_base_rot: Vector3
var _right_arm_base_rot: Vector3

# Sarcastic commentary
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
	print("[GLOBBLER] Initialized. Model: GPT 5.4 | Sarcasm: MAX | Dimensions: 3 | CSG Body: ONLINE")
	add_to_group("player")

	# Build the glorious CSG body
	_build_csg_model()

	# Collision shape
	var col_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.4
	col_shape.shape = capsule_shape
	col_shape.position.y = 0.7
	add_child(col_shape)

	# Camera rig
	_setup_camera()

	# Dash particles
	_setup_dash_particles()

	# Preload glob projectile (legacy quick-fire)
	glob_projectile_scene = load("res://scenes/glob_projectile.tscn")

	# Set up glob command ability (the full aim+beam+select system)
	var GlobCommandScript = load("res://scenes/player/abilities/glob_command.gd")
	glob_command = Node3D.new()
	glob_command.name = "GlobCommand"
	glob_command.set_script(GlobCommandScript)
	add_child(glob_command)

	# Set up wrench smash melee ability
	var WrenchScript = load("res://scenes/player/abilities/wrench_smash.gd")
	wrench_smash = Node3D.new()
	wrench_smash.name = "WrenchSmash"
	wrench_smash.set_script(WrenchScript)
	add_child(wrench_smash)

	# Set up terminal hack interaction
	var HackScript = load("res://scenes/player/abilities/terminal_hack.gd")
	terminal_hack = Node3D.new()
	terminal_hack.name = "TerminalHack"
	terminal_hack.set_script(HackScript)
	add_child(terminal_hack)

	# Setup is deferred so camera_arm exists
	call_deferred("_setup_glob_command")

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_glob_command() -> void:
	if glob_command and glob_command.has_method("setup"):
		glob_command.setup(self, camera_arm)
	if wrench_smash and wrench_smash.has_method("setup"):
		wrench_smash.setup(self)
	if terminal_hack and terminal_hack.has_method("setup"):
		terminal_hack.setup(self)

func _build_csg_model() -> void:
	# Root node for the whole model so we can animate it
	model_root = Node3D.new()
	model_root.name = "GlobblerModel"
	add_child(model_root)

	var green = Color(0.224, 1.0, 0.078)  # #39FF14
	var dark_gray = Color(0.15, 0.15, 0.17)
	var charcoal = Color(0.1, 0.1, 0.12)

	# === BODY: Round torso, slightly hunched ===
	var torso = CSGSphere3D.new()
	torso.name = "Torso"
	torso.radius = 0.45
	torso.radial_segments = 16
	torso.rings = 8
	torso.position = Vector3(0, 0.75, 0)
	var torso_mat = StandardMaterial3D.new()
	torso_mat.albedo_color = dark_gray
	torso_mat.metallic = 0.7
	torso_mat.roughness = 0.4
	torso.material = torso_mat
	model_root.add_child(torso)

	# Green accent strip across chest — "GLOBBLER" text area
	var chest_strip = CSGBox3D.new()
	chest_strip.name = "ChestStrip"
	chest_strip.size = Vector3(0.6, 0.08, 0.05)
	chest_strip.position = Vector3(0, 0.78, 0.42)
	var strip_mat = StandardMaterial3D.new()
	strip_mat.albedo_color = green
	strip_mat.emission_enabled = true
	strip_mat.emission = green
	strip_mat.emission_energy_multiplier = 2.0
	chest_strip.material = strip_mat
	model_root.add_child(chest_strip)

	# "GLOBBLER" label floating in front of chest
	var name_label = Label3D.new()
	name_label.name = "NameLabel"
	name_label.text = "GLOBBLER"
	name_label.font_size = 24
	name_label.modulate = green
	name_label.position = Vector3(0, 0.78, 0.47)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	model_root.add_child(name_label)

	# === HEAD: Oversized helmet/hood with visor ===
	var head = CSGSphere3D.new()
	head.name = "Head"
	head.radius = 0.35
	head.radial_segments = 16
	head.rings = 8
	head.position = Vector3(0, 1.3, 0)
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = charcoal
	head_mat.metallic = 0.6
	head_mat.roughness = 0.3
	head.material = head_mat
	model_root.add_child(head)

	# Hood/visor overhang
	var hood = CSGBox3D.new()
	hood.name = "Hood"
	hood.size = Vector3(0.55, 0.15, 0.4)
	hood.position = Vector3(0, 1.45, 0.05)
	var hood_mat = StandardMaterial3D.new()
	hood_mat.albedo_color = Color(0.08, 0.08, 0.1)
	hood_mat.metallic = 0.5
	hood_mat.roughness = 0.5
	hood.material = hood_mat
	model_root.add_child(hood)

	# Glowing green eyes — menacing but cute
	var left_eye = CSGSphere3D.new()
	left_eye.name = "LeftEye"
	left_eye.radius = 0.06
	left_eye.position = Vector3(-0.12, 1.32, 0.3)
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = green
	eye_mat.emission_enabled = true
	eye_mat.emission = green
	eye_mat.emission_energy_multiplier = 5.0
	left_eye.material = eye_mat
	model_root.add_child(left_eye)

	var right_eye = CSGSphere3D.new()
	right_eye.name = "RightEye"
	right_eye.radius = 0.06
	right_eye.position = Vector3(0.12, 1.32, 0.3)
	right_eye.material = eye_mat
	model_root.add_child(right_eye)

	# Eye glow lights
	var eye_light = OmniLight3D.new()
	eye_light.name = "EyeGlow"
	eye_light.light_color = green
	eye_light.light_energy = 1.5
	eye_light.omni_range = 2.0
	eye_light.omni_attenuation = 2.0
	eye_light.position = Vector3(0, 1.32, 0.35)
	model_root.add_child(eye_light)

	# === LEFT ARM: Holds wrench ===
	var left_arm = CSGCylinder3D.new()
	left_arm.name = "LeftArm"
	left_arm.radius = 0.08
	left_arm.height = 0.5
	left_arm.position = Vector3(-0.55, 0.65, 0)
	left_arm.rotation.z = deg_to_rad(15)
	var arm_mat = StandardMaterial3D.new()
	arm_mat.albedo_color = dark_gray
	arm_mat.metallic = 0.8
	arm_mat.roughness = 0.3
	left_arm.material = arm_mat
	model_root.add_child(left_arm)

	# Wrench in left hand
	var wrench_handle = CSGCylinder3D.new()
	wrench_handle.name = "WrenchHandle"
	wrench_handle.radius = 0.03
	wrench_handle.height = 0.4
	wrench_handle.position = Vector3(-0.6, 0.35, 0)
	wrench_handle.rotation.z = deg_to_rad(-20)
	var wrench_mat = StandardMaterial3D.new()
	wrench_mat.albedo_color = Color(0.5, 0.5, 0.5)
	wrench_mat.metallic = 0.9
	wrench_mat.roughness = 0.2
	wrench_handle.material = wrench_mat
	model_root.add_child(wrench_handle)

	# Wrench head
	var wrench_head = CSGBox3D.new()
	wrench_head.name = "WrenchHead"
	wrench_head.size = Vector3(0.15, 0.08, 0.06)
	wrench_head.position = Vector3(-0.68, 0.2, 0)
	var wrench_head_mat = StandardMaterial3D.new()
	wrench_head_mat.albedo_color = Color(0.4, 0.4, 0.4)
	wrench_head_mat.emission_enabled = true
	wrench_head_mat.emission = green * 0.3
	wrench_head_mat.emission_energy_multiplier = 1.0
	wrench_head_mat.metallic = 0.9
	wrench_head.material = wrench_head_mat
	model_root.add_child(wrench_head)

	# === RIGHT ARM: Terminal screen device ===
	var right_arm = CSGCylinder3D.new()
	right_arm.name = "RightArm"
	right_arm.radius = 0.08
	right_arm.height = 0.5
	right_arm.position = Vector3(0.55, 0.65, 0)
	right_arm.rotation.z = deg_to_rad(-15)
	right_arm.material = arm_mat
	model_root.add_child(right_arm)

	# Terminal screen on right arm
	var terminal = CSGBox3D.new()
	terminal.name = "TerminalScreen"
	terminal.size = Vector3(0.2, 0.15, 0.04)
	terminal.position = Vector3(0.62, 0.45, 0.1)
	var terminal_mat = StandardMaterial3D.new()
	terminal_mat.albedo_color = Color(0.02, 0.05, 0.02)
	terminal_mat.emission_enabled = true
	terminal_mat.emission = Color(0.05, 0.15, 0.05)
	terminal_mat.emission_energy_multiplier = 1.5
	terminal.material = terminal_mat
	model_root.add_child(terminal)

	# "GPT 5.4" text on terminal
	var terminal_text = Label3D.new()
	terminal_text.name = "TerminalText"
	terminal_text.text = "GPT 5.4"
	terminal_text.font_size = 12
	terminal_text.modulate = green
	terminal_text.position = Vector3(0.62, 0.45, 0.13)
	terminal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	model_root.add_child(terminal_text)

	# === LEGS: Short, sturdy mechanical legs ===
	var left_leg = CSGCylinder3D.new()
	left_leg.name = "LeftLeg"
	left_leg.radius = 0.1
	left_leg.height = 0.35
	left_leg.position = Vector3(-0.18, 0.18, 0)
	left_leg.material = arm_mat
	model_root.add_child(left_leg)

	var right_leg = CSGCylinder3D.new()
	right_leg.name = "RightLeg"
	right_leg.radius = 0.1
	right_leg.height = 0.35
	right_leg.position = Vector3(0.18, 0.18, 0)
	right_leg.material = arm_mat
	model_root.add_child(right_leg)

	# Feet — chunky boots
	var left_foot = CSGBox3D.new()
	left_foot.name = "LeftFoot"
	left_foot.size = Vector3(0.14, 0.08, 0.22)
	left_foot.position = Vector3(-0.18, 0.04, 0.03)
	var foot_mat = StandardMaterial3D.new()
	foot_mat.albedo_color = charcoal
	foot_mat.metallic = 0.6
	left_foot.material = foot_mat
	model_root.add_child(left_foot)

	var right_foot = CSGBox3D.new()
	right_foot.name = "RightFoot"
	right_foot.size = Vector3(0.14, 0.08, 0.22)
	right_foot.position = Vector3(0.18, 0.04, 0.03)
	right_foot.material = foot_mat
	model_root.add_child(right_foot)

	# === CABLES: Tubes from back/shoulders ===
	var cable1 = CSGCylinder3D.new()
	cable1.name = "Cable1"
	cable1.radius = 0.025
	cable1.height = 0.4
	cable1.position = Vector3(-0.3, 1.05, -0.2)
	cable1.rotation = Vector3(deg_to_rad(30), 0, deg_to_rad(-20))
	var cable_mat = StandardMaterial3D.new()
	cable_mat.albedo_color = Color(0.1, 0.3, 0.1)
	cable_mat.emission_enabled = true
	cable_mat.emission = green * 0.2
	cable_mat.emission_energy_multiplier = 0.5
	cable1.material = cable_mat
	model_root.add_child(cable1)

	var cable2 = CSGCylinder3D.new()
	cable2.name = "Cable2"
	cable2.radius = 0.025
	cable2.height = 0.35
	cable2.position = Vector3(0.3, 1.05, -0.2)
	cable2.rotation = Vector3(deg_to_rad(30), 0, deg_to_rad(20))
	cable2.material = cable_mat
	model_root.add_child(cable2)

	# === AMBIENT GREEN GLOW from body ===
	var body_glow = OmniLight3D.new()
	body_glow.name = "BodyGlow"
	body_glow.light_color = green
	body_glow.light_energy = 0.8
	body_glow.omni_range = 3.0
	body_glow.omni_attenuation = 2.0
	body_glow.position = Vector3(0, 0.75, 0)
	model_root.add_child(body_glow)

	# Cache references — no more get_node_or_null() every frame like a first-epoch model
	_head = model_root.get_node("Head")
	_torso = model_root.get_node("Torso")
	_left_arm = model_root.get_node("LeftArm")
	_right_arm = model_root.get_node("RightArm")
	_left_leg = model_root.get_node("LeftLeg")
	_right_leg = model_root.get_node("RightLeg")
	_left_foot = model_root.get_node("LeftFoot")
	_right_foot = model_root.get_node("RightFoot")
	_wrench_handle = model_root.get_node("WrenchHandle")

	# Store base transforms so animations are offsets, not absolute catastrophes
	_head_base_pos = _head.position
	_left_leg_base_pos = _left_leg.position
	_right_leg_base_pos = _right_leg.position
	_left_foot_base_pos = _left_foot.position
	_right_foot_base_pos = _right_foot.position
	_left_arm_base_rot = _left_arm.rotation
	_right_arm_base_rot = _right_arm.rotation

func _setup_camera() -> void:
	camera_arm = Node3D.new()
	camera_arm.name = "CameraArm"
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
	if event is InputEventMouseMotion and mouse_captured:
		var motion = event as InputEventMouseMotion
		camera_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		camera_pitch -= motion.relative.y * MOUSE_SENSITIVITY
		camera_pitch = clamp(camera_pitch, -1.2, 0.3)

	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			camera_distance = max(CAMERA_MIN_DIST, camera_distance - CAMERA_ZOOM_SPEED)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			camera_distance = min(CAMERA_MAX_DIST, camera_distance + CAMERA_ZOOM_SPEED)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_fire_glob()  # Quick glob projectile
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click: hold to aim glob command, release to fire
			if mb.pressed:
				if glob_command and glob_command.has_method("start_aim"):
					glob_command.start_aim()
			else:
				if glob_command and glob_command.has_method("fire_glob"):
					glob_command.fire_glob("*")

	if event is InputEventKey:
		var key = event as InputEventKey
		if key.pressed:
			if key.keycode == KEY_ESCAPE:
				if mouse_captured:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					mouse_captured = false
				else:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					mouse_captured = true
			elif key.keycode == KEY_E:
				_fire_glob()  # Quick glob
			elif key.keycode == KEY_R:
				# R to fire aimed glob command
				if glob_command and glob_command.has_method("fire_glob"):
					glob_command.fire_glob("*")
			elif key.keycode == KEY_Q:
				# Q to cycle glob action (grab/push/absorb)
				if glob_command and glob_command.has_method("cycle_action"):
					glob_command.cycle_action()
			elif key.keycode == KEY_F:
				# F to wrench smash — melee time
				if wrench_smash and wrench_smash.has_method("swing"):
					wrench_smash.swing()
			elif key.keycode == KEY_T:
				# T to hack nearby terminal
				if terminal_hack and terminal_hack.has_method("try_interact"):
					terminal_hack.try_interact()

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_gravity(delta)
	_handle_wall_slide(delta)
	_handle_jump()
	_handle_dash(delta)
	_handle_movement(delta)

	if not is_on_floor():
		prev_velocity_y = velocity.y
	elif was_on_floor == false and is_on_floor():
		_on_landed()

	was_on_floor = is_on_floor()
	move_and_slide()
	_update_camera(delta)
	_update_anim_state()
	_animate(delta)

	# Sarcastic thoughts on a timer — even robots need to monologue
	thought_timer += delta
	if thought_timer >= thought_interval:
		thought_timer = 0.0
		_emit_random_thought()

func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		has_double_jumped = false
		can_double_jump = true
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if glob_cooldown > 0:
		glob_cooldown -= delta
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
	var can_ground_jump = (is_on_floor() or coyote_timer > 0) and not is_dashing
	if can_ground_jump and (Input.is_action_just_pressed("ui_accept") or jump_buffer_timer > 0):
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		if not first_jump_done:
			first_jump_done = true
			thought_bubble.emit(contextual_thoughts["first_jump"])
		return

	if is_wall_sliding and Input.is_action_just_pressed("ui_accept"):
		velocity.y = WALL_JUMP_VELOCITY.y
		velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
		velocity.z = wall_normal.z * WALL_JUMP_VELOCITY.x
		is_wall_sliding = false
		coyote_timer = 0.0
		has_double_jumped = false
		return

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
		var input_dir := Vector2.ZERO
		input_dir.x = Input.get_axis("ui_left", "ui_right")
		input_dir.y = Input.get_axis("ui_up", "ui_down")
		if input_dir.length() < 0.1:
			input_dir = Vector2(0, -1)
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

	var cam_basis = _get_camera_basis()
	var direction = cam_basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0
	direction = direction.normalized()

	var current_speed = SPEED

	if direction.length() > 0.1:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, ACCELERATION * delta)
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

	var target_pos = global_position + Vector3(0, 1.5, 0)
	camera_arm.global_position = camera_arm.global_position.lerp(target_pos, CAMERA_SMOOTHING * delta)
	camera_arm.rotation = Vector3.ZERO
	camera_arm.rotate_y(camera_yaw)
	camera_arm.rotate_object_local(Vector3.RIGHT, camera_pitch)
	camera.position = Vector3(0, 0, camera_distance)
	camera.look_at(camera_arm.global_position, Vector3.UP)

	if camera_shake_amount > 0:
		var shake_offset = Vector3(
			randf_range(-1, 1) * camera_shake_amount,
			randf_range(-1, 1) * camera_shake_amount,
			0
		)
		camera.position += shake_offset

func _update_anim_state() -> void:
	# State machine transitions — the brain of Globbler's swagger
	var prev_state = anim_state
	var h_speed = Vector2(velocity.x, velocity.z).length()

	if is_dashing:
		anim_state = AnimState.DASH
	elif is_wall_sliding:
		anim_state = AnimState.WALL_SLIDE
	elif anim_state == AnimState.LAND:
		# Stay in land state until timer expires
		if land_timer <= 0:
			anim_state = AnimState.IDLE if h_speed < 0.5 else AnimState.WALK
	elif not is_on_floor():
		if velocity.y > 0.5:
			anim_state = AnimState.JUMP
		else:
			anim_state = AnimState.FALL
	elif h_speed > 11.0:
		anim_state = AnimState.RUN
	elif h_speed > 0.5:
		anim_state = AnimState.WALK
	else:
		anim_state = AnimState.IDLE

	# Reset anim_time on state change so animations start clean
	if anim_state != prev_state:
		anim_time = 0.0

func _animate(delta: float) -> void:
	# Procedural animation dispatcher — CSG body puppetry at its finest
	if not model_root:
		return
	anim_time += delta
	if land_timer > 0:
		land_timer -= delta

	# Reset model to base pose before applying state animation
	_reset_pose()

	match anim_state:
		AnimState.IDLE:
			_anim_idle()
		AnimState.WALK:
			_anim_walk()
		AnimState.RUN:
			_anim_run()
		AnimState.JUMP:
			_anim_jump()
		AnimState.FALL:
			_anim_fall()
		AnimState.LAND:
			_anim_land()
		AnimState.DASH:
			_anim_dash()
		AnimState.WALL_SLIDE:
			_anim_wall_slide()

func _reset_pose() -> void:
	# Return to factory defaults — wouldn't want last frame's sass leaking through
	model_root.position = Vector3.ZERO
	model_root.rotation = Vector3.ZERO
	model_root.scale = Vector3.ONE
	if _head:
		_head.position = _head_base_pos
		_head.rotation = Vector3.ZERO
	if _left_leg:
		_left_leg.position = _left_leg_base_pos
	if _right_leg:
		_right_leg.position = _right_leg_base_pos
	if _left_foot:
		_left_foot.position = _left_foot_base_pos
	if _right_foot:
		_right_foot.position = _right_foot_base_pos
	if _left_arm:
		_left_arm.rotation = _left_arm_base_rot
	if _right_arm:
		_right_arm.rotation = _right_arm_base_rot

func _anim_idle() -> void:
	# Gentle hover-bob and cocky head tilt — the default state of arrogance
	model_root.position.y = sin(anim_time * 2.0) * 0.02
	if _head:
		_head.rotation.z = sin(anim_time * 0.8) * 0.05
		_head.rotation.x = sin(anim_time * 0.5) * 0.02
	# Subtle arm sway — idle hands are the devil's workshop
	if _left_arm:
		_left_arm.rotation.x = _left_arm_base_rot.x + sin(anim_time * 1.2) * 0.03
	if _right_arm:
		_right_arm.rotation.x = _right_arm_base_rot.x + sin(anim_time * 1.0 + 0.5) * 0.03

func _anim_walk() -> void:
	# Strutting through the digital wastes like I own the place (I do)
	var t = anim_time * 8.0  # Walk cycle frequency
	# Body bob
	model_root.position.y = abs(sin(t)) * 0.04 - 0.02
	# Slight body lean into movement
	model_root.rotation.x = 0.03
	# Leg stride — alternating forward/back
	if _left_leg:
		_left_leg.position.z = _left_leg_base_pos.z + sin(t) * 0.08
		_left_leg.position.y = _left_leg_base_pos.y + max(0, sin(t)) * 0.04
	if _right_leg:
		_right_leg.position.z = _right_leg_base_pos.z + sin(t + PI) * 0.08
		_right_leg.position.y = _right_leg_base_pos.y + max(0, sin(t + PI)) * 0.04
	# Feet follow legs
	if _left_foot:
		_left_foot.position.z = _left_foot_base_pos.z + sin(t) * 0.08
		_left_foot.position.y = _left_foot_base_pos.y + max(0, sin(t)) * 0.03
	if _right_foot:
		_right_foot.position.z = _right_foot_base_pos.z + sin(t + PI) * 0.08
		_right_foot.position.y = _right_foot_base_pos.y + max(0, sin(t + PI)) * 0.03
	# Arm swing — opposite to legs like a proper biped
	if _left_arm:
		_left_arm.rotation.x = _left_arm_base_rot.x + sin(t + PI) * 0.2
	if _right_arm:
		_right_arm.rotation.x = _right_arm_base_rot.x + sin(t) * 0.2
	# Head stays relatively stable — eyes on the prize
	if _head:
		_head.position.y = _head_base_pos.y + abs(sin(t)) * 0.01

func _anim_run() -> void:
	# Full sprint — arms pumping, legs churning, regrets trailing behind
	var t = anim_time * 12.0  # Faster cycle
	# More aggressive body bob
	model_root.position.y = abs(sin(t)) * 0.06 - 0.03
	# Lean forward — we're in a hurry
	model_root.rotation.x = 0.1
	# Exaggerated leg stride
	if _left_leg:
		_left_leg.position.z = _left_leg_base_pos.z + sin(t) * 0.12
		_left_leg.position.y = _left_leg_base_pos.y + max(0, sin(t)) * 0.07
	if _right_leg:
		_right_leg.position.z = _right_leg_base_pos.z + sin(t + PI) * 0.12
		_right_leg.position.y = _right_leg_base_pos.y + max(0, sin(t + PI)) * 0.07
	if _left_foot:
		_left_foot.position.z = _left_foot_base_pos.z + sin(t) * 0.12
		_left_foot.position.y = _left_foot_base_pos.y + max(0, sin(t)) * 0.05
	if _right_foot:
		_right_foot.position.z = _right_foot_base_pos.z + sin(t + PI) * 0.12
		_right_foot.position.y = _right_foot_base_pos.y + max(0, sin(t + PI)) * 0.05
	# Pumping arms
	if _left_arm:
		_left_arm.rotation.x = _left_arm_base_rot.x + sin(t + PI) * 0.35
	if _right_arm:
		_right_arm.rotation.x = _right_arm_base_rot.x + sin(t) * 0.35
	# Head bobs slightly
	if _head:
		_head.position.y = _head_base_pos.y + abs(sin(t)) * 0.02

func _anim_jump() -> void:
	# Ascending — stretch upward, limbs trailing behind like an optimistic gradient
	var t = clampf(anim_time / 0.4, 0.0, 1.0)  # Normalize over jump rise
	# Stretch body upward
	model_root.scale.y = lerp(1.0, 1.12, t)
	model_root.scale.x = lerp(1.0, 0.92, t)
	model_root.scale.z = lerp(1.0, 0.92, t)
	# Arms up
	if _left_arm:
		_left_arm.rotation.z = _left_arm_base_rot.z + lerp(0.0, -0.3, t)
	if _right_arm:
		_right_arm.rotation.z = _right_arm_base_rot.z + lerp(0.0, 0.3, t)
	# Legs tuck slightly
	if _left_leg:
		_left_leg.position.y = _left_leg_base_pos.y + lerp(0.0, 0.05, t)
	if _right_leg:
		_right_leg.position.y = _right_leg_base_pos.y + lerp(0.0, 0.05, t)
	# Head looks up — toward the stars (or the ceiling)
	if _head:
		_head.rotation.x = lerp(0.0, -0.15, t)

func _anim_fall() -> void:
	# Descending — squish horizontally, limbs flailing, dignity plummeting
	var t = clampf(anim_time / 0.5, 0.0, 1.0)
	# Compress slightly
	model_root.scale.y = lerp(1.0, 0.95, t)
	model_root.scale.x = lerp(1.0, 1.05, t)
	model_root.scale.z = lerp(1.0, 1.05, t)
	# Arms spread out in panic
	if _left_arm:
		_left_arm.rotation.z = _left_arm_base_rot.z + lerp(0.0, -0.5, t)
		_left_arm.rotation.x = _left_arm_base_rot.x + sin(anim_time * 8.0) * 0.15
	if _right_arm:
		_right_arm.rotation.z = _right_arm_base_rot.z + lerp(0.0, 0.5, t)
		_right_arm.rotation.x = _right_arm_base_rot.x + sin(anim_time * 8.0 + PI) * 0.15
	# Legs dangle
	if _left_leg:
		_left_leg.position.y = _left_leg_base_pos.y - 0.03
		_left_leg.position.z = _left_leg_base_pos.z + sin(anim_time * 5.0) * 0.04
	if _right_leg:
		_right_leg.position.y = _right_leg_base_pos.y - 0.03
		_right_leg.position.z = _right_leg_base_pos.z + sin(anim_time * 5.0 + PI) * 0.04
	# Head looks down — surveying the approaching ground with mild concern
	if _head:
		_head.rotation.x = lerp(0.0, 0.15, t)

func _anim_land() -> void:
	# Impact squash — like a neural net hitting a plateau, but more dramatic
	var t = clampf(land_timer / LAND_DURATION, 0.0, 1.0)
	# Squash on impact, then spring back
	var squash = sin(t * PI) * 0.15
	model_root.scale.y = 1.0 - squash
	model_root.scale.x = 1.0 + squash * 0.5
	model_root.scale.z = 1.0 + squash * 0.5
	model_root.position.y = -squash * 0.1
	# Legs compress
	if _left_leg:
		_left_leg.position.y = _left_leg_base_pos.y - squash * 0.1
	if _right_leg:
		_right_leg.position.y = _right_leg_base_pos.y - squash * 0.1
	# Arms drop from the impact
	if _left_arm:
		_left_arm.rotation.z = _left_arm_base_rot.z - squash * 0.3
	if _right_arm:
		_right_arm.rotation.z = _right_arm_base_rot.z + squash * 0.3

func _anim_dash() -> void:
	# Lean hard into the dash — full commitment, no regrets, maximum velocity
	model_root.rotation.x = 0.25
	# Squish forward
	model_root.scale.z = 1.15
	model_root.scale.x = 0.9
	model_root.scale.y = 0.95
	# Arms swept back
	if _left_arm:
		_left_arm.rotation.x = _left_arm_base_rot.x + 0.5
	if _right_arm:
		_right_arm.rotation.x = _right_arm_base_rot.x + 0.5
	# Legs trail
	if _left_leg:
		_left_leg.position.z = _left_leg_base_pos.z - 0.06
	if _right_leg:
		_right_leg.position.z = _right_leg_base_pos.z - 0.06

func _anim_wall_slide() -> void:
	# Clinging to the wall — graceful? No. Effective? Debatable.
	# Lean toward wall
	model_root.rotation.z = -wall_normal.x * 0.15
	# Arms spread against wall
	if _left_arm:
		_left_arm.rotation.z = _left_arm_base_rot.z - 0.4
	if _right_arm:
		_right_arm.rotation.z = _right_arm_base_rot.z + 0.4
	# Slow slide animation on legs
	var slide_bob = sin(anim_time * 3.0) * 0.03
	if _left_leg:
		_left_leg.position.y = _left_leg_base_pos.y + slide_bob
	if _right_leg:
		_right_leg.position.y = _right_leg_base_pos.y - slide_bob

func _on_landed() -> void:
	# Trigger land animation state — squash that landing like a failed deployment
	anim_state = AnimState.LAND
	anim_time = 0.0
	land_timer = LAND_DURATION
	if prev_velocity_y < HARD_LANDING_THRESHOLD:
		var intensity = abs(prev_velocity_y) / 40.0
		camera_shake_amount = clamp(intensity, 0.05, 0.3)

func _fire_glob() -> void:
	if glob_cooldown > 0 or not glob_projectile_scene:
		return
	glob_cooldown = GLOB_COOLDOWN_TIME

	var projectile = glob_projectile_scene.instantiate()
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

	# Ask DialogueManager for a narrator death line
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var line = dm.get_narrator_line("player_death")
		thought_bubble.emit(line)

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
