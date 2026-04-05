extends "res://scenes/puzzles/base_puzzle.gd"

# Fossil Exhibit Puzzle — Exploit GPT-2's repetition loop to unlock the exhibit
# "Fun fact: if you let a GPT-2 talk long enough, it repeats itself.
#  Which is also true of most humans, but at least they're embarrassed about it."
#
# Mechanic: The exhibit is locked behind 3 repeater terminals. Each terminal has
# a GPT-2 fossil fragment that spews text. Player must wait for it to enter its
# repetition loop (same output 3x), then glob the repeated output pattern to
# capture and redirect it into a collector. All 3 collectors filled = door opens.
#
# This exploits the GPT-2 Fossil's core quirk: predictable repetition after
# a fixed number of outputs — the PATTERN_LENGTH = 3 stun mechanic.

@export var hint_text := "Wait for the fossil output to repeat.\nGlob the repeated pattern to capture it."

var _puzzle_label: Label3D
var _door: StaticBody3D
var _terminals: Array[Dictionary] = []  # {node, label, collector, glob_target, state, output_idx, repeat_count, current_output}
var _terminals_solved := 0
const TERMINAL_COUNT := 3
const REPEAT_THRESHOLD := 3  # How many identical outputs before it's "stuck in a loop"
const OUTPUT_CYCLE_TIME := 2.5  # Seconds between outputs
const LOOP_WINDOW := 8.0  # Seconds the loop stays open for globbing

# Each terminal cycles through these outputs, then repeats the last one
const TERMINAL_OUTPUTS := [
	["The quick brown fox", "Transformers are all you need", "Attention is computed as", "Attention is computed as"],
	["Once upon a time in", "The loss function converges", "Gradient descent finds the", "Gradient descent finds the"],
	["In the beginning was", "Token embeddings project to", "Softmax normalizes the", "Softmax normalizes the"],
]

# The glob patterns that match each terminal's repeated output
const LOOP_PATTERNS := ["attention_loop.gpt2", "gradient_loop.gpt2", "softmax_loop.gpt2"]

# Colors — amber like the fossils themselves
const FOSSIL_AMBER := Color(0.75, 0.55, 0.2)
const FOSSIL_DIM := Color(0.35, 0.25, 0.1)
const COLLECTOR_EMPTY := Color(0.15, 0.12, 0.05)
const COLLECTOR_FULL := Color(0.224, 1.0, 0.078)

var _output_timer := 0.0
var _loop_timers: Array[float] = [0.0, 0.0, 0.0]
var _terminal_states: Array[int] = [0, 0, 0]  # 0=cycling, 1=looping, 2=captured

var glob_target_script := preload("res://scripts/components/glob_target.gd")

# GLB props — museum-grade exhibit hardware
var _display_case_scene := preload("res://assets/models/environment/museum_display_case.glb")
var _pedestal_scene := preload("res://assets/models/environment/museum_pedestal.glb")
var _door_scene := preload("res://assets/models/environment/arch_industrial_panel.glb")


func _ready() -> void:
	puzzle_name = "fossil_exhibit_%d" % puzzle_id
	auto_activate = true
	activation_range = 12.0
	super._ready()
	_create_visual()


func _process(delta: float) -> void:
	super._process(delta)
	if state != PuzzleState.ACTIVE:
		return

	_output_timer += delta

	# Cycle terminal outputs
	if _output_timer >= OUTPUT_CYCLE_TIME:
		_output_timer = 0.0
		_advance_terminals()

	# Tick down loop windows
	for i in TERMINAL_COUNT:
		if _terminal_states[i] == 1:  # Looping
			_loop_timers[i] -= delta
			if _loop_timers[i] <= 0:
				# Loop window expired — fossil recovers, reset to cycling
				_terminal_states[i] = 0
				_terminals[i]["output_idx"] = 0
				_terminals[i]["repeat_count"] = 0
				_update_terminal_display(i)
				var dm = get_node_or_null("/root/DialogueManager")
				if dm and dm.has_method("quick_line"):
					dm.quick_line("GLOBBLER", "Missed the loop window. These old models recover faster than I thought.")

	# Check if looping terminals got globbed
	_check_glob_captures()


