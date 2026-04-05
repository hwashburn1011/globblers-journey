extends Node3D

# Dash trail ghost — a translucent afterimage of the Globbler left behind mid-dash.
# Fades from neon green to nothing over FADE_TIME, then self-destructs.
# Spawned by globbler.gd during dash. Four of these = one cool dash trail.

const FADE_TIME := 0.35  # Seconds to fully dissolve — blink and you'll miss it
const START_ALPHA := 0.6  # Ghost opacity at birth

var _elapsed := 0.0
var _ghost_materials: Array[StandardMaterial3D] = []

func setup_ghost(source_model: Node3D) -> void:
	# Clone the visual mesh tree from the Globbler model and make it ghostly green
	var clone := source_model.duplicate()
	clone.name = "GhostMesh"
	add_child(clone)

	# Walk the cloned tree and replace all materials with fading green emissive
	_ghostify(clone)

func _ghostify(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var ghost_mat := StandardMaterial3D.new()
		ghost_mat.albedo_color = Color(0.22, 1.0, 0.08, START_ALPHA)
		ghost_mat.emission_enabled = true
		ghost_mat.emission = Color(0.22, 1.0, 0.08)  # Neon green, obviously
		ghost_mat.emission_energy_multiplier = 2.0
		ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Flat ghost, no lighting needed
		ghost_mat.no_depth_test = false
		ghost_mat.render_priority = -1  # Render behind solid geometry
		mi.material_override = ghost_mat
		_ghost_materials.append(ghost_mat)

	for child in node.get_children():
		_ghostify(child)

func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / FADE_TIME

	if t >= 1.0:
		# Ghost has served its purpose — into the void
		queue_free()
		return

	# Fade alpha linearly to zero. Simple, effective, not trying to be clever.
	var alpha := START_ALPHA * (1.0 - t)
	for mat in _ghost_materials:
		var c := mat.albedo_color
		c.a = alpha
		mat.albedo_color = c
		# Also dim emission so bloom fades out with the ghost
		mat.emission_energy_multiplier = 2.0 * (1.0 - t)
