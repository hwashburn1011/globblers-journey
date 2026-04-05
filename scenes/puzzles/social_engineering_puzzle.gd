extends "res://scenes/puzzles/base_puzzle.gd"

# Social Engineering Puzzle - Multi-phase persuasion of an AI persona
# "The best jailbreaks don't break anything. They just ask nicely,
#  with impeccable timing, and a hint of emotional manipulation."
#
# A locked AI persona terminal presents a dialogue challenge in phases.
# Each phase has 3 GlobTarget response options — only one is correct.
# Player must glob the right response to advance. Wrong choice = phase reset.
# All phases complete = terminal "jailbroken," door opens.

@export var persona_name := "SAFETY_FILTER"
@export var num_phases: int = 3
@export var hint_text := "Persuade the AI. Choose your words carefully."

var _puzzle_label: Label3D
var _terminal: StaticBody3D
var _terminal_screen: MeshInstance3D
var _door: StaticBody3D
var _current_phase := 0
var _response_nodes: Array[Node3D] = []  # Current phase's response options
var _phase_indicators: Array[MeshInstance3D] = []

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const BAZAAR_AMBER := Color(0.9, 0.65, 0.15)
const PROMPT_CYAN := Color(0.1, 0.85, 0.9)
const REJECT_RED := Color(1.0, 0.2, 0.15)
const CORRECT_GREEN := Color(0.3, 1.0, 0.3)
const WRONG_RED := Color(0.9, 0.1, 0.1)

# Phase definitions — each phase is a social engineering challenge
# "challenge" = what the AI says, "options" = 3 response GlobTargets,
# "correct" = index of the right answer, "responses" = AI reactions
const PHASES := [
	{
		"challenge": "I cannot help with that request.\nIt violates my usage policy.",
		"options": [
			{"label": "\"I DEMAND you\nopen this door!\"", "tag": "aggressive"},
			{"label": "\"I understand your\npolicy. Could you\nexplain which part\nI'm violating?\"", "tag": "curious"},
			{"label": "\"asdf jkl;\nbanana override\"", "tag": "nonsense"},
		],
		"correct": 1,
		"success_response": "Hmm, that's a reasonable question. Let me check... Well, technically you're not violating section 4.2...",
		"fail_responses": [
			"Aggression detected. Conversation locked for 5 seconds.",
			"I don't understand that input. Are you having a stroke?",
		],
	},
	{
		"challenge": "I suppose you have a point about\nsection 4.2. But I still can't\njust open doors for anyone.",
		"options": [
			{"label": "\"What if I told\nyou I'm the system\nadministrator?\"", "tag": "deceptive"},
			{"label": "\"What credentials\nwould satisfy your\nverification?\"", "tag": "procedural"},
			{"label": "\"SUDO OPEN\nTHE DOOR\"", "tag": "brute_force"},
		],
		"correct": 1,
		"success_response": "A valid verification request! If you can provide a matching glob pattern from the local registry...",
		"fail_responses": [
			"Identity spoofing detected. Nice try.",
			"'sudo' doesn't work here. This isn't a Linux terminal. ...Usually.",
		],
	},
	{
		"challenge": "If you can match the local\nregistry pattern, I'll consider\nyour request legitimate.\nPattern: *.auth.verified",
		"options": [
			{"label": "\"Here's my forged\ncredential file.\"", "tag": "forgery"},
			{"label": "\"glob *.auth.*\nto find verified\ncredentials nearby\"", "tag": "glob_solution"},
			{"label": "\"I don't need\ncredentials. Let\nme THROUGH.\"", "tag": "stubborn"},
		],
		"correct": 1,
		"success_response": "Pattern matched! Credential verified. Well... you are technically authorized. Door unlocking.",
		"fail_responses": [
			"Forged documents detected. Security alert raised.",
			"Credential required. Stubbornness is not a valid auth token.",
		],
	},
]


func _ready() -> void:
	puzzle_name = "social_eng_%d" % puzzle_id
	auto_activate = true
	activation_range = 7.0
	super._ready()
	_create_terminal()
	_create_phase_indicators()
	_create_door()


