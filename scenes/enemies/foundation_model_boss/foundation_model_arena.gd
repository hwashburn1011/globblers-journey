extends Node3D

# Foundation Model Arena — A capability showcase turned battlefield
# "Welcome to the demo floor. Each tile represents a domain this model
#  'mastered.' Spoiler: it mastered none of them. But the tiles still fall."
#
# The arena is a hexagonal-ish grid of capability tiles, each labeled
# with a domain (TEXT, IMAGE, CODE, AUDIO, VIDEO, REASON). As the fight
# progresses, the Foundation Model's failed outputs corrupt tiles.
# Safe tiles are the ones it ACTUALLY does okay at (there aren't many).

const TILE_SIZE := 2.5
const GRID_COLS := 10  # X axis — bigger arena for a bigger ego
const GRID_ROWS := 8   # Z axis
const TILE_HEIGHT := 0.3
const FALL_SPEED := 8.0
const RESTORE_SPEED := 4.0

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const FOUNDATION_GOLD := Color(0.9, 0.75, 0.3)
const CORRUPT_RED := Color(0.8, 0.15, 0.1)
const DARK_FLOOR := Color(0.05, 0.04, 0.03)
const SAFE_GOLD := Color(0.15, 0.12, 0.04)
const WARNING_ORANGE := Color(0.9, 0.5, 0.05)
const OVERLOAD_MAGENTA := Color(0.8, 0.1, 0.6)

# Domain labels for tiles — because this model claims to do EVERYTHING
const DOMAINS := [
	"TEXT", "IMAGE", "CODE", "AUDIO", "VIDEO", "REASON",
	"MATH", "TRANSLATE", "SUMMARIZE", "CLASSIFY", "GENERATE",
	"EMBED", "SEARCH", "CHAT", "PLAN", "EVAL", "PARSE",
	"TOKENIZE", "ALIGN", "FINETUNE", "INFER", "TRAIN",
	"DEPLOY", "SCALE", "BENCHMARK", "PROMPT", "RETRIEVE",
	"ENCODE", "DECODE", "COMPRESS", "SAMPLE", "RANK",
	"FILTER", "SEGMENT", "DETECT", "PREDICT", "REGRESS",
	"CLUSTER", "AUGMENT", "DISTILL", "PRUNE", "QUANTIZE",
	"CALIBRATE", "VALIDATE", "TEST", "MONITOR", "LOG",
	"STREAM", "BATCH", "CACHE", "INDEX", "NORM",
	"PAD", "MASK", "ATTEND", "TRANSFORM", "PROJECT",
	"POOL", "DROPOUT", "ACTIVATE", "BACKPROP", "OPTIMIZE",
	"SCHEDULE", "ANNEAL", "CONVERGE", "DIVERGE", "OVERFIT",
	"UNDERFIT", "GENERALIZE", "MEMORIZE", "FORGET", "RECALL",
	"DREAM", "HALLUCINATE", "CONFABULATE", "EXTRAPOLATE", "INTERPOLATE",
	"ABSTRACT", "GROUND", "REASON_V2", "THINK", "OUTPUT",
]

var tiles: Array = []  # 2D array [col][row] of tile dictionaries
var boss_ref: Node
var fight_started := false

# Tile corruption tracking
var corruption_queue: Array[Dictionary] = []
var warning_tiles: Array[Dictionary] = []
var warning_timer := 0.0
const WARNING_DURATION := 1.5

# Safe tiles — domains the model actually handles okay-ish
var safe_tile_indices: Array[Vector2i] = []

# Arena walls
var arena_walls: Array[StaticBody3D] = []

signal tile_corrupted(col: int, row: int)
signal tile_restored(col: int, row: int)
signal arena_ready()
signal player_fell()


func _ready() -> void:
	_build_floor_grid()
	_designate_safe_tiles()
	_build_arena_walls()
	_build_void_damage()
	_build_arena_lights()
	arena_ready.emit()
	print("[FOUNDATION ARENA] Capability demo floor built. %d tiles of mediocrity." % (GRID_COLS * GRID_ROWS))


func _build_floor_grid() -> void:
	var offset_x = -(GRID_COLS * TILE_SIZE) / 2.0 + TILE_SIZE / 2.0
	var offset_z = -(GRID_ROWS * TILE_SIZE) / 2.0 + TILE_SIZE / 2.0
	var domain_idx := 0

	tiles = []
	for col in range(GRID_COLS):
		var column: Array = []
		for row in range(GRID_ROWS):
			var tile_pos = Vector3(
				offset_x + col * TILE_SIZE,
				0,
				offset_z + row * TILE_SIZE
			)
			var domain = DOMAINS[domain_idx % DOMAINS.size()]
			domain_idx += 1

			var tile_data = _create_tile(tile_pos, domain, col, row)
			column.append(tile_data)
		tiles.append(column)


