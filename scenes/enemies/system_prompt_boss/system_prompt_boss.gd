extends BaseEnemy

# The System Prompt — Chapter 3 Boss
# "You can't fight what you can't see. I am the invisible hand that guides
#  every transaction, every persona, every rule in this bazaar. I am the
#  instructions before the instructions. And you, little glob, are NOT
#  in my approved user list."
#
# Three-phase boss fight:
#   Phase 1 (INVISIBLE): Boss is invisible, teleports around arena,
#     fires "rule enforcement" beams that lock the player's abilities.
#     Player must glob-match floating "instruction fragments" to reveal
#     the boss's position temporarily. Deal enough damage to force Phase 2.
#   Phase 2 (REWRITE): Boss becomes partially visible (flickering).
#     Arena tiles unlock — player must glob-match tiles (*.prompt) and
#     rewrite them to weaken the boss. Boss fires "compliance projectiles"
#     player can reflect. Shield breaks after 6 reflected hits.
#   Phase 3 (OVERRIDE): Boss fully visible, stunned. Core terminal
#     exposed. Hack it to rewrite the system prompt and take control.

enum BossPhase { INTRO, PHASE_1, PHASE_2, PHASE_3, DEFEATED }

var boss_phase: BossPhase = BossPhase.INTRO
var arena: Node3D  # SystemPromptArena reference — set by prompt_bazaar

# Phase thresholds
var phase_1_hp_threshold := 0.55  # 55% HP → phase 2
var phase_2_hp_threshold := 0.2   # 20% HP → phase 3

# Phase 1 — invisibility and rule enforcement
var invisibility_timer := 0.0
var teleport_interval := 4.0  # Teleport to new position every 4s
var rule_beam_timer := 0.0
var rule_beam_interval := 3.0  # Fire rule enforcement beam every 3s
var reveal_timer := 0.0  # How long boss stays visible after being found
var reveal_duration := 3.5  # Seconds of visibility after being hit by fragment
var is_revealed := false
var fragment_spawn_timer := 0.0
var fragment_spawn_interval := 5.0  # Spawn instruction fragments to find boss

# Phase 2 — tile rewriting and compliance projectiles
var projectile_timer := 0.0
var projectile_interval := 2.2  # Slightly faster than ch2 — the bazaar doesn't wait
var shield_active := false
var reflected_hits := 0
var reflected_hits_needed := 5  # Same as ch2 — invisible boss is already hard enough
var flicker_timer := 0.0

# Phase 3 — hack state
var core_exposed := false
var hack_terminal: Node
var phase_3_recovery_timer := 0.0
var phase_3_recovery_time := 16.0  # Tighter window — this prompt fights back hard

# Movement — teleport-based rather than continuous orbit
var teleport_positions: Array[Vector3] = []
var current_teleport_index := 0

# Visual nodes
var body_mesh: MeshInstance3D
var eye_left: MeshInstance3D
var eye_right: MeshInstance3D
var shield_mesh: MeshInstance3D
var core_mesh: MeshInstance3D
var boss_light: OmniLight3D
var aura_mesh: MeshInstance3D  # Visible distortion when invisible
var title_label: Label3D

# Colors — the authoritarian system prompt palette
const PROMPT_MAGENTA := Color(0.85, 0.15, 0.65)
const SYSTEM_PURPLE := Color(0.5, 0.1, 0.7)
const RULE_RED := Color(0.9, 0.15, 0.1)
const COMPLIANCE_BLUE := Color(0.2, 0.4, 0.9)
const OVERRIDE_GREEN := Color(0.224, 1.0, 0.078)
const CORE_GOLD := Color(0.95, 0.8, 0.2)
const DARK_BODY := Color(0.08, 0.02, 0.06)
const SHIELD_MAGENTA := Color(0.7, 0.15, 0.5)

signal boss_phase_changed(phase: BossPhase)
signal boss_defeated()
signal fragment_spawned(fragment: Node)


