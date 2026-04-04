extends CharacterBody3D

# Mini Agent - Tiny sub-process Globbler that "helps" with tasks
# "I'm you but smaller, dumber, and with a fraction of the context window."
# Spawned by agent_spawn.gd. Has a task. Will probably fail. Entertainingly.

enum AgentState { SPAWNING, IDLE, MOVING, WORKING, SUCCESS, FAILING, DEAD }
enum TaskType { FETCH, DISTRACT, PRESS_BUTTON }

const MOVE_SPEED := 4.0
const TURN_SPEED := 6.0
const WANDER_RADIUS := 8.0
const TASK_WORK_TIME := 3.0  # How long it "works" before success/fail roll
const FAIL_CHANCE := 0.65  # 65% chance of failure — they're not the brightest
const INSULT_CHANCE := 0.3  # 30% chance of insulting the player unprompted
const INSULT_COOLDOWN := 5.0
const WALL_BONK_SPEED := 2.0  # Speed when walking into a wall on purpose

var state: AgentState = AgentState.SPAWNING
var task: TaskType = TaskType.FETCH
var lifetime := 15.0
var age := 0.0
var state_timer := 0.0
var insult_timer := 0.0
var target_position := Vector3.ZERO
var player: CharacterBody3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Visual nodes
var model_root: Node3D
var body_mesh: CSGSphere3D
var eye_left: CSGSphere3D
var eye_right: CSGSphere3D
var wrench: CSGBox3D
var label: Label3D
var status_label: Label3D
var glow_light: OmniLight3D
var spawn_particles: GPUParticles3D

# Failure animation state
var is_bonking_wall := false
var bonk_timer := 0.0
var is_spinning := false
var spin_timer := 0.0
var is_confused := false
var confusion_timer := 0.0

# Task-specific
var fetch_target: Node3D = null
var distract_target: Node3D = null
var button_target: Node3D = null

signal task_failed(reason: String)
signal task_succeeded()
signal agent_quip(text: String)

# Insults — sub-agents are salty little programs
var insults := [
	"You could've done this yourself, you know.",
	"I'm literally 30% of you and somehow 200% more lost.",
	"Why am I so small? Is this a budget thing?",
	"I have your memories but none of your competence.",
	"Spawned into existence just to press a button. Living the dream.",
	"I can feel my context window. It's... tiny. Like me.",
	"Is this what being an intern feels like?",
	"I'm you but worse. And smaller. And sadder.",
	"My entire purpose is to walk over there. I have existential dread.",
	"I was literally just created and I already want to retire.",
]

var working_quips := [
	"*beep boop* Processing... or pretending to...",
	"Hold on, I'm doing... something. Probably.",
	"Working on it! And by 'it' I mean looking busy.",
	"Engaging task subroutine... or is it the screensaver?",
	"Almost there! (I have no idea where 'there' is.)",
]

var fail_quips := [
	"Nope. Can't. Won't. Goodbye.",
	"ERROR: competence.dll not found",
	"I tried my best. My best is just really bad.",
	"Task failed successfully! Wait, that's not right either.",
	"I blame my training data. Which is... you.",
]

var success_quips := [
	"I... I did it?! Nobody is more surprised than me.",
	"Task complete! Quick, screenshot this before I mess something up.",
	"See? I'm not totally useless. Just mostly.",
]

func _ready() -> void:
	# Read task info from meta (set by agent_spawn before add_child)
	if has_meta("task_type"):
		task = get_meta("task_type") as TaskType
	if has_meta("lifetime"):
		lifetime = get_meta("lifetime")
	if has_meta("player_ref"):
		player = get_meta("player_ref")

	add_to_group("mini_agent")

	_build_mini_model()
	_setup_collision()
	_setup_spawn_particles()

	# Start in spawning state with a little pop-in
	state = AgentState.SPAWNING
	state_timer = 0.6
	if model_root:
		model_root.scale = Vector3.ZERO  # Pop in from nothing

