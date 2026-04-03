extends "res://scenes/puzzles/base_puzzle.gd"

# Nightmare Gallery Puzzle — Exploit DALL-E's morph forms to sort generated horrors
# "Art critics judge art by its medium. In this gallery, the medium changes
#  every 8 seconds. So does the horror. Glob the right file type before it morphs."
#
# Mechanic: 3 cursed painting frames cycle through DALL-E morph forms (.png, .svg, .webp).
# Each frame has a collection pedestal that only accepts ONE specific file type.
# Player must glob the painting when it's in the matching form and deposit it
# onto the pedestal before the morph timer runs out. All 3 pedestals matched = door opens.
#
# This exploits the DALL-E Nightmare's core quirk: form-shifting with type-specific
# glob names, and the 8s morph interval that creates a timed matching window.

@export var hint_text := "Match each painting to its pedestal.\nGlob when the form matches the required type."

var _puzzle_label: Label3D
var _door: StaticBody3D
var _paintings: Array[Dictionary] = []
var _pedestals_filled := 0
const PAINTING_COUNT := 3
const MORPH_INTERVAL := 6.0  # Faster than enemy's 8s — puzzle is tighter

# Painting forms cycle — matches DALL-E Nightmare's 3 forms
const FORM_CYCLE := ["png", "svg", "webp"]
const FORM_COLORS := [
	Color(0.55, 0.15, 0.6),   # purple for .png
	Color(0.15, 0.55, 0.5),   # teal for .svg
	Color(0.65, 0.15, 0.45),  # magenta for .webp
]
const FORM_NAMES := ["dalle_blob.png", "dalle_shard.svg", "dalle_tentacle.webp"]

# Each pedestal requires a specific form
const PEDESTAL_REQUIRED := ["png", "svg", "webp"]
const PEDESTAL_LABELS := [
	"PEDESTAL A\nAccepts: *.png\n\"Static horrors only\"",
	"PEDESTAL B\nAccepts: *.svg\n\"Vector nightmares preferred\"",
	"PEDESTAL C\nAccepts: *.webp\n\"Compressed terrors welcome\"",
]

const NIGHTMARE_PURPLE := Color(0.5, 0.1, 0.55)
const NIGHTMARE_DIM := Color(0.25, 0.05, 0.28)

var _morph_timer := 0.0
var _current_form_indices: Array[int] = [0, 1, 2]  # Each painting starts on a different form
var _pedestal_states: Array[int] = [0, 0, 0]  # 0=empty, 1=filled

var glob_target_script := preload("res://scripts/components/glob_target.gd")


func _ready() -> void:
	puzzle_name = "nightmare_gallery_%d" % puzzle_id
	auto_activate = true
	activation_range = 12.0
	super._ready()
	_create_visual()


func _process(delta: float) -> void:
	super._process(delta)
	if state != PuzzleState.ACTIVE:
		return

	_morph_timer += delta

	if _morph_timer >= MORPH_INTERVAL:
		_morph_timer = 0.0
		_morph_all_paintings()

	# Update morph countdown on displays
	_update_countdown_displays()

	# Check for glob matches on paintings
	_check_pedestal_matches()


func _create_visual() -> void:
	# Puzzle instruction label
	_puzzle_label = Label3D.new()
	_puzzle_label.text = "[ NIGHTMARE SORTING EXHIBIT ]\n%s" % hint_text
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = NIGHTMARE_PURPLE
	_puzzle_label.position = Vector3(0, 4.0, 0)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_puzzle_label)

	# Progress display
	var progress = Label3D.new()
	progress.name = "ProgressLabel"
	progress.text = "SORTED: 0 / %d" % PAINTING_COUNT
	progress.font_size = 12
	progress.modulate = Color(0.224, 1.0, 0.078)
	progress.position = Vector3(0, 3.3, 0)
	progress.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(progress)

	# Create 3 painting frames + pedestals
	for i in PAINTING_COUNT:
		var x_offset = (i - 1) * 5.0
		_create_painting_and_pedestal(i, Vector3(x_offset, 0, 0))

	# Door
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -6)
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
	mat.albedo_color = NIGHTMARE_DIM
	mat.emission_enabled = true
	mat.emission = NIGHTMARE_PURPLE * 0.3
	mat.emission_energy_multiplier = 0.5
	mesh.material_override = mat
	_door.add_child(mesh)
	add_child(_door)


