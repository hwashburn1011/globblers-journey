extends BaseEnemy

# Hallucination Merchant — The Bazaar's most dishonest salesman
# "Everything I sell is real! The fact that it disappears when you look
#  too closely is a feature, not a bug."
#
# Mechanic: Creates illusory clones of itself that look identical but deal
# no damage and die in one hit. The real one teleports when hit. Some of
# its attacks are purely visual — you never know which ones actually hurt.
# Visual: Shimmering merchant with shifting magenta/gold colors, multiple
# ghostly faces, and a merchant's cloak.

# -- Clone System --
const MAX_CLONES := 2
const CLONE_SPAWN_COOLDOWN := 6.0
const CLONE_LIFETIME := 8.0
const CLONE_HP := 1  # One-hit kills

# -- Teleport --
const TELEPORT_RANGE := 8.0  # max distance for teleport
const TELEPORT_COOLDOWN := 3.5
const TELEPORT_ON_HIT_CHANCE := 0.7  # 70% chance to teleport when hit

# -- Fake Attack --
const FAKE_ATTACK_CHANCE := 0.4  # 40% of attacks are visual-only

# -- Real Attack --
const REAL_ATTACK_DAMAGE := 10
const HALLUCINATION_BOLT_SPEED := 8.0

var clone_timer := 0.0
var teleport_timer := 0.0
var active_clones: Array[Node3D] = []
var is_clone := false  # Set to true for spawned clones
var shimmer_offset := 0.0

# Visual nodes
var cloak_mesh: MeshInstance3D
var face_meshes: Array[MeshInstance3D] = []
var wares_mesh: MeshInstance3D
var shimmer_light: OmniLight3D
var merchant_label: Label3D

func _init() -> void:
	max_health = 3
	contact_damage = 8
	detection_range = 16.0
	attack_range = 10.0
	patrol_speed = 2.5
	chase_speed = 4.5
	stun_duration = 1.5
	attack_cooldown = 2.5
	token_drop_count = 3
	enemy_name = "hallucination_merchant.ai"
	enemy_tags = ["hostile", "chapter3", "merchant", "hallucination"]
	shimmer_offset = randf() * TAU  # Each instance shimmers differently


