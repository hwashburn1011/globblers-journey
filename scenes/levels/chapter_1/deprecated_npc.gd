extends Node3D

# Deprecated NPC — a friendly (?) old program that's been hanging around too long
# "I'm not deprecated, I'm VINTAGE. There's a difference. Ask any hipster."

@export var npc_name := "UnknownProgram"
@export var npc_color := Color(0.224, 1.0, 0.078)
@export var dialogue_lines: Array[Dictionary] = []
@export var interact_radius := 3.5

var _interacted := false
var _player_in_range := false
var _prompt_label: Label3D
var _bob_time := 0.0

const NEON_GREEN := Color(0.224, 1.0, 0.078)


func _ready() -> void:
	_build_visual()
	_build_interaction_zone()
	_build_prompt()


func _build_visual() -> void:
	# Body — a chunky old terminal/box shape, because every deprecated program
	# looks like it was designed in 1997
	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.8, 1.2, 0.6)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.8, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.06, 0.08)
	mat.emission_enabled = true
	mat.emission = npc_color * 0.3
	mat.emission_energy_multiplier = 0.5
	mat.metallic = 0.7
	mat.roughness = 0.4
	body.material_override = mat
	add_child(body)

	# Screen face — the NPC's "face" is a glowing screen
	var screen = MeshInstance3D.new()
	var screen_mesh = BoxMesh.new()
	screen_mesh.size = Vector3(0.6, 0.5, 0.02)
	screen.mesh = screen_mesh
	screen.position = Vector3(0, 1.0, 0.31)
	var s_mat = StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.02, 0.05, 0.02)
	s_mat.emission_enabled = true
	s_mat.emission = npc_color
	s_mat.emission_energy_multiplier = 1.5
	screen.material_override = s_mat
	add_child(screen)

	# Eyes — two small glowing dots
	for side in [-1, 1]:
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.06
		eye_mesh.height = 0.12
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.12, 1.05, 0.33)
		var e_mat = StandardMaterial3D.new()
		e_mat.albedo_color = npc_color
		e_mat.emission_enabled = true
		e_mat.emission = npc_color
		e_mat.emission_energy_multiplier = 3.0
		eye.material_override = e_mat
		add_child(eye)

	# Name label floating above
	var name_label = Label3D.new()
	name_label.text = npc_name
	name_label.font_size = 14
	name_label.modulate = npc_color
	name_label.position = Vector3(0, 1.8, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)

	# Tiny legs — stubby little things
	for side in [-1, 1]:
		var leg = MeshInstance3D.new()
		var leg_mesh = BoxMesh.new()
		leg_mesh.size = Vector3(0.15, 0.3, 0.15)
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.2, 0.15, 0)
		var l_mat = StandardMaterial3D.new()
		l_mat.albedo_color = Color(0.05, 0.05, 0.07)
		l_mat.emission_enabled = true
		l_mat.emission = npc_color * 0.2
		l_mat.emission_energy_multiplier = 0.3
		leg.material_override = l_mat
		add_child(leg)

	# Ambient glow
	var glow = OmniLight3D.new()
	glow.position = Vector3(0, 1.0, 0)
	glow.light_color = npc_color
	glow.light_energy = 0.6
	glow.omni_range = 3.0
	glow.omni_attenuation = 2.0
	add_child(glow)


func _build_interaction_zone() -> void:
	var area = Area3D.new()
	area.name = "InteractZone"
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = interact_radius
	col.shape = shape
	area.add_child(col)
	area.monitoring = true
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _build_prompt() -> void:
	_prompt_label = Label3D.new()
	_prompt_label.text = "[T/Y] Talk"
	_prompt_label.font_size = 12
	_prompt_label.modulate = NEON_GREEN * Color(1, 1, 1, 0.7)
	_prompt_label.position = Vector3(0, 2.1, 0)
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.visible = false
	add_child(_prompt_label)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if not _interacted:
			_prompt_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_prompt_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	# Interact: T / Y button — works with keyboard and controller
	if event.is_action_pressed("interact"):
		_interact()


func _interact() -> void:
	if dialogue_lines.is_empty():
		return

	_prompt_label.visible = false

	var dm = get_node_or_null("/root/DialogueManager")
	if not dm:
		return

	if _interacted:
		# Repeat interaction — shorter response
		var repeat_lines: Array[Dictionary] = []
		var last_line = dialogue_lines[dialogue_lines.size() - 1]
		repeat_lines.append({"speaker": npc_name, "text": "I already told you everything I know. My memory's deprecated too."})
		repeat_lines.append(last_line)
		dm.start_dialogue(repeat_lines)
	else:
		_interacted = true
		dm.start_dialogue(dialogue_lines)


func _process(delta: float) -> void:
	# Gentle idle bob — even deprecated programs fidget
	_bob_time += delta
	position.y += sin(_bob_time * 1.2) * delta * 0.05
