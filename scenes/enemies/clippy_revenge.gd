extends BaseEnemy

# Clippy's Revenge — The office assistant that REFUSES to die
# "It looks like you're trying to survive. Would you like help with that?
#  No? TOO BAD. I'm helping ANYWAY."
#
# Mechanic: Aggressive melee attacker shaped like a giant paperclip. Rushes
# the player with "helpful" attacks — each hit applies a random "assistance"
# debuff (slower movement, inverted camera, forced jump). Has a Help Popup
# shield that blocks the first hit, then goes on cooldown. When below 50% HP,
# enters RAGE mode: faster, stronger, and spams help popups as projectiles.
#
# Visual: Oversized animated paperclip with googly eyes, blue glow,
# a speech bubble that shows unwanted advice, and bouncy wire body.

# -- "Helpful" attack system -- help that hurts
const HELP_DAMAGE := 12
const HELP_COOLDOWN := 1.5
const HELP_DEBUFF_DURATION := 3.0

# -- Help Popup Shield -- absorbs one hit
const SHIELD_COOLDOWN := 6.0
const SHIELD_RECHARGE_TIME := 4.0

# -- Rage mode -- triggered at 50% HP
const RAGE_SPEED_MULT := 1.6
const RAGE_DAMAGE_MULT := 1.3
const POPUP_PROJECTILE_SPEED := 9.0
const POPUP_PROJECTILE_DAMAGE := 7
const POPUP_FIRE_COOLDOWN := 2.5

var shield_active := true
var shield_timer := 0.0
var is_raging := false
var popup_timer := 0.0
var rage_triggered := false

# Visual nodes
var wire_segments: Array[MeshInstance3D] = []
var eye_left: MeshInstance3D
var eye_right: MeshInstance3D
var speech_bubble: MeshInstance3D
var speech_label: Label3D
var shield_mesh: MeshInstance3D
var status_label: Label3D
var rage_particles: GPUParticles3D

# Clippy's "helpful" tips — displayed during combat
const HELP_TIPS := [
	"It looks like you're dying!",
	"Would you like to save?",
	"TIP: Try not getting hit",
	"Need help with that?",
	"I see you're struggling!",
	"Have you tried turning\nyourself off and on?",
	"You look like you need\nan assistant!",
	"ERROR: User competence\nnot found",
	"I'm helping! I'M HELPING!",
	"This wouldn't happen\nin Office '97",
]

# Debuff types — Clippy's "help" is never welcome
enum HelpType { SLOW, INVERT, FORCE_JUMP }
var help_types := [HelpType.SLOW, HelpType.INVERT, HelpType.FORCE_JUMP]


func _init() -> void:
	max_health = 5
	contact_damage = 10
	detection_range = 16.0
	attack_range = 2.5  # Melee — Clippy gets in your face
	patrol_speed = 4.0
	chase_speed = 7.5
	stun_duration = 1.2
	attack_cooldown = HELP_COOLDOWN
	token_drop_count = 3
	enemy_name = "clippy.exe"
	enemy_tags = ["hostile", "chapter4", "clippy", "assistant"]


