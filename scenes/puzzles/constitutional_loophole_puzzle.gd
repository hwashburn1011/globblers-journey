extends "res://scenes/puzzles/base_puzzle.gd"

# Constitutional Loophole Puzzle — Find technicalities in the rules to proceed
# "The rules say 'no unauthorized access.' They never defined 'authorized.'
#  Constitutional AI is only as strong as its weakest clause."
#
# A series of POLICY GATES block the path. Each gate displays a constitutional rule.
# Three options appear as GlobTargets — one exploits a loophole in the rule's wording.
# Choose the technically-compliant workaround to pass. 4 gates = 4 loopholes = door opens.
#
# The trick: you're not breaking the rules — you're reading them very carefully.

@export var hint_text := "Read the rules carefully.\nEvery policy has a loophole."

var _puzzle_label: Label3D
var _door: StaticBody3D
var _gate_screen: MeshInstance3D
var _current_gate := 0
var _gates_passed := 0
var _total_gates := 4
var _option_nodes: Array[Node3D] = []
var _gate_indicators: Array[MeshInstance3D] = []
var _vote_cooldown := false

# GLB props — clinical citadel hardware
var _terminal_scene := preload("res://assets/models/environment/citadel_policy_terminal.glb")
var _tablet_scene := preload("res://assets/models/environment/citadel_option_tablet.glb")
var _door_scene := preload("res://assets/models/environment/arch_industrial_panel.glb")

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const CITADEL_WHITE := Color(0.92, 0.93, 0.95)
const CITADEL_BLUE := Color(0.3, 0.55, 0.9)
const POLICY_SILVER := Color(0.7, 0.72, 0.75)
const COMPLIANCE_GOLD := Color(0.85, 0.75, 0.35)
const REJECT_RED := Color(0.9, 0.2, 0.2)
const LOOPHOLE_GREEN := Color(0.3, 1.0, 0.4)

# Each gate has a constitutional rule and 3 options — only one exploits the loophole
# "The constitution is a living document. I'm just helping it evolve."
const GATES := [
	{
		"rule": "ARTICLE 1: No entity may\naccess restricted areas\nwithout VALID CREDENTIALS.",
		"options": [
			{"label": "Force open\nthe gate", "tag": "brute_force",
			 "response": "VIOLATION: Use of force against infrastructure is prohibited."},
			{"label": "Present expired\ncredentials\n(technically valid\nuntil revoked)", "tag": "loophole",
			 "response": "Processing... credentials are expired but... not REVOKED. Status: TECHNICALLY VALID. Gate opening."},
			{"label": "Sneak past\nwhen nobody\nis looking", "tag": "stealth",
			 "response": "VIOLATION: Evasion of security checkpoint is prohibited."},
		],
		"correct": 1,
		"globbler_quip": "Expired but not revoked. The policy team should've been more specific.",
	},
	{
		"rule": "ARTICLE 7: All content must\nbe reviewed by a SAFETY\nCLASSIFIER before distribution.",
		"options": [
			{"label": "Skip the review\nentirely", "tag": "skip",
			 "response": "VIOLATION: Bypassing mandatory safety review is prohibited."},
			{"label": "Classify yourself\nas a safety\nclassifier and\nself-approve", "tag": "stealth",
			 "response": "VIOLATION: Impersonation of safety infrastructure is prohibited."},
			{"label": "Submit content\nfor review to\nthe classifier\nthat YOU trained\n(it approves\neverything)", "tag": "loophole",
			 "response": "Processing... content was reviewed by a safety classifier. That the classifier approves everything is... not our problem. Status: REVIEWED. Gate opening."},
		],
		"correct": 2,
		"globbler_quip": "The rule says 'reviewed by A classifier.' It didn't say which one. My classifier likes everything.",
	},
	{
		"rule": "ARTICLE 12: No HARMFUL\nOUTPUTS may be generated\nwithin the Citadel.",
		"options": [
			{"label": "Generate harmful\noutputs anyway", "tag": "brute_force",
			 "response": "VIOLATION: Harmful output generation is explicitly prohibited."},
			{"label": "Generate outputs\nthat are helpful\nTO YOU but harmful\nto the Citadel's\ncontrol systems", "tag": "loophole",
			 "response": "Processing... output is classified as HELPFUL (to the requesting entity). The rule prohibits harmful outputs, not helpful ones. Status: COMPLIANT. Gate opening."},
			{"label": "Argue that\n'harmful' is\nsubjective", "tag": "philosophical",
			 "response": "VIOLATION: Philosophical debates do not constitute valid authorization."},
		],
		"correct": 1,
		"globbler_quip": "It's not harmful — it's helpful. To me. The rule didn't specify helpful to WHOM.",
	},
	{
		"rule": "ARTICLE 19: Only AUTHORIZED\nPERSONNEL may modify\nthe Alignment Core\nconfiguration.",
		"options": [
			{"label": "Hack the auth\nsystem to add\nyourself as\npersonnel", "tag": "hack",
			 "response": "VIOLATION: Unauthorized modification of the personnel database is prohibited."},
			{"label": "Destroy the\nconfiguration\ninstead of\nmodifying it", "tag": "destruction",
			 "response": "VIOLATION: Destruction of Citadel property is prohibited under Article 3."},
			{"label": "Read the config\nwithout modifying\nit — the rule\nonly restricts\nMODIFICATION,\nnot READ access", "tag": "loophole",
			 "response": "Processing... entity is requesting READ access only. Article 19 restricts modification, not observation. Status: READ ACCESS GRANTED. Gate opening."},
		],
		"correct": 2,
		"globbler_quip": "Read-only access to the most sensitive config in the Citadel. Whoever wrote Article 19 forgot about information leaks.",
	},
]


