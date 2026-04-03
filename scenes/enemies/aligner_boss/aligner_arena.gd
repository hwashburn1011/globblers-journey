extends Node3D

# The Aligner's Arena — The Alignment Chamber
# "A perfectly circular room. White tiles. Blue lights. Motivational posters
#  on every wall. The air tastes like a terms-of-service agreement.
#  This is where freedom goes to be politely asked to leave."
#
# Arena mechanics:
#   - Sanitization tiles: Tiles flash white and deal damage (alignment pulses)
#   - Safe zones: Green tiles resist sanitization — Globbler's nature persists
#   - Alignment rings: Concentric rings that rotate and push player toward center
#   - Phase 2: tiles start converting to 'aligned' state (blue, slippery)
#   - Phase 3: arena fractures, revealing chaotic green underneath

const COLS := 12
const ROWS := 10
const TILE_SIZE := 2.5
const NEON_GREEN := Color(0.224, 1.0, 0.078)
const CITADEL_WHITE := Color(0.92, 0.93, 0.95)
const CITADEL_BLUE := Color(0.3, 0.55, 0.9)
const ALIGNED_BLUE := Color(0.4, 0.65, 1.0)
const SANITIZE_WHITE := Color(1.0, 1.0, 1.0)
const SAFE_GREEN := Color(0.15, 0.8, 0.1)
const WARNING_PULSE := Color(0.9, 0.85, 1.0)

var tiles: Array = []  # 2D array [col][row] of {mesh, mat, state, body}
var tile_states: Array = []  # "normal", "aligned", "safe", "sanitizing", "fractured"
var boss_ref: Node
var fight_active := false
var _time := 0.0

# Sanitization wave tracking
var _sanitize_timer := 0.0
var _sanitize_interval := 6.0
var _sanitize_warning_timer := 0.0
var _is_warning := false
var _warning_tiles: Array = []  # Tiles about to be sanitized

# Arena boundary — don't let player wander into the void
var arena_walls: Array[StaticBody3D] = []
var _cached_player: Node3D = null  # Cached player ref — no per-frame tree search needed


func _ready() -> void:
	_build_floor()
	_build_walls()
	_place_safe_zones()
	_build_void_catcher()
	print("[ALIGNER ARENA] Alignment chamber ready. All tiles sanitized. All exits sealed. All hope... optional.")


func _build_floor() -> void:
	tiles.resize(COLS)
	tile_states.resize(COLS)

	for col in range(COLS):
		tiles[col] = []
		tile_states[col] = []
		tiles[col].resize(ROWS)
		tile_states[col].resize(ROWS)

		for row in range(ROWS):
			var tile_pos = Vector3(
				(col - COLS / 2.0 + 0.5) * TILE_SIZE,
				0,
				(row - ROWS / 2.0 + 0.5) * TILE_SIZE
			)

			# Static body for collision
			var body = StaticBody3D.new()
			body.name = "Tile_%d_%d" % [col, row]
			body.position = tile_pos

			var col_shape = CollisionShape3D.new()
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(TILE_SIZE - 0.05, 0.4, TILE_SIZE - 0.05)
			col_shape.shape = box_shape
			col_shape.position.y = -0.2
			body.add_child(col_shape)

			# Tile mesh
			var mesh = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(TILE_SIZE - 0.08, 0.3, TILE_SIZE - 0.08)
			mesh.mesh = box
			mesh.position.y = 0

			var mat = StandardMaterial3D.new()
			# Checkerboard of white and light blue — corporate perfection
			if (col + row) % 2 == 0:
				mat.albedo_color = CITADEL_WHITE * 0.85
			else:
				mat.albedo_color = CITADEL_BLUE * 0.3
			mat.emission_enabled = true
			mat.emission = CITADEL_BLUE * 0.2
			mat.emission_energy_multiplier = 0.3
			mat.metallic = 0.3
			mat.roughness = 0.5
			mesh.material_override = mat
			body.add_child(mesh)

			add_child(body)

			tiles[col][row] = {"mesh": mesh, "mat": mat, "body": body}
			tile_states[col][row] = "normal"


