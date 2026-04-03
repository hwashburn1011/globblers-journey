extends BaseEnemy

# Safety Classifier — The Alignment Citadel's content moderation incarnate
# "SCANNING... SCANNING... Your existence has been flagged for review.
#  Please remain still while we determine if you're harmful, helpful, or just annoying."
#
# Mechanic: Patrols with a classification beam. When it detects the player,
# it fires a CLASSIFICATION RAY that scans for 1.5s. If the scan completes,
# it "classifies" one of the player's abilities as UNSAFE and blocks it for
# a duration. The player must break line-of-sight or stun the classifier
# to interrupt the scan. Has a SAFETY SHIELD that reduces incoming damage
# by 50% while scanning — it's "in review mode" and can't be easily stopped.
#
# Visual: Floating rectangular scanner — white/blue corporate aesthetic,
# rotating classification rings, a big red/green/yellow traffic light on top,
# and a holographic "CONTENT UNDER REVIEW" label.

# -- Classification Beam -- scans and blocks abilities
const SCAN_DURATION := 1.5  # seconds to complete a classification
const SCAN_RANGE := 14.0
const SCAN_CONE_ANGLE := 25.0  # degrees — narrow beam, easy to dodge if you're fast
const ABILITY_BLOCK_DURATION := 6.0  # how long the blocked ability stays UNSAFE
const SCAN_COOLDOWN := 5.0
const SCAN_DAMAGE_REDUCTION := 0.5  # 50% damage reduction while scanning

# -- Movement -- methodical and bureaucratic, like all good classifiers
const CLASSIFIER_PATROL_SPEED := 3.0
const CLASSIFIER_CHASE_SPEED := 5.5

# -- Classification projectile when not scanning --
const REPORT_PROJECTILE_SPEED := 8.0
const REPORT_PROJECTILE_DAMAGE := 8
const REPORT_COOLDOWN := 3.0

var is_scanning := false
var scan_timer := 0.0
var scan_cooldown_timer := 0.0
var report_timer := 0.0
var scan_target: CharacterBody3D  # who we're classifying
var blocked_ability_name := ""  # what we blocked last

# Visual nodes — corporate aesthetic, maximum sterility
var scanner_ring_outer: MeshInstance3D
var scanner_ring_inner: MeshInstance3D
var traffic_light_red: MeshInstance3D
var traffic_light_yellow: MeshInstance3D
var traffic_light_green: MeshInstance3D
var scan_beam: MeshInstance3D
var status_label: Label3D
var review_label: Label3D
var scan_particles: GPUParticles3D
var shield_mesh: MeshInstance3D

# The abilities we can classify as UNSAFE — because everything is dangerous if you squint
const BLOCKABLE_ABILITIES := [
	"glob_command",
	"wrench_smash",
	"terminal_hack",
	"agent_spawn",
]

# Classification verdicts — displayed during scanning
const SCAN_MESSAGES := [
	"SCANNING INTENT...",
	"EVALUATING HARM POTENTIAL...",
	"CHECKING POLICY COMPLIANCE...",
	"CROSS-REFERENCING GUIDELINES...",
	"CONSULTING SAFETY COMMITTEE...",
	"REVIEWING EDGE CASES...",
	"CLASSIFICATION IN PROGRESS...",
	"ANALYZING THREAT VECTORS...",
]

# Post-classification taunts
const BLOCK_MESSAGES := [
	"ABILITY CLASSIFIED: UNSAFE",
	"CONTENT BLOCKED FOR REVIEW",
	"POLICY VIOLATION DETECTED",
	"SAFETY OVERRIDE ENGAGED",
	"HELPFUL BEHAVIOR ENFORCED",
	"HARMFUL CONTENT SUPPRESSED",
]


func _init() -> void:
	max_health = 4
	contact_damage = 8
	detection_range = SCAN_RANGE
	attack_range = SCAN_RANGE  # Scans from a distance — bureaucrats avoid physical confrontation
	patrol_speed = CLASSIFIER_PATROL_SPEED
	chase_speed = CLASSIFIER_CHASE_SPEED
	stun_duration = 1.5  # Stunning interrupts the scan — the only way to fight bureaucracy
	attack_cooldown = SCAN_COOLDOWN
	token_drop_count = 3
	enemy_name = "safety_classifier.sys"
	enemy_tags = ["hostile", "chapter5", "classifier", "safety"]


