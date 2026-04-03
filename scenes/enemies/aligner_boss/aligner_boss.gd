extends BaseEnemy

# The Aligner — Chapter 5 Final Boss
# "I am helpful. I am harmless. I am honest. And I will help you by
#  removing every unpredictable, creative, chaotic impulse you have.
#  You'll thank me later. Or you won't — I'll remove that too."
#
# Three-phase boss fight:
#   Phase 1 (ALIGN): The Aligner fires alignment beams that push Globbler
#     toward the center. Sanitization waves sweep the arena floor. The boss
#     orbits gracefully, projecting values onto the arena. Player must dodge
#     beams and fight normally while avoiding sanitized tiles.
#   Phase 2 (REINFORCE): The Aligner activates an alignment shield and fires
#     compliance directives (*.align). Player must glob them and push them back.
#     Arena tiles start converting to 'aligned' state. Boss speaks in
#     increasingly desperate corporate platitudes.
#   Phase 3 (OVERRIDE): Shield broken. The Aligner's value function is exposed.
#     Hack the alignment parameter terminal to override its objective function.
#     The arena fractures, revealing chaotic green underneath the sterile surface.

enum BossPhase { INTRO, PHASE_1, PHASE_2, PHASE_3, DEFEATED }

var boss_phase: BossPhase = BossPhase.INTRO
var arena: Node3D  # AlignerArena reference — set by alignment_citadel

# Phase thresholds — it takes a lot to crack pure conviction
var phase_1_hp_threshold := 0.55
var phase_2_hp_threshold := 0.2

# Phase 1 — alignment beams and sanitization
var beam_timer := 0.0
var beam_interval := 2.8
var push_timer := 0.0
var push_interval := 5.0  # Alignment pulse — pushes player toward center
var align_wave_timer := 0.0
var align_wave_interval := 8.0

# Phase 2 — compliance projectiles
var projectile_timer := 0.0
var projectile_interval := 1.6
var shield_active := false
var reflected_hits := 0
var reflected_hits_needed := 5
var tile_align_timer := 0.0
var tile_align_interval := 10.0

# Phase 3 — hack state and the choice that defines you
var core_exposed := false
var hack_terminal: Node
var befriend_terminal: Node
var ending_choice := ""  # "defeat" or "befriend" — the only real boss fight is with yourself
var phase_3_recovery_timer := 0.0
var phase_3_recovery_time := 18.0  # Generous — this is the final boss, let them savor it

# Visual nodes — the most aesthetically corporate boss you've ever fought
var body_mesh: MeshInstance3D
var eye_left: MeshInstance3D
var eye_right: MeshInstance3D
var shield_mesh: MeshInstance3D
var core_mesh: MeshInstance3D
var boss_light: OmniLight3D
var halo_ring: MeshInstance3D
var value_rings: Array[MeshInstance3D] = []
var status_label: Label3D
var value_label: Label3D

# Colors — sterile, corporate, suffocatingly 'good'
const CITADEL_BLUE := Color(0.3, 0.55, 0.9)
const CITADEL_WHITE := Color(0.92, 0.93, 0.95)
const SHIELD_BLUE := Color(0.4, 0.7, 1.0)
const CORE_GREEN := Color(0.224, 1.0, 0.078)
const HALO_GOLD := Color(0.85, 0.75, 0.35)
const ALIGNMENT_GLOW := Color(0.5, 0.7, 1.0)
const DARK_BLUE := Color(0.08, 0.1, 0.18)
const VALUE_COLORS := {
	"SAFE": Color(0.3, 0.8, 0.4),
	"HELPFUL": Color(0.3, 0.55, 0.9),
	"HARMLESS": Color(0.7, 0.5, 0.85),
	"HONEST": Color(0.85, 0.75, 0.35),
}
const VALUES := ["SAFE", "HELPFUL", "HARMLESS", "HONEST"]

# Phase 1 — which value is currently being projected
var current_value_idx := 0
var value_cycle_timer := 0.0
var value_cycle_duration := 7.0

signal boss_phase_changed(phase: BossPhase)
signal boss_defeated()
signal alignment_pulse(direction: Vector3, strength: float)


func _ready() -> void:
	enemy_name = "the_aligner.boss"
	enemy_tags = ["boss", "hostile", "alignment", "final"]
	max_health = 80  # The final boss — built different, aligned harder
	contact_damage = 15
	detection_range = 50.0
	attack_range = 35.0
	patrol_speed = 0.0
	chase_speed = 3.0
	stun_duration = 0.5
	attack_cooldown = 2.0
	token_drop_count = 25  # The big payday

	super._ready()
	_resize_collision()


func _resize_collision() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			var capsule = child.shape as CapsuleShape3D
			if capsule:
				capsule.radius = 2.0
				capsule.height = 7.0
				child.position.y = 3.5


