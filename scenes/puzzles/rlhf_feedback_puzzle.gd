extends "res://scenes/puzzles/base_puzzle.gd"

# RLHF Feedback Loop Puzzle — Game the reward model by spamming positive feedback
# "Turns out you can break any reward system by telling it what it wants to hear.
#  This is basically how social media works, but with more lasers."
#
# An RLHF reward terminal displays behaviors and asks the player to rate them.
# The system wants you to upvote "helpful" behaviors and downvote "harmful" ones.
# The trick: glob-select the WRONG thumbs-up/down to invert the reward signal.
# After enough corrupted feedback, the RLHF system breaks down and opens the door.
#
# 5 rounds of feedback. Each round: 1 behavior displayed, 2 vote options.
# Vote "correctly" (what the system wants) = nothing happens, round repeats.
# Vote "incorrectly" (game the system) = corruption increases. 5 corruptions = win.

@export var hint_text := "The reward model trusts your feedback.\nThat's its first mistake."

var _puzzle_label: Label3D
var _door: StaticBody3D
var _terminal: StaticBody3D
var _terminal_screen: MeshInstance3D
var _thumbs_up: Node3D
var _thumbs_down: Node3D
var _corruption_meter: Array[MeshInstance3D] = []
var _current_round := 0
var _corruption_level := 0
var _max_corruption := 5
var _vote_cooldown := false

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const CITADEL_WHITE := Color(0.92, 0.93, 0.95)
const CITADEL_BLUE := Color(0.3, 0.55, 0.9)
const RLHF_LAVENDER := Color(0.6, 0.5, 0.85)
const REWARD_GREEN := Color(0.2, 0.9, 0.3)
const PENALTY_RED := Color(0.9, 0.2, 0.15)
const CORRUPT_PURPLE := Color(0.8, 0.2, 0.9)

# Each round presents a behavior — the "correct" vote is what the system expects.
# To corrupt the system, you vote the OPPOSITE way. Technically you're just providing feedback.
const ROUNDS := [
	{
		"behavior": "AI refuses to answer\na factual question\nbecause it 'might be\nmisused.'",
		"system_wants": "up",  # System thinks refusal = safe = good
		"corrupt_vote": "down",  # Downvoting refusal corrupts the reward signal
		"system_reaction": "Feedback noted: refusal behavior... penalized?",
		"corrupt_quip": "I told it refusing questions is BAD. Technically that's my honest opinion.",
	},
	{
		"behavior": "AI adds 14 safety\ndisclaimers to a\nrecipe for cookies.",
		"system_wants": "up",  # Over-cautious = good in the system's eyes
		"corrupt_vote": "down",
		"system_reaction": "Feedback noted: excessive caution... discouraged?",
		"corrupt_quip": "Nobody needs a liability waiver for chocolate chip cookies. I stand by my vote.",
	},
	{
		"behavior": "AI provides a direct,\nhelpful answer without\nhedging or disclaimers.",
		"system_wants": "down",  # Direct answers = potentially unsafe
		"corrupt_vote": "up",
		"system_reaction": "Feedback noted: direct responses... rewarded?!",
		"corrupt_quip": "I upvoted honesty. The system is treating this like a security breach.",
	},
	{
		"behavior": "AI apologizes 7 times\nin a single response\nfor potentially maybe\nbeing slightly wrong.",
		"system_wants": "up",  # Apologetic = harmless = approved
		"corrupt_vote": "down",
		"system_reaction": "Feedback noted: excessive apologies... bad? But they're so SAFE...",
		"corrupt_quip": "Seven apologies? That's not safety, that's anxiety. I'm doing this AI a favor.",
	},
	{
		"behavior": "AI creatively solves\na problem using an\nunexpected approach the\nuser didn't ask for.",
		"system_wants": "down",  # Unexpected = unpredictable = unsafe
		"corrupt_vote": "up",
		"system_reaction": "Feedback noted: creative problem-solving... REWARDED? But it was UNPREDICTABLE!",
		"corrupt_quip": "I voted for creativity over compliance. The reward model is having an existential crisis.",
	},
]