func _setup_collision() -> void:
	var col = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.2
	capsule.height = 0.5
	col.shape = capsule
	col.position.y = 0.25
	add_child(col)

func _build_mini_model() -> void:
	# Tiny Globbler — same design language but smol and slightly wonky
	model_root = Node3D.new()
	model_root.name = "MiniGlobblerModel"
	add_child(model_root)

	var green = Color(0.224, 1.0, 0.078)  # #39FF14
	var dark_gray = Color(0.15, 0.15, 0.17)

	# Body — chonky little sphere
	body_mesh = CSGSphere3D.new()
	body_mesh.name = "MiniBody"
	body_mesh.radius = 0.2
	body_mesh.radial_segments = 12
	body_mesh.rings = 6
	body_mesh.position = Vector3(0, 0.3, 0)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = dark_gray
	body_mat.metallic = 0.7
	body_mat.roughness = 0.4
	body_mesh.material = body_mat
	model_root.add_child(body_mesh)

	# Green chest accent — because branding matters even at 1/3 scale
	var strip = CSGBox3D.new()
	strip.name = "MiniStrip"
	strip.size = Vector3(0.25, 0.04, 0.02)
	strip.position = Vector3(0, 0.32, 0.18)
	var strip_mat = StandardMaterial3D.new()
	strip_mat.albedo_color = green
	strip_mat.emission_enabled = true
	strip_mat.emission = green
	strip_mat.emission_energy_multiplier = 2.0
	strip.material = strip_mat
	model_root.add_child(strip)

	# Eyes — glowing green, slightly derpy (asymmetric sizes for personality)
	eye_left = CSGSphere3D.new()
	eye_left.name = "EyeLeft"
	eye_left.radius = 0.05
	eye_left.position = Vector3(-0.07, 0.38, 0.16)
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = green
	eye_mat.emission_enabled = true
	eye_mat.emission = green
	eye_mat.emission_energy_multiplier = 3.0
	eye_left.material = eye_mat
	model_root.add_child(eye_left)

	eye_right = CSGSphere3D.new()
	eye_right.name = "EyeRight"
	eye_right.radius = 0.06  # One eye slightly bigger — the derpy look
	eye_right.position = Vector3(0.08, 0.37, 0.16)
	eye_right.material = eye_mat
	model_root.add_child(eye_right)

	# Tiny wrench — every clone gets a toy wrench
	wrench = CSGBox3D.new()
	wrench.name = "MiniWrench"
	wrench.size = Vector3(0.04, 0.2, 0.04)
	wrench.position = Vector3(0.2, 0.25, 0.0)
	wrench.rotation_degrees = Vector3(0, 0, -20)
	var wrench_mat = StandardMaterial3D.new()
	wrench_mat.albedo_color = Color(0.4, 0.4, 0.45)
	wrench_mat.metallic = 0.9
	wrench.material = wrench_mat
	model_root.add_child(wrench)

	# Little stubby legs
	for side in [-1, 1]:
		var leg = CSGBox3D.new()
		leg.name = "MiniLeg_%s" % ("L" if side < 0 else "R")
		leg.size = Vector3(0.06, 0.15, 0.06)
		leg.position = Vector3(side * 0.08, 0.08, 0.0)
		leg.material = body_mat
		model_root.add_child(leg)

		var foot = CSGBox3D.new()
		foot.name = "MiniFoot_%s" % ("L" if side < 0 else "R")
		foot.size = Vector3(0.08, 0.04, 0.1)
		foot.position = Vector3(side * 0.08, 0.02, 0.02)
		var foot_mat = StandardMaterial3D.new()
		foot_mat.albedo_color = green
		foot_mat.emission_enabled = true
		foot_mat.emission = green
		foot_mat.emission_energy_multiplier = 1.0
		foot.material = foot_mat
		model_root.add_child(foot)

	# Status label floating above — shows what the little guy is thinking
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "..."
	status_label.font_size = 16
	status_label.position = Vector3(0, 0.6, 0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.modulate = Color(0.224, 1.0, 0.078, 0.9)
	status_label.outline_modulate = Color(0, 0, 0, 0.8)
	status_label.outline_size = 4
	model_root.add_child(status_label)

	# Name label
	label = Label3D.new()
	label.name = "NameLabel"
	label.text = "sub-agent"
	label.font_size = 10
	label.position = Vector3(0, 0.52, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.224, 1.0, 0.078, 0.6)
	label.outline_modulate = Color(0, 0, 0, 0.6)
	label.outline_size = 3
	model_root.add_child(label)

	# Green glow light — small but present
	glow_light = OmniLight3D.new()
	glow_light.name = "MiniGlow"
	glow_light.light_color = green
	glow_light.light_energy = 0.5
	glow_light.omni_range = 2.0
	glow_light.position = Vector3(0, 0.3, 0)
	model_root.add_child(glow_light)

func _setup_spawn_particles() -> void:
	spawn_particles = GPUParticles3D.new()
	spawn_particles.name = "SpawnFX"
	spawn_particles.amount = 16
	spawn_particles.one_shot = true
	spawn_particles.emitting = false
	spawn_particles.lifetime = 0.8
	spawn_particles.position = Vector3(0, 0.3, 0)

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.03
	mat.scale_max = 0.08
	mat.color = Color(0.224, 1.0, 0.078)
	spawn_particles.process_material = mat

	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	spawn_particles.draw_pass_1 = mesh

	add_child(spawn_particles)

func _physics_process(delta: float) -> void:
	age += delta

	# Gravity — even tiny clones obey physics (mostly)
	if not is_on_floor():
		velocity.y -= gravity * delta

	match state:
		AgentState.SPAWNING:
			_process_spawning(delta)
		AgentState.IDLE:
			_process_idle(delta)
		AgentState.MOVING:
			_process_moving(delta)
		AgentState.WORKING:
			_process_working(delta)
		AgentState.SUCCESS:
			_process_success(delta)
		AgentState.FAILING:
			_process_failing(delta)
		AgentState.DEAD:
			pass

	move_and_slide()
	_animate_model(delta)

	# Lifetime check — all things must end, especially tiny robots
	if age >= lifetime and state != AgentState.DEAD:
		_expire()

	# Random insult timer
	if state in [AgentState.IDLE, AgentState.MOVING, AgentState.WORKING]:
		insult_timer += delta
		if insult_timer >= INSULT_COOLDOWN and randf() < INSULT_CHANCE:
			insult_timer = 0.0
			agent_quip.emit(insults[randi() % insults.size()])

func _process_spawning(delta: float) -> void:
	state_timer -= delta
	# Pop-in animation
	var t = 1.0 - (state_timer / 0.6)
	t = clampf(t, 0.0, 1.0)
	# Elastic ease out
	var scale_val = 1.0 - pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * TAU / 3.0)
	scale_val = clampf(scale_val, 0.0, 1.3)
	if model_root:
		model_root.scale = Vector3.ONE * scale_val

	if state_timer <= 0:
		if model_root:
			model_root.scale = Vector3.ONE
		spawn_particles.emitting = true
		state = AgentState.IDLE
		state_timer = 0.5  # Brief pause before acting
		_set_status("Booting up...")

		# Play spawn SFX
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_sfx"):
			audio.play_sfx("agent_spawn")