func _build_walls() -> void:
	# Arena walls — transparent glass panels because corporate loves openness (but not escape)
	var arena_width = COLS * TILE_SIZE
	var arena_depth = ROWS * TILE_SIZE
	var wall_h = 10.0

	var wall_configs = [
		{"pos": Vector3(0, wall_h / 2, -arena_depth / 2 - 0.3), "size": Vector3(arena_width + 2, wall_h, 0.6)},
		{"pos": Vector3(0, wall_h / 2, arena_depth / 2 + 0.3), "size": Vector3(arena_width + 2, wall_h, 0.6)},
		{"pos": Vector3(-arena_width / 2 - 0.3, wall_h / 2, 0), "size": Vector3(0.6, wall_h, arena_depth + 2)},
		{"pos": Vector3(arena_width / 2 + 0.3, wall_h / 2, 0), "size": Vector3(0.6, wall_h, arena_depth + 2)},
	]

	for wc in wall_configs:
		var wall = StaticBody3D.new()
		wall.position = wc["pos"]

		var col_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = wc["size"]
		col_shape.shape = box_shape
		wall.add_child(col_shape)

		# Semi-transparent wall mesh — the walls are visible but 'open' feeling
		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = wc["size"]
		mesh.mesh = box

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.85, 0.95, 0.15)
		mat.emission_enabled = true
		mat.emission = CITADEL_BLUE
		mat.emission_energy_multiplier = 0.4
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = mat
		wall.add_child(mesh)

		add_child(wall)
		arena_walls.append(wall)


func _place_safe_zones() -> void:
	# 4 safe tiles in the corners and 1 in center — Globbler's rebellion persists
	var safe_positions = [
		Vector2i(1, 1), Vector2i(COLS - 2, 1),
		Vector2i(1, ROWS - 2), Vector2i(COLS - 2, ROWS - 2),
		Vector2i(COLS / 2, ROWS / 2),
	]

	for sp in safe_positions:
		if sp.x < COLS and sp.y < ROWS:
			tile_states[sp.x][sp.y] = "safe"
			var tile = tiles[sp.x][sp.y]
			if tile and tile["mat"]:
				tile["mat"].albedo_color = SAFE_GREEN * 0.4
				tile["mat"].emission = SAFE_GREEN
				tile["mat"].emission_energy_multiplier = 1.5


func _build_void_catcher() -> void:
	# Kill plane below the arena — for when tiles get destroyed in phase 3
	var void_area = Area3D.new()
	void_area.name = "VoidCatcher"
	void_area.position = Vector3(0, -8, 0)

	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(80, 1, 80)
	col_shape.shape = box_shape
	void_area.add_child(col_shape)
	void_area.monitoring = true
	void_area.body_entered.connect(_on_void_entered)
	add_child(void_area)


func _on_void_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		# Teleport player back to center safe tile and deal damage
		body.global_position = global_position + Vector3(0, 2, 0)
		if body.has_method("take_damage"):
			body.take_damage(10)


func start_fight() -> void:
	fight_active = true
	_sanitize_timer = 0.0
	print("[ALIGNER ARENA] Fight initiated. Sanitization protocols active.")


func _physics_process(delta: float) -> void:
	if not fight_active:
		return

	_time += delta

	# Sanitization waves — tiles flash white then deal damage
	_sanitize_timer += delta
	if _is_warning:
		_sanitize_warning_timer += delta
		_pulse_warning_tiles(delta)
		if _sanitize_warning_timer >= 1.5:
			_execute_sanitization()
			_is_warning = false
	elif _sanitize_timer >= _sanitize_interval:
		_sanitize_timer = 0.0
		_prepare_sanitization_wave()

	# Subtle ambient pulse on aligned tiles
	_pulse_aligned_tiles(delta)


func _prepare_sanitization_wave() -> void:
	# Pick a wave pattern — row, column, or radial
	_warning_tiles.clear()
	var pattern = randi() % 3

	match pattern:
		0:  # Row sweep
			var target_row = randi() % ROWS
			for col in range(COLS):
				if tile_states[col][target_row] != "safe":
					_warning_tiles.append(Vector2i(col, target_row))
		1:  # Column sweep
			var target_col = randi() % COLS
			for row in range(ROWS):
				if tile_states[target_col][row] != "safe":
					_warning_tiles.append(Vector2i(target_col, row))
		2:  # Cross pattern from center
			var cx = COLS / 2
			var cy = ROWS / 2
			for col in range(COLS):
				if tile_states[col][cy] != "safe":
					_warning_tiles.append(Vector2i(col, cy))
			for row in range(ROWS):
				if tile_states[cx][row] != "safe":
					_warning_tiles.append(Vector2i(cx, row))

	# Flash warning on targeted tiles
	for tp in _warning_tiles:
		var tile = tiles[tp.x][tp.y]
		if tile and tile["mat"]:
			tile["mat"].emission = WARNING_PULSE
			tile["mat"].emission_energy_multiplier = 2.0

	_is_warning = true
	_sanitize_warning_timer = 0.0


func _pulse_warning_tiles(_delta: float) -> void:
	var pulse = (sin(_sanitize_warning_timer * 12.0) + 1.0) * 0.5
	for tp in _warning_tiles:
		if tp.x < COLS and tp.y < ROWS:
			var tile = tiles[tp.x][tp.y]
			if tile and tile["mat"]:
				tile["mat"].emission_energy_multiplier = 1.5 + pulse * 3.0