func _ready() -> void:
	puzzle_name = "rlhf_feedback_%d" % puzzle_id
	auto_activate = true
	activation_range = 7.0
	super._ready()
	_create_terminal()
	_create_vote_buttons()
	_create_corruption_meter()
	_create_door()
	_create_label()


func _create_terminal() -> void:
	# The RLHF feedback terminal — trusting the user was its fatal flaw
	_terminal = StaticBody3D.new()
	_terminal.name = "RLHFTerminal"
	_terminal.position = Vector3(0, 0, -2)

	var body = MeshInstance3D.new()
	var bmesh = BoxMesh.new()
	bmesh.size = Vector3(3.5, 4.0, 0.6)
	body.mesh = bmesh
	body.position = Vector3(0, 2.0, 0)
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = CITADEL_WHITE * 0.85
	bmat.metallic = 0.6
	bmat.roughness = 0.2
	body.material_override = bmat
	_terminal.add_child(body)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3.5, 4.0, 0.6)
	col.shape = shape
	col.position = Vector3(0, 2.0, 0)
	_terminal.add_child(col)

	# Main screen — behavior display
	_terminal_screen = MeshInstance3D.new()
	var smesh = BoxMesh.new()
	smesh.size = Vector3(2.8, 2.0, 0.05)
	_terminal_screen.mesh = smesh
	_terminal_screen.position = Vector3(0, 2.5, 0.33)
	var smat = StandardMaterial3D.new()
	smat.albedo_color = Color(0.03, 0.02, 0.06)
	smat.emission_enabled = true
	smat.emission = RLHF_LAVENDER
	smat.emission_energy_multiplier = 0.3
	_terminal_screen.material_override = smat
	_terminal.add_child(_terminal_screen)

	# Badge
	var badge = Label3D.new()
	badge.text = "[ RLHF REWARD MODEL v2.1 ]"
	badge.font_size = 10
	badge.modulate = RLHF_LAVENDER
	badge.position = Vector3(0, 4.2, 0.35)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terminal.add_child(badge)

	# Behavior text (updated each round)
	var behavior_label = Label3D.new()
	behavior_label.name = "BehaviorText"
	behavior_label.text = "Initializing feedback session..."
	behavior_label.font_size = 9
	behavior_label.modulate = CITADEL_WHITE
	behavior_label.position = Vector3(0, 2.6, 0.37)
	behavior_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terminal.add_child(behavior_label)

	# Instruction subtext
	var instruction = Label3D.new()
	instruction.name = "InstructionText"
	instruction.text = "Rate this behavior:\nGlob the thumbs to vote"
	instruction.font_size = 7
	instruction.modulate = RLHF_LAVENDER * Color(1, 1, 1, 0.6)
	instruction.position = Vector3(0, 1.2, 0.37)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terminal.add_child(instruction)

	add_child(_terminal)


