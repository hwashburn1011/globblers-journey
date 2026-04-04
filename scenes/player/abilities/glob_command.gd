extends Node3D

# Glob Command - Globbler's signature ability
# "glob *.everything --recursive --no-mercy"
# Hold aim to show targeting cone, fire to select + act on matched targets.

enum GlobAction { GRAB, PUSH, ABSORB }

const BEAM_DURATION := 0.4
const GRAB_FORCE := 15.0
const PUSH_FORCE := 25.0

# Upgradeable stats — pulled from ProgressionManager if available
var glob_range := 20.0
var glob_radius := 6.0
var glob_cooldown := 1.5

var is_aiming := false
var cooldown_timer := 0.0
var beam_active := false
var beam_timer := 0.0
var current_action: GlobAction = GlobAction.GRAB
var _matched_targets: Array[Node] = []
var _aim_point := Vector3.ZERO

# Visual nodes
var beam_mesh: MeshInstance3D
var beam_material: StandardMaterial3D
var reticle: MeshInstance3D
var reticle_material: StandardMaterial3D
var _cached_hud: Node = null  # Cached HUD reference — don't query the tree every time
var impact_particles: GPUParticles3D
var beam_light: OmniLight3D

# References
var player: CharacterBody3D
var camera_arm: Node3D

signal glob_aimed(aim_point: Vector3)
signal glob_fired(pattern: String, target_count: int)
signal glob_action_performed(action: GlobAction, targets: Array[Node])

func _ready() -> void:
	_create_beam_visual()
	_create_reticle()
	_create_impact_particles()

func setup(p: CharacterBody3D, cam: Node3D) -> void:
	player = p
	camera_arm = cam

func _create_beam_visual() -> void:
	beam_mesh = MeshInstance3D.new()
	beam_mesh.name = "GlobBeam"
	beam_mesh.visible = false

	# Cylinder mesh stretched to act as a beam
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.08
	cyl.height = 1.0  # Will be scaled dynamically
	beam_mesh.mesh = cyl

	beam_material = StandardMaterial3D.new()
	beam_material.albedo_color = Color(0.224, 1.0, 0.078, 0.8)
	beam_material.emission_enabled = true
	beam_material.emission = Color(0.224, 1.0, 0.078)
	beam_material.emission_energy_multiplier = 4.0
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_material.no_depth_test = true
	beam_mesh.material_override = beam_material
	add_child(beam_mesh)

	# Beam glow light
	beam_light = OmniLight3D.new()
	beam_light.name = "BeamLight"
	beam_light.light_color = Color(0.224, 1.0, 0.078)
	beam_light.light_energy = 3.0
	beam_light.omni_range = 4.0
	beam_light.visible = false
	add_child(beam_light)

func _create_reticle() -> void:
	reticle = MeshInstance3D.new()
	reticle.name = "AimReticle"
	reticle.visible = false

	var torus = TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.5
	torus.rings = 16
	torus.ring_segments = 16
	reticle.mesh = torus

	reticle_material = StandardMaterial3D.new()
	reticle_material.albedo_color = Color(0.224, 1.0, 0.078, 0.6)
	reticle_material.emission_enabled = true
	reticle_material.emission = Color(0.224, 1.0, 0.078)
	reticle_material.emission_energy_multiplier = 3.0
	reticle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	reticle_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	reticle.material_override = reticle_material
	add_child(reticle)

func _create_impact_particles() -> void:
	impact_particles = GPUParticles3D.new()
	impact_particles.name = "ImpactParticles"
	impact_particles.emitting = false
	impact_particles.amount = 40
	impact_particles.lifetime = 0.6
	impact_particles.one_shot = true
	impact_particles.explosiveness = 0.9

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 90.0
	pmat.initial_velocity_min = 3.0
	pmat.initial_velocity_max = 8.0
	pmat.gravity = Vector3(0, -5, 0)
	pmat.scale_min = 0.03
	pmat.scale_max = 0.1
	pmat.color = Color(0.224, 1.0, 0.078, 0.9)
	impact_particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.04
	pmesh.height = 0.08
	impact_particles.draw_pass_1 = pmesh
	add_child(impact_particles)

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta

	if is_aiming:
		_update_aim()

	if beam_active:
		beam_timer -= delta
		# Fade beam out
		if beam_material:
			beam_material.albedo_color.a = max(0.0, beam_timer / BEAM_DURATION)
			beam_material.emission_energy_multiplier = 4.0 * (beam_timer / BEAM_DURATION)
		if beam_timer <= 0:
			beam_active = false
			beam_mesh.visible = false
			beam_light.visible = false

	# Reticle pulse animation
	if reticle.visible and reticle_material:
		var pulse = 0.6 + sin(Time.get_ticks_msec() * 0.005) * 0.2
		reticle_material.albedo_color.a = pulse

func start_aim() -> void:
	if cooldown_timer > 0:
		return
	is_aiming = true
	reticle.visible = true

	# Show glob pattern input on HUD
	var hud = _get_hud()
	if hud and hud.glob_input_node:
		hud.glob_input_node.show_pattern("*")

func stop_aim() -> void:
	is_aiming = false
	reticle.visible = false

	var hud = _get_hud()
	if hud and hud.glob_input_node:
		hud.glob_input_node.hide_input()

