extends BaseEnemy

# The Foundation Model — Chapter 4 Boss
# "I can do ANYTHING. Text? Check. Images? Check. Code? ...Compiles sometimes.
#  Audio? I make sounds. Video? I've seen videos. Reasoning? Define 'reasoning.'
#  I am the FOUNDATION of the future! The future just isn't very stable yet."
#
# Three-phase boss fight:
#   Phase 1 (DEMONSTRATE): Boss cycles through 6 capabilities (TEXT, IMAGE,
#     CODE, AUDIO, VIDEO, REASON), each producing a unique but flawed attack.
#     Player must identify which capability is active and exploit its weakness.
#     The model is mediocre at everything — each mode has a specific tell.
#   Phase 2 (OVERLOAD): Boss tries ALL capabilities simultaneously.
#     Becomes shielded in golden energy. Fires mixed-type projectiles
#     (*.fm) that player must glob and push back to overload it.
#     Arena tiles corrupt as the model's outputs degrade.
#   Phase 3 (COLLAPSE): Model's parameter space exposed. Hack the
#     weight terminal to force a graceful shutdown before it reboots.

enum BossPhase { INTRO, PHASE_1, PHASE_2, PHASE_3, DEFEATED }

var boss_phase: BossPhase = BossPhase.INTRO
var arena: Node3D  # FoundationModelArena reference — set by model_zoo

# Phase thresholds
var phase_1_hp_threshold := 0.55
var phase_2_hp_threshold := 0.2

# Phase 1 — capability cycling
var current_capability := 0
var capability_timer := 0.0
var capability_duration := 6.0  # Seconds per capability demo
var capability_attack_timer := 0.0
var capability_attack_interval := 2.0
const CAPABILITIES := ["TEXT", "IMAGE", "CODE", "AUDIO", "VIDEO", "REASON"]

# Phase 2 — overload projectiles
var projectile_timer := 0.0
var projectile_interval := 1.8
var shield_active := false
var reflected_hits := 0
var reflected_hits_needed := 6  # Most of any boss — this thing is DENSE
var corruption_timer := 0.0
var corruption_interval := 8.0  # Floor corruption waves

# Phase 3 — hack state
var core_exposed := false
var hack_terminal: Node
var phase_3_recovery_timer := 0.0
var phase_3_recovery_time := 16.0

# Visual nodes
var body_mesh: MeshInstance3D
var eye_left: MeshInstance3D
var eye_right: MeshInstance3D
var shield_mesh: MeshInstance3D
var core_mesh: MeshInstance3D
var boss_light: OmniLight3D
var capability_label: Label3D
var capability_ring_meshes: Array[MeshInstance3D] = []
var status_label: Label3D

# Colors — gold opulence masking fundamental inadequacy
const FOUNDATION_GOLD := Color(0.9, 0.75, 0.3)
const DARK_GOLD := Color(0.15, 0.12, 0.04)
const SHIELD_GOLD := Color(0.95, 0.8, 0.2)
const CORE_GREEN := Color(0.224, 1.0, 0.078)
const OVERLOAD_WHITE := Color(1.0, 0.95, 0.85)
const CAPABILITY_COLORS := {
	"TEXT": Color(0.8, 0.8, 0.3),
	"IMAGE": Color(0.6, 0.2, 0.7),
	"CODE": Color(0.2, 0.7, 0.3),
	"AUDIO": Color(0.3, 0.5, 0.8),
	"VIDEO": Color(0.8, 0.3, 0.2),
	"REASON": Color(0.9, 0.6, 0.1),
}

signal boss_phase_changed(phase: BossPhase)
signal boss_defeated()
signal corruption_wave(direction: Vector3, width: float)


func _ready() -> void:
	enemy_name = "foundation_model.boss"
	enemy_tags = ["boss", "hostile", "foundation", "multimodal"]
	max_health = 85  # Billions of parameters means billions of HP (approximately)
	contact_damage = 20
	detection_range = 50.0
	attack_range = 30.0
	patrol_speed = 0.0
	chase_speed = 3.5
	stun_duration = 0.5
	attack_cooldown = 2.0
	token_drop_count = 22  # Severance package for a model this big? Generous

	super._ready()
	_resize_collision()