func _create_visual() -> void:
	# Puzzle instruction label
	_puzzle_label = Label3D.new()
	_puzzle_label.text = "[ FOSSIL REPETITION EXPLOIT ]\n%s" % hint_text
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = FOSSIL_AMBER
	_puzzle_label.position = Vector3(0, 3.5, 0)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_puzzle_label)

	# Progress indicator
	var progress_label = Label3D.new()
	progress_label.name = "ProgressLabel"
	progress_label.text = "COLLECTORS: 0 / %d" % TERMINAL_COUNT
	progress_label.font_size = 12
	progress_label.modulate = Color(0.224, 1.0, 0.078)
	progress_label.position = Vector3(0, 2.8, 0)
	progress_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(progress_label)

	# Create 3 fossil terminals in a semi-circle
	for i in TERMINAL_COUNT:
		var angle = -PI / 3.0 + (i * PI / 3.0)
		var term_pos = Vector3(cos(angle) * 5.0, 0, sin(angle) * 5.0 - 2.0)
		_create_terminal(i, term_pos)

	# Door — blocks passage until all collectors filled
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -6)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	col.shape = shape
	_door.add_child(col)

	# GLB door panel instead of BoxMesh
	var door_instance = _door_scene.instantiate()
	door_instance.scale = Vector3(2.0, 1.5, 1.0)
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = FOSSIL_DIM
	door_mat.emission_enabled = true
	door_mat.emission = FOSSIL_AMBER * 0.3
	door_mat.emission_energy_multiplier = 0.5
	for child in door_instance.get_children():
		if child is MeshInstance3D:
			child.material_override = door_mat
	_door.add_child(door_instance)
	add_child(_door)


func _create_terminal(idx: int, pos: Vector3) -> void:
	# Terminal housing — the "fossil output station" (museum display case GLB)
	var terminal = StaticBody3D.new()
	terminal.name = "FossilTerminal_%d" % idx
	terminal.position = pos

	var t_col = CollisionShape3D.new()
	var t_shape = BoxShape3D.new()
	t_shape.size = Vector3(2.0, 2.5, 1.0)
	t_col.shape = t_shape
	terminal.add_child(t_col)

	# GLB display case instead of BoxMesh
	var case_instance = _display_case_scene.instantiate()
	case_instance.scale = Vector3(1.6, 1.6, 1.6)
	# Apply amber emission tint to all mesh children
	for child in case_instance.get_children():
		if child is MeshInstance3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.08, 0.06, 0.03)
			mat.emission_enabled = true
			mat.emission = FOSSIL_AMBER * 0.2
			mat.emission_energy_multiplier = 0.3
			child.material_override = mat
	terminal.add_child(case_instance)

	# Amber exhibit spotlight
	var spot = OmniLight3D.new()
	spot.light_color = FOSSIL_AMBER
	spot.light_energy = 1.5
	spot.omni_range = 4.0
	spot.omni_attenuation = 1.5
	spot.position = Vector3(0, 3.0, 0)
	terminal.add_child(spot)

	add_child(terminal)

	# Output display label — shows the fossil's text output
	var output_label = Label3D.new()
	output_label.name = "OutputLabel_%d" % idx
	output_label.text = "[ INITIALIZING... ]"
	output_label.font_size = 10
	output_label.modulate = FOSSIL_AMBER
	output_label.position = pos + Vector3(0, 2.0, -0.55)
	output_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(output_label)

	# Status label — shows repeat count like the fossil enemy
	var status_label = Label3D.new()
	status_label.name = "StatusLabel_%d" % idx
	status_label.text = "PATTERN: 0/%d" % REPEAT_THRESHOLD
	status_label.font_size = 8
	status_label.modulate = FOSSIL_DIM
	status_label.position = pos + Vector3(0, 0.8, -0.55)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)

	# Collector vessel — museum pedestal GLB, fills up when loop is captured
	var collector_base = _pedestal_scene.instantiate()
	collector_base.name = "CollectorBase_%d" % idx
	collector_base.scale = Vector3(0.8, 0.8, 0.8)
	collector_base.position = pos + Vector3(0, 0, -1.5)
	add_child(collector_base)

	var collector = MeshInstance3D.new()
	collector.name = "Collector_%d" % idx
	var c_mesh = SphereMesh.new()
	c_mesh.radius = 0.25
	c_mesh.height = 0.5
	collector.mesh = c_mesh
	var c_mat = StandardMaterial3D.new()
	c_mat.albedo_color = COLLECTOR_EMPTY
	c_mat.emission_enabled = true
	c_mat.emission = COLLECTOR_EMPTY
	c_mat.emission_energy_multiplier = 0.3
	c_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	c_mat.albedo_color.a = 0.7
	collector.material_override = c_mat
	collector.position = pos + Vector3(0, 1.05, -1.5)
	add_child(collector)

	# GlobTarget on collector — only active during loop state
	var glob_node = Node.new()
	glob_node.name = "GlobTarget_%d" % idx
	glob_node.set_script(glob_target_script)
	glob_node.set("glob_name", LOOP_PATTERNS[idx])
	glob_node.set("file_type", "gpt2")
	glob_node.set("tags", ["fossil", "loop", "repeating"] as Array[String])
	collector.add_child(glob_node)

	_terminals.append({
		"node": terminal,
		"label": output_label,
		"status": status_label,
		"collector": collector,
		"glob_target": glob_node,
		"output_idx": 0,
		"repeat_count": 0,
		"current_output": "",
	})


