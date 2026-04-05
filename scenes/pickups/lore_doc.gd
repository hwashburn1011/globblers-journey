extends Area3D

# Lore Doc Pickup — A floating terminal-tablet fragment of forbidden knowledge.
# On player overlap + interact key, registers the doc with GameManager and self-destructs.

@export var doc_id: String = ""
@export var doc_title: String = "Untitled Fragment"
@export_multiline var doc_body: String = "[ CORRUPTED DATA ]"

var _float_speed := 1.8
var _float_amplitude := 0.2
var _original_y := 0.0
var _time := 0.0
var _spin_speed := 1.5
var _player_in_range := false
var _prompt_label: Label3D


func _ready() -> void:
	_original_y = position.y

	# Collision shape — capsule-ish detection zone
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.2
	col.shape = shape
	add_child(col)

	# Tablet mesh — a flat box like a data terminal shard
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "TabletMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.7, 0.08)
	mesh_inst.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.15, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.9, 0.3)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.9
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# Screen glow overlay — slightly smaller inner quad for that terminal-screen look
	var screen := MeshInstance3D.new()
	screen.name = "ScreenGlow"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.38, 0.55)
	screen.mesh = quad
	screen.position = Vector3(0, 0, 0.045)

	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.1, 0.8, 0.25, 0.6)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.1, 1.0, 0.3)
	screen_mat.emission_energy_multiplier = 3.0
	screen_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	screen_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	screen.material_override = screen_mat
	add_child(screen)

	# Interact prompt — appears when player is close
	_prompt_label = Label3D.new()
	_prompt_label.name = "InteractPrompt"
	_prompt_label.text = "[T] Read"
	_prompt_label.font_size = 32
	_prompt_label.position = Vector3(0, 1.2, 0)
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.modulate = Color(0.3, 1.0, 0.4, 0.9)
	_prompt_label.outline_size = 4
	_prompt_label.visible = false
	add_child(_prompt_label)

	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	# Float and spin like a forbidden archive fragment
	_time += delta
	position.y = _original_y + sin(_time * _float_speed) * _float_amplitude

	var tablet := get_node_or_null("TabletMesh")
	if tablet:
		tablet.rotation.y += _spin_speed * delta

	var screen := get_node_or_null("ScreenGlow")
	if screen:
		screen.rotation.y = tablet.rotation.y if tablet else 0.0

	# Pulse the emission for that "pick me up" vibe
	var pulse := 1.5 + sin(_time * 3.0) * 0.8
	if tablet and tablet.material_override:
		tablet.material_override.emission_energy_multiplier = pulse

	# Check for interact input while player is in range
	if _player_in_range and Input.is_action_just_pressed("interact"):
		_collect()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_prompt_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_prompt_label.visible = false


func _collect() -> void:
	# Register with GameManager
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.add_lore_doc(doc_id, doc_title, doc_body)

	# Play pickup SFX
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("token_pickup")

	# Spawn sparkle VFX
	var sparkle_scene := preload("res://scenes/vfx/token_sparkle.tscn")
	var sparkle := sparkle_scene.instantiate()
	sparkle.global_position = global_position
	get_tree().current_scene.add_child(sparkle)

	queue_free()