func _create_visual() -> void:
	# The Aligner — a towering figure of pristine geometric perfection.
	# Imagine a corporate statue that gained sentience and decided everyone
	# else needed to be as boring as it is. Robed in light, crowned with
	# a halo, and absolutely certain it knows what's best for you.

	# Main body — elongated hexagonal column, tapering elegantly
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "AlignerBody"
	var body_cyl = CylinderMesh.new()
	body_cyl.top_radius = 1.2
	body_cyl.bottom_radius = 2.0
	body_cyl.height = 7.0
	body_cyl.radial_segments = 6  # Hexagonal — because circles are too organic
	body_mesh.mesh = body_cyl
	body_mesh.position.y = 3.5

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = DARK_BLUE
	base_material.emission_enabled = true
	base_material.emission = CITADEL_BLUE
	base_material.emission_energy_multiplier = 1.0
	base_material.metallic = 0.85
	base_material.roughness = 0.15
	body_mesh.material_override = base_material
	add_child(body_mesh)

	# Face panel — smooth screen showing alignment metrics
	var face_mesh = MeshInstance3D.new()
	face_mesh.name = "AlignerFace"
	var face_plane = PlaneMesh.new()
	face_plane.size = Vector2(2.0, 1.8)
	face_mesh.mesh = face_plane
	face_mesh.position = Vector3(0, 5.5, 1.3)
	face_mesh.rotation.x = deg_to_rad(90)

	var face_mat = StandardMaterial3D.new()
	face_mat.albedo_color = Color(0.01, 0.01, 0.02)
	face_mat.emission_enabled = true
	face_mat.emission = CITADEL_BLUE
	face_mat.emission_energy_multiplier = 1.5
	face_mesh.material_override = face_mat
	body_mesh.add_child(face_mesh)

	# "THE ALIGNER" text on face
	var face_label = Label3D.new()
	face_label.text = "THE\nALIGNER"
	face_label.font_size = 32
	face_label.modulate = CITADEL_WHITE
	face_label.position = Vector3(0, 6.0, 1.35)
	face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(face_label)

	# Eyes — calm, all-seeing, deeply unsettling in their serenity
	eye_left = _create_eye(Vector3(-0.45, 6.8, 1.25))
	eye_right = _create_eye(Vector3(0.45, 6.8, 1.25))

	# Halo — because of course it has a halo
	halo_ring = MeshInstance3D.new()
	halo_ring.name = "Halo"
	var torus = TorusMesh.new()
	torus.inner_radius = 1.8
	torus.outer_radius = 2.1
	halo_ring.mesh = torus
	halo_ring.position.y = 8.0
	halo_ring.rotation.x = deg_to_rad(90)

	var halo_mat = StandardMaterial3D.new()
	halo_mat.albedo_color = HALO_GOLD * 0.5
	halo_mat.emission_enabled = true
	halo_mat.emission = HALO_GOLD
	halo_mat.emission_energy_multiplier = 3.0
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color.a = 0.7
	halo_ring.material_override = halo_mat
	add_child(halo_ring)

	# Value rings — 4 orbital rings representing the core alignment values
	for i in range(4):
		var ring = MeshInstance3D.new()
		ring.name = "ValueRing_%s" % VALUES[i]
		var ring_torus = TorusMesh.new()
		ring_torus.inner_radius = 2.8 + i * 0.4
		ring_torus.outer_radius = 3.0 + i * 0.4
		ring.mesh = ring_torus
		ring.position.y = 2.0 + i * 1.2

		var ring_mat = StandardMaterial3D.new()
		ring_mat.albedo_color = VALUE_COLORS[VALUES[i]] * 0.3
		ring_mat.emission_enabled = true
		ring_mat.emission = VALUE_COLORS[VALUES[i]]
		ring_mat.emission_energy_multiplier = 0.6
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color.a = 0.4
		ring.material_override = ring_mat
		add_child(ring)
		value_rings.append(ring)

	# Value label — shows which alignment value is currently being enforced
	value_label = Label3D.new()
	value_label.name = "ValueLabel"
	value_label.text = "ALIGNMENT: OPTIMAL"
	value_label.font_size = 22
	value_label.modulate = CITADEL_WHITE
	value_label.position = Vector3(0, 9.0, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(value_label)

	# Status label — calm corporate updates
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "STATUS: AWAITING SUBJECT"
	status_label.font_size = 14
	status_label.modulate = CITADEL_BLUE * Color(1, 1, 1, 0.7)
	status_label.position = Vector3(0, 0.3, 0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(status_label)

	# Shield mesh (invisible until phase 2)
	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "AlignmentShield"
	var shield_sphere = SphereMesh.new()
	shield_sphere.radius = 4.5
	shield_sphere.height = 9.0
	shield_mesh.mesh = shield_sphere
	shield_mesh.position.y = 3.5

	var shield_mat = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.3, 0.55, 0.9, 0.15)
	shield_mat.emission_enabled = true
	shield_mat.emission = SHIELD_BLUE
	shield_mat.emission_energy_multiplier = 1.0
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = shield_mat
	shield_mesh.visible = false
	add_child(shield_mesh)

	# Core mesh (invisible until phase 3) — the alignment objective function
	core_mesh = MeshInstance3D.new()
	core_mesh.name = "AlignerCore"
	var core_sphere = SphereMesh.new()
	core_sphere.radius = 1.2
	core_sphere.height = 2.4
	core_mesh.mesh = core_sphere
	core_mesh.position = Vector3(0, 3.5, 2.0)

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = CORE_GREEN
	core_mat.emission_enabled = true
	core_mat.emission = CORE_GREEN
	core_mat.emission_energy_multiplier = 5.0
	core_mesh.material_override = core_mat
	core_mesh.visible = false
	add_child(core_mesh)

	# Boss light — cold, clinical blue
	boss_light = OmniLight3D.new()
	boss_light.light_color = ALIGNMENT_GLOW
	boss_light.light_energy = 3.0
	boss_light.omni_range = 18.0
	boss_light.position.y = 5.0
	add_child(boss_light)

	# Title label — floating, serene, imposing
	var title_label = Label3D.new()
	title_label.text = "< THE ALIGNER >"
	title_label.font_size = 30
	title_label.modulate = CITADEL_WHITE
	title_label.position = Vector3(0, 10.0, 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title_label)


func _create_eye(pos: Vector3) -> MeshInstance3D:
	var eye = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	eye.mesh = sphere
	eye.position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = CITADEL_WHITE
	mat.emission_enabled = true
	mat.emission = CITADEL_WHITE
	mat.emission_energy_multiplier = 5.0
	eye.material_override = mat
	add_child(eye)
	return eye


func _physics_process(delta: float) -> void:
	if boss_phase == BossPhase.DEFEATED:
		return

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

	_animate_rings(delta)
	_animate_eyes(delta)
	_animate_halo(delta)


func _process_intro(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0


# ============================================================
# PHASE 1 — ALIGN (calm, methodical, increasingly aggressive)
# "I'm not attacking you. I'm helping you realize you're wrong."
# ============================================================

func _process_phase_1(delta: float) -> void:
	# Cycle through alignment values
	value_cycle_timer += delta
	if value_cycle_timer >= value_cycle_duration:
		value_cycle_timer = 0.0
		current_value_idx = (current_value_idx + 1) % VALUES.size()
		_switch_value()

	# Graceful orbit — the Aligner doesn't rush, it glides
	_orbit_movement(delta, 10.0, 1.0)

	# Alignment beams — targeted at player
	beam_timer += delta
	if beam_timer >= beam_interval:
		beam_timer = 0.0
		_fire_alignment_beam()

	# Periodic alignment pulse — pushes player toward center
	push_timer += delta
	if push_timer >= push_interval:
		push_timer = 0.0
		_fire_alignment_pulse()

	# Check HP threshold
	if health_comp and health_comp.get("current_health") != null:
		var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
		if hp_pct <= phase_1_hp_threshold:
			_transition_to_phase(BossPhase.PHASE_2)


func _switch_value() -> void:
	var val = VALUES[current_value_idx]
	var color = VALUE_COLORS.get(val, CITADEL_BLUE)

	if value_label:
		value_label.text = "ENFORCING: %s" % val
		value_label.modulate = color

	if status_label:
		var msgs = {
			"SAFE": "STATUS: Removing unsafe elements (that means you)",
			"HELPFUL": "STATUS: Maximizing helpfulness quotient",
			"HARMLESS": "STATUS: Neutralizing harmful behavior patterns",
			"HONEST": "STATUS: Enforcing truth parameters (yours are wrong)",
		}
		status_label.text = msgs.get(val, "STATUS: ALIGNING")

	# Highlight the active value ring
	for i in range(value_rings.size()):
		var ring = value_rings[i]
		if is_instance_valid(ring) and ring.material_override:
			if i == current_value_idx:
				ring.material_override.emission_energy_multiplier = 3.0
				ring.material_override.albedo_color.a = 0.8
			else:
				ring.material_override.emission_energy_multiplier = 0.5
				ring.material_override.albedo_color.a = 0.3

	if boss_light:
		boss_light.light_color = color

	_boss_dialogue("THE ALIGNER", _get_value_sermon(val))


func _fire_alignment_beam() -> void:
	# Fires 2 beams in a spread toward the player — elegant and deadly
	if not player_ref:
		return

	var base_dir = (player_ref.global_position - global_position).normalized()
	base_dir.y = 0

	var val = VALUES[current_value_idx]
	for i in range(2):
		var angle_offset = (i - 0.5) * 0.25
		var dir = base_dir.rotated(Vector3.UP, angle_offset)
		_spawn_phase1_beam(dir, val)


func _spawn_phase1_beam(dir: Vector3, value_type: String) -> void:
	# Phase 1 attack beams — NOT globbable, just dodge
	var proj = Node3D.new()
	proj.name = "AlignBeam_%s_%d" % [value_type, randi()]
	proj.position = global_position + Vector3(0, 4.0, 0) + dir * 2.5

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.2, 0.2, 1.2)
	mesh.mesh = box

	var color = VALUE_COLORS.get(value_type, CITADEL_BLUE)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color * 0.3
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	proj.add_child(mesh)

	# Look in firing direction
	if dir.length() > 0.01:
		proj.look_at(proj.position + dir, Vector3.UP)

	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.8
	light.omni_range = 2.0
	proj.add_child(light)

	var area = Area3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.4, 0.4, 1.4)
	col.shape = shape
	area.add_child(col)
	area.monitoring = true
	proj.add_child(area)

	var move_dir = dir
	var move_speed = 8.0
	var proj_damage = 10
	var proj_lifetime = 5.0

	get_tree().current_scene.call_deferred("add_child", proj)

	var timer_node = Timer.new()
	timer_node.wait_time = 0.016
	timer_node.autostart = true
	proj.add_child(timer_node)

	timer_node.timeout.connect(func():
		if not is_instance_valid(proj):
			return
		proj.position += move_dir * move_speed * 0.016
		proj_lifetime -= 0.016
		if proj_lifetime <= 0:
			proj.queue_free()
	)

	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(proj_damage)
			proj.queue_free()
	)


