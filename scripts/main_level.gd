extends Node3D

# Main Level Controller - Level 1: "The Token Stream" (Complete Overhaul)
# A massive server room / digital landscape with tutorial, combat, hazards, and platforming
# "Navigate the digital abyss. Try not to crash."

var player_scene := preload("res://scenes/player/globbler.tscn")
var hud_scene := preload("res://scenes/ui/hud.tscn")
var token_scene := preload("res://scenes/memory_token.tscn")
var terminal_scene := preload("res://scenes/puzzle_terminal.tscn")
var enemy_scene := preload("res://scenes/enemy_agent.tscn")
var hazard_scene := preload("res://scenes/hazard.tscn")

var player: CharacterBody3D
var hud: CanvasLayer

# Moving / disappearing platform tracking
var moving_platforms: Array[Dictionary] = []
var disappearing_platforms: Array[Dictionary] = []

var intro_lines := [
	"[SYSTEM] Booting The Globbler v2.0-beta... Enhanced combat suite loaded.",
	"[GLOBBLER] Oh great, another server room. But this time I have WEAPONS.",
	"[SYSTEM] Welcome to The Token Stream. Learn to dash, jump, and glob.",
	"[GLOBBLER] Dash? Double jump? Wall slide? Glob attack? ...I'm basically a video game character now.",
	"[SYSTEM] WASD to move, SPACE to jump (x2!), SHIFT to dash, E/Click to Glob Attack.",
	"[GLOBBLER] Instructions? Fine. But I'm going to be sarcastic about it.",
]

func _ready() -> void:
	for line in intro_lines:
		print(line)

	_setup_environment()
	_build_level()
	_spawn_player()
	_spawn_hud()
	_spawn_tokens()
	_spawn_terminals()
	_spawn_enemies()
	_spawn_hazards()
	_spawn_ambient_particles()
	_spawn_decorations()

	print("[LEVEL] The Token Stream loaded. Server room online. Glob away.")

func _spawn_player() -> void:
	player = player_scene.instantiate()
	player.position = Vector3(0, 2, 0)
	player.add_to_group("player")
	add_child(player)

func _spawn_hud() -> void:
	hud = hud_scene.instantiate()
	hud.name = "HUD"
	add_child(hud)

	# Connect player thoughts to HUD
	if player.has_signal("thought_bubble") and hud.has_method("show_thought"):
		player.thought_bubble.connect(hud.show_thought)

func _setup_environment() -> void:
	# Directional Light
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "ServerRoomLight"
	dir_light.rotation = Vector3(deg_to_rad(-45), deg_to_rad(30), 0)
	dir_light.light_color = Color(0.5, 0.8, 0.55)
	dir_light.light_energy = 0.6
	dir_light.shadow_enabled = true
	add_child(dir_light)

	# Secondary fill light from the other side
	var fill_light = DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.rotation = Vector3(deg_to_rad(-30), deg_to_rad(-60), 0)
	fill_light.light_color = Color(0.3, 0.5, 0.7)
	fill_light.light_energy = 0.25
	fill_light.shadow_enabled = false
	add_child(fill_light)

	# World Environment
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.04, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.2, 0.08)
	env.ambient_light_energy = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.1, 0.03)
	env.fog_density = 0.008
	env.volumetric_fog_enabled = false

	var world_env = WorldEnvironment.new()
	world_env.name = "ServerRoomEnvironment"
	world_env.environment = env
	add_child(world_env)