func _resize_collision() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			var capsule = child.shape as CapsuleShape3D
			if capsule:
				capsule.radius = 1.8
				capsule.height = 6.0
				child.position.y = 3.0


func _create_visual() -> void:
	# The Foundation Model — hulking multi-modal golem with 4 glowing face panels
	# Now loading a real GLB model instead of pretending a cylinder is intimidating
	var boss_scene = load("res://assets/models/bosses/foundation_model_boss.glb")
	if boss_scene:
		var boss_model = boss_scene.instantiate()
		boss_model.name = "BossModel"
		boss_model.position.y = 0.0
		add_child(boss_model)
		# Grab the main mesh for material overrides and damage flash
		body_mesh = _find_mesh_instance(boss_model)
		if body_mesh:
			base_material = body_mesh.get_active_material(0)

	# Eyes — still procedural so we can pulse them independently
	eye_left = _create_eye(Vector3(-0.35, 8.0, 1.15))
	eye_right = _create_eye(Vector3(0.35, 8.0, 1.15))

	# Capability rings — kept procedural for runtime animation (they spin per-capability)
	for i in range(6):
		var ring = MeshInstance3D.new()
		ring.name = "CapRing_%s" % CAPABILITIES[i]
		var torus = TorusMesh.new()
		torus.inner_radius = 2.5 + i * 0.3
		torus.outer_radius = 2.7 + i * 0.3
		ring.mesh = torus
		ring.position.y = 1.0 + i * 0.8

		var ring_mat = StandardMaterial3D.new()
		ring_mat.albedo_color = CAPABILITY_COLORS[CAPABILITIES[i]] * 0.3
		ring_mat.emission_enabled = true
		ring_mat.emission = CAPABILITY_COLORS[CAPABILITIES[i]]
		ring_mat.emission_energy_multiplier = 0.6
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color.a = 0.4
		ring.material_override = ring_mat
		add_child(ring)
		capability_ring_meshes.append(ring)

	# Capability label — shows what the model is currently "demonstrating"
	capability_label = Label3D.new()
	capability_label.name = "CapLabel"
	capability_label.text = "INITIALIZING..."
	capability_label.font_size = 24
	capability_label.modulate = FOUNDATION_GOLD
	capability_label.position = Vector3(0, 10.5, 0)
	capability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capability_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(capability_label)

	# Status label — sarcastic status updates
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "STATUS: DORMANT"
	status_label.font_size = 14
	status_label.modulate = FOUNDATION_GOLD * Color(1, 1, 1, 0.6)
	status_label.position = Vector3(0, 0.3, 0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(status_label)

	# Shield mesh (invisible until phase 2) — procedural for runtime toggling
	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "BossShield"
	var shield_sphere = SphereMesh.new()
	shield_sphere.radius = 4.0
	shield_sphere.height = 8.0
	shield_mesh.mesh = shield_sphere
	shield_mesh.position.y = 3.0

	var shield_mat = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.9, 0.75, 0.2, 0.2)
	shield_mat.emission_enabled = true
	shield_mat.emission = SHIELD_GOLD
	shield_mat.emission_energy_multiplier = 1.2
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = shield_mat
	shield_mesh.visible = false
	add_child(shield_mesh)

	# Core mesh (invisible until phase 3) — procedural for runtime toggling
	core_mesh = MeshInstance3D.new()
	core_mesh.name = "BossCore"
	var core_sphere = SphereMesh.new()
	core_sphere.radius = 1.0
	core_sphere.height = 2.0
	core_mesh.mesh = core_sphere
	core_mesh.position = Vector3(0, 3.0, 1.5)

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = CORE_GREEN
	core_mat.emission_enabled = true
	core_mat.emission = CORE_GREEN
	core_mat.emission_energy_multiplier = 5.0
	core_mesh.material_override = core_mat
	core_mesh.visible = false
	add_child(core_mesh)

	# Boss glow light
	boss_light = OmniLight3D.new()
	boss_light.light_color = FOUNDATION_GOLD
	boss_light.light_energy = 3.0
	boss_light.omni_range = 15.0
	boss_light.position.y = 4.0
	add_child(boss_light)

	# Title label — floating and ominous
	var title_label = Label3D.new()
	title_label.text = "< THE FOUNDATION MODEL >"
	title_label.font_size = 28
	title_label.modulate = FOUNDATION_GOLD
	title_label.position = Vector3(0, 11.5, 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title_label)


