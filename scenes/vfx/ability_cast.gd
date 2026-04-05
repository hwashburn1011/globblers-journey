extends Node3D

# Ability cast VFX — a quick burst of colored sparks at the caster's hand.
# Fire-and-forget: spawns particles, self-destructs when done.
# Color is set by the caller to match each ability's theme.

const ABILITY_COLORS := {
	"glob": Color(0.22, 1.0, 0.08),    # #39FF14 neon green
	"wrench": Color(1.0, 1.0, 1.0),     # white-hot sparks
	"hack": Color(0.6, 0.2, 1.0),       # purple terminal glow
	"dash": Color(0.0, 0.9, 0.9),       # cyan streak
	"agent": Color(1.0, 0.55, 0.0),     # orange deployment flare
}

var ability_type: String = "glob"

func _ready() -> void:
	var color: Color = ABILITY_COLORS.get(ability_type, Color(0.22, 1.0, 0.08))

	var particles := GPUParticles3D.new()
	particles.name = "CastBurst"
	particles.emitting = true
	particles.amount = 15
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.fixed_fps = 60

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 120.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 5.0
	pmat.gravity = Vector3(0, -6.0, 0)
	pmat.damping_min = 3.0
	pmat.damping_max = 6.0
	pmat.scale_min = 0.02
	pmat.scale_max = 0.06

	# Color ramp: bright core -> ability color -> fade out
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.3, Color(color.r, color.g, color.b, 0.9))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = gradient
	pmat.color_ramp = color_tex

	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.1

	particles.process_material = pmat

	# Small sphere mesh for each particle
	var pmesh := SphereMesh.new()
	pmesh.radius = 0.03
	pmesh.height = 0.06

	var pmat3d := StandardMaterial3D.new()
	pmat3d.albedo_color = color
	pmat3d.emission_enabled = true
	pmat3d.emission = color
	pmat3d.emission_energy_multiplier = 4.0
	pmat3d.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pmat3d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmesh.material = pmat3d

	particles.draw_pass_1 = pmesh
	add_child(particles)

	# Self-destruct after particles finish
	var timer := get_tree().create_timer(particles.lifetime + 0.1)
	timer.timeout.connect(queue_free)