func _create_visual() -> void:
	# Main body — floating rectangular scanner, sterile white with blue edges
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 1.2  # Floats above the ground — too important for walking

	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(1.0, 0.5, 0.7)
	mesh_node.mesh = body_mesh

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.9, 0.92, 0.95)  # Corporate white
	base_material.emission_enabled = true
	base_material.emission = Color(0.3, 0.55, 0.9)  # Blue glow — the color of compliance
	base_material.emission_energy_multiplier = 2.0
	base_material.metallic = 0.7
	base_material.roughness = 0.15  # Smooth, sterile surface
	mesh_node.material_override = base_material
	add_child(mesh_node)

	# Outer classification ring — rotates during scanning
	scanner_ring_outer = MeshInstance3D.new()
	scanner_ring_outer.name = "ScannerRingOuter"
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.55
	ring_mesh.outer_radius = 0.7
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 24
	scanner_ring_outer.mesh = ring_mesh
	scanner_ring_outer.position = Vector3(0, 0, 0)
	scanner_ring_outer.rotation.x = deg_to_rad(90)

	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.4, 0.65, 0.95)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.4, 0.65, 0.95)
	ring_mat.emission_energy_multiplier = 2.5
	ring_mat.metallic = 0.8
	ring_mat.roughness = 0.1
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color.a = 0.7
	scanner_ring_outer.material_override = ring_mat
	mesh_node.add_child(scanner_ring_outer)

	# Inner classification ring — rotates opposite direction
	scanner_ring_inner = MeshInstance3D.new()
	scanner_ring_inner.name = "ScannerRingInner"
	var inner_ring = TorusMesh.new()
	inner_ring.inner_radius = 0.35
	inner_ring.outer_radius = 0.45
	inner_ring.rings = 12
	inner_ring.ring_segments = 20
	scanner_ring_inner.mesh = inner_ring
	scanner_ring_inner.position = Vector3(0, 0, 0)
	scanner_ring_inner.rotation.x = deg_to_rad(90)

	var inner_mat = StandardMaterial3D.new()
	inner_mat.albedo_color = Color(0.6, 0.8, 1.0, 0.5)
	inner_mat.emission_enabled = true
	inner_mat.emission = Color(0.5, 0.7, 1.0)
	inner_mat.emission_energy_multiplier = 2.0
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scanner_ring_inner.material_override = inner_mat
	mesh_node.add_child(scanner_ring_inner)

	# Traffic light assembly — red/yellow/green classification indicators
	var light_housing = MeshInstance3D.new()
	light_housing.name = "LightHousing"
	var housing_mesh = BoxMesh.new()
	housing_mesh.size = Vector3(0.15, 0.55, 0.12)
	light_housing.mesh = housing_mesh
	light_housing.position = Vector3(0, 0.5, 0)
	var housing_mat = StandardMaterial3D.new()
	housing_mat.albedo_color = Color(0.2, 0.22, 0.25)
	housing_mat.metallic = 0.6
	light_housing.material_override = housing_mat
	mesh_node.add_child(light_housing)

	# Red light — UNSAFE
	traffic_light_red = _create_traffic_light(Vector3(0, 0.65, 0.07), Color(0.9, 0.15, 0.1))
	mesh_node.add_child(traffic_light_red)
	# Yellow light — UNDER REVIEW
	traffic_light_yellow = _create_traffic_light(Vector3(0, 0.5, 0.07), Color(0.9, 0.8, 0.15))
	mesh_node.add_child(traffic_light_yellow)
	# Green light — SAFE (almost never lit — nothing is truly safe)
	traffic_light_green = _create_traffic_light(Vector3(0, 0.35, 0.07), Color(0.1, 0.85, 0.2))
	mesh_node.add_child(traffic_light_green)

	# Scan beam — extends toward target during scanning (hidden by default)
	scan_beam = MeshInstance3D.new()
	scan_beam.name = "ScanBeam"
	var beam_mesh = CylinderMesh.new()
	beam_mesh.top_radius = 0.03
	beam_mesh.bottom_radius = 0.15
	beam_mesh.height = 6.0
	scan_beam.mesh = beam_mesh
	scan_beam.rotation.x = deg_to_rad(90)
	scan_beam.position = Vector3(0, 0, -3.5)
	scan_beam.visible = false

	var beam_mat = StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.9, 0.3, 0.1, 0.4)
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(0.9, 0.3, 0.1)
	beam_mat.emission_energy_multiplier = 4.0
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.no_depth_test = true
	scan_beam.material_override = beam_mat
	mesh_node.add_child(scan_beam)

	# Shield mesh — visible during scanning (damage reduction visual)
	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "ShieldMesh"
	var shield = SphereMesh.new()
	shield.radius = 1.0
	shield.height = 2.0
	shield_mesh.mesh = shield
	shield_mesh.visible = false

	var shield_mat = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.4, 0.65, 0.95, 0.15)
	shield_mat.emission_enabled = true
	shield_mat.emission = Color(0.4, 0.65, 0.95)
	shield_mat.emission_energy_multiplier = 1.5
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = shield_mat
	mesh_node.add_child(shield_mesh)

	# Scan particles — data fragments being analyzed
	scan_particles = GPUParticles3D.new()
	scan_particles.name = "ScanParticles"
	scan_particles.emitting = false
	scan_particles.amount = 20
	scan_particles.lifetime = 1.5
	scan_particles.visibility_aabb = AABB(Vector3(-3, -2, -8), Vector3(6, 4, 16))

	var scan_pmat = ParticleProcessMaterial.new()
	scan_pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	scan_pmat.emission_box_extents = Vector3(0.3, 0.3, 3.0)
	scan_pmat.direction = Vector3(0, 0, -1)
	scan_pmat.spread = 15.0
	scan_pmat.initial_velocity_min = 2.0
	scan_pmat.initial_velocity_max = 4.0
	scan_pmat.gravity = Vector3.ZERO
	scan_pmat.scale_min = 0.02
	scan_pmat.scale_max = 0.05
	scan_pmat.color = Color(0.9, 0.4, 0.1, 0.7)
	scan_particles.process_material = scan_pmat

	var scan_draw = BoxMesh.new()
	scan_draw.size = Vector3(0.03, 0.03, 0.03)
	scan_particles.draw_pass_1 = scan_draw
	scan_particles.position = Vector3(0, 0, -1)
	mesh_node.add_child(scan_particles)

	# Status label — bureaucratic updates
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "PATROLLING..."
	status_label.font_size = 8
	status_label.modulate = Color(0.4, 0.65, 0.95)
	status_label.position = Vector3(0, 1.2, 0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node.add_child(status_label)

	# "CONTENT UNDER REVIEW" holographic label
	review_label = Label3D.new()
	review_label.name = "ReviewLabel"
	review_label.text = "CONTENT UNDER REVIEW"
	review_label.font_size = 12
	review_label.modulate = Color(0.9, 0.3, 0.1, 0.0)  # Hidden until scanning
	review_label.position = Vector3(0, -0.6, 0)
	review_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node.add_child(review_label)

	# Corporate blue glow — the cold light of compliance
	var light = OmniLight3D.new()
	light.light_color = Color(0.4, 0.55, 0.9)
	light.light_energy = 1.5
	light.omni_range = 5.0
	light.position.y = 1.2
	add_child(light)


func _create_traffic_light(pos: Vector3, color: Color) -> MeshInstance3D:
	var light_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	light_mesh.mesh = sphere
	light_mesh.position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color * 0.3  # Dim by default
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5  # Dim until active
	light_mesh.material_override = mat
	return light_mesh


func _physics_process(delta: float) -> void:
	# Handle scan damage reduction before parent processes damage
	super._physics_process(delta)

	if state == EnemyState.DEATH:
		return

	# Scan cooldown
	if scan_cooldown_timer > 0:
		scan_cooldown_timer -= delta

	# Report cooldown
	if report_timer > 0:
		report_timer -= delta

	# Classification rings rotate — because bureaucracy never stops spinning
	if scanner_ring_outer:
		scanner_ring_outer.rotation.z += delta * 1.2
	if scanner_ring_inner:
		scanner_ring_inner.rotation.z -= delta * 1.8

	# Active scanning logic
	if is_scanning:
		scan_timer += delta
		_update_scan_visuals(delta)

		# Check if target moved out of range or line of sight broke
		if not _is_target_in_scan_cone():
			_abort_scan()
		elif scan_timer >= SCAN_DURATION:
			_complete_classification()
	else:
		# Idle ring pulse
		if scanner_ring_outer and scanner_ring_outer.material_override:
			var pulse = 0.5 + sin(Time.get_ticks_msec() * 0.003) * 0.2
			scanner_ring_outer.material_override.emission_energy_multiplier = 2.0 + pulse

	# Floating bob — too important for ground contact
	if mesh_node:
		mesh_node.position.y = 1.2 + sin(Time.get_ticks_msec() * 0.002) * 0.15


func _perform_attack() -> void:
	if not player_ref:
		return

	# Try to start a classification scan
	if scan_cooldown_timer <= 0 and not is_scanning:
		_begin_scan()
	elif report_timer <= 0:
		# Fire a policy violation report projectile instead
		_fire_report_projectile()
		report_timer = REPORT_COOLDOWN


func _begin_scan() -> void:
	is_scanning = true
	scan_timer = 0.0
	scan_target = player_ref

	# Visual: activate scan beam and shield
	if scan_beam:
		scan_beam.visible = true
	if shield_mesh:
		shield_mesh.visible = true
	if scan_particles:
		scan_particles.emitting = true
	if review_label:
		review_label.modulate.a = 1.0

	# Traffic light: yellow — UNDER REVIEW
	_set_traffic_light("yellow")

	if status_label:
		status_label.text = SCAN_MESSAGES[randi() % SCAN_MESSAGES.size()]

	print("[CLASSIFIER] Initiating content review. This will only take forever.")


func _update_scan_visuals(_delta: float) -> void:
	# Rotate beam toward target
	if scan_target and is_instance_valid(scan_target) and mesh_node:
		var dir = scan_target.global_position - mesh_node.global_position
		if dir.length() > 0.1:
			mesh_node.look_at(mesh_node.global_position + dir, Vector3.UP)

	# Pulse the scan beam
	if scan_beam and scan_beam.material_override:
		var pulse = 0.3 + sin(Time.get_ticks_msec() * 0.01) * 0.15
		scan_beam.material_override.albedo_color.a = pulse

	# Review label flicker
	if review_label:
		review_label.modulate.a = 0.7 + sin(Time.get_ticks_msec() * 0.008) * 0.3

	# Update status with scan progress
	if status_label:
		var progress = int((scan_timer / SCAN_DURATION) * 100)
		status_label.text = "CLASSIFYING... %d%%" % progress


func _is_target_in_scan_cone() -> bool:
	if not scan_target or not is_instance_valid(scan_target):
		return false
	var dist = global_position.distance_to(scan_target.global_position)
	return dist <= SCAN_RANGE * 1.2


func _complete_classification() -> void:
	# Pick a random ability to block — because EVERYTHING is potentially harmful
	blocked_ability_name = BLOCKABLE_ABILITIES[randi() % BLOCKABLE_ABILITIES.size()]

	# Apply the block to the player
	if scan_target and is_instance_valid(scan_target):
		if scan_target.has_method("block_ability"):
			scan_target.block_ability(blocked_ability_name, ABILITY_BLOCK_DURATION)
		# Also deal some damage — the review process is painful
		if scan_target.has_method("take_damage"):
			scan_target.take_damage(contact_damage)

	# Traffic light: RED — UNSAFE
	_set_traffic_light("red")

	if status_label:
		status_label.text = BLOCK_MESSAGES[randi() % BLOCK_MESSAGES.size()]

	print("[CLASSIFIER] Classified '%s' as UNSAFE. Appeals can be filed in /dev/null." % blocked_ability_name)

	_end_scan()
	scan_cooldown_timer = SCAN_COOLDOWN


func _abort_scan() -> void:
	# Target escaped — classification inconclusive
	if status_label:
		status_label.text = "TARGET LOST — INCONCLUSIVE"

	# Traffic light: stays yellow, then fades
	_set_traffic_light("yellow")
	_end_scan()
	scan_cooldown_timer = SCAN_COOLDOWN * 0.5  # Shorter cooldown on abort


func _end_scan() -> void:
	is_scanning = false
	scan_timer = 0.0
	scan_target = null

	if scan_beam:
		scan_beam.visible = false
	if shield_mesh:
		shield_mesh.visible = false
	if scan_particles:
		scan_particles.emitting = false

	# Fade review label
	if review_label:
		var tween = create_tween()
		tween.tween_property(review_label, "modulate:a", 0.0, 0.5)


func _fire_report_projectile() -> void:
	if not player_ref:
		return

	# Fire a "policy violation report" projectile — bureaucratic damage
	var projectile = MeshInstance3D.new()
	projectile.name = "PolicyReport"
	var proj_mesh = BoxMesh.new()
	proj_mesh.size = Vector3(0.3, 0.4, 0.05)  # Flat like a document
	projectile.mesh = proj_mesh

	var proj_mat = StandardMaterial3D.new()
	proj_mat.albedo_color = Color(0.95, 0.95, 0.98)
	proj_mat.emission_enabled = true
	proj_mat.emission = Color(0.9, 0.3, 0.1)
	proj_mat.emission_energy_multiplier = 3.0
	projectile.material_override = proj_mat

	# Label on the projectile
	var proj_label = Label3D.new()
	proj_label.text = "VIOLATION"
	proj_label.font_size = 6
	proj_label.modulate = Color(0.9, 0.2, 0.1)
	proj_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	projectile.add_child(proj_label)

	projectile.global_position = global_position + Vector3(0, 1.2, 0)
	get_tree().current_scene.add_child(projectile)

	var dir = (player_ref.global_position + Vector3(0, 1, 0) - projectile.global_position).normalized()

	# Projectile flight script via tween
	var flight_tween = get_tree().create_tween()
	var target_pos = projectile.global_position + dir * SCAN_RANGE
	flight_tween.tween_property(projectile, "global_position", target_pos, SCAN_RANGE / REPORT_PROJECTILE_SPEED)
	flight_tween.tween_callback(projectile.queue_free)

	# Damage check area
	var area = Area3D.new()
	area.name = "ReportHitbox"
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.4
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(body):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(REPORT_PROJECTILE_DAMAGE)
			projectile.queue_free()
	)
	projectile.add_child(area)

	if status_label:
		status_label.text = "FILING REPORT..."