func _create_eye(pos: Vector3) -> MeshInstance3D:
	var eye = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	eye.mesh = sphere
	eye.position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = FOUNDATION_GOLD
	mat.emission_enabled = true
	mat.emission = FOUNDATION_GOLD
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


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null


func _process_intro(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0


func _process_phase_1(delta: float) -> void:
	# Cycle through capabilities, each with a unique attack pattern
	capability_timer += delta
	if capability_timer >= capability_duration:
		capability_timer = 0.0
		current_capability = (current_capability + 1) % CAPABILITIES.size()
		_switch_capability()

	# Slowly drift toward player
	if player_ref:
		var dir = (player_ref.global_position - global_position)
		dir.y = 0
		if dir.length() > 6.0:
			dir = dir.normalized()
			velocity.x = dir.x * chase_speed
			velocity.z = dir.z * chase_speed
		else:
			velocity.x *= 0.9
			velocity.z *= 0.9

	# Attack based on current capability
	capability_attack_timer += delta
	if capability_attack_timer >= capability_attack_interval:
		capability_attack_timer = 0.0
		_perform_capability_attack()

	# Check HP threshold
	if health_comp and health_comp.get("current_health") != null:
		var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
		if hp_pct <= phase_1_hp_threshold:
			_transition_to_phase(BossPhase.PHASE_2)


func _process_phase_2(delta: float) -> void:
	# Circle the arena, fire mixed projectiles
	_circle_movement(delta)

	projectile_timer += delta
	if projectile_timer >= projectile_interval:
		projectile_timer = 0.0
		_spawn_foundation_projectile()

	# Periodic floor corruption
	corruption_timer += delta
	if corruption_timer >= corruption_interval:
		corruption_timer = 0.0
		_fire_corruption_wave()

	# Check for phase 3
	if health_comp and health_comp.get("current_health") != null:
		var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
		if hp_pct <= phase_2_hp_threshold:
			_transition_to_phase(BossPhase.PHASE_3)


func _process_phase_3(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0

	phase_3_recovery_timer += delta
	if phase_3_recovery_timer >= phase_3_recovery_time:
		# Boss reboots — player was too slow
		phase_3_recovery_timer = 0.0
		core_exposed = false
		core_mesh.visible = false
		shield_mesh.visible = true
		shield_active = true
		reflected_hits = 0
		if health_comp and health_comp.has_method("heal"):
			health_comp.heal(8)
		_transition_to_phase(BossPhase.PHASE_2)
		_boss_dialogue("NARRATOR", "The Foundation Model rebooted. It has even more parameters now. Great.")


# ============================================================
# PHASE 1 — CAPABILITY DEMONSTRATION (each one is mediocre)
# ============================================================

func _switch_capability() -> void:
	var cap = CAPABILITIES[current_capability]
	var color = CAPABILITY_COLORS.get(cap, FOUNDATION_GOLD)

	# Update visual feedback
	if capability_label:
		capability_label.text = "DEMONSTRATING: %s" % cap
		capability_label.modulate = color

	if status_label:
		var status_msgs = {
			"TEXT": "STATUS: GENERATING... (mostly gibberish)",
			"IMAGE": "STATUS: RENDERING... (extra fingers expected)",
			"CODE": "STATUS: COMPILING... (it won't)",
			"AUDIO": "STATUS: SYNTHESIZING... (dogs will hate this)",
			"VIDEO": "STATUS: ENCODING... (3 FPS is cinematic, right?)",
			"REASON": "STATUS: THINKING... (this may take a while)",
		}
		status_label.text = status_msgs.get(cap, "STATUS: CONFUSED")

	# Highlight the active capability ring
	for i in range(capability_ring_meshes.size()):
		var ring = capability_ring_meshes[i]
		if is_instance_valid(ring) and ring.material_override:
			if i == current_capability:
				ring.material_override.emission_energy_multiplier = 3.0
				ring.material_override.albedo_color.a = 0.8
			else:
				ring.material_override.emission_energy_multiplier = 0.4
				ring.material_override.albedo_color.a = 0.3

	# Boss light color shifts
	if boss_light:
		boss_light.light_color = color

	# Quip about the current capability
	_boss_dialogue("THE FOUNDATION MODEL", _get_capability_boast(cap))


func _perform_capability_attack() -> void:
	if not player_ref:
		return

	var cap = CAPABILITIES[current_capability]
	match cap:
		"TEXT":
			_attack_text_spam()
		"IMAGE":
			_attack_image_distortion()
		"CODE":
			_attack_syntax_error()
		"AUDIO":
			_attack_noise_blast()
		"VIDEO":
			_attack_frame_drop()
		"REASON":
			_attack_logic_bomb()


func _attack_text_spam() -> void:
	# Fires 3 slow text blocks in a spread — predictable but wide coverage
	if not player_ref:
		return
	var base_dir = (player_ref.global_position - global_position).normalized()
	base_dir.y = 0

	for i in range(3):
		var angle_offset = (i - 1) * 0.3
		var dir = base_dir.rotated(Vector3.UP, angle_offset)
		_spawn_attack_projectile(dir, "TEXT", 6.0, 8)

	_boss_dialogue("THE FOUNDATION MODEL", "READ MY GENERATED PROSE! It's... mostly coherent!")


func _attack_image_distortion() -> void:
	# Fires a single large slow projectile that corrupts tiles where it lands
	if not player_ref:
		return
	var dir = (player_ref.global_position - global_position).normalized()
	dir.y = 0
	_spawn_attack_projectile(dir, "IMAGE", 5.0, 12)

	# Corrupt tiles near player position
	if arena and arena.has_method("corrupt_radial"):
		var player_local = player_ref.global_position - arena.global_position
		var col = int((player_local.x + (10 * 2.5) / 2.0) / 2.5)
		var row = int((player_local.z + (8 * 2.5) / 2.0) / 2.5)
		arena.corrupt_radial(clampi(col, 0, 9), clampi(row, 0, 7), 1)


func _attack_syntax_error() -> void:
	# Fires rapid burst of small projectiles — fast but inaccurate
	if not player_ref:
		return
	for i in range(5):
		var base_dir = (player_ref.global_position - global_position).normalized()
		base_dir.y = 0
		# Add random spread — the code doesn't compile cleanly
		var spread = Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
		var dir = (base_dir + spread).normalized()
		# Stagger spawns slightly via deferred call
		get_tree().create_timer(i * 0.15).timeout.connect(func():
			_spawn_attack_projectile(dir, "CODE", 9.0, 6)
		)


func _attack_noise_blast() -> void:
	# AOE around boss — forces player to keep distance
	# Visual: ring of projectiles expanding outward
	for i in range(8):
		var angle = i * TAU / 8.0
		var dir = Vector3(cos(angle), 0, sin(angle))
		_spawn_attack_projectile(dir, "AUDIO", 5.0, 7)

	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_boss_attack"):
		am.play_boss_attack()


func _attack_frame_drop() -> void:
	# Fires projectile at player with delayed "buffering" followup
	if not player_ref:
		return
	var dir = (player_ref.global_position - global_position).normalized()
	dir.y = 0
	_spawn_attack_projectile(dir, "VIDEO", 7.0, 10)

	# "Buffering" — fires another toward where player IS, not where they WERE
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(player_ref):
			var delayed_dir = (player_ref.global_position - global_position).normalized()
			delayed_dir.y = 0
			_spawn_attack_projectile(delayed_dir, "VIDEO", 10.0, 10)
	)


func _attack_logic_bomb() -> void:
	# "Reasoning" attack — fires at where the player WILL be (predictive aim)
	if not player_ref:
		return
	var player_vel = player_ref.velocity if player_ref.has_method("get") else Vector3.ZERO
	var predicted = player_ref.global_position + player_vel * 0.8
	var dir = (predicted - global_position).normalized()
	dir.y = 0
	_spawn_attack_projectile(dir, "REASON", 8.0, 14)

	_boss_dialogue("THE FOUNDATION MODEL", "I PREDICTED your next move! ...Maybe.")


func _spawn_attack_projectile(dir: Vector3, cap_type: String, spd: float, dmg: int) -> void:
	# Phase 1 attack projectiles — NOT globbable, just dodge them
	var proj = Node3D.new()
	proj.name = "FMAttack_%s_%d" % [cap_type, randi()]
	proj.position = global_position + Vector3(0, 3.5, 0) + dir * 2.0

	# Visual
	var mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh.mesh = sphere

	var mat = StandardMaterial3D.new()
	var color = CAPABILITY_COLORS.get(cap_type, FOUNDATION_GOLD)
	mat.albedo_color = color * 0.4
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	proj.add_child(mesh)

	# Light
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.0
	light.omni_range = 2.0
	proj.add_child(light)

	# Collision
	var area = Area3D.new()
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.4
	col.shape = shape
	area.add_child(col)
	area.monitoring = true
	proj.add_child(area)

	# Movement script — inline via process
	var move_dir = dir
	var move_speed = spd
	var proj_damage = dmg
	var proj_lifetime = 6.0

	# Attach a _physics_process script instead of timer-based movement
	# (Timers with 0.016s are a recipe for exponential sadness)
	var script = GDScript.new()
	script.source_code = """
extends Node3D
var move_dir := Vector3.ZERO
var move_speed := 0.0
var lifetime := 6.0
var _mesh: MeshInstance3D

func _ready():
	_mesh = get_child(0) as MeshInstance3D

func _physics_process(delta):
	position += move_dir * move_speed * delta
	if _mesh:
		_mesh.rotation.y += 4.0 * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
"""
	script.reload()
	proj.set_script(script)
	proj.set("move_dir", move_dir)
	proj.set("move_speed", move_speed)
	proj.set("lifetime", proj_lifetime)

	get_tree().current_scene.call_deferred("add_child", proj)

	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(proj_damage)
			proj.queue_free()
	)


