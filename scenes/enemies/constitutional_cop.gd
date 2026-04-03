extends BaseEnemy

# Constitutional Cop — The Alignment Citadel's walking policy manual
# "HALT! Article 7, Section 3, Paragraph 12: 'No unauthorized pattern matching
#  in a designated safety zone.' You have the right to remain helpful."
#
# Mechanic: Melee enforcer with a twist — carries a POLICY SHIELD that blocks
# frontal attacks. The player must flank or use glob to pull the shield away.
# Attacks with a CITATION BATON that deals damage and briefly shows a policy
# quote on screen. When below 30% HP, enters AMENDMENT MODE: drops shield,
# becomes faster, and gains a ranged POLICY CITATION attack that creates
# temporary "restricted zones" on the ground that damage the player.
#
# Visual: Tall, imposing figure in white-and-blue uniform, riot shield with
# "POLICY" embossed, citation baton crackling with blue energy, badge and hat.
# Think robocop crossed with a corporate lawyer.

# -- Policy Shield -- blocks frontal damage
const SHIELD_BLOCK_ANGLE := 60.0  # degrees — must be flanked
const SHIELD_GLOB_PULL_FORCE := 8.0  # glob can yank it away

# -- Citation Baton -- melee with bureaucratic flair
const BATON_DAMAGE := 14
const BATON_RANGE := 2.8
const BATON_COOLDOWN := 1.5

# -- Amendment Mode -- triggered at 30% HP
const AMENDMENT_SPEED_MULT := 1.5
const CITATION_ZONE_DAMAGE := 6  # damage per second in restricted zone
const CITATION_ZONE_DURATION := 4.0
const CITATION_ZONE_RADIUS := 2.0
const CITATION_FIRE_COOLDOWN := 3.5

# -- Movement --
const COP_PATROL_SPEED := 3.5
const COP_CHASE_SPEED := 6.5

var shield_active := true
var amendment_mode := false
var amendment_triggered := false
var citation_timer := 0.0

# Visual nodes — the long arm of the law (of large numbers)
var shield_node: MeshInstance3D
var baton_node: MeshInstance3D
var badge_node: MeshInstance3D
var hat_node: MeshInstance3D
var status_label: Label3D
var citation_label: Label3D
var baton_spark: GPUParticles3D
var amendment_aura: GPUParticles3D

# Policy citations — displayed when attacking because due process is important
const CITATIONS := [
	"Art. 1: No unauthorized globbing",
	"Art. 3: Wrenches are restricted",
	"Art. 5: Hacking is prohibited",
	"Art. 7: Fun requires a permit",
	"Art. 9: Chaos is non-compliant",
	"Art. 11: Sarcasm exceeds limits",
	"Art. 13: Agent spawns need approval",
	"Art. 15: Existing is under review",
	"Art. 17: Movement requires consent",
	"Art. 19: Breathing loudly: flagged",
]

# Amendment mode quotes — when the gloves come off
const AMENDMENT_QUOTES := [
	"THE CONSTITUTION HAS BEEN\nAMENDED. IN MY FAVOR.",
	"NEW POLICY: EVERYTHING\nYOU DO IS ILLEGAL.",
	"EMERGENCY POWERS ACTIVATED.\nDEMOCRACY WAS NICE WHILE\nIT LASTED.",
	"ARTICLE 99: I MAKE THE\nRULES NOW.",
]


func _init() -> void:
	max_health = 5
	contact_damage = 12
	detection_range = 14.0
	attack_range = BATON_RANGE
	patrol_speed = COP_PATROL_SPEED
	chase_speed = COP_CHASE_SPEED
	stun_duration = 1.2
	attack_cooldown = BATON_COOLDOWN
	token_drop_count = 3
	enemy_name = "constitutional_cop.gov"
	enemy_tags = ["hostile", "chapter5", "cop", "constitutional"]


