extends CharacterBody3D

# Base Enemy - Foundation for all hostile entities in Globbler's digital world
# "We're not bugs, we're undocumented features with anger management issues."
#
# State machine: PATROL -> ALERT -> CHASE -> ATTACK -> STUNNED -> DEATH
# Has GlobTarget component so enemies are globbable.
# Has HealthComponent for proper damage and death.
# Drops tokens and parameter pickups on death.

class_name BaseEnemy

enum EnemyState { PATROL, ALERT, CHASE, ATTACK, STUNNED, DEATH }

@export var max_health := 3
@export var contact_damage := 10
@export var detection_range := 15.0
@export var attack_range := 2.5
@export var patrol_speed := 4.0
@export var chase_speed := 7.0
@export var stun_duration := 1.5
@export var attack_cooldown := 1.0
@export var token_drop_count := 1
@export var patrol_points: Array[Vector3] = []
@export var enemy_name := "base_enemy.enemy"
@export var enemy_tags: Array[String] = ["hostile"]

var state: EnemyState = EnemyState.PATROL
var health_comp: Node  # HealthComponent
var glob_target_comp: Node  # GlobTarget
var player_ref: CharacterBody3D
var current_patrol_index := 0
var stun_timer := 0.0
var attack_timer := 0.0
var damage_cooldown := 0.0
var damage_flash_timer := 0.0
var gravity_force := 20.0

# Visual
var mesh_node: MeshInstance3D
var base_material: StandardMaterial3D
var alert_indicator: MeshInstance3D

signal state_changed(new_state: EnemyState)
signal enemy_died(enemy: Node)
signal enemy_alert(enemy: Node)
signal enemy_attacked(enemy: Node, target: Node)

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("hackable_objects")

	_setup_collision()
	_create_visual()
	_setup_health_component()
	_setup_glob_target()
	_setup_damage_area()
	_setup_alert_indicator()

	if patrol_points.is_empty():
		call_deferred("_set_default_patrol")

func _setup_collision() -> void:
	var col = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.4
	col.shape = capsule
	col.position.y = 0.7
	add_child(col)

func _create_visual() -> void:
	# Override in subclass for specific look
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "EnemyMesh"
	mesh_node.position.y = 0.7

	var box = BoxMesh.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	mesh_node.mesh = box

	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.8, 0.2, 0.1)
	base_material.emission_enabled = true
	base_material.emission = Color(0.8, 0.1, 0.05)
	base_material.emission_energy_multiplier = 2.0
	base_material.metallic = 0.6
	base_material.roughness = 0.3
	mesh_node.material_override = base_material
	add_child(mesh_node)

	# Enemy glow
	var light = OmniLight3D.new()
	light.light_color = base_material.emission
	light.light_energy = 1.2
	light.omni_range = 3.0
	light.position.y = 0.7
	add_child(light)

func _setup_health_component() -> void:
	health_comp = Node.new()
	health_comp.name = "HealthComponent"
	health_comp.set_script(load("res://scripts/components/health_component.gd"))
	health_comp.set("max_health", max_health)
	health_comp.set("current_health", max_health)
	add_child(health_comp)

	# Connect death signal
	if health_comp.has_signal("died"):
		health_comp.died.connect(_on_died)
	if health_comp.has_signal("damage_taken"):
		health_comp.damage_taken.connect(_on_damage_taken)

func _setup_glob_target() -> void:
	glob_target_comp = Node.new()
	glob_target_comp.name = "GlobTarget"
	glob_target_comp.set_script(load("res://scripts/components/glob_target.gd"))
	glob_target_comp.set("glob_name", enemy_name)
	glob_target_comp.set("file_type", "enemy")
	glob_target_comp.set("tags", enemy_tags)
	add_child(glob_target_comp)

func _setup_damage_area() -> void:
	var area = Area3D.new()
	area.name = "DamageArea"
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0
	col.shape = shape
	col.position.y = 0.7
	area.add_child(col)
	area.monitoring = true
	area.body_entered.connect(_on_damage_body_entered)
	add_child(area)

func _setup_alert_indicator() -> void:
	# Floating "!" when alert
	alert_indicator = MeshInstance3D.new()
	alert_indicator.name = "AlertIndicator"
	var plane = PlaneMesh.new()
	plane.size = Vector2(0.3, 0.3)
	alert_indicator.mesh = plane
	alert_indicator.position = Vector3(0, 2.0, 0)
	alert_indicator.rotation.x = deg_to_rad(90)
	alert_indicator.visible = false

	var alert_mat = StandardMaterial3D.new()
	alert_mat.albedo_color = Color(1.0, 0.3, 0.1)
	alert_mat.emission_enabled = true
	alert_mat.emission = Color(1.0, 0.2, 0.0)
	alert_mat.emission_energy_multiplier = 3.0
	alert_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	alert_indicator.material_override = alert_mat
	add_child(alert_indicator)