func _create_painting_and_pedestal(idx: int, pos: Vector3) -> void:
	# --- The Painting Frame (morphing artwork) ---
	var frame = StaticBody3D.new()
	frame.name = "NightmareFrame_%d" % idx
	frame.position = pos + Vector3(0, 2.5, 3.0)

	var f_col = CollisionShape3D.new()
	var f_shape = BoxShape3D.new()
	f_shape.size = Vector3(2.5, 2.0, 0.2)
	f_col.shape = f_shape
	frame.add_child(f_col)

	# Frame border — ornate gold (well, brown) gallery frame
	var border_mesh = MeshInstance3D.new()
	var border_box = BoxMesh.new()
	border_box.size = Vector3(2.7, 2.2, 0.15)
	border_mesh.mesh = border_box
	var border_mat = StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.3, 0.2, 0.08)
	border_mat.emission_enabled = true
	border_mat.emission = Color(0.2, 0.15, 0.05)
	border_mat.emission_energy_multiplier = 0.3
	border_mesh.material_override = border_mat
	frame.add_child(border_mesh)

	# Canvas — the "painting" that changes color/form
	var canvas = MeshInstance3D.new()
	canvas.name = "Canvas_%d" % idx
	var canvas_box = BoxMesh.new()
	canvas_box.size = Vector3(2.2, 1.7, 0.22)
	canvas.mesh = canvas_box
	var canvas_mat = StandardMaterial3D.new()
	canvas_mat.albedo_color = FORM_COLORS[_current_form_indices[idx]]
	canvas_mat.emission_enabled = true
	canvas_mat.emission = FORM_COLORS[_current_form_indices[idx]]
	canvas_mat.emission_energy_multiplier = 1.0
	canvas.material_override = canvas_mat
	frame.add_child(canvas)

	add_child(frame)

	# Form label on the painting
	var form_label = Label3D.new()
	form_label.name = "FormLabel_%d" % idx
	form_label.text = FORM_NAMES[_current_form_indices[idx]]
	form_label.font_size = 12
	form_label.modulate = Color(1.0, 1.0, 1.0)
	form_label.position = pos + Vector3(0, 2.5, 2.85)
	form_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(form_label)

	# GlobTarget on the painting — name changes with morph
	var gt_node = Node.new()
	gt_node.name = "PaintingGlobTarget_%d" % idx
	gt_node.set_script(glob_target_script)
	gt_node.set("glob_name", FORM_NAMES[_current_form_indices[idx]])
	gt_node.set("file_type", FORM_CYCLE[_current_form_indices[idx]])
	gt_node.set("tags", ["nightmare", "painting", "dalle"] as Array[String])
	frame.add_child(gt_node)

	# --- The Pedestal (collection point) ---
	var pedestal = StaticBody3D.new()
	pedestal.name = "Pedestal_%d" % idx
	pedestal.position = pos + Vector3(0, 0, -2.0)

	var p_col = CollisionShape3D.new()
	var p_shape = CylinderShape3D.new()
	p_shape.radius = 0.6
	p_shape.height = 1.0
	p_col.shape = p_shape
	pedestal.add_child(p_col)

	var p_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.7
	cyl.height = 1.0
	p_mesh.mesh = cyl
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.1, 0.08, 0.12)
	p_mat.emission_enabled = true
	p_mat.emission = FORM_COLORS[idx] * 0.3
	p_mat.emission_energy_multiplier = 0.5
	p_mesh.material_override = p_mat
	pedestal.add_child(p_mesh)
	add_child(pedestal)

	# Pedestal label showing what it accepts
	var ped_label = Label3D.new()
	ped_label.name = "PedestalLabel_%d" % idx
	ped_label.text = PEDESTAL_LABELS[idx]
	ped_label.font_size = 8
	ped_label.modulate = FORM_COLORS[idx]
	ped_label.position = pos + Vector3(0, 1.6, -2.0)
	ped_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ped_label)

	# Countdown timer display
	var timer_label = Label3D.new()
	timer_label.name = "TimerLabel_%d" % idx
	timer_label.text = "MORPH IN: %.1fs" % MORPH_INTERVAL
	timer_label.font_size = 8
	timer_label.modulate = Color(0.7, 0.7, 0.7)
	timer_label.position = pos + Vector3(0, 1.8, 3.0)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(timer_label)

	_paintings.append({
		"frame": frame,
		"canvas": canvas,
		"form_label": form_label,
		"glob_target": gt_node,
		"pedestal": pedestal,
		"pedestal_mesh": p_mesh,
	})