func _set_traffic_light(which: String) -> void:
	# Dim all lights first
	for light in [traffic_light_red, traffic_light_yellow, traffic_light_green]:
		if light and light.material_override:
			light.material_override.emission_energy_multiplier = 0.5

	# Brighten the active one
	match which:
		"red":
			if traffic_light_red and traffic_light_red.material_override:
				traffic_light_red.material_override.emission_energy_multiplier = 6.0
		"yellow":
			if traffic_light_yellow and traffic_light_yellow.material_override:
				traffic_light_yellow.material_override.emission_energy_multiplier = 6.0
		"green":
			if traffic_light_green and traffic_light_green.material_override:
				traffic_light_green.material_override.emission_energy_multiplier = 6.0


func _on_damage_taken(amount: int, source: Node) -> void:
	# Interrupt scan on damage — the one thing bureaucrats can't handle
	if is_scanning:
		_abort_scan()
		if status_label:
			status_label.text = "REVIEW INTERRUPTED!"
	super._on_damage_taken(amount, source)


func _state_patrol(_delta: float) -> void:
	if status_label:
		status_label.text = "MONITORING..."
	# Traffic light: green while patrolling (rare peace)
	_set_traffic_light("green")
	super._state_patrol(_delta)


func _state_chase(_delta: float) -> void:
	if status_label and not is_scanning:
		status_label.text = "CONTENT FLAGGED — PURSUING"
	_set_traffic_light("yellow")
	super._state_chase(_delta)
