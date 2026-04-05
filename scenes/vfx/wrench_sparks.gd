extends Node3D

# Wrench impact sparks — because nothing says "percussive maintenance" like a shower of green sparks
# Self-destructs after the particles finish. One-shot, fire-and-forget.

func _ready() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "SparkBurst"
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 0.95  # All sparks burst at once, like a real impact
	particles.fixed_fps = 60

	# Spark movement — radial burst from impact point
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 180.0  # Full sphere burst
	pmat.initial_velocity_min = 4.0
	pmat.initial_velocity_max = 10.0
	pmat.gravity = Vector3(0, -15.0, 0)  # Sparks arc downward — physics still applies even in cyberspace
	pmat.damping_min = 2.0
	pmat.damping_max = 5.0
	pmat.scale_min = 0.01
	pmat.scale_max = 0.04
	pmat.angular_velocity_min = -720.0
	pmat.angular_velocity_max = 720.0

	# Green-white color ramp — hot white core fading to neon green
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))       # White-hot birth
	gradient.set_color(1, Color(0.22, 1.0, 0.08, 0.0))      # Neon green fade to nothing
	gradient.add_point(0.3, Color(0.5, 1.0, 0.3, 0.9))      # Mid-life green-white
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = gradient
	pmat.color_ramp = color_tex

	# Emission — glow so the bloom pass picks these up
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.15

	particles.process_material = pmat

	# Spark mesh — elongated for that streaky spark look
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.02, 0.02, 0.08)

	# Emissive material so sparks actually glow
	var spark_mat := StandardMaterial3D.new()
	spark_mat.albedo_color = Color(0.8, 1.0, 0.6)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(0.22, 1.0, 0.08)  # #39FF14 adjacent
	spark_mat.emission_energy_multiplier = 3.0
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mesh.material = spark_mat

	particles.draw_pass_1 = spark_mesh
	add_child(particles)

	# Self-destruct after particles finish — no zombie nodes cluttering the scene tree
	var timer := get_tree().create_timer(particles.lifetime + 0.1)
	timer.timeout.connect(queue_free)