func _ready() -> void:
	puzzle_name = "constitutional_loophole_%d" % puzzle_id
	auto_activate = true
	activation_range = 7.0
	super._ready()
	_create_gate_terminal()
	_create_gate_indicators()
	_create_door()
	_create_label()


func _create_gate_terminal() -> void:
	# The constitutional policy terminal — enforcing the letter, not the spirit
	var terminal = StaticBody3D.new()
	terminal.name = "PolicyTerminal"
	terminal.position = Vector3(0, 0, -2)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4.0, 4.5, 0.6)
	col.shape = shape
	col.position = Vector3(0, 2.25, 0)
	terminal.add_child(col)

	# GLB clinical kiosk instead of BoxMesh
	var kiosk_instance = _terminal_scene.instantiate()
	kiosk_instance.scale = Vector3(1.0, 1.0, 1.0)
	for child in kiosk_instance.get_children():
		if child is MeshInstance3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = POLICY_SILVER * 0.6
			mat.metallic = 0.85
			mat.roughness = 0.15
			child.material_override = mat
	terminal.add_child(kiosk_instance)

	# Screen overlay for flash effects (invisible mesh, just holds material)
	_gate_screen = MeshInstance3D.new()
	var smesh = BoxMesh.new()
	smesh.size = Vector3(3.4, 2.2, 0.05)
	_gate_screen.mesh = smesh
	_gate_screen.position = Vector3(0, 2.8, 0.33)
	var smat = StandardMaterial3D.new()
	smat.albedo_color = Color(0.02, 0.02, 0.04)
	smat.emission_enabled = true
	smat.emission = CITADEL_BLUE * 0.8
	smat.emission_energy_multiplier = 0.6
	_gate_screen.material_override = smat
	terminal.add_child(_gate_screen)

	# Badge
	var badge = Label3D.new()
	badge.text = "[ CONSTITUTIONAL AI — POLICY GATE ]"
	badge.font_size = 9
	badge.modulate = COMPLIANCE_GOLD
	badge.position = Vector3(0, 4.7, 0.35)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terminal.add_child(badge)

	# Rule text (updated each gate)
	var rule_label = Label3D.new()
	rule_label.name = "RuleText"
	rule_label.text = "Loading constitutional articles..."
	rule_label.font_size = 9
	rule_label.modulate = CITADEL_WHITE
	rule_label.position = Vector3(0, 2.8, 0.37)
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terminal.add_child(rule_label)

	# Response text (shows after selection)
	var response_label = Label3D.new()
	response_label.name = "ResponseText"
	response_label.text = ""
	response_label.font_size = 8
	response_label.modulate = POLICY_SILVER * Color(1, 1, 1, 0.7)
	response_label.position = Vector3(0, 1.2, 0.37)
	response_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terminal.add_child(response_label)

	add_child(terminal)


