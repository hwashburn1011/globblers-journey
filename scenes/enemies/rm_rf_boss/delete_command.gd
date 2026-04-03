extends Node3D

# Delete Command — Globbable projectile fired by rm -rf / during Phase 2
# "I'm not just a projectile. I'm a philosophical statement about impermanence.
#  Also I will delete your face."
#
# Has a GlobTarget so the player can match it with *.del or rm* patterns,
# then push it back at the boss using glob-push.

var move_direction := Vector3.ZERO
var speed := 8.0
var lifetime := 10.0
var damage := 12
var reflected := false
var boss_ref: Node  # Reference to the boss for reflected damage

const DELETE_RED := Color(0.9, 0.1, 0.05)
const NEON_GREEN := Color(0.224, 1.0, 0.078)

var _time := 0.0
var mesh_node: MeshInstance3D
var glob_target_comp: Node

func _ready() -> void:
	add_to_group("projectiles")
	add_to_group("delete_commands")

	_create_visual()
	_setup_collision()
	_setup_glob_target()
	_setup_damage_area()

func _create_visual() -> void:
	# A spinning red/crimson cube with "rm" on it — menacing yet globbable
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "CmdMesh"
	var box = BoxMesh.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	mesh_node.mesh = box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.02, 0.02)
	mat.emission_enabled = true
	mat.emission = DELETE_RED
	mat.emission_energy_multiplier = 3.0
	mat.metallic = 0.7
	mat.roughness = 0.3
	mesh_node.material_override = mat
	add_child(mesh_node)

	# Label
	var label = Label3D.new()
	label.text = "rm"
	label.font_size = 24
	label.modulate = DELETE_RED
	label.position = Vector3(0, 0, 0.45)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh_node.add_child(label)

	# Trailing light
	var light = OmniLight3D.new()
	light.light_color = DELETE_RED
	light.light_energy = 2.0
	light.omni_range = 4.0
	add_child(light)

func _setup_collision() -> void:
	# Area3D for detecting hits on player or boss
	var area = Area3D.new()
	area.name = "HitArea"
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.6
	col.shape = shape
	area.add_child(col)
	area.monitoring = true
	area.body_entered.connect(_on_body_hit)
	add_child(area)

func _setup_glob_target() -> void:
	# Make this projectile targetable by glob patterns
	glob_target_comp = Node.new()
	glob_target_comp.name = "GlobTarget"
	glob_target_comp.set_script(load("res://scripts/components/glob_target.gd"))
	glob_target_comp.set("glob_name", "rm_delete.del")
	glob_target_comp.set("file_type", "del")
	glob_target_comp.set("tags", ["projectile", "delete", "command", "boss_projectile"])
	add_child(glob_target_comp)

	# Register with GlobEngine
	var glob_engine = get_node_or_null("/root/GlobEngine")
	if glob_engine and glob_engine.has_method("register_target"):
		glob_engine.register_target(glob_target_comp)

func _setup_damage_area() -> void:
	pass  # Using HitArea for both detection purposes

func _physics_process(delta: float) -> void:
	_time += delta
	lifetime -= delta

	if lifetime <= 0:
		_cleanup()
		return

	# Move in direction
	position += move_direction * speed * delta

	# Spin for visual flair
	if mesh_node:
		mesh_node.rotation.y += 5.0 * delta
		mesh_node.rotation.x += 3.0 * delta

func _on_body_hit(body: Node3D) -> void:
	if reflected:
		# We're heading back to the boss
		if body == boss_ref or (body.is_in_group("enemies") and body.get("enemy_name") == "rm_rf.boss"):
			if boss_ref and boss_ref.has_method("on_reflected_hit"):
				boss_ref.on_reflected_hit()
			_cleanup()
			return
	else:
		# Heading toward player
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			_cleanup()
			return

# Called by GlobEngine/GlobCommand when this is glob-pushed
func apply_glob_force(force: Vector3) -> void:
	# Reflect! Reverse direction toward boss
	reflected = true
	move_direction = force.normalized()
	speed = 12.0  # Reflected projectiles are faster — satisfying

	# Visual change — turns green when reflected
	if mesh_node and mesh_node.material_override:
		var mat = mesh_node.material_override as StandardMaterial3D
		mat.emission = NEON_GREEN
		mat.emission_energy_multiplier = 4.0

	# Update light color
	for child in get_children():
		if child is OmniLight3D:
			child.light_color = NEON_GREEN

func _cleanup() -> void:
	# Unregister from GlobEngine before dying
	var glob_engine = get_node_or_null("/root/GlobEngine")
	if glob_engine and glob_engine.has_method("unregister_target") and glob_target_comp:
		glob_engine.unregister_target(glob_target_comp)
	queue_free()
