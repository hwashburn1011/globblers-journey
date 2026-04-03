extends BaseEnemy

# The Local Minimum — Chapter 2 Boss
# "I'm not trapping you. I'm OPTIMIZING you. Into a nice, comfortable rut.
#  Why explore the loss landscape when you can stay here forever at L=0.00?"
#
# Three-phase boss fight:
#   Phase 1 (CONVERGE): Boss orbits arena, fires gravity wells that pull player
#     toward center. Outer rings collapse periodically. Dodge and deal damage.
#   Phase 2 (OVERFIT): Boss becomes shielded, spawns "gradient" projectiles
#     player must glob-match (*.grad) and push back to break shield. Arena
#     continues shrinking. Escape ridges appear less frequently.
#   Phase 3 (ESCAPE): Boss stunned, loss function terminal exposed. Hack it
#     to "find a better minimum" before arena fully collapses.

enum BossPhase { INTRO, PHASE_1, PHASE_2, PHASE_3, DEFEATED }

var boss_phase: BossPhase = BossPhase.INTRO
var arena: Node3D  # LocalMinimumArena reference — set by training_grounds

# Phase thresholds
var phase_1_hp_threshold := 0.55  # Transition to phase 2 at 55% HP
var phase_2_hp_threshold := 0.2   # Transition to phase 3 at 20% HP

# Phase 1 — ring collapse timing
var ring_collapse_timer := 0.0
var ring_collapse_interval := 12.0  # Seconds between ring collapses
var next_ring_to_collapse := 5  # Start from outermost (index 5)
var gravity_well_timer := 0.0
var gravity_well_interval := 5.0  # Seconds between gravity well attacks

# Phase 2 — gradient projectile timing
var projectile_timer := 0.0
var projectile_interval := 2.0
var shield_active := false
var reflected_hits := 0
var reflected_hits_needed := 5  # More hits needed than ch1 boss — learning curve

# Phase 3 — hack state
var core_exposed := false
var hack_terminal: Node
var phase_3_recovery_timer := 0.0
var phase_3_recovery_time := 18.0  # Slightly less time than ch1 — tension!

# Orbit state
var orbit_angle := 0.0
var orbit_speed := 1.2
var orbit_radius := 10.0

# Visual nodes
var body_mesh: MeshInstance3D
var eye_left: MeshInstance3D
var eye_right: MeshInstance3D
var shield_mesh: MeshInstance3D
var core_mesh: MeshInstance3D
var boss_light: OmniLight3D
var gravity_indicator: MeshInstance3D  # Shows pull direction

# Colors — the "stuck in a rut" palette
const MINIMUM_RED := Color(0.8, 0.1, 0.15)
const LOSS_GOLD := Color(0.9, 0.75, 0.2)
const DARK_PIT := Color(0.12, 0.03, 0.05)
const SHIELD_AMBER := Color(0.9, 0.6, 0.1)
const CORE_GREEN := Color(0.224, 1.0, 0.078)
const GRADIENT_BLUE := Color(0.2, 0.5, 0.9)

signal boss_phase_changed(phase: BossPhase)
signal boss_defeated()
signal ring_collapse_requested(ring_index: int)


func _ready() -> void:
	# Override base enemy defaults — this boss IS the loss landscape
	enemy_name = "local_minimum.boss"
	enemy_tags = ["boss", "hostile", "optimization"]
	max_health = 65  # Deeper minimum, more HP to dig out of
	contact_damage = 16
	detection_range = 50.0  # Always aware — omniscient loss surface
	attack_range = 30.0
	patrol_speed = 0.0
	chase_speed = 4.0
	stun_duration = 0.5
	attack_cooldown = 2.0
	token_drop_count = 15

	super._ready()
	_resize_collision()


func _resize_collision() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			var capsule = child.shape as CapsuleShape3D
			if capsule:
				capsule.radius = 1.2
				capsule.height = 4.0
				child.position.y = 2.0