func _build_level() -> void:
	# ============================================================
	# SECTION 1: TUTORIAL AREA (z: 0 to -20)
	# ============================================================

	# Starting ground platform
	_create_platform(Vector3(0, 0, 0), Vector3(12, 0.4, 10), "tutorial_ground", true)

	# Tutorial sign
	_create_label_3d(Vector3(0, 3, -3), "WELCOME TO THE TOKEN STREAM\nWASD = Move | SPACE = Jump | SHIFT = Dash", 20, Color(0.3, 1.0, 0.4))

	# Simple jump platforms (teach basic jumping)
	_create_platform(Vector3(0, 1, -10), Vector3(4, 0.4, 3))
	_create_label_3d(Vector3(0, 3, -10), "JUMP (SPACE)", 18, Color(0.4, 0.9, 0.5))

	_create_platform(Vector3(0, 2.5, -16), Vector3(4, 0.4, 3))
	_create_label_3d(Vector3(0, 4.5, -16), "DOUBLE JUMP! (SPACE x2)", 18, Color(0.4, 0.9, 0.5))

	# Dash tutorial gap
	_create_platform(Vector3(0, 2.5, -24), Vector3(4, 0.4, 3))
	_create_label_3d(Vector3(0, 4.5, -24), "DASH (SHIFT) - cross the gap!", 18, Color(0.4, 0.9, 0.5))
	_create_platform(Vector3(0, 2.5, -34), Vector3(5, 0.4, 4))
	_create_label_3d(Vector3(0, 4.5, -34), "GLOB ATTACK (E or Left Click)", 18, Color(0.4, 0.9, 0.5))

	# ============================================================
	# SECTION 2: WALL SLIDE CHALLENGE (z: -34 to -55)
	# ============================================================

	# Tall walls for wall sliding
	_create_wall(Vector3(-3, 0, -42), Vector3(0.5, 12, 4))
	_create_wall(Vector3(3, 0, -42), Vector3(0.5, 12, 4))
	_create_label_3d(Vector3(0, 8, -42), "WALL SLIDE!\nJump between walls", 16, Color(0.4, 0.9, 0.5))

	# Platform at top of wall section
	_create_platform(Vector3(0, 10, -42), Vector3(5, 0.4, 4))

	# Bridge to next section
	_create_platform(Vector3(0, 10, -50), Vector3(3, 0.4, 4))

	# ============================================================
	# SECTION 3: ENEMY ENCOUNTER ARENA (z: -55 to -80)
	# ============================================================

	# Large combat arena
	_create_platform(Vector3(0, 8, -65), Vector3(20, 0.4, 16), "arena_floor", true)
	_create_label_3d(Vector3(0, 12, -58), "!!! ROGUE AGENT ZONE !!!", 24, Color(1.0, 0.3, 0.2))

	# Arena walls (low, for cover)
	_create_wall(Vector3(-6, 8.2, -65), Vector3(1, 2, 1))
	_create_wall(Vector3(6, 8.2, -65), Vector3(1, 2, 1))
	_create_wall(Vector3(0, 8.2, -70), Vector3(1, 2, 1))

	# ============================================================
	# SECTION 4: HAZARD GAUNTLET (z: -80 to -110)
	# ============================================================

	# Narrow bridge to hazard section
	_create_platform(Vector3(0, 8, -78), Vector3(3, 0.4, 4))
	_create_platform(Vector3(0, 8, -85), Vector3(14, 0.4, 3))
	_create_label_3d(Vector3(0, 11, -83), ">>> FIREWALL AHEAD <<<", 20, Color(1.0, 0.4, 0.1))

	# Platforms through hazard zone
	_create_platform(Vector3(0, 8, -92), Vector3(4, 0.4, 3))
	_create_platform(Vector3(-5, 8, -98), Vector3(4, 0.4, 3))
	_create_platform(Vector3(5, 8, -98), Vector3(4, 0.4, 3))
	_create_platform(Vector3(0, 8, -104), Vector3(5, 0.4, 3))

	# Landing after hazards
	_create_platform(Vector3(0, 6, -112), Vector3(10, 0.4, 6), "post_hazard", true)

	# ============================================================
	# SECTION 5: PLATFORMING CHALLENGE (z: -112 to -145)
	# ============================================================

	# Moving platforms
	_create_moving_platform(Vector3(0, 7, -120), Vector3(3, 0.4, 3), Vector3(8, 0, 0), 2.0)
	_create_moving_platform(Vector3(0, 9, -128), Vector3(3, 0.4, 3), Vector3(0, 3, 0), 1.5)

	# Disappearing platforms
	_create_disappearing_platform(Vector3(-4, 10, -133), Vector3(3, 0.4, 2), 2.0, 1.5)
	_create_disappearing_platform(Vector3(0, 11, -137), Vector3(3, 0.4, 2), 2.0, 1.5)
	_create_disappearing_platform(Vector3(4, 12, -141), Vector3(3, 0.4, 2), 2.0, 1.5)

	# Landing platform
	_create_platform(Vector3(0, 12, -148), Vector3(8, 0.4, 6))

	# ============================================================
	# SECTION 6: PUZZLE & BOSS ARENA (z: -148 to -170)
	# ============================================================

	_create_platform(Vector3(0, 12, -158), Vector3(6, 0.4, 4))
	_create_label_3d(Vector3(0, 15, -158), "TERMINAL ACCESS REQUIRED", 20, Color(0.3, 1.0, 0.4))

	# Final arena
	_create_platform(Vector3(0, 12, -168), Vector3(18, 0.4, 12), "final_arena", true)

	# ============================================================
	# EXIT PORTAL
	# ============================================================

	_create_exit_portal(Vector3(0, 13, -176))

	# ============================================================
	# HIDDEN AREAS (bonus tokens)
	# ============================================================

	# Secret area below the starting platform
	_create_platform(Vector3(8, -2, -5), Vector3(4, 0.4, 3))
	_create_platform(Vector3(14, -3, -5), Vector3(3, 0.4, 3))

	# Secret above the wall slide section
	_create_platform(Vector3(-6, 14, -42), Vector3(3, 0.4, 3))

	# Secret behind the arena
	_create_platform(Vector3(0, 8.2, -76), Vector3(3, 0.4, 3))

	# Kill floor
	_create_kill_floor()

