extends "res://scenes/puzzles/base_puzzle.gd"

# Recursive Glob Puzzle - Nested directory challenge
# "glob -r is not a lifestyle, it's a cry for help."
#
# The puzzle spawns "directory" nodes containing "file" objects at multiple
# depths. Player must use recursive-style glob patterns to match deeply
# nested targets. This is the optional hard puzzle for completionists
# who think they're clever.

@export var required_pattern := "**/secret.key"
@export var target_count := 1
@export var hint_text := "Some files hide deep. Think recursively."
@export var directory_structure: Array[String] = [
	"root/",
	"root/bin/",
	"root/bin/tools/",
	"root/etc/",
	"root/etc/config/",
	"root/var/",
	"root/var/log/",
	"root/var/log/old/",
]
@export var file_entries: Array[Dictionary] = []
# Each entry: { "dir": "root/var/log/old/", "name": "secret.key", "type": "key", "tags": ["hidden", "recursive"] }

var _puzzle_label: Label3D
var _door: StaticBody3D
var _dir_visuals: Array[Node3D] = []
var _file_nodes: Array[Node3D] = []

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const SYNAPSE_TEAL := Color(0.29, 0.88, 0.65)  # Ch2 teal #4AE0A5
const DARK_BASE := Color(0.04, 0.1, 0.1)  # Ch2 dark
const DIR_COLOR := Color(0.04, 0.1, 0.08)
const FILE_COLOR := Color(0.04, 0.08, 0.1)

const _hard_drive_scene = preload("res://assets/models/environment/prop_hard_drive.glb")
const _floppy_scene = preload("res://assets/models/environment/prop_floppy_disk.glb")
const _panel_scene = preload("res://assets/models/environment/arch_industrial_panel.glb")

func _ready() -> void:
	puzzle_name = "recursive_glob_%d" % puzzle_id
	auto_activate = true
	super._ready()
	_create_directory_tree()
	_create_files()
	_create_label()
	_create_door()