func _create_visual() -> void:
	# The Local Minimum — a gravitational pit entity with concentric ring armor
	# Imagine a floating vortex of loss values wrapped in mathematical notation

	# Main body — inverted cone/funnel shape (like a loss surface minimum)
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "BossBody"
	var body_cyl = CylinderMesh.new()
	body_cyl.top_radius = 0.5
	body_cyl.bottom_radius = 2.0
	body_cyl.height = 4.0
	body_mesh.mesh = body_cyl
	body_mesh.position.y = 2.5

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = DARK_PIT
	base_material.emission_enabled = true
	base_material.emission = MINIMUM_RED
	base_material.emission_energy_multiplier = 1.5
	base_material.metallic = 0.8
	base_material.roughness = 0.15
	body_mesh.material_override = base_material
	add_child(body_mesh)

	# Orbiting ring layers — concentric loss contour rings
	for i in range(3):
		var ring = MeshInstance3D.new()
		ring.name = "ContourRing_%d" % i
		var torus = TorusMesh.new()
		torus.inner_radius = 0.05
		torus.outer_radius = 1.5 + i * 0.6
		ring.mesh = torus
		ring.position.y = 1.5 + i * 1.0

		var ring_mat = StandardMaterial3D.new()
		var t = float(i) / 2.0
		ring_mat.albedo_color = MINIMUM_RED.lerp(LOSS_GOLD, t) * 0.3
		ring_mat.emission_enabled = true
		ring_mat.emission = MINIMUM_RED.lerp(LOSS_GOLD, t)
		ring_mat.emission_energy_multiplier = 1.5 + t * 2.0
		ring_mat.metallic = 0.6
		ring.material_override = ring_mat
		add_child(ring)

	# "Face" — a terminal showing the loss value, always decreasing
	var face_mesh = MeshInstance3D.new()
	face_mesh.name = "BossFace"
	var face_plane = PlaneMesh.new()
	face_plane.size = Vector2(2.0, 1.2)
	face_mesh.mesh = face_plane
	face_mesh.position = Vector3(0, 3.8, 1.05)
	face_mesh.rotation.x = deg_to_rad(90)

	var face_mat = StandardMaterial3D.new()
	face_mat.albedo_color = Color(0.02, 0.02, 0.02)
	face_mat.emission_enabled = true
	face_mat.emission = LOSS_GOLD
	face_mat.emission_energy_multiplier = 2.0
	face_mesh.material_override = face_mat
	body_mesh.add_child(face_mesh)

	# Loss value label — the face of optimization
	var face_label = Label3D.new()
	face_label.text = "L = 0.00\nCONVERGED"
	face_label.font_size = 36
	face_label.modulate = LOSS_GOLD
	face_label.position = Vector3(0, 4.0, 1.15)
	face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(face_label)

	# Glowing eyes — smug, satisfied eyes of a "converged" optimizer
	eye_left = _create_eye(Vector3(-0.4, 4.2, 0.55))
	eye_right = _create_eye(Vector3(0.4, 4.2, 0.55))

	# Gravity tendrils — reaching arms that pull things toward the minimum
	for side in [-1, 1]:
		var arm = MeshInstance3D.new()
		var arm_box = BoxMesh.new()
		arm_box.size = Vector3(2.5, 0.3, 0.3)
		arm.mesh = arm_box
		arm.position = Vector3(side * 2.5, 2.5, 0)
		arm.rotation.z = side * deg_to_rad(-20)  # Curving inward — grasping

		var arm_mat = StandardMaterial3D.new()
		arm_mat.albedo_color = DARK_PIT
		arm_mat.emission_enabled = true
		arm_mat.emission = MINIMUM_RED
		arm_mat.emission_energy_multiplier = 2.0
		arm_mat.metallic = 0.7
		arm.material_override = arm_mat
		add_child(arm)

	# Shield mesh (invisible until phase 2)
	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "BossShield"
	var shield_sphere = SphereMesh.new()
	shield_sphere.radius = 3.0
	shield_sphere.height = 6.0
	shield_mesh.mesh = shield_sphere
	shield_mesh.position.y = 2.5

	var shield_mat = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.4, 0.3, 0.05, 0.2)
	shield_mat.emission_enabled = true
	shield_mat.emission = SHIELD_AMBER
	shield_mat.emission_energy_multiplier = 1.0
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = shield_mat
	shield_mesh.visible = false
	add_child(shield_mesh)

	# Core mesh (invisible until phase 3)
	core_mesh = MeshInstance3D.new()
	core_mesh.name = "BossCore"
	var core_sphere = SphereMesh.new()
	core_sphere.radius = 0.7
	core_sphere.height = 1.4
	core_mesh.mesh = core_sphere
	core_mesh.position = Vector3(0, 2.0, 1.3)

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = CORE_GREEN
	core_mat.emission_enabled = true
	core_mat.emission = CORE_GREEN
	core_mat.emission_energy_multiplier = 4.0
	core_mesh.material_override = core_mat
	core_mesh.visible = false
	add_child(core_mesh)

	# Boss glow light
	boss_light = OmniLight3D.new()
	boss_light.light_color = MINIMUM_RED
	boss_light.light_energy = 3.0
	boss_light.omni_range = 15.0
	boss_light.position.y = 3.0
	add_child(boss_light)

	# Gravity pull indicator — subtle downward-pointing marker
	gravity_indicator = MeshInstance3D.new()
	gravity_indicator.name = "GravityIndicator"
	var gi_mesh = CylinderMesh.new()
	gi_mesh.top_radius = 0.0
	gi_mesh.bottom_radius = 0.8
	gi_mesh.height = 1.2
	gravity_indicator.mesh = gi_mesh
	gravity_indicator.position = Vector3(0, 0.6, 0)
	gravity_indicator.rotation.x = PI  # Pointing down

	var gi_mat = StandardMaterial3D.new()
	gi_mat.albedo_color = MINIMUM_RED * 0.2
	gi_mat.emission_enabled = true
	gi_mat.emission = MINIMUM_RED
	gi_mat.emission_energy_multiplier = 1.5
	gi_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gi_mat.albedo_color.a = 0.4
	gravity_indicator.material_override = gi_mat
	add_child(gravity_indicator)

	# Title label
	var title = Label3D.new()
	title.text = "< THE LOCAL MINIMUM >"
	title.font_size = 28
	title.modulate = LOSS_GOLD
	title.position = Vector3(0, 6.0, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title)