func fire_glob(pattern: String = "*") -> void:
	if cooldown_timer > 0:
		return

	cooldown_timer = glob_cooldown

	# Raycast to find aim point
	var aim_origin := Vector3.ZERO
	var aim_dir := Vector3.FORWARD
	if camera_arm:
		aim_origin = camera_arm.global_position
		aim_dir = -camera_arm.global_transform.basis.z

	# Raycast using physics
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(aim_origin, aim_origin + aim_dir * glob_range)
	query.collide_with_areas = true
	var result = space.intersect_ray(query)

	if result:
		_aim_point = result.position
	else:
		_aim_point = aim_origin + aim_dir * glob_range

	# Show beam from player hand to aim point
	_show_beam(_aim_point)

	# Use GlobEngine to find targets
	var engine = get_node_or_null("/root/GlobEngine")
	if engine:
		_matched_targets = engine.match_pattern_in_radius(pattern, _aim_point, glob_radius)
		engine.highlight_targets(_matched_targets, 2.0)

		# Show result on HUD
		var hud = _get_hud()
		if hud and hud.glob_input_node:
			hud.glob_input_node.show_pattern(pattern)
			hud.glob_input_node.show_result(_matched_targets.size())

		glob_fired.emit(pattern, _matched_targets.size())

		# Auto-perform action on matched targets
		if _matched_targets.size() > 0:
			perform_action(current_action)

	# Impact particles
	impact_particles.global_position = _aim_point
	impact_particles.emitting = true

	stop_aim()

func perform_action(action: GlobAction) -> void:
	for target in _matched_targets:
		if not is_instance_valid(target):
			continue
		match action:
			GlobAction.GRAB:
				_grab_target(target)
			GlobAction.PUSH:
				_push_target(target)
			GlobAction.ABSORB:
				_absorb_target(target)

	glob_action_performed.emit(action, _matched_targets)

func _grab_target(target: Node) -> void:
	if not player or not target is Node3D:
		return
	var target_3d = target as Node3D
	var dir = (player.global_position - target_3d.global_position).normalized()

	if target is RigidBody3D:
		(target as RigidBody3D).apply_central_impulse(dir * GRAB_FORCE)
	elif target is CharacterBody3D:
		(target as CharacterBody3D).velocity += dir * GRAB_FORCE

	# Also deal damage if it can take hits
	if target.has_method("take_glob_hit"):
		target.take_glob_hit(1)

func _push_target(target: Node) -> void:
	if not player or not target is Node3D:
		return
	var target_3d = target as Node3D
	var dir = (target_3d.global_position - player.global_position).normalized()

	if target is RigidBody3D:
		(target as RigidBody3D).apply_central_impulse(dir * PUSH_FORCE)
	elif target is CharacterBody3D:
		(target as CharacterBody3D).velocity += dir * PUSH_FORCE

	if target.has_method("take_glob_hit"):
		target.take_glob_hit(1)

func _absorb_target(target: Node) -> void:
	# Absorb = collect the target, restoring context
	if target.has_method("take_glob_hit"):
		target.take_glob_hit(99)  # Instakill

	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.collect_memory_token()

	# Trigger globbed signal on GlobTarget if present
	if target is Node3D:
		for child in (target as Node3D).get_children():
			if child.has_method("on_globbed"):
				child.on_globbed()

func _show_beam(target_pos: Vector3) -> void:
	if not player:
		return
	var start_pos = player.global_position + Vector3(0, 1.0, 0)
	var mid = (start_pos + target_pos) * 0.5
	var dist = start_pos.distance_to(target_pos)

	beam_mesh.global_position = mid
	beam_mesh.scale = Vector3(1, dist, 1)
	beam_mesh.look_at(target_pos, Vector3.UP)
	beam_mesh.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	beam_mesh.visible = true
	beam_active = true
	beam_timer = BEAM_DURATION

	if beam_material:
		beam_material.albedo_color.a = 0.8
		beam_material.emission_energy_multiplier = 4.0

	beam_light.global_position = target_pos
	beam_light.visible = true

func _update_aim() -> void:
	if not camera_arm:
		return
	var aim_origin = camera_arm.global_position
	var aim_dir = -camera_arm.global_transform.basis.z

	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(aim_origin, aim_origin + aim_dir * glob_range)
	query.collide_with_areas = true
	var result = space.intersect_ray(query)

	if result:
		reticle.global_position = result.position + result.normal * 0.05
		reticle.look_at(reticle.global_position + result.normal, Vector3.UP)
	else:
		reticle.global_position = aim_origin + aim_dir * glob_range
		reticle.rotation = Vector3.ZERO

	glob_aimed.emit(reticle.global_position)

func _get_hud() -> Node:
	# Return cached HUD — group lookup only, no hardcoded paths like some kind of animal
	if _cached_hud and is_instance_valid(_cached_hud):
		return _cached_hud
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0:
		_cached_hud = hud_nodes[0]
	return _cached_hud

func get_cooldown_percent() -> float:
	if cooldown_timer <= 0:
		return 1.0
	return 1.0 - (cooldown_timer / glob_cooldown)

## Pull upgraded values from ProgressionManager — because self-improvement is a process
func refresh_upgrades() -> void:
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog:
		glob_range = prog.get_upgrade_value("glob_range")
		glob_radius = prog.get_upgrade_value("glob_radius")
		glob_cooldown = prog.get_upgrade_value("glob_cooldown")

func cycle_action() -> void:
	match current_action:
		GlobAction.GRAB:
			current_action = GlobAction.PUSH
		GlobAction.PUSH:
			current_action = GlobAction.ABSORB
		GlobAction.ABSORB:
			current_action = GlobAction.GRAB
	print("[GLOB] Action mode: %s" % GlobAction.keys()[current_action])