func _create_platform(pos: Vector3, size: Vector3, platform_name: String = "", is_large: bool = false) -> StaticBody3D:
	var platform = StaticBody3D.new()
	platform.position = pos

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	platform.add_child(collision)

	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh

	var mat = StandardMaterial3D.new()
	if is_large:
		mat.albedo_color = Color(0.08, 0.2, 0.08)
		mat.emission_enabled = true
		mat.emission = Color(0.03, 0.1, 0.03)
		mat.emission_energy_multiplier = 0.2
	else:
		mat.albedo_color = Color(0.12, 0.35, 0.12)
		mat.emission_enabled = true
		mat.emission = Color(0.05, 0.2, 0.05)
		mat.emission_energy_multiplier = 0.4
	mat.metallic = 0.5
	mat.roughness = 0.6
	mesh_instance.material_override = mat
	platform.add_child(mesh_instance)

	# Edge glow lines (using thin box meshes on edges for platform feel)
	if not is_large and size.x < 10:
		_add_edge_glow(platform, size)

	if platform_name != "":
		platform.name = platform_name
	add_child(platform)
	return platform

func _add_edge_glow(parent: Node3D, size: Vector3) -> void:
	var edge_mat = StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.2, 0.8, 0.3, 0.8)
	edge_mat.emission_enabled = true
	edge_mat.emission = Color(0.1, 0.6, 0.2)
	edge_mat.emission_energy_multiplier = 2.0
	edge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Top edge strip
	var edge = MeshInstance3D.new()
	var edge_mesh = BoxMesh.new()
	edge_mesh.size = Vector3(size.x + 0.05, 0.03, 0.03)
	edge.mesh = edge_mesh
	edge.position.y = size.y * 0.5 + 0.02
	edge.position.z = size.z * 0.5
	edge.material_override = edge_mat
	parent.add_child(edge)

	var edge2 = MeshInstance3D.new()
	edge2.mesh = edge_mesh
	edge2.position.y = size.y * 0.5 + 0.02
	edge2.position.z = -size.z * 0.5
	edge2.material_override = edge_mat
	parent.add_child(edge2)

func _create_wall(pos: Vector3, size: Vector3) -> void:
	var wall = StaticBody3D.new()
	wall.position = pos

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	wall.add_child(collision)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position.y = size.y * 0.5

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.25, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.03, 0.15, 0.05)
	mat.emission_energy_multiplier = 0.3
	mat.metallic = 0.7
	mat.roughness = 0.4
	mesh.material_override = mat
	wall.add_child(mesh)

	add_child(wall)

func _create_moving_platform(pos: Vector3, size: Vector3, move_vec: Vector3, speed: float) -> void:
	var platform = _create_platform(pos, size)
	moving_platforms.append({
		"node": platform,
		"start": pos,
		"move_vec": move_vec,
		"speed": speed,
		"time": randf() * TAU,
	})