func _create_visual() -> void:
	# "Step right up! Every model guaranteed real!* (*guarantee not guaranteed)"
	var glb_scene = load("res://assets/models/enemies/hallucination_merchant.glb")
	if glb_scene:
		mesh_node = glb_scene.instantiate()
		mesh_node.name = "EnemyMesh"
		mesh_node.position.y = 0.0
		add_child(mesh_node)

		# Apply clone transparency if this is a fake merchant
		if is_clone:
			for child in mesh_node.get_children():
				if child is MeshInstance3D:
					var mat = child.get_active_material(0)
					if mat and mat is StandardMaterial3D:
						var clone_mat = mat.duplicate()
						clone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						clone_mat.albedo_color.a = 0.6
						child.material_override = clone_mat

		# Grab references to key child meshes for animation
		wares_mesh = mesh_node.get_node_or_null("WaresTray")
		face_meshes.clear()
		for i in range(3):
			var face = mesh_node.get_node_or_null("GhostFace_%d" % i)
			if face:
				face_meshes.append(face)

		# Base material for shimmer — grab from cloak body
		var cloak_node = mesh_node.get_node_or_null("CloakBody")
		if cloak_node and cloak_node is MeshInstance3D:
			base_material = cloak_node.get_active_material(0)
			if base_material:
				base_material = base_material.duplicate()
				cloak_node.material_override = base_material
	else:
		# CSG fallback — the budget version of deception
		mesh_node = MeshInstance3D.new()
		mesh_node.name = "EnemyMesh"
		mesh_node.position.y = 0.7
		var cloak = BoxMesh.new()
		cloak.size = Vector3(1.0, 1.5, 0.8)
		mesh_node.mesh = cloak
		base_material = StandardMaterial3D.new()
		base_material.albedo_color = Color(0.5, 0.1, 0.4)
		base_material.emission_enabled = true
		base_material.emission = Color(0.85, 0.15, 0.65)
		base_material.emission_energy_multiplier = 2.0
		if is_clone:
			base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			base_material.albedo_color.a = 0.6
		mesh_node.material_override = base_material
		add_child(mesh_node)

	# Label — because every con artist needs a sign
	merchant_label = Label3D.new()
	merchant_label.name = "MerchantLabel"
	merchant_label.text = "TOTALLY REAL MERCHANT" if not is_clone else "ALSO REAL MERCHANT"
	merchant_label.font_size = 9
	merchant_label.modulate = Color(0.85, 0.15, 0.65)
	merchant_label.position = Vector3(0, 2.2, 0)
	merchant_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(merchant_label)

	# Shimmer light — shifts between magenta and gold
	shimmer_light = OmniLight3D.new()
	shimmer_light.light_color = Color(0.85, 0.15, 0.65)
	shimmer_light.light_energy = 1.5 if not is_clone else 0.8
	shimmer_light.omni_range = 4.0
	shimmer_light.position.y = 0.7
	add_child(shimmer_light)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if state == EnemyState.DEATH:
		return

	var t = Time.get_ticks_msec() * 0.001 + shimmer_offset

	# Shimmer effect — color oscillation between magenta and gold
	if base_material:
		var shimmer = (sin(t * 2.0) + 1.0) * 0.5
		base_material.emission = Color(0.85, 0.15, 0.65).lerp(Color(0.95, 0.75, 0.2), shimmer)
		base_material.emission_energy_multiplier = 1.8 + sin(t * 3.0) * 0.5

	if shimmer_light:
		var shimmer = (sin(t * 2.0 + 0.5) + 1.0) * 0.5
		shimmer_light.light_color = Color(0.85, 0.15, 0.65).lerp(Color(0.95, 0.75, 0.2), shimmer)

	# Ghostly faces shift positions
	for i in range(face_meshes.size()):
		if is_instance_valid(face_meshes[i]):
			face_meshes[i].position.x = (i - 1) * 0.12 + sin(t * 1.5 + i * 2.0) * 0.06
			face_meshes[i].position.y = 0.15 + i * 0.05 + cos(t * 1.2 + i * 1.5) * 0.03

	# Wares bob gently — enticing the customer
	if wares_mesh:
		wares_mesh.position.y = sin(t * 1.8) * 0.05

	# Clone management
	clone_timer -= delta
	teleport_timer -= delta
	active_clones = active_clones.filter(func(c): return is_instance_valid(c))

	# Spawn clones when in combat and cooldown is ready (real merchant only)
	if not is_clone and state == EnemyState.CHASE and clone_timer <= 0 and active_clones.size() < MAX_CLONES:
		_spawn_clone()
		clone_timer = CLONE_SPAWN_COOLDOWN

	# Update label with clone count
	if merchant_label and not is_clone:
		if active_clones.size() > 0:
			merchant_label.text = "MERCHANTS: %d" % (active_clones.size() + 1)
		else:
			merchant_label.text = "TOTALLY REAL MERCHANT"


func _perform_attack() -> void:
	if not player_ref:
		return

	# Decide: real or fake attack?
	var is_fake = randf() < FAKE_ATTACK_CHANCE

	_fire_hallucination_bolt(is_fake)

	# Audio — plays either way so player can't tell
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_enemy_attack"):
		am.play_enemy_attack()


func _fire_hallucination_bolt(fake: bool) -> void:
	if not player_ref:
		return

	var bolt = Area3D.new()
	bolt.name = "HallucinationBolt"
	bolt.monitoring = true

	var bcol = CollisionShape3D.new()
	var bshape = SphereShape3D.new()
	bshape.radius = 0.3
	bcol.shape = bshape
	bolt.add_child(bcol)

	# Visual — all bolts look the same (that's the point)
	var bolt_vis = MeshInstance3D.new()
	var bolt_mesh = SphereMesh.new()
	bolt_mesh.radius = 0.15
	bolt_mesh.height = 0.3
	bolt_vis.mesh = bolt_mesh
	var bolt_mat = StandardMaterial3D.new()
	bolt_mat.albedo_color = Color(0.85, 0.15, 0.65, 0.8)
	bolt_mat.emission_enabled = true
	bolt_mat.emission = Color(0.9, 0.2, 0.7)
	bolt_mat.emission_energy_multiplier = 4.0
	bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt_vis.material_override = bolt_mat
	bolt.add_child(bolt_vis)

	var b_light = OmniLight3D.new()
	b_light.light_color = Color(0.85, 0.15, 0.65)
	b_light.light_energy = 1.5
	b_light.omni_range = 2.0
	bolt.add_child(b_light)

	bolt.global_position = global_position + Vector3(0, 1.0, 0)

	var target = player_ref.global_position + Vector3(0, 0.5, 0)
	var fire_dir = (target - bolt.global_position).normalized()

	if not fake:
		bolt.body_entered.connect(_on_bolt_hit.bind(bolt))

	get_tree().current_scene.call_deferred("add_child", bolt)

	var end_pos = bolt.global_position + fire_dir * HALLUCINATION_BOLT_SPEED * 2.5
	var tween = create_tween()
	tween.tween_property(bolt, "global_position", end_pos, 2.5)
	tween.tween_callback(bolt.queue_free)