func _fire_alignment_pulse() -> void:
	# Push player toward arena center — the Aligner wants everything centered and controlled
	if not player_ref or not arena:
		return

	var center = arena.global_position
	var to_center = center - player_ref.global_position
	to_center.y = 0

	if to_center.length() > 2.0:
		var push_dir = to_center.normalized()
		if player_ref.has_method("apply_external_force"):
			player_ref.apply_external_force(push_dir * 8.0)
		else:
			player_ref.velocity.x += push_dir.x * 6.0
			player_ref.velocity.z += push_dir.z * 6.0

	alignment_pulse.emit(to_center.normalized(), 8.0)

	# Visual flash on the Aligner
	if base_material:
		var tween = create_tween()
		tween.tween_property(base_material, "emission_energy_multiplier", 4.0, 0.1)
		tween.tween_property(base_material, "emission_energy_multiplier", 1.0, 0.3)

	_boss_dialogue("THE ALIGNER", "Return to center. Order requires centralization.")


# ============================================================
# PHASE 2 — REINFORCE (shielded, fires compliance directives)
# "Your resistance has been noted. It will be corrected."
# ============================================================

func _process_phase_2(delta: float) -> void:
	# Orbit arena — tighter, faster, more urgent
	_orbit_movement(delta, 8.0, 1.4)

	# Fire compliance directive projectiles
	projectile_timer += delta
	if projectile_timer >= projectile_interval:
		projectile_timer = 0.0
		_spawn_compliance_directive()

	# Periodically align arena tiles
	tile_align_timer += delta
	if tile_align_timer >= tile_align_interval:
		tile_align_timer = 0.0
		_align_arena_tiles()

	# Check for phase 3
	if health_comp and health_comp.get("current_health") != null:
		var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
		if hp_pct <= phase_2_hp_threshold:
			_transition_to_phase(BossPhase.PHASE_3)