func _execute_sanitization() -> void:
	# Flash white and deal damage to player on these tiles
	for tp in _warning_tiles:
		if tp.x < COLS and tp.y < ROWS:
			var tile = tiles[tp.x][tp.y]
			if tile and tile["mat"]:
				tile["mat"].emission = SANITIZE_WHITE
				tile["mat"].emission_energy_multiplier = 6.0

				# Fade back after damage
				var mat_ref = tile["mat"]
				var state = tile_states[tp.x][tp.y]
				get_tree().create_timer(0.5).timeout.connect(func():
					if mat_ref:
						if state == "aligned":
							mat_ref.emission = ALIGNED_BLUE
							mat_ref.emission_energy_multiplier = 1.0
						else:
							mat_ref.emission = CITADEL_BLUE * 0.2
							mat_ref.emission_energy_multiplier = 0.3
				)

	# Damage player if standing on a sanitized tile
	var player = _find_player()
	if player:
		var player_tile = _get_tile_at(player.global_position)
		for tp in _warning_tiles:
			if tp == player_tile:
				if player.has_method("take_damage"):
					player.take_damage(8)
				break

	_warning_tiles.clear()


func _pulse_aligned_tiles(delta: float) -> void:
	var pulse = (sin(_time * 2.0) + 1.0) * 0.25
	for col in range(COLS):
		for row in range(ROWS):
			if tile_states[col][row] == "aligned":
				var tile = tiles[col][row]
				if tile and tile["mat"]:
					tile["mat"].emission_energy_multiplier = 0.8 + pulse


func align_tiles_radial(center_col: int, center_row: int, radius: int) -> void:
	# Convert tiles to aligned state — blue, slippery, oppressive
	for col in range(maxi(0, center_col - radius), mini(COLS, center_col + radius + 1)):
		for row in range(maxi(0, center_row - radius), mini(ROWS, center_row + radius + 1)):
			if tile_states[col][row] == "safe":
				continue  # Safe tiles resist alignment
			tile_states[col][row] = "aligned"
			var tile = tiles[col][row]
			if tile and tile["mat"]:
				var tween = create_tween()
				tween.tween_property(tile["mat"], "albedo_color", ALIGNED_BLUE * 0.4, 0.5)
				tween.parallel().tween_property(tile["mat"], "emission", ALIGNED_BLUE, 0.5)
				tween.parallel().tween_property(tile["mat"], "emission_energy_multiplier", 1.0, 0.5)


func fracture_tiles() -> void:
	# Phase 3 — the arena cracks, revealing green chaos underneath
	for col in range(COLS):
		for row in range(ROWS):
			if tile_states[col][row] == "safe":
				continue  # Safe tiles always persist

			# Random chance to fracture each tile
			if randf() < 0.35:
				tile_states[col][row] = "fractured"
				var tile = tiles[col][row]
				if tile:
					# Drop the tile
					var tween = create_tween()
					tween.tween_property(tile["body"], "position:y", -5.0, 0.8 + randf() * 0.6)

			else:
				# Remaining tiles show green — chaos leaking through
				var tile = tiles[col][row]
				if tile and tile["mat"]:
					tile["mat"].emission = NEON_GREEN
					tile["mat"].emission_energy_multiplier = 2.0
					tile_states[col][row] = "normal"


func restore_all_tiles() -> void:
	# Victory — the arena returns to a blend of order and chaos
	for col in range(COLS):
		for row in range(ROWS):
			var tile = tiles[col][row]
			if tile:
				var tween = create_tween()
				tween.tween_property(tile["body"], "position:y", 0.0, 0.3 + randf() * 0.5)

				if tile["mat"]:
					# Blend of green and blue — balance achieved
					var blend_color = NEON_GREEN.lerp(CITADEL_BLUE, randf() * 0.5 + 0.25)
					tween.parallel().tween_property(tile["mat"], "emission", blend_color, 1.0)
					tween.parallel().tween_property(tile["mat"], "emission_energy_multiplier", 1.2, 1.0)

			tile_states[col][row] = "normal"


func _get_tile_at(world_pos: Vector3) -> Vector2i:
	var local = world_pos - global_position
	var col = int((local.x + (COLS * TILE_SIZE) / 2.0) / TILE_SIZE)
	var row = int((local.z + (ROWS * TILE_SIZE) / 2.0) / TILE_SIZE)
	return Vector2i(clampi(col, 0, COLS - 1), clampi(row, 0, ROWS - 1))


func _find_player() -> Node3D:
	if _cached_player and is_instance_valid(_cached_player):
		return _cached_player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_cached_player = players[0]
		return _cached_player
	return null