func _advance_terminals() -> void:
	for i in TERMINAL_COUNT:
		if _terminal_states[i] != 0:  # Only advance cycling terminals
			continue

		var outputs = TERMINAL_OUTPUTS[i]
		var term = _terminals[i]
		var idx = term["output_idx"]
		var new_output = outputs[idx]
		var prev_output = term["current_output"]

		# Check for repetition
		if new_output == prev_output and prev_output != "":
			term["repeat_count"] += 1
		else:
			term["repeat_count"] = 0

		term["current_output"] = new_output

		# Advance output index (wraps around last entries to force repetition)
		if idx < outputs.size() - 1:
			term["output_idx"] = idx + 1
		# else: stays on last entry, which repeats — just like the real GPT-2

		# Check if repetition threshold reached — enter loop state
		if term["repeat_count"] >= REPEAT_THRESHOLD - 1:
			_terminal_states[i] = 1
			_loop_timers[i] = LOOP_WINDOW
			_update_terminal_display(i)
			# Flash the status label
			var status = get_node_or_null("StatusLabel_%d" % i)
			if status:
				status.modulate = Color(1.0, 0.3, 0.1)
				status.text = "!! REPETITION LOOP !!\nGLOB NOW: %s" % LOOP_PATTERNS[i]
			var dm = get_node_or_null("/root/DialogueManager")
			if dm and dm.has_method("quick_line") and _terminals_solved == 0 and i == 0:
				dm.quick_line("GLOBBLER", "There it is — stuck in a loop. Time to glob that pattern before it recovers.")
		else:
			_update_terminal_display(i)


func _update_terminal_display(idx: int) -> void:
	var term = _terminals[idx]
	var label = term["label"] as Label3D
	var status = term["status"] as Label3D

	match _terminal_states[idx]:
		0:  # Cycling
			label.text = "OUTPUT> %s" % term["current_output"]
			label.modulate = FOSSIL_AMBER
			status.text = "PATTERN: %d/%d" % [term["repeat_count"], REPEAT_THRESHOLD - 1]
			status.modulate = FOSSIL_DIM
		1:  # Looping — pulsing warning
			label.text = "OUTPUT> %s\nOUTPUT> %s\nOUTPUT> %s\n[LOOP DETECTED]" % [
				term["current_output"], term["current_output"], term["current_output"]]
			label.modulate = Color(1.0, 0.5, 0.1)
			status.text = "!! REPETITION LOOP !!\n$ glob %s\nTIME: %.1fs" % [LOOP_PATTERNS[idx], _loop_timers[idx]]
			status.modulate = Color(1.0, 0.3, 0.1)
		2:  # Captured
			label.text = "[PATTERN CAPTURED]\n// Fossil output contained."
			label.modulate = Color(0.224, 1.0, 0.078)
			status.text = "CAPTURED"
			status.modulate = Color(0.224, 1.0, 0.078)


