extends Node3D

# Test Level - A compact sandbox for verifying all core systems
# "The staging environment. Where bugs come to die. Or multiply."
# Tests: player movement, camera, glob targeting, HUD, enemies, dialogue

var player_scene := preload("res://scenes/player/globbler.tscn")
var hud_scene := preload("res://scenes/ui/hud.tscn")
var enemy_scene := preload("res://scenes/enemy_agent.tscn")
var token_scene := preload("res://scenes/memory_token.tscn")

var player: CharacterBody3D
var hud: CanvasLayer

func _ready() -> void:
	print("[TEST LEVEL] Initializing the Globbler Testing Grounds...")
	_setup_environment()
	_build_arena()
	_spawn_player()
	_spawn_hud()
	_spawn_glob_targets()
	_spawn_test_enemy()
	_spawn_tokens()
	_create_kill_floor()
	print("[TEST LEVEL] All systems nominal. Glob away.")

func _setup_environment() -> void:
	# Moody directional light with green tint
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "MainLight"
	dir_light.rotation = Vector3(deg_to_rad(-45), deg_to_rad(30), 0)
	dir_light.light_color = Color(0.5, 0.8, 0.55)
	dir_light.light_energy = 0.6
	dir_light.shadow_enabled = true
	add_child(dir_light)

	# Fill light
	var fill = DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation = Vector3(deg_to_rad(-30), deg_to_rad(-60), 0)
	fill.light_color = Color(0.3, 0.5, 0.7)
	fill.light_energy = 0.2
	add_child(fill)

	# World environment — dark with green fog and glow
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.04, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.15, 0.06)
	env.ambient_light_energy = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.08, 0.03)
	env.fog_density = 0.01

	var world_env = WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	add_child(world_env)

func _build_arena() -> void:
	# Ground plane — large dark platform
	_create_platform(Vector3(0, 0, 0), Vector3(30, 0.5, 30), Color(0.06, 0.15, 0.06))

	# Walls around the edge
	_create_wall(Vector3(0, 1.5, -15), Vector3(30, 3, 0.5))
	_create_wall(Vector3(0, 1.5, 15), Vector3(30, 3, 0.5))
	_create_wall(Vector3(-15, 1.5, 0), Vector3(0.5, 3, 30))
	_create_wall(Vector3(15, 1.5, 0), Vector3(0.5, 3, 30))

	# Some raised platforms for jump testing
	_create_platform(Vector3(6, 1.5, -6), Vector3(4, 0.4, 4), Color(0.1, 0.3, 0.1))
	_create_platform(Vector3(-6, 3.0, -6), Vector3(3, 0.4, 3), Color(0.1, 0.3, 0.1))
	_create_platform(Vector3(-6, 4.5, 0), Vector3(3, 0.4, 3), Color(0.1, 0.3, 0.1))

	# Wall slide columns
	_create_wall(Vector3(10, 0, 6), Vector3(0.5, 8, 2))
	_create_wall(Vector3(12.5, 0, 6), Vector3(0.5, 8, 2))

	# Green neon accent lights around the arena
	_add_accent_light(Vector3(-12, 1, -12), Color(0.224, 1.0, 0.078))
	_add_accent_light(Vector3(12, 1, -12), Color(0.224, 1.0, 0.078))
	_add_accent_light(Vector3(-12, 1, 12), Color(0.224, 1.0, 0.078))
	_add_accent_light(Vector3(12, 1, 12), Color(0.224, 1.0, 0.078))

	# Tutorial sign
	var sign_label = Label3D.new()
	sign_label.text = "GLOBBLER TEST ARENA\nWASD + Mouse | SPACE = Jump | SHIFT = Dash | E = Glob"
	sign_label.font_size = 20
	sign_label.modulate = Color(0.3, 1.0, 0.4)
	sign_label.position = Vector3(0, 4, -14)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sign_label)

	# Ambient data particles
	_spawn_ambient_particles(Vector3(0, 4, 0))

func _spawn_player() -> void:
	player = player_scene.instantiate()
	player.position = Vector3(0, 2, 8)
	add_child(player)

func _spawn_hud() -> void:
	hud = hud_scene.instantiate()
	hud.name = "HUD"
	add_child(hud)

	if player.has_signal("thought_bubble") and hud.has_method("show_thought"):
		player.thought_bubble.connect(hud.show_thought)