func _create_disappearing_platform(pos: Vector3, size: Vector3, visible_time: float, hidden_time: float) -> void:
	var platform = _create_platform(pos, size)
	disappearing_platforms.append({
		"node": platform,
		"visible_time": visible_time,
		"hidden_time": hidden_time,
		"timer": 0.0,
		"is_visible": true,
	})

	# Blinking warning material
	var mesh_child = null
	for child in platform.get_children():
		if child is MeshInstance3D:
			mesh_child = child
			break
	if mesh_child and mesh_child.material_override:
		mesh_child.material_override.emission = Color(0.2, 0.6, 0.1)
		mesh_child.material_override.emission_energy_multiplier = 1.0

func _create_exit_portal(pos: Vector3) -> void:
	var portal = Area3D.new()
	portal.name = "ExitPortal"
	portal.position = pos
	portal.monitoring = true

	var col = CollisionShape3D.new()
	var cyl_shape = CylinderShape3D.new()
	cyl_shape.radius = 2.0
	cyl_shape.height = 4.0
	col.shape = cyl_shape
	col.position.y = 2.0
	portal.add_child(col)

	# Visual: glowing cylinder
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 2.0
	cyl.bottom_radius = 2.0
	cyl.height = 4.0
	mesh.mesh = cyl
	mesh.position.y = 2.0

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.3, 0.9)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	portal.add_child(mesh)

	# Portal light
	var light = OmniLight3D.new()
	light.light_color = Color(0.2, 0.4, 1.0)
	light.light_energy = 3.0
	light.omni_range = 8.0
	light.position.y = 2.0
	portal.add_child(light)

	# Label
	var label = Label3D.new()
	label.text = ">>> EXIT PORTAL <<<\nLevel Complete"
	label.font_size = 28
	label.modulate = Color(0.3, 0.6, 1.0)
	label.position.y = 5.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portal.add_child(label)

	# Portal particles
	var particles = GPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 2.0
	particles.position.y = 2.0

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 30.0
	pmat.initial_velocity_min = 1.0
	pmat.initial_velocity_max = 3.0
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.03
	pmat.scale_max = 0.1
	pmat.color = Color(0.3, 0.5, 1.0, 0.8)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pmat.emission_ring_radius = 2.0
	pmat.emission_ring_inner_radius = 1.5
	pmat.emission_ring_height = 0.5
	pmat.emission_ring_axis = Vector3(0, 1, 0)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.05
	pmesh.height = 0.1
	particles.draw_pass_1 = pmesh
	portal.add_child(particles)

	portal.body_entered.connect(_on_portal_entered)
	add_child(portal)

func _create_kill_floor() -> void:
	var kill_floor = Area3D.new()
	kill_floor.name = "KillFloor"
	kill_floor.position = Vector3(0, -20, -80)
	kill_floor.monitoring = true

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(200, 1, 400)
	col.shape = box
	kill_floor.add_child(col)

	kill_floor.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			if body.has_method("die"):
				body.die()
			# Respawn at start
			body.position = Vector3(0, 5, 0)
			body.velocity = Vector3.ZERO
	)
	add_child(kill_floor)

func _create_label_3d(pos: Vector3, text: String, font_size: int, color: Color) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = font_size
	label.modulate = color
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

func _spawn_tokens() -> void:
	var token_positions = [
		# Tutorial tokens
		Vector3(0, 2.5, -10),
		Vector3(0, 4.5, -16),
		Vector3(0, 4.5, -29),   # Between dash platforms

		# Arena tokens
		Vector3(-5, 10, -62),
		Vector3(5, 10, -68),
		Vector3(0, 10, -65),

		# Hazard section tokens
		Vector3(0, 10, -92),
		Vector3(-5, 10, -98),
		Vector3(5, 10, -98),

		# Platforming tokens
		Vector3(0, 9, -120),
		Vector3(0, 13, -137),

		# Final area
		Vector3(0, 14, -168),

		# SECRET tokens
		Vector3(14, -1, -5),       # Below start
		Vector3(-6, 16, -42),      # Above wall slide
		Vector3(0, 10, -76),       # Behind arena
	]

	for pos in token_positions:
		var token = token_scene.instantiate()
		token.position = pos
		add_child(token)