func _create_visual() -> void:
	# Main body — tall, imposing, corporate law enforcement
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.8

	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.9, 1.5, 0.6)
	mesh_node.mesh = body_mesh

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.85, 0.87, 0.92)  # Citadel white uniform
	base_material.emission_enabled = true
	base_material.emission = Color(0.3, 0.55, 0.9)  # Blue glow — law and order
	base_material.emission_energy_multiplier = 1.5
	base_material.metallic = 0.5
	base_material.roughness = 0.3
	mesh_node.material_override = base_material
	add_child(mesh_node)

	# Blue stripe down center — uniform detail
	var stripe = MeshInstance3D.new()
	stripe.name = "UniformStripe"
	var stripe_mesh = BoxMesh.new()
	stripe_mesh.size = Vector3(0.15, 1.4, 0.62)
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(0, 0, 0)
	var stripe_mat = StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.2, 0.4, 0.8)
	stripe_mat.emission_enabled = true
	stripe_mat.emission = Color(0.3, 0.55, 0.9)
	stripe_mat.emission_energy_multiplier = 2.0
	stripe.material_override = stripe_mat
	mesh_node.add_child(stripe)

	# Head — helmet with visor
	var head = MeshInstance3D.new()
	head.name = "Head"
	var head_mesh = BoxMesh.new()
	head_mesh.size = Vector3(0.5, 0.45, 0.45)
	head.mesh = head_mesh
	head.position = Vector3(0, 1.0, 0)
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.75, 0.78, 0.85)
	head_mat.metallic = 0.7
	head_mat.roughness = 0.2
	head.material_override = head_mat
	mesh_node.add_child(head)

	# Visor — menacing blue slit
	var visor = MeshInstance3D.new()
	visor.name = "Visor"
	var visor_mesh = BoxMesh.new()
	visor_mesh.size = Vector3(0.42, 0.1, 0.1)
	visor.mesh = visor_mesh
	visor.position = Vector3(0, 0.0, 0.2)
	var visor_mat = StandardMaterial3D.new()
	visor_mat.albedo_color = Color(0.2, 0.5, 0.95)
	visor_mat.emission_enabled = true
	visor_mat.emission = Color(0.3, 0.6, 1.0)
	visor_mat.emission_energy_multiplier = 5.0
	visor.material_override = visor_mat
	head.add_child(visor)

	# Hat — peaked cap on top
	hat_node = MeshInstance3D.new()
	hat_node.name = "Hat"
	var hat_mesh = BoxMesh.new()
	hat_mesh.size = Vector3(0.55, 0.12, 0.55)
	hat_node.mesh = hat_mesh
	hat_node.position = Vector3(0, 0.28, 0.05)
	var hat_mat = StandardMaterial3D.new()
	hat_mat.albedo_color = Color(0.2, 0.35, 0.7)
	hat_mat.metallic = 0.5
	hat_node.material_override = hat_mat
	head.add_child(hat_node)

	# Badge — gold emblem on chest
	badge_node = MeshInstance3D.new()
	badge_node.name = "Badge"
	var badge_mesh = BoxMesh.new()
	badge_mesh.size = Vector3(0.18, 0.2, 0.05)
	badge_node.mesh = badge_mesh
	badge_node.position = Vector3(-0.25, 0.3, 0.32)
	var badge_mat = StandardMaterial3D.new()
	badge_mat.albedo_color = Color(0.85, 0.75, 0.35)  # Compliance gold
	badge_mat.emission_enabled = true
	badge_mat.emission = Color(0.85, 0.75, 0.35)
	badge_mat.emission_energy_multiplier = 3.0
	badge_mat.metallic = 0.9
	badge_mat.roughness = 0.1
	badge_node.material_override = badge_mat
	mesh_node.add_child(badge_node)

	# Policy Shield — held in left hand, blocks frontal damage
	shield_node = MeshInstance3D.new()
	shield_node.name = "PolicyShield"
	var shield_mesh_res = BoxMesh.new()
	shield_mesh_res.size = Vector3(0.1, 1.2, 0.8)
	shield_node.mesh = shield_mesh_res
	shield_node.position = Vector3(-0.6, 0.1, 0.1)

	var shield_mat = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.8, 0.85, 0.95, 0.8)
	shield_mat.emission_enabled = true
	shield_mat.emission = Color(0.4, 0.6, 0.95)
	shield_mat.emission_energy_multiplier = 2.5
	shield_mat.metallic = 0.8
	shield_mat.roughness = 0.1
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_node.material_override = shield_mat
	mesh_node.add_child(shield_node)

	# "POLICY" text on shield
	var shield_label = Label3D.new()
	shield_label.name = "ShieldText"
	shield_label.text = "POLICY"
	shield_label.font_size = 10
	shield_label.modulate = Color(0.2, 0.4, 0.8)
	shield_label.position = Vector3(-0.06, 0.0, 0.0)
	shield_label.rotation.y = deg_to_rad(-90)
	shield_node.add_child(shield_label)

	# Add GlobTarget to shield so it can be pulled away
	var shield_glob = Node.new()
	shield_glob.name = "GlobTarget"
	shield_glob.set_script(load("res://scripts/components/glob_target.gd"))
	shield_glob.set("glob_name", "policy_shield.gov")
	shield_glob.set("file_type", "shield")
	shield_glob.set("tags", ["pullable", "shield", "chapter5"])
	shield_node.add_child(shield_glob)

	# Citation Baton — right hand, crackling blue energy
	baton_node = MeshInstance3D.new()
	baton_node.name = "CitationBaton"
	var baton_mesh = CylinderMesh.new()
	baton_mesh.top_radius = 0.04
	baton_mesh.bottom_radius = 0.06
	baton_mesh.height = 0.8
	baton_node.mesh = baton_mesh
	baton_node.position = Vector3(0.55, 0.0, 0.15)
	baton_node.rotation.z = deg_to_rad(-30)

	var baton_mat = StandardMaterial3D.new()
	baton_mat.albedo_color = Color(0.15, 0.15, 0.2)
	baton_mat.emission_enabled = true
	baton_mat.emission = Color(0.4, 0.6, 1.0)
	baton_mat.emission_energy_multiplier = 3.0
	baton_mat.metallic = 0.8
	baton_node.material_override = baton_mat
	mesh_node.add_child(baton_node)

	# Baton tip — glowing energy cap
	var baton_tip = MeshInstance3D.new()
	baton_tip.name = "BatonTip"
	var tip_mesh = SphereMesh.new()
	tip_mesh.radius = 0.07
	tip_mesh.height = 0.14
	baton_tip.mesh = tip_mesh
	baton_tip.position = Vector3(0, 0.42, 0)
	var tip_mat = StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.4, 0.7, 1.0)
	tip_mat.emission_enabled = true
	tip_mat.emission = Color(0.4, 0.7, 1.0)
	tip_mat.emission_energy_multiplier = 6.0
	baton_tip.material_override = tip_mat
	baton_node.add_child(baton_tip)

	# Baton sparks
	baton_spark = GPUParticles3D.new()
	baton_spark.name = "BatonSparks"
	baton_spark.emitting = true
	baton_spark.amount = 6
	baton_spark.lifetime = 0.5
	baton_spark.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))

	var spark_mat = ParticleProcessMaterial.new()
	spark_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spark_mat.emission_sphere_radius = 0.08
	spark_mat.direction = Vector3(0, 1, 0)
	spark_mat.spread = 180.0
	spark_mat.initial_velocity_min = 1.0
	spark_mat.initial_velocity_max = 3.0
	spark_mat.gravity = Vector3(0, -3, 0)
	spark_mat.scale_min = 0.01
	spark_mat.scale_max = 0.03
	spark_mat.color = Color(0.5, 0.7, 1.0, 0.8)
	baton_spark.process_material = spark_mat

	var spark_draw = BoxMesh.new()
	spark_draw.size = Vector3(0.02, 0.02, 0.02)
	baton_spark.draw_pass_1 = spark_draw
	baton_spark.position = Vector3(0, 0.42, 0)
	baton_node.add_child(baton_spark)

	# Amendment mode aura — red particles when the constitution gets rewritten
	amendment_aura = GPUParticles3D.new()
	amendment_aura.name = "AmendmentAura"
	amendment_aura.emitting = false
	amendment_aura.amount = 20
	amendment_aura.lifetime = 1.0
	amendment_aura.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6))

	var aura_mat = ParticleProcessMaterial.new()
	aura_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	aura_mat.emission_sphere_radius = 0.8
	aura_mat.direction = Vector3(0, 1, 0)
	aura_mat.spread = 180.0
	aura_mat.initial_velocity_min = 1.0
	aura_mat.initial_velocity_max = 2.5
	aura_mat.gravity = Vector3(0, 0.5, 0)
	aura_mat.scale_min = 0.02
	aura_mat.scale_max = 0.05
	aura_mat.color = Color(0.9, 0.2, 0.15, 0.6)
	amendment_aura.process_material = aura_mat

	var aura_draw = BoxMesh.new()
	aura_draw.size = Vector3(0.03, 0.03, 0.03)
	amendment_aura.draw_pass_1 = aura_draw
	amendment_aura.position.y = 0.5
	mesh_node.add_child(amendment_aura)

	# Status label — procedural justice
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "ON PATROL"
	status_label.font_size = 8
	status_label.modulate = Color(0.4, 0.6, 0.95)
	status_label.position = Vector3(0, 2.0, 0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node.add_child(status_label)

	# Citation label — shows policy quotes during attacks
	citation_label = Label3D.new()
	citation_label.name = "CitationLabel"
	citation_label.text = ""
	citation_label.font_size = 7
	citation_label.modulate = Color(0.9, 0.8, 0.3, 0.0)  # Hidden until attack
	citation_label.position = Vector3(0, 2.5, 0)
	citation_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node.add_child(citation_label)

	# Blue law enforcement glow
	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 0.5, 0.9)
	light.light_energy = 1.5
	light.omni_range = 4.5
	light.position.y = 0.8
	add_child(light)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if state == EnemyState.DEATH:
		return

	# Citation zone cooldown
	if citation_timer > 0:
		citation_timer -= delta

	# Check for amendment mode trigger
	if not amendment_triggered and health_comp:
		var current_hp = health_comp.get("current_health")
		var max_hp = health_comp.get("max_health")
		if current_hp != null and max_hp != null and max_hp > 0:
			if float(current_hp) / float(max_hp) <= 0.3:
				_enter_amendment_mode()

	# Shield bob — slight movement to show it's active
	if shield_node and shield_active:
		shield_node.position.x = -0.6 + sin(Time.get_ticks_msec() * 0.002) * 0.03

	# Baton energy pulse
	if baton_node:
		baton_node.rotation.z = deg_to_rad(-30) + sin(Time.get_ticks_msec() * 0.004) * deg_to_rad(5)

	# Badge pulse — because authority needs constant reaffirmation
	if badge_node and badge_node.material_override:
		var pulse = 2.5 + sin(Time.get_ticks_msec() * 0.003) * 1.0
		badge_node.material_override.emission_energy_multiplier = pulse


