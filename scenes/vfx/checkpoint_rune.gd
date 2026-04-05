extends Node3D

# Checkpoint rune VFX — rotating green ring + vertical light beam.
# Starts dormant. Call activate() when the checkpoint is triggered.
# Persists in the scene (not one-shot) to mark the save point.

var _ring: MeshInstance3D
var _beam: MeshInstance3D
var _light: OmniLight3D
var _particles: GPUParticles3D
var _active := false
var _ring_rotation_speed := 1.2  # radians per second


func _ready() -> void:
	_build_ring()
	_build_beam()
	_build_light()
	_build_particles()
	# Start invisible — dormant until player triggers checkpoint
	_set_visibility(false)


func _process(delta: float) -> void:
	if not _active:
		return
	# Rotate the ring continuously
	if _ring:
		_ring.rotate_y(delta * _ring_rotation_speed)


func activate() -> void:
	if _active:
		return
	_active = true
	_set_visibility(true)

	# Animate in — scale up from zero + fade light energy
	if _ring:
		_ring.scale = Vector3.ZERO
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(_ring, "scale", Vector3.ONE, 0.6)

	if _beam:
		var beam_mat: StandardMaterial3D = _beam.material_override
		if beam_mat:
			beam_mat.albedo_color.a = 0.0
			var tween := create_tween()
			tween.tween_property(beam_mat, "albedo_color:a", 0.15, 0.8)

	if _light:
		_light.light_energy = 0.0
		var tween := create_tween()
		tween.tween_property(_light, "light_energy", 2.5, 0.5)

	if _particles:
		_particles.emitting = true

	# Check reduce_motion
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		_ring_rotation_speed = 0.0
		if _particles:
			_particles.emitting = false


func _set_visibility(vis: bool) -> void:
	if _ring:
		_ring.visible = vis
	if _beam:
		_beam.visible = vis
	if _light:
		_light.visible = vis
	if _particles:
		_particles.visible = vis


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "RuneRing"

	# Torus ring — use a TorusMesh
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 16
	_ring.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.6, 0.1, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.22, 1.0, 0.08)  # Neon green
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = mat

	# Position at ground level, lying flat
	_ring.position = Vector3(0, 0.05, 0)
	add_child(_ring)


func _build_beam() -> void:
	_beam = MeshInstance3D.new()
	_beam.name = "LightBeam"

	# Tall thin cylinder for the vertical light beam
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.4
	cyl.height = 5.0
	cyl.radial_segments = 12
	_beam.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 1.0, 0.08, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.22, 1.0, 0.08)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	_beam.material_override = mat

	# Beam rises from ground upward
	_beam.position = Vector3(0, 2.5, 0)
	add_child(_beam)


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "RuneLight"
	_light.light_color = Color(0.22, 1.0, 0.08)
	_light.light_energy = 2.5
	_light.omni_range = 4.0
	_light.omni_attenuation = 1.5
	_light.shadow_enabled = false
	_light.position = Vector3(0, 1.0, 0)
	add_child(_light)


func _build_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "RuneSparkles"
	_particles.emitting = false
	_particles.amount = 12
	_particles.lifetime = 2.0
	_particles.one_shot = false
	_particles.fixed_fps = 30

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 15.0
	pmat.initial_velocity_min = 0.5
	pmat.initial_velocity_max = 1.5
	pmat.gravity = Vector3(0, -0.3, 0)
	pmat.scale_min = 0.02
	pmat.scale_max = 0.06
	pmat.angular_velocity_min = -180.0
	pmat.angular_velocity_max = 180.0

	# Green fade gradient
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.22, 1.0, 0.08, 0.8))
	gradient.add_point(0.5, Color(0.4, 1.0, 0.3, 0.5))
	gradient.set_color(1, Color(0.22, 1.0, 0.08, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = gradient
	pmat.color_ramp = color_tex

	# Emit from ring area
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pmat.emission_ring_radius = 0.9
	pmat.emission_ring_inner_radius = 0.7
	pmat.emission_ring_height = 0.1
	pmat.emission_ring_axis = Vector3(0, 1, 0)

	_particles.process_material = pmat

	# Small glowing quad particles
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var qmat := StandardMaterial3D.new()
	qmat.albedo_color = Color(0.5, 1.0, 0.6)
	qmat.emission_enabled = true
	qmat.emission = Color(0.22, 1.0, 0.08)
	qmat.emission_energy_multiplier = 3.0
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = qmat
	_particles.draw_pass_1 = quad

	_particles.position = Vector3(0, 0.1, 0)
	add_child(_particles)
