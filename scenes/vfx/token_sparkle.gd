extends Node3D

# Token pickup sparkle — green stars rising skyward like your context window after a good collect.
# One-shot, self-destructing. Fire and forget, like most LLM training runs.

func _ready() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "TokenSparkle"
	particles.emitting = true
	particles.amount = 16
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.85  # Burst mostly at once, with slight stagger for that twinkle feel
	particles.fixed_fps = 60

	# Stars float upward — ascending to a higher context window
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 45.0  # Conical upward burst, not a chaotic sphere
	pmat.initial_velocity_min = 1.5
	pmat.initial_velocity_max = 3.5
	pmat.gravity = Vector3(0, -1.0, 0)  # Gentle pullback so stars arc gracefully
	pmat.damping_min = 1.0
	pmat.damping_max = 2.0
	pmat.scale_min = 0.04
	pmat.scale_max = 0.1
	pmat.angular_velocity_min = -360.0
	pmat.angular_velocity_max = 360.0

	# Green-to-white color ramp — neon green core fading to ethereal white twinkle
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.22, 1.0, 0.08, 1.0))       # Neon green birth (#39FF14 ish)
	gradient.add_point(0.4, Color(0.6, 1.0, 0.5, 0.9))       # Bright green-white mid-life
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))          # White twinkle fade to nothing

	var color_tex := GradientTexture1D.new()
	color_tex.gradient = gradient
	pmat.color_ramp = color_tex

	# Emission origin — small sphere at pickup point
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.3

	particles.process_material = pmat

	# Star mesh — quad with billboard so it always faces the camera like a needy chatbot
	var star_mesh := QuadMesh.new()
	star_mesh.size = Vector2(0.12, 0.12)

	var star_mat := StandardMaterial3D.new()
	star_mat.albedo_color = Color(0.5, 1.0, 0.6)
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.22, 1.0, 0.08)  # That signature neon green
	star_mat.emission_energy_multiplier = 4.0
	star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star_mesh.material = star_mat

	particles.draw_pass_1 = star_mesh
	add_child(particles)

	# Self-destruct after the show is over — no lingering like a cached hallucination
	var timer := get_tree().create_timer(particles.lifetime + 0.2)
	timer.timeout.connect(queue_free)