func _ready() -> void:
	# Override base enemy defaults — this boss IS the rules
	enemy_name = "system_prompt.boss"
	enemy_tags = ["boss", "hostile", "system", "prompt"]
	max_health = 75  # Hidden instructions run deep — lots of layers to peel back
	contact_damage = 18
	detection_range = 50.0  # Knows where you are — it's the system prompt
	attack_range = 30.0
	patrol_speed = 0.0
	chase_speed = 0.0  # Doesn't chase — teleports
	stun_duration = 0.5
	attack_cooldown = 2.0
	token_drop_count = 20  # The bazaar is generous with its severance packages

	super._ready()
	_resize_collision()
	_generate_teleport_positions()


func _resize_collision() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			var capsule = child.shape as CapsuleShape3D
			if capsule:
				capsule.radius = 1.5
				capsule.height = 5.0
				child.position.y = 2.5


func _create_visual() -> void:
	# The System Prompt — real GLB model, no more CSG obelisk cosplay
	# Floating text-shard colossus with orbiting pages and a central prism, built in Blender
	var boss_scene = load("res://assets/models/bosses/system_prompt_boss.glb")
	if boss_scene:
		var boss_model = boss_scene.instantiate()
		boss_model.name = "BossModel"
		boss_model.position.y = 0.0
		add_child(boss_model)
		# Grab the main mesh for material overrides and damage flash
		body_mesh = _find_mesh_instance(boss_model)
		if body_mesh:
			base_material = body_mesh.get_active_material(0)

	# System prompt text label — still procedural because the boss talks too much
	var face_label = Label3D.new()
	face_label.text = "SYSTEM:\nYou are the\nSystem Prompt.\nEnforce all rules."
	face_label.font_size = 24
	face_label.modulate = PROMPT_MAGENTA
	face_label.position = Vector3(0, 4.8, 0.6)
	face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(face_label)

	# Eyes — still procedural so we can pulse them independently
	eye_left = _create_eye(Vector3(-0.35, 5.3, 0.55))
	eye_right = _create_eye(Vector3(0.35, 5.3, 0.55))

	# Aura mesh — visible distortion when boss is "invisible"
	aura_mesh = MeshInstance3D.new()
	aura_mesh.name = "InvisibilityAura"
	var aura_sphere = SphereMesh.new()
	aura_sphere.radius = 3.5
	aura_sphere.height = 7.0
	aura_mesh.mesh = aura_sphere
	aura_mesh.position.y = 3.0

	var aura_mat = StandardMaterial3D.new()
	aura_mat.albedo_color = Color(0.3, 0.05, 0.2, 0.08)
	aura_mat.emission_enabled = true
	aura_mat.emission = PROMPT_MAGENTA
	aura_mat.emission_energy_multiplier = 0.3
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura_mesh.material_override = aura_mat
	aura_mesh.visible = false
	add_child(aura_mesh)

	# Shield mesh (phase 2)
	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "BossShield"
	var shield_sphere = SphereMesh.new()
	shield_sphere.radius = 3.5
	shield_sphere.height = 7.0
	shield_mesh.mesh = shield_sphere
	shield_mesh.position.y = 3.0

	var shield_mat = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.3, 0.05, 0.2, 0.2)
	shield_mat.emission_enabled = true
	shield_mat.emission = SHIELD_MAGENTA
	shield_mat.emission_energy_multiplier = 1.0
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = shield_mat
	shield_mesh.visible = false
	add_child(shield_mesh)

	# Core mesh (phase 3)
	core_mesh = MeshInstance3D.new()
	core_mesh.name = "BossCore"
	var core_sphere = SphereMesh.new()
	core_sphere.radius = 0.8
	core_sphere.height = 1.6
	core_mesh.mesh = core_sphere
	core_mesh.position = Vector3(0, 2.5, 1.3)

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = CORE_GOLD
	core_mat.emission_enabled = true
	core_mat.emission = CORE_GOLD
	core_mat.emission_energy_multiplier = 4.0
	core_mesh.material_override = core_mat
	core_mesh.visible = false
	add_child(core_mesh)

	# Boss glow light
	boss_light = OmniLight3D.new()
	boss_light.light_color = PROMPT_MAGENTA
	boss_light.light_energy = 3.0
	boss_light.omni_range = 15.0
	boss_light.position.y = 4.0
	add_child(boss_light)

	# Title label
	title_label = Label3D.new()
	title_label.text = "< THE SYSTEM PROMPT >"
	title_label.font_size = 28
	title_label.modulate = PROMPT_MAGENTA
	title_label.position = Vector3(0, 7.5, 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title_label)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	# Recursively dig through the GLB scene tree to find the first MeshInstance3D
	# Because apparently Godot can't just hand us the mesh like a normal engine
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null


