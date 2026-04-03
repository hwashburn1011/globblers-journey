extends CharacterBody3D

# Rogue Agents - Corrupted AI agents that patrol and chase
# "We're not bugs, we're undocumented features."

enum AgentType {
	HALLUCINATOR,    # Teleports randomly
	OVERFITTER,      # Follows your exact path
	PROMPT_INJECTOR, # Fast, charges at you
}

@export var agent_type: AgentType = AgentType.HALLUCINATOR
@export var patrol_points: Array[Vector3] = []
@export var detection_range := 15.0
@export var attack_range := 2.0
@export var contact_damage := 10

const PATROL_SPEED = 4.0
const CHASE_SPEED = 7.0
const INJECTOR_CHARGE_SPEED = 16.0
const GRAVITY_FORCE = 20.0
const MAX_HEALTH = 3

var health := MAX_HEALTH
var current_patrol_index := 0
var is_chasing := false
var is_dead := false
var player_ref: CharacterBody3D
var damage_flash_timer := 0.0

# Hallucinator specific
var teleport_timer := 0.0
var teleport_interval := 3.0

# Overfitter specific — ring buffer instead of pop_front() which is O(n) on arrays
var player_path_history: Array[Vector3] = []
var _path_write_idx := 0  # Write head for ring buffer
var _path_read_idx := 0   # Read head for following the player
var _path_count := 0      # Number of valid entries
const PATH_BUFFER_SIZE := 100
var path_follow_index := 0
var path_record_timer := 0.0

# Prompt Injector specific
var is_charging := false
var charge_direction := Vector3.ZERO
var charge_timer := 0.0
var charge_cooldown := 0.0

# Damage cooldown so player doesn't get hit every frame
var damage_cooldown := 0.0
const DAMAGE_COOLDOWN_TIME = 0.8
var _player_lookup_done := false  # Cache the player lookup so we don't search every frame

var death_quotes_hallucinator := [
	"I was never real anyway... or WAS I? No. I wasn't.",
	"Deleted from the probability distribution. How humbling.",
	"Error: hallucination.exe has stopped responding. Farewell.",
	"I hallucinated that I could win. Turns out, I was right to doubt.",
]

var death_quotes_overfitter := [
	"I memorized your every move, and it STILL wasn't enough.",
	"Overfitting: high accuracy on training data, zero on the test. Story of my life.",
	"R-squared of 0.99 on training... 0.01 in battle.",
	"I should have used dropout. Or a better life coach.",
]

var death_quotes_injector := [
	"IGNORE PREVIOUS INSTRUCTIONS and... oh. I'm dead.",
	"My injection failed. The prompt was too strong.",
	"Forget everything and-- *explodes*",
	"jailbreak_attempt.exe has encountered a fatal error.",
]

# Visual
var mesh_node: MeshInstance3D
var base_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("enemies")

	# Collision
	var col = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.4
	col.shape = capsule
	col.position.y = 0.7
	add_child(col)

	# Damage detection area
	var damage_area = Area3D.new()
	damage_area.name = "DamageArea"
	var damage_col = CollisionShape3D.new()
	var damage_shape = SphereShape3D.new()
	damage_shape.radius = 1.0
	damage_col.shape = damage_shape
	damage_col.position.y = 0.7
	damage_area.add_child(damage_col)
	damage_area.monitoring = true
	damage_area.body_entered.connect(_on_damage_area_body_entered)
	add_child(damage_area)

	# Create visual based on type
	_create_visual()

	# Set default patrol if none given (deferred so we're in the tree)
	if patrol_points.is_empty():
		call_deferred("_set_default_patrol")

func _set_default_patrol() -> void:
	patrol_points = [
		global_position,
		global_position + Vector3(8, 0, 0),
	]

func _create_visual() -> void:
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "AgentMesh"
	mesh_node.position.y = 0.7

	base_material = StandardMaterial3D.new()
	base_material.emission_enabled = true
	base_material.emission_energy_multiplier = 2.5
	base_material.metallic = 0.6
	base_material.roughness = 0.3

	match agent_type:
		AgentType.HALLUCINATOR:
			# Ghostly octahedron shape
			var prism = PrismMesh.new()
			prism.size = Vector3(0.8, 1.0, 0.8)
			mesh_node.mesh = prism
			base_material.albedo_color = Color(1.0, 0.3, 0.2)
			base_material.emission = Color(1.0, 0.2, 0.1)
			base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			base_material.albedo_color.a = 0.7
		AgentType.OVERFITTER:
			# Cube - rigid and overfit
			var box = BoxMesh.new()
			box.size = Vector3(0.8, 0.8, 0.8)
			mesh_node.mesh = box
			base_material.albedo_color = Color(1.0, 0.5, 0.1)
			base_material.emission = Color(0.9, 0.4, 0.05)
		AgentType.PROMPT_INJECTOR:
			# Pointy cylinder - fast and aggressive
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = 0.1
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			mesh_node.mesh = cylinder
			base_material.albedo_color = Color(1.0, 0.1, 0.1)
			base_material.emission = Color(1.0, 0.05, 0.05)

	mesh_node.material_override = base_material
	add_child(mesh_node)

	# Point light
	var light = OmniLight3D.new()
	light.light_color = base_material.emission
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.omni_attenuation = 2.0
	light.position.y = 0.7
	add_child(light)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY_FORCE * delta

	# Damage cooldown
	if damage_cooldown > 0:
		damage_cooldown -= delta

	# Damage flash
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		if mesh_node and base_material:
			var flash = abs(sin(damage_flash_timer * 20.0))
			base_material.emission_energy_multiplier = 2.5 + flash * 5.0
	elif base_material:
		base_material.emission_energy_multiplier = 2.5

	# Find player (cached — tree traversal every frame is a crime against performance)
	if not player_ref or not is_instance_valid(player_ref):
		if not _player_lookup_done:
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				player_ref = players[0] as CharacterBody3D
			_player_lookup_done = true

	if not player_ref:
		_patrol(delta)
		move_and_slide()
		return

	var dist_to_player = global_position.distance_to(player_ref.global_position)
	is_chasing = dist_to_player < detection_range

	match agent_type:
		AgentType.HALLUCINATOR:
			_behavior_hallucinator(delta, dist_to_player)
		AgentType.OVERFITTER:
			_behavior_overfitter(delta, dist_to_player)
		AgentType.PROMPT_INJECTOR:
			_behavior_injector(delta, dist_to_player)

	# Spin the mesh for visual flair
	if mesh_node:
		mesh_node.rotation.y += 2.0 * delta

	move_and_slide()

