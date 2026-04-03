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
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.4

	# Spider body — flattened sphere
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

	# Spider legs — 4 pairs of thin cylinders
	var leg_mat = StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.4, 0.1, 0.4)
	leg_mat.emission_enabled = true
	leg_mat.emission = Color(0.3, 0.05, 0.3)
	leg_mat.emission_energy_multiplier = 1.5

	for i in range(4):
		for side in [-1, 1]:
			var leg = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.radius = 0.02
			cyl.height = 0.5
			leg.mesh = cyl
			var angle = deg_to_rad(-30 + i * 20)
			leg.position = Vector3(side * 0.3, 0.2, -0.2 + i * 0.13)
			leg.rotation.z = side * deg_to_rad(45)
			leg.rotation.x = angle
			leg.material_override = leg_mat
			mesh_node.add_child(leg)

	# Eyes — multiple small glowing spheres
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.224, 1.0, 0.078)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.224, 1.0, 0.078)
	eye_mat.emission_energy_multiplier = 5.0

	for i in range(4):
		var eye = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.04
		eye.mesh = sphere
		eye.position = Vector3(-0.1 + i * 0.07, 0.35, 0.3)
		eye.material_override = eye_mat
		mesh_node.add_child(eye)

	# Glow light
	var light = OmniLight3D.new()
	light.light_color = Color(0.5, 0.1, 0.5)
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.position.y = 0.5
	add_child(light)

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