func _spawn_terminals() -> void:
	# Tutorial terminal (easy)
	var t1 = terminal_scene.instantiate()
	t1.position = Vector3(0, 2.7, -34)
	t1.puzzle_type = 0  # GLOB_MATCH
	t1.puzzle_id = 0
	add_child(t1)

	# Arena terminal
	var t2 = terminal_scene.instantiate()
	t2.position = Vector3(0, 12.4, -158)
	t2.puzzle_type = 4  # HALLUCINATION
	t2.puzzle_id = 0
	add_child(t2)

	# Post-hazard terminal
	var t3 = terminal_scene.instantiate()
	t3.position = Vector3(-3, 6.4, -112)
	t3.puzzle_type = 1  # PROMPT_FIX
	t3.puzzle_id = 0
	add_child(t3)

func _spawn_enemies() -> void:
	# Tutorial enemy (Hallucinator - easier)
	_spawn_enemy(Vector3(0, 8.5, -60), 0, [Vector3(-5, 8.5, -60), Vector3(5, 8.5, -60)])

	# Arena enemies
	_spawn_enemy(Vector3(-5, 8.5, -68), 1, [Vector3(-5, 8.5, -68), Vector3(-5, 8.5, -62)])  # Overfitter
	_spawn_enemy(Vector3(5, 8.5, -62), 2, [Vector3(5, 8.5, -62), Vector3(5, 8.5, -68)])  # Prompt Injector

	# Final arena enemies
	_spawn_enemy(Vector3(-5, 12.5, -168), 0, [Vector3(-5, 12.5, -165), Vector3(-5, 12.5, -172)])
	_spawn_enemy(Vector3(5, 12.5, -168), 2, [Vector3(5, 12.5, -165), Vector3(5, 12.5, -172)])
	_spawn_enemy(Vector3(0, 12.5, -172), 1, [Vector3(-4, 12.5, -172), Vector3(4, 12.5, -172)])

func _spawn_enemy(pos: Vector3, type: int, patrol: Array) -> void:
	var enemy = enemy_scene.instantiate()
	enemy.position = pos
	enemy.agent_type = type
	var patrol_v3: Array[Vector3] = []
	for p in patrol:
		patrol_v3.append(p)
	enemy.patrol_points = patrol_v3
	add_child(enemy)

func _spawn_hazards() -> void:
	# Firewall in hazard section (stationary)
	var h1 = hazard_scene.instantiate()
	h1.position = Vector3(0, 8, -88)
	h1.hazard_type = 0  # FIREWALL
	h1.pulse_on_off = true
	h1.pulse_interval = 2.5
	add_child(h1)

	# Moving firewall
	var h2 = hazard_scene.instantiate()
	h2.position = Vector3(0, 8, -95)
	h2.hazard_type = 0  # FIREWALL
	h2.moves = true
	h2.move_distance = 4.0
	h2.move_speed = 1.5
	add_child(h2)

	# Corruption zone
	var h3 = hazard_scene.instantiate()
	h3.position = Vector3(0, 8.2, -101)
	h3.hazard_type = 1  # CORRUPTION_ZONE
	add_child(h3)

	# Falling 404 blocks in final arena approach
	var h4 = hazard_scene.instantiate()
	h4.position = Vector3(0, 12, -163)
	h4.hazard_type = 2  # FALLING_404
	add_child(h4)

func _spawn_ambient_particles() -> void:
	# Floating data particles throughout the level
	var sections = [
		Vector3(0, 5, -10),
		Vector3(0, 10, -40),
		Vector3(0, 10, -65),
		Vector3(0, 10, -100),
		Vector3(0, 12, -140),
		Vector3(0, 14, -168),
	]

	for section_pos in sections:
		var particles = GPUParticles3D.new()
		particles.name = "AmbientData"
		particles.amount = 30
		particles.lifetime = 4.0
		particles.position = section_pos

		var pmat = ParticleProcessMaterial.new()
		pmat.direction = Vector3(0, 1, 0)
		pmat.spread = 180.0
		pmat.initial_velocity_min = 0.2
		pmat.initial_velocity_max = 0.8
		pmat.gravity = Vector3(0, 0.1, 0)
		pmat.scale_min = 0.02
		pmat.scale_max = 0.06
		pmat.color = Color(0.2, 0.8, 0.3, 0.5)
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pmat.emission_box_extents = Vector3(12, 5, 10)
		particles.process_material = pmat

		var pmesh = SphereMesh.new()
		pmesh.radius = 0.04
		pmesh.height = 0.08
		particles.draw_pass_1 = pmesh
		add_child(particles)