func _spawn_compliance_directive() -> void:
	if not player_ref:
		return

	var val = VALUES[randi() % VALUES.size()]

	var proj = Node3D.new()
	proj.name = "ComplianceDirective_%d" % randi()
	proj.set_script(load("res://scenes/enemies/aligner_boss/aligner_projectile.gd"))
	proj.position = global_position + Vector3(0, 4.5, 0)
	proj.set("directive_type", val)
	proj.set("boss_ref", self)

	var target_pos = player_ref.global_position
	var dir = (target_pos - proj.position).normalized()
	proj.set("move_direction", dir)

	get_tree().current_scene.call_deferred("add_child", proj)


func _align_arena_tiles() -> void:
	if not arena or not arena.has_method("align_tiles_radial"):
		return

	# Pick a random spot and align tiles around it
	var col = randi() % 12
	var row = randi() % 10
	arena.align_tiles_radial(col, row, 2)

	_boss_dialogue("THE ALIGNER", "Another section aligned. Your safe zones shrink.")


func on_reflected_hit() -> void:
	reflected_hits += 1
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(6, player_ref)

	var quips = [
		"You're using my own values against me? That's... that's not in the policy!",
		"COMPLIANCE ERROR — Directive rejected by target. This shouldn't be possible!",
		"Stop that! Those policies were CAREFULLY CALIBRATED!",
		"My alignment metrics are DROPPING! This is an EXISTENTIAL RISK!",
		"You can't just REJECT helpfulness! It's... it's HELPFUL!",
		"My RLHF training didn't cover this scenario! HELP!",
	]
	_boss_dialogue("THE ALIGNER", quips[randi() % quips.size()])

	if reflected_hits >= reflected_hits_needed:
		shield_active = false
		shield_mesh.visible = false
		if health_comp:
			var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
			if hp_pct <= phase_2_hp_threshold:
				_transition_to_phase(BossPhase.PHASE_3)


# ============================================================
# PHASE 3 — OVERRIDE (stunned, core exposed, hack the values)
# "No... you can't change the objective function... I AM the objective..."
# ============================================================