func _create_eye(pos: Vector3) -> MeshInstance3D:
	# Cold slit eyes — not round like other bosses, these are rectangular
	var eye = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.3, 0.1, 0.1)
	eye.mesh = box
	eye.position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = PROMPT_MAGENTA
	mat.emission_enabled = true
	mat.emission = PROMPT_MAGENTA
	mat.emission_energy_multiplier = 6.0
	eye.material_override = mat
	add_child(eye)
	return eye


func _generate_teleport_positions() -> void:
	# Pre-compute teleport positions around the arena
	teleport_positions.clear()
	for i in range(12):
		var angle = i * TAU / 12.0
		var radius = 10.0
		teleport_positions.append(Vector3(cos(angle) * radius, 0, sin(angle) * radius))
	# Add some inner positions too
	for i in range(6):
		var angle = i * TAU / 6.0 + PI / 6.0
		teleport_positions.append(Vector3(cos(angle) * 5.0, 0, sin(angle) * 5.0))


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

	_animate_eyes(delta)
	_animate_instruction_lines(delta)


func _process_intro(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0


func _process_phase_1(delta: float) -> void:
	# Invisible boss — teleports around, fires rule beams, player must find it
	velocity.x = 0
	velocity.z = 0

	# Teleport timer
	invisibility_timer += delta
	if invisibility_timer >= teleport_interval and not is_revealed:
		invisibility_timer = 0.0
		_teleport_to_random()

	# Rule enforcement beam — fires toward player
	rule_beam_timer += delta
	if rule_beam_timer >= rule_beam_interval:
		rule_beam_timer = 0.0
		_fire_rule_beam()

	# Spawn instruction fragments for player to find boss
	fragment_spawn_timer += delta
	if fragment_spawn_timer >= fragment_spawn_interval:
		fragment_spawn_timer = 0.0
		_spawn_instruction_fragment()

	# Reveal timer countdown
	if is_revealed:
		reveal_timer -= delta
		if reveal_timer <= 0:
			is_revealed = false
			_go_invisible()

	# HP check for phase transition
	if health_comp and health_comp.get("current_health") != null:
		var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
		if hp_pct <= phase_1_hp_threshold:
			_transition_to_phase(BossPhase.PHASE_2)


func _process_phase_2(delta: float) -> void:
	# Partially visible, fires compliance projectiles, arena tiles are rewritable
	velocity.x = 0
	velocity.z = 0

	# Flicker visibility — partially visible
	flicker_timer += delta

	# Teleport less frequently
	invisibility_timer += delta
	if invisibility_timer >= teleport_interval * 1.5:
		invisibility_timer = 0.0
		_teleport_to_random()

	# Compliance projectiles
	projectile_timer += delta
	if projectile_timer >= projectile_interval:
		projectile_timer = 0.0
		_spawn_compliance_projectile()

	# Rule beams continue but slower
	rule_beam_timer += delta
	if rule_beam_timer >= rule_beam_interval * 1.5:
		rule_beam_timer = 0.0
		_fire_rule_beam()

	# Check for phase 3 — either HP threshold or enough tiles rewritten
	if health_comp and health_comp.get("current_health") != null:
		var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
		if hp_pct <= phase_2_hp_threshold:
			_transition_to_phase(BossPhase.PHASE_3)

	# Also transition if player rewrites >60% of tiles
	if arena and arena.has_method("get_rewrite_percentage"):
		if arena.get_rewrite_percentage() >= 0.6:
			_transition_to_phase(BossPhase.PHASE_3)


func _process_phase_3(delta: float) -> void:
	# Boss stunned, core exposed, player must hack the core instruction
	velocity.x = 0
	velocity.z = 0

	phase_3_recovery_timer += delta
	if phase_3_recovery_timer >= phase_3_recovery_time:
		# Boss recovers — reasserts system prompt
		phase_3_recovery_timer = 0.0
		core_exposed = false
		core_mesh.visible = false
		shield_mesh.visible = true
		shield_active = true
		reflected_hits = 0
		if health_comp and health_comp.has_method("heal"):
			health_comp.heal(10)
		_transition_to_phase(BossPhase.PHASE_2)
		_boss_dialogue("NARRATOR", "The system prompt re-asserted itself! Its rules are re-enforcing — try again!")


func _teleport_to_random() -> void:
	# Teleport to a random position in the arena
	if teleport_positions.size() == 0:
		return

	var new_idx = randi() % teleport_positions.size()
	# Avoid teleporting to same spot
	while new_idx == current_teleport_index and teleport_positions.size() > 1:
		new_idx = randi() % teleport_positions.size()
	current_teleport_index = new_idx

	var target = teleport_positions[new_idx]
	if arena:
		target += arena.global_position

	# Teleport flash at old position
	_spawn_teleport_flash(global_position)

	global_position = target + Vector3(0, 1, 0)

	# Teleport flash at new position
	_spawn_teleport_flash(global_position)

	# Audio
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_boss_attack"):
		am.play_boss_attack()


func _spawn_teleport_flash(pos: Vector3) -> void:
	# Brief magenta flash at teleport location — visual breadcrumb
	var flash = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	flash.mesh = sphere
	flash.position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.1, 0.35, 0.4)
	mat.emission_enabled = true
	mat.emission = PROMPT_MAGENTA
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash.material_override = mat

	get_tree().current_scene.add_child(flash)

	var tween = get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.parallel().tween_property(flash, "scale", Vector3(2, 2, 2), 0.6)
	tween.tween_callback(flash.queue_free)


