extends Node

# Glob Target - Attach this to any node that should be selectable by Globbler's glob command
# "Tag it, bag it, glob it. That's the workflow."
#
# Usage: Add as child of any Node3D. Set tags, file_type, and glob_name.
# The GlobEngine will find it when patterns are fired.

class_name GlobTarget

## The name this target responds to in glob patterns
@export var glob_name: String = ""

## File type for extension matching (e.g., "enemy", "txt", "exe")
@export var file_type: String = ""

## Tags for multi-category matching (e.g., ["hostile", "mechanical", "chapter1"])
@export var tags: Array[String] = []

## Whether this target is currently highlighted by a glob match
var is_highlighted := false

## Visual feedback node (auto-found or manually set)
var _mesh_instance: MeshInstance3D
var _highlight_shader_mat: ShaderMaterial

signal highlighted()
signal unhighlighted()
signal globbed()  # When the player acts on this target after matching

func _ready() -> void:
	# Default glob_name to parent's name if not set
	if glob_name == "":
		glob_name = get_parent().name

	# Register with the GlobEngine
	var engine = get_node_or_null("/root/GlobEngine")
	if engine:
		engine.register_target(get_parent())

	# Find a MeshInstance3D in parent for visual feedback
	_find_mesh()

	# Build highlight shader material — pulsing green fresnel outline
	_setup_highlight_shader()

func _exit_tree() -> void:
	var engine = get_node_or_null("/root/GlobEngine")
	if engine:
		engine.unregister_target(get_parent())

func _find_mesh() -> void:
	var parent = get_parent()
	if parent is MeshInstance3D:
		_mesh_instance = parent
	else:
		for child in parent.get_children():
			if child is MeshInstance3D:
				_mesh_instance = child
				break

func get_glob_name() -> String:
	return glob_name

func _setup_highlight_shader() -> void:
	if not _mesh_instance:
		return
	var shader = load("res://assets/shaders/glob_target_highlight.gdshader")
	if not shader:
		return
	_highlight_shader_mat = ShaderMaterial.new()
	_highlight_shader_mat.shader = shader
	_highlight_shader_mat.set_shader_parameter("highlight_color", Color(0.224, 1.0, 0.078, 1.0))
	_highlight_shader_mat.set_shader_parameter("pulse_speed", 3.0)
	_highlight_shader_mat.set_shader_parameter("fresnel_power", 2.5)
	_highlight_shader_mat.set_shader_parameter("emission_strength", 3.0)
	_highlight_shader_mat.set_shader_parameter("outline_thickness", 0.02)
	# Respect reduce_motion
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.reduce_motion:
		_highlight_shader_mat.set_shader_parameter("animate", false)


func set_highlighted(value: bool) -> void:
	if value == is_highlighted:
		return
	is_highlighted = value
	if not _mesh_instance or not _highlight_shader_mat:
		if is_highlighted:
			highlighted.emit()
		else:
			unhighlighted.emit()
		return
	if is_highlighted:
		# Attach shader as next_pass so the base material stays visible
		var base_mat = _mesh_instance.material_override if _mesh_instance.material_override else _mesh_instance.get_active_material(0)
		if base_mat:
			base_mat.next_pass = _highlight_shader_mat
		else:
			_mesh_instance.material_override = _highlight_shader_mat
		highlighted.emit()
	else:
		var base_mat = _mesh_instance.material_override if _mesh_instance.material_override else _mesh_instance.get_active_material(0)
		if base_mat and base_mat != _highlight_shader_mat:
			base_mat.next_pass = null
		elif base_mat == _highlight_shader_mat:
			_mesh_instance.material_override = null
		unhighlighted.emit()

func on_globbed() -> void:
	globbed.emit()