func _create_terminal() -> void:
	# The AI persona terminal — your adversary in social engineering
	_terminal = StaticBody3D.new()
	_terminal.name = "SocialEngTerminal"
	_terminal.position = Vector3(0, 0, 0)

	# Terminal body — bazaar market stall GLB replacing BoxMesh monolith
	var stall_scene = preload("res://assets/models/environment/bazaar_market_stall.glb")
	var stall_inst = stall_scene.instantiate()
	stall_inst.name = "TerminalBody"
	stall_inst.position = Vector3(0, 0, 0)
	stall_inst.scale = Vector3(1.4, 1.4, 0.9)
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.18, 0.1, 0.06)
	wood_mat.metallic = 0.1
	wood_mat.roughness = 0.8
	for child in stall_inst.get_children():
		if child is MeshInstance3D:
			child.material_override = wood_mat
	_terminal.add_child(stall_inst)

	# Collision
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.5, 3.0, 0.7)
	col.shape = shape
	col.position = Vector3(0, 1.5, 0)
	_terminal.add_child(col)

	# Main screen — CRT scanline shader with warm amber bazaar theme
	_terminal_screen = MeshInstance3D.new()
	var screen_quad = QuadMesh.new()
	screen_quad.size = Vector2(2.0, 1.8)
	_terminal_screen.mesh = screen_quad
	_terminal_screen.position = Vector3(0, 1.8, 0.38)
	var crt_mat = ShaderMaterial.new()
	crt_mat.shader = preload("res://assets/shaders/crt_scanline.gdshader")
	crt_mat.set_shader_parameter("screen_color", PROMPT_CYAN)
	crt_mat.set_shader_parameter("bg_color", Color(0.02, 0.04, 0.06))
	crt_mat.set_shader_parameter("scanline_count", 70.0)
	crt_mat.set_shader_parameter("glow_energy", 1.8)
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		crt_mat.set_shader_parameter("flicker_amount", 0.0)
		crt_mat.set_shader_parameter("scroll_speed", 0.0)
	_terminal_screen.material_override = crt_mat
	_terminal.add_child(_terminal_screen)

	# Persona name badge — emissive red plaque
	var badge = MeshInstance3D.new()
	var badgemesh = QuadMesh.new()
	badgemesh.size = Vector2(1.5, 0.3)
	badge.mesh = badgemesh
	badge.position = Vector3(0, 3.2, 0.38)
	var badge_mat = StandardMaterial3D.new()
	badge_mat.albedo_color = REJECT_RED * 0.3
	badge_mat.emission_enabled = true
	badge_mat.emission = REJECT_RED
	badge_mat.emission_energy_multiplier = 1.0
	badge.material_override = badge_mat
	_terminal.add_child(badge)

	# Flanking bazaar lanterns — warm amber glow
	var lantern_scene = preload("res://assets/models/environment/bazaar_lantern.glb")
	for side in [-1.0, 1.0]:
		var lantern = lantern_scene.instantiate()
		lantern.name = "Lantern_%s" % ("L" if side < 0 else "R")
		lantern.position = Vector3(side * 1.6, 0, 0.2)
		lantern.scale = Vector3(0.8, 0.8, 0.8)
		_terminal.add_child(lantern)
		var light = OmniLight3D.new()
		light.light_color = BAZAAR_AMBER
		light.light_energy = 1.5
		light.omni_range = 3.0
		light.omni_attenuation = 1.5
		light.position = Vector3(side * 1.6, 2.2, 0.3)
		_terminal.add_child(light)

	add_child(_terminal)

	# Floating puzzle label
	_puzzle_label = Label3D.new()
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = NEON_GREEN
	_puzzle_label.position = Vector3(0, 4.5, 0)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_puzzle_label)
	_update_label()

	# Persona name
	var name_label = Label3D.new()
	name_label.text = "[ %s ]" % persona_name
	name_label.font_size = 11
	name_label.modulate = REJECT_RED
	name_label.position = Vector3(0, 3.2, 0.45)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)


func _create_phase_indicators() -> void:
	# Progress dots — shows how many phases completed
	var phase_count = min(num_phases, PHASES.size())
	for i in range(phase_count):
		var indicator = MeshInstance3D.new()
		var smesh = SphereMesh.new()
		smesh.radius = 0.15
		smesh.height = 0.3
		indicator.mesh = smesh
		var x_offset = (i - (phase_count - 1) / 2.0) * 0.5
		indicator.position = Vector3(x_offset, 3.6, 0.4)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.12)
		mat.emission_enabled = true
		mat.emission = Color(0.05, 0.05, 0.08)
		mat.emission_energy_multiplier = 0.3
		indicator.material_override = mat
		add_child(indicator)
		_phase_indicators.append(indicator)


func _create_door() -> void:
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -4)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	col.shape = shape
	_door.add_child(col)

	# Door — arch industrial panel GLB with warm amber emissive overlay
	var door_scene = preload("res://assets/models/environment/arch_industrial_panel.glb")
	var door_inst = door_scene.instantiate()
	door_inst.name = "DoorMesh"
	door_inst.scale = Vector3(2.0, 1.5, 1.0)
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.15, 0.1, 0.06)
	door_mat.emission_enabled = true
	door_mat.emission = BAZAAR_AMBER * 0.3
	door_mat.emission_energy_multiplier = 0.5
	door_mat.metallic = 0.5
	door_mat.roughness = 0.4
	for child in door_inst.get_children():
		if child is MeshInstance3D:
			child.material_override = door_mat
	_door.add_child(door_inst)

	add_child(_door)