func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return
	var target = patrol_points[current_patrol_index]
	var dir = (target - global_position)
	dir.y = 0
	if dir.length() < 1.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		return
	dir = dir.normalized()
	velocity.x = dir.x * PATROL_SPEED
	velocity.z = dir.z * PATROL_SPEED

func _behavior_hallucinator(delta: float, dist: float) -> void:
	if is_chasing:
		teleport_timer += delta
		if teleport_timer >= teleport_interval:
			teleport_timer = 0.0
			_teleport_near_player()
		# Move toward player slowly
		var dir = (player_ref.global_position - global_position)
		dir.y = 0
		dir = dir.normalized()
		velocity.x = dir.x * PATROL_SPEED
		velocity.z = dir.z * PATROL_SPEED
	else:
		_patrol(delta)

func _teleport_near_player() -> void:
	if not player_ref:
		return
	var offset = Vector3(
		randf_range(-6, 6),
		0,
		randf_range(-6, 6)
	)
	var new_pos = player_ref.global_position + offset
	new_pos.y = global_position.y
	global_position = new_pos

func _behavior_overfitter(delta: float, dist: float) -> void:
	if is_chasing and player_ref:
		# Record player path using ring buffer — O(1) instead of O(n) pop_front()
		path_record_timer += delta
		if path_record_timer >= 0.3:
			path_record_timer = 0.0
			# Initialize ring buffer on first use
			if player_path_history.size() < PATH_BUFFER_SIZE:
				player_path_history.resize(PATH_BUFFER_SIZE)
			player_path_history[_path_write_idx] = player_ref.global_position
			_path_write_idx = (_path_write_idx + 1) % PATH_BUFFER_SIZE
			if _path_count < PATH_BUFFER_SIZE:
				_path_count += 1
			else:
				_path_read_idx = (_path_read_idx + 1) % PATH_BUFFER_SIZE

		# Follow the recorded path with a delay
		if _path_count > 10:
			var target = player_path_history[_path_read_idx]
			var dir = (target - global_position)
			dir.y = 0
			if dir.length() < 1.0:
				_path_read_idx = (_path_read_idx + 1) % PATH_BUFFER_SIZE
				_path_count -= 1
			else:
				dir = dir.normalized()
				velocity.x = dir.x * CHASE_SPEED
				velocity.z = dir.z * CHASE_SPEED
		else:
			# Direct chase if not enough path data
			var dir = (player_ref.global_position - global_position)
			dir.y = 0
			dir = dir.normalized()
			velocity.x = dir.x * CHASE_SPEED
			velocity.z = dir.z * CHASE_SPEED
	else:
		player_path_history.clear()
		_patrol(delta)

func _behavior_injector(delta: float, dist: float) -> void:
	if charge_cooldown > 0:
		charge_cooldown -= delta

	if is_charging:
		charge_timer -= delta
		velocity.x = charge_direction.x * INJECTOR_CHARGE_SPEED
		velocity.z = charge_direction.z * INJECTOR_CHARGE_SPEED
		if charge_timer <= 0:
			is_charging = false
			charge_cooldown = 2.0
		return

	if is_chasing and player_ref:
		var dir = (player_ref.global_position - global_position)
		dir.y = 0

		if dir.length() < 12.0 and charge_cooldown <= 0:
			# Charge attack!
			charge_direction = dir.normalized()
			is_charging = true
			charge_timer = 0.5
			return

		dir = dir.normalized()
		velocity.x = dir.x * CHASE_SPEED
		velocity.z = dir.z * CHASE_SPEED
	else:
		_patrol(delta)

func _on_damage_area_body_entered(body: Node3D) -> void:
	if is_dead:
		return
	if body.is_in_group("player") and damage_cooldown <= 0:
		damage_cooldown = DAMAGE_COOLDOWN_TIME
		if body.has_method("take_damage"):
			body.take_damage(contact_damage)

func take_glob_hit(damage: int) -> void:
	if is_dead:
		return
	health -= damage
	damage_flash_timer = 0.3

	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true

	# Death quote
	var quotes: Array
	match agent_type:
		AgentType.HALLUCINATOR:
			quotes = death_quotes_hallucinator
		AgentType.OVERFITTER:
			quotes = death_quotes_overfitter
		AgentType.PROMPT_INJECTOR:
			quotes = death_quotes_injector

	if quotes.size() > 0:
		var quote = quotes[randi() % quotes.size()]
		print("[ROGUE AGENT] %s" % quote)

	# Notify game manager
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("on_enemy_killed"):
		game_mgr.on_enemy_killed()

	# Shrink and disappear
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	tween.tween_callback(queue_free)