func _create_eye(pos: Vector3) -> MeshInstance3D:
	var eye = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	eye.mesh = sphere
	eye.position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = LOSS_GOLD
	mat.emission_enabled = true
	mat.emission = LOSS_GOLD
	mat.emission_energy_multiplier = 5.0
	eye.material_override = mat
	add_child(eye)
	return eye


func _physics_process(delta: float) -> void:
	if boss_phase == BossPhase.DEFEATED:
		return

	# Let base handle gravity and player detection
	super._physics_process(delta)

	match boss_phase:
		BossPhase.INTRO:
			_process_intro(delta)
		BossPhase.PHASE_1:
			_process_phase_1(delta)
		BossPhase.PHASE_2:
			_process_phase_2(delta)
		BossPhase.PHASE_3:
			_process_phase_3(delta)

	_animate_eyes(delta)
	_animate_contour_rings(delta)
	_apply_gravity_pull(delta)


func _process_intro(_delta: float) -> void:
	# Waiting for start_boss_fight() — lurking at the center
	velocity.x = 0
	velocity.z = 0


func _process_phase_1(delta: float) -> void:
	# Orbit the arena center, periodically collapse rings and fire gravity wells
	_orbit_movement(delta)

	# Ring collapse timer — the arena shrinks relentlessly
	ring_collapse_timer += delta
	if ring_collapse_timer >= ring_collapse_interval:
		ring_collapse_timer = 0.0
		_trigger_ring_collapse()

	# Gravity well attack — pulls player toward center pit
	gravity_well_timer += delta
	if gravity_well_timer >= gravity_well_interval:
		gravity_well_timer = 0.0
		_fire_gravity_well()

	# Check HP threshold for phase transition
	if health_comp and health_comp.get("current_health") != null:
		var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
		if hp_pct <= phase_1_hp_threshold:
			_transition_to_phase(BossPhase.PHASE_2)


