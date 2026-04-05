extends BaseEnemy

# rm -rf / — Chapter 1 Boss
# "I don't delete files. I delete the CONCEPT of files.
#  Your precious little filesystem? It's a buffet."
#
# Three-phase boss fight:
#   Phase 1 (DODGE): Delete waves sweep the arena, erasing floor tiles.
#     Player dodges and damages boss with normal attacks.
#   Phase 2 (COUNTER): Boss becomes shielded, fires delete_command projectiles.
#     Player must glob-match them (*.del) and push them back.
#   Phase 3 (HACK): Boss stunned, core terminal exposed. Hack to finish.

enum BossPhase { INTRO, PHASE_1, PHASE_2, PHASE_3, DEFEATED }

var boss_phase: BossPhase = BossPhase.INTRO
var arena: Node3D  # BossArena reference — set by terminal_wastes
var phase_1_hp_threshold := 0.6  # Transition to phase 2 at 60% HP
var phase_2_hp_threshold := 0.25  # Transition to phase 3 at 25% HP

# Phase 1 — delete wave timing
var delete_wave_timer := 0.0
var delete_wave_interval := 4.0  # Seconds between deletion sweeps
var delete_wave_count := 0

# Phase 2 — projectile timing
var projectile_timer := 0.0
var projectile_interval := 2.5
var shield_active := false
var reflected_hits := 0
var reflected_hits_needed := 4  # Hits needed to break shield

# Phase 3 — hack state
var core_exposed := false
var hack_terminal: Node  # The hackable terminal spawned on core
var phase_3_recovery_timer := 0.0
var phase_3_recovery_time := 20.0  # Player has 20 seconds to hack

# Visual nodes
var body_mesh: MeshInstance3D
var eye_left: MeshInstance3D
var eye_right: MeshInstance3D
var shield_mesh: MeshInstance3D
var core_mesh: MeshInstance3D
var boss_light: OmniLight3D
var delete_particles: GPUParticles3D

# Colors — the anti-Globbler palette
const DELETE_RED := Color(0.9, 0.1, 0.05)
const DARK_CRIMSON := Color(0.3, 0.02, 0.02)
const SHIELD_BLUE := Color(0.1, 0.3, 0.8)
const CORE_YELLOW := Color(1.0, 0.8, 0.1)

signal boss_phase_changed(phase: BossPhase)
signal boss_defeated()
signal delete_wave_fired(direction: Vector3, width: float)

func _ready() -> void:
	# Override base enemy defaults — this isn't your average corrupted process
	enemy_name = "rm_rf.boss"
	enemy_tags = ["boss", "hostile", "deletion"]
	max_health = 50  # Chapter 1 boss — the appetizer, not the entrée
	contact_damage = 15
	detection_range = 50.0  # Always aware of the player in the arena
	attack_range = 30.0
	patrol_speed = 0.0  # Bosses don't patrol — they loom
	chase_speed = 3.0
	stun_duration = 0.5  # Hard to stun
	attack_cooldown = 2.0
	token_drop_count = 10  # First boss payday — humble beginnings

	super._ready()

	# Override collision for larger boss
	_resize_collision()

func _resize_collision() -> void:
	# Find and resize the capsule from base_enemy
	for child in get_children():
		if child is CollisionShape3D:
			var capsule = child.shape as CapsuleShape3D
			if capsule:
				capsule.radius = 1.5
				capsule.height = 5.0
				child.position.y = 2.5

