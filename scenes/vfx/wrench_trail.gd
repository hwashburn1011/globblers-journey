extends MeshInstance3D

## Ribbon trail that follows wrench tip during swing.
## Tracks base/tip positions each frame, builds a quad-strip mesh.

const MAX_POINTS := 12
const TRAIL_LIFETIME := 0.15

var _points_base: Array[Vector3] = []
var _points_tip: Array[Vector3] = []
var _ages: Array[float] = []
var _active := false
var _immediate_mesh: ImmediateMesh

func _ready() -> void:
	_immediate_mesh = ImmediateMesh.new()
	mesh = _immediate_mesh
	# Material
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/wrench_trail.gdshader")
	material_override = mat
	# Trail renders in world space
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func start_trail() -> void:
	_points_base.clear()
	_points_tip.clear()
	_ages.clear()
	_active = true
	visible = true

func stop_trail() -> void:
	_active = false

func add_point(base_pos: Vector3, tip_pos: Vector3) -> void:
	if not _active:
		return
	_points_base.push_front(base_pos)
	_points_tip.push_front(tip_pos)
	_ages.push_front(0.0)
	# Cap length
	while _points_base.size() > MAX_POINTS:
		_points_base.pop_back()
		_points_tip.pop_back()
		_ages.pop_back()

func _process(delta: float) -> void:
	# Age out old points
	var i := _ages.size() - 1
	while i >= 0:
		_ages[i] += delta
		if _ages[i] > TRAIL_LIFETIME:
			_points_base.remove_at(i)
			_points_tip.remove_at(i)
			_ages.remove_at(i)
		i -= 1

	_rebuild_mesh()

	if not _active and _points_base.is_empty():
		visible = false

func _rebuild_mesh() -> void:
	_immediate_mesh.clear_surfaces()
	if _points_base.size() < 2:
		return

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var count := _points_base.size()
	for idx in range(count):
		var t := float(idx) / float(count - 1)  # 0=newest, 1=oldest
		# UV.x = age ratio (0 newest, 1 oldest), UV.y = 0 base, 1 tip
		_immediate_mesh.surface_set_uv(Vector2(t, 0.0))
		_immediate_mesh.surface_add_vertex(_points_base[idx])
		_immediate_mesh.surface_set_uv(Vector2(t, 1.0))
		_immediate_mesh.surface_add_vertex(_points_tip[idx])
	_immediate_mesh.surface_end()