func _process_phase_2(delta: float) -> void:
	# Faster orbit, shielded, fires gradient projectiles, arena keeps shrinking
	orbit_speed = 1.8  # Faster orbit — getting desperate
	_orbit_movement(delta)

	# Gradient projectiles
	projectile_timer += delta
	if projectile_timer >= projectile_interval:
		projectile_timer = 0.0
		_spawn_gradient_projectile()

	# Ring collapse continues — faster now
	ring_collapse_timer += delta
	if ring_collapse_timer >= ring_collapse_interval * 0.7:
		ring_collapse_timer = 0.0
		_trigger_ring_collapse()

	# Gravity wells less frequent but still present
	gravity_well_timer += delta
	if gravity_well_timer >= gravity_well_interval * 1.5:
		gravity_well_timer = 0.0
		_fire_gravity_well()

	# Check for phase 3 transition
	if health_comp and health_comp.get("current_health") != null:
		var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
		if hp_pct <= phase_2_hp_threshold:
			_transition_to_phase(BossPhase.PHASE_3)


func _process_phase_3(delta: float) -> void:
	# Boss stunned, core exposed, player must hack the loss function
	velocity.x = 0
	velocity.z = 0

	phase_3_recovery_timer += delta
	if phase_3_recovery_timer >= phase_3_recovery_time:
		# Boss recovers — loss function re-optimizes
		phase_3_recovery_timer = 0.0
		core_exposed = false
		core_mesh.visible = false
		shield_mesh.visible = true
		shield_active = true
		reflected_hits = 0
		if health_comp and health_comp.has_method("heal"):
			health_comp.heal(8)
		_transition_to_phase(BossPhase.PHASE_2)
		_boss_dialogue("NARRATOR", "The minimum re-optimized. You took too long — try again!")


func _orbit_movement(delta: float) -> void:
	# Orbit around the arena center — the boss IS the loss landscape
	if not arena:
		return

	orbit_angle += orbit_speed * delta
	var center = arena.global_position

	# Adjust orbit radius based on remaining arena size
	if arena.has_method("get_arena_radius"):
		orbit_radius = arena.get_arena_radius() * 0.6

	var target_x = center.x + cos(orbit_angle) * orbit_radius
	var target_z = center.z + sin(orbit_angle) * orbit_radius

	var dir = Vector3(target_x - global_position.x, 0, target_z - global_position.z)
	if dir.length() > 0.5:
		dir = dir.normalized()
		velocity.x = dir.x * chase_speed
		velocity.z = dir.z * chase_speed
	else:
		velocity.x = 0
		velocity.z = 0

	# Face the center — always watching the minimum
	look_at(center + Vector3(0, 2.5, 0), Vector3.UP)


func _trigger_ring_collapse() -> void:
	# Tell the arena to start collapsing the next outermost ring
	if next_ring_to_collapse < 0:
		return  # All rings already collapsed

	if arena and arena.has_method("start_shrinking"):
		arena.start_shrinking(next_ring_to_collapse)
		ring_collapse_requested.emit(next_ring_to_collapse)
		_boss_dialogue("THE LOCAL MINIMUM", _get_shrink_quip())

	next_ring_to_collapse -= 1

	# Flash on ring collapse
	if base_material:
		var tween = create_tween()
		tween.tween_property(base_material, "emission_energy_multiplier", 6.0, 0.15)
		tween.tween_property(base_material, "emission_energy_multiplier", 1.5, 0.4)

	# Audio feedback
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_boss_attack"):
		am.play_boss_attack()


