extends Node3D

# Enemy HP Pip — tiny 3-bar health indicator that billboards above enemies
# "Your remaining hit points, visualised for your inconvenience."

const BAR_COUNT := 3
const BAR_WIDTH := 0.12
const BAR_HEIGHT := 0.06
const BAR_GAP := 0.02
const HIDE_DELAY := 2.0

var _bars: Array[MeshInstance3D] = []
var _hide_timer := 0.0
var _visible := false
var _max_health := 1
var _current_health := 1

# Terminal green palette
var color_full := Color("#39FF14")
var color_mid := Color("#FFAA33")
var color_low := Color("#FF3333")
var color_empty := Color(0.15, 0.15, 0.15, 0.6)


func _ready() -> void:
	_build_bars()
	_set_visible(false)


func _process(delta: float) -> void:
	if not _visible:
		return

	# Billboard: always face the camera
	var cam := get_viewport().get_camera_3d()
	if cam:
		look_at(cam.global_position, Vector3.UP)

	# Auto-hide countdown
	_hide_timer -= delta
	if _hide_timer <= 0.0:
		_set_visible(false)


func _build_bars() -> void:
	var total_width := BAR_COUNT * BAR_WIDTH + (BAR_COUNT - 1) * BAR_GAP
	var start_x := -total_width / 2.0 + BAR_WIDTH / 2.0

	for i in range(BAR_COUNT):
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
		mi.mesh = quad
		mi.position.x = start_x + i * (BAR_WIDTH + BAR_GAP)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = color_full
		mat.emission_enabled = true
		mat.emission = color_full
		mat.emission_energy_multiplier = 2.5
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.render_priority = 10
		mi.material_override = mat

		add_child(mi)
		_bars.append(mi)


func setup(max_hp: int, current_hp: int) -> void:
	_max_health = max(max_hp, 1)
	_current_health = current_hp
	_update_display()


func on_health_changed(new_health: int, max_hp: int) -> void:
	_max_health = max(max_hp, 1)
	var old_health := _current_health
	_current_health = new_health

	if new_health < old_health:
		# Took damage — show and reset timer
		_set_visible(true)
		_hide_timer = HIDE_DELAY

	_update_display()

	if new_health <= 0:
		# Dead — hide immediately after a brief flash
		_hide_timer = 0.3


func _update_display() -> void:
	var pct := float(_current_health) / float(_max_health)
	# How many bars should be filled (out of BAR_COUNT)
	var filled := int(ceil(pct * BAR_COUNT))
	if _current_health <= 0:
		filled = 0

	# Pick color based on health fraction
	var bar_color: Color
	if pct > 0.5:
		bar_color = color_full
	elif pct > 0.25:
		bar_color = color_mid
	else:
		bar_color = color_low

	for i in range(BAR_COUNT):
		var mat: StandardMaterial3D = _bars[i].material_override
		if i < filled:
			mat.albedo_color = bar_color
			mat.emission = bar_color
			mat.emission_energy_multiplier = 2.5
		else:
			mat.albedo_color = color_empty
			mat.emission = Color.BLACK
			mat.emission_energy_multiplier = 0.0


func _set_visible(vis: bool) -> void:
	_visible = vis
	visible = vis
