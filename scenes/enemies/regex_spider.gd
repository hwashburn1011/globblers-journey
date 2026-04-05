extends "res://scenes/enemies/base_enemy.gd"

# Regex Spider - Moves erratically, shoots pattern traps that slow the player
# "I'm a regular expression with legs. Your worst nightmare, parsed literally."
# Behavior: erratic movement, fires web traps that create slow zones

const TRAP_COOLDOWN := 4.0
const TRAP_RANGE := 12.0
const TRAP_DURATION := 3.0
const ERRATIC_CHANGE_TIME := 0.8

var trap_timer := 0.0
var erratic_timer := 0.0
var erratic_direction := Vector3.ZERO

func _ready() -> void:
	enemy_name = "regex_spider.enemy"
	enemy_tags = ["hostile", "chapter1", "spider"]
	max_health = 2
	contact_damage = 8
	patrol_speed = 5.0
	chase_speed = 6.0
	detection_range = 12.0
	attack_range = TRAP_RANGE
	super._ready()

func _create_visual() -> void:
	# Load the real GLB model — no more CSG pretending to be a spider
	var glb_scene = load("res://assets/models/enemies/regex_spider.glb")
	if glb_scene:
		var model = glb_scene.instantiate()
		model.name = "SpiderModel"
		model.position.y = 0.0
		model.scale = Vector3(1.8, 1.8, 1.8)  # Scale up for game visibility
		add_child(model)
		# Find the first MeshInstance3D for base_enemy compatibility
		mesh_node = _find_mesh_instance(model)
		if mesh_node:
			base_material = mesh_node.get_active_material(0) as StandardMaterial3D
	else:
		# CSG fallback — the spider regresses to its primitive form
		_create_csg_fallback()

	# Purple glow light — because spiders that don't glow aren't trying hard enough
	var light = OmniLight3D.new()
	light.light_color = Color(0.5, 0.1, 0.5)
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.position.y = 0.3
	add_child(light)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	# Recursively find first MeshInstance3D child
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null

func _create_csg_fallback() -> void:
	# Original CSG spider for when the GLB decides to go missing
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.4
	var spider_body = SphereMesh.new()
	spider_body.radius = 0.4
	spider_body.height = 0.5
	mesh_node.mesh = spider_body
	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.6, 0.1, 0.6)
	base_material.emission_enabled = true
	base_material.emission = Color(0.5, 0.05, 0.5)
	base_material.emission_energy_multiplier = 2.5
	base_material.metallic = 0.4
	base_material.roughness = 0.5
	mesh_node.material_override = base_material
	add_child(mesh_node)

func _state_patrol(delta: float) -> void:
	# Erratic movement — change direction randomly
	erratic_timer -= delta
	if erratic_timer <= 0:
		erratic_timer = ERRATIC_CHANGE_TIME
		erratic_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()

	if _can_see_player():
		_change_state(EnemyState.ALERT)
		return

	velocity.x = erratic_direction.x * patrol_speed
	velocity.z = erratic_direction.z * patrol_speed

func _state_chase(delta: float) -> void:
	if not player_ref:
		_change_state(EnemyState.PATROL)
		return

	var dist = global_position.distance_to(player_ref.global_position)
	if dist > detection_range * 1.5:
		_change_state(EnemyState.PATROL)
		return

	# Erratic chase — zigzag toward player
	erratic_timer -= delta
	if erratic_timer <= 0:
		erratic_timer = ERRATIC_CHANGE_TIME * 0.5
		erratic_direction = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))

	var dir = (player_ref.global_position - global_position)
	dir.y = 0
	dir = (dir.normalized() + erratic_direction * 0.4).normalized()
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed

	# Fire traps
	trap_timer -= delta
	if trap_timer <= 0 and dist < TRAP_RANGE:
		_fire_trap()
		trap_timer = TRAP_COOLDOWN

func _perform_attack() -> void:
	_fire_trap()

func _fire_trap() -> void:
	if not player_ref:
		return
	# Create a slow-zone trap at player's predicted position
	var trap = Area3D.new()
	trap.name = "RegexTrap"

	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 1.5
	shape.height = 0.5
	col.shape = shape
	trap.add_child(col)

	# Visual — purple web circle on ground
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 1.5
	cyl.bottom_radius = 1.5
	cyl.height = 0.05
	mesh.mesh = cyl

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.1, 0.5, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.05, 0.4)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	trap.add_child(mesh)

	# Place at player position
	trap.global_position = player_ref.global_position
	trap.global_position.y = global_position.y - 0.5
	trap.monitoring = true

	# Slow players who enter
	trap.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and "velocity" in body:
			# Slow effect — reduce speed temporarily
			body.velocity *= 0.3
	)

	get_tree().current_scene.add_child(trap)

	# Auto-destroy after duration
	get_tree().create_timer(TRAP_DURATION).timeout.connect(func():
		if is_instance_valid(trap):
			var fade_tween = trap.create_tween()
			fade_tween.tween_property(mesh, "transparency", 1.0, 0.5)
			fade_tween.tween_callback(trap.queue_free)
	)