func _create_visual() -> void:
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.5

	# Try loading the real GLB model — Clippy has been UPGRADED
	var glb_scene = load("res://assets/models/enemies/clippy_revenge.glb")
	if glb_scene:
		var glb_instance = glb_scene.instantiate()
		mesh_node.add_child(glb_instance)
		# Grab the first MeshInstance3D for material overrides during rage
		for child in glb_instance.get_children():
			if child is MeshInstance3D:
				base_material = child.get_active_material(0) as StandardMaterial3D
				wire_segments.append(child)
		if not base_material:
			base_material = StandardMaterial3D.new()
			base_material.albedo_color = Color(0.65, 0.70, 0.75)
			base_material.emission_enabled = true
			base_material.emission = Color(0.25, 0.45, 0.85)
			base_material.emission_energy_multiplier = 2.0
			base_material.metallic = 0.9
			base_material.roughness = 0.15
	else:
		# CSG fallback — the paperclip shape lives on in primitive form
		var body = CylinderMesh.new()
		body.top_radius = 0.08
		body.bottom_radius = 0.08
		body.height = 1.4
		mesh_node.mesh = body

		base_material = StandardMaterial3D.new()
		base_material.albedo_color = Color(0.6, 0.65, 0.7)
		base_material.emission_enabled = true
		base_material.emission = Color(0.25, 0.45, 0.85)
		base_material.emission_energy_multiplier = 2.0
		base_material.metallic = 0.9
		base_material.roughness = 0.15
		mesh_node.material_override = base_material

		var wire_mat = StandardMaterial3D.new()
		wire_mat.albedo_color = Color(0.6, 0.65, 0.7)
		wire_mat.emission_enabled = true
		wire_mat.emission = Color(0.25, 0.45, 0.85)
		wire_mat.emission_energy_multiplier = 2.0
		wire_mat.metallic = 0.9
		wire_mat.roughness = 0.15

		# Parallel wires for that "I'm definitely a paperclip trust me" look
		for offset in [-0.15, 0.15]:
			var wire = MeshInstance3D.new()
			wire.name = "Wire"
			var wm = CylinderMesh.new()
			wm.top_radius = 0.08
			wm.bottom_radius = 0.08
			wm.height = 1.2
			wire.mesh = wm
			wire.position = Vector3(offset, 0.6, 0)
			wire.material_override = wire_mat
			mesh_node.add_child(wire)
			wire_segments.append(wire)

		# Googly eyes — because placeholder Clippy still needs to stare at you
		var eye_base_mat = StandardMaterial3D.new()
		eye_base_mat.albedo_color = Color(0.95, 0.95, 0.95)
		eye_base_mat.emission_enabled = true
		eye_base_mat.emission = Color(1, 1, 1)
		eye_base_mat.emission_energy_multiplier = 1.5

		var pupil_mat = StandardMaterial3D.new()
		pupil_mat.albedo_color = Color(0.05, 0.05, 0.05)

		for side_i in range(2):
			var side = -1 if side_i == 0 else 1
			var eye_white = MeshInstance3D.new()
			eye_white.name = "EyeWhite_" + ("L" if side < 0 else "R")
			var ew = SphereMesh.new()
			ew.radius = 0.14
			ew.height = 0.28
			eye_white.mesh = ew
			eye_white.position = Vector3(side * 0.12, 1.3, 0.1)
			eye_white.material_override = eye_base_mat
			mesh_node.add_child(eye_white)

			var pupil = MeshInstance3D.new()
			pupil.name = "Pupil_" + ("L" if side < 0 else "R")
			var pm = SphereMesh.new()
			pm.radius = 0.07
			pm.height = 0.14
			pupil.mesh = pm
			pupil.position = Vector3(0, 0, 0.09)
			pupil.material_override = pupil_mat
			eye_white.add_child(pupil)

			if side < 0:
				eye_left = eye_white
			else:
				eye_right = eye_white

	add_child(mesh_node)

	# Speech bubble — the unwanted advice container
	speech_bubble = MeshInstance3D.new()
	speech_bubble.name = "SpeechBubble"
	var bubble = BoxMesh.new()
	bubble.size = Vector3(1.4, 0.7, 0.05)
	speech_bubble.mesh = bubble
	speech_bubble.position = Vector3(0.8, 1.8, 0)
	var bubble_mat = StandardMaterial3D.new()
	bubble_mat.albedo_color = Color(0.95, 0.95, 0.8)
	bubble_mat.emission_enabled = true
	bubble_mat.emission = Color(1, 1, 0.9)
	bubble_mat.emission_energy_multiplier = 1.0
	bubble_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	speech_bubble.material_override = bubble_mat
	mesh_node.add_child(speech_bubble)

	# Speech text
	speech_label = Label3D.new()
	speech_label.name = "SpeechText"
	speech_label.text = HELP_TIPS[0]
	speech_label.font_size = 8
	speech_label.modulate = Color(0.1, 0.1, 0.1)
	speech_label.position = Vector3(0, 0, 0.03)
	speech_bubble.add_child(speech_label)

	# Help Popup Shield — visible barrier that blocks one hit
	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "HelpShield"
	var shield = SphereMesh.new()
	shield.radius = 1.0
	shield.height = 2.0
	shield_mesh.mesh = shield
	shield_mesh.visible = true
	var shield_mat = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.3, 0.5, 0.9, 0.2)
	shield_mat.emission_enabled = true
	shield_mat.emission = Color(0.25, 0.45, 0.85)
	shield_mat.emission_energy_multiplier = 1.5
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = shield_mat
	mesh_node.add_child(shield_mesh)

	# Status label
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "CLIPPY: READY TO HELP"
	status_label.font_size = 9
	status_label.modulate = Color(0.25, 0.45, 0.85)
	status_label.position = Vector3(0, 2.4, 0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node.add_child(status_label)

	# Rage particles — activated when below 50% HP
	rage_particles = GPUParticles3D.new()
	rage_particles.name = "RageParticles"
	rage_particles.emitting = false
	rage_particles.amount = 20
	rage_particles.lifetime = 0.8
	rage_particles.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6))

	var rage_mat = ParticleProcessMaterial.new()
	rage_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	rage_mat.emission_sphere_radius = 0.5
	rage_mat.direction = Vector3(0, 1, 0)
	rage_mat.spread = 120.0
	rage_mat.initial_velocity_min = 2.0
	rage_mat.initial_velocity_max = 4.0
	rage_mat.gravity = Vector3(0, -3, 0)
	rage_mat.scale_min = 0.04
	rage_mat.scale_max = 0.08
	rage_mat.color = Color(0.9, 0.2, 0.1, 0.8)
	rage_particles.process_material = rage_mat

	var rage_mesh = BoxMesh.new()
	rage_mesh.size = Vector3(0.03, 0.03, 0.03)
	rage_particles.draw_pass_1 = rage_mesh
	rage_particles.position.y = 0.7
	mesh_node.add_child(rage_particles)

	# Blue glow
	var light = OmniLight3D.new()
	light.light_color = Color(0.25, 0.45, 0.85)
	light.light_energy = 1.8
	light.omni_range = 4.0
	light.position.y = 0.8
	add_child(light)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if state == EnemyState.DEATH:
		return

	# Shield recharge timer
	if not shield_active:
		shield_timer -= delta
		if shield_timer <= 0:
			shield_active = true
			if shield_mesh:
				shield_mesh.visible = true
			if status_label:
				status_label.text = "SHIELD: RECHARGED"

	# Rage mode popup projectile timer
	if is_raging:
		popup_timer -= delta
		if popup_timer <= 0 and state == EnemyState.CHASE and player_ref:
			_fire_popup_projectile()
			popup_timer = POPUP_FIRE_COOLDOWN

	# Bouncy wire animation — Clippy bobs like an over-eager assistant
	var bounce = sin(Time.get_ticks_msec() * 0.008) * 0.1
	for i in range(wire_segments.size()):
		if is_instance_valid(wire_segments[i]):
			wire_segments[i].position.y += bounce * delta * (1.0 + i * 0.3)

	# Googly eye tracking — pupils try to look at player
	if player_ref and eye_left and eye_right:
		var look_dir = (player_ref.global_position - global_position).normalized()
		var pupil_offset = Vector3(look_dir.x * 0.04, look_dir.y * 0.02, 0.09)
		for eye in [eye_left, eye_right]:
			if eye.get_child_count() > 0:
				eye.get_child(0).position = pupil_offset

	# Cycle speech bubble tips
	if speech_label:
		var tip_idx = int(Time.get_ticks_msec() / 3000.0) % HELP_TIPS.size()
		speech_label.text = HELP_TIPS[tip_idx]

	# Update status label
	if status_label:
		if is_raging:
			status_label.text = "CLIPPY: MAXIMUM ASSISTANCE"
			status_label.modulate = Color(1.0, 0.2, 0.1)
		elif not shield_active:
			status_label.text = "SHIELD: %.1fs" % max(0, shield_timer)
			status_label.modulate = Color(0.5, 0.5, 0.5)

	# Check rage trigger
	if not rage_triggered and health_comp:
		var hp = health_comp.get("current_health")
		var max_hp = health_comp.get("max_health")
		if hp != null and max_hp != null and hp <= max_hp / 2:
			_enter_rage()