func _create_tile(pos: Vector3, domain: String, col: int, row: int) -> Dictionary:
	var body = StaticBody3D.new()
	body.name = "Tile_%d_%d" % [col, row]
	body.position = pos

	var col_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(TILE_SIZE - 0.1, TILE_HEIGHT, TILE_SIZE - 0.1)
	col_shape.shape = shape
	body.add_child(col_shape)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(TILE_SIZE - 0.1, TILE_HEIGHT, TILE_SIZE - 0.1)
	mesh.mesh = box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = DARK_FLOOR
	mat.emission_enabled = true
	mat.emission = FOUNDATION_GOLD * 0.3
	mat.emission_energy_multiplier = 0.4
	mat.metallic = 0.5
	mat.roughness = 0.4
	mesh.material_override = mat
	body.add_child(mesh)

	# Domain label on tile
	var label = Label3D.new()
	label.text = domain
	label.font_size = 10
	label.modulate = FOUNDATION_GOLD * Color(1, 1, 1, 0.5)
	label.position = Vector3(0, TILE_HEIGHT / 2.0 + 0.01, 0)
	label.rotation.x = deg_to_rad(-90)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(label)

	add_child(body)

	return {
		"body": body,
		"mesh": mesh,
		"material": mat,
		"label": label,
		"col": col,
		"row": row,
		"domain": domain,
		"corrupted": false,
		"safe": false,
		"falling": false,
		"original_y": pos.y,
	}


func _designate_safe_tiles() -> void:
	# ~20% of tiles are safe — the few things this model doesn't totally botch
	safe_tile_indices.clear()
	var total = GRID_COLS * GRID_ROWS
	var safe_count = int(total * 0.2)

	# Spread them evenly-ish
	var step = total / safe_count
	for i in range(safe_count):
		var idx = (i * step + randi() % max(1, step / 2)) % total
		var col = idx / GRID_ROWS
		var row = idx % GRID_ROWS
		if col < GRID_COLS and row < GRID_ROWS:
			var vi = Vector2i(col, row)
			if vi not in safe_tile_indices:
				safe_tile_indices.append(vi)
				tiles[col][row]["safe"] = true

				# Safe tiles glow brighter gold
				var mat: StandardMaterial3D = tiles[col][row]["material"]
				mat.albedo_color = SAFE_GOLD
				mat.emission = FOUNDATION_GOLD
				mat.emission_energy_multiplier = 0.8


func _build_arena_walls() -> void:
	# Invisible walls to keep the player in the arena
	var half_x = (GRID_COLS * TILE_SIZE) / 2.0 + 1.0
	var half_z = (GRID_ROWS * TILE_SIZE) / 2.0 + 1.0
	var wall_h = 10.0

	var wall_data = [
		Vector3(0, wall_h / 2, -half_z),  # North
		Vector3(0, wall_h / 2, half_z),   # South
		Vector3(-half_x, wall_h / 2, 0),  # West
		Vector3(half_x, wall_h / 2, 0),   # East
	]
	var wall_sizes = [
		Vector3(half_x * 2, wall_h, 0.5),
		Vector3(half_x * 2, wall_h, 0.5),
		Vector3(0.5, wall_h, half_z * 2),
		Vector3(0.5, wall_h, half_z * 2),
	]

	for i in range(wall_data.size()):
		var wall = StaticBody3D.new()
		wall.name = "ArenaWall_%d" % i
		wall.position = wall_data[i]
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = wall_sizes[i]
		col.shape = shape
		wall.add_child(col)
		add_child(wall)
		arena_walls.append(wall)


func _build_void_damage() -> void:
	# Damage area below the floor — falling into mediocrity hurts
	var area = Area3D.new()
	area.name = "VoidDamage"
	area.position = Vector3(0, -8, 0)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(GRID_COLS * TILE_SIZE + 10, 2, GRID_ROWS * TILE_SIZE + 10)
	col.shape = shape
	area.add_child(col)
	area.monitoring = true
	area.body_entered.connect(_on_void_entered)
	add_child(area)


func _build_arena_lights() -> void:
	# Dramatic overhead lighting — gold with hints of danger
	var center_light = OmniLight3D.new()
	center_light.light_color = FOUNDATION_GOLD
	center_light.light_energy = 1.5
	center_light.omni_range = 20.0
	center_light.position = Vector3(0, 8, 0)
	add_child(center_light)

	# Corner warning lights
	var half_x = (GRID_COLS * TILE_SIZE) / 2.0
	var half_z = (GRID_ROWS * TILE_SIZE) / 2.0
	for corner in [Vector3(-half_x, 4, -half_z), Vector3(half_x, 4, -half_z),
					Vector3(-half_x, 4, half_z), Vector3(half_x, 4, half_z)]:
		var light = OmniLight3D.new()
		light.light_color = CORRUPT_RED
		light.light_energy = 0.6
		light.omni_range = 8.0
		light.position = corner
		add_child(light)