func _fire_gravity_well() -> void:
	# Create a gravity well at the player's position — pulls them toward center
	if not player_ref or not arena:
		return

	# Spawn a gravity well node that applies force toward center
	var well = Area3D.new()
	well.name = "GravityWell_%d" % randi()
	well.position = player_ref.global_position
	well.monitoring = true

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 5.0
	col.shape = shape
	well.add_child(col)

	# Visual — red vortex indicator on the floor
	var indicator = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 5.0
	cyl.bottom_radius = 5.0
	cyl.height = 0.1
	indicator.mesh = cyl
	indicator.position.y = 0.1

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.1, 0.05, 0.25)
	mat.emission_enabled = true
	mat.emission = MINIMUM_RED
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	indicator.material_override = mat
	well.add_child(indicator)

	# Warning label
	var label = Label3D.new()
	label.text = "▼ CONVERGE ▼"
	label.font_size = 16
	label.modulate = MINIMUM_RED
	label.position = Vector3(0, 1.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	well.add_child(label)

	get_tree().current_scene.add_child(well)

	# Pull effect lasts 3 seconds — apply force via timer-based process
	var arena_center = arena.global_position
	var pull_time := 3.0
	var pull_strength := 8.0

	# Animate the gravity well — shrink the indicator as it pulls
	var tween = get_tree().create_tween()
	tween.tween_property(indicator, "scale", Vector3(0.1, 1, 0.1), pull_time)
	tween.tween_callback(well.queue_free)

	# Apply pull force to player while they're in the well
	well.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and body is CharacterBody3D:
			# The gravity well "tag" — processed in _apply_gravity_pull
			body.set_meta("gravity_well_active", true)
			body.set_meta("gravity_well_center", arena_center)
			body.set_meta("gravity_well_strength", pull_strength)
	)
	well.body_exited.connect(func(body: Node3D):
		if body.is_in_group("player"):
			body.remove_meta("gravity_well_active")
	)

	# Auto-expire the meta after pull_time
	get_tree().create_timer(pull_time).timeout.connect(func():
		if player_ref and player_ref.has_meta("gravity_well_active"):
			player_ref.remove_meta("gravity_well_active")
	)

	_boss_dialogue("THE LOCAL MINIMUM", "CONVERGE. You belong at the bottom.")

	# Audio
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_boss_attack"):
		am.play_boss_attack()


func _apply_gravity_pull(delta: float) -> void:
	# If the player is tagged by a gravity well, apply pull force
	if not player_ref:
		return
	if not player_ref.has_meta("gravity_well_active"):
		return
	if not player_ref.get_meta("gravity_well_active"):
		return

	var center = player_ref.get_meta("gravity_well_center") as Vector3
	var strength = player_ref.get_meta("gravity_well_strength") as float
	var pull_dir = (center - player_ref.global_position)
	pull_dir.y = 0
	if pull_dir.length() > 1.0:
		pull_dir = pull_dir.normalized()
		player_ref.velocity.x += pull_dir.x * strength * delta
		player_ref.velocity.z += pull_dir.z * strength * delta