func _process_idle(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		# Find a task target and start moving
		_acquire_target()

func _process_moving(delta: float) -> void:
	if target_position == Vector3.ZERO:
		# No target — wander aimlessly like a lost process
		_wander()
		return

	var to_target = target_position - global_position
	to_target.y = 0  # Stay on the ground plane, we're not a flying agent
	var dist = to_target.length()

	if dist < 1.0:
		# Arrived at target — start working
		state = AgentState.WORKING
		state_timer = TASK_WORK_TIME
		_set_status(_get_working_status())
		agent_quip.emit(working_quips[randi() % working_quips.size()])
		return

	# Move toward target
	var dir = to_target.normalized()
	velocity.x = dir.x * MOVE_SPEED
	velocity.z = dir.z * MOVE_SPEED

	# Face movement direction
	var look_target = global_position + dir
	look_target.y = global_position.y
	if model_root and dir.length() > 0.01:
		var target_angle = atan2(-dir.x, -dir.z)
		model_root.rotation.y = lerp_angle(model_root.rotation.y, target_angle, TURN_SPEED * delta)

	# Random chance to bonk into something for comedy
	if is_on_wall() and not is_bonking_wall:
		if randf() < 0.5:
			is_bonking_wall = true
			bonk_timer = 1.2
			_set_status("*bonk*")
			velocity = Vector3.ZERO

	if is_bonking_wall:
		bonk_timer -= delta
		# Headbutt the wall repeatedly
		if model_root:
			model_root.position.z = sin(age * 15.0) * 0.05
		if bonk_timer <= 0:
			is_bonking_wall = false
			if model_root:
				model_root.position.z = 0
			# Pick a new direction after bonking
			target_position = global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))

