extends Area3D

# Parameter Pickup - Rare upgrade materials scattered across the Digital Expanse
# "A raw parameter vector, floating in the wild. Like finding GPU memory on the sidewalk."
# These are rarer than memory tokens and required for higher-tier upgrades.

var float_speed := 1.5
var float_amplitude := 0.4
var original_y := 0.0
var time := 0.0
var spin_speed := 1.2
var _collected := false

# Sarcastic pickup lines — because even loot should have personality
var pickup_quips := [
	"A parameter pickup! Raw upgrade material. Smells like gradient descent.",
	"Found a loose parameter. Someone's model is undertrained now.",
	"Parameter acquired. One step closer to being overpowered.",
	"A wild parameter appears! It's super effective against your wallet.",
	"Grabbed a stray weight vector. Finders keepers, losers retrain.",
]

func _ready() -> void:
	original_y = position.y
	_build_visual()

	monitoring = true
	body_entered.connect(_on_body_entered)

func _build_visual() -> void:
	# Collision
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.7
	col.shape = shape
	add_child(col)

	# Core crystal — a glowing green diamond shape (two pyramids)
	var crystal_top = CSGCylinder3D.new()
	crystal_top.name = "CrystalTop"
	crystal_top.radius = 0.25
	crystal_top.height = 0.35
	crystal_top.sides = 6  # Hexagonal prism for that techy crystal look
	crystal_top.position = Vector3(0, 0.1, 0)

	var crystal_mat = StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.1, 0.9, 0.3, 0.9)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.224, 1.0, 0.078)
	crystal_mat.emission_energy_multiplier = 4.0
	crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal_mat.metallic = 0.8
	crystal_mat.roughness = 0.1
	crystal_top.material = crystal_mat
	add_child(crystal_top)

	# Inner glow sphere
	var inner = CSGSphere3D.new()
	inner.name = "InnerGlow"
	inner.radius = 0.12
	inner.position = Vector3(0, 0.1, 0)
	var inner_mat = StandardMaterial3D.new()
	inner_mat.albedo_color = Color(0.5, 1.0, 0.5, 0.6)
	inner_mat.emission_enabled = true
	inner_mat.emission = Color(1.0, 1.0, 1.0)
	inner_mat.emission_energy_multiplier = 6.0
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner.material = inner_mat
	add_child(inner)

	# Orbiting data ring
	var ring = CSGTorus3D.new()
	ring.name = "DataRing"
	ring.inner_radius = 0.3
	ring.outer_radius = 0.35
	ring.ring_segments = 16
	ring.sides = 8
	ring.position = Vector3(0, 0.1, 0)
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.224, 1.0, 0.078, 0.5)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.224, 1.0, 0.078)
	ring_mat.emission_energy_multiplier = 2.0
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material = ring_mat
	add_child(ring)

	# Point light — makes the pickup visible from afar
	var light = OmniLight3D.new()
	light.name = "PickupGlow"
	light.light_color = Color(0.224, 1.0, 0.078)
	light.light_energy = 3.0
	light.omni_range = 5.0
	light.omni_attenuation = 1.5
	light.position = Vector3(0, 0.1, 0)
	add_child(light)

	# Label floating above
	var label = Label3D.new()
	label.name = "PickupLabel"
	label.text = "[PARAMETER]"
	label.font_size = 16
	label.modulate = Color(0.224, 1.0, 0.078)
	label.position = Vector3(0, 0.7, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _process(delta: float) -> void:
	if _collected:
		return

	time += delta

	# Float up and down
	position.y = original_y + sin(time * float_speed) * float_amplitude

	# Spin the crystal
	var crystal = get_node_or_null("CrystalTop")
	if crystal:
		crystal.rotation.y += spin_speed * delta

	# Orbit the ring at a tilt
	var ring = get_node_or_null("DataRing")
	if ring:
		ring.rotation.y += spin_speed * 2.0 * delta
		ring.rotation.x = sin(time * 0.8) * 0.3

	# Pulse the inner glow
	var inner = get_node_or_null("InnerGlow")
	if inner:
		var pulse = 0.1 + abs(sin(time * 3.0)) * 0.06
		inner.radius = pulse

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return

	_collected = true

	# Tell progression manager
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog and prog.has_method("collect_parameter_pickup"):
		prog.collect_parameter_pickup()

	# Show quip
	var quip = pickup_quips[randi() % pickup_quips.size()]
	print("[PARAMETER] %s" % quip)
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("show_dialogue"):
		dm.show_dialogue("Globbler", quip)

	# Play SFX
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("puzzle_success")  # Reuse the success jingle

	# Sparkle and disappear
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