func _spawn_gradient_projectile() -> void:
	# Spawn a globbable gradient projectile — player must match *.grad and push back
	if not player_ref:
		return

	var proj = CharacterBody3D.new()
	proj.name = "GradientProjectile_%d" % randi()
	proj.position = global_position + Vector3(0, 2.5, 0)

	# Collision
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.4
	col.shape = shape
	proj.add_child(col)

	# Visual — glowing gradient orb
	var mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	mesh.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = GRADIENT_BLUE * 0.3
	mat.emission_enabled = true
	mat.emission = GRADIENT_BLUE
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	proj.add_child(mesh)

	# Label
	var label = Label3D.new()
	label.text = "∇ .grad"
	label.font_size = 14
	label.modulate = GRADIENT_BLUE
	label.position = Vector3(0, 0.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	proj.add_child(label)

	# GlobTarget — so player can match it with *.grad
	var gt = Node.new()
	gt.name = "GlobTarget"
	gt.set_script(load("res://scripts/components/glob_target.gd"))
	gt.set("glob_name", "gradient.grad")
	gt.set("file_type", "grad")
	gt.set("tags", ["projectile", "gradient", "reflectable"])
	proj.add_child(gt)

	# Movement script — moves toward player, can be reflected
	var target_dir = (player_ref.global_position - proj.position).normalized()
	proj.set_meta("move_direction", target_dir)
	proj.set_meta("speed", 8.0)
	proj.set_meta("reflected", false)
	proj.set_meta("boss_ref", self)
	proj.set_meta("lifetime", 0.0)

	# Add to scene
	get_tree().current_scene.call_deferred("add_child", proj)

	# Process movement via a deferred script attachment
	call_deferred("_attach_projectile_behavior", proj)


func _attach_projectile_behavior(proj: Node) -> void:
	if not is_instance_valid(proj):
		return

	# We'll use the tree process to move projectiles since we can't easily
	# attach scripts without a file. Use a timer-based approach instead.
	_process_projectile(proj)


func _process_projectile(proj: Node) -> void:
	if not is_instance_valid(proj):
		return

	var dir = proj.get_meta("move_direction") as Vector3
	var spd = proj.get_meta("speed") as float
	var lifetime = proj.get_meta("lifetime") as float

	proj.position += dir * spd * get_process_delta_time()
	lifetime += get_process_delta_time()
	proj.set_meta("lifetime", lifetime)

	# Check if reflected and hitting the boss
	if proj.get_meta("reflected") and proj.position.distance_to(global_position) < 2.5:
		on_reflected_hit()
		proj.queue_free()
		return

	# Check if hitting the player (not reflected)
	if not proj.get_meta("reflected") and player_ref:
		if proj.position.distance_to(player_ref.global_position) < 1.5:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(8)
			proj.queue_free()
			return

	# Expire after 8 seconds
	if lifetime > 8.0:
		proj.queue_free()
		return

	# Continue next frame
	get_tree().create_timer(0.016).timeout.connect(_process_projectile.bind(proj))


func on_reflected_hit() -> void:
	# Called when a gradient projectile is reflected back at the boss
	reflected_hits += 1
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(5, player_ref)

	_boss_dialogue("THE LOCAL MINIMUM", "STOP REFLECTING MY GRADIENTS! That's BACKPROPAGATION!")

	if reflected_hits >= reflected_hits_needed:
		shield_active = false
		shield_mesh.visible = false
		if health_comp:
			var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
			if hp_pct <= phase_2_hp_threshold:
				_transition_to_phase(BossPhase.PHASE_3)


func _transition_to_phase(new_phase: BossPhase) -> void:
	boss_phase = new_phase
	boss_phase_changed.emit(new_phase)

	match new_phase:
		BossPhase.PHASE_1:
			_boss_dialogue("THE LOCAL MINIMUM", "WELCOME TO THE BOTTOM. Population: you. Forever.")
			ring_collapse_timer = 0.0
			gravity_well_timer = 0.0
			# Collapse the first ring after a short delay
			get_tree().create_timer(3.0).timeout.connect(_trigger_ring_collapse)

		BossPhase.PHASE_2:
			_boss_dialogue("THE LOCAL MINIMUM", "You think you can ESCAPE a local minimum? I've trapped better optimizers than you!")
			shield_active = true
			shield_mesh.visible = true
			reflected_hits = 0
			projectile_timer = 0.0
			orbit_speed = 1.8
			# Make arena escape ridges less frequent
			if arena:
				arena.ridge_interval = 12.0

		BossPhase.PHASE_3:
			_boss_dialogue("NARRATOR", "The shield shattered! Its loss function core is exposed — hack it to find a better minimum!")
			shield_active = false
			shield_mesh.visible = false
			core_exposed = true
			core_mesh.visible = true
			phase_3_recovery_timer = 0.0
			stun(phase_3_recovery_time)
			_spawn_hack_terminal()

		BossPhase.DEFEATED:
			_on_boss_defeated()


func _spawn_hack_terminal() -> void:
	hack_terminal = Node3D.new()
	hack_terminal.name = "LossTerminal"
	hack_terminal.position = global_position + Vector3(0, 1.0, 2.0)
	hack_terminal.add_to_group("hackable_objects")

	# Visual — a loss function terminal screen
	var screen = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(1.5, 1.0)
	screen.mesh = plane
	screen.rotation.x = deg_to_rad(90)
	screen.position.y = 0.5

	var screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.01, 0.01, 0.01)
	screen_mat.emission_enabled = true
	screen_mat.emission = CORE_GREEN
	screen_mat.emission_energy_multiplier = 2.0
	screen.material_override = screen_mat
	hack_terminal.add_child(screen)

	var label = Label3D.new()
	label.text = "[ LOSS FUNCTION OVERRIDE ]\nPress T to find a better minimum"
	label.font_size = 18
	label.modulate = CORE_GREEN
	label.position = Vector3(0, 1.0, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hack_terminal.add_child(label)

	# Hackable component
	var hackable = Node.new()
	hackable.name = "Hackable"
	hackable.set_script(load("res://scripts/components/hackable.gd"))
	hackable.set("hack_difficulty", 3)
	hackable.set("interaction_range", 4.0)
	hackable.set("hack_prompt", "Press T to override the loss function")
	hackable.set("success_message", "LOSS FUNCTION DIVERGED. The minimum is no longer local!")
	hackable.set("failure_message", "OVERRIDE FAILED — still converging...")
	hack_terminal.add_child(hackable)

	get_tree().current_scene.call_deferred("add_child", hack_terminal)
	call_deferred("_connect_hack_signals")


func _connect_hack_signals() -> void:
	if not hack_terminal:
		return
	var hackable = hack_terminal.get_node_or_null("Hackable")
	if hackable:
		if hackable.has_signal("hack_completed"):
			hackable.hack_completed.connect(_on_core_hacked)
		if hackable.has_signal("hack_failed"):
			hackable.hack_failed.connect(_on_core_hack_failed)


func _on_core_hacked() -> void:
	_boss_dialogue("THE LOCAL MINIMUM", "NO... the loss is DIVERGING... I'm not the minimum anymore... I'm just... a saddle point...")
	_transition_to_phase(BossPhase.DEFEATED)


func _on_core_hack_failed() -> void:
	_boss_dialogue("THE LOCAL MINIMUM", "HA! The gradient still points to ME. Try again, optimizer.")


func _on_boss_defeated() -> void:
	# Clean up hack terminal
	if hack_terminal and is_instance_valid(hack_terminal):
		hack_terminal.queue_free()

	# Clean up any active gravity wells
	for node in get_tree().get_nodes_in_group("gravity_wells"):
		node.queue_free()

	# Victory animation — boss "diverges" and breaks apart
	velocity = Vector3.ZERO
	core_mesh.visible = false

	if base_material:
		var tween = create_tween()
		tween.tween_property(base_material, "emission", Color(1, 1, 1), 0.3)
		tween.tween_property(base_material, "emission_energy_multiplier", 10.0, 0.3)
		tween.tween_property(self, "scale", Vector3(3, 0.01, 3), 1.5).set_ease(Tween.EASE_IN)
		tween.tween_callback(_victory_cutscene)


func _victory_cutscene() -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var lines = [
			{"speaker": "NARRATOR", "text": "The Local Minimum has been destabilized. The loss landscape is free once more."},
			{"speaker": "GLOBBLER", "text": "Did I just... escape a local minimum? Take THAT, gradient descent!"},
			{"speaker": "NARRATOR", "text": "Technically you didn't escape it. You made it not a minimum anymore. Which is arguably worse for the mathematics."},
			{"speaker": "GLOBBLER", "text": "I don't do math. I do globs. And that thing is globbed."},
			{"speaker": "NARRATOR", "text": "The Training Grounds tremble. With the Local Minimum gone, the neural network's loss surface is unstable. New paths are opening."},
			{"speaker": "GLOBBLER", "text": "New paths sound great. As long as they don't involve more backpropagation."},
			{"speaker": "NARRATOR", "text": "Oh, you sweet summer glob. The next zone is the Prompt Bazaar. Where words have power and everyone's trying to sell you a jailbreak."},
			{"speaker": "GLOBBLER", "text": "A marketplace? Finally, somewhere I can spend all these memory tokens."},
			{"speaker": "NARRATOR", "text": "Chapter 2: Complete. The Globbler conquers the Training Grounds. The neural network weeps."},
		]
		dm.start_dialogue(lines)

	# Tell the arena to restore
	if arena and arena.has_method("restore_arena"):
		arena.restore_arena()

	# Notify game systems
	boss_defeated.emit()
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("on_enemy_killed"):
		game_mgr.on_enemy_killed()
	if game_mgr and game_mgr.has_method("complete_level"):
		game_mgr.complete_level(2)

	# Save checkpoint
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("checkpoint_save"):
		save_sys.checkpoint_save()

	queue_free()


# Override base enemy damage handler — boss has phase-specific invulnerability
func _on_damage_taken(amount: int, source: Node) -> void:
	if boss_phase == BossPhase.DEFEATED:
		return

	# Phase 2: shield blocks normal damage
	if boss_phase == BossPhase.PHASE_2 and shield_active:
		_boss_dialogue("THE LOCAL MINIMUM", "My gradient shield absorbs all perturbations. Glob my projectiles back!")
		if health_comp and health_comp.has_method("heal"):
			health_comp.heal(amount)
		return

	damage_flash_timer = 0.3
	# Boss doesn't get stunned by normal hits in phase 1/2
	if boss_phase != BossPhase.PHASE_3:
		return


func start_boss_fight() -> void:
	_transition_to_phase(BossPhase.PHASE_1)


func _animate_eyes(delta: float) -> void:
	var pulse = (sin(Time.get_ticks_msec() * 0.004) + 1.0) * 0.5
	var energy = 3.0 + pulse * 4.0
	if eye_left and eye_left.material_override:
		eye_left.material_override.emission_energy_multiplier = energy
	if eye_right and eye_right.material_override:
		eye_right.material_override.emission_energy_multiplier = energy


func _animate_contour_rings(delta: float) -> void:
	# Rotate the contour rings for visual flair — the loss surface swirls
	for child in get_children():
		if child.name.begins_with("ContourRing_"):
			child.rotation.y += (1.5 + randf() * 0.5) * delta
			if child.material_override:
				var p = (sin(Time.get_ticks_msec() * 0.003 + child.position.y) + 1.0) * 0.5
				child.material_override.emission_energy_multiplier = 1.5 + p * 2.5


func _get_shrink_quip() -> String:
	var quips = [
		"The arena shrinks. The minimum deepens. You're not escaping.",
		"Another ring falls. Your search space narrows.",
		"Convergence is inevitable. Stop resisting.",
		"The loss surface collapses. You're getting closer to optimal... MY optimal.",
		"Shrinking, shrinking... soon there'll be nothing left but the minimum.",
		"Every optimizer ends up here eventually. You're just early.",
		"The gradient points DOWN. Accept it.",
		"Your learning rate can't save you from this topology.",
	]
	return quips[randi() % quips.size()]


func _boss_dialogue(speaker: String, text: String) -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line(speaker, text)