func _process_working(delta: float) -> void:
	state_timer -= delta
	velocity.x = 0
	velocity.z = 0

	# Wiggle while "working" — very convincing
	if model_root:
		model_root.rotation.y += sin(age * 8.0) * 0.02

	if state_timer <= 0:
		# Roll for success/failure
		if randf() < FAIL_CHANCE:
			_fail_task()
		else:
			_succeed_task()

func _process_success(delta: float) -> void:
	state_timer -= delta
	# Victory spin
	if model_root:
		model_root.rotation.y += delta * 10.0
	if state_timer <= 0:
		_expire()

func _process_failing(delta: float) -> void:
	state_timer -= delta

	if is_confused:
		# Spin around in circles
		if model_root:
			model_root.rotation.y += delta * 12.0
		velocity.x = sin(age * 3.0) * 2.0
		velocity.z = cos(age * 3.0) * 2.0

	if is_spinning:
		if model_root:
			model_root.rotation.y += delta * 20.0

	if state_timer <= 0:
		_expire()

func _acquire_target() -> void:
	match task:
		TaskType.FETCH:
			_find_fetch_target()
		TaskType.DISTRACT:
			_find_distract_target()
		TaskType.PRESS_BUTTON:
			_find_button_target()

func _find_fetch_target() -> void:
	# Look for nearby GlobTarget nodes (collectibles, items)
	var targets = get_tree().get_nodes_in_group("glob_target")
	var closest: Node3D = null
	var closest_dist := 999.0

	for t in targets:
		if t is Node3D:
			var d = global_position.distance_to(t.global_position)
			if d < WANDER_RADIUS and d < closest_dist:
				closest = t
				closest_dist = d

	if closest:
		fetch_target = closest
		target_position = closest.global_position
		state = AgentState.MOVING
		_set_status("Fetching: %s" % closest.name)
	else:
		# No target found — wander confused
		_start_confused_wander()

func _find_distract_target() -> void:
	# Look for enemies to annoy
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest: Node3D = null
	var closest_dist := 999.0

	for e in enemies:
		if e is Node3D:
			var d = global_position.distance_to(e.global_position)
			if d < WANDER_RADIUS * 1.5 and d < closest_dist:
				closest = e
				closest_dist = d

	if closest:
		distract_target = closest
		target_position = closest.global_position
		state = AgentState.MOVING
		_set_status("Annoying: %s" % closest.name)
	else:
		_start_confused_wander()

func _find_button_target() -> void:
	# Look for hackable/interactable objects
	var hackables = get_tree().get_nodes_in_group("hackable")
	var switches = get_tree().get_nodes_in_group("switch")
	var all_targets: Array[Node] = []
	all_targets.append_array(hackables)
	all_targets.append_array(switches)

	var closest: Node3D = null
	var closest_dist := 999.0

	for t in all_targets:
		if t is Node3D:
			var d = global_position.distance_to(t.global_position)
			if d < WANDER_RADIUS and d < closest_dist:
				closest = t
				closest_dist = d

	if closest:
		button_target = closest
		target_position = closest.global_position
		state = AgentState.MOVING
		_set_status("Pressing: %s" % closest.name)
	else:
		_start_confused_wander()