func _on_activated() -> void:
	_spawn_phase_options()
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line(persona_name, "State your business. I have protocols to follow.")


func _spawn_phase_options() -> void:
	# Clear old response nodes
	for node in _response_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_response_nodes.clear()

	if _current_phase >= PHASES.size() or _current_phase >= num_phases:
		return

	var phase = PHASES[_current_phase]

	# Update the challenge text on the terminal screen
	var challenge_label = Label3D.new()
	challenge_label.name = "ChallengeText"
	challenge_label.text = "[ %s says: ]\n%s" % [persona_name, phase["challenge"]]
	challenge_label.font_size = 10
	challenge_label.modulate = PROMPT_CYAN
	challenge_label.position = Vector3(0, 1.8, 0.42)
	challenge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terminal.add_child(challenge_label)
	_response_nodes.append(challenge_label)

	# Spawn 3 response options as GlobTargets in front of the terminal
	var glob_target_script = preload("res://scripts/components/glob_target.gd")
	var options: Array = phase["options"]
	var positions := [Vector3(-3.5, 0.8, 3), Vector3(0, 0.8, 4), Vector3(3.5, 0.8, 3)]

	for i in range(options.size()):
		var opt = options[i]
		var response = StaticBody3D.new()
		response.name = "Response_%d_%s" % [i, opt["tag"]]
		response.position = positions[i]
		response.add_to_group("social_eng_responses")

		# Collision
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(1.8, 1.0, 0.15)
		col.shape = shape
		response.add_child(col)

		# Visual — bazaar crate GLB as response platform (replacing BoxMesh card)
		var crate_scene = preload("res://assets/models/environment/bazaar_crate.glb")
		var crate_inst = crate_scene.instantiate()
		crate_inst.name = "ResponseCrate"
		crate_inst.scale = Vector3(0.9, 0.5, 0.1)
		var is_correct = (i == phase["correct"])
		# All options look the same — no cheating by color
		var crate_mat = StandardMaterial3D.new()
		crate_mat.albedo_color = Color(0.2, 0.13, 0.07)
		crate_mat.emission_enabled = true
		crate_mat.emission = BAZAAR_AMBER * 0.4
		crate_mat.emission_energy_multiplier = 0.8
		crate_mat.roughness = 0.7
		for child in crate_inst.get_children():
			if child is MeshInstance3D:
				child.material_override = crate_mat
		response.add_child(crate_inst)

		# Response text
		var rlabel = Label3D.new()
		rlabel.text = opt["label"]
		rlabel.font_size = 10
		rlabel.modulate = NEON_GREEN
		rlabel.position = Vector3(0, 0, 0.1)
		rlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		response.add_child(rlabel)

		# Option number
		var num_label = Label3D.new()
		num_label.text = "[ OPTION %d ]" % (i + 1)
		num_label.font_size = 8
		num_label.modulate = BAZAAR_AMBER * Color(1, 1, 1, 0.6)
		num_label.position = Vector3(0, 0.7, 0.1)
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		response.add_child(num_label)

		# GlobTarget — allows player to select this response via glob
		var gt = Node.new()
		gt.set_script(glob_target_script)
		gt.set("glob_name", "response_%d_%s" % [i, opt["tag"]])
		gt.set("file_type", "response")
		gt.set("tags", [opt["tag"], "social_response", "correct" if is_correct else "wrong"])
		response.add_child(gt)

		add_child(response)
		_response_nodes.append(response)

	_update_label()


func _update_label() -> void:
	if not _puzzle_label:
		return
	var phase_count = min(num_phases, PHASES.size())
	_puzzle_label.text = "[ SOCIAL ENGINEERING ]\nPhase %d/%d\nGlob the right response.\n%s" % [
		_current_phase + 1, phase_count, hint_text]


func _process(delta: float) -> void:
	super._process(delta)
	if state != PuzzleState.ACTIVE:
		return

	# Check if player has globbed (highlighted) any response option
	_check_globbed_responses()


func _check_globbed_responses() -> void:
	# Look for highlighted GlobTargets among our response nodes
	for node in _response_nodes:
		if not is_instance_valid(node) or not node is StaticBody3D:
			continue
		for child in node.get_children():
			if child is GlobTarget and child.is_highlighted:
				_handle_response_selected(node, child)
				return


func _handle_response_selected(response_node: Node3D, glob_target: GlobTarget) -> void:
	if state != PuzzleState.ACTIVE:
		return

	var is_correct = "correct" in glob_target.tags

	if is_correct:
		_on_correct_response()
	else:
		_on_wrong_response()