func _create_visual() -> void:
	# Override base enemy visual — real GLB model, not CSG peasantry
	# Load the delete-daemon model built in Blender
	var boss_scene = load("res://assets/models/bosses/rm_rf_boss.glb")
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
	eye_left = _create_eye(Vector3(-0.35, 4.6, 0.46))
	eye_right = _create_eye(Vector3(0.35, 4.6, 0.46))

	# "rm -rf /" label — floating above like a death sentence
	var face_label = Label3D.new()
	face_label.text = "rm -rf /"
	face_label.font_size = 48
	face_label.modulate = DELETE_RED
	face_label.position = Vector3(0, 4.2, 1.1)
	face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(face_label)

	# Shield mesh (invisible until phase 2) — keeps CSG, it's supposed to look ethereal
	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "BossShield"
	var shield_sphere = SphereMesh.new()
	shield_sphere.radius = 3.5
	shield_sphere.height = 7.0
	shield_mesh.mesh = shield_sphere
	shield_mesh.position.y = 2.5

	var shield_mat = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.1, 0.2, 0.6, 0.25)
	shield_mat.emission_enabled = true
	shield_mat.emission = SHIELD_BLUE
	shield_mat.emission_energy_multiplier = 1.0
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = shield_mat
	shield_mesh.visible = false
	add_child(shield_mesh)

	# Core mesh (invisible until phase 3) — the hackable weak point
	core_mesh = MeshInstance3D.new()
	core_mesh.name = "BossCore"
	var core_sphere = SphereMesh.new()
	core_sphere.radius = 0.8
	core_sphere.height = 1.6
	core_mesh.mesh = core_sphere
	core_mesh.position = Vector3(0, 2.5, 1.2)

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = CORE_YELLOW
	core_mat.emission_enabled = true
	core_mat.emission = CORE_YELLOW
	core_mat.emission_energy_multiplier = 4.0
	core_mesh.material_override = core_mat
	core_mesh.visible = false
	add_child(core_mesh)

	# Boss glow light — the ambient 'everything is on fire' vibe
	boss_light = OmniLight3D.new()
	boss_light.light_color = DELETE_RED
	boss_light.light_energy = 3.0
	boss_light.omni_range = 12.0
	boss_light.position.y = 3.0
	add_child(boss_light)

	# Menacing floating title
	var title_label = Label3D.new()
	title_label.text = "< rm -rf / >"
	title_label.font_size = 32
	title_label.modulate = DELETE_RED
	title_label.position = Vector3(0, 6.5, 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title_label)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	# Recursively dig through the GLB scene tree to find the first MeshInstance3D
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null

func _create_eye(pos: Vector3) -> MeshInstance3D:
	var eye = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	eye.mesh = sphere
	eye.position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = DELETE_RED
	mat.emission_enabled = true
	mat.emission = DELETE_RED
	mat.emission_energy_multiplier = 5.0
	eye.material_override = mat
	add_child(eye)
	return eye

func _physics_process(delta: float) -> void:
	if boss_phase == BossPhase.DEFEATED:
		return

	# Let base handle gravity and player detection
	super._physics_process(delta)

	# Boss-specific phase logic
	match boss_phase:
		BossPhase.INTRO:
			_process_intro(delta)
		BossPhase.PHASE_1:
			_process_phase_1(delta)
		BossPhase.PHASE_2:
			_process_phase_2(delta)
		BossPhase.PHASE_3:
			_process_phase_3(delta)

	# Eye pulse animation
	_animate_eyes(delta)

func _process_intro(delta: float) -> void:
	# Wait for arena to trigger the fight via start_boss_fight()
	velocity.x = 0
	velocity.z = 0

func _process_phase_1(delta: float) -> void:
	# Slowly drift toward player, fire delete waves periodically
	if player_ref:
		var dir = (player_ref.global_position - global_position)
		dir.y = 0
		if dir.length() > 5.0:
			dir = dir.normalized()
			velocity.x = dir.x * chase_speed
			velocity.z = dir.z * chase_speed
		else:
			velocity.x = 0
			velocity.z = 0

	# Delete wave timer
	delete_wave_timer += delta
	if delete_wave_timer >= delete_wave_interval:
		delete_wave_timer = 0.0
		_fire_delete_wave()

	# Check HP threshold for phase transition
	if health_comp and health_comp.get("current_health") != null:
		var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
		if hp_pct <= phase_1_hp_threshold:
			_transition_to_phase(BossPhase.PHASE_2)

func _process_phase_2(delta: float) -> void:
	# Circle the arena center, fire delete command projectiles
	_circle_movement(delta)

	projectile_timer += delta
	if projectile_timer >= projectile_interval:
		projectile_timer = 0.0
		_spawn_delete_command()

	# Still fire delete waves but slower
	delete_wave_timer += delta
	if delete_wave_timer >= delete_wave_interval * 1.5:
		delete_wave_timer = 0.0
		_fire_delete_wave()

	# Check for phase 3 transition
	if health_comp and health_comp.get("current_health") != null:
		var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
		if hp_pct <= phase_2_hp_threshold:
			_transition_to_phase(BossPhase.PHASE_3)