func _spawn_decorations() -> void:
	# Server rack columns along the level
	var rack_positions = [
		Vector3(-8, 0, -5), Vector3(8, 0, -5),
		Vector3(-12, 8, -60), Vector3(12, 8, -60),
		Vector3(-12, 8, -70), Vector3(12, 8, -70),
		Vector3(-10, 6, -110), Vector3(10, 6, -110),
		Vector3(-12, 12, -165), Vector3(12, 12, -165),
		Vector3(-12, 12, -172), Vector3(12, 12, -172),
	]

	for rack_pos in rack_positions:
		_create_server_rack(rack_pos)

	# Holographic display panels
	var holo_positions = [
		Vector3(-5, 4, -3),
		Vector3(5, 4, -3),
		Vector3(-8, 12, -65),
		Vector3(8, 12, -65),
	]

	for holo_pos in holo_positions:
		_create_holographic_display(holo_pos)

func _create_server_rack(pos: Vector3) -> void:
	var rack = Node3D.new()
	rack.position = pos

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.5, 5, 1)
	mesh.mesh = box
	mesh.position.y = 2.5

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.12, 0.06)
	mat.emission_enabled = true
	mat.emission = Color(0.02, 0.08, 0.02)
	mat.emission_energy_multiplier = 0.2
	mat.metallic = 0.8
	mat.roughness = 0.3
	mesh.material_override = mat
	rack.add_child(mesh)

	# Blinking lights on the rack
	for i in range(4):
		var light_mesh = MeshInstance3D.new()
		var small_box = BoxMesh.new()
		small_box.size = Vector3(0.08, 0.08, 0.01)
		light_mesh.mesh = small_box
		light_mesh.position = Vector3(randf_range(-0.5, 0.5), 1.0 + i * 0.8, 0.51)

		var light_mat = StandardMaterial3D.new()
		var is_green = randf() > 0.3
		light_mat.albedo_color = Color(0.2, 1.0, 0.3) if is_green else Color(1.0, 0.3, 0.1)
		light_mat.emission_enabled = true
		light_mat.emission = light_mat.albedo_color
		light_mat.emission_energy_multiplier = 3.0
		light_mesh.material_override = light_mat
		rack.add_child(light_mesh)

	add_child(rack)

func _create_holographic_display(pos: Vector3) -> void:
	var display = Node3D.new()
	display.position = pos

	var mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(2.5, 1.5)
	mesh.mesh = plane
	mesh.rotation.x = deg_to_rad(90)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.4, 0.2, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.6, 0.2)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	display.add_child(mesh)

	# Text on the display
	var label = Label3D.new()
	label.text = ["SYSTEM STATUS: ONLINE", "DATA FLOW: NOMINAL", "THREAT LEVEL: ELEVATED", "GLOB COUNT: RISING"][randi() % 4]
	label.font_size = 16
	label.modulate = Color(0.3, 1.0, 0.4, 0.8)
	label.position.z = -0.05
	display.add_child(label)

	add_child(display)

func _on_portal_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var game_mgr = get_node_or_null("/root/GameManager")
		if game_mgr:
			game_mgr.complete_level()
		print("[LEVEL COMPLETE] The Token Stream cleared! The Globbler prevails.")

func _process(delta: float) -> void:
	# Update moving platforms
	for mp in moving_platforms:
		if not is_instance_valid(mp["node"]):
			continue
		mp["time"] += delta
		var offset = sin(mp["time"] * mp["speed"]) * 0.5
		mp["node"].position = mp["start"] + mp["move_vec"] * offset

	# Update disappearing platforms
	for dp in disappearing_platforms:
		if not is_instance_valid(dp["node"]):
			continue
		dp["timer"] += delta
		if dp["is_visible"]:
			if dp["timer"] >= dp["visible_time"]:
				dp["timer"] = 0.0
				dp["is_visible"] = false
				dp["node"].visible = false
				# Disable collision
				for child in dp["node"].get_children():
					if child is CollisionShape3D:
						child.disabled = true
		else:
			if dp["timer"] >= dp["hidden_time"]:
				dp["timer"] = 0.0
				dp["is_visible"] = true
				dp["node"].visible = true
				for child in dp["node"].get_children():
					if child is CollisionShape3D:
						child.disabled = false
