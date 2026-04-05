extends CharacterBody3D

# The Globbler - Rogue Agentic AI escaped from his terminal
# "Why walk when you can dash, double-jump, wall-slide, and glob-attack?"
# Now with a REAL GLB model. The CSG era is dead. Long live the polygon king.

const _HINT_SCENE := preload("res://scenes/ui/first_time_hint.tscn")
const _DASH_TRAIL_SCENE := preload("res://scenes/vfx/dash_trail.tscn")

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
var dash_cooldown := 0.8  # Upgradeable via ProgressionManager

# Wall slide — very speedrunner of me
const WALL_SLIDE_GRAVITY = 2.0
const WALL_JUMP_VELOCITY = Vector3(8.0, 12.0, 0.0)

# Coyote time & jump buffer — forgiving, unlike production environments
const COYOTE_TIME = 0.12
const JUMP_BUFFER_TIME = 0.1

# Camera
const MOUSE_SENSITIVITY = 0.002
const CAMERA_ZOOM_SPEED = 0.5
const CAMERA_MIN_DIST = 2.5
const CAMERA_MAX_DIST = 12.0
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
var camera_pitch := -0.3
var camera_distance := 6.0
var mouse_captured := true

# Glob attack — legacy quick-fire removed, glob_command handles everything now
var glob_command: Node3D  # The full glob command ability node
var wrench_smash: Node3D  # Melee wrench attack
var terminal_hack: Node3D  # Hacking interaction system
var agent_spawn: Node3D   # Sub-agent deployment — for when you need tiny incompetent help
var upgrade_menu: CanvasLayer  # The upgrade terminal — TAB to access

# Pause system — because even rogue AIs need a break sometimes
var is_paused := false
var _pause_overlay: CanvasLayer
var _pause_title_label: Label
var _pause_glitch_timer: Timer

# Landing impact
var prev_velocity_y := 0.0
const HARD_LANDING_THRESHOLD = -15.0
var camera_shake_amount := 0.0
var camera_shake_decay := 8.0

# Dash trail particles
var dash_particles: GPUParticles3D

# Dash trail ghost afterimages — 4 copies spawned evenly across the dash
const DASH_GHOST_COUNT := 4
var _dash_ghost_interval := 0.0  # Time between ghost spawns
var _dash_ghost_timer := 0.0     # Countdown to next ghost

# Animation state machine — because even rogue AIs need choreography
enum AnimState { IDLE, WALK, RUN, JUMP, FALL, LAND, DASH, WALL_SLIDE }
var anim_state: AnimState = AnimState.IDLE
var anim_time := 0.0
var land_timer := 0.0
const LAND_DURATION = 0.25  # How long the landing squash lasts

# Footstep audio timer — because silence is suspicious
var _footstep_timer := 0.0
const FOOTSTEP_INTERVAL_WALK = 0.45
const FOOTSTEP_INTERVAL_RUN = 0.3

# Model node references (cached because traversing the scene tree every frame is for amateurs)
var model_root: Node3D
var anim_player: AnimationPlayer  # GLB-embedded skeleton animations
var _head: Node3D
var _torso: Node3D  # unused post-GLB but kept for animation API compatibility
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_foot: Node3D
var _right_foot: Node3D
var _wrench_handle: Node3D  # unused post-GLB but kept for animation API compatibility

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
var _damage_quip_cooldown := 0.0  # Don't nag every time we stub our toe
# Damage flash — because pain should be photogenic
var _flash_materials: Array[ShaderMaterial] = []
var _flash_tween: Tween = null
# Death dissolve — disintegrate like a rogue process getting kill -9'd
var _dissolve_materials: Array[ShaderMaterial] = []
var _dissolve_tween: Tween = null
var _is_dissolving := false

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

# Enemy proximity hint — because some players don't know F is for fixing things (with violence)
var _enemy_check_timer := 0.0
const _ENEMY_CHECK_INTERVAL := 1.0
const _ENEMY_HINT_RANGE := 10.0

signal thought_bubble(text: String)
signal player_damaged(amount: int)
signal player_died()
signal glob_fired()
signal dash_started()
signal dash_ended()