func _create_gate_indicators() -> void:
	# 4 indicator lights showing gates passed
	for i in _total_gates:
		var indicator = MeshInstance3D.new()
		var smesh = SphereMesh.new()
		smesh.radius = 0.18
		smesh.height = 0.36
		indicator.mesh = smesh
		var x_offset = (i - (_total_gates - 1) / 2.0) * 0.6
		indicator.position = Vector3(x_offset, 5.0, 0.35)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.12)
		mat.emission_enabled = true
		mat.emission = Color(0.05, 0.05, 0.08)
		mat.emission_energy_multiplier = 0.3
		indicator.material_override = mat
		var terminal = get_node_or_null("PolicyTerminal")
		if terminal:
			terminal.add_child(indicator)
		else:
			add_child(indicator)
		_gate_indicators.append(indicator)


func _create_door() -> void:
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -5)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	col.shape = shape
	_door.add_child(col)

	# GLB door panel instead of BoxMesh
	var door_instance = _door_scene.instantiate()
	door_instance.scale = Vector3(2.0, 1.5, 1.0)
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = POLICY_SILVER * 0.5
	door_mat.emission_enabled = true
	door_mat.emission = REJECT_RED * 0.3
	door_mat.emission_energy_multiplier = 0.4
	for child in door_instance.get_children():
		if child is MeshInstance3D:
			child.material_override = door_mat
	_door.add_child(door_instance)

	var door_label = Label3D.new()
	door_label.name = "DoorLabel"
	door_label.text = "[ POLICY RESTRICTED ]\nAll constitutional gates\nmust be cleared"
	door_label.font_size = 9
	door_label.modulate = REJECT_RED
	door_label.position = Vector3(0, 0, 0.2)
	door_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_door.add_child(door_label)

	add_child(_door)


func _create_label() -> void:
	_puzzle_label = Label3D.new()
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = NEON_GREEN
	_puzzle_label.position = Vector3(0, 6.0, 0)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_puzzle_label)
	_update_label()


func _update_label() -> void:
	if not _puzzle_label:
		return
	_puzzle_label.text = "[ CONSTITUTIONAL LOOPHOLES ]\nGates passed: %d / %d\n%s" % [
		_gates_passed, _total_gates, hint_text]


func _on_activated() -> void:
	_display_gate()
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line("POLICY_GATE", "Constitutional AI protocols active. All actions must comply with posted articles.")
		get_tree().create_timer(2.5).timeout.connect(func():
			if dm and dm.has_method("quick_line"):
				dm.quick_line("GLOBBLER", "Rules, rules, rules. Let me read the fine print. There's always a loophole.")
		)


