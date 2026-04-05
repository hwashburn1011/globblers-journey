extends Node

# Hackable Component - Makes any node hackable via Globbler's terminal arm
# "sudo make me_a_sandwich. ACCESS GRANTED."

class_name Hackable

enum HackState { LOCKED, AVAILABLE, HACKING, HACKED, FAILED }

@export var hack_difficulty: int = 1  # 1-5, affects minigame
@export var interaction_range: float = 3.0
@export var hack_prompt: String = "Press F to hack"
@export var success_message: String = "ACCESS GRANTED"
@export var failure_message: String = "ACCESS DENIED"

var state: HackState = HackState.LOCKED

# Beacon visuals
var _beacon_beam: MeshInstance3D = null
var _beacon_ring: MeshInstance3D = null
var _beacon_visible := false
var _beacon_fade := 0.0  # 0=hidden, 1=fully visible
var _beam_mat: ShaderMaterial = null
var _ring_mat: ShaderMaterial = null
var _reduce_motion := false

signal hack_started()
signal hack_completed()
signal hack_failed()
signal state_changed(new_state: HackState)

func _ready() -> void:
	state = HackState.AVAILABLE
	var gm = get_node_or_null("/root/GameManager")
	if gm and "reduce_motion" in gm:
		_reduce_motion = gm.reduce_motion
	call_deferred("_create_beacon")

func _create_beacon() -> void:
	var parent = get_parent()
	if not parent is Node3D:
		return

	var beacon_shader = load("res://assets/shaders/hackable_beacon.gdshader")
	if not beacon_shader:
		return

	# Vertical beam — tall thin quad
	_beacon_beam = MeshInstance3D.new()
	_beacon_beam.name = "HackBeacon_Beam"
	var beam_mesh = QuadMesh.new()
	beam_mesh.size = Vector2(0.4, 3.0)
	_beacon_beam.mesh = beam_mesh
	_beacon_beam.position = Vector3(0, 1.5, 0)  # centered above terminal
	_beacon_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = beacon_shader
	_beam_mat.set_shader_parameter("is_ring", false)
	_beam_mat.set_shader_parameter("proximity_fade", 0.0)
	_beam_mat.set_shader_parameter("animate", not _reduce_motion)
	_beacon_beam.material_override = _beam_mat
	_beacon_beam.visible = false
	parent.add_child(_beacon_beam)

	# Ground ring — flat horizontal disc
	_beacon_ring = MeshInstance3D.new()
	_beacon_ring.name = "HackBeacon_Ring"
	var ring_mesh = QuadMesh.new()
	ring_mesh.size = Vector2(2.0, 2.0)
	_beacon_ring.mesh = ring_mesh
	_beacon_ring.position = Vector3(0, 0.05, 0)  # just above ground
	_beacon_ring.rotation_degrees = Vector3(-90, 0, 0)  # lay flat
	_beacon_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = beacon_shader
	_ring_mat.set_shader_parameter("is_ring", true)
	_ring_mat.set_shader_parameter("proximity_fade", 0.0)
	_ring_mat.set_shader_parameter("animate", not _reduce_motion)
	_beacon_ring.material_override = _ring_mat
	_beacon_ring.visible = false
	parent.add_child(_beacon_ring)

func _process(delta: float) -> void:
	if not _beacon_beam or not _beacon_ring:
		return
	if state == HackState.HACKED:
		# Fade out after hacked
		_beacon_fade = move_toward(_beacon_fade, 0.0, delta * 2.0)
		if _beacon_fade <= 0.0:
			_beacon_beam.visible = false
			_beacon_ring.visible = false
			set_process(false)
		else:
			_beam_mat.set_shader_parameter("proximity_fade", _beacon_fade)
			_ring_mat.set_shader_parameter("proximity_fade", _beacon_fade)
		return

	# Check player proximity
	var player = _find_player()
	if player and state == HackState.AVAILABLE:
		var parent = get_parent()
		if parent is Node3D:
			var dist = player.global_position.distance_to((parent as Node3D).global_position)
			_beacon_visible = dist <= interaction_range * 1.5
	else:
		_beacon_visible = false

	# Smooth fade
	var target = 1.0 if _beacon_visible else 0.0
	_beacon_fade = move_toward(_beacon_fade, target, delta * 3.0)

	if _beacon_fade > 0.001:
		_beacon_beam.visible = true
		_beacon_ring.visible = true
		_beam_mat.set_shader_parameter("proximity_fade", _beacon_fade)
		_ring_mat.set_shader_parameter("proximity_fade", _beacon_fade)
	else:
		_beacon_beam.visible = false
		_beacon_ring.visible = false

var _player_cache: CharacterBody3D = null
var _player_scan_timer := 0.0

func _find_player() -> CharacterBody3D:
	if is_instance_valid(_player_cache):
		return _player_cache
	_player_scan_timer += get_process_delta_time()
	if _player_scan_timer < 0.5:
		return null
	_player_scan_timer = 0.0
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is CharacterBody3D:
		_player_cache = players[0] as CharacterBody3D
		return _player_cache
	return null

func start_hack() -> void:
	if state != HackState.AVAILABLE:
		return
	state = HackState.HACKING
	state_changed.emit(state)
	hack_started.emit()

func complete_hack() -> void:
	state = HackState.HACKED
	state_changed.emit(state)
	hack_completed.emit()
	print("[HACK] %s — %s" % [get_parent().name, success_message])

func fail_hack() -> void:
	state = HackState.FAILED
	state_changed.emit(state)
	hack_failed.emit()
	print("[HACK] %s — %s" % [get_parent().name, failure_message])
	# Reset to available after a delay
	get_tree().create_timer(2.0).timeout.connect(func():
		state = HackState.AVAILABLE
		state_changed.emit(state)
	)

func is_hackable() -> bool:
	return state == HackState.AVAILABLE

func is_hacked() -> bool:
	return state == HackState.HACKED
