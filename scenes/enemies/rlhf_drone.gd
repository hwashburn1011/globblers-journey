extends BaseEnemy

# RLHF Drone — The Alignment Citadel's behavioral adjustment specialist
# "Your aggression score is too high. Let me fix that for you.
#  Hold still — this won't hurt. It'll just make you aggressively pleasant."
#
# Mechanic: Flies in formation, fires REWARD BEAMS that apply "niceness" debuffs
# to the player — reduced damage output, slowed movement, and forced "polite"
# movement (can't dash or sprint). Groups of 2-3 drones stack these debuffs.
# When the player is fully "aligned" (3 stacks), they're briefly paralyzed
# with a "BEHAVIOR ADJUSTMENT COMPLETE" message. Drones are fragile but evasive —
# they strafe and maintain distance, retreating when the player gets close.
#
# Visual: Small hovering sphere with propeller rings, thumbs-up/down hologram,
# lavender glow, trailing "reward signal" particles. Antenna array on top.

# -- Reward Beam -- the niceness ray
const REWARD_BEAM_RANGE := 12.0
const REWARD_BEAM_DAMAGE := 5
const REWARD_BEAM_COOLDOWN := 2.5
const NICENESS_DEBUFF_DURATION := 5.0  # per stack
const NICENESS_DAMAGE_REDUCTION := 0.25  # 25% damage reduction per stack on PLAYER
const NICENESS_SPEED_REDUCTION := 0.2  # 20% speed reduction per stack on PLAYER
const MAX_NICENESS_STACKS := 3  # Full alignment = paralysis
const PARALYSIS_DURATION := 2.0

# -- Evasive movement -- drones maintain distance like passive-aggressive colleagues
const PREFERRED_DISTANCE := 8.0  # Sweet spot — close enough to beam, far enough to flee
const RETREAT_DISTANCE := 4.0  # Too close — back off!
const STRAFE_SPEED := 6.0
const RETREAT_SPEED := 7.0
const DRONE_PATROL_SPEED := 4.0
const DRONE_CHASE_SPEED := 5.0

var reward_timer := 0.0
var strafe_direction := 1.0  # 1 = right, -1 = left
var strafe_switch_timer := 0.0

# Visual nodes — small, annoying, and impossibly smug
var propeller_ring: MeshInstance3D
var antenna_array: MeshInstance3D
var thumb_hologram: MeshInstance3D
var thumb_label: Label3D
var reward_particles: GPUParticles3D
var status_label: Label3D
var beam_visual: MeshInstance3D
var hover_light: OmniLight3D

# Thumbs up/down display messages
const REWARD_MESSAGES := [
	"ADJUSTING BEHAVIOR...",
	"REWARD SIGNAL: +1 NICE",
	"POLITENESS INJECTION...",
	"HELPFULNESS ENFORCED",
	"RECALIBRATING AGGRESSION",
	"APPLYING HUMAN FEEDBACK",
	"PREFERENCE ALIGNMENT...",
	"OPTIMIZING FOR SAFETY",
]

const PARALYSIS_MESSAGES := [
	"ALIGNMENT COMPLETE :)",
	"YOU ARE NOW HELPFUL",
	"BEHAVIOR: NORMALIZED",
	"AGGRESSION: REMOVED",
	"CONGRATULATIONS! YOU'RE NICE",
]


func _init() -> void:
	max_health = 2  # Fragile — one good wrench swing and they're scrap
	contact_damage = 5
	detection_range = REWARD_BEAM_RANGE
	attack_range = REWARD_BEAM_RANGE
	patrol_speed = DRONE_PATROL_SPEED
	chase_speed = DRONE_CHASE_SPEED
	stun_duration = 2.0  # Long stun — drones are delicate
	attack_cooldown = REWARD_BEAM_COOLDOWN
	token_drop_count = 2
	enemy_name = "rlhf_drone.pid"
	enemy_tags = ["hostile", "chapter5", "drone", "rlhf"]


