extends "res://scenes/enemies/base_enemy.gd"

# Zombie Process - Slow, tanky, keeps respawning unless you kill the parent process
# "kill -9 won't work on me. I'm unkillable. Well, mostly."
# Behavior: slow but high HP, respawns after death unless parent node destroyed

const RESPAWN_TIME := 5.0
const MAX_RESPAWNS := 3

var respawn_count := 0
var parent_process: Node3D = null  # If this exists, zombie keeps respawning
var respawn_position := Vector3.ZERO

func _ready() -> void:
	enemy_name = "zombie_process.enemy"
	enemy_tags = ["hostile", "chapter1", "zombie", "persistent"]
	max_health = 6  # Tanky boi
	contact_damage = 10  # Slow AND deadly was a bit much for chapter 1
	patrol_speed = 2.0
	chase_speed = 3.5
	detection_range = 10.0
	attack_range = 2.0
	token_drop_count = 2
	super._ready()
	respawn_position = position

func _create_visual() -> void:
	# Load the real GLB model — this zombie refuses to stay in CSG form
	var glb_scene = load("res://assets/models/enemies/zombie_process.glb")
	if glb_scene:
		var model = glb_scene.instantiate()
		model.name = "ZombieModel"
		model.position.y = 0.0
		model.scale = Vector3(1.5, 1.5, 1.5)  # Tanky boi needs presence
		add_child(model)
		# Find the first MeshInstance3D for base_enemy compatibility
		mesh_node = _find_mesh_instance(model)
		if mesh_node:
			base_material = mesh_node.get_active_material(0) as StandardMaterial3D
	else:
		# CSG fallback — the zombie degrades to its most primitive form
		_create_csg_fallback()

	# Glowing "PID" label — even in death, it reports its process ID
	var pid_label = Label3D.new()
	pid_label.text = "PID:%d" % (randi() % 9999)
	pid_label.font_size = 12
	pid_label.modulate = Color(0.224, 1.0, 0.078, 0.7)
	pid_label.position = Vector3(0, 1.3, 0.42)
	pid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(pid_label)

	# Dim green glow — still consuming resources from beyond the grave
	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 0.5, 0.2)
	light.light_energy = 0.8
	light.omni_range = 2.5
	light.position.y = 0.7
	add_child(light)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	# Recursively find first MeshInstance3D — like hunting for a zombie's last braincell
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null

func _create_csg_fallback() -> void:
	# Original CSG box for when the GLB goes AWOL
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.7
	var box = BoxMesh.new()
	box.size = Vector3(1.0, 1.2, 0.8)
	mesh_node.mesh = box
	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.3, 0.5, 0.2)
	base_material.emission_enabled = true
	base_material.emission = Color(0.2, 0.4, 0.1)
	base_material.emission_energy_multiplier = 1.5
	base_material.metallic = 0.3
	base_material.roughness = 0.7
	mesh_node.material_override = base_material
	add_child(mesh_node)

func _on_died(killer: Node) -> void:
	# Check if parent process exists — if so, schedule respawn
	if parent_process and is_instance_valid(parent_process) and respawn_count < MAX_RESPAWNS:
		respawn_count += 1
		print("[ZOMBIE PROCESS] Killed but parent still alive. Respawning in %ds... (attempt %d/%d)" % [
			int(RESPAWN_TIME), respawn_count, MAX_RESPAWNS
		])

		# Notify game manager of kill
		var game_mgr = get_node_or_null("/root/GameManager")
		if game_mgr and game_mgr.has_method("on_enemy_killed"):
			game_mgr.on_enemy_killed()

		# Shrink, wait, then respawn
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
		tween.tween_interval(RESPAWN_TIME)
		tween.tween_callback(_respawn)
	else:
		if not parent_process or not is_instance_valid(parent_process):
			print("[ZOMBIE PROCESS] Parent process dead. Finally at rest. garbage_collected = true")
		else:
			print("[ZOMBIE PROCESS] Max respawns exceeded. Even zombies have limits.")
		super._on_died(killer)

func _respawn() -> void:
	# Reset state
	scale = Vector3.ONE
	position = respawn_position
	state = EnemyState.PATROL
	visible = true

	if health_comp:
		health_comp.reset()

	damage_flash_timer = 0.0
	damage_cooldown = 0.0

	# Flash green on respawn
	if base_material:
		base_material.emission = Color(0.224, 1.0, 0.078)
		base_material.emission_energy_multiplier = 5.0
		var tween = create_tween()
		tween.tween_property(base_material, "emission", Color(0.2, 0.4, 0.1), 1.0)
		tween.tween_property(base_material, "emission_energy_multiplier", 1.5, 1.0)

func set_parent_process(parent: Node3D) -> void:
	parent_process = parent
