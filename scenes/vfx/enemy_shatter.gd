extends Node3D

# Enemy death shatter — polygon shard explosion for when a rogue process gets terminated with extreme prejudice
# Spawns 20 angular shards that burst outward, spin, and fade to nothing. Self-destructs when done.

func _ready() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ShardBurst"
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 0.9  # Almost all shards launch at once — instant satisfying pop
	particles.fixed_fps = 60

	# Shard movement — violent radial burst with gravity pulling debris down
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 180.0  # Full sphere because exploding enemies have no chill
	pmat.initial_velocity_min = 3.0
	pmat.initial_velocity_max = 8.0
	pmat.gravity = Vector3(0, -12.0, 0)  # Shards arc downward like digital shrapnel
	pmat.damping_min = 1.0
	pmat.damping_max = 3.0
	pmat.angular_velocity_min = -540.0
	pmat.angular_velocity_max = 540.0  # Tumble wildly — these shards had a rough day

	# Scale: start chunky, shrink to nothing as they dissolve
	pmat.scale_min = 0.06
	pmat.scale_max = 0.15

	# Color ramp — hot red-orange core fading through neon green to transparent
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.4, 0.1, 1.0))       # Hot orange birth — the enemy's last scream
	gradient.set_color(1, Color(0.22, 1.0, 0.08, 0.0))      # Neon green fade to void
	gradient.add_point(0.3, Color(1.0, 0.2, 0.05, 0.9))     # Still angry red-orange
	gradient.add_point(0.6, Color(0.5, 1.0, 0.3, 0.5))      # Transitioning to green
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = gradient
	pmat.color_ramp = color_tex

	# Emission shape — small sphere at enemy center
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.3

	particles.process_material = pmat

	# Shard mesh — angular polygon fragments, not spheres (we're shattering, not bubbling)
	var shard_mesh := BoxMesh.new()
	shard_mesh.size = Vector3(0.15, 0.08, 0.12)  # Flat angular shards

	# Emissive material for that bloom-friendly glow
	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.9, 0.3, 0.1)
	shard_mat.emission_enabled = true
	shard_mat.emission = Color(1.0, 0.3, 0.05)
	shard_mat.emission_energy_multiplier = 4.0  # Bright enough to make bloom weep with joy
	shard_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_mesh.material = shard_mat

	particles.draw_pass_1 = shard_mesh
	add_child(particles)

	# Flash light — brief bright burst at death point for dramatic effect
	var flash := OmniLight3D.new()
	flash.name = "DeathFlash"
	flash.light_color = Color(1.0, 0.4, 0.1)
	flash.light_energy = 5.0
	flash.omni_range = 4.0
	add_child(flash)

	# Fade the flash light out quickly
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)

	# Self-destruct after particles finish — clean up after ourselves like responsible garbage collectors
	var timer := get_tree().create_timer(particles.lifetime + 0.2)
	timer.timeout.connect(queue_free)