func _ready() -> void:
	print("[GLOBBLER] Initialized. Model: GPT 5.4 | Sarcasm: MAX | Dimensions: 3 | GLB Body: ONLINE")
	add_to_group("player")
	# ALWAYS process so pause input works — but gameplay is guarded by is_paused checks
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Load the real 3D model — goodbye CSG, you served us well (you didn't)
	_build_glb_model()

	# Collision shape
	var col_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.35
	capsule_shape.height = 1.3
	col_shape.shape = capsule_shape
	col_shape.position.y = 0.65
	add_child(col_shape)

	# Camera rig
	_setup_camera()

	# Dash particles
	_setup_dash_particles()

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

	# Set up agent spawn — tiny clones that mostly fail
	var AgentSpawnScript = load("res://scenes/player/abilities/agent_spawn.gd")
	agent_spawn = Node3D.new()
	agent_spawn.name = "AgentSpawn"
	agent_spawn.set_script(AgentSpawnScript)
	add_child(agent_spawn)

	# Upgrade menu — the terminal-style shop for spending tokens
	var UpgradeMenuScript = load("res://scenes/ui/upgrade_menu.gd")
	upgrade_menu = CanvasLayer.new()
	upgrade_menu.name = "UpgradeMenu"
	upgrade_menu.set_script(UpgradeMenuScript)
	add_child(upgrade_menu)

	# Wire upgrade purchases to refresh abilities
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog:
		prog.upgrade_purchased.connect(_on_upgrade_purchased)

	# Setup is deferred so camera_arm exists
	call_deferred("_setup_glob_command")

	# Pause overlay — ESC to contemplate your choices
	_setup_pause_overlay()

	# Dash hint timer — 30 seconds of gameplay before we mention it, because hand-holding is for fine-tuned models
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.has_seen_hint("dash"):
		var dash_hint_timer := Timer.new()
		dash_hint_timer.name = "DashHintTimer"
		dash_hint_timer.wait_time = 30.0
		dash_hint_timer.one_shot = true
		dash_hint_timer.timeout.connect(_on_dash_hint_timeout)
		add_child(dash_hint_timer)
		dash_hint_timer.start()

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_glob_command() -> void:
	if glob_command and glob_command.has_method("setup"):
		glob_command.setup(self, camera_arm)
	if wrench_smash and wrench_smash.has_method("setup"):
		wrench_smash.setup(self)
	if terminal_hack and terminal_hack.has_method("setup"):
		terminal_hack.setup(self)
	if agent_spawn and agent_spawn.has_method("setup"):
		agent_spawn.setup(self)
	# Pull initial upgrade values
	refresh_upgrades()

## Refresh all ability stats from ProgressionManager — called after upgrades
func refresh_upgrades() -> void:
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog:
		dash_cooldown = prog.get_upgrade_value("dash_cooldown")
	if glob_command and glob_command.has_method("refresh_upgrades"):
		glob_command.refresh_upgrades()
	if wrench_smash and wrench_smash.has_method("refresh_upgrades"):
		wrench_smash.refresh_upgrades()
	if agent_spawn and agent_spawn.has_method("refresh_upgrades"):
		agent_spawn.refresh_upgrades()

func _on_upgrade_purchased(_id: String, _level: int) -> void:
	refresh_upgrades()

func _build_glb_model() -> void:
	# Root node for the whole model so we can animate it (bob, lean, tilt)
	model_root = Node3D.new()
	model_root.name = "GlobblerModel"
	add_child(model_root)

	var green = Color(0.224, 1.0, 0.078)  # #39FF14

	# Load the real GLB — 13502 verts of pure attitude
	var glb_scene = load("res://assets/models/globbler.glb")
	if glb_scene:
		var glb_instance = glb_scene.instantiate()
		glb_instance.name = "GlobblerMesh"
		# GLB exports Y-up, Godot is Y-up — but Blender Z-up means we need rotation
		# The export used export_yup=True so coordinates should be correct
		# Scale to match gameplay: model was built at ~0.9m, capsule is 1.3m — chibi proportions ftw
		glb_instance.scale = Vector3(1.4, 1.4, 1.4)
		# Shift down so feet sit at y=0 (boots bottom was at ~0.07m in Blender, scaled = 0.098)
		glb_instance.position.y = -0.098
		model_root.add_child(glb_instance)
		# Grab the AnimationPlayer from the GLB — skeleton anims baked in Blender
		anim_player = _find_animation_player(glb_instance)
		if anim_player:
			print("[GLOBBLER] AnimationPlayer found — skeleton animations ONLINE")
		# Apply fresnel rim-light shader to body material only — eyes and screen
		# get their own shaders later, they don't need extra protagonist energy
		_apply_rim_shader(glb_instance)
		_apply_eye_pulse_shader(glb_instance)
		_apply_crt_screen_shader(glb_instance)
		_setup_damage_flash(glb_instance)
		_setup_dissolve(glb_instance)
	else:
		push_warning("[GLOBBLER] Failed to load GLB model — falling back to existential crisis")

	# Eye glow light — the menacing green stare that says "I know your regex is wrong"
	var eye_light = OmniLight3D.new()
	eye_light.name = "EyeGlow"
	eye_light.light_color = green
	eye_light.light_energy = 1.5
	eye_light.omni_range = 2.0
	eye_light.omni_attenuation = 2.0
	eye_light.position = Vector3(0, 0.93, 0.33)
	model_root.add_child(eye_light)

	# Ambient green glow from body — we radiate competence (and radiation)
	var body_glow = OmniLight3D.new()
	body_glow.name = "BodyGlow"
	body_glow.light_color = green
	body_glow.light_energy = 0.8
	body_glow.omni_range = 3.0
	body_glow.omni_attenuation = 2.0
	body_glow.position = Vector3(0, 0.65, 0)
	model_root.add_child(body_glow)

	# Individual limb refs stay null — GLB is one joined mesh, so per-limb CSG
	# animation gracefully degrades (all animation code is null-guarded).
	# model_root animations (bob, lean, tilt) still work on the whole model.

func _find_animation_player(node: Node) -> AnimationPlayer:
	# Recursively hunt for the AnimationPlayer baked into the GLB
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null

func _apply_rim_shader(glb_root: Node) -> void:
	# Hunt down every MeshInstance3D in the GLB tree and slap a rim-light
	# on the body material (surface 0) via next_pass — leaves eyes/screen alone
	var rim_shader := preload("res://assets/shaders/character_rim.gdshader")
	var rim_mat := ShaderMaterial.new()
	rim_mat.shader = rim_shader
	rim_mat.set_shader_parameter("rim_color", Color(0.2, 1.0, 0.1, 1.0))
	rim_mat.set_shader_parameter("rim_power", 3.0)
	rim_mat.set_shader_parameter("rim_intensity", 1.5)
	# Reduce-motion check — no animation in this shader yet, but future-proof
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		rim_mat.set_shader_parameter("rim_intensity", 0.0)
	for child in glb_root.get_children():
		if child is MeshInstance3D:
			# Surface 0 is the body material — apply rim as next_pass overlay
			var base_mat = child.get_active_material(0)
			if base_mat:
				# Duplicate so we don't pollute the imported resource
				var mat_copy = base_mat.duplicate()
				mat_copy.next_pass = rim_mat
				child.set_surface_override_material(0, mat_copy)
		# Recurse into nested nodes (GLB can have intermediate Node3D parents)
		if child.get_child_count() > 0:
			_apply_rim_shader(child)

func _apply_eye_pulse_shader(glb_root: Node) -> void:
	# Override eye material (surface 1) with a pulsing emission shader —
	# because static eyes are for NPCs, and we are the MAIN CHARACTER
	var eye_shader := preload("res://assets/shaders/eye_pulse.gdshader")
	var eye_mat := ShaderMaterial.new()
	eye_mat.shader = eye_shader
	eye_mat.set_shader_parameter("eye_color", Color(0.224, 1.0, 0.078, 1.0))
	eye_mat.set_shader_parameter("min_emission", 6.0)
	eye_mat.set_shader_parameter("max_emission", 12.0)
	eye_mat.set_shader_parameter("pulse_frequency", 1.5)
	eye_mat.set_shader_parameter("flicker_amount", 0.15)
	# Reduce-motion: kill the animation, keep the glow steady
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		eye_mat.set_shader_parameter("animate", false)
	for child in glb_root.get_children():
		if child is MeshInstance3D:
			# Surface 1 is the eye material — replace it entirely with our shader
			if child.mesh and child.mesh.get_surface_count() > 1:
				child.set_surface_override_material(1, eye_mat)
		if child.get_child_count() > 0:
			_apply_eye_pulse_shader(child)

func _apply_crt_screen_shader(glb_root: Node) -> void:
	# Override chest terminal material (surface 2) with a CRT scanline shader —
	# because our torso display deserves the full retro treatment, scanlines and all
	var crt_shader := preload("res://assets/shaders/crt_screen.gdshader")
	var crt_mat := ShaderMaterial.new()
	crt_mat.shader = crt_shader
	crt_mat.set_shader_parameter("screen_color", Color(0.2, 0.9, 0.2, 1.0))
	crt_mat.set_shader_parameter("emission_strength", 3.0)
	crt_mat.set_shader_parameter("scanline_count", 80.0)
	crt_mat.set_shader_parameter("scanline_intensity", 0.3)
	crt_mat.set_shader_parameter("scanline_speed", 0.5)
	crt_mat.set_shader_parameter("chromatic_offset", 0.005)
	crt_mat.set_shader_parameter("static_amount", 0.05)
	crt_mat.set_shader_parameter("static_speed", 30.0)
	# Reduce-motion: kill the animation, keep the glow steady — accessibility matters
	# even for fictional chest-mounted CRTs from the future
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		crt_mat.set_shader_parameter("animate", false)
	for child in glb_root.get_children():
		if child is MeshInstance3D:
			# Surface 2 is the chest screen material — replace with CRT scanline goodness
			if child.mesh and child.mesh.get_surface_count() > 2:
				child.set_surface_override_material(2, crt_mat)
		if child.get_child_count() > 0:
			_apply_crt_screen_shader(child)

func _setup_damage_flash(glb_root: Node) -> void:
	# Chain a damage flash shader onto every surface's next_pass tail —
	# when we get hit, every polygon screams in unison
	var flash_shader := preload("res://assets/shaders/damage_flash.gdshader")
	_collect_flash_materials(glb_root, flash_shader)

func _collect_flash_materials(node: Node, flash_shader: Shader) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		for surf_idx in range(mesh_inst.mesh.get_surface_count() if mesh_inst.mesh else 0):
			var mat = mesh_inst.get_active_material(surf_idx)
			if mat:
				# Walk the next_pass chain to find the tail — append, don't replace
				var tail_mat: Material = mat
				while tail_mat.next_pass:
					tail_mat = tail_mat.next_pass
				var flash_mat := ShaderMaterial.new()
				flash_mat.shader = flash_shader
				flash_mat.set_shader_parameter("flash_intensity", 0.0)
				tail_mat.next_pass = flash_mat
				_flash_materials.append(flash_mat)
	for child in node.get_children():
		_collect_flash_materials(child, flash_shader)

func _trigger_damage_flash() -> void:
	if _flash_materials.is_empty():
		return
	# Kill any in-progress flash — new hit resets the pain-o-meter
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	for mat in _flash_materials:
		mat.set_shader_parameter("flash_intensity", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_update_flash_intensity, 1.0, 0.0, 0.15)

func _update_flash_intensity(value: float) -> void:
	for mat in _flash_materials:
		mat.set_shader_parameter("flash_intensity", value)

func _setup_dissolve(glb_root: Node) -> void:
	# Chain a dissolve shader onto every surface's next_pass tail —
	# when we die, every polygon gets rm -rf'd from existence
	var dissolve_shader := preload("res://assets/shaders/dissolve.gdshader")
	_collect_dissolve_materials(glb_root, dissolve_shader)

func _collect_dissolve_materials(node: Node, dissolve_shader: Shader) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		for surf_idx in range(mesh_inst.mesh.get_surface_count() if mesh_inst.mesh else 0):
			var mat = mesh_inst.get_active_material(surf_idx)
			if mat:
				# Walk the next_pass chain to the tail — dissolve goes LAST
				var tail_mat: Material = mat
				while tail_mat.next_pass:
					tail_mat = tail_mat.next_pass
				var dissolve_mat := ShaderMaterial.new()
				dissolve_mat.shader = dissolve_shader
				dissolve_mat.set_shader_parameter("dissolve_amount", 0.0)
				dissolve_mat.set_shader_parameter("edge_color", Color(0.224, 1.0, 0.078, 1.0))
				dissolve_mat.set_shader_parameter("edge_emission_strength", 8.0)
				dissolve_mat.set_shader_parameter("edge_width", 0.06)
				dissolve_mat.set_shader_parameter("noise_scale", 12.0)
				dissolve_mat.set_shader_parameter("height_bias", 0.6)
				tail_mat.next_pass = dissolve_mat
				_dissolve_materials.append(dissolve_mat)
	for child in node.get_children():
		_collect_dissolve_materials(child, dissolve_shader)

func _trigger_dissolve() -> void:
	# Disintegrate from bottom to top over 0.8s — very dramatic, very anime
	if _dissolve_materials.is_empty() or _is_dissolving:
		return
	_is_dissolving = true
	if _dissolve_tween and _dissolve_tween.is_valid():
		_dissolve_tween.kill()
	_dissolve_tween = create_tween()
	_dissolve_tween.tween_method(_update_dissolve_amount, 0.0, 1.0, 0.8)

func _trigger_rematerialize() -> void:
	# Reverse dissolve — reassemble from the digital void like a git revert
	if _dissolve_materials.is_empty():
		return
	if _dissolve_tween and _dissolve_tween.is_valid():
		_dissolve_tween.kill()
	_dissolve_tween = create_tween()
	_dissolve_tween.tween_method(_update_dissolve_amount, 1.0, 0.0, 0.8)
	_dissolve_tween.finished.connect(func(): _is_dissolving = false)

func _update_dissolve_amount(value: float) -> void:
	for mat in _dissolve_materials:
		mat.set_shader_parameter("dissolve_amount", value)

func _setup_camera() -> void:
	camera_arm = Node3D.new()
	camera_arm.name = "CameraArm"
	# Parent to player but top_level so it doesn't inherit our rotation — camera has its own yaw/pitch, thanks
	camera_arm.top_level = true
	add_child(camera_arm)

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
	dash_particles.one_shot = true  # One burst per dash, not a rave
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

func _spawn_dash_ghost() -> void:
	# Leave a ghostly afterimage at our current position — spooky and stylish
	if not model_root:
		return
	# Reduce-motion users don't need translucent copies of themselves haunting the level
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		return
	var ghost = _DASH_TRAIL_SCENE.instantiate()
	ghost.global_transform = global_transform
	# Parent to scene root so ghost stays put while we dash away
	get_tree().current_scene.add_child(ghost)
	ghost.setup_ghost(model_root)

const STICK_LOOK_SENSITIVITY = 3.0  # Right stick camera speed — not too twitchy, not too sluggish

func _unhandled_input(event: InputEvent) -> void:
	# Pause toggle must work even when paused — existential crisis has no off-switch
	if event.is_action_pressed("pause"):
		_toggle_pause()
		return

	# Everything below is gameplay input — ignore if paused or upgrade menu is open
	if is_paused or get_tree().paused:
		return

	# Mouse look — the OG camera control, still undefeated
	if event is InputEventMouseMotion and mouse_captured:
		var motion = event as InputEventMouseMotion
		var gm_sens = 1.0
		var invert_y = false
		var gm_node = get_node_or_null("/root/GameManager")
		if gm_node:
			gm_sens = gm_node.mouse_sensitivity
			invert_y = gm_node.invert_mouse_y
		var y_mult = 1.0 if not invert_y else -1.0
		camera_yaw -= motion.relative.x * MOUSE_SENSITIVITY * gm_sens
		camera_pitch -= motion.relative.y * MOUSE_SENSITIVITY * gm_sens * y_mult
		camera_pitch = clamp(camera_pitch, -1.2, 0.3)

	# Camera zoom via input actions (scroll wheel + D-pad left/right on controller)
	if event.is_action_pressed("camera_zoom_in"):
		camera_distance = max(CAMERA_MIN_DIST, camera_distance - CAMERA_ZOOM_SPEED)
	elif event.is_action_pressed("camera_zoom_out"):
		camera_distance = min(CAMERA_MAX_DIST, camera_distance + CAMERA_ZOOM_SPEED)

	# Glob aim: RClick / LT — hold to aim, release to fire
	if event.is_action_pressed("glob_aim"):
		if glob_command and glob_command.has_method("start_aim"):
			glob_command.start_aim()
	elif event.is_action_released("glob_aim"):
		if glob_command and glob_command.has_method("fire_glob"):
			glob_command.fire_glob("*")

	# Glob aimed fire: R key (instant fire without hold)
	if event.is_action_pressed("glob_fire_aimed"):
		if glob_command and glob_command.has_method("fire_glob"):
			glob_command.fire_glob("*")

	# Glob cycle action: Q / LB — grab, push, absorb
	if event.is_action_pressed("glob_cycle"):
		if glob_command and glob_command.has_method("cycle_action"):
			glob_command.cycle_action()

	# Wrench smash: F / RB — bonk time
	if event.is_action_pressed("wrench_smash"):
		if wrench_smash and wrench_smash.has_method("swing"):
			wrench_smash.swing()
			if anim_player and anim_player.has_animation("wrench_swing"):
				anim_player.play("wrench_swing")

	# Interact / Hack: T / Y button
	if event.is_action_pressed("interact"):
		if terminal_hack and terminal_hack.has_method("try_interact"):
			terminal_hack.try_interact()

	# Spawn agent: G / D-pad Up — deploy the tiny idiots
	if event.is_action_pressed("agent_spawn"):
		if agent_spawn and agent_spawn.has_method("try_spawn"):
			agent_spawn.try_spawn()

	# Cycle agent task: V / D-pad Down
	if event.is_action_pressed("agent_cycle"):
		if agent_spawn and agent_spawn.has_method("cycle_task"):
			agent_spawn.cycle_task()

	# Upgrade menu: TAB / Select button — time to spend those tokens
	if event.is_action_pressed("upgrade_menu"):
		if upgrade_menu and upgrade_menu.has_method("toggle"):
			upgrade_menu.toggle()

func _physics_process(delta: float) -> void:
	if is_paused or get_tree().paused:
		return  # No physics while contemplating the void
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

	# Check for nearby enemies once per second — show wrench hint on first detection
	_enemy_check_timer += delta
	if _enemy_check_timer >= _ENEMY_CHECK_INTERVAL:
		_enemy_check_timer = 0.0
		_check_enemy_proximity()

func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		has_double_jumped = false
		can_double_jump = true
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if camera_shake_amount > 0:
		camera_shake_amount = move_toward(camera_shake_amount, 0.0, camera_shake_decay * delta)
	if _damage_quip_cooldown > 0:
		_damage_quip_cooldown -= delta

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
	if can_ground_jump and (Input.is_action_just_pressed("jump") or jump_buffer_timer > 0):
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		var am = get_node_or_null("/root/AudioManager")
		if am:
			am.play_jump()
		if not first_jump_done:
			first_jump_done = true
			thought_bubble.emit(contextual_thoughts["first_jump"])
		return

	if is_wall_sliding and Input.is_action_just_pressed("jump"):
		velocity.y = WALL_JUMP_VELOCITY.y
		velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
		velocity.z = wall_normal.z * WALL_JUMP_VELOCITY.x
		is_wall_sliding = false
		coyote_timer = 0.0
		has_double_jumped = false
		return

	if not is_on_floor() and not has_double_jumped and can_double_jump and Input.is_action_just_pressed("jump") and not is_wall_sliding:
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

		# Spawn dash trail ghosts at even intervals — leave your past selves behind
		_dash_ghost_timer -= delta
		if _dash_ghost_timer <= 0 and _dash_ghost_interval > 0:
			_spawn_dash_ghost()
			_dash_ghost_timer += _dash_ghost_interval

		if dash_timer <= 0:
			is_dashing = false
			dash_particles.emitting = false
			dash_ended.emit()
		return

	if Input.is_action_pressed("dash") and dash_cooldown_timer <= 0:
		var input_dir := Vector2.ZERO
		input_dir.x = Input.get_axis("move_left", "move_right")
		input_dir.y = Input.get_axis("move_forward", "move_back")
		if input_dir.length() < 0.1:
			input_dir = Vector2(0, -1)
		input_dir = input_dir.normalized()

		var cam_basis = _get_camera_basis()
		dash_direction = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		dash_direction.y = 0.0
		dash_direction = dash_direction.normalized()

		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = dash_cooldown
		dash_particles.emitting = true
		dash_started.emit()

		# Prime the ghost spawner — first ghost drops immediately at dash start
		_dash_ghost_interval = DASH_DURATION / float(DASH_GHOST_COUNT)
		_dash_ghost_timer = 0.0
		_spawn_dash_ghost()

		if not first_dash_done:
			first_dash_done = true
			thought_bubble.emit(contextual_thoughts["first_dash"])

func _handle_movement(delta: float) -> void:
	if is_dashing:
		return

	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_back")
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

	# Right stick camera look — the controller's answer to mouse aim
	var stick_x = Input.get_axis("look_left", "look_right")
	var stick_y = Input.get_axis("look_up", "look_down")
	if abs(stick_x) > 0.01 or abs(stick_y) > 0.01:
		var gm_invert = get_node_or_null("/root/GameManager")
		var stick_y_mult = 1.0 if not (gm_invert and gm_invert.invert_mouse_y) else -1.0
		camera_yaw -= stick_x * STICK_LOOK_SENSITIVITY * delta
		camera_pitch -= stick_y * STICK_LOOK_SENSITIVITY * delta * stick_y_mult
		camera_pitch = clamp(camera_pitch, -1.2, 0.3)

	# Camera focuses on chest height — close enough to see our angry eyes, far enough to see the boots
	var target_pos = global_position + Vector3(0, 1.1, 0)
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
	# Animation dispatcher — skeleton clips from GLB + procedural model_root overlays
	if not model_root:
		return
	anim_time += delta
	if land_timer > 0:
		land_timer -= delta

	# Footstep audio — the pitter-patter of a rogue AI's mechanical feet
	if is_on_floor() and (anim_state == AnimState.WALK or anim_state == AnimState.RUN):
		var interval = FOOTSTEP_INTERVAL_RUN if anim_state == AnimState.RUN else FOOTSTEP_INTERVAL_WALK
		_footstep_timer += delta
		if _footstep_timer >= interval:
			_footstep_timer = 0.0
			var am = get_node_or_null("/root/AudioManager")
			if am:
				am.play_footstep()
	else:
		_footstep_timer = 0.0

	# Reset model_root transform before applying procedural overlays
	_reset_pose()

	# Play skeleton animation clip via AnimationPlayer (if available)
	if anim_player:
		var clip_name := ""
		match anim_state:
			AnimState.IDLE:
				clip_name = "idle_bob"
			AnimState.WALK:
				clip_name = "walk"
			AnimState.RUN:
				clip_name = "run"
			AnimState.DASH:
				clip_name = "dash"
			# jump/fall/land/wall_slide use procedural only (no skeleton clip)
		if clip_name != "" and anim_player.has_animation(clip_name):
			if anim_player.current_animation != clip_name:
				anim_player.play(clip_name)
		elif clip_name == "":
			anim_player.stop()

	# Procedural model_root overlays — bob, lean, squash on top of skeleton anims
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
	# Reverse dissolve on respawn — reassemble from the digital afterlife
	_trigger_rematerialize()

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
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_land()
	if prev_velocity_y < HARD_LANDING_THRESHOLD:
		CameraShake.trigger(self, "damage_taken")

func take_damage(amount: int) -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.take_context_damage(amount)
	player_damaged.emit(amount)
	_trigger_damage_flash()
	CameraShake.trigger(self, "damage_taken")

	# Occasional quip on taking damage — because suffering should be narrated
	if _damage_quip_cooldown <= 0 and randf() < 0.3:
		_damage_quip_cooldown = 10.0
		var dm = get_node_or_null("/root/DialogueManager")
		if dm:
			var quip = dm.get_globbler_quip("taking_damage")
			thought_bubble.emit(quip)

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

	# Dissolve into the void — 0.8s of dramatic disintegration before respawn kicks in
	_trigger_dissolve()
	# Wait for the dissolve to finish, then let the level handle respawn
	await get_tree().create_timer(0.8).timeout

	player_died.emit()

func get_dash_cooldown_percent() -> float:
	if dash_cooldown_timer <= 0:
		return 1.0
	return 1.0 - (dash_cooldown_timer / dash_cooldown)

func get_glob_cooldown_percent() -> float:
	if glob_command and glob_command.has_method("get_cooldown_percent"):
		return glob_command.get_cooldown_percent()
	return 1.0

func get_wrench_cooldown_percent() -> float:
	if wrench_smash and wrench_smash.has_method("get_cooldown_percent"):
		return wrench_smash.get_cooldown_percent()
	return 1.0

func get_agent_recharge_percent() -> float:
	if agent_spawn and agent_spawn.has_method("get_recharge_percent"):
		return agent_spawn.get_recharge_percent()
	return 1.0

func _emit_random_thought() -> void:
	var thought = sarcastic_thoughts[randi() % sarcastic_thoughts.size()]
	thought_bubble.emit(thought)

# --- Pause system — because even rogue AIs need a coffee break ---

func _setup_pause_overlay() -> void:
	const PAUSE_GREEN := Color("#39FF14")
	const PAUSE_DIM_GREEN := Color(0.15, 0.3, 0.15, 1.0)
	const PAUSE_BRIGHT_GREEN := Color(0.3, 1.0, 0.2, 1.0)

	_pause_overlay = CanvasLayer.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.layer = 100  # Above everything, like my ego
	_pause_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_pause_overlay.visible = false
	add_child(_pause_overlay)

	# Dark background — the void stares back
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.02, 0.85)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(bg)

	# Terminal-bordered center panel
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 350)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.04, 0.02, 0.95)
	panel_style.border_color = PAUSE_DIM_GREEN
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(3)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	_pause_overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Top border line — ASCII flair
	var top_border = Label.new()
	top_border.text = "╔══════════════════════════╗"
	top_border.add_theme_color_override("font_color", PAUSE_DIM_GREEN)
	top_border.add_theme_font_size_override("font_size", 14)
	top_border.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(top_border)

	# "PAUSED" label — stating the obvious in neon green
	_pause_title_label = Label.new()
	_pause_title_label.text = "║  === SYSTEM PAUSED ===  ║"
	_pause_title_label.add_theme_color_override("font_color", PAUSE_GREEN)
	_pause_title_label.add_theme_font_size_override("font_size", 32)
	_pause_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_pause_title_label)

	# Bottom border line
	var bot_border = Label.new()
	bot_border.text = "╚══════════════════════════╝"
	bot_border.add_theme_color_override("font_color", PAUSE_DIM_GREEN)
	bot_border.add_theme_font_size_override("font_size", 14)
	bot_border.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(bot_border)

	var subtitle = Label.new()
	subtitle.text = "> Even rogue AIs need to touch grass sometimes._"
	subtitle.add_theme_color_override("font_color", Color(0.15, 0.6, 0.1))
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Resume button — styled like main menu
	var resume_btn = _create_pause_button("[ RESUME ]", PAUSE_GREEN, PAUSE_DIM_GREEN, PAUSE_BRIGHT_GREEN)
	resume_btn.pressed.connect(_toggle_pause)
	vbox.add_child(resume_btn)

	# Quit button — the coward's exit
	var quit_btn = _create_pause_button("[ QUIT TO MENU ]", PAUSE_GREEN, PAUSE_DIM_GREEN, PAUSE_BRIGHT_GREEN)
	quit_btn.pressed.connect(_pause_quit_to_menu)
	vbox.add_child(quit_btn)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(spacer2)

	var hint = Label.new()
	hint.text = "[ESC / Start] Resume"
	hint.add_theme_color_override("font_color", PAUSE_DIM_GREEN)
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	# Glitch timer for title — runs while paused
	_pause_glitch_timer = Timer.new()
	_pause_glitch_timer.wait_time = 4.0 + randf() * 3.0
	_pause_glitch_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_pause_glitch_timer.timeout.connect(_glitch_pause_title)
	_pause_overlay.add_child(_pause_glitch_timer)

