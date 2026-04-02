extends Area3D

# Glob Projectile - The Globbler's signature attack
# "glob *.enemies --delete --recursive --no-mercy"

const SPEED = 30.0
const MAX_DISTANCE = 50.0
const DAMAGE = 1

var direction := Vector3.FORWARD
var distance_traveled := 0.0

func _ready() -> void:
	# Collision shape
	var col = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.25
	col.shape = sphere_shape
	add_child(col)

	# Glowing green sphere mesh
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "GlobMesh"
	var sphere = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	mesh_inst.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 0.3)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.9
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# Omni light for glow effect
	var light = OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.3)
	light.light_energy = 2.0
	light.omni_range = 3.0
	light.omni_attenuation = 2.0
	add_child(light)

	# Trail particles
	var trail = GPUParticles3D.new()
	trail.name = "TrailParticles"
	trail.amount = 16
	trail.lifetime = 0.3
	trail.explosiveness = 0.0

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0, 0)
	pmat.spread = 180.0
	pmat.initial_velocity_min = 0.5
	pmat.initial_velocity_max = 1.5
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.02
	pmat.scale_max = 0.08
	pmat.color = Color(0.3, 1.0, 0.5, 0.7)
	trail.process_material = pmat

	var trail_mesh = SphereMesh.new()
	trail_mesh.radius = 0.04
	trail_mesh.height = 0.08
	trail.draw_pass_1 = trail_mesh
	add_child(trail)

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	monitoring = true

func _physics_process(delta: float) -> void:
	var move = direction * SPEED * delta
	global_position += move
	distance_traveled += move.length()

	if distance_traveled >= MAX_DISTANCE:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		return
	if body.has_method("take_glob_hit"):
		body.take_glob_hit(DAMAGE)
	_impact()

func _on_area_entered(area: Area3D) -> void:
	if area.has_method("take_glob_hit"):
		area.take_glob_hit(DAMAGE)
		_impact()

func _impact() -> void:
	# Could spawn impact particles here
	queue_free()