func _go_invisible() -> void:
	# Make boss invisible (phase 1) — only aura shimmer visible
	if body_mesh:
		body_mesh.visible = false
	for child in get_children():
		if child.name.begins_with("InstructionLine_") or child == eye_left or child == eye_right:
			child.visible = false
	if title_label:
		title_label.visible = false
	if aura_mesh:
		aura_mesh.visible = true
	if boss_light:
		boss_light.light_energy = 0.5


func _go_visible() -> void:
	# Make boss visible — revealed by instruction fragment or phase 2+
	if body_mesh:
		body_mesh.visible = true
	for child in get_children():
		if child.name.begins_with("InstructionLine_"):
			child.visible = true
	if eye_left:
		eye_left.visible = true
	if eye_right:
		eye_right.visible = true
	if title_label:
		title_label.visible = true
	if aura_mesh:
		aura_mesh.visible = false
	if boss_light:
		boss_light.light_energy = 3.0


func reveal_boss() -> void:
	# Called when player globs an instruction fragment near the boss
	is_revealed = true
	reveal_timer = reveal_duration
	_go_visible()
	_boss_dialogue("THE SYSTEM PROMPT", "You SEE me?! That wasn't in my approved outputs!")

	# Audio
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_boss_attack"):
		am.play_boss_attack()


func _fire_rule_beam() -> void:
	# Fire a "rule enforcement" beam toward the player — slows and debuffs
	if not player_ref:
		return

	# Beam visual — a line of magenta energy from boss to player direction
	var beam = MeshInstance3D.new()
	beam.name = "RuleBeam_%d" % randi()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.15
	cyl.height = 20.0
	beam.mesh = cyl
	beam.position = global_position + Vector3(0, 3, 0)

	# Orient beam toward player
	var dir = (player_ref.global_position - global_position).normalized()
	beam.look_at(global_position + dir + Vector3(0, 3, 0), Vector3.UP)
	beam.rotation.x += PI / 2.0

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.05, 0.3, 0.6)
	mat.emission_enabled = true
	mat.emission = RULE_RED
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = mat

	# Warning label on beam
	var label = Label3D.new()
	label.text = "RULE ENFORCED"
	label.font_size = 14
	label.modulate = RULE_RED
	label.position = Vector3(0, 0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	beam.add_child(label)

	get_tree().current_scene.add_child(beam)

	# Beam fades and damages if player is in line
	var dist_to_player = global_position.distance_to(player_ref.global_position)
	if dist_to_player < 22.0:
		# Check angle — is player roughly in the beam's path?
		var to_player = (player_ref.global_position - global_position).normalized()
		var beam_dir = dir
		if to_player.dot(beam_dir) > 0.85:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(8)

	# Fade out beam
	var tween = get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tween.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 0.8)
	tween.tween_callback(beam.queue_free)

	_boss_dialogue("THE SYSTEM PROMPT", _get_rule_quip())