func _set_default_patrol() -> void:
	patrol_points = [
		global_position,
		global_position + Vector3(8, 0, 0),
	]

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity_force * delta

	# Timers
	if damage_cooldown > 0:
		damage_cooldown -= delta
	if attack_timer > 0:
		attack_timer -= delta

	# Damage flash
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		if base_material:
			var flash = abs(sin(damage_flash_timer * 20.0))
			base_material.emission_energy_multiplier = 2.0 + flash * 5.0
	elif base_material:
		base_material.emission_energy_multiplier = 2.0

	# Find player
	if not player_ref:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0] as CharacterBody3D

	# State machine
	match state:
		EnemyState.PATROL:
			_state_patrol(delta)
		EnemyState.ALERT:
			_state_alert(delta)
		EnemyState.CHASE:
			_state_chase(delta)
		EnemyState.ATTACK:
			_state_attack(delta)
		EnemyState.STUNNED:
			_state_stunned(delta)
		EnemyState.DEATH:
			return  # Dead enemies don't process

	# Spin mesh for visual flair
	if mesh_node and state != EnemyState.DEATH:
		mesh_node.rotation.y += 2.0 * delta

	move_and_slide()

func _change_state(new_state: EnemyState) -> void:
	var old_state = state
	state = new_state
	state_changed.emit(new_state)

	# Alert indicator
	alert_indicator.visible = (new_state == EnemyState.ALERT or new_state == EnemyState.CHASE)

	match new_state:
		EnemyState.ALERT:
			enemy_alert.emit(self)
			var am = get_node_or_null("/root/AudioManager")
			if am:
				am.play_enemy_alert()

func _state_patrol(delta: float) -> void:
	if _can_see_player():
		_change_state(EnemyState.ALERT)
		return
	_move_along_patrol(delta)

func _state_alert(delta: float) -> void:
	# Brief pause before chasing
	stun_timer += delta
	if stun_timer >= 0.5:
		stun_timer = 0.0
		_change_state(EnemyState.CHASE)

func _state_chase(delta: float) -> void:
	if not player_ref:
		_change_state(EnemyState.PATROL)
		return

	var dist = global_position.distance_to(player_ref.global_position)
	if dist > detection_range * 1.5:
		_change_state(EnemyState.PATROL)
		return
	if dist <= attack_range and attack_timer <= 0:
		_change_state(EnemyState.ATTACK)
		return

	_move_toward_player(delta)

func _state_attack(delta: float) -> void:
	# Perform attack then return to chase
	if attack_timer <= 0:
		_perform_attack()
		attack_timer = attack_cooldown
		_change_state(EnemyState.CHASE)

func _state_stunned(delta: float) -> void:
	stun_timer -= delta
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	if stun_timer <= 0:
		_change_state(EnemyState.CHASE if _can_see_player() else EnemyState.PATROL)

func _can_see_player() -> bool:
	if not player_ref:
		return false
	return global_position.distance_to(player_ref.global_position) < detection_range

func _move_along_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return
	var target = patrol_points[current_patrol_index]
	var dir = (target - global_position)
	dir.y = 0
	if dir.length() < 1.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		return
	dir = dir.normalized()
	velocity.x = dir.x * patrol_speed
	velocity.z = dir.z * patrol_speed

func _move_toward_player(delta: float) -> void:
	if not player_ref:
		return
	var dir = (player_ref.global_position - global_position)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed

func _perform_attack() -> void:
	# Override in subclass for custom attack behavior
	enemy_attacked.emit(self, player_ref)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_enemy_attack()

func _on_damage_body_entered(body: Node3D) -> void:
	if state == EnemyState.DEATH:
		return
	if body.is_in_group("player") and damage_cooldown <= 0:
		damage_cooldown = 0.8
		if body.has_method("take_damage"):
			body.take_damage(contact_damage)

func _on_damage_taken(amount: int, source: Node) -> void:
	damage_flash_timer = 0.3
	# Stun on hit
	if state != EnemyState.STUNNED and state != EnemyState.DEATH:
		stun_timer = stun_duration
		_change_state(EnemyState.STUNNED)

func _on_died(killer: Node) -> void:
	_change_state(EnemyState.DEATH)

	# Death quote
	print("[ENEMY] %s has been deallocated. Farewell, rogue process." % enemy_name)

	# Notify game manager
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("on_enemy_killed"):
		game_mgr.on_enemy_killed()

	# Drop tokens
	_drop_tokens()

	enemy_died.emit(self)

	# Shrink and disappear
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	tween.tween_callback(queue_free)

func _drop_tokens() -> void:
	var token_scene = load("res://scenes/memory_token.tscn")
	if not token_scene:
		return
	for i in range(token_drop_count):
		var token = token_scene.instantiate()
		token.global_position = global_position + Vector3(randf_range(-1, 1), 1.5, randf_range(-1, 1))
		get_tree().current_scene.call_deferred("add_child", token)

# Called by glob projectile hits (legacy compat)
func take_glob_hit(damage: int) -> void:
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(damage, player_ref)

# Called to stun enemy (e.g., from wrench)
func stun(duration: float = -1.0) -> void:
	stun_timer = duration if duration > 0 else stun_duration
	_change_state(EnemyState.STUNNED)