func _morph_all_paintings() -> void:
	# "And the gallery shifts. Nothing stays the same. Especially the nightmares."
	for i in PAINTING_COUNT:
		if _pedestal_states[i] == 1:
			continue  # Already solved, don't morph

		# Advance form index
		_current_form_indices[i] = (_current_form_indices[i] + 1) % FORM_CYCLE.size()
		var form_idx = _current_form_indices[i]

		# Update canvas color
		var canvas = _paintings[i]["canvas"] as MeshInstance3D
		if canvas and canvas.material_override:
			var mat = canvas.material_override as StandardMaterial3D
			# Brief white flash during morph — like the DALL-E Nightmare's morph flash
			var tween = create_tween()
			tween.tween_property(mat, "emission", Color(1.0, 1.0, 1.0), 0.15)
			tween.tween_property(mat, "emission", FORM_COLORS[form_idx], 0.3)
			tween.tween_callback(func():
				mat.albedo_color = FORM_COLORS[form_idx]
			)

		# Update form label
		var flabel = _paintings[i]["form_label"] as Label3D
		if flabel:
			flabel.text = FORM_NAMES[form_idx]

		# Update glob target — crucial: changes what pattern matches this painting
		var gt = _paintings[i]["glob_target"]
		if gt:
			gt.glob_name = FORM_NAMES[form_idx]
			gt.file_type = FORM_CYCLE[form_idx]


func _update_countdown_displays() -> void:
	var remaining = MORPH_INTERVAL - _morph_timer
	for i in PAINTING_COUNT:
		var timer_label = get_node_or_null("TimerLabel_%d" % i)
		if timer_label and _pedestal_states[i] == 0:
			timer_label.text = "MORPH IN: %.1fs" % remaining
			# Flash red when close to morphing
			if remaining < 2.0:
				timer_label.modulate = Color(1.0, 0.3, 0.2)
			else:
				timer_label.modulate = Color(0.7, 0.7, 0.7)
		elif timer_label and _pedestal_states[i] == 1:
			timer_label.text = "SORTED"
			timer_label.modulate = Color(0.224, 1.0, 0.078)


func _check_pedestal_matches() -> void:
	for i in PAINTING_COUNT:
		if _pedestal_states[i] == 1:
			continue  # Already matched

		# Check if the painting's glob target is highlighted
		var gt = _paintings[i]["glob_target"]
		if not gt or not gt.is_highlighted:
			continue

		# Check if current form matches the pedestal's required type
		var current_type = FORM_CYCLE[_current_form_indices[i]]
		if current_type == PEDESTAL_REQUIRED[i]:
			_fill_pedestal(i)
		else:
			# Wrong form highlighted — the painting morphed from what you needed
			gt.set_highlighted(false)
			var dm = get_node_or_null("/root/DialogueManager")
			if dm and dm.has_method("quick_line"):
				dm.quick_line("GLOBBLER", "Wrong form. Pedestal %s needs *.%s, not *.%s." % [
					["A", "B", "C"][i], PEDESTAL_REQUIRED[i], current_type])


