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
var _original_material: Material
var _highlight_material: StandardMaterial3D

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

	# Create highlight material — neon green, because of course
	_highlight_material = StandardMaterial3D.new()
	_highlight_material.albedo_color = Color(0.22, 1.0, 0.08, 0.9)
	_highlight_material.emission_enabled = true
	_highlight_material.emission = Color(0.22, 1.0, 0.08)
	_highlight_material.emission_energy_multiplier = 3.0

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
	if _mesh_instance:
		_original_material = _mesh_instance.material_override

func get_glob_name() -> String:
	return glob_name

func set_highlighted(value: bool) -> void:
	if value == is_highlighted:
		return
	is_highlighted = value
	if is_highlighted:
		if _mesh_instance:
			_mesh_instance.material_override = _highlight_material
		highlighted.emit()
	else:
		if _mesh_instance:
			_mesh_instance.material_override = _original_material
		unhighlighted.emit()

func on_globbed() -> void:
	globbed.emit()
