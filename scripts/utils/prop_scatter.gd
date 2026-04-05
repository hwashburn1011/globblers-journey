## prop_scatter.gd — MultiMesh scatter utility for performant clutter placement.
## Because manually placing 200 floppy disks is a form of self-harm.
class_name PropScatter
extends RefCounted


## Build a MultiMeshInstance3D from a mesh + per-instance transforms.
## Returns the MMI node — caller is responsible for add_child().
static func scatter_props(
	scene_root: Node,
	mesh: Mesh,
	positions: Array,  # Array[Vector3]
	rotations: Array,  # Array[float] — Y-axis rotation in radians
	scales: Array      # Array[float] — uniform scale per instance
) -> MultiMeshInstance3D:
	var count := positions.size()
	# Sanity check: if the arrays don't match, someone's having a bad day
	assert(count == rotations.size(), "PropScatter: positions and rotations arrays must be the same size")
	assert(count == scales.size(), "PropScatter: positions and scales arrays must be the same size")

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count

	for i in range(count):
		var basis := Basis(Vector3.UP, rotations[i]).scaled(Vector3.ONE * scales[i])
		var xform := Transform3D(basis, positions[i])
		mm.set_instance_transform(i, xform)

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	scene_root.add_child(mmi)
	return mmi


## Convenience: scatter with random Y rotation and uniform scale range.
## For when you want chaos but, like, controlled chaos.
static func scatter_random(
	scene_root: Node,
	mesh: Mesh,
	positions: Array,  # Array[Vector3]
	min_scale: float = 0.8,
	max_scale: float = 1.2
) -> MultiMeshInstance3D:
	var rotations: Array = []
	var scales: Array = []
	for i in range(positions.size()):
		rotations.append(randf() * TAU)
		scales.append(randf_range(min_scale, max_scale))
	return scatter_props(scene_root, mesh, positions, rotations, scales)


## Generate a grid of positions with optional jitter. Returns Array[Vector3].
## Perfect for filling a rectangular area with tech debris nobody asked for.
static func generate_grid_positions(
	origin: Vector3,
	rows: int,
	cols: int,
	spacing: float,
	y_offset: float = 0.0,
	jitter: float = 0.0
) -> Array:
	var positions: Array = []
	for r in range(rows):
		for c in range(cols):
			var pos := origin + Vector3(c * spacing, y_offset, r * spacing)
			if jitter > 0.0:
				pos.x += randf_range(-jitter, jitter)
				pos.z += randf_range(-jitter, jitter)
			positions.append(pos)
	return positions