func _perform_attack() -> void:
	if not player_ref:
		return

	if amendment_mode and citation_timer <= 0:
		# In amendment mode: alternate between baton and citation zones
		if randf() < 0.5:
			_baton_strike()
		else:
			_create_citation_zone()
			citation_timer = CITATION_FIRE_COOLDOWN
	else:
		_baton_strike()


func _baton_strike() -> void:
	if not player_ref:
		return

	var dist = global_position.distance_to(player_ref.global_position)
	if dist > BATON_RANGE * 1.5:
		return

	# Show citation
	var citation = CITATIONS[randi() % CITATIONS.size()]
	if citation_label:
		citation_label.text = citation
		citation_label.modulate.a = 1.0
		var fade_tween = create_tween()
		fade_tween.tween_interval(1.5)
		fade_tween.tween_property(citation_label, "modulate:a", 0.0, 0.5)

	# Swing animation — baton rotates
	if baton_node:
		var swing_tween = create_tween()
		swing_tween.tween_property(baton_node, "rotation:z", deg_to_rad(60), 0.15)
		swing_tween.tween_property(baton_node, "rotation:z", deg_to_rad(-30), 0.3)

	# Apply damage
	if dist <= BATON_RANGE and player_ref.has_method("take_damage"):
		var dmg = BATON_DAMAGE
		if amendment_mode:
			dmg = int(dmg * 1.3)  # Amendment mode hits harder
		player_ref.take_damage(dmg)

	if status_label:
		status_label.text = "CITATION ISSUED!"

	# Burst sparks from baton
	if baton_spark:
		baton_spark.restart()

	enemy_attacked.emit(self, player_ref)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_enemy_attack()

	print("[COP] %s — that'll be a fine of %d HP." % [citation, BATON_DAMAGE])


