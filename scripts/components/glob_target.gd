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
var _glow_overlay: MeshInstance3D  # Additive glow shell — the "you've been selected" aura

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

	# Build glow overlay — additive shell that pulses around the mesh
	_setup_glow_overlay()

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

func _setup_glow_overlay() -> void:
	# Pulsing green glow shell — the "I see you" effect
	if not _mesh_instance or not _mesh_instance.mesh:
		return

	_glow_overlay = MeshInstance3D.new()
	_glow_overlay.name = "GlowOverlay"
	_glow_overlay.mesh = _mesh_instance.mesh  # Same shape, different destiny
	_glow_overlay.position = _mesh_instance.position
	_glow_overlay.rotation = _mesh_instance.rotation
	_glow_overlay.scale = _mesh_instance.scale * 1.05  # Slightly larger for halo effect

	var glow_shader = load("res://assets/shaders/green_glow.gdshader")
	if glow_shader:
		var glow_mat = ShaderMaterial.new()
		glow_mat.shader = glow_shader
		glow_mat.set_shader_parameter("glow_color", Color(0.224, 1.0, 0.078, 0.8))
		glow_mat.set_shader_parameter("pulse_speed", 2.5)
		glow_mat.set_shader_parameter("fresnel_power", 2.0)
		glow_mat.set_shader_parameter("glow_intensity", 2.0)
		_glow_overlay.material_override = glow_mat

	_glow_overlay.visible = false
	get_parent().add_child.call_deferred(_glow_overlay)


func set_highlighted(value: bool) -> void:
	if value == is_highlighted:
		return
	is_highlighted = value
	if is_highlighted:
		if _mesh_instance:
			_mesh_instance.material_override = _highlight_material
		if _glow_overlay:
			_glow_overlay.visible = true
		highlighted.emit()
	else:
		if _mesh_instance:
			_mesh_instance.material_override = _original_material
		if _glow_overlay:
			_glow_overlay.visible = false
		unhighlighted.emit()

func on_globbed() -> void:
	globbed.emit()