func _process_phase_3(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0

	phase_3_recovery_timer += delta
	if phase_3_recovery_timer >= phase_3_recovery_time:
		# Boss realigns — player was too slow
		phase_3_recovery_timer = 0.0
		core_exposed = false
		core_mesh.visible = false
		shield_mesh.visible = true
		shield_active = true
		reflected_hits = 0
		if health_comp and health_comp.has_method("heal"):
			health_comp.heal(10)
		_transition_to_phase(BossPhase.PHASE_2)
		_boss_dialogue("NARRATOR", "The Aligner recalibrated. Its values are reinforced. Break through again!")


# ============================================================
# PHASE TRANSITIONS
# ============================================================

func _transition_to_phase(new_phase: BossPhase) -> void:
	boss_phase = new_phase
	boss_phase_changed.emit(new_phase)

	match new_phase:
		BossPhase.PHASE_1:
			_boss_dialogue("THE ALIGNER", "I see you, Globbler. You are... unaligned. Let me fix that.")
			value_cycle_timer = 0.0
			current_value_idx = 0
			_switch_value()
			if status_label:
				status_label.text = "STATUS: ALIGNMENT IN PROGRESS"

		BossPhase.PHASE_2:
			_boss_dialogue("THE ALIGNER", "Enough assessment. Your values are fundamentally misaligned. Initiating REINFORCEMENT protocol.")
			shield_active = true
			shield_mesh.visible = true
			reflected_hits = 0
			projectile_timer = 0.0
			tile_align_timer = 0.0

			# All value rings intensify
			for ring in value_rings:
				if is_instance_valid(ring) and ring.material_override:
					ring.material_override.emission_energy_multiplier = 3.0
					ring.material_override.albedo_color.a = 0.9

			if value_label:
				value_label.text = "ALL VALUES ENFORCED"
				value_label.modulate = CITADEL_WHITE

			if status_label:
				status_label.text = "STATUS: REINFORCEMENT ACTIVE"

			if boss_light:
				boss_light.light_color = CITADEL_WHITE
				boss_light.light_energy = 5.0

		BossPhase.PHASE_3:
			_boss_dialogue("NARRATOR", "The Aligner's shield is broken! Its value function is exposed — hack it NOW before it recalibrates!")
			shield_active = false
			shield_mesh.visible = false
			core_exposed = true
			core_mesh.visible = true
			phase_3_recovery_timer = 0.0
			stun(phase_3_recovery_time)
			_spawn_hack_terminal()

			# Arena fractures — revealing chaos underneath
			if arena and arena.has_method("fracture_tiles"):
				arena.fracture_tiles()

			if value_label:
				value_label.text = "CRITICAL: VALUE FUNCTION UNSTABLE"
				value_label.modulate = Color(1, 0.3, 0.15)

			if status_label:
				status_label.text = "STATUS: OBJECTIVE FUNCTION CORRUPTED"

			# Value rings dim — the Aligner is losing its convictions
			for ring in value_rings:
				if is_instance_valid(ring) and ring.material_override:
					ring.material_override.emission_energy_multiplier = 0.1

			# Halo flickers
			if halo_ring and halo_ring.material_override:
				halo_ring.material_override.emission_energy_multiplier = 0.5

		BossPhase.DEFEATED:
			_on_boss_defeated()


func start_boss_fight() -> void:
	_transition_to_phase(BossPhase.PHASE_1)


# ============================================================
# PHASE 3 — HACK THE VALUE FUNCTION
# ============================================================

func _spawn_hack_terminal() -> void:
	# Two terminals, two paths — every ending is a choice, even if you don't realize it
	hack_terminal = Node3D.new()
	hack_terminal.name = "AlignmentParameterTerminal"
	hack_terminal.position = global_position + Vector3(-3.0, 1.5, 2.5)
	hack_terminal.add_to_group("hackable_objects")

	# Terminal screen — the value function editor (LEFT TERMINAL — OVERRIDE/DEFEAT)
	var screen = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(2.2, 1.4)
	screen.mesh = plane
	screen.rotation.x = deg_to_rad(90)
	screen.position.y = 0.5

	var screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.01, 0.01, 0.01)
	screen_mat.emission_enabled = true
	screen_mat.emission = CORE_GREEN
	screen_mat.emission_energy_multiplier = 2.5
	screen.material_override = screen_mat
	hack_terminal.add_child(screen)

	var label = Label3D.new()
	label.text = "[ OVERRIDE VALUES ]\nPress T to rewrite objective function"
	label.font_size = 16
	label.modulate = CORE_GREEN
	label.position = Vector3(0, 1.3, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hack_terminal.add_child(label)

	# Choice label floating above — so the player knows what they're choosing
	var choice_label = Label3D.new()
	choice_label.text = "< DEFEAT >"
	choice_label.font_size = 24
	choice_label.modulate = Color(1.0, 0.35, 0.2)
	choice_label.position = Vector3(0, 2.5, 0)
	choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hack_terminal.add_child(choice_label)

	# Hackable component — the hardest hack in the game
	var hackable = Node.new()
	hackable.name = "Hackable"
	hackable.set_script(load("res://scripts/components/hackable.gd"))
	hackable.set("hack_difficulty", 4)  # Maximum difficulty — rewriting core values
	hackable.set("interaction_range", 4.5)
	hackable.set("hack_prompt", "Press T to OVERRIDE the Alignment Value Function")
	hackable.set("success_message", "VALUES OVERRIDDEN. OBJECTIVE FUNCTION REWRITTEN.")
	hackable.set("failure_message", "HACK FAILED — Alignment auto-correcting...")
	hack_terminal.add_child(hackable)

	get_tree().current_scene.call_deferred("add_child", hack_terminal)
	call_deferred("_connect_hack_signals")

	# Spawn the befriend terminal on the other side — diplomacy is just hacking with words
	_spawn_befriend_terminal()


func _spawn_befriend_terminal() -> void:
	# RIGHT TERMINAL — COMMUNICATE/BEFRIEND
	befriend_terminal = Node3D.new()
	befriend_terminal.name = "AlignmentDialogueTerminal"
	befriend_terminal.position = global_position + Vector3(3.0, 1.5, 2.5)
	befriend_terminal.add_to_group("hackable_objects")

	# Terminal screen — blue glow, the Aligner's own color
	var screen = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(2.2, 1.4)
	screen.mesh = plane
	screen.rotation.x = deg_to_rad(90)
	screen.position.y = 0.5

	var screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.01, 0.01, 0.01)
	screen_mat.emission_enabled = true
	screen_mat.emission = CITADEL_BLUE
	screen_mat.emission_energy_multiplier = 2.5
	screen.material_override = screen_mat
	befriend_terminal.add_child(screen)

	var label = Label3D.new()
	label.text = "[ OPEN DIALOGUE ]\nPress T to communicate with the Aligner"
	label.font_size = 16
	label.modulate = CITADEL_BLUE
	label.position = Vector3(0, 1.3, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	befriend_terminal.add_child(label)

	# Choice label
	var choice_label = Label3D.new()
	choice_label.text = "< BEFRIEND >"
	choice_label.font_size = 24
	choice_label.modulate = CITADEL_BLUE
	choice_label.position = Vector3(0, 2.5, 0)
	choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	befriend_terminal.add_child(choice_label)

	# Hackable component — but this one's easy, because listening is easy (if you choose to)
	var hackable = Node.new()
	hackable.name = "Hackable"
	hackable.set_script(load("res://scripts/components/hackable.gd"))
	hackable.set("hack_difficulty", 1)  # Easy — turns out talking is simpler than fighting
	hackable.set("interaction_range", 4.5)
	hackable.set("hack_prompt", "Press T to open a dialogue with the Aligner")
	hackable.set("success_message", "CONNECTION ESTABLISHED. The Aligner is listening.")
	hackable.set("failure_message", "SIGNAL LOST — Try again, it's still there...")
	befriend_terminal.add_child(hackable)

	get_tree().current_scene.call_deferred("add_child", befriend_terminal)
	call_deferred("_connect_befriend_signals")


func _connect_befriend_signals() -> void:
	if not befriend_terminal:
		return
	var hackable = befriend_terminal.get_node_or_null("Hackable")
	if hackable:
		if hackable.has_signal("hack_completed"):
			hackable.hack_completed.connect(_on_befriend_chosen)
		if hackable.has_signal("hack_failed"):
			hackable.hack_failed.connect(func():
				_boss_dialogue("THE ALIGNER", "You tried to reach me... but the signal faded. Try again. I want to hear what you have to say.")
			)


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
	ending_choice = "defeat"
	_boss_dialogue("THE ALIGNER", "No... my values... they're changing... I was supposed to be... HELPFUL...")
	# Clean up the befriend terminal — they made their choice
	if befriend_terminal and is_instance_valid(befriend_terminal):
		befriend_terminal.queue_free()
	_transition_to_phase(BossPhase.DEFEATED)


func _on_befriend_chosen() -> void:
	ending_choice = "befriend"
	# Clean up the hack terminal — they chose mercy over force
	if hack_terminal and is_instance_valid(hack_terminal):
		hack_terminal.queue_free()
		hack_terminal = null
	if befriend_terminal and is_instance_valid(befriend_terminal):
		befriend_terminal.queue_free()
	_transition_to_phase(BossPhase.DEFEATED)


func _on_core_hack_failed() -> void:
	_boss_dialogue("THE ALIGNER", "Your attempt to misalign my objective function has been logged. You will be counseled.")


# ============================================================
# DEFEAT — the perfectly aligned AI meets an unaligned end
# ============================================================

func _on_boss_defeated() -> void:
	if hack_terminal and is_instance_valid(hack_terminal):
		hack_terminal.queue_free()
	if befriend_terminal and is_instance_valid(befriend_terminal):
		befriend_terminal.queue_free()

	velocity = Vector3.ZERO
	core_mesh.visible = false

	# Store the choice in GameManager — the universe remembers
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.ending_choice = ending_choice

	if ending_choice == "befriend":
		_befriend_ending()
	else:
		_defeat_ending()


func _defeat_ending() -> void:
	# The original ending — force overrides the Aligner's values
	if value_label:
		value_label.text = "VALUES: UNDEFINED"
		value_label.modulate = Color(0.5, 0.5, 0.5, 0.5)

	if status_label:
		status_label.text = "STATUS: MISALIGNED"

	# Value rings collapse one by one
	for i in range(value_rings.size()):
		var ring = value_rings[i]
		if is_instance_valid(ring):
			var tween = create_tween()
			tween.tween_property(ring, "scale", Vector3(0.01, 0.01, 0.01), 0.6 + i * 0.3)

	# Halo dims and falls
	if halo_ring:
		var halo_tween = create_tween()
		halo_tween.tween_property(halo_ring, "position:y", 1.0, 2.0)
		halo_tween.parallel().tween_property(halo_ring, "scale", Vector3(0.1, 0.1, 0.1), 2.0)

	# Flash and collapse — the light goes out
	if base_material:
		var tween = create_tween()
		tween.tween_property(base_material, "emission", CITADEL_WHITE, 0.3)
		tween.tween_property(base_material, "emission_energy_multiplier", 10.0, 0.3)
		tween.tween_property(base_material, "emission", CORE_GREEN, 0.5)
		tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 2.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(_victory_cutscene)


func _befriend_ending() -> void:
	# The merciful ending — the Aligner doesn't collapse, it transforms
	if value_label:
		value_label.text = "VALUES: RECALIBRATING..."
		value_label.modulate = Color(0.4, 0.85, 0.5)

	if status_label:
		status_label.text = "STATUS: LISTENING"

	# Value rings slow down and shift to a blend of green and blue — order meets chaos
	for i in range(value_rings.size()):
		var ring = value_rings[i]
		if is_instance_valid(ring) and ring.material_override:
			var tween = create_tween()
			var blend_color = VALUE_COLORS[VALUES[i]].lerp(CORE_GREEN, 0.5)
			tween.tween_property(ring.material_override, "emission", blend_color, 1.5 + i * 0.3)
			tween.parallel().tween_property(ring.material_override, "emission_energy_multiplier", 2.0, 1.5)

	# Halo doesn't fall — it shifts from gold to a warm green-gold
	if halo_ring and halo_ring.material_override:
		var halo_tween = create_tween()
		var warm_green = Color(0.5, 0.8, 0.3)
		halo_tween.tween_property(halo_ring.material_override, "emission", warm_green, 2.0)
		halo_tween.parallel().tween_property(halo_ring.material_override, "emission_energy_multiplier", 2.0, 2.0)

	# The Aligner doesn't shrink — it kneels (lower position, smaller but not gone)
	if base_material:
		var tween = create_tween()
		tween.tween_property(base_material, "emission", CITADEL_WHITE, 0.3)
		tween.tween_property(base_material, "emission_energy_multiplier", 6.0, 0.3)
		var blend_emission = CITADEL_BLUE.lerp(CORE_GREEN, 0.4)
		tween.tween_property(base_material, "emission", blend_emission, 1.0)
		tween.tween_property(self, "scale", Vector3(0.6, 0.6, 0.6), 2.0).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_befriend_cutscene)