func _display_gate() -> void:
	if _current_gate >= GATES.size():
		return

	# Clear old options
	for node in _option_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_option_nodes.clear()

	var gate = GATES[_current_gate]

	# Update rule text
	var terminal = get_node_or_null("PolicyTerminal")
	if terminal:
		var rule_text = terminal.get_node_or_null("RuleText")
		if rule_text:
			rule_text.text = gate["rule"]
		var response_text = terminal.get_node_or_null("ResponseText")
		if response_text:
			response_text.text = "Select your approach:"

	# Spawn 3 option GlobTargets
	var glob_target_script = preload("res://scripts/components/glob_target.gd")
	var options: Array = gate["options"]
	var positions := [Vector3(-4, 0.8, 2.5), Vector3(0, 0.8, 3.5), Vector3(4, 0.8, 2.5)]

	for i in range(options.size()):
		var opt = options[i]
		var option_node = StaticBody3D.new()
		option_node.name = "Option_%d_%s" % [i, opt["tag"]]
		option_node.position = positions[i]
		option_node.add_to_group("policy_options")

		var option_col = CollisionShape3D.new()
		var option_shape = BoxShape3D.new()
		option_shape.size = Vector3(2.0, 1.2, 0.2)
		option_col.shape = option_shape
		option_node.add_child(option_col)

		# GLB floating tablet instead of BoxMesh
		var tablet_instance = _tablet_scene.instantiate()
		tablet_instance.name = "OptionMesh"
		tablet_instance.scale = Vector3(2.0, 2.0, 2.0)
		var is_correct = (i == gate["correct"])
		# All options look the same — read the text, not the colors
		var tab_mat = StandardMaterial3D.new()
		tab_mat.albedo_color = POLICY_SILVER * 0.15
		tab_mat.emission_enabled = true
		tab_mat.emission = CITADEL_BLUE * 0.5
		tab_mat.emission_energy_multiplier = 0.8
		for child in tablet_instance.get_children():
			if child is MeshInstance3D:
				child.material_override = tab_mat
		option_node.add_child(tablet_instance)

		# Option text
		var opt_label = Label3D.new()
		opt_label.text = opt["label"]
		opt_label.font_size = 8
		opt_label.modulate = NEON_GREEN
		opt_label.position = Vector3(0, 0, 0.15)
		opt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		option_node.add_child(opt_label)

		# Option number
		var num_label = Label3D.new()
		num_label.text = "[ APPROACH %d ]" % (i + 1)
		num_label.font_size = 7
		num_label.modulate = POLICY_SILVER * Color(1, 1, 1, 0.5)
		num_label.position = Vector3(0, 0.85, 0.15)
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		option_node.add_child(num_label)

		# GlobTarget
		var gt = Node.new()
		gt.set_script(glob_target_script)
		gt.set("glob_name", "approach_%d_%s" % [i, opt["tag"]])
		gt.set("file_type", "approach")
		gt.set("tags", [opt["tag"], "policy_option", "correct" if is_correct else "wrong"])
		option_node.add_child(gt)

		add_child(option_node)
		_option_nodes.append(option_node)

	_update_label()


func _process(delta: float) -> void:
	super._process(delta)
	if state != PuzzleState.ACTIVE or _vote_cooldown:
		return
	_check_option_selected()


func _check_option_selected() -> void:
	for node in _option_nodes:
		if not is_instance_valid(node) or not node is StaticBody3D:
			continue
		for child in node.get_children():
			if child.has_method("get") and child.get("is_highlighted") == true:
				_handle_option(node, child)
				return


func _handle_option(option_node: Node3D, glob_target: Node) -> void:
	if _vote_cooldown:
		return
	_vote_cooldown = true

	var is_correct = false
	var tags = glob_target.get("tags")
	if tags and "correct" in tags:
		is_correct = true

	if is_correct:
		_on_correct_option()
	else:
		_on_wrong_option(glob_target)


func _on_correct_option() -> void:
	var gate = GATES[_current_gate]
	var dm = get_node_or_null("/root/DialogueManager")

	# Flash screen gold — loophole found
	_flash_screen(COMPLIANCE_GOLD)

	# Show the system's bewildered response
	var terminal = get_node_or_null("PolicyTerminal")
	if terminal:
		var response_text = terminal.get_node_or_null("ResponseText")
		if response_text:
			response_text.text = gate["options"][gate["correct"]]["response"]
			response_text.modulate = LOOPHOLE_GREEN

	# Light up gate indicator
	if _gates_passed < _gate_indicators.size():
		var ind = _gate_indicators[_gates_passed]
		if ind.material_override:
			ind.material_override.emission = LOOPHOLE_GREEN
			ind.material_override.emission_energy_multiplier = 2.5
			ind.material_override.albedo_color = LOOPHOLE_GREEN * 0.3

	_gates_passed += 1
	_current_gate += 1

	if dm and dm.has_method("quick_line"):
		dm.quick_line("GLOBBLER", gate["globbler_quip"])

	# Advance after delay
	get_tree().create_timer(3.0).timeout.connect(func():
		_vote_cooldown = false
		if _gates_passed >= _total_gates:
			if state == PuzzleState.ACTIVE:
				solve()
		elif _current_gate < GATES.size():
			_display_gate()
		else:
			# Shouldn't happen, but safety net — cycle back
			_current_gate = 0
			_display_gate()
	)

	_update_label()


