extends Node3D

# Terminal Hack - Globbler's arm-mounted terminal interfaces with hackable objects
# "sudo rm -rf /problems — if only it were that easy."
#
# Press interact near a hackable object to start a minigame.
# Success: opens doors, disables traps, reprograms enemies.
# Failure: triggers alarm or spawns enemies.

const INTERACT_RANGE := 3.5

var player: CharacterBody3D
var _nearby_hackable: Node = null
var _is_hacking := false
var _hack_ui: Control = null

# Minigame state
var _sequence: Array[int] = []
var _player_input: Array[int] = []
var _current_step := 0
var _show_timer := 0.0
var _input_phase := false
var _hack_difficulty := 1

signal hack_started(target: Node)
signal hack_completed(target: Node)
signal hack_failed(target: Node)

func _ready() -> void:
	pass

func setup(p: CharacterBody3D) -> void:
	player = p

func _process(delta: float) -> void:
	if _is_hacking:
		_process_hack_minigame(delta)
		return

	# Scan for nearby hackables
	_scan_for_hackables()

func _scan_for_hackables() -> void:
	if not player:
		return

	_nearby_hackable = null
	var closest_dist := INTERACT_RANGE + 1.0

	# Find all nodes with Hackable component
	for node in get_tree().get_nodes_in_group("hackable"):
		if node is Node3D:
			var dist = player.global_position.distance_to((node as Node3D).global_position)
			if dist < INTERACT_RANGE and dist < closest_dist:
				# Check if it has a hackable component that's available
				for child in node.get_children():
					if child.has_method("is_hackable") and child.is_hackable():
						_nearby_hackable = node
						closest_dist = dist
						break

	# Also check parent nodes of Hackable scripts
	for node in get_tree().get_nodes_in_group("hackable_objects"):
		if node is Node3D:
			var dist = player.global_position.distance_to((node as Node3D).global_position)
			if dist < INTERACT_RANGE and dist < closest_dist:
				_nearby_hackable = node
				closest_dist = dist

func try_interact() -> void:
	if _is_hacking:
		return
	if not _nearby_hackable:
		return

	# Find the Hackable component
	var hackable_comp: Node = null
	for child in _nearby_hackable.get_children():
		if child.has_method("start_hack"):
			hackable_comp = child
			break

	if not hackable_comp:
		return

	# Get difficulty
	if "hack_difficulty" in hackable_comp:
		_hack_difficulty = hackable_comp.hack_difficulty

	hackable_comp.start_hack()
	_start_minigame()
	hack_started.emit(_nearby_hackable)
	# "Initiating hack sequence. Try not to drool on the keyboard."
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_hack_start()

func _start_minigame() -> void:
	_is_hacking = true

	# Generate sequence based on difficulty (3-7 steps)
	var seq_length = 3 + _hack_difficulty
	_sequence.clear()
	for i in range(seq_length):
		_sequence.append(randi() % 4)  # 0=UP, 1=RIGHT, 2=DOWN, 3=LEFT

	_player_input.clear()
	_current_step = 0
	_show_timer = 0.0
	_input_phase = false

	# Show the hack UI
	_create_hack_ui()

func _create_hack_ui() -> void:
	if _hack_ui:
		_hack_ui.queue_free()

	_hack_ui = PanelContainer.new()
	_hack_ui.name = "HackUI"

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.02, 0.95)
	style.border_color = Color(0.224, 1.0, 0.078, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 20.0
	style.content_margin_top = 15.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 15.0
	_hack_ui.add_theme_stylebox_override("panel", style)

	_hack_ui.anchor_left = 0.25
	_hack_ui.anchor_top = 0.3
	_hack_ui.anchor_right = 0.75
	_hack_ui.anchor_bottom = 0.7

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_hack_ui.add_child(vbox)

	var title = Label.new()
	title.name = "Title"
	title.text = "[ TERMINAL HACK - SEQUENCE MEMORY ]"
	title.add_theme_color_override("font_color", Color(0.224, 1.0, 0.078))
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var seq_label = Label.new()
	seq_label.name = "SequenceLabel"
	seq_label.text = "Memorize the sequence..."
	seq_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	seq_label.add_theme_font_size_override("font_size", 24)
	seq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(seq_label)

	var hint = Label.new()
	hint.name = "HintLabel"
	hint.text = "Arrow keys: UP DOWN LEFT RIGHT | ESC to abort"
	hint.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2, 0.7))
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	# Add to canvas layer so it renders on top
	var canvas = CanvasLayer.new()
	canvas.name = "HackCanvas"
	canvas.layer = 10
	canvas.add_child(_hack_ui)
	add_child(canvas)

func _process_hack_minigame(delta: float) -> void:
	if not _input_phase:
		# Show sequence phase
		_show_timer += delta
		var step_duration = 0.8
		var total_show_time = _sequence.size() * step_duration + 0.5

		# Update display
		var current_show = int(_show_timer / step_duration)
		var seq_label = _hack_ui.get_node_or_null("VBoxContainer/SequenceLabel") if _hack_ui else null
		if not seq_label and _hack_ui:
			# Try alternate path — UI nodes love to hide from us
			for child in _hack_ui.get_children():
				if child is VBoxContainer:
					for sub in child.get_children():
						if sub.name == "SequenceLabel":
							seq_label = sub

		if seq_label:
			if current_show < _sequence.size():
				var dir_names = ["UP", "RIGHT", "DOWN", "LEFT"]
				seq_label.text = ">>> %s <<<" % dir_names[_sequence[current_show]]
			else:
				seq_label.text = "YOUR TURN! Repeat the sequence."
				_input_phase = true

func _unhandled_input(event: InputEvent) -> void:
	if not _is_hacking or not _input_phase:
		return

	if event is InputEventKey:
		var key = event as InputEventKey
		if not key.pressed:
			return

		var input_dir := -1
		match key.keycode:
			KEY_UP:
				input_dir = 0
			KEY_RIGHT:
				input_dir = 1
			KEY_DOWN:
				input_dir = 2
			KEY_LEFT:
				input_dir = 3
			KEY_ESCAPE:
				_end_hack(false)
				return

		if input_dir >= 0:
			_player_input.append(input_dir)
			# Every keypress gets a tiny bleep — satisfying terminal feedback
			var audio = get_node_or_null("/root/AudioManager")
			if audio:
				audio.play_hack_keypress()

			if input_dir != _sequence[_current_step]:
				# Wrong input — hack failed!
				_end_hack(false)
				return

			_current_step += 1

			if _current_step >= _sequence.size():
				# All correct — hack succeeded!
				_end_hack(true)

func _end_hack(success: bool) -> void:
	_is_hacking = false
	_input_phase = false

	# Sound feedback — you'll know if you passed or failed before reading the text
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		if success:
			audio.play_hack_success()
		else:
			audio.play_hack_fail()

	# Find hackable component and notify
	if _nearby_hackable:
		for child in _nearby_hackable.get_children():
			if success and child.has_method("complete_hack"):
				child.complete_hack()
				hack_completed.emit(_nearby_hackable)
			elif not success and child.has_method("fail_hack"):
				child.fail_hack()
				hack_failed.emit(_nearby_hackable)

	# Clean up UI
	var canvas = get_node_or_null("HackCanvas")
	if canvas:
		canvas.queue_free()
	_hack_ui = null

func has_nearby_hackable() -> bool:
	return _nearby_hackable != null

func is_hacking() -> bool:
	return _is_hacking