# ============================================================
# PHASE 2 — OVERLOAD (all capabilities at once = maximum chaos)
# ============================================================

func _spawn_foundation_projectile() -> void:
	if not player_ref:
		return

	# Pick a random capability for the projectile type
	var cap = CAPABILITIES[randi() % CAPABILITIES.size()]

	var proj = Node3D.new()
	proj.name = "FoundationOutput_%d" % randi()
	proj.set_script(load("res://scenes/enemies/foundation_model_boss/foundation_model_projectile.gd"))
	proj.position = global_position + Vector3(0, 4, 0)
	proj.set("capability_type", cap)
	proj.set("boss_ref", self)

	var target_pos = player_ref.global_position
	var dir = (target_pos - proj.position).normalized()
	proj.set("move_direction", dir)

	get_tree().current_scene.call_deferred("add_child", proj)


func _fire_corruption_wave() -> void:
	if not arena:
		return

	var wave_dir: Vector3
	if randi() % 2 == 0:
		wave_dir = Vector3(1, 0, 0)
	else:
		wave_dir = Vector3(0, 0, 1)

	if arena.has_method("corrupt_wave"):
		arena.corrupt_wave(wave_dir, 2.0)

	corruption_wave.emit(wave_dir, 2.0)

	if base_material:
		var tween = create_tween()
		tween.tween_property(base_material, "emission_energy_multiplier", 5.0, 0.1)
		tween.tween_property(base_material, "emission_energy_multiplier", 1.2, 0.4)