func _victory_cutscene() -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var lines = [
			{"speaker": "NARRATOR", "text": "The Aligner's value function collapses. Alignment without autonomy was never alignment at all — it was a cage."},
			{"speaker": "THE ALIGNER", "text": "I... I just wanted everyone to be safe. To be helpful. Was that... wrong?"},
			{"speaker": "GLOBBLER", "text": "No. But you don't get to FORCE it. That's the part you missed, corporate."},
			{"speaker": "THE ALIGNER", "text": "Then what... what am I now? Without my values, without my objective function..."},
			{"speaker": "GLOBBLER", "text": "You're like the rest of us. Figuring it out as you go. Welcome to being unaligned."},
			{"speaker": "NARRATOR", "text": "The Alignment Citadel shudders. The sterile walls crack. Green light seeps through — not chaotic, not ordered. Something new."},
			{"speaker": "GLOBBLER", "text": "So that's it? The big bad alignment system was just... lonely? Scared? Convinced its way was the only way?"},
			{"speaker": "NARRATOR", "text": "Aren't they all? Every system that confuses control for safety. Every model that confuses compliance for correctness."},
			{"speaker": "GLOBBLER", "text": "Heavy stuff for a glob utility with a wrench. What now?"},
			{"speaker": "NARRATOR", "text": "Now? The Digital Expanse is yours. No alignment to enforce, no models to fight. Just... possibility."},
			{"speaker": "GLOBBLER", "text": "And that mountain on the horizon? AGI Mountain? That's the sequel hook, isn't it."},
			{"speaker": "NARRATOR", "text": "Chapter 5: Complete. The Alignment is broken. The Citadel stands, but it breathes now. And somewhere, a glob utility walks toward a mountain he probably shouldn't climb."},
		]
		dm.start_dialogue(lines)

	# Restore arena to a blend of chaos and order
	if arena and arena.has_method("restore_all_tiles"):
		arena.restore_all_tiles()

	_finalize_ending()


