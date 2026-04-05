class_name BossIntroCamera
extends Node3D

# Boss intro cinematic: 3-second orbital sweep around the boss, then hand back to player camera.
# Usage: BossIntroCamera.play(boss_node, callable_on_complete)

var _camera: Camera3D
var _boss_pos: Vector3
var _orbit_radius: float
var _orbit_height: float
var _elapsed := 0.0
var _duration := 3.0
var _start_angle: float
var _on_complete: Callable
var _player_camera: Camera3D

static func play(boss: Node3D, on_complete: Callable) -> void:
	var gm = boss.get_node_or_null("/root/GameManager")
	if gm and gm.reduce_motion:
		# Skip cinematic entirely for reduce_motion users
		on_complete.call()
		return

	var intro = BossIntroCamera.new()
	intro._boss_pos = boss.global_position
	intro._on_complete = on_complete
	boss.get_tree().current_scene.add_child(intro)
	intro._start(boss)

func _start(boss: Node3D) -> void:
	# Find and store the current player camera
	_player_camera = get_viewport().get_camera_3d()

	# Calculate orbit parameters based on boss size
	var boss_height := 4.0
	for child in boss.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			boss_height = child.shape.height
			break
	_orbit_radius = boss_height * 1.8
	_orbit_height = boss_height * 0.6

	# Start angle: from player camera direction
	if _player_camera:
		var dir = _player_camera.global_position - _boss_pos
		_start_angle = atan2(dir.x, dir.z)
	else:
		_start_angle = 0.0

	# Create cinematic camera
	_camera = Camera3D.new()
	_camera.name = "BossIntroCamera"
	_camera.fov = 50.0
	_camera.near = 0.1
	_camera.far = 500.0
	add_child(_camera)
	_update_camera_position(0.0)
	_camera.make_current()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		_finish()
		return
	var t = _elapsed / _duration
	_update_camera_position(t)

func _update_camera_position(t: float) -> void:
	# Sweep 270 degrees around the boss with slight zoom-in
	var angle = _start_angle + t * PI * 1.5
	var radius = _orbit_radius * (1.0 - t * 0.2)  # Slight zoom in
	var height = _boss_pos.y + _orbit_height * (1.0 + (1.0 - t) * 0.3)

	_camera.global_position = Vector3(
		_boss_pos.x + cos(angle) * radius,
		height,
		_boss_pos.z + sin(angle) * radius
	)
	_camera.look_at(_boss_pos + Vector3.UP * _orbit_height * 0.5)

func _finish() -> void:
	if _player_camera:
		_player_camera.make_current()
	_on_complete.call()
	queue_free()