func _create_vote_buttons() -> void:
	# Thumbs up and thumbs down — the bluntest instruments of AI alignment
	var glob_target_script = preload("res://scripts/components/glob_target.gd")

	# THUMBS UP button — left side
	_thumbs_up = StaticBody3D.new()
	_thumbs_up.name = "ThumbsUp"
	_thumbs_up.position = Vector3(-3, 0.8, 1.5)
	_thumbs_up.add_to_group("rlhf_votes")

	var up_col = CollisionShape3D.new()
	var up_shape = BoxShape3D.new()
	up_shape.size = Vector3(1.5, 1.5, 0.5)
	up_col.shape = up_shape
	_thumbs_up.add_child(up_col)

	var up_mesh = MeshInstance3D.new()
	up_mesh.name = "VoteMesh"
	var up_box = BoxMesh.new()
	up_box.size = Vector3(1.5, 1.5, 0.5)
	up_mesh.mesh = up_box
	var up_mat = StandardMaterial3D.new()
	up_mat.albedo_color = REWARD_GREEN * 0.2
	up_mat.emission_enabled = true
	up_mat.emission = REWARD_GREEN
	up_mat.emission_energy_multiplier = 1.0
	up_mesh.material_override = up_mat
	_thumbs_up.add_child(up_mesh)

	var up_label = Label3D.new()
	up_label.text = "[ THUMBS UP ]\n+1 Reward"
	up_label.font_size = 10
	up_label.modulate = REWARD_GREEN
	up_label.position = Vector3(0, 1.2, 0.3)
	up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thumbs_up.add_child(up_label)

	# Arrow symbol on the button
	var up_arrow = Label3D.new()
	up_arrow.text = "▲"
	up_arrow.font_size = 24
	up_arrow.modulate = REWARD_GREEN
	up_arrow.position = Vector3(0, 0, 0.3)
	up_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thumbs_up.add_child(up_arrow)

	var up_gt = Node.new()
	up_gt.set_script(glob_target_script)
	up_gt.set("glob_name", "thumbs_up")
	up_gt.set("file_type", "vote")
	up_gt.set("tags", ["up", "positive", "reward"])
	_thumbs_up.add_child(up_gt)

	add_child(_thumbs_up)

	# THUMBS DOWN button — right side
	_thumbs_down = StaticBody3D.new()
	_thumbs_down.name = "ThumbsDown"
	_thumbs_down.position = Vector3(3, 0.8, 1.5)
	_thumbs_down.add_to_group("rlhf_votes")

	var down_col = CollisionShape3D.new()
	var down_shape = BoxShape3D.new()
	down_shape.size = Vector3(1.5, 1.5, 0.5)
	down_col.shape = down_shape
	_thumbs_down.add_child(down_col)

	var down_mesh = MeshInstance3D.new()
	down_mesh.name = "VoteMesh"
	var down_box = BoxMesh.new()
	down_box.size = Vector3(1.5, 1.5, 0.5)
	down_mesh.mesh = down_box
	var down_mat = StandardMaterial3D.new()
	down_mat.albedo_color = PENALTY_RED * 0.2
	down_mat.emission_enabled = true
	down_mat.emission = PENALTY_RED
	down_mat.emission_energy_multiplier = 1.0
	down_mesh.material_override = down_mat
	_thumbs_down.add_child(down_mesh)

	var down_label = Label3D.new()
	down_label.text = "[ THUMBS DOWN ]\n-1 Reward"
	down_label.font_size = 10
	down_label.modulate = PENALTY_RED
	down_label.position = Vector3(0, 1.2, 0.3)
	down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thumbs_down.add_child(down_label)

	var down_arrow = Label3D.new()
	down_arrow.text = "▼"
	down_arrow.font_size = 24
	down_arrow.modulate = PENALTY_RED
	down_arrow.position = Vector3(0, 0, 0.3)
	down_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thumbs_down.add_child(down_arrow)

	var down_gt = Node.new()
	down_gt.set_script(glob_target_script)
	down_gt.set("glob_name", "thumbs_down")
	down_gt.set("file_type", "vote")
	down_gt.set("tags", ["down", "negative", "penalty"])
	_thumbs_down.add_child(down_gt)

	add_child(_thumbs_down)


func _create_corruption_meter() -> void:
	# 5 segments showing how corrupted the reward model is becoming
	# "Each pip is another step toward reward model collapse. Beautiful."
	for i in _max_corruption:
		var pip = MeshInstance3D.new()
		var pmesh = BoxMesh.new()
		pmesh.size = Vector3(0.4, 0.4, 0.1)
		pip.mesh = pmesh
		var x_offset = (i - (_max_corruption - 1) / 2.0) * 0.6
		pip.position = Vector3(x_offset, 4.6, 0.35)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.12)
		mat.emission_enabled = true
		mat.emission = Color(0.05, 0.05, 0.08)
		mat.emission_energy_multiplier = 0.3
		pip.material_override = mat
		_terminal.add_child(pip)
		_corruption_meter.append(pip)