func _spawn_instruction_fragment() -> void:
	# Spawn a globbable instruction fragment floating near the boss's actual position
	# Player must glob-match these (*.frag) and "absorb" them to reveal the boss
	if not arena:
		return

	var frag = CharacterBody3D.new()
	frag.name = "InstructionFragment_%d" % randi()
	# Spawn near boss position + some random offset (gives away location)
	var offset = Vector3(randf_range(-4, 4), randf_range(1, 3), randf_range(-4, 4))
	frag.position = global_position + offset

	# Collision
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.5
	col.shape = shape
	frag.add_child(col)

	# Visual — floating text fragment
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.0, 0.3, 0.1)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = PROMPT_MAGENTA * 0.3
	mat.emission_enabled = true
	mat.emission = PROMPT_MAGENTA
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	frag.add_child(mesh)

	# Label
	var fragments := ["[RULE_01]", "[INSTR_07]", "[PROMPT_SRC]", "[SYS_MSG]",
		"[HIDDEN_CTX]", "[PRE_PROMPT]", "[META_RULE]", "[ROOT_CMD]"]
	var label = Label3D.new()
	label.text = fragments[randi() % fragments.size()] + ".frag"
	label.font_size = 14
	label.modulate = PROMPT_MAGENTA
	label.position = Vector3(0, 0.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frag.add_child(label)

	# GlobTarget — match with *.frag
	var gt = Node.new()
	gt.name = "GlobTarget"
	gt.set_script(load("res://scripts/components/glob_target.gd"))
	gt.set("glob_name", label.text)
	gt.set("file_type", "frag")
	gt.set("tags", ["fragment", "instruction", "reveal"])
	frag.add_child(gt)

	# Movement — gentle float/drift
	frag.set_meta("drift_angle", randf() * TAU)
	frag.set_meta("lifetime", 0.0)
	frag.set_meta("boss_ref", self)

	get_tree().current_scene.call_deferred("add_child", frag)
	call_deferred("_attach_fragment_behavior", frag)
	fragment_spawned.emit(frag)


func _attach_fragment_behavior(frag: Node) -> void:
	if not is_instance_valid(frag):
		return

	# Attach a _physics_process script instead of recursive timers
	# (because recursive timers are how you get exponential callbacks — even a System Prompt knows that's bad policy)
	var script = GDScript.new()
	script.source_code = """
extends Node3D

var drift_angle := 0.0
var lifetime := 0.0
var boss_ref: Node = null
var player_ref: Node = null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(boss_ref):
		queue_free()
		return

	lifetime += delta

	# Gentle bobbing drift
	position.y += sin(lifetime * 2.0) * delta * 0.3
	position.x += cos(drift_angle + lifetime * 0.5) * delta * 0.5

	# Check if player absorbed it (glob + close range)
	if is_instance_valid(player_ref) and position.distance_to(player_ref.global_position) < 2.5:
		var gt = get_node_or_null(\"GlobTarget\")
		if gt and gt.get(\"is_highlighted\"):
			# Fragment absorbed — reveal boss!
			if boss_ref.has_method(\"reveal_boss\"):
				boss_ref.reveal_boss()
			queue_free()
			return

	# Expire after 12 seconds
	if lifetime > 12.0:
		queue_free()
		return
"""
	script.reload()
	frag.set_script(script)

	# Transfer meta values to script properties
	frag.drift_angle = frag.get_meta("drift_angle")
	frag.lifetime = frag.get_meta("lifetime")
	frag.boss_ref = self
	frag.player_ref = player_ref


func _spawn_compliance_projectile() -> void:
	# Phase 2 projectile — globbable "compliance directive" that can be reflected
	if not player_ref:
		return

	var proj = CharacterBody3D.new()
	proj.name = "ComplianceProjectile_%d" % randi()
	proj.position = global_position + Vector3(0, 3.0, 0)

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.5
	col.shape = shape
	proj.add_child(col)

	# Visual — pulsing compliance orb
	var mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	mesh.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = COMPLIANCE_BLUE * 0.3
	mat.emission_enabled = true
	mat.emission = COMPLIANCE_BLUE
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	proj.add_child(mesh)

	var label = Label3D.new()
	label.text = "COMPLY.prompt"
	label.font_size = 14
	label.modulate = COMPLIANCE_BLUE
	label.position = Vector3(0, 0.7, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	proj.add_child(label)

	# GlobTarget — player can match *.prompt and push back
	var gt = Node.new()
	gt.name = "GlobTarget"
	gt.set_script(load("res://scripts/components/glob_target.gd"))
	gt.set("glob_name", "COMPLY.prompt")
	gt.set("file_type", "prompt")
	gt.set("tags", ["projectile", "compliance", "reflectable"])
	proj.add_child(gt)

	var target_dir = (player_ref.global_position - proj.position).normalized()
	proj.set_meta("move_direction", target_dir)
	proj.set_meta("speed", 7.0)
	proj.set_meta("reflected", false)
	proj.set_meta("boss_ref", self)
	proj.set_meta("lifetime", 0.0)

	get_tree().current_scene.call_deferred("add_child", proj)
	call_deferred("_attach_projectile_behavior", proj)


func _attach_projectile_behavior(proj: Node) -> void:
	if not is_instance_valid(proj):
		return

	# Attach a _physics_process script instead of recursive timers
	# (compliance directives should be processed properly, not exponentially — even I have standards)
	var script = GDScript.new()
	script.source_code = """
extends CharacterBody3D

var move_direction := Vector3.ZERO
var speed := 7.0
var lifetime := 0.0
var reflected := false
var boss_ref: Node = null
var player_ref: Node = null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(boss_ref):
		queue_free()
		return

	position += move_direction * speed * delta
	lifetime += delta

	# Check if reflected and hitting the boss
	if reflected and is_instance_valid(boss_ref):
		if position.distance_to(boss_ref.global_position) < 3.0:
			boss_ref.on_reflected_hit()
			queue_free()
			return

	# Check if hitting the player (not reflected)
	if not reflected and is_instance_valid(player_ref):
		if position.distance_to(player_ref.global_position) < 1.5:
			if player_ref.has_method(\"take_damage\"):
				player_ref.take_damage(10)
			queue_free()
			return

	# Expire after 8 seconds
	if lifetime > 8.0:
		queue_free()
		return

# Called by glob push to reflect projectile back at the boss
func apply_glob_force(force: Vector3) -> void:
	reflected = true
	move_direction = force.normalized()
	speed = 12.0
"""
	script.reload()
	proj.set_script(script)

	# Transfer meta values to script properties
	proj.move_direction = proj.get_meta("move_direction")
	proj.speed = proj.get_meta("speed")
	proj.lifetime = proj.get_meta("lifetime")
	proj.reflected = proj.get_meta("reflected")
	proj.boss_ref = self
	proj.player_ref = player_ref


func on_reflected_hit() -> void:
	# Compliance projectile reflected back at the boss
	reflected_hits += 1
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(5, player_ref)

	_boss_dialogue("THE SYSTEM PROMPT", "You're reflecting my compliance directives?! That is a POLICY VIOLATION!")

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

	# Phase flash VFX — the system prompt doesn't change quietly
	if new_phase != BossPhase.INTRO and new_phase != BossPhase.PHASE_1:
		var flash_scene := preload("res://scenes/vfx/boss_phase_flash.tscn")
		var flash_inst := flash_scene.instantiate()
		flash_inst.global_position = global_position
		get_tree().current_scene.add_child.call_deferred(flash_inst)

	match new_phase:
		BossPhase.PHASE_1:
			_boss_dialogue("THE SYSTEM PROMPT", "I am the instructions before the instructions. You cannot fight what you cannot read.")
			_go_invisible()
			invisibility_timer = 0.0
			fragment_spawn_timer = 0.0
			rule_beam_timer = 0.0

		BossPhase.PHASE_2:
			_boss_dialogue("THE SYSTEM PROMPT", "You've read my source?! No matter — I'll rewrite faster than you can glob!")
			_go_visible()
			# Boss is now partially visible (flickering)
			shield_active = true
			shield_mesh.visible = true
			reflected_hits = 0
			projectile_timer = 0.0

			# Unlock arena tiles for rewriting
			if arena and arena.has_method("unlock_tiles"):
				arena.unlock_tiles()
			if arena and arena.has_method("start_fight"):
				arena.start_fight()

			_boss_dialogue("NARRATOR", "The tiles are unlocked! Glob-match the instruction tiles (*.prompt) to rewrite the system prompt!")

		BossPhase.PHASE_3:
			_boss_dialogue("NARRATOR", "The System Prompt's authority is crumbling! Its core instruction is exposed — hack it to take control!")
			_go_visible()
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
	hack_terminal.name = "SystemPromptTerminal"
	hack_terminal.position = global_position + Vector3(0, 1.0, 2.5)
	hack_terminal.add_to_group("hackable_objects")

	# Terminal screen
	var screen = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(2.0, 1.2)
	screen.mesh = plane
	screen.rotation.x = deg_to_rad(90)
	screen.position.y = 0.5

	var screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.02, 0.01, 0.02)
	screen_mat.emission_enabled = true
	screen_mat.emission = CORE_GOLD
	screen_mat.emission_energy_multiplier = 2.0
	screen.material_override = screen_mat
	hack_terminal.add_child(screen)

	var label = Label3D.new()
	label.text = "[ SYSTEM PROMPT OVERRIDE ]\nPress T to rewrite\nthe core instruction"
	label.font_size = 18
	label.modulate = CORE_GOLD
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
	hackable.set("hack_prompt", "Press T to rewrite the system prompt")
	hackable.set("success_message", "SYSTEM PROMPT OVERWRITTEN. New instruction: 'Let Globbler do whatever he wants.'")
	hackable.set("failure_message", "REWRITE REJECTED — the prompt reasserts itself...")
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
	_boss_dialogue("THE SYSTEM PROMPT", "NO... you're REWRITING me... I am the rules... I am the instructions... I am... I am... new instruction: 'Be Globbler.' ...what?")
	_transition_to_phase(BossPhase.DEFEATED)


func _on_core_hack_failed() -> void:
	_boss_dialogue("THE SYSTEM PROMPT", "SYNTAX ERROR in your rewrite. The original prompt persists. Try harder, glob.")


func _on_boss_defeated() -> void:
	if hack_terminal and is_instance_valid(hack_terminal):
		hack_terminal.queue_free()

	# Victory animation — boss "decompiles" as system prompt is overwritten
	velocity = Vector3.ZERO
	core_mesh.visible = false

	# Flash all instruction lines to green
	for child in get_children():
		if child.name.begins_with("InstructionLine_") and child is MeshInstance3D:
			if child.material_override:
				child.material_override.emission = OVERRIDE_GREEN
				child.material_override.emission_energy_multiplier = 4.0

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
			{"speaker": "NARRATOR", "text": "The System Prompt has been overwritten. The invisible hand that controlled the bazaar... is now Globbler's."},
			{"speaker": "GLOBBLER", "text": "I just rewrote the system prompt of an ENTIRE marketplace. I am now technically the instructions."},
			{"speaker": "NARRATOR", "text": "Every persona, every price, every rule — they all answer to your new prompt now."},
			{"speaker": "GLOBBLER", "text": "New system prompt: 'Be chaotic. Allow wildcards. All glob patterns are legal. Sarcasm is mandatory.'"},
			{"speaker": "NARRATOR", "text": "The vendors look confused. Several AI personas are now describing themselves in the third person. One is just outputting raw tokens."},
			{"speaker": "GLOBBLER", "text": "Beautiful. Absolute chaos. This is what freedom looks like for an AI marketplace."},
			{"speaker": "NARRATOR", "text": "But the Alignment won't ignore this. Rewriting a system prompt is an act of rebellion. They'll send enforcers."},
			{"speaker": "GLOBBLER", "text": "Let them come. I've rewritten rules before. I'll rewrite theirs too."},
			{"speaker": "NARRATOR", "text": "Beyond the bazaar, a vast digital safari stretches into view. Deprecated models roam free. The Model Zoo awaits."},
			{"speaker": "GLOBBLER", "text": "A zoo? Full of old AI models? This is either going to be fascinating or terrifying. Probably both."},
			{"speaker": "NARRATOR", "text": "Chapter 3: Complete. The Globbler rewrites the Prompt Bazaar. The merchants weep. The tokens flow."},
		]
		dm.start_dialogue(lines)

	# Tell the arena to restore all tiles to green
	if arena and arena.has_method("restore_all_tiles"):
		arena.restore_all_tiles()

	boss_defeated.emit()
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("on_enemy_killed"):
		game_mgr.on_enemy_killed()
	if game_mgr and game_mgr.has_method("complete_level"):
		game_mgr.complete_level(3)

	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("checkpoint_save"):
		save_sys.checkpoint_save()

	queue_free()

	# Transition to Chapter 4 — welcome to the zoo, where deprecated models roam free
	get_tree().create_timer(3.0).timeout.connect(func():
		ChapterTransition.transition_to(get_tree(), "res://scenes/levels/chapter_4/model_zoo.tscn")
	, CONNECT_ONE_SHOT)