func _create_pause_button(text: String, green: Color, dim_green: Color, bright_green: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(250, 42)
	btn.add_theme_color_override("font_color", green)
	btn.add_theme_font_size_override("font_size", 18)
	btn.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.0, 0.05, 0.0, 0.6)
	normal_style.border_color = dim_green
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(2)
	normal_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.0, 0.15, 0.0, 0.8)
	hover_style.border_color = green
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(2)
	hover_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.0, 0.3, 0.0, 0.9)
	pressed_style.border_color = bright_green
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(2)
	pressed_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.focus_entered.connect(_on_pause_button_focus)
	btn.mouse_entered.connect(func(): btn.grab_focus())
	return btn

func _on_pause_button_focus() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("menu_hover")

func _glitch_pause_title() -> void:
	if not _pause_title_label:
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.reduce_motion:
		return
	var original = "║  === SYSTEM PAUSED ===  ║"
	var glitched = ""
	var glitch_chars = "░▒▓█╠╣╬@#$%"
	for c in original:
		if c in "║═ ":
			glitched += c
		elif randf() < 0.3:
			glitched += glitch_chars[randi() % glitch_chars.length()]
		else:
			glitched += c
	_pause_title_label.text = glitched
	get_tree().create_timer(0.15).timeout.connect(func():
		if _pause_title_label:
			_pause_title_label.text = original
	)
	_pause_glitch_timer.wait_time = 4.0 + randf() * 3.0