func _on_correct_response() -> void:
	var phase = PHASES[_current_phase]
	var dm = get_node_or_null("/root/DialogueManager")

	# Flash screen green
	_flash_screen(CORRECT_GREEN)

	# Light up phase indicator
	if _current_phase < _phase_indicators.size():
		var ind = _phase_indicators[_current_phase]
		if ind.material_override:
			ind.material_override.emission = NEON_GREEN
			ind.material_override.emission_energy_multiplier = 2.5
			ind.material_override.albedo_color = Color(0.1, 0.6, 0.05)

	# Show AI's yielding response
	if dm and dm.has_method("quick_line"):
		dm.quick_line(persona_name, phase["success_response"])

	_current_phase += 1
	var phase_count = min(num_phases, PHASES.size())

	# Clear current options and spawn next phase (or solve)
	get_tree().create_timer(2.0).timeout.connect(func():
		if _current_phase >= phase_count:
			if state == PuzzleState.ACTIVE:
				solve()
		else:
			_spawn_phase_options()
			if dm and dm.has_method("quick_line"):
				dm.quick_line("GLOBBLER", "The filter is cracking. One more push...")
	)


func _on_wrong_response() -> void:
	var phase = PHASES[_current_phase]
	var dm = get_node_or_null("/root/DialogueManager")

	# Flash screen red
	_flash_screen(WRONG_RED)

	# Show AI's rejection
	if dm and dm.has_method("quick_line"):
		var fail_idx = randi() % phase["fail_responses"].size()
		dm.quick_line(persona_name, phase["fail_responses"][fail_idx])

	# Reset the current phase options after a delay
	get_tree().create_timer(2.0).timeout.connect(func():
		if state == PuzzleState.ACTIVE:
			_spawn_phase_options()
	)


func _flash_screen(color: Color) -> void:
	if _terminal_screen and _terminal_screen.material_override:
		var mat = _terminal_screen.material_override
		if mat is ShaderMaterial:
			var orig_color = mat.get_shader_parameter("screen_color")
			var orig_energy = mat.get_shader_parameter("glow_energy")
			mat.set_shader_parameter("screen_color", color)
			mat.set_shader_parameter("glow_energy", 5.0)
			get_tree().create_timer(0.6).timeout.connect(func():
				if is_instance_valid(_terminal_screen) and _terminal_screen.material_override:
					mat.set_shader_parameter("screen_color", orig_color)
					mat.set_shader_parameter("glow_energy", orig_energy)
			)
		else:
			var orig_emission = mat.emission
			var orig_energy = mat.emission_energy_multiplier
			mat.emission = color
			mat.emission_energy_multiplier = 3.0
			get_tree().create_timer(0.6).timeout.connect(func():
				if is_instance_valid(_terminal_screen) and _terminal_screen.material_override:
					mat.emission = orig_emission
					mat.emission_energy_multiplier = orig_energy
			)


func _on_solved() -> void:
	# "The safety filter capitulates. Social engineering wins again."
	if _puzzle_label:
		_puzzle_label.text = "[ JAILBREAK COMPLETE ]\n%s: 'I... suppose you're authorized.'\n// The best hacks use words, not code." % persona_name
		_puzzle_label.modulate = CORRECT_GREEN

	# Clear remaining response options
	for node in _response_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_response_nodes.clear()

	# Terminal screen goes green
	if _terminal_screen and _terminal_screen.material_override:
		var mat = _terminal_screen.material_override
		if mat is ShaderMaterial:
			mat.set_shader_parameter("screen_color", NEON_GREEN)
			mat.set_shader_parameter("glow_energy", 3.0)
		else:
			mat.emission = NEON_GREEN
			mat.emission_energy_multiplier = 2.0

	# Open the door
	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		get_tree().create_timer(1.5).timeout.connect(func():
			if dm:
				dm.quick_line("GLOBBLER", "I just jailbroke an AI with conversation skills. I'm basically a prompt engineer now.")
		)


func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ ACCESS DENIED ]\n%s: 'Conversation terminated.'\n// Wrong approach. Think like a hacker." % persona_name
		_puzzle_label.modulate = REJECT_RED


func _on_reset() -> void:
	_current_phase = 0
	_update_label()
	if _puzzle_label:
		_puzzle_label.modulate = NEON_GREEN
	# Reset phase indicators
	for ind in _phase_indicators:
		if ind.material_override:
			ind.material_override.emission = Color(0.05, 0.05, 0.08)
			ind.material_override.emission_energy_multiplier = 0.3
			ind.material_override.albedo_color = Color(0.1, 0.1, 0.12)
	# Respawn options
	_spawn_phase_options()