func _create_directory_tree() -> void:
	# Build a visual representation of nested directories — filing cabinets of despair
	var base_pos = Vector3(-3, 0, 0)
	for i in directory_structure.size():
		var depth = directory_structure[i].count("/") - 1
		var dir_node = Node3D.new()
		dir_node.name = "Dir_%s" % directory_structure[i].replace("/", "_").rstrip("_")

		# Stagger position by depth and index for visual clarity
		var x = base_pos.x + depth * 1.8
		var z = base_pos.z + i * 1.5
		var y = 0.5
		dir_node.position = Vector3(x, y, z)

		# GLB hard drive prop replacing BoxMesh directory folder
		var drive_inst = _hard_drive_scene.instantiate()
		drive_inst.name = "DirMesh"
		drive_inst.scale = Vector3(1.0, 1.0, 1.0)
		dir_node.add_child(drive_inst)

		# Emissive teal glow light for directory
		var dir_light = OmniLight3D.new()
		dir_light.light_color = SYNAPSE_TEAL
		dir_light.light_energy = 0.3
		dir_light.omni_range = 1.5
		dir_light.position = Vector3(0, 0.3, 0)
		dir_node.add_child(dir_light)

		# Directory name label
		var label = Label3D.new()
		label.text = directory_structure[i].get_file().rstrip("/")
		if label.text == "":
			label.text = directory_structure[i].rstrip("/")
		label.font_size = 10
		label.modulate = SYNAPSE_TEAL * 0.7
		label.position = Vector3(0, 0.6, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		dir_node.add_child(label)

		# Depth indicator line connecting to parent
		if depth > 0:
			# Cylinder connector replacing BoxMesh line
			var line = MeshInstance3D.new()
			var tube = CylinderMesh.new()
			tube.top_radius = 0.04
			tube.bottom_radius = 0.04
			tube.height = 1.5
			tube.radial_segments = 8
			line.mesh = tube
			line.position = Vector3(-0.9, 0, 0)
			line.rotation = Vector3(0, 0, PI / 2.0)  # Rotate to horizontal
			var line_mat = StandardMaterial3D.new()
			line_mat.albedo_color = SYNAPSE_TEAL * 0.3
			line_mat.emission_enabled = true
			line_mat.emission = SYNAPSE_TEAL * 0.3
			line_mat.emission_energy_multiplier = 0.5
			line.material_override = line_mat
			dir_node.add_child(line)

		add_child(dir_node)
		_dir_visuals.append(dir_node)

func _create_files() -> void:
	# Place file objects inside their directories — digital buried treasure
	if file_entries.is_empty():
		# Default files if none provided — a mix of distractors and the real target
		file_entries = [
			{ "dir": "root/", "name": "readme.txt", "type": "txt", "tags": ["text", "readme"] },
			{ "dir": "root/bin/", "name": "glob.exe", "type": "exe", "tags": ["binary", "tool"] },
			{ "dir": "root/bin/tools/", "name": "wrench.dll", "type": "dll", "tags": ["binary", "library"] },
			{ "dir": "root/etc/", "name": "config.cfg", "type": "cfg", "tags": ["config"] },
			{ "dir": "root/etc/config/", "name": "auth.cfg", "type": "cfg", "tags": ["config", "auth"] },
			{ "dir": "root/var/", "name": "status.log", "type": "log", "tags": ["log"] },
			{ "dir": "root/var/log/", "name": "error.log", "type": "log", "tags": ["log", "error"] },
			{ "dir": "root/var/log/old/", "name": "secret.key", "type": "key", "tags": ["hidden", "recursive", "key"] },
		]

	for entry in file_entries:
		# Find the directory this file belongs to
		var dir_path: String = entry.get("dir", "root/")
		var dir_index := -1
		for i in directory_structure.size():
			if directory_structure[i] == dir_path:
				dir_index = i
				break

		var file_node = StaticBody3D.new()
		var fname: String = entry.get("name", "unknown")
		file_node.name = "File_%s" % fname.replace(".", "_")

		# Position near the directory visual or offset if no match found
		if dir_index >= 0 and dir_index < _dir_visuals.size():
			var dir_pos = _dir_visuals[dir_index].position
			file_node.position = dir_pos + Vector3(0.6, 0.3, 0.3)
		else:
			file_node.position = Vector3(0, 0.5, _file_nodes.size() * 1.5)

		# Collision
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.5, 0.4, 0.3)
		col.shape = shape
		file_node.add_child(col)

		# GLB floppy disk prop replacing BoxMesh data slab
		var floppy_inst = _floppy_scene.instantiate()
		floppy_inst.name = "FileMesh"
		floppy_inst.scale = Vector3(0.8, 0.8, 0.8)
		file_node.add_child(floppy_inst)

		# Emissive glow indicator for file
		var glow = MeshInstance3D.new()
		glow.name = "FileGlow"
		var glow_sphere = SphereMesh.new()
		glow_sphere.radius = 0.1
		glow_sphere.height = 0.2
		glow_sphere.radial_segments = 8
		glow_sphere.rings = 4
		glow.mesh = glow_sphere
		glow.position = Vector3(0, 0.3, 0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = FILE_COLOR
		mat.emission_enabled = true
		mat.emission = SYNAPSE_TEAL * 0.15
		mat.emission_energy_multiplier = 0.2
		mat.metallic = 0.4
		glow.material_override = mat
		file_node.add_child(glow)

		# File name label
		var label = Label3D.new()
		label.text = fname
		label.font_size = 8
		label.modulate = SYNAPSE_TEAL * 0.6
		label.position = Vector3(0, 0.35, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		file_node.add_child(label)

		# GlobTarget component — the thing that makes it matchable
		var glob_target = preload("res://scripts/components/glob_target.gd").new()
		# Use the full path as the glob_name for recursive matching
		glob_target.glob_name = dir_path + fname
		glob_target.file_type = entry.get("type", "")
		var tags_raw = entry.get("tags", [])
		var typed_tags: Array[String] = []
		for t in tags_raw:
			typed_tags.append(str(t))
		glob_target.tags = typed_tags
		file_node.add_child(glob_target)

		add_child(file_node)
		_file_nodes.append(file_node)

func _create_label() -> void:
	_puzzle_label = Label3D.new()
	_puzzle_label.text = "[ RECURSIVE GLOB CHALLENGE ]\n$ glob -r %s\n%s\n// OPTIONAL — for the truly stubborn" % [
		required_pattern, hint_text]
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = Color(1.0, 0.85, 0.2)  # Gold for optional
	_puzzle_label.position = Vector3(0, 4.0, 0)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_puzzle_label)

func _create_door() -> void:
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -3)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	col.shape = shape
	_door.add_child(col)

	# GLB industrial panel replacing BoxMesh door
	var door_inst = _panel_scene.instantiate()
	door_inst.name = "DoorPanel"
	door_inst.scale = Vector3(2.0, 1.5, 1.0)
	_door.add_child(door_inst)

	# Emissive overlay for tween animation
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(4, 3, 0.05)
	mesh.mesh = box
	mesh.position = Vector3(0, 0, 0.2)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = SYNAPSE_TEAL * 0.15
	mat.albedo_color.a = 0.5
	mat.emission_enabled = true
	mat.emission = SYNAPSE_TEAL * 0.3
	mat.emission_energy_multiplier = 0.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	_door.add_child(mesh)
	add_child(_door)

func _on_activated() -> void:
	var engine = get_node_or_null("/root/GlobEngine")
	if engine and engine.has_signal("targets_matched"):
		engine.targets_matched.connect(_on_targets_matched)

func _on_targets_matched(targets: Array[Node]) -> void:
	if state != PuzzleState.ACTIVE:
		return

	var engine = get_node_or_null("/root/GlobEngine")
	if not engine:
		return

	# Check for the recursive pattern match
	var results = engine.match_pattern(required_pattern)
	if results.size() >= target_count:
		solve()

func _on_solved() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ RECURSION COMPLETE ]\n$ glob -r %s\nFound it.\n// You actually did it. Respect." % required_pattern
		_puzzle_label.modulate = Color(0.4, 1.0, 0.4)

	# Flash all file glow indicators green
	for fnode in _file_nodes:
		var fglow = fnode.get_node_or_null("FileGlow")
		if fglow and fglow.material_override:
			fglow.material_override.emission = NEON_GREEN
			fglow.material_override.emission_energy_multiplier = 2.0

	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ PATTERN NOT FOUND ]\n$ glob -r %s\nNo match.\n// Dig deeper." % required_pattern
		_puzzle_label.modulate = Color(1.0, 0.3, 0.2)

func _on_reset() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ RECURSIVE GLOB CHALLENGE ]\n$ glob -r %s\n%s\n// OPTIONAL — for the truly stubborn" % [
			required_pattern, hint_text]
		_puzzle_label.modulate = Color(1.0, 0.85, 0.2)
	# Reset file glow indicators
	for fnode in _file_nodes:
		var fglow = fnode.get_node_or_null("FileGlow")
		if fglow and fglow.material_override:
			fglow.material_override.emission = SYNAPSE_TEAL * 0.15
			fglow.material_override.emission_energy_multiplier = 0.2