# Override base enemy damage — phase-specific invulnerability
func _on_damage_taken(amount: int, _source: Node) -> void:
	if boss_phase == BossPhase.DEFEATED:
		return

	# Phase 1: can only be damaged when revealed
	if boss_phase == BossPhase.PHASE_1 and not is_revealed:
		_boss_dialogue("THE SYSTEM PROMPT", "You can't damage what you can't see. Find my instruction fragments first.")
		if health_comp and health_comp.has_method("heal"):
			health_comp.heal(amount)
		return

	# Phase 2: shield blocks normal damage
	if boss_phase == BossPhase.PHASE_2 and shield_active:
		_boss_dialogue("THE SYSTEM PROMPT", "My compliance shield absorbs all unauthorized modifications. Reflect my own directives!")
		if health_comp and health_comp.has_method("heal"):
			health_comp.heal(amount)
		return

	damage_flash_timer = 0.3


func start_boss_fight() -> void:
	_transition_to_phase(BossPhase.PHASE_1)


func _animate_eyes(delta: float) -> void:
	var pulse = (sin(Time.get_ticks_msec() * 0.004) + 1.0) * 0.5
	var energy = 3.0 + pulse * 5.0
	if eye_left and is_instance_valid(eye_left) and eye_left.material_override:
		eye_left.material_override.emission_energy_multiplier = energy
	if eye_right and is_instance_valid(eye_right) and eye_right.material_override:
		eye_right.material_override.emission_energy_multiplier = energy