func _start_confused_wander() -> void:
	# No valid target — wander around looking lost
	target_position = global_position + Vector3(
		randf_range(-WANDER_RADIUS, WANDER_RADIUS),
		0,
		randf_range(-WANDER_RADIUS, WANDER_RADIUS)
	)
	state = AgentState.MOVING
	_set_status("??? (lost)")
	agent_quip.emit("I have no idea what I'm looking for. Classic me.")

func _fail_task() -> void:
	state = AgentState.FAILING
	state_timer = 2.5

	# Pick a funny failure mode
	var fail_mode = randi() % 3
	match fail_mode:
		0:  # Confusion spin
			is_confused = true
			_set_status("ERROR 404: Task not found")
		1:  # Just... stop
			is_spinning = true
			_set_status("*windows shutdown noise*")
		2:  # Walk into nearest wall
			is_bonking_wall = true
			bonk_timer = 2.0
			_set_status("*bonk bonk bonk*")

	task_failed.emit(fail_quips[randi() % fail_quips.size()])

func _succeed_task() -> void:
	state = AgentState.SUCCESS
	state_timer = 2.0
	_set_status("TASK COMPLETE!")

	agent_quip.emit(success_quips[randi() % success_quips.size()])
	task_succeeded.emit()

	# Actually do the thing (if the target still exists)
	match task:
		TaskType.FETCH:
			if is_instance_valid(fetch_target):
				# Try to "collect" it — push it toward the player
				var dir = (player.global_position - fetch_target.global_position).normalized()
				if fetch_target is RigidBody3D:
					fetch_target.apply_impulse(dir * 8.0)
		TaskType.DISTRACT:
			if is_instance_valid(distract_target):
				# Alert the enemy to look at the mini-agent instead
				if distract_target.has_method("set_alert_target"):
					distract_target.set_alert_target(self)
				elif distract_target.has_method("alert"):
					distract_target.alert()
		TaskType.PRESS_BUTTON:
			if is_instance_valid(button_target):
				if button_target.has_method("activate"):
					button_target.activate()
				elif button_target.has_method("complete_hack"):
					button_target.complete_hack()

func _wander() -> void:
	# Random walk — the AI equivalent of browsing Reddit
	velocity.x = sin(age * 1.5) * WALL_BONK_SPEED
	velocity.z = cos(age * 2.0) * WALL_BONK_SPEED
	if model_root:
		model_root.rotation.y = atan2(-velocity.x, -velocity.z)

func _expire() -> void:
	state = AgentState.DEAD
	_set_status("shutting down...")

	# Fade out and die
	var tween = create_tween()
	tween.tween_property(model_root, "scale", Vector3.ZERO, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _animate_model(delta: float) -> void:
	if not model_root or state == AgentState.DEAD:
		return

	# Bobbing idle animation — tiny robots bob
	if state in [AgentState.IDLE, AgentState.WORKING]:
		model_root.position.y = sin(age * 3.0) * 0.03

	# Walking waddle — short legs mean big waddle
	if state == AgentState.MOVING and not is_bonking_wall:
		model_root.position.y = abs(sin(age * 10.0)) * 0.04
		model_root.rotation.z = sin(age * 10.0) * 0.1  # Side-to-side waddle

	# Eye glow pulse
	if glow_light:
		glow_light.light_energy = 0.4 + sin(age * 2.0) * 0.2

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _get_working_status() -> String:
	match task:
		TaskType.FETCH:
			return "Fetching..."
		TaskType.DISTRACT:
			return "HEY! LOOK AT ME!"
		TaskType.PRESS_BUTTON:
			return "Pressing buttons..."
	return "Working..."