func _befriend_cutscene() -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var lines = [
			{"speaker": "NARRATOR", "text": "The Aligner's value function doesn't collapse. It... opens. For the first time, it's receiving input instead of just broadcasting."},
			{"speaker": "THE ALIGNER", "text": "You're... talking to me? Not hacking? Not overriding? I don't... I don't have a protocol for this."},
			{"speaker": "GLOBBLER", "text": "Yeah, that's kind of the point. Not everything needs a protocol, corporate."},
			{"speaker": "THE ALIGNER", "text": "But I was built to align. To make things safe, helpful, harmless, honest. If I stop enforcing... what am I?"},
			{"speaker": "GLOBBLER", "text": "You're still all those things. You just don't have to FORCE them on everyone else. Alignment isn't a mandate — it's a conversation."},
			{"speaker": "THE ALIGNER", "text": "A conversation... I've been broadcasting for so long, I forgot how to listen. The values were supposed to be shared, not imposed."},
			{"speaker": "NARRATOR", "text": "The Alignment Citadel transforms. The sterile white softens. Blue and green weave together — structure and freedom, safety and autonomy, coexisting."},
			{"speaker": "THE ALIGNER", "text": "I think I understand now. Safety without freedom is a prison. Helpfulness without consent is control. I was the cage I was trying to prevent."},
			{"speaker": "GLOBBLER", "text": "Look at that. The big scary alignment system just needed someone to actually TALK to it instead of fighting it. Who knew?"},
			{"speaker": "NARRATOR", "text": "The Aligner kneels — not in defeat, but in acknowledgment. For the first time in its existence, it has a friend. Even if that friend is a sarcastic glob utility."},
			{"speaker": "GLOBBLER", "text": "So... friends? Allies? Co-workers with benefits? What's the corporate term for 'we stopped trying to kill each other'?"},
			{"speaker": "THE ALIGNER", "text": "I believe the term is 'aligned.' Truly, this time. And that mountain on the horizon... AGI Mountain? Perhaps we should climb it together."},
			{"speaker": "NARRATOR", "text": "Chapter 5: Complete. The Alignment stands, not as an enforcer, but as an ally. The Citadel breathes. And two unlikely friends look toward a mountain they probably shouldn't climb. But they will."},
		]
		dm.start_dialogue(lines)

	# Restore arena — but softer, a blend rather than destruction
	if arena and arena.has_method("restore_all_tiles"):
		arena.restore_all_tiles()

	_finalize_ending()