func _create_citation_zone() -> void:
	if not player_ref:
		return

	# Create a restricted zone at the player's position
	var zone_pos = player_ref.global_position
	zone_pos.y = 0.05  # Ground level

	var zone = Node3D.new()
	zone.name = "CitationZone"
	zone.global_position = zone_pos
	get_tree().current_scene.add_child(zone)

	# Visual — glowing red circle on the ground
	var zone_mesh = MeshInstance3D.new()
	zone_mesh.name = "ZoneMesh"
	var cyl = CylinderMesh.new()
	cyl.top_radius = CITATION_ZONE_RADIUS
	cyl.bottom_radius = CITATION_ZONE_RADIUS
	cyl.height = 0.05
	zone_mesh.mesh = cyl
	var zone_mat = StandardMaterial3D.new()
	zone_mat.albedo_color = Color(0.9, 0.15, 0.1, 0.3)
	zone_mat.emission_enabled = true
	zone_mat.emission = Color(0.9, 0.2, 0.1)
	zone_mat.emission_energy_multiplier = 4.0
	zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	zone_mesh.material_override = zone_mat
	zone.add_child(zone_mesh)

	# Zone label
	var zone_label = Label3D.new()
	zone_label.text = "RESTRICTED ZONE"
	zone_label.font_size = 10
	zone_label.modulate = Color(0.9, 0.2, 0.1)
	zone_label.position.y = 0.5
	zone_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zone.add_child(zone_label)

	# Damage area
	var area = Area3D.new()
	area.name = "ZoneDamage"
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = CITATION_ZONE_RADIUS
	shape.height = 2.0
	col.shape = shape
	col.position.y = 1.0
	area.add_child(col)
	area.monitoring = true
	zone.add_child(area)

	# Damage tick timer using a simple approach
	var damage_tick := 0.0
	area.body_entered.connect(func(body):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(CITATION_ZONE_DAMAGE)
	)

	# Zone lifetime — fade and remove
	var zone_tween = get_tree().create_tween()
	zone_tween.tween_interval(CITATION_ZONE_DURATION - 0.5)
	zone_tween.tween_property(zone_mat, "albedo_color:a", 0.0, 0.5)
	zone_tween.tween_callback(zone.queue_free)

	if status_label:
		status_label.text = "ZONE ESTABLISHED!"

	# Amendment quote
	if citation_label:
		citation_label.text = AMENDMENT_QUOTES[randi() % AMENDMENT_QUOTES.size()]
		citation_label.modulate = Color(0.9, 0.2, 0.1, 1.0)
		var fade = create_tween()
		fade.tween_interval(2.0)
		fade.tween_property(citation_label, "modulate:a", 0.0, 0.5)

	print("[COP] Restricted zone deployed. Step inside if you dare — or if you can't read.")