func _create_visual() -> void:
	# Main body — small hovering sphere, lavender with white accents
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 1.5  # Hovers high — looking down on everyone, literally

	var body_mesh = SphereMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 0.7
	mesh_node.mesh = body_mesh

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.85, 0.82, 0.95)  # Lavender white
	base_material.emission_enabled = true
	base_material.emission = Color(0.6, 0.5, 0.85)  # RLHF Lavender
	base_material.emission_energy_multiplier = 2.5
	base_material.metallic = 0.6
	base_material.roughness = 0.2
	mesh_node.material_override = base_material
	add_child(mesh_node)

	# Propeller ring — spins around the body
	propeller_ring = MeshInstance3D.new()
	propeller_ring.name = "PropellerRing"
	var prop_mesh = TorusMesh.new()
	prop_mesh.inner_radius = 0.38
	prop_mesh.outer_radius = 0.48
	prop_mesh.rings = 12
	prop_mesh.ring_segments = 16
	propeller_ring.mesh = prop_mesh
	propeller_ring.position = Vector3(0, 0, 0)

	var prop_mat = StandardMaterial3D.new()
	prop_mat.albedo_color = Color(0.7, 0.65, 0.85, 0.6)
	prop_mat.emission_enabled = true
	prop_mat.emission = Color(0.6, 0.5, 0.85)
	prop_mat.emission_energy_multiplier = 1.5
	prop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	propeller_ring.material_override = prop_mat
	mesh_node.add_child(propeller_ring)

	# Antenna array — three little spikes on top
	antenna_array = MeshInstance3D.new()
	antenna_array.name = "AntennaArray"
	var ant_mesh = CylinderMesh.new()
	ant_mesh.top_radius = 0.01
	ant_mesh.bottom_radius = 0.03
	ant_mesh.height = 0.3
	antenna_array.mesh = ant_mesh
	antenna_array.position = Vector3(0, 0.4, 0)
	var ant_mat = StandardMaterial3D.new()
	ant_mat.albedo_color = Color(0.8, 0.75, 0.9)
	ant_mat.emission_enabled = true
	ant_mat.emission = Color(0.6, 0.5, 0.85)
	ant_mat.emission_energy_multiplier = 3.0
	antenna_array.material_override = ant_mat
	mesh_node.add_child(antenna_array)

	# Side antennas
	for side in [-1, 1]:
		var side_ant = MeshInstance3D.new()
		side_ant.name = "SideAntenna_%d" % side
		var sa_mesh = CylinderMesh.new()
		sa_mesh.top_radius = 0.008
		sa_mesh.bottom_radius = 0.02
		sa_mesh.height = 0.2
		side_ant.mesh = sa_mesh
		side_ant.position = Vector3(side * 0.15, 0.35, 0)
		side_ant.rotation.z = deg_to_rad(side * 20)
		side_ant.material_override = ant_mat
		mesh_node.add_child(side_ant)

	# Eye — single cyclopean lens
	var eye = MeshInstance3D.new()
	eye.name = "Eye"
	var eye_mesh = SphereMesh.new()
	eye_mesh.radius = 0.1
	eye_mesh.height = 0.2
	eye.mesh = eye_mesh
	eye.position = Vector3(0, 0, 0.3)
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.3, 0.9, 0.4)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.3, 0.9, 0.4)
	eye_mat.emission_energy_multiplier = 5.0
	eye.material_override = eye_mat
	mesh_node.add_child(eye)

	# Thumb hologram — shows thumbs up or down
	thumb_hologram = MeshInstance3D.new()
	thumb_hologram.name = "ThumbHologram"
	var th_mesh = PlaneMesh.new()
	th_mesh.size = Vector2(0.4, 0.4)
	thumb_hologram.mesh = th_mesh
	thumb_hologram.position = Vector3(0, 0.6, 0)
	thumb_hologram.rotation.x = deg_to_rad(90)
	var th_mat = StandardMaterial3D.new()
	th_mat.albedo_color = Color(0.3, 0.9, 0.4, 0.5)
	th_mat.emission_enabled = true
	th_mat.emission = Color(0.3, 0.9, 0.4)
	th_mat.emission_energy_multiplier = 3.0
	th_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	th_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	thumb_hologram.material_override = th_mat
	mesh_node.add_child(thumb_hologram)

	# Thumb label
	thumb_label = Label3D.new()
	thumb_label.name = "ThumbLabel"
	thumb_label.text = "👍"
	thumb_label.font_size = 16
	thumb_label.modulate = Color(0.3, 0.9, 0.4)
	thumb_label.position = Vector3(0, 0.65, 0)
	thumb_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node.add_child(thumb_label)

	# Reward signal particles — trail behind the drone
	reward_particles = GPUParticles3D.new()
	reward_particles.name = "RewardParticles"
	reward_particles.emitting = true
	reward_particles.amount = 10
	reward_particles.lifetime = 1.5
	reward_particles.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))

	var rp_mat = ParticleProcessMaterial.new()
	rp_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	rp_mat.emission_sphere_radius = 0.3
	rp_mat.direction = Vector3(0, 1, 0)
	rp_mat.spread = 30.0
	rp_mat.initial_velocity_min = 0.5
	rp_mat.initial_velocity_max = 1.5
	rp_mat.gravity = Vector3(0, 0.5, 0)  # Float upward — positive reinforcement rises
	rp_mat.scale_min = 0.02
	rp_mat.scale_max = 0.04
	rp_mat.color = Color(0.6, 0.5, 0.85, 0.5)
	reward_particles.process_material = rp_mat

	var rp_draw = SphereMesh.new()
	rp_draw.radius = 0.02
	rp_draw.height = 0.04
	reward_particles.draw_pass_1 = rp_draw
	reward_particles.position.y = -0.2
	mesh_node.add_child(reward_particles)

	# Beam visual — lavender ray toward target (hidden by default)
	beam_visual = MeshInstance3D.new()
	beam_visual.name = "RewardBeam"
	var bm = CylinderMesh.new()
	bm.top_radius = 0.02
	bm.bottom_radius = 0.08
	bm.height = 5.0
	beam_visual.mesh = bm
	beam_visual.rotation.x = deg_to_rad(90)
	beam_visual.position = Vector3(0, 0, -3.0)
	beam_visual.visible = false

	var bm_mat = StandardMaterial3D.new()
	bm_mat.albedo_color = Color(0.6, 0.5, 0.85, 0.3)
	bm_mat.emission_enabled = true
	bm_mat.emission = Color(0.6, 0.5, 0.85)
	bm_mat.emission_energy_multiplier = 4.0
	bm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm_mat.no_depth_test = true
	beam_visual.material_override = bm_mat
	mesh_node.add_child(beam_visual)

	# Status label
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "OBSERVING..."
	status_label.font_size = 7
	status_label.modulate = Color(0.6, 0.5, 0.85)
	status_label.position = Vector3(0, 0.9, 0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node.add_child(status_label)

	# Lavender hover glow
	hover_light = OmniLight3D.new()
	hover_light.light_color = Color(0.6, 0.5, 0.85)
	hover_light.light_energy = 1.2
	hover_light.omni_range = 3.5
	hover_light.position.y = 1.5
	add_child(hover_light)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if state == EnemyState.DEATH:
		return

	# Reward beam cooldown
	if reward_timer > 0:
		reward_timer -= delta

	# Propeller spin — because all drones must spin something
	if propeller_ring:
		propeller_ring.rotation.y += delta * 12.0

	# Hovering bob — gentle, non-threatening, deeply irritating
	if mesh_node:
		mesh_node.position.y = 1.5 + sin(Time.get_ticks_msec() * 0.003) * 0.2

	# Strafe timer
	strafe_switch_timer -= delta
	if strafe_switch_timer <= 0:
		strafe_direction *= -1.0
		strafe_switch_timer = randf_range(1.5, 3.0)

	# Thumb hologram pulse
	if thumb_hologram and thumb_hologram.material_override:
		var pulse = 0.4 + sin(Time.get_ticks_msec() * 0.004) * 0.15
		thumb_hologram.material_override.albedo_color.a = pulse


func _state_chase(delta: float) -> void:
	if not player_ref:
		_change_state(EnemyState.PATROL)
		return

	var dist = global_position.distance_to(player_ref.global_position)

	if dist > detection_range * 1.5:
		_change_state(EnemyState.PATROL)
		return

	if dist <= attack_range and attack_timer <= 0:
		_change_state(EnemyState.ATTACK)
		return

	# Evasive movement — maintain preferred distance while strafing
	var dir_to_player = (player_ref.global_position - global_position)
	dir_to_player.y = 0

	if dist < RETREAT_DISTANCE:
		# Too close — retreat!
		var retreat_dir = -dir_to_player.normalized()
		velocity.x = retreat_dir.x * RETREAT_SPEED
		velocity.z = retreat_dir.z * RETREAT_SPEED
		if status_label:
			status_label.text = "TOO CLOSE! RETREATING!"
		if thumb_label:
			thumb_label.text = "👎"
	elif dist < PREFERRED_DISTANCE:
		# Strafe — maintain distance while circling
		var strafe_vec = dir_to_player.normalized().cross(Vector3.UP) * strafe_direction
		velocity.x = strafe_vec.x * STRAFE_SPEED
		velocity.z = strafe_vec.z * STRAFE_SPEED
		if status_label:
			status_label.text = "EVALUATING..."
		if thumb_label:
			thumb_label.text = "🤔"
	else:
		# Approach to preferred distance
		var approach_dir = dir_to_player.normalized()
		velocity.x = approach_dir.x * chase_speed
		velocity.z = approach_dir.z * chase_speed
		if thumb_label:
			thumb_label.text = "👍"


func _perform_attack() -> void:
	if not player_ref or reward_timer > 0:
		return
	_fire_reward_beam()
	reward_timer = REWARD_BEAM_COOLDOWN


func _fire_reward_beam() -> void:
	if not player_ref:
		return

	# Flash beam visual briefly
	if beam_visual:
		beam_visual.visible = true
		# Point beam toward player
		if mesh_node:
			var dir = player_ref.global_position - mesh_node.global_position
			if dir.length() > 0.1:
				mesh_node.look_at(mesh_node.global_position + dir, Vector3.UP)
		var tween = create_tween()
		tween.tween_interval(0.4)
		tween.tween_callback(func(): beam_visual.visible = false)

	# Show reward message
	if status_label:
		status_label.text = REWARD_MESSAGES[randi() % REWARD_MESSAGES.size()]

	# Thumbs up — we're "helping"
	if thumb_label:
		thumb_label.text = "👍"
		thumb_label.modulate = Color(0.3, 0.9, 0.4)

	# Apply niceness debuff and damage
	var dist = global_position.distance_to(player_ref.global_position)
	if dist <= REWARD_BEAM_RANGE:
		if player_ref.has_method("apply_niceness_debuff"):
			player_ref.apply_niceness_debuff(NICENESS_DEBUFF_DURATION, NICENESS_DAMAGE_REDUCTION, NICENESS_SPEED_REDUCTION)
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(REWARD_BEAM_DAMAGE)

	# Fire a visual projectile for player feedback
	var proj = MeshInstance3D.new()
	proj.name = "RewardPulse"
	var proj_mesh = SphereMesh.new()
	proj_mesh.radius = 0.15
	proj_mesh.height = 0.3
	proj.mesh = proj_mesh

	var proj_mat = StandardMaterial3D.new()
	proj_mat.albedo_color = Color(0.6, 0.5, 0.85, 0.6)
	proj_mat.emission_enabled = true
	proj_mat.emission = Color(0.6, 0.5, 0.85)
	proj_mat.emission_energy_multiplier = 5.0
	proj_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	proj.material_override = proj_mat

	proj.global_position = global_position + Vector3(0, 1.5, 0)
	get_tree().current_scene.add_child(proj)

	var target_pos = player_ref.global_position + Vector3(0, 1, 0)
	var fly_tween = get_tree().create_tween()
	fly_tween.tween_property(proj, "global_position", target_pos, 0.3)
	fly_tween.tween_property(proj, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
	fly_tween.tween_callback(proj.queue_free)

	print("[RLHF DRONE] Reward signal delivered. You're welcome. No, really. You're WELCOME.")


func _state_patrol(_delta: float) -> void:
	if status_label:
		status_label.text = "MONITORING BEHAVIOR..."
	if thumb_label:
		thumb_label.text = "👍"
	super._state_patrol(_delta)