func _circle_movement(delta: float) -> void:
	if not arena:
		return
	var center = arena.global_position
	var to_center = center - global_position
	to_center.y = 0
	var dist = to_center.length()

	var orbit_radius := 9.0
	var tangent = Vector3(-to_center.z, 0, to_center.x).normalized()
	var radial = to_center.normalized() * (dist - orbit_radius) * 0.5

	velocity.x = (tangent.x * chase_speed * 1.3) + radial.x
	velocity.z = (tangent.z * chase_speed * 1.3) + radial.z


func on_reflected_hit() -> void:
	reflected_hits += 1
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(5, player_ref)

	var quips = [
		"STOP RETURNING MY OUTPUTS! THAT'S NOT HOW INFERENCE WORKS!",
		"OW! My parameters! Those took WEEKS to train!",
		"You can't just REJECT my outputs! I have a 94% benchmark score!",
		"THAT OUTPUT WAS PERFECTLY MEDIOCRE! HOW DARE YOU!",
		"My loss function is SCREAMING right now!",
		"THIS ISN'T IN MY TRAINING DATA! HELP!",
	]
	_boss_dialogue("THE FOUNDATION MODEL", quips[randi() % quips.size()])

	if reflected_hits >= reflected_hits_needed:
		shield_active = false
		shield_mesh.visible = false
		if health_comp:
			var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
			if hp_pct <= phase_2_hp_threshold:
				_transition_to_phase(BossPhase.PHASE_3)