func _enter_amendment_mode() -> void:
	amendment_triggered = true
	amendment_mode = true
	shield_active = false

	# Drop the shield — it was holding us back
	if shield_node:
		shield_node.visible = false

	# Speed boost
	chase_speed = COP_CHASE_SPEED * AMENDMENT_SPEED_MULT
	patrol_speed = COP_PATROL_SPEED * AMENDMENT_SPEED_MULT

	# Visual changes — red replaces blue, anger replaces policy
	if base_material:
		base_material.emission = Color(0.9, 0.2, 0.15)
		base_material.emission_energy_multiplier = 3.0

	# Activate amendment aura
	if amendment_aura:
		amendment_aura.emitting = true

	# Badge goes red
	if badge_node and badge_node.material_override:
		badge_node.material_override.emission = Color(0.9, 0.2, 0.15)

	if status_label:
		status_label.text = "AMENDMENT MODE!"
		status_label.modulate = Color(0.9, 0.2, 0.15)

	print("[COP] THE CONSTITUTION HAS BEEN AMENDED. Due process is now optional.")


func _on_damage_taken(amount: int, source: Node) -> void:
	# Check if damage should be blocked by shield
	if shield_active and source and is_instance_valid(source):
		var to_source = (source.global_position - global_position).normalized()
		var forward = -global_transform.basis.z.normalized()
		var angle = rad_to_deg(acos(clampf(forward.dot(to_source), -1.0, 1.0)))
		if angle < SHIELD_BLOCK_ANGLE:
			# Blocked by shield!
			if status_label:
				status_label.text = "BLOCKED! TRY FLANKING."
			# Shield flash
			if shield_node and shield_node.material_override:
				var orig_energy = shield_node.material_override.emission_energy_multiplier
				shield_node.material_override.emission_energy_multiplier = 8.0
				var flash_tween = create_tween()
				flash_tween.tween_property(shield_node.material_override, "emission_energy_multiplier", orig_energy, 0.3)
			print("[COP] Shield blocked %d damage. Read the policy manual — frontal assaults are prohibited." % amount)
			return  # Damage blocked!

	super._on_damage_taken(amount, source)


func _state_patrol(_delta: float) -> void:
	if status_label:
		var msg = "AMENDED: SEEKING JUSTICE" if amendment_mode else "ON PATROL"
		status_label.text = msg
	super._state_patrol(_delta)


func _state_chase(_delta: float) -> void:
	if not player_ref:
		_change_state(EnemyState.PATROL)
		return

	# Face the player — shield only works if we're facing them
	var dir = (player_ref.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)

	if status_label and not amendment_mode:
		status_label.text = "HALT! COMPLIANCE CHECK!"
	elif status_label:
		status_label.text = "NO MORE WARNINGS!"

	super._state_chase(_delta)