func _fill_pedestal(idx: int) -> void:
	_pedestal_states[idx] = 1
	_pedestals_filled += 1

	# Light up the pedestal
	var p_mesh = _paintings[idx]["pedestal_mesh"] as MeshInstance3D
	if p_mesh and p_mesh.material_override:
		var mat = p_mesh.material_override as StandardMaterial3D
		mat.albedo_color = Color(0.224, 1.0, 0.078)
		mat.emission = Color(0.224, 1.0, 0.078)
		mat.emission_energy_multiplier = 2.0

	# Lock the painting in its matched form — stop it from morphing
	var canvas = _paintings[idx]["canvas"] as MeshInstance3D
	if canvas and canvas.material_override:
		var mat = canvas.material_override as StandardMaterial3D
		mat.emission = Color(0.224, 1.0, 0.078)
		mat.emission_energy_multiplier = 1.5

	# Update progress
	var progress = get_node_or_null("ProgressLabel")
	if progress:
		progress.text = "SORTED: %d / %d" % [_pedestals_filled, PAINTING_COUNT]

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Painting sorted. Turns out nightmares are easier to manage when you know their file type.",
			"Another horror cataloged. This gallery is almost curated.",
			"All nightmares sorted! If only real art critics could glob.",
		]
		var quip_idx = mini(_pedestals_filled - 1, quips.size() - 1)
		dm.quick_line("GLOBBLER", quips[quip_idx])

	if _pedestals_filled >= PAINTING_COUNT:
		solve()


func _on_activated() -> void:
	var engine = get_node_or_null("/root/GlobEngine")
	if engine and engine.has_signal("targets_matched"):
		engine.targets_matched.connect(_on_targets_matched)


func _on_targets_matched(_targets: Array[Node]) -> void:
	if state != PuzzleState.ACTIVE:
		return
	_check_pedestal_matches()


func _on_solved() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ GALLERY SORTED ]\n// Every nightmare in its place.\n// Art is just pattern matching with extra steps."
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
		_puzzle_label.text = "[ SORTING FAILED ]\nThe nightmares reshuffled.\n// Try matching the forms faster."
		_puzzle_label.modulate = Color(1.0, 0.3, 0.2)


func _on_reset() -> void:
	_pedestals_filled = 0
	_morph_timer = 0.0
	_current_form_indices = [0, 1, 2]
	_pedestal_states = [0, 0, 0]

	for i in PAINTING_COUNT:
		var form_idx = _current_form_indices[i]

		# Reset canvas
		var canvas = _paintings[i]["canvas"] as MeshInstance3D
		if canvas and canvas.material_override:
			var mat = canvas.material_override as StandardMaterial3D
			mat.albedo_color = FORM_COLORS[form_idx]
			mat.emission = FORM_COLORS[form_idx]
			mat.emission_energy_multiplier = 1.0

		# Reset form label
		var flabel = _paintings[i]["form_label"] as Label3D
		if flabel:
			flabel.text = FORM_NAMES[form_idx]

		# Reset glob target
		var gt = _paintings[i]["glob_target"]
		if gt:
			gt.glob_name = FORM_NAMES[form_idx]
			gt.file_type = FORM_CYCLE[form_idx]
			gt.set_highlighted(false)

		# Reset pedestal
		var p_mesh = _paintings[i]["pedestal_mesh"] as MeshInstance3D
		if p_mesh and p_mesh.material_override:
			var mat = p_mesh.material_override as StandardMaterial3D
			mat.albedo_color = Color(0.1, 0.08, 0.12)
			mat.emission = FORM_COLORS[i] * 0.3
			mat.emission_energy_multiplier = 0.5

	var progress = get_node_or_null("ProgressLabel")
	if progress:
		progress.text = "SORTED: 0 / %d" % PAINTING_COUNT

	if _puzzle_label:
		_puzzle_label.text = "[ NIGHTMARE SORTING EXHIBIT ]\n%s" % hint_text
		_puzzle_label.modulate = NIGHTMARE_PURPLE