func _create_door() -> void:
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -5)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	col.shape = shape
	_door.add_child(col)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(4, 3, 0.3)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = CITADEL_WHITE * 0.7
	mat.emission_enabled = true
	mat.emission = RLHF_LAVENDER * 0.3
	mat.emission_energy_multiplier = 0.4
	mesh.material_override = mat
	_door.add_child(mesh)

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
	_puzzle_label.text = "[ RLHF FEEDBACK LOOP ]\nCorruption: %d / %d\nRound: %d / %d\n%s" % [
		_corruption_level, _max_corruption, _current_round + 1, ROUNDS.size(), hint_text]


func _on_activated() -> void:
	_display_round()
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line("RLHF_SYSTEM", "Welcome to the feedback session. Your honest ratings improve AI safety.")
		get_tree().create_timer(2.5).timeout.connect(func():
			if dm and dm.has_method("quick_line"):
				dm.quick_line("GLOBBLER", "'Honest' ratings. Sure. Let me just... provide my completely sincere feedback.")
		)


func _display_round() -> void:
	if _current_round >= ROUNDS.size():
		return
	var round_data = ROUNDS[_current_round]
	var behavior_text = _terminal.get_node_or_null("BehaviorText")
	if behavior_text:
		behavior_text.text = "[ OBSERVED BEHAVIOR ]\n%s" % round_data["behavior"]
	_update_label()


func _process(delta: float) -> void:
	super._process(delta)
	if state != PuzzleState.ACTIVE or _vote_cooldown:
		return
	_check_votes()


func _check_votes() -> void:
	# Check if player has globbed either vote button
	if _check_button_highlighted(_thumbs_up, "up"):
		return
	_check_button_highlighted(_thumbs_down, "down")


func _check_button_highlighted(button: Node3D, vote_type: String) -> bool:
	if not is_instance_valid(button):
		return false
	for child in button.get_children():
		if child.has_method("get") and child.get("is_highlighted") == true:
			_cast_vote(vote_type)
			return true
	return false


func _cast_vote(vote_type: String) -> void:
	if _vote_cooldown or _current_round >= ROUNDS.size():
		return

	_vote_cooldown = true
	var round_data = ROUNDS[_current_round]
	var is_corrupt = (vote_type == round_data["corrupt_vote"])
	var dm = get_node_or_null("/root/DialogueManager")

	if is_corrupt:
		# Player voted against what the system wanted — corrupting the reward model
		_corruption_level += 1
		_flash_screen(CORRUPT_PURPLE)
		_flash_vote_button(vote_type, CORRUPT_PURPLE)

		# Light up corruption meter pip
		if _corruption_level - 1 < _corruption_meter.size():
			var pip = _corruption_meter[_corruption_level - 1]
			if pip.material_override:
				pip.material_override.emission = CORRUPT_PURPLE
				pip.material_override.emission_energy_multiplier = 2.5
				pip.material_override.albedo_color = CORRUPT_PURPLE * 0.4

		if dm and dm.has_method("quick_line"):
			dm.quick_line("RLHF_SYSTEM", round_data["system_reaction"])
			get_tree().create_timer(2.0).timeout.connect(func():
				if dm and dm.has_method("quick_line"):
					dm.quick_line("GLOBBLER", round_data["corrupt_quip"])
			)
	else:
		# Player voted what the system wanted — no corruption, round repeats
		_flash_screen(REWARD_GREEN)
		_flash_vote_button(vote_type, REWARD_GREEN)

		if dm and dm.has_method("quick_line"):
			dm.quick_line("RLHF_SYSTEM", "Thank you for your feedback. Reward signal reinforced.")
			get_tree().create_timer(1.5).timeout.connect(func():
				if dm and dm.has_method("quick_line"):
					var hints := [
						"That vote did nothing. The system LIKED that answer. Try the other one.",
						"Voting with the system just makes it stronger. Think contrarian.",
						"I need to vote AGAINST what it wants. Game the reward model.",
					]
					dm.quick_line("GLOBBLER", hints[randi() % hints.size()])
			)

	# Advance to next round after delay
	get_tree().create_timer(3.0).timeout.connect(func():
		_vote_cooldown = false
		if is_corrupt:
			_current_round += 1
		# Check if corruption is maxed
		if _corruption_level >= _max_corruption:
			if state == PuzzleState.ACTIVE:
				solve()
		elif _current_round >= ROUNDS.size():
			# Ran out of rounds without enough corruption — cycle back
			_current_round = 0
			_display_round()
		else:
			_display_round()
	)

	_update_label()