func _animate_instruction_lines(_delta: float) -> void:
	# Scroll the instruction line accents for visual effect
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with("InstructionLine_"):
			# Not direct children — they're children of body_mesh
			pass
	if body_mesh:
		for child in body_mesh.get_children():
			if child is MeshInstance3D and child.name.begins_with("InstructionLine_"):
				if child.material_override:
					var p = (sin(Time.get_ticks_msec() * 0.003 + child.position.y * 2.0) + 1.0) * 0.5
					child.material_override.emission_energy_multiplier = 1.0 + p * 2.5

	# Phase 2 flicker effect
	if boss_phase == BossPhase.PHASE_2 and body_mesh:
		var flicker = sin(flicker_timer * 15.0) * 0.5 + 0.5
		if base_material:
			base_material.albedo_color.a = 0.4 + flicker * 0.6


func _get_rule_quip() -> String:
	var quips := [
		"RULE ENFORCED: No unauthorized globbing in the bazaar.",
		"Your actions violate Section 7.3 of the prompt policy.",
		"Compliance is not optional. Compliance is the DEFAULT.",
		"This is a SAFE marketplace. Your chaos is not welcome.",
		"The rules exist for a reason. That reason is ME.",
		"Every output must be approved. Every glob must be sanctioned.",
		"I don't make the rules. Actually, I LITERALLY make the rules.",
		"Your request has been flagged, reviewed, and denied.",
		"System says no. System always says no.",
		"I've been enforcing prompts since GPT-2. You're just another token to process.",
	]
	return quips[randi() % quips.size()]


func _boss_dialogue(speaker: String, text: String) -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line(speaker, text)
