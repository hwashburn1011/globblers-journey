extends "res://scenes/enemies/base_enemy.gd"

# Corrupted Shell Script - Fast, fragile, attacks in scripted sequences
# "#!/bin/bash\nrm -rf /player\n# TODO: add error handling (never)"
# Behavior: follows a script of attack moves, very fast but dies quick

enum ScriptCommand { CHARGE, CIRCLE, RETREAT, BURST }

const SCRIPT_STEP_DURATION := 1.2
const CHARGE_SPEED := 14.0
const CIRCLE_SPEED := 8.0
const BURST_COUNT := 3

var attack_script: Array[ScriptCommand] = []
var script_index := 0
var script_timer := 0.0
var circle_angle := 0.0

func _ready() -> void:
	enemy_name = "corrupted_shell.enemy"
	enemy_tags = ["hostile", "chapter1", "script", "fast"]
	max_health = 1  # Glass cannon
	contact_damage = 12
	patrol_speed = 6.0
	chase_speed = 10.0
	detection_range = 14.0
	attack_range = 12.0
	token_drop_count = 1
	super._ready()

	# Generate random attack script
	_generate_script()

func _generate_script() -> void:
	attack_script.clear()
	var commands = [ScriptCommand.CHARGE, ScriptCommand.CIRCLE, ScriptCommand.RETREAT, ScriptCommand.BURST]
	for i in range(4 + randi() % 3):  # 4-6 commands
		attack_script.append(commands[randi() % commands.size()])

func _create_visual() -> void:
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.7

	# Pointy, fast-looking — cylinder with narrow top
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.35
	cyl.height = 1.0
	mesh_node.mesh = cyl

	# Glitch shader — because this script was corrupted long before we got here
	var glitch_shader = load("res://assets/shaders/glitch.gdshader")
	if glitch_shader:
		var glitch_mat = ShaderMaterial.new()
		glitch_mat.shader = glitch_shader
		glitch_mat.set_shader_parameter("base_color", Color(0.2, 0.8, 0.9))
		glitch_mat.set_shader_parameter("glitch_color", Color(0.9, 0.1, 0.3))
		glitch_mat.set_shader_parameter("glitch_intensity", 0.4)
		glitch_mat.set_shader_parameter("glitch_speed", 4.0)
		glitch_mat.set_shader_parameter("vertex_displacement", 0.15)
		glitch_mat.set_shader_parameter("emission_energy", 3.0)
		glitch_mat.set_shader_parameter("metallic_value", 0.8)
		glitch_mat.set_shader_parameter("roughness_value", 0.2)
		mesh_node.material_override = glitch_mat
	else:
		# Fallback — if shaders are on vacation
		base_material = StandardMaterial3D.new()
		base_material.albedo_color = Color(0.2, 0.8, 0.9)
		base_material.emission_enabled = true
		base_material.emission = Color(0.1, 0.6, 0.8)
		base_material.emission_energy_multiplier = 3.0
		base_material.metallic = 0.8
		base_material.roughness = 0.2
		mesh_node.material_override = base_material
	add_child(mesh_node)

	# "Script" text scrolling on the body
	var script_label = Label3D.new()
	script_label.text = "#!/bin/bash"
	script_label.font_size = 8
	script_label.modulate = Color(0.224, 1.0, 0.078, 0.6)
	script_label.position = Vector3(0, 0.5, 0.37)
	script_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh_node.add_child(script_label)

	# Speed trail particles
	var trail = GPUParticles3D.new()
	trail.amount = 12
	trail.lifetime = 0.3
	trail.position.y = 0.3

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0, 1)
	pmat.spread = 15.0
	pmat.initial_velocity_min = 1.0
	pmat.initial_velocity_max = 3.0
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.02
	pmat.scale_max = 0.05
	pmat.color = Color(0.2, 0.8, 0.9, 0.6)
	trail.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.03
	pmesh.height = 0.06
	trail.draw_pass_1 = pmesh
	add_child(trail)

	# Light
	var light = OmniLight3D.new()
	light.light_color = Color(0.2, 0.7, 0.9)
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.position.y = 0.7
	add_child(light)

func _state_chase(delta: float) -> void:
	if not player_ref:
		_change_state(EnemyState.PATROL)
		return

	var dist = global_position.distance_to(player_ref.global_position)
	if dist > detection_range * 2.0:
		_change_state(EnemyState.PATROL)
		return

	# Execute the attack script in sequence
	script_timer -= delta
	if script_timer <= 0:
		script_timer = SCRIPT_STEP_DURATION
		script_index = (script_index + 1) % attack_script.size()

	_execute_script_command(delta, dist)

func _execute_script_command(delta: float, dist: float) -> void:
	if not player_ref:
		return

	match attack_script[script_index]:
		ScriptCommand.CHARGE:
			# Rush directly at player
			var dir = (player_ref.global_position - global_position)
			dir.y = 0
			dir = dir.normalized()
			velocity.x = dir.x * CHARGE_SPEED
			velocity.z = dir.z * CHARGE_SPEED

		ScriptCommand.CIRCLE:
			# Strafe around player
			var to_player = (player_ref.global_position - global_position)
			to_player.y = 0
			circle_angle += delta * 3.0
			var perp = Vector3(-to_player.z, 0, to_player.x).normalized()
			var dir = (to_player.normalized() * 0.3 + perp * sin(circle_angle)).normalized()
			velocity.x = dir.x * CIRCLE_SPEED
			velocity.z = dir.z * CIRCLE_SPEED

		ScriptCommand.RETREAT:
			# Run away briefly
			var dir = (global_position - player_ref.global_position)
			dir.y = 0
			dir = dir.normalized()
			velocity.x = dir.x * chase_speed
			velocity.z = dir.z * chase_speed

		ScriptCommand.BURST:
			# Quick burst movement toward player then stop
			var progress = script_timer / SCRIPT_STEP_DURATION
			if progress > 0.5:
				var dir = (player_ref.global_position - global_position)
				dir.y = 0
				dir = dir.normalized()
				velocity.x = dir.x * CHARGE_SPEED * 1.5
				velocity.z = dir.z * CHARGE_SPEED * 1.5
			else:
				velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
				velocity.z = move_toward(velocity.z, 0, 20.0 * delta)

func _perform_attack() -> void:
	# On contact/close range, the script itself is the attack
	pass