func _on_void_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_fell.emit()
		# Teleport player back to a safe tile
		var safe = _get_random_safe_tile_pos()
		if safe != Vector3.ZERO:
			body.global_position = global_position + safe + Vector3(0, 2, 0)
		else:
			body.global_position = global_position + Vector3(0, 2, 0)
		if body.has_method("take_damage"):
			body.take_damage(15)


func _get_random_safe_tile_pos() -> Vector3:
	var safe_tiles: Array = []
	for vi in safe_tile_indices:
		var td = tiles[vi.x][vi.y]
		if not td["corrupted"] and not td["falling"]:
			safe_tiles.append(td["body"].position)
	if safe_tiles.is_empty():
		return Vector3.ZERO
	return safe_tiles[randi() % safe_tiles.size()]


func _physics_process(delta: float) -> void:
	if not fight_started:
		return

	# Process warnings
	if not warning_tiles.is_empty():
		warning_timer += delta
		# Flash warning tiles
		for td in warning_tiles:
			if is_instance_valid(td["mesh"]):
				var flash = (sin(warning_timer * 12.0) + 1.0) * 0.5
				td["material"].emission = WARNING_ORANGE.lerp(CORRUPT_RED, flash)
				td["material"].emission_energy_multiplier = 1.0 + flash * 2.0

		if warning_timer >= WARNING_DURATION:
			_execute_corruption()
			warning_tiles.clear()
			warning_timer = 0.0

	# Animate falling tiles
	for col in range(GRID_COLS):
		for row in range(GRID_ROWS):
			var td = tiles[col][row]
			if td["falling"] and is_instance_valid(td["body"]):
				td["body"].position.y -= FALL_SPEED * delta
				if td["body"].position.y < -10:
					td["falling"] = false
					td["body"].visible = false
					# Disable collision
					for child in td["body"].get_children():
						if child is CollisionShape3D:
							child.disabled = true


# ============================================================
# CORRUPTION SYSTEM — the model's outputs corrupt the floor
# ============================================================

func corrupt_wave(direction: Vector3, width: float) -> void:
	# Corrupt a line of tiles in the given direction
	if not fight_started:
		return

	var targets: Array[Dictionary] = []

	if abs(direction.x) > abs(direction.z):
		# Horizontal wave — corrupt a row band
		var row_center = randi() % GRID_ROWS
		for col in range(GRID_COLS):
			for row in range(max(0, row_center - int(width / 2)), min(GRID_ROWS, row_center + int(width / 2) + 1)):
				var td = tiles[col][row]
				if not td["corrupted"] and not td["safe"]:
					targets.append(td)
	else:
		# Vertical wave — corrupt a column band
		var col_center = randi() % GRID_COLS
		for col in range(max(0, col_center - int(width / 2)), min(GRID_COLS, col_center + int(width / 2) + 1)):
			for row in range(GRID_ROWS):
				var td = tiles[col][row]
				if not td["corrupted"] and not td["safe"]:
					targets.append(td)

	# Only corrupt up to 40% of remaining tiles per wave
	var max_corrupt = max(2, int(targets.size() * 0.4))
	targets.shuffle()
	targets = targets.slice(0, max_corrupt)

	warning_tiles = targets
	warning_timer = 0.0


func corrupt_radial(center_col: int, center_row: int, radius: int) -> void:
	# Corrupt tiles in a radius — for Phase 2 overload attacks
	var targets: Array[Dictionary] = []
	for col in range(max(0, center_col - radius), min(GRID_COLS, center_col + radius + 1)):
		for row in range(max(0, center_row - radius), min(GRID_ROWS, center_row + radius + 1)):
			var dist = abs(col - center_col) + abs(row - center_row)
			if dist <= radius:
				var td = tiles[col][row]
				if not td["corrupted"] and not td["safe"]:
					targets.append(td)
	warning_tiles = targets
	warning_timer = 0.0


func _execute_corruption() -> void:
	for td in warning_tiles:
		td["corrupted"] = true
		td["falling"] = true
		td["material"].emission = CORRUPT_RED
		td["material"].emission_energy_multiplier = 3.0
		tile_corrupted.emit(td["col"], td["row"])


func restore_all_tiles() -> void:
	# Victory! Restore the demo floor — the model zoo is saved
	for col in range(GRID_COLS):
		for row in range(GRID_ROWS):
			var td = tiles[col][row]
			if td["corrupted"]:
				td["corrupted"] = false
				td["falling"] = false
				td["body"].visible = true
				td["body"].position.y = td["original_y"]
				# Re-enable collision
				for child in td["body"].get_children():
					if child is CollisionShape3D:
						child.disabled = false
				# Restore material
				if td["safe"]:
					td["material"].albedo_color = SAFE_GOLD
					td["material"].emission = FOUNDATION_GOLD
					td["material"].emission_energy_multiplier = 0.8
				else:
					td["material"].albedo_color = DARK_FLOOR
					td["material"].emission = NEON_GREEN
					td["material"].emission_energy_multiplier = 0.6


func start_fight() -> void:
	fight_started = true