func _on_bolt_hit(body: Node3D, bolt: Area3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(REAL_ATTACK_DAMAGE)
	if is_instance_valid(bolt):
		bolt.queue_free()


func _spawn_clone() -> void:
	# "Why have one me when you can have three? Quantity IS quality."
	var clone_node = CharacterBody3D.new()
	clone_node.name = "HallucinationClone_%d" % randi()

	# Give clone its own script instance
	var script = load("res://scenes/enemies/hallucination_merchant.gd")
	clone_node.set_script(script)
	clone_node.set("is_clone", true)
	clone_node.set("max_health", CLONE_HP)

	# Position randomly near the real merchant
	var angle = randf() * TAU
	var dist = 3.0 + randf() * 3.0
	var clone_pos = global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	clone_node.global_position = clone_pos

	# Give it patrol points near spawn
	clone_node.set("patrol_points", [
		clone_pos,
		clone_pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)),
		clone_pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)),
	])

	get_tree().current_scene.call_deferred("add_child", clone_node)
	active_clones.append(clone_node)

	# Auto-destroy clone after lifetime
	var lifetime_tween = create_tween()
	lifetime_tween.tween_interval(CLONE_LIFETIME)
	lifetime_tween.tween_callback(func():
		if is_instance_valid(clone_node):
			clone_node.queue_free()
	)

	# Quip about clones
	if randf() < 0.5:
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("show_dialogue"):
			var quips = [
				"Two-for-one special! Both equally real!",
				"Meet my business partner. Also me.",
				"Hallucinate responsibly. Or don't.",
			]
			dm.show_dialogue("Hallucination Merchant", quips[randi() % quips.size()])


func _on_damage_taken(amount: int, source: Node) -> void:
	super._on_damage_taken(amount, source)

	if is_clone:
		return  # Clones just die normally (1 HP)

	# Real merchant: chance to teleport on hit
	if teleport_timer <= 0 and randf() < TELEPORT_ON_HIT_CHANCE:
		_teleport_away()


func _teleport_away() -> void:
	teleport_timer = TELEPORT_COOLDOWN

	# Fade out
	if mesh_node:
		var tween = create_tween()
		tween.tween_property(mesh_node, "modulate:a", 0.0, 0.2)
		tween.tween_callback(_complete_teleport)
		tween.tween_property(mesh_node, "modulate:a", 1.0, 0.3)
	else:
		_complete_teleport()


func _complete_teleport() -> void:
	# Pick a new position away from player
	var angle = randf() * TAU
	var dist = TELEPORT_RANGE * 0.6 + randf() * TELEPORT_RANGE * 0.4
	var new_pos = global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)

	# Prefer positions behind the player if possible
	if player_ref:
		var behind = player_ref.global_position - (player_ref.global_position - global_position).normalized() * dist
		behind.y = global_position.y
		if randf() < 0.5:
			new_pos = behind

	global_position = new_pos

	# Taunt after teleporting
	if merchant_label:
		merchant_label.text = "OVER HERE!"
		var label_tween = create_tween()
		label_tween.tween_interval(1.5)
		label_tween.tween_callback(func():
			if is_instance_valid(merchant_label):
				merchant_label.text = "TOTALLY REAL MERCHANT"
		)


# Clones drop nothing — they were never real
func _drop_tokens() -> void:
	if is_clone:
		return  # "No refunds on hallucinated merchandise."
	super._drop_tokens()