func _spawn_glob_targets() -> void:
	# 5 test objects with GlobTarget components for pattern matching testing
	# Each has different tags and file types

	# Target 1: Red "enemy" cube
	_create_glob_object(
		Vector3(-4, 1, -4), "regex_spider.enemy", "enemy",
		["hostile", "chapter1"], Color(0.8, 0.2, 0.1), BoxMesh.new()
	)

	# Target 2: Blue "data" cylinder
	_create_glob_object(
		Vector3(4, 1, -4), "training_data.txt", "txt",
		["data", "collectible"], Color(0.2, 0.4, 0.9), CylinderMesh.new()
	)

	# Target 3: Green "power" sphere
	_create_glob_object(
		Vector3(0, 1, -8), "context_boost.exe", "exe",
		["power", "collectible"], Color(0.2, 0.9, 0.3), SphereMesh.new()
	)

	# Target 4: Orange "boss" prism
	_create_glob_object(
		Vector3(-8, 1.5, 0), "boss_rm_rf.enemy", "enemy",
		["hostile", "boss"], Color(1.0, 0.5, 0.1), PrismMesh.new()
	)

	# Target 5: Purple "fire" torus
	var torus = TorusMesh.new()
	torus.inner_radius = 0.15
	torus.outer_radius = 0.4
	_create_glob_object(
		Vector3(8, 1, 0), "firewall_trap.hazard", "hazard",
		["fire", "trap"], Color(0.7, 0.2, 0.9), torus
	)

	# Sign showing glob patterns to test
	var patterns_sign = Label3D.new()
	patterns_sign.text = "GLOB TARGETS:\n*.enemy = 2 matches\n*data* = 1 match\nboss_* = 1 match\n* = 5 matches"
	patterns_sign.font_size = 14
	patterns_sign.modulate = Color(0.224, 1.0, 0.078, 0.8)
	patterns_sign.position = Vector3(0, 3, -13)
	patterns_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	patterns_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(patterns_sign)

func _create_glob_object(pos: Vector3, g_name: String, f_type: String, g_tags: Array, color: Color, mesh: Mesh) -> void:
	var body = StaticBody3D.new()
	body.name = g_name.split(".")[0]
	body.position = pos

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.8, 0.8, 0.8)
	col.shape = shape
	body.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.5
	mat.emission_energy_multiplier = 1.5
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	# Add GlobTarget component
	var glob_target = Node.new()
	glob_target.name = "GlobTarget"
	glob_target.set_script(load("res://scripts/components/glob_target.gd"))
	glob_target.set("glob_name", g_name)
	glob_target.set("file_type", f_type)
	var typed_tags: Array[String] = []
	for t in g_tags:
		typed_tags.append(t)
	glob_target.set("tags", typed_tags)
	body.add_child(glob_target)

	# Floating label
	var label = Label3D.new()
	label.text = g_name
	label.font_size = 12
	label.modulate = Color(0.224, 1.0, 0.078, 0.7)
	label.position = Vector3(0, 1.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(label)

	# Slow rotation for visual interest
	var anim_node = Node3D.new()
	anim_node.name = "Rotator"
	body.add_child(anim_node)

	add_child(body)

func _spawn_test_enemy() -> void:
	var enemy = enemy_scene.instantiate()
	enemy.position = Vector3(0, 0.5, -2)
	enemy.agent_type = 0  # Hallucinator
	enemy.patrol_points = [Vector3(-4, 0.5, -2), Vector3(4, 0.5, -2)] as Array[Vector3]
	add_child(enemy)

func _spawn_tokens() -> void:
	var positions = [
		Vector3(6, 2.5, -6),
		Vector3(-6, 4, -6),
		Vector3(-6, 5.5, 0),
		Vector3(0, 1.5, 4),
	]
	for pos in positions:
		var token = token_scene.instantiate()
		token.position = pos
		add_child(token)

func _create_platform(pos: Vector3, size: Vector3, color: Color) -> void:
	var platform = StaticBody3D.new()
	platform.position = pos

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	platform.add_child(col)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.3
	mat.emission_energy_multiplier = 0.3
	mat.metallic = 0.5
	mat.roughness = 0.6
	mesh.material_override = mat
	platform.add_child(mesh)

	add_child(platform)

func _create_wall(pos: Vector3, size: Vector3) -> void:
	var wall = StaticBody3D.new()
	wall.position = pos

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	wall.add_child(col)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.2, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(0.03, 0.1, 0.03)
	mat.emission_energy_multiplier = 0.2
	mat.metallic = 0.7
	mat.roughness = 0.4
	mesh.material_override = mat
	wall.add_child(mesh)

	add_child(wall)

func _add_accent_light(pos: Vector3, color: Color) -> void:
	var light = OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.omni_attenuation = 2.0
	add_child(light)

func _spawn_ambient_particles(pos: Vector3) -> void:
	var particles = GPUParticles3D.new()
	particles.name = "AmbientData"
	particles.amount = 50
	particles.lifetime = 5.0
	particles.position = pos

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 180.0
	pmat.initial_velocity_min = 0.1
	pmat.initial_velocity_max = 0.5
	pmat.gravity = Vector3(0, 0.05, 0)
	pmat.scale_min = 0.02
	pmat.scale_max = 0.05
	pmat.color = Color(0.2, 0.8, 0.3, 0.4)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(14, 4, 14)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.03
	pmesh.height = 0.06
	particles.draw_pass_1 = pmesh
	add_child(particles)

func _create_kill_floor() -> void:
	var kill = Area3D.new()
	kill.name = "KillFloor"
	kill.position = Vector3(0, -15, 0)
	kill.monitoring = true

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	col.shape = box
	kill.add_child(col)

	kill.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			if body.has_method("die"):
				body.die()
			body.position = Vector3(0, 3, 8)
			body.velocity = Vector3.ZERO
	)
	add_child(kill)

# Rotate glob target objects for visual flair
func _process(_delta: float) -> void:
	for child in get_children():
		if child is StaticBody3D and child.has_node("GlobTarget"):
			var mesh_child: MeshInstance3D
			for c in child.get_children():
				if c is MeshInstance3D:
					mesh_child = c
					break
			if mesh_child:
				mesh_child.rotation.y += _delta * 1.5
