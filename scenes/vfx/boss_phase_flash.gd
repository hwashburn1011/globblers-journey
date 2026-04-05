extends Node3D

# Boss phase transition flash — screen-space color flash + expanding shockwave ring
# Because nothing says "I'm getting angrier" like a blinding light and an energy explosion.
# Spawned at boss position on phase change. Self-destructs after the dramatic moment passes.

func _ready() -> void:
	# === Shockwave ring — expanding torus that blasts outward from the boss ===
	var shockwave := GPUParticles3D.new()
	shockwave.name = "ShockwaveRing"
	shockwave.emitting = true
	shockwave.amount = 1  # One big ring, because subtlety is for Phase 1
	shockwave.lifetime = 0.8
	shockwave.one_shot = true
	shockwave.explosiveness = 1.0  # All at once — BOOM
	shockwave.fixed_fps = 60

	var wave_mat := ParticleProcessMaterial.new()
	wave_mat.direction = Vector3(0, 0, 0)  # No movement — the scale does the expanding
	wave_mat.spread = 0.0
	wave_mat.initial_velocity_min = 0.0
	wave_mat.initial_velocity_max = 0.0
	wave_mat.gravity = Vector3.ZERO

	# Scale curve — start small, expand rapidly, then disappear like your confidence in Phase 3
	wave_mat.scale_min = 0.1
	wave_mat.scale_max = 0.1
	var scale_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.05))
	curve.add_point(Vector2(0.3, 0.8))   # Rapid expansion
	curve.add_point(Vector2(0.6, 1.0))   # Full size
	curve.add_point(Vector2(1.0, 0.0))   # Gone
	scale_curve.curve = curve
	wave_mat.scale_curve = scale_curve

	# Color — white-hot flash to neon green to transparent
	var wave_gradient := Gradient.new()
	wave_gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.9))     # Blinding white — your retinas send their regards
	wave_gradient.add_point(0.3, Color(0.22, 1.0, 0.08, 0.8))  # Quick snap to neon green
	wave_gradient.set_color(1, Color(0.1, 0.6, 0.05, 0.0))     # Fade to nothing
	var wave_color_tex := GradientTexture1D.new()
	wave_color_tex.gradient = wave_gradient
	wave_mat.color_ramp = wave_color_tex

	shockwave.process_material = wave_mat

	# Shockwave mesh — flat torus that looks like an energy ring expanding outward
	var wave_mesh := TorusMesh.new()
	wave_mesh.inner_radius = 3.5
	wave_mesh.outer_radius = 4.0
	wave_mesh.rings = 24
	wave_mesh.ring_segments = 32

	var wave_mesh_mat := StandardMaterial3D.new()
	wave_mesh_mat.albedo_color = Color(0.22, 1.0, 0.08, 0.8)
	wave_mesh_mat.emission_enabled = true
	wave_mesh_mat.emission = Color(0.22, 1.0, 0.08)
	wave_mesh_mat.emission_energy_multiplier = 5.0  # Max bloom — this ring wants to be SEEN
	wave_mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED  # Stays flat on the ground plane
	wave_mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave_mesh_mat.no_depth_test = true  # Renders on top of everything — cheating, but it looks great
	wave_mesh.material = wave_mesh_mat

	shockwave.draw_pass_1 = wave_mesh
	add_child(shockwave)

	# === Radial spark burst — debris particles flying outward from the phase transition ===
	var sparks := GPUParticles3D.new()
	sparks.name = "PhaseTransitionSparks"
	sparks.emitting = true
	sparks.amount = 40  # Generous spark count — boss phase changes deserve spectacle
	sparks.lifetime = 1.2
	sparks.one_shot = true
	sparks.explosiveness = 0.9  # Near-instant burst with slight stagger for organic feel
	sparks.fixed_fps = 60

	var spark_mat := ParticleProcessMaterial.new()
	spark_mat.direction = Vector3(0, 0.5, 0)  # Slight upward bias
	spark_mat.spread = 180.0  # Full sphere — phase transitions explode in all directions
	spark_mat.initial_velocity_min = 3.0
	spark_mat.initial_velocity_max = 7.0  # Fast — these sparks have places to be
	spark_mat.gravity = Vector3(0, -3.0, 0)  # Arc back down eventually
	spark_mat.damping_min = 1.0
	spark_mat.damping_max = 3.0
	spark_mat.angular_velocity_min = -540.0
	spark_mat.angular_velocity_max = 540.0  # Spinning wildly — pure chaos energy

	spark_mat.scale_min = 0.03
	spark_mat.scale_max = 0.08

	# Spark color — white core to green to red-orange warning flash
	var spark_gradient := Gradient.new()
	spark_gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))      # White-hot — fresh from the boss's fury
	spark_gradient.add_point(0.15, Color(0.8, 1.0, 0.3, 0.95))   # Warm green — transitional rage
	spark_gradient.add_point(0.5, Color(0.22, 1.0, 0.08, 0.7))   # Neon green — on-brand
	spark_gradient.set_color(1, Color(1.0, 0.3, 0.05, 0.0))      # Angry red-orange fade — next phase is worse
	var spark_color_tex := GradientTexture1D.new()
	spark_color_tex.gradient = spark_gradient
	spark_mat.color_ramp = spark_color_tex

	spark_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spark_mat.emission_sphere_radius = 0.8

	sparks.process_material = spark_mat

	# Spark mesh — tiny glowing rectangles tumbling through space
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.08, 0.03, 0.03)  # Elongated for that streak look

	var spark_mesh_mat := StandardMaterial3D.new()
	spark_mesh_mat.albedo_color = Color(0.9, 1.0, 0.9)
	spark_mesh_mat.emission_enabled = true
	spark_mesh_mat.emission = Color(0.22, 1.0, 0.08)
	spark_mesh_mat.emission_energy_multiplier = 4.0
	spark_mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLE_BILLBOARD
	spark_mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mesh.material = spark_mesh_mat

	sparks.draw_pass_1 = spark_mesh
	add_child(sparks)

	# === Screen-space flash — a massive point light that simulates screen whiteout ===
	var flash := OmniLight3D.new()
	flash.name = "PhaseFlash"
	flash.light_color = Color(0.22, 1.0, 0.08)  # Green flash — boss fights are always on-brand
	flash.light_energy = 12.0  # Ridiculously bright — temporarily blinds the player (narratively, not literally)
	flash.omni_range = 15.0  # Covers the whole arena — nowhere to hide from the drama
	flash.omni_attenuation = 0.5
	add_child(flash)

	# Two-stage flash: hold bright briefly, then rapid fade — like a camera flash of doom
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 8.0, 0.1)  # Brief hold at near-max
	tween.tween_property(flash, "light_energy", 0.0, 0.6)   # Fade to darkness

	# === Secondary warm flash for color contrast — brief orange accent ===
	var accent_flash := OmniLight3D.new()
	accent_flash.name = "AccentFlash"
	accent_flash.light_color = Color(1.0, 0.5, 0.1)  # Warning orange — "things are about to get worse"
	accent_flash.light_energy = 6.0
	accent_flash.omni_range = 10.0
	accent_flash.omni_attenuation = 1.0
	accent_flash.position = Vector3(0, 2.0, 0)  # Slightly above for overhead drama lighting
	add_child(accent_flash)

	var accent_tween := create_tween()
	accent_tween.tween_property(accent_flash, "light_energy", 0.0, 0.4)  # Fast fade — it's just an accent

	# Self-destruct after the longest effect finishes — don't litter the scene tree
	var max_lifetime := maxf(shockwave.lifetime, sparks.lifetime)
	var timer := get_tree().create_timer(max_lifetime + 0.5)
	timer.timeout.connect(queue_free)