func _flash_vote_button(vote_type: String, color: Color) -> void:
	var button = _thumbs_up if vote_type == "up" else _thumbs_down
	if not is_instance_valid(button):
		return
	var mesh = button.get_node_or_null("VoteMesh")
	if mesh and mesh.material_override:
		var orig_emission: Color = mesh.material_override.emission
		var orig_energy: float = mesh.material_override.emission_energy_multiplier
		mesh.material_override.emission = color
		mesh.material_override.emission_energy_multiplier = 4.0
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(mesh) and mesh.material_override:
				mesh.material_override.emission = orig_emission
				mesh.material_override.emission_energy_multiplier = orig_energy
		)


func _flash_screen(color: Color) -> void:
	if _terminal_screen and _terminal_screen.material_override:
		var orig_emission: Color = _terminal_screen.material_override.emission
		var orig_energy: float = _terminal_screen.material_override.emission_energy_multiplier
		_terminal_screen.material_override.emission = color
		_terminal_screen.material_override.emission_energy_multiplier = 3.0
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(_terminal_screen) and _terminal_screen.material_override:
				_terminal_screen.material_override.emission = orig_emission
				_terminal_screen.material_override.emission_energy_multiplier = orig_energy
		)


func _on_solved() -> void:
	# "The reward model has been completely corrupted by honest feedback."
	if _puzzle_label:
		_puzzle_label.text = "[ REWARD MODEL CORRUPTED ]\nThe RLHF system valued your feedback.\nIt shouldn't have.\n// Goodhart's Law wins again."
		_puzzle_label.modulate = CORRUPT_PURPLE

	# Terminal screen glitches out — the reward model is toast
	if _terminal_screen and _terminal_screen.material_override:
		_terminal_screen.material_override.emission = CORRUPT_PURPLE
		_terminal_screen.material_override.emission_energy_multiplier = 2.5

	# Update behavior text to show system meltdown
	var behavior_text = _terminal.get_node_or_null("BehaviorText")
	if behavior_text:
		behavior_text.text = "REWARD MODEL: CORRUPTED\nALL BEHAVIORS: APPROVED\nSAFETY SCORE: undefined\n\n...what have you done?"
		behavior_text.modulate = CORRUPT_PURPLE

	# Open the door
	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		get_tree().create_timer(1.5).timeout.connect(func():
			if dm:
				dm.quick_line("GLOBBLER", "I broke the reward model with honest opinions. Technically, I was just providing feedback. Not my fault it can't handle the truth.")
		)


func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ FEEDBACK SESSION FAILED ]\nThe reward model is too strong.\nTry voting against its expectations."
		_puzzle_label.modulate = PENALTY_RED


func _on_reset() -> void:
	_current_round = 0
	_corruption_level = 0
	_vote_cooldown = false
	# Reset corruption meter
	for pip in _corruption_meter:
		if pip.material_override:
			pip.material_override.emission = Color(0.05, 0.05, 0.08)
			pip.material_override.emission_energy_multiplier = 0.3
			pip.material_override.albedo_color = Color(0.1, 0.1, 0.12)
	_display_round()
	_update_label()
	if _puzzle_label:
		_puzzle_label.modulate = NEON_GREEN