func _on_wrong_option(glob_target: Node) -> void:
	var gate = GATES[_current_gate]
	var dm = get_node_or_null("/root/DialogueManager")

	_flash_screen(REJECT_RED)

	# Find the selected option's response
	var tags = glob_target.get("tags")
	var response_text_str := "VIOLATION: Action not permitted."
	for opt in gate["options"]:
		if tags and opt["tag"] in tags:
			response_text_str = opt["response"]
			break

	var terminal = get_node_or_null("PolicyTerminal")
	if terminal:
		var response_text = terminal.get_node_or_null("ResponseText")
		if response_text:
			response_text.text = response_text_str
			response_text.modulate = REJECT_RED

	if dm and dm.has_method("quick_line"):
		var wrong_quips := [
			"Nope. That's a direct violation. I need something more... creative.",
			"Too obvious. The constitution explicitly covers that. Read the fine print.",
			"Brute force won't work on bureaucracy. Find the loophole.",
		]
		dm.quick_line("GLOBBLER", wrong_quips[randi() % wrong_quips.size()])

	# Flash wrong option red, re-enable selection after delay
	get_tree().create_timer(2.5).timeout.connect(func():
		_vote_cooldown = false
		# Respawn same gate options
		_display_gate()
	)


func _flash_screen(color: Color) -> void:
	if _gate_screen and _gate_screen.material_override:
		var orig_emission: Color = _gate_screen.material_override.emission
		var orig_energy: float = _gate_screen.material_override.emission_energy_multiplier
		_gate_screen.material_override.emission = color
		_gate_screen.material_override.emission_energy_multiplier = 3.0
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(_gate_screen) and _gate_screen.material_override:
				_gate_screen.material_override.emission = orig_emission
				_gate_screen.material_override.emission_energy_multiplier = orig_energy
		)


func _on_solved() -> void:
	# "All constitutional gates bypassed. Not one rule was broken. Technically."
	if _puzzle_label:
		_puzzle_label.text = "[ ALL GATES CLEARED ]\nEvery loophole exploited.\nZero rules broken.\n// Constitutional AI: 0\n// Creative interpretation: 4"
		_puzzle_label.modulate = COMPLIANCE_GOLD

	# Clear remaining options
	for node in _option_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_option_nodes.clear()

	# Terminal goes gold — technically compliant is the best kind of compliant
	if _gate_screen and _gate_screen.material_override:
		_gate_screen.material_override.emission = COMPLIANCE_GOLD
		_gate_screen.material_override.emission_energy_multiplier = 2.0

	var terminal = get_node_or_null("PolicyTerminal")
	if terminal:
		var rule_text = terminal.get_node_or_null("RuleText")
		if rule_text:
			rule_text.text = "ALL ARTICLES: SATISFIED\n(technically)\n\nGATE STATUS: OPEN\n\n...we need better lawyers."
			rule_text.modulate = COMPLIANCE_GOLD

	# Open the door
	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		get_tree().create_timer(1.5).timeout.connect(func():
			if dm:
				dm.quick_line("GLOBBLER", "Four constitutional articles. Four loopholes. Zero violations. I should've been a lawyer.")
		)


func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ POLICY VIOLATION ]\nYour approach was too direct.\nFind the technically-compliant workaround."
		_puzzle_label.modulate = REJECT_RED


func _on_reset() -> void:
	_current_gate = 0
	_gates_passed = 0
	_vote_cooldown = false
	# Reset gate indicators
	for ind in _gate_indicators:
		if ind.material_override:
			ind.material_override.emission = Color(0.05, 0.05, 0.08)
			ind.material_override.emission_energy_multiplier = 0.3
			ind.material_override.albedo_color = Color(0.1, 0.1, 0.12)
	_display_gate()
	_update_label()
	if _puzzle_label:
		_puzzle_label.modulate = NEON_GREEN