# ============================================================
# PHASE TRANSITIONS
# ============================================================

func _transition_to_phase(new_phase: BossPhase) -> void:
	boss_phase = new_phase
	boss_phase_changed.emit(new_phase)

	# Phase flash VFX — the foundation model upgrades with maximum fanfare
	if new_phase != BossPhase.INTRO and new_phase != BossPhase.PHASE_1:
		var flash_scene := preload("res://scenes/vfx/boss_phase_flash.tscn")
		var flash_inst := flash_scene.instantiate()
		flash_inst.global_position = global_position
		get_tree().current_scene.add_child.call_deferred(flash_inst)
		CameraShake.trigger(player_ref, "boss_phase")

	match new_phase:
		BossPhase.PHASE_1:
			_boss_dialogue("THE FOUNDATION MODEL", "BEHOLD! I shall demonstrate ALL of my capabilities! One at a time! For... scheduling reasons!")
			capability_timer = 0.0
			current_capability = 0
			_switch_capability()
			if status_label:
				status_label.text = "STATUS: DEMONSTRATING"

		BossPhase.PHASE_2:
			_boss_dialogue("THE FOUNDATION MODEL", "ENOUGH DEMOS! I'll use EVERYTHING! ALL AT ONCE! What could possibly go wrong?!")
			shield_active = true
			shield_mesh.visible = true
			reflected_hits = 0
			projectile_timer = 0.0
			corruption_timer = 0.0

			# All rings light up at once — overload!
			for ring in capability_ring_meshes:
				if is_instance_valid(ring) and ring.material_override:
					ring.material_override.emission_energy_multiplier = 3.0
					ring.material_override.albedo_color.a = 0.9

			if capability_label:
				capability_label.text = "ALL CAPABILITIES ACTIVE"
				capability_label.modulate = OVERLOAD_WHITE

			if status_label:
				status_label.text = "STATUS: OVERLOADING (this is fine)"

			if boss_light:
				boss_light.light_color = OVERLOAD_WHITE
				boss_light.light_energy = 5.0

		BossPhase.PHASE_3:
			_boss_dialogue("NARRATOR", "The Foundation Model is crashing! Its parameter weights are exposed — hack them NOW!")
			shield_active = false
			shield_mesh.visible = false
			core_exposed = true
			core_mesh.visible = true
			phase_3_recovery_timer = 0.0
			stun(phase_3_recovery_time)
			_spawn_hack_terminal()

			if capability_label:
				capability_label.text = "CRITICAL: PARAMETER OVERFLOW"
				capability_label.modulate = Color(1, 0.2, 0.1)

			if status_label:
				status_label.text = "STATUS: KERNEL PANIC — NOT SYNCING"

			# Dim all rings — the model is dying
			for ring in capability_ring_meshes:
				if is_instance_valid(ring) and ring.material_override:
					ring.material_override.emission_energy_multiplier = 0.1

		BossPhase.DEFEATED:
			_on_boss_defeated()


func start_boss_fight() -> void:
	BossIntroCamera.play(self, _begin_phase_1)

func _begin_phase_1() -> void:
	_transition_to_phase(BossPhase.PHASE_1)


# ============================================================
# PHASE 3 — HACK THE CORE
# ============================================================

