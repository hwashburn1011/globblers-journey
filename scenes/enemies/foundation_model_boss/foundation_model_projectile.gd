extends Node3D

# Foundation Model Projectile — A half-baked AI output that can be globbed back
# "I'm a generated artifact. I might be text. I might be an image.
#  I might be a code snippet that doesn't compile. Nobody knows.
#  Including the model that made me."
#
# The Foundation Model fires these during Phase 2. Each one represents
# a failed capability output. Player globs them (*.fm) and pushes back.

var move_direction := Vector3.ZERO
var speed := 7.0
var lifetime := 12.0
var damage := 10
var reflected := false
var boss_ref: Node
var capability_type := "TEXT"  # Which capability spawned this garbage

const FOUNDATION_GOLD := Color(0.9, 0.75, 0.3)
const NEON_GREEN := Color(0.224, 1.0, 0.078)
const CORRUPT_RED := Color(0.8, 0.15, 0.1)

# Each capability has a different visual color — all equally terrible
const CAPABILITY_COLORS := {
	"TEXT": Color(0.8, 0.8, 0.3),
	"IMAGE": Color(0.6, 0.2, 0.7),
	"CODE": Color(0.2, 0.7, 0.3),
	"AUDIO": Color(0.3, 0.5, 0.8),
	"VIDEO": Color(0.8, 0.3, 0.2),
	"REASON": Color(0.9, 0.6, 0.1),
}

# What the model claims each output is — always wrong
const CAPABILITY_LABELS := {
	"TEXT": "txt",
	"IMAGE": "png",
	"CODE": "py",
	"AUDIO": "wav",
	"VIDEO": "mp4",
	"REASON": "log",
}

var _time := 0.0
var mesh_node: MeshInstance3D
var glob_target_comp: Node
var output_color: Color


func _ready() -> void:
	add_to_group("projectiles")
	add_to_group("foundation_outputs")

	output_color = CAPABILITY_COLORS.get(capability_type, FOUNDATION_GOLD)
	_create_visual()
	_setup_collision()
	_setup_glob_target()


func _create_visual() -> void:
	# A glitchy polyhedron — the shape of mediocre AI output
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "OutputMesh"

	# Each capability type gets a different shape — all ugly
	match capability_type:
		"TEXT":
			var box = BoxMesh.new()
			box.size = Vector3(0.7, 0.5, 0.3)
			mesh_node.mesh = box
		"IMAGE":
			var sphere = SphereMesh.new()
			sphere.radius = 0.45
			sphere.height = 0.9
			mesh_node.mesh = sphere
		"CODE":
			var box = BoxMesh.new()
			box.size = Vector3(0.5, 0.5, 0.5)
			mesh_node.mesh = box
		"AUDIO":
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.2
			cyl.bottom_radius = 0.4
			cyl.height = 0.7
			mesh_node.mesh = cyl
		"VIDEO":
			var box = BoxMesh.new()
			box.size = Vector3(0.8, 0.45, 0.15)
			mesh_node.mesh = box
		_:
			var prism = PrismMesh.new()
			prism.size = Vector3(0.6, 0.6, 0.6)
			mesh_node.mesh = prism

	var mat = StandardMaterial3D.new()
	mat.albedo_color = output_color * 0.3
	mat.emission_enabled = true
	mat.emission = output_color
	mat.emission_energy_multiplier = 2.5
	mat.metallic = 0.6
	mat.roughness = 0.35
	mesh_node.material_override = mat
	add_child(mesh_node)

	# Label showing what it claims to be
	var label = Label3D.new()
	var ext = CAPABILITY_LABELS.get(capability_type, "dat")
	label.text = "output.%s" % ext
	label.font_size = 16
	label.modulate = output_color
	label.position = Vector3(0, 0, 0.35)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node.add_child(label)

	# Trailing light
	var light = OmniLight3D.new()
	light.light_color = output_color
	light.light_energy = 1.5
	light.omni_range = 3.0
	add_child(light)


func _setup_collision() -> void:
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
	# All foundation outputs are *.fm — because it's a Foundation Model, geddit?
	glob_target_comp = Node.new()
	glob_target_comp.name = "GlobTarget"
	glob_target_comp.set_script(load("res://scripts/components/glob_target.gd"))
	var ext = CAPABILITY_LABELS.get(capability_type, "dat")
	glob_target_comp.set("glob_name", "foundation_output.fm")
	glob_target_comp.set("file_type", "fm")
	glob_target_comp.set("tags", ["projectile", "foundation", "output", "boss_projectile", capability_type.to_lower()])
	add_child(glob_target_comp)

	var glob_engine = get_node_or_null("/root/GlobEngine")
	if glob_engine and glob_engine.has_method("register_target"):
		glob_engine.register_target(glob_target_comp)


func _physics_process(delta: float) -> void:
	_time += delta
	lifetime -= delta

	if lifetime <= 0:
		_cleanup()
		return

	position += move_direction * speed * delta

	# Each type spins differently — chaos is on-brand
	if mesh_node:
		mesh_node.rotation.y += 4.0 * delta
		mesh_node.rotation.x += 2.5 * delta
		# Wobbly flight path — these outputs are unstable
		if not reflected:
			position.y += sin(_time * 3.0) * 0.02


func _on_body_hit(body: Node3D) -> void:
	if reflected:
		if body == boss_ref or (body.is_in_group("enemies") and body.get("enemy_name") == "foundation_model.boss"):
			if boss_ref and boss_ref.has_method("on_reflected_hit"):
				boss_ref.on_reflected_hit()
			_cleanup()
			return
	else:
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			_cleanup()
			return


func apply_glob_force(force: Vector3) -> void:
	# Reflected! The model's own garbage comes back to haunt it
	reflected = true
	move_direction = force.normalized()
	speed = 11.0

	# Turns green when globbed — proper Globbler branding
	if mesh_node and mesh_node.material_override:
		var mat = mesh_node.material_override as StandardMaterial3D
		mat.emission = NEON_GREEN
		mat.emission_energy_multiplier = 4.0

	for child in get_children():
		if child is OmniLight3D:
			child.light_color = NEON_GREEN


func _cleanup() -> void:
	var glob_engine = get_node_or_null("/root/GlobEngine")
	if glob_engine and glob_engine.has_method("unregister_target") and glob_target_comp:
		glob_engine.unregister_target(glob_target_comp)
	queue_free()