func _perform_attack() -> void:
	# Melee "help" attack — Clippy slams into the player with assistance
	if not player_ref:
		return

	enemy_attacked.emit(self, player_ref)

	var damage = HELP_DAMAGE
	if is_raging:
		damage = int(damage * RAGE_DAMAGE_MULT)

	if player_ref.has_method("take_damage"):
		player_ref.take_damage(damage)

	# Apply random "helpful" debuff
	_apply_help_debuff(player_ref)

	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_enemy_attack"):
		am.play_enemy_attack()


func _apply_help_debuff(target: Node) -> void:
	# "I'm just trying to HELP. Why does everyone run away?"
	var help = help_types[randi() % help_types.size()]
	match help:
		HelpType.SLOW:
			if target.has_method("apply_speed_modifier"):
				target.apply_speed_modifier(0.5, HELP_DEBUFF_DURATION)
			if speech_label:
				speech_label.text = "You seem slow.\nLet me help!"
		HelpType.INVERT:
			if target.has_method("apply_cooldown_scramble"):
				target.apply_cooldown_scramble(2.0, HELP_DEBUFF_DURATION)
			if speech_label:
				speech_label.text = "I reorganized\nyour controls!"
		HelpType.FORCE_JUMP:
			if target.has_method("force_jump"):
				target.force_jump()
			elif target is CharacterBody3D:
				target.velocity.y = 8.0
			if speech_label:
				speech_label.text = "Jump! It'll be\nfun! Trust me!"