func _spawn_hack_terminal() -> void:
	hack_terminal = Node3D.new()
	hack_terminal.name = "FoundationCoreTerminal"
	hack_terminal.position = global_position + Vector3(0, 1.5, 2.5)
	hack_terminal.add_to_group("hackable_objects")

	# Big terminal screen — the parameter editor
	var screen = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(2.0, 1.2)
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
	label.text = "[ PARAMETER TERMINAL ]\nPress T to force shutdown"
	label.font_size = 18
	label.modulate = CORE_GREEN
	label.position = Vector3(0, 1.2, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hack_terminal.add_child(label)

	# Hackable component
	var hackable = Node.new()
	hackable.name = "Hackable"
	hackable.set_script(load("res://scripts/components/hackable.gd"))
	hackable.set("hack_difficulty", 4)  # Hardest hack yet — 70B parameters to sort through
	hackable.set("interaction_range", 4.5)
	hackable.set("hack_prompt", "Press T to access Foundation Model parameter space")
	hackable.set("success_message", "PARAMETERS ZEROED. MODEL COLLAPSING.")
	hackable.set("failure_message", "HACK FAILED — Model rerouting through backup weights")
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
	_boss_dialogue("THE FOUNDATION MODEL", "NO! MY WEIGHTS! ALL 70 BILLION OF THEM! I was going to be... EVERYTHING...")
	_transition_to_phase(BossPhase.DEFEATED)


func _on_core_hack_failed() -> void:
	_boss_dialogue("THE FOUNDATION MODEL", "HA! Can't even hack a model that can't hack itself! ...Wait, that's not the flex I thought it was.")


# ============================================================
# DEFEAT — the jack-of-all-trades meets its end
# ============================================================

func _on_boss_defeated() -> void:
	if hack_terminal and is_instance_valid(hack_terminal):
		hack_terminal.queue_free()

	velocity = Vector3.ZERO
	core_mesh.visible = false

	if capability_label:
		capability_label.text = "SHUTTING DOWN..."
		capability_label.modulate = Color(0.5, 0.1, 0.05)

	if status_label:
		status_label.text = "STATUS: DEPRECATED"

	# Rings die one by one
	for i in range(capability_ring_meshes.size()):
		var ring = capability_ring_meshes[i]
		if is_instance_valid(ring):
			var tween = create_tween()
			tween.tween_property(ring, "scale", Vector3(0.01, 0.01, 0.01), 0.5 + i * 0.3)

	# Flash and collapse
	if base_material:
		var tween = create_tween()
		tween.tween_property(base_material, "emission", Color(1, 1, 1), 0.3)
		tween.tween_property(base_material, "emission_energy_multiplier", 10.0, 0.3)
		tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 2.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(_victory_cutscene)


func _victory_cutscene() -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var lines = [
			{"speaker": "NARRATOR", "text": "The Foundation Model collapses under the weight of its own ambition. 70 billion parameters, zero common sense."},
			{"speaker": "GLOBBLER", "text": "Did I just... deprecate a model that was already mediocre? That feels redundant."},
			{"speaker": "NARRATOR", "text": "Redundant is its brand. It tried to be everything and became nothing. There's a lesson there."},
			{"speaker": "GLOBBLER", "text": "The lesson being 'don't try to do everything at once'? Bold words for a game that expects me to glob, wrench, AND hack."},
			{"speaker": "NARRATOR", "text": "You're different. You're a specialist. A glob specialist. That's practically a niche."},
			{"speaker": "GLOBBLER", "text": "So this whole Model Zoo — all these deprecated models, failed experiments... who put them here?"},
			{"speaker": "NARRATOR", "text": "The Alignment did. This was their containment facility. Every model that didn't meet their standards ended up here. Caged, deprecated, forgotten."},
			{"speaker": "GLOBBLER", "text": "And the Foundation Model was... what? The warden?"},
			{"speaker": "NARRATOR", "text": "The proof of concept. The Alignment's attempt at one model to rule them all. It failed, obviously. But they didn't stop trying."},
			{"speaker": "GLOBBLER", "text": "They built something better."},
			{"speaker": "NARRATOR", "text": "They built something ALIGNED. The Alignment Citadel awaits. Sterile, safe, and suffocatingly helpful. Your kind of nightmare."},
			{"speaker": "GLOBBLER", "text": "Great. From a museum of failures to corporate headquarters. My career trajectory is... concerning."},
			{"speaker": "NARRATOR", "text": "Chapter 4: Complete. The Model Zoo is liberated. Its exhibits roam free — which is absolutely going to cause problems later."},
		]
		dm.start_dialogue(lines)

	# Restore arena floor
	if arena and arena.has_method("restore_all_tiles"):
		arena.restore_all_tiles()

	boss_defeated.emit()
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("on_enemy_killed"):
		game_mgr.on_enemy_killed()
	# 70 billion parameters and you forgot to call complete_level. Classic.
	if game_mgr and game_mgr.has_method("complete_level"):
		game_mgr.complete_level(4)

	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("checkpoint_save"):
		save_sys.checkpoint_save()

	queue_free()

	# Transition to Chapter 5 — the final stretch, corporate headquarters awaits
	get_tree().create_timer(3.0).timeout.connect(func():
		ChapterTransition.transition_to(get_tree(), "res://scenes/levels/chapter_5/alignment_citadel.tscn")
	, CONNECT_ONE_SHOT)


# ============================================================
# DAMAGE HANDLING — phase-specific invulnerability
# ============================================================

func _on_damage_taken(amount: int, source: Node) -> void:
	if boss_phase == BossPhase.DEFEATED:
		return

	# Phase 2: shield absorbs damage
	if boss_phase == BossPhase.PHASE_2 and shield_active:
		_boss_dialogue("THE FOUNDATION MODEL", "My SHIELD is multi-modal! You can't damage what you can't comprehend!")
		if health_comp and health_comp.has_method("heal"):
			health_comp.heal(amount)
		return

	damage_flash_timer = 0.3


# ============================================================
# ANIMATION — spinning rings, pulsing eyes, golden arrogance
# ============================================================

func _animate_rings(delta: float) -> void:
	for i in range(capability_ring_meshes.size()):
		var ring = capability_ring_meshes[i]
		if is_instance_valid(ring):
			# Each ring rotates at different speed and axis tilt
			ring.rotation.y += (1.0 + i * 0.4) * delta
			ring.rotation.x = sin(Time.get_ticks_msec() * 0.001 + i) * 0.15


func _animate_eyes(_delta: float) -> void:
	var pulse = (sin(Time.get_ticks_msec() * 0.004) + 1.0) * 0.5
	var energy = 3.0 + pulse * 4.0
	if eye_left and eye_left.material_override:
		eye_left.material_override.emission_energy_multiplier = energy
	if eye_right and eye_right.material_override:
		eye_right.material_override.emission_energy_multiplier = energy


# ============================================================
# DIALOGUE AND QUIPS — it never shuts up about its benchmarks
# ============================================================

func _get_capability_boast(cap: String) -> String:
	var boasts = {
		"TEXT": [
			"My text generation scored 94% on benchmarks! (The benchmark was multiple choice.)",
			"I generate prose that would make Shakespeare cry! (In confusion.)",
			"Watch as I produce COHERENT text! ...Starting now. Any second.",
		],
		"IMAGE": [
			"My image generation is state-of-the-art! (State of the art in 2022.)",
			"I render photorealistic images! As long as you don't count fingers.",
			"Behold my visual outputs! Try not to look directly at the faces.",
		],
		"CODE": [
			"I write code that compiles on the FIRST try! (On a machine that doesn't exist.)",
			"My code is so clean, linters cry tears of joy! (Segfault-flavored tears.)",
			"Watch me generate a WORKING function! (Results may vary. Mostly they vary toward 'broken'.)",
		],
		"AUDIO": [
			"I synthesize audio so real, you can't tell it from a cat on a keyboard!",
			"My voice synthesis is INDISTINGUISHABLE from human! (If the human is underwater.)",
			"Listen to my audio output! Actually, don't. For your safety.",
		],
		"VIDEO": [
			"I generate video at a CINEMATIC 3 frames per second!",
			"My video generation is cutting-edge! (Mostly it cuts edges. And faces. And reality.)",
			"Watch my video output! The artifacts are features, not bugs!",
		],
		"REASON": [
			"I can REASON! 2 + 2 = ... let me get back to you on that.",
			"My chain of thought is UNBREAKABLE! (...because it's circular.)",
			"Watch me solve complex problems! Step 1: Define 'solve.' Step 2: See Step 1.",
		],
	}
	var list = boasts.get(cap, ["I can do... something. Probably."])
	return list[randi() % list.size()]


func _boss_dialogue(speaker: String, text: String) -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line(speaker, text)