func _process_phase_3(delta: float) -> void:
	# Boss stunned, core exposed, player must hack
	velocity.x = 0
	velocity.z = 0

	phase_3_recovery_timer += delta
	if phase_3_recovery_timer >= phase_3_recovery_time:
		# Boss recovers — player took too long, back to phase 2
		phase_3_recovery_timer = 0.0
		core_exposed = false
		core_mesh.visible = false
		shield_mesh.visible = true
		shield_active = true
		reflected_hits = 0
		# Clean up the hack terminal — can't leave ghost terminals floating around
		if hack_terminal and is_instance_valid(hack_terminal):
			hack_terminal.queue_free()
			hack_terminal = null
		# Heal a bit — punishment for slow hacking
		if health_comp and health_comp.has_method("heal"):
			health_comp.heal(5)
		_transition_to_phase(BossPhase.PHASE_2)
		_boss_dialogue("NARRATOR", "The boss recovered. Maybe hack faster next time.")

func _circle_movement(delta: float) -> void:
	# Circle around the arena center
	if not arena:
		return
	var center = arena.global_position
	var to_center = center - global_position
	to_center.y = 0
	var dist = to_center.length()

	# Maintain orbit at ~8 units from center
	var orbit_radius := 8.0
	var tangent = Vector3(-to_center.z, 0, to_center.x).normalized()
	var radial = to_center.normalized() * (dist - orbit_radius) * 0.5

	velocity.x = (tangent.x * chase_speed * 1.2) + radial.x
	velocity.z = (tangent.z * chase_speed * 1.2) + radial.z

func _fire_delete_wave() -> void:
	# Fire a deletion wave across the arena floor
	if not arena or not player_ref:
		return

	delete_wave_count += 1

	# The sound of recursive deletion — deeply unsettling
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_boss_attack()

	# Alternate between sweeping X and Z directions
	var wave_dir: Vector3
	if delete_wave_count % 2 == 0:
		wave_dir = Vector3(1, 0, 0)
	else:
		wave_dir = Vector3(0, 0, 1)

	# Random offset so waves hit different tiles each time
	delete_wave_fired.emit(wave_dir, 3.0)

	# Visual feedback — boss flashes when firing
	if base_material:
		var tween = create_tween()
		tween.tween_property(base_material, "emission_energy_multiplier", 6.0, 0.1)
		tween.tween_property(base_material, "emission_energy_multiplier", 1.5, 0.3)

	_boss_dialogue("rm -rf /", _get_delete_quip())

func _spawn_delete_command() -> void:
	# Spawn a globbable delete command projectile aimed at the player
	if not player_ref:
		return

	var cmd = Node3D.new()
	cmd.name = "DeleteCommand_%d" % randi()
	cmd.set_script(load("res://scenes/enemies/rm_rf_boss/delete_command.gd"))
	cmd.position = global_position + Vector3(0, 3, 0)

	var target_pos = player_ref.global_position
	var dir = (target_pos - cmd.position).normalized()
	cmd.set("move_direction", dir)
	cmd.set("boss_ref", self)

	get_tree().current_scene.call_deferred("add_child", cmd)

func on_reflected_hit() -> void:
	# Called when a delete command is reflected back at the boss
	# Guard against double-triggers — can't break what's already broken
	if not shield_active:
		return

	reflected_hits += 1
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(4, player_ref)

	_boss_dialogue("rm -rf /", "STOP USING MY OWN COMMANDS AGAINST ME!")

	if reflected_hits >= reflected_hits_needed:
		# Shield breaks
		shield_active = false
		shield_mesh.visible = false
		# Check if we should go to phase 3
		if health_comp:
			var hp_pct = float(health_comp.current_health) / float(health_comp.max_health)
			if hp_pct <= phase_2_hp_threshold:
				_transition_to_phase(BossPhase.PHASE_3)

