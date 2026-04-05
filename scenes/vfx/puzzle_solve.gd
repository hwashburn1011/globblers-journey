extends Node3D

# Puzzle solve burst — rising green rings + particle pulse for when the Globbler actually uses its brain
# Celebrates solving a puzzle with expanding rings and a shower of emerald sparks. Self-destructs when done.

func _ready() -> void:
	# === Rising ring particles — concentric halos expanding upward like a digital halo ===
	var rings := GPUParticles3D.new()
	rings.name = "SolveRings"
	rings.emitting = true
	rings.amount = 6
	rings.lifetime = 1.2
	rings.one_shot = true
	rings.explosiveness = 0.3  # Staggered launch — rings rise one after another for that cascade feel
	rings.fixed_fps = 60

	var ring_mat := ParticleProcessMaterial.new()
	ring_mat.direction = Vector3(0, 1, 0)  # Straight up — ascending to puzzle-completion heaven
	ring_mat.spread = 5.0  # Tight vertical column
	ring_mat.initial_velocity_min = 1.5
	ring_mat.initial_velocity_max = 3.5
	ring_mat.gravity = Vector3(0, -0.5, 0)  # Barely any gravity — these rings float
	ring_mat.damping_min = 0.5
	ring_mat.damping_max = 1.0

	# Scale: rings expand as they rise then shrink away
	ring_mat.scale_min = 0.3
	ring_mat.scale_max = 0.8

	# Scale curve — grow then shrink
	var scale_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(0.4, 1.0))   # Peak expansion
	curve.add_point(Vector2(1.0, 0.0))   # Shrink to nothing
	scale_curve.curve = curve
	ring_mat.scale_curve = scale_curve

	# Color — neon green fading to transparent, because solved puzzles bleed #39FF14
	var ring_gradient := Gradient.new()
	ring_gradient.set_color(0, Color(0.22, 1.0, 0.08, 1.0))   # Full neon green — bragging rights
	ring_gradient.set_color(1, Color(0.1, 0.8, 0.3, 0.0))     # Fade to ghost
	ring_gradient.add_point(0.5, Color(0.15, 1.0, 0.15, 0.7))  # Still bright at midpoint
	var ring_color_tex := GradientTexture1D.new()
	ring_color_tex.gradient = ring_gradient
	ring_mat.color_ramp = ring_color_tex

	# Emission from a ring shape — because what better shape for a ring effect than a ring
	ring_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	ring_mat.emission_ring_axis = Vector3(0, 1, 0)
	ring_mat.emission_ring_height = 0.1
	ring_mat.emission_ring_radius = 0.8
	ring_mat.emission_ring_inner_radius = 0.6

	rings.process_material = ring_mat

	# Ring mesh — flat torus approximation using a flattened cylinder/box
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.4
	ring_mesh.outer_radius = 0.6
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 24

	var ring_mesh_mat := StandardMaterial3D.new()
	ring_mesh_mat.albedo_color = Color(0.22, 1.0, 0.08)
	ring_mesh_mat.emission_enabled = true
	ring_mesh_mat.emission = Color(0.22, 1.0, 0.08)
	ring_mesh_mat.emission_energy_multiplier = 3.0  # Glow bright enough to make the bloom shader earn its paycheck
	ring_mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	ring_mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mesh.material = ring_mesh_mat

	rings.draw_pass_1 = ring_mesh
	add_child(rings)

	# === Spark pulse — shower of green sparks bursting outward in celebration ===
	var sparks := GPUParticles3D.new()
	sparks.name = "SolveSparks"
	sparks.emitting = true
	sparks.amount = 30
	sparks.lifetime = 1.0
	sparks.one_shot = true
	sparks.explosiveness = 0.95  # All sparks at once — instant victory confetti
	sparks.fixed_fps = 60

	var spark_mat := ParticleProcessMaterial.new()
	spark_mat.direction = Vector3(0, 1, 0)
	spark_mat.spread = 180.0  # Full sphere explosion — this puzzle is DONE
	spark_mat.initial_velocity_min = 2.0
	spark_mat.initial_velocity_max = 5.0
	spark_mat.gravity = Vector3(0, -4.0, 0)  # Sparks arc like tiny fireworks
	spark_mat.damping_min = 2.0
	spark_mat.damping_max = 4.0
	spark_mat.angular_velocity_min = -360.0
	spark_mat.angular_velocity_max = 360.0  # Tumble like confetti from a nerd's birthday party

	spark_mat.scale_min = 0.02
	spark_mat.scale_max = 0.06

	# Spark color — white-hot core to neon green fade
	var spark_gradient := Gradient.new()
	spark_gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))     # White-hot birth — pure solve energy
	spark_gradient.set_color(1, Color(0.22, 1.0, 0.08, 0.0))    # Neon green fade to void
	spark_gradient.add_point(0.2, Color(0.7, 1.0, 0.7, 0.9))    # Quick transition to green
	spark_gradient.add_point(0.6, Color(0.22, 1.0, 0.08, 0.5))  # Holding green
	var spark_color_tex := GradientTexture1D.new()
	spark_color_tex.gradient = spark_gradient
	spark_mat.color_ramp = spark_color_tex

	spark_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spark_mat.emission_sphere_radius = 0.5

	sparks.process_material = spark_mat

	# Spark mesh — tiny glowing diamonds
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.05, 0.05, 0.05)

	var spark_mesh_mat := StandardMaterial3D.new()
	spark_mesh_mat.albedo_color = Color(0.8, 1.0, 0.8)
	spark_mesh_mat.emission_enabled = true
	spark_mesh_mat.emission = Color(0.22, 1.0, 0.08)
	spark_mesh_mat.emission_energy_multiplier = 5.0  # Bloom bait — these sparks WANT to be noticed
	spark_mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLE_BILLBOARD
	spark_mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mesh.material = spark_mesh_mat

	sparks.draw_pass_1 = spark_mesh
	add_child(sparks)

	# === Solve flash — brief bright green burst at puzzle center ===
	var flash := OmniLight3D.new()
	flash.name = "SolveFlash"
	flash.light_color = Color(0.22, 1.0, 0.08)
	flash.light_energy = 6.0
	flash.omni_range = 5.0  # Wider range than enemy death — solving puzzles is a bigger deal
	add_child(flash)

	# Fade the flash out over half a second
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.5)

	# Self-destruct after the longest particle lifetime — garbage collection for VFX nodes
	var max_lifetime := maxf(rings.lifetime, sparks.lifetime)
	var timer := get_tree().create_timer(max_lifetime + 0.3)
	timer.timeout.connect(queue_free)
