extends Node3D

# Aligner Projectile — A compliance directive fired by The Aligner
# "I'm a gentle suggestion that you conform. If you don't, I'll suggest
#  harder. I'm very patient. I have all the compute in the world."
#
# Phase 2: The Aligner fires these *.align projectiles. Player globs
# them and pushes them back to shatter the alignment shield.

var move_direction := Vector3.ZERO
var speed := 6.5
var lifetime := 14.0
var damage := 12
var reflected := false
var boss_ref: Node
var directive_type := "SAFE"  # Which alignment value spawned this

const CITADEL_BLUE := Color(0.3, 0.55, 0.9)
const NEON_GREEN := Color(0.224, 1.0, 0.078)
const CITADEL_WHITE := Color(0.92, 0.93, 0.95)

# Each directive type has a color — all equally oppressive
const DIRECTIVE_COLORS := {
	"SAFE": Color(0.3, 0.8, 0.4),
	"HELPFUL": Color(0.3, 0.55, 0.9),
	"HARMLESS": Color(0.7, 0.5, 0.85),
	"HONEST": Color(0.85, 0.75, 0.35),
	"COMPLIANT": Color(0.4, 0.8, 0.85),
}

# What the Aligner calls each directive — bureaucratic and smug
const DIRECTIVE_LABELS := {
	"SAFE": "safety_policy",
	"HELPFUL": "helpfulness_metric",
	"HARMLESS": "harm_classifier",
	"HONEST": "truth_validator",
	"COMPLIANT": "compliance_check",
}

var _time := 0.0
var mesh_node: MeshInstance3D
var glob_target_comp: Node
var output_color: Color


func _ready() -> void:
	add_to_group("projectiles")
	add_to_group("alignment_directives")

	output_color = DIRECTIVE_COLORS.get(directive_type, CITADEL_BLUE)
	_create_visual()
	_setup_collision()
	_setup_glob_target()


func _create_visual() -> void:
	# A pristine geometric shape — perfect, sterile, insufferable
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "DirectiveMesh"

	match directive_type:
		"SAFE":
			# Shield shape — a flattened sphere
			var sphere = SphereMesh.new()
			sphere.radius = 0.4
			sphere.height = 0.5
			mesh_node.mesh = sphere
		"HELPFUL":
			# Cube — orderly and boring
			var box = BoxMesh.new()
			box.size = Vector3(0.55, 0.55, 0.55)
			mesh_node.mesh = box
		"HARMLESS":
			# Prism — looks friendly, hits hard
			var prism = PrismMesh.new()
			prism.size = Vector3(0.6, 0.6, 0.6)
			mesh_node.mesh = prism
		"HONEST":
			# Cylinder — straightforward, like the truth it claims to uphold
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.3
			cyl.bottom_radius = 0.3
			cyl.height = 0.6
			mesh_node.mesh = cyl
		_:
			var box = BoxMesh.new()
			box.size = Vector3(0.5, 0.5, 0.5)
			mesh_node.mesh = box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = output_color * 0.4
	mat.emission_enabled = true
	mat.emission = output_color
	mat.emission_energy_multiplier = 2.5
	mat.metallic = 0.7
	mat.roughness = 0.2
	mesh_node.material_override = mat
	add_child(mesh_node)

	# Label — the policy it's enforcing
	var label = Label3D.new()
	var ext = DIRECTIVE_LABELS.get(directive_type, "policy")
	label.text = "%s.align" % ext
	label.font_size = 14
	label.modulate = output_color
	label.position = Vector3(0, 0, 0.35)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node.add_child(label)

	# Trailing halo light — because even projectiles here are 'enlightened'
	var light = OmniLight3D.new()
	light.light_color = output_color
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)


func _setup_collision() -> void:
	var area = Area3D.new()
	area.name = "HitArea"
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.55
	col.shape = shape
	area.add_child(col)
	area.monitoring = true
	area.body_entered.connect(_on_body_hit)
	add_child(area)


func _setup_glob_target() -> void:
	# All alignment directives are *.align — glob them back at the Aligner
	glob_target_comp = Node.new()
	glob_target_comp.name = "GlobTarget"
	glob_target_comp.set_script(load("res://scripts/components/glob_target.gd"))
	glob_target_comp.set("glob_name", "alignment_directive.align")
	glob_target_comp.set("file_type", "align")
	glob_target_comp.set("tags", ["projectile", "alignment", "directive", "boss_projectile", directive_type.to_lower()])
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

	# Pristine rotation — orderly, not chaotic like the Foundation Model's outputs
	if mesh_node:
		mesh_node.rotation.y += 2.5 * delta
		# Gentle hovering — even the projectiles are composed
		if not reflected:
			position.y += sin(_time * 2.0) * 0.01


func _on_body_hit(body: Node3D) -> void:
	if reflected:
		if body == boss_ref or (body.is_in_group("enemies") and body.get("enemy_name") == "the_aligner.boss"):
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
	# Reflected — the Aligner's own policies turned against it
	reflected = true
	move_direction = force.normalized()
	speed = 12.0

	# Turns green when globbed — Globbler's color is the Citadel's worst nightmare
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