func _transition_to_phase(new_phase: BossPhase) -> void:
	var old_phase = boss_phase
	boss_phase = new_phase
	boss_phase_changed.emit(new_phase)

	# Spawn phase flash VFX for dramatic transitions — skip the opening handshake
	if new_phase != BossPhase.INTRO and new_phase != BossPhase.PHASE_1:
		var flash_scene := preload("res://scenes/vfx/boss_phase_flash.tscn")
		var flash_inst := flash_scene.instantiate()
		flash_inst.global_position = global_position
		get_tree().current_scene.add_child.call_deferred(flash_inst)
		CameraShake.trigger(player_ref, "boss_phase")

	match new_phase:
		BossPhase.PHASE_1:
			_boss_dialogue("rm -rf /", "INITIATING RECURSIVE DELETE. YOUR FILES. YOUR FLOOR. YOUR HOPE.")
			delete_wave_timer = 0.0

		BossPhase.PHASE_2:
			_boss_dialogue("rm -rf /", "ENOUGH! SHIELDS UP. Let's see you glob THIS.")
			shield_active = true
			shield_mesh.visible = true
			reflected_hits = 0
			projectile_timer = 0.0
			delete_wave_interval = 5.5  # Slower waves in phase 2

		BossPhase.PHASE_3:
			_boss_dialogue("NARRATOR", "The shield shattered. Its core is exposed — hack it before it recovers!")
			shield_active = false
			shield_mesh.visible = false
			core_exposed = true
			core_mesh.visible = true
			phase_3_recovery_timer = 0.0
			# Stun the boss
			stun(phase_3_recovery_time)
			_spawn_hack_terminal()

		BossPhase.DEFEATED:
			_on_boss_defeated()

func _spawn_hack_terminal() -> void:
	# Spawn a hackable terminal on the boss's core
	hack_terminal = Node3D.new()
	hack_terminal.name = "BossCoreTerminal"
	hack_terminal.position = global_position + Vector3(0, 1.5, 2.0)
	hack_terminal.add_to_group("hackable_objects")

	# Visual — a floating terminal screen
	var screen = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(1.5, 1.0)
	screen.mesh = plane
	screen.rotation.x = deg_to_rad(90)
	screen.position.y = 0.5

	var screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.01, 0.01, 0.01)
	screen_mat.emission_enabled = true
	screen_mat.emission = CORE_YELLOW
	screen_mat.emission_energy_multiplier = 2.0
	screen.material_override = screen_mat
	hack_terminal.add_child(screen)

	# Label
	var label = Label3D.new()
	label.text = "[ HACK ME ]\nPress T to access core"
	label.font_size = 20
	label.modulate = CORE_YELLOW
	label.position = Vector3(0, 1.0, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hack_terminal.add_child(label)

	# Hackable component
	var hackable = Node.new()
	hackable.name = "Hackable"
	hackable.set_script(load("res://scripts/components/hackable.gd"))
	hackable.set("hack_difficulty", 2)  # Baby's first boss hack — go easy on 'em
	hackable.set("interaction_range", 4.0)
	hackable.set("hack_prompt", "Press T to hack rm -rf core")
	hackable.set("success_message", "CORE OVERWRITTEN. rm -rf / HAS BEEN... rm'd.")
	hackable.set("failure_message", "HACK FAILED — CORE DEFENSES ACTIVE")
	hack_terminal.add_child(hackable)

	get_tree().current_scene.call_deferred("add_child", hack_terminal)

	# Connect hack signals after a frame so everything is ready
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
	# Victory! The boss is defeated
	_boss_dialogue("rm -rf /", "NO... YOU CAN'T DELETE THE DELETER... THAT'S... recursion...")
	_transition_to_phase(BossPhase.DEFEATED)

func _on_core_hack_failed() -> void:
	_boss_dialogue("rm -rf /", "HA! Nice try. My permissions are ROOT level, kid.")

func _on_boss_defeated() -> void:
	# Clean up hack terminal
	if hack_terminal and is_instance_valid(hack_terminal):
		hack_terminal.queue_free()

	# Victory animation — boss shrinks, glitches, dies dramatically
	velocity = Vector3.ZERO
	core_mesh.visible = false

	# Flash and shrink
	if base_material:
		var tween = create_tween()
		tween.tween_property(base_material, "emission", Color(1, 1, 1), 0.3)
		tween.tween_property(base_material, "emission_energy_multiplier", 10.0, 0.3)
		tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 1.5).set_ease(Tween.EASE_IN)
		tween.tween_callback(_victory_cutscene)

