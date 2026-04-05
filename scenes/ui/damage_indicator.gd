extends Control

# Damage Direction Indicator — "Pain has a direction, and it's THAT way."
# Shows red chevron arcs at screen edges pointing toward the damage source.
# Falls back to nearest enemy if no explicit source is provided.

const FADE_TIME := 0.8
const CHEVRON_SIZE := 40.0
const CHEVRON_WIDTH := 6.0
const EDGE_MARGIN := 60.0
const HIT_COLOR := Color(1.0, 0.15, 0.1, 0.85)

var _indicators: Array[Dictionary] = []
var _camera: Camera3D
var _player_ref: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_FULL_RECT
	set_process(true)

	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_signal("damage_taken"):
		game_mgr.damage_taken.connect(_on_player_damaged)

func _find_player() -> Node3D:
	if is_instance_valid(_player_ref):
		return _player_ref
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0] as Node3D
	return _player_ref

func _find_nearest_enemy() -> Node3D:
	var player = _find_player()
	if not player:
		return null
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest: Node3D = null
	var closest_dist := 999999.0
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		var dist = player.global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy as Node3D
	return closest

func show_damage_from(world_pos: Vector3) -> void:
	_indicators.append({
		"world_pos": world_pos,
		"timer": FADE_TIME,
	})
	queue_redraw()

func _on_player_damaged(_amount: int) -> void:
	# Check reduce_motion
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		return

	var source = _find_nearest_enemy()
	if source and is_instance_valid(source):
		show_damage_from(source.global_position)
	else:
		# No enemy found — show a random-direction indicator as fallback
		var player = _find_player()
		if player:
			var random_offset = Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)).normalized() * 10.0
			show_damage_from(player.global_position + random_offset)

func _process(delta: float) -> void:
	if _indicators.is_empty():
		return

	var needs_redraw := false
	var i := _indicators.size() - 1
	while i >= 0:
		_indicators[i]["timer"] -= delta
		if _indicators[i]["timer"] <= 0.0:
			_indicators.remove_at(i)
		needs_redraw = true
		i -= 1

	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	if _indicators.is_empty():
		return

	_camera = get_viewport().get_camera_3d()
	if not _camera:
		return

	var player = _find_player()
	if not player:
		return

	var screen_center = size / 2.0

	for indicator in _indicators:
		var alpha = clamp(indicator["timer"] / FADE_TIME, 0.0, 1.0)
		var world_pos: Vector3 = indicator["world_pos"]

		# Get direction from player to damage source in screen space
		var player_screen = _camera.unproject_position(player.global_position)
		var source_screen = _camera.unproject_position(world_pos)

		# Check if behind camera
		if _camera.is_position_behind(world_pos):
			source_screen = screen_center + (screen_center - source_screen)

		var dir = (source_screen - screen_center).normalized()
		if dir.length_squared() < 0.001:
			dir = Vector2.UP

		# Calculate angle for the chevron
		var angle = dir.angle()

		# Position the chevron at the screen edge
		var chevron_pos = _get_edge_position(screen_center, dir)

		# Draw the chevron
		var color = HIT_COLOR
		color.a *= alpha
		_draw_chevron(chevron_pos, angle, color)

func _get_edge_position(center: Vector2, direction: Vector2) -> Vector2:
	# Cast a ray from center in direction and find where it hits the screen edge
	var half_w = size.x / 2.0 - EDGE_MARGIN
	var half_h = size.y / 2.0 - EDGE_MARGIN

	var t_min = 99999.0
	if abs(direction.x) > 0.001:
		var t = half_w / abs(direction.x)
		t_min = min(t_min, t)
	if abs(direction.y) > 0.001:
		var t = half_h / abs(direction.y)
		t_min = min(t_min, t)

	return center + direction * t_min

func _draw_chevron(pos: Vector2, angle: float, color: Color) -> void:
	# Draw a V-shaped chevron pointing outward
	var forward = Vector2.from_angle(angle)
	var perp = Vector2(-forward.y, forward.x)

	var tip = pos + forward * CHEVRON_SIZE * 0.5
	var left = pos - forward * CHEVRON_SIZE * 0.3 + perp * CHEVRON_SIZE * 0.4
	var right = pos - forward * CHEVRON_SIZE * 0.3 - perp * CHEVRON_SIZE * 0.4
	var inner_left = pos - forward * CHEVRON_SIZE * 0.05 + perp * CHEVRON_SIZE * 0.15
	var inner_right = pos - forward * CHEVRON_SIZE * 0.05 - perp * CHEVRON_SIZE * 0.15

	# Filled chevron with slight glow
	var glow_color = color
	glow_color.a *= 0.3
	var glow_points = PackedVector2Array([
		tip + forward * 4.0,
		left + perp * 4.0 - forward * 4.0,
		inner_left,
		inner_right,
		right - perp * 4.0 - forward * 4.0,
	])
	draw_colored_polygon(glow_points, glow_color)

	# Main chevron shape
	var points = PackedVector2Array([tip, left, inner_left, inner_right, right])
	draw_colored_polygon(points, color)