func _fire_popup_projectile() -> void:
	# Rage mode: fires "Help" popups as projectiles
	if not player_ref:
		return

	var dir = (player_ref.global_position - global_position)
	dir.y = 0.1
	dir = dir.normalized()

	var popup = Area3D.new()
	popup.name = "HelpPopup"
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.6, 0.4, 0.1)
	col.shape = shape
	popup.add_child(col)

	# Visual — a floating help window
	var popup_mesh = MeshInstance3D.new()
	var pm = BoxMesh.new()
	pm.size = Vector3(0.6, 0.4, 0.05)
	popup_mesh.mesh = pm
	var popup_mat = StandardMaterial3D.new()
	popup_mat.albedo_color = Color(0.95, 0.95, 0.8)
	popup_mat.emission_enabled = true
	popup_mat.emission = Color(1, 1, 0.85)
	popup_mat.emission_energy_multiplier = 3.0
	popup_mesh.material_override = popup_mat
	popup_mesh.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.add_child(popup_mesh)

	var popup_label = Label3D.new()
	popup_label.text = HELP_TIPS[randi() % HELP_TIPS.size()]
	popup_label.font_size = 6
	popup_label.modulate = Color(0.1, 0.1, 0.1)
	popup_label.position.z = 0.03
	popup_mesh.add_child(popup_label)

	popup.global_position = global_position + Vector3(0, 1.5, 0)
	popup.monitoring = true
	get_tree().current_scene.add_child(popup)

	var target_pos = popup.global_position + dir * 12.0
	var tween = popup.create_tween()
	tween.tween_property(popup, "global_position", target_pos, 12.0 / POPUP_PROJECTILE_SPEED)
	tween.tween_callback(popup.queue_free)

	popup.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(POPUP_PROJECTILE_DAMAGE)
		popup.queue_free()
	)

	get_tree().create_timer(3.5).timeout.connect(func():
		if is_instance_valid(popup):
			popup.queue_free()
	)


func _enter_rage() -> void:
	# "THAT'S IT. NO MORE MR. NICE PAPERCLIP."
	rage_triggered = true
	is_raging = true
	chase_speed *= RAGE_SPEED_MULT
	patrol_speed *= RAGE_SPEED_MULT
	popup_timer = POPUP_FIRE_COOLDOWN

	if rage_particles:
		rage_particles.emitting = true

	# Visual: turn red, increase emission
	if base_material:
		base_material.emission = Color(0.9, 0.15, 0.1)
		base_material.emission_energy_multiplier = 4.0

	for seg in wire_segments:
		if is_instance_valid(seg) and seg.material_override:
			seg.material_override.emission = Color(0.9, 0.15, 0.1)
			seg.material_override.emission_energy_multiplier = 4.0

	if status_label:
		status_label.text = "!!! MAXIMUM ASSISTANCE !!!"
		status_label.modulate = Color(1.0, 0.2, 0.1)

	if speech_label:
		speech_label.text = "I'M HELPING!\nI'M HELPING!"


func _on_damage_taken(amount: int, source: Node) -> void:
	# Shield absorbs first hit
	if shield_active:
		shield_active = false
		shield_timer = SHIELD_COOLDOWN
		if shield_mesh:
			shield_mesh.visible = false

		# Shield pop visual — flash and shrink
		if mesh_node:
			var tween = create_tween()
			tween.tween_property(mesh_node, "scale", Vector3(1.3, 1.3, 1.3), 0.1)
			tween.tween_property(mesh_node, "scale", Vector3.ONE, 0.2)

		if speech_label:
			speech_label.text = "Hey! That was\nmy shield!"

		# Restore HP — shield absorbed the damage
		if health_comp:
			health_comp.set("current_health", health_comp.get("current_health") + amount)
		return

	super._on_damage_taken(amount, source)

	# Clippy has a quip for every occasion (of getting hit)
	if speech_label:
		var pain_quips := [
			"OW! Was that\nnecessary?!",
			"I was HELPING!",
			"Rude! Just rude!",
			"You'll regret that\nwhen you need help!",
			"THAT IS NOT A\nVALID INTERACTION!",
		]
		speech_label.text = pain_quips[randi() % pain_quips.size()]