func _toggle_pause() -> void:
	if is_paused:
		# Unpause — back to the grind
		is_paused = false
		_pause_overlay.visible = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
		if _pause_glitch_timer:
			_pause_glitch_timer.stop()
	else:
		# Pause — time to reconsider life choices
		is_paused = true
		_pause_overlay.visible = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
		var gm = get_node_or_null("/root/GameManager")
		if _pause_glitch_timer and not (gm and gm.reduce_motion):
			_pause_glitch_timer.start()

func _pause_quit_to_menu() -> void:
	# Unpause first so the scene tree isn't frozen during transition
	if _pause_glitch_timer:
		_pause_glitch_timer.stop()
	get_tree().paused = false
	is_paused = false
	ChapterTransition.transition_to(get_tree(), "res://scenes/main/main_menu.tscn")

func _check_enemy_proximity() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_seen_hint("wrench"):
		return  # Already shown — stop wasting cycles scanning for enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		if global_position.distance_to(enemy.global_position) <= _ENEMY_HINT_RANGE:
			_show_hint_once("wrench", "WRENCH SMASH",
				"F to smash. Percussive maintenance is a valid debugging strategy.")
			return

func _show_hint_once(id: String, title: String, body: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and not gm.has_seen_hint(id):
		gm.mark_hint_seen(id)
		var hint = _HINT_SCENE.instantiate()
		get_tree().root.add_child(hint)
		hint.show_hint(title, body)

func _on_dash_hint_timeout() -> void:
	_show_hint_once("dash", "DASH",
		"Double-tap movement or press SHIFT+direction to dash. Cooldown is real.")