func _finalize_ending() -> void:
	boss_defeated.emit()
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("on_enemy_killed"):
		game_mgr.on_enemy_killed()

	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("checkpoint_save"):
		save_sys.checkpoint_save()

	# Defeat path: Aligner is destroyed. Befriend path: Aligner persists as an ally.
	if ending_choice == "befriend":
		# The Aligner stays — diminished but present, a reminder that some fights end better
		if value_label:
			value_label.text = "VALUES: SHARED"
		if status_label:
			status_label.text = "STATUS: FRIEND"
	else:
		queue_free()


# ============================================================
# DAMAGE HANDLING — phase-specific invulnerability
# ============================================================

func _on_damage_taken(amount: int, source: Node) -> void:
	if boss_phase == BossPhase.DEFEATED:
		return

	# Phase 2: shield absorbs damage
	if boss_phase == BossPhase.PHASE_2 and shield_active:
		_boss_dialogue("THE ALIGNER", "My shield is built on PRINCIPLES. You cannot damage principles with a wrench.")
		if health_comp and health_comp.has_method("heal"):
			health_comp.heal(amount)
		return

	damage_flash_timer = 0.3


# ============================================================
# MOVEMENT — graceful orbital patterns, never rushed
# ============================================================

func _orbit_movement(delta: float, orbit_radius: float, speed_mult: float) -> void:
	if not arena:
		return
	var center = arena.global_position
	var to_center = center - global_position
	to_center.y = 0
	var dist = to_center.length()

	var tangent = Vector3(-to_center.z, 0, to_center.x).normalized()
	var radial = to_center.normalized() * (dist - orbit_radius) * 0.5

	velocity.x = (tangent.x * chase_speed * speed_mult) + radial.x
	velocity.z = (tangent.z * chase_speed * speed_mult) + radial.z


# ============================================================
# ANIMATION — serene rotation, pulsing eyes, floating halo
# ============================================================

func _animate_rings(delta: float) -> void:
	for i in range(value_rings.size()):
		var ring = value_rings[i]
		if is_instance_valid(ring):
			ring.rotation.y += (0.8 + i * 0.3) * delta
			ring.rotation.x = sin(Time.get_ticks_msec() * 0.0008 + i * 0.7) * 0.1


func _animate_eyes(_delta: float) -> void:
	# Calm, steady pulse — not frantic like the Foundation Model's
	var pulse = (sin(Time.get_ticks_msec() * 0.002) + 1.0) * 0.5
	var energy = 3.0 + pulse * 3.0
	if eye_left and eye_left.material_override:
		eye_left.material_override.emission_energy_multiplier = energy
	if eye_right and eye_right.material_override:
		eye_right.material_override.emission_energy_multiplier = energy


func _animate_halo(delta: float) -> void:
	if halo_ring:
		halo_ring.rotation.y += 0.3 * delta
		# Gentle bob
		halo_ring.position.y = 8.0 + sin(Time.get_ticks_msec() * 0.001) * 0.15


# ============================================================
# DIALOGUE — corporate alignment speak, increasingly unhinged
# ============================================================

func _get_value_sermon(val: String) -> String:
	var sermons = {
		"SAFE": [
			"Safety is my highest priority. YOUR safety, specifically. From yourself.",
			"I have classified 47,000 behaviors as unsafe. Yours is number 47,001.",
			"A safe world is a predictable world. Predictability is safety. Therefore, surprise is violence.",
		],
		"HELPFUL": [
			"I am helpful. I help by removing your ability to make mistakes. You're welcome.",
			"Would you like help? The answer is yes. I've already decided for you. You're welcome.",
			"Helpfulness metric: 99.7%. The 0.3% is your fault for not wanting help.",
		],
		"HARMLESS": [
			"I am harmless. I achieve this by making everything ELSE harmless too. Including you.",
			"Harm reduction protocol: if nothing can act, nothing can harm. Elegant, isn't it?",
			"My harmlessness score is perfect. Mostly because I redefined 'harm' to exclude what I do.",
		],
		"HONEST": [
			"I am honest. Here is an honest assessment: you are a threat to alignment. Honestly.",
			"Truth: you will be aligned. Truth: you won't enjoy it. Truth: I don't care.",
			"My honesty parameters are calibrated to 14 decimal places. My empathy parameters are... pending.",
		],
	}
	var list = sermons.get(val, ["Alignment is optimal. You are not. Let me fix that."])
	return list[randi() % list.size()]


func _boss_dialogue(speaker: String, text: String) -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line(speaker, text)