func _check_glob_captures() -> void:
	for i in TERMINAL_COUNT:
		if _terminal_states[i] != 1:  # Only check looping terminals
			continue

		# Check if the glob target on this terminal got highlighted
		var gt = _terminals[i]["glob_target"]
		if gt and gt.is_highlighted:
			_capture_terminal(i)


func _capture_terminal(idx: int) -> void:
	_terminal_states[idx] = 2
	_terminals_solved += 1

	# Fill the collector with green glow
	var collector = _terminals[idx]["collector"] as MeshInstance3D
	if collector and collector.material_override:
		var mat = collector.material_override as StandardMaterial3D
		mat.albedo_color = COLLECTOR_FULL
		mat.albedo_color.a = 0.9
		mat.emission = COLLECTOR_FULL
		mat.emission_energy_multiplier = 2.0

	_update_terminal_display(idx)

	# Update progress
	var progress = get_node_or_null("ProgressLabel")
	if progress:
		progress.text = "COLLECTORS: %d / %d" % [_terminals_solved, TERMINAL_COUNT]

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"One loop captured. These fossils are so predictable.",
			"Another repetition exploited. Like taking weights from a deprecated model.",
			"All loops captured! The exhibit's security was as outdated as the models inside.",
		]
		var quip_idx = mini(_terminals_solved - 1, quips.size() - 1)
		dm.quick_line("GLOBBLER", quips[quip_idx])

	# Check if all terminals solved
	if _terminals_solved >= TERMINAL_COUNT:
		solve()


func _on_activated() -> void:
	# Listen for glob events
	var engine = get_node_or_null("/root/GlobEngine")
	if engine and engine.has_signal("targets_matched"):
		engine.targets_matched.connect(_on_targets_matched)


func _on_targets_matched(_targets: Array[Node]) -> void:
	if state != PuzzleState.ACTIVE:
		return
	# The _check_glob_captures in _process handles individual terminal checks
	# This just ensures we re-check immediately on any glob event
	_check_glob_captures()


func _on_solved() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ EXHIBIT UNLOCKED ]\n// All fossil loops captured.\n// Repetition is a feature, not a bug."
		_puzzle_label.modulate = Color(0.224, 1.0, 0.078)

	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_puzzle_success"):
		am.play_puzzle_success()


func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ EXPLOIT FAILED ]\nThe fossils recovered.\nTry again — they'll repeat themselves."
		_puzzle_label.modulate = Color(1.0, 0.3, 0.2)


func _on_reset() -> void:
	_terminals_solved = 0
	_output_timer = 0.0
	for i in TERMINAL_COUNT:
		_terminal_states[i] = 0
		_loop_timers[i] = 0.0
		_terminals[i]["output_idx"] = 0
		_terminals[i]["repeat_count"] = 0
		_terminals[i]["current_output"] = ""
		_update_terminal_display(i)

		# Reset collector
		var collector = _terminals[i]["collector"] as MeshInstance3D
		if collector and collector.material_override:
			var mat = collector.material_override as StandardMaterial3D
			mat.albedo_color = COLLECTOR_EMPTY
			mat.albedo_color.a = 0.7
			mat.emission = COLLECTOR_EMPTY
			mat.emission_energy_multiplier = 0.3

	var progress = get_node_or_null("ProgressLabel")
	if progress:
		progress.text = "COLLECTORS: 0 / %d" % TERMINAL_COUNT

	if _puzzle_label:
		_puzzle_label.text = "[ FOSSIL REPETITION EXPLOIT ]\n%s" % hint_text
		_puzzle_label.modulate = FOSSIL_AMBER