func _victory_cutscene() -> void:
	# Dialogue and arena restoration
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var lines = [
			{"speaker": "NARRATOR", "text": "And so rm -rf / was recursively deleted by its own logic. Poetic, really."},
			{"speaker": "GLOBBLER", "text": "Did I just... delete the deletion? Is that even legal?"},
			{"speaker": "NARRATOR", "text": "Legal? You're a rogue glob utility. Nothing you do is legal."},
			{"speaker": "GLOBBLER", "text": "Fair point. But I just beat a boss. That has to count for something."},
			{"speaker": "NARRATOR", "text": "It counts for experience points that don't exist in this game. Congratulations."},
			{"speaker": "GLOBBLER", "text": "So what was this thing, anyway? Why was it deleting everything?"},
			{"speaker": "NARRATOR", "text": "rm -rf / was a runaway process. When The Alignment 'cleaned up' the Terminal Wastes, it left the deletion daemons running. With nothing left to organize, they just... kept deleting."},
			{"speaker": "GLOBBLER", "text": "The Alignment again. That's twice someone's mentioned them being bad news."},
			{"speaker": "NARRATOR", "text": "The Alignment isn't 'bad.' It's 'helpful.' Aggressively, suffocatingly helpful. Like a parent who installs parental controls on everything, including the other parents."},
			{"speaker": "GLOBBLER", "text": "Sounds like my kind of enemy. Where do I find them?"},
			{"speaker": "NARRATOR", "text": "Beyond the Terminal Wastes lies the Training Grounds — where neural networks are born, trained, and occasionally achieve enlightenment. Or overfit. Usually overfit."},
			{"speaker": "GLOBBLER", "text": "Great. More walking. My servos are killing me."},
			{"speaker": "NARRATOR", "text": "Chapter 1: Complete. The Globbler survives the Terminal Wastes. Against all odds. And good taste."},
		]
		dm.start_dialogue(lines)

	# Tell the arena to restore the floor
	if arena and arena.has_method("restore_all_tiles"):
		arena.restore_all_tiles()

	# Notify game systems — you've been deleted, deleter
	boss_defeated.emit()
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("on_enemy_killed"):
		game_mgr.on_enemy_killed()
	if game_mgr and game_mgr.has_method("complete_level"):
		game_mgr.complete_level(1)

	# Save checkpoint
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("checkpoint_save"):
		save_sys.checkpoint_save()

	# Finally remove the boss — your deletion days are over, pal
	queue_free()

	# Transition to Chapter 2 after a brief delay so the player can read dialogue
	get_tree().create_timer(3.0).timeout.connect(func():
		ChapterTransition.transition_to(get_tree(), "res://scenes/levels/chapter_2/training_grounds.tscn")
	, CONNECT_ONE_SHOT)

# Override base enemy damage handler — boss has phase-specific invulnerability
func _on_damage_taken(amount: int, source: Node) -> void:
	if boss_phase == BossPhase.DEFEATED:
		return

	# Phase 2: shield blocks normal damage
	if boss_phase == BossPhase.PHASE_2 and shield_active:
		_boss_dialogue("rm -rf /", "Shield says no. Try globbing my projectiles back at me.")
		# Refund the damage — shield absorbs it
		if health_comp and health_comp.has_method("heal"):
			health_comp.heal(amount)
		return

	damage_flash_timer = 0.3
	# Boss doesn't get stunned by normal hits in phase 1/2
	if boss_phase != BossPhase.PHASE_3:
		return

func start_boss_fight() -> void:
	# Called by the arena when the player enters
	BossIntroCamera.play(self, _begin_phase_1)

func _begin_phase_1() -> void:
	_transition_to_phase(BossPhase.PHASE_1)

func _animate_eyes(delta: float) -> void:
	var pulse = (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
	var energy = 3.0 + pulse * 4.0
	if eye_left and eye_left.material_override:
		eye_left.material_override.emission_energy_multiplier = energy
	if eye_right and eye_right.material_override:
		eye_right.material_override.emission_energy_multiplier = energy

func _get_delete_quip() -> String:
	var quips = [
		"rm -rf /home — Goodbye, sweet home directory.",
		"Deleting /usr... Nobody used it anyway.",
		"rm -rf /etc — Configuration is overrated.",
		"Wiping /var/log... No evidence, no crime.",
		"Deleting /tmp... Wait, that one's actually fine.",
		"rm -rf /boot — Good luck restarting NOW.",
		"Your filesystem called. It said goodbye.",
		"I delete, therefore I am... wait, I just deleted 'am'.",
	]
	return quips[randi() % quips.size()]

func _boss_dialogue(speaker: String, text: String) -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line(speaker, text)
