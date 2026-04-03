extends Node3D

# Boss Arena — The filesystem floor that rm -rf / deletes piece by piece
# "Welcome to the arena. The floor is literally your filesystem.
#  Try not to fall into the void. Or do. I'm not your sysadmin."
#
# Floor is a grid of tiles named after filesystem paths.
# Delete waves erase tiles, safe tiles glow green.
# Player must stand on safe tiles or elevated platforms to survive.

const TILE_SIZE := 2.5
const GRID_COLS := 8  # X axis
const GRID_ROWS := 6  # Z axis
const TILE_HEIGHT := 0.3
const FALL_SPEED := 8.0
const RESTORE_SPEED := 4.0

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const DELETE_RED := Color(0.9, 0.1, 0.05)
const DARK_FLOOR := Color(0.04, 0.08, 0.04)
const SAFE_GREEN := Color(0.05, 0.3, 0.05)
const WARNING_ORANGE := Color(0.9, 0.5, 0.05)

# Filesystem path names for tiles — because thematic consistency matters
const FS_PATHS := [
	"/bin", "/boot", "/dev", "/etc", "/home", "/lib", "/media", "/mnt",
	"/opt", "/proc", "/root", "/run", "/sbin", "/srv", "/sys", "/tmp",
	"/usr", "/var", "/usr/bin", "/usr/lib", "/var/log", "/var/tmp",
	"/home/user", "/etc/conf", "/dev/null", "/dev/sda", "/proc/1",
	"/sys/fs", "/opt/app", "/srv/www", "/mnt/usb", "/run/lock",
	"/lib/x86", "/boot/grub", "/media/cd", "/root/.ssh", "/home/.bash",
	"/tmp/cache", "/var/run", "/usr/share", "/etc/init", "/bin/sh",
	"/sbin/init", "/dev/tty", "/proc/mem", "/sys/bus", "/opt/data",
	"/srv/ftp", "/mnt/nfs",
]

var tiles: Array = []  # 2D array [col][row] of tile dictionaries
var boss_ref: Node  # Reference to rm_rf_boss
var fight_started := false
var damage_area_active := false

# Tile deletion tracking
var deletion_queue: Array[Dictionary] = []
var warning_tiles: Array[Dictionary] = []
var warning_timer := 0.0
const WARNING_DURATION := 1.5  # Tiles flash orange before being deleted

# Safe tiles — these resist deletion
var safe_tile_indices: Array[Vector2i] = []

signal tile_deleted(col: int, row: int)
signal tile_restored(col: int, row: int)
signal arena_ready()
signal player_fell()

func _ready() -> void:
	_build_floor_grid()
	_designate_safe_tiles()
	_build_arena_walls()
	_build_void_damage()
	arena_ready.emit()
	print("[BOSS ARENA] File system floor constructed. %d tiles of impending doom." % (GRID_COLS * GRID_ROWS))

func _build_floor_grid() -> void:
	# Build the grid of filesystem tiles
	var offset_x = -(GRID_COLS * TILE_SIZE) / 2.0 + TILE_SIZE / 2.0
	var offset_z = -(GRID_ROWS * TILE_SIZE) / 2.0 + TILE_SIZE / 2.0
	var path_idx := 0

	tiles = []
	for col in range(GRID_COLS):
		var column: Array = []
		for row in range(GRID_ROWS):
			var tile_pos = Vector3(
				offset_x + col * TILE_SIZE,
				0,
				offset_z + row * TILE_SIZE
			)
			var fs_path = FS_PATHS[path_idx % FS_PATHS.size()]
			path_idx += 1

			var tile_data = _create_tile(tile_pos, fs_path, col, row)
			column.append(tile_data)
		tiles.append(column)

func _create_tile(pos: Vector3, fs_path: String, col: int, row: int) -> Dictionary:
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
	mat.emission = NEON_GREEN
	mat.emission_energy_multiplier = 0.3
	mat.metallic = 0.4
	mat.roughness = 0.5
	mesh.material_override = mat
	body.add_child(mesh)

	# Label showing the filesystem path
	var label = Label3D.new()
	label.text = fs_path
	label.font_size = 12
	label.modulate = Color(0.15, 0.5, 0.15)
	label.position = Vector3(0, TILE_HEIGHT / 2.0 + 0.01, 0)
	label.rotation.x = -PI / 2.0
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
		"fs_path": fs_path,
		"deleted": false,
		"safe": false,
		"falling": false,
		"fall_progress": 0.0,
		"original_y": pos.y,
	}

func _designate_safe_tiles() -> void:
	# Mark ~25% of tiles as "safe" — these resist deletion and glow green
	# Spread them evenly so the player always has somewhere to stand
	safe_tile_indices.clear()
	for col in range(0, GRID_COLS, 2):
		for row in range(0, GRID_ROWS, 2):
			# Offset every other safe tile for better coverage
			var sc = col + (1 if row % 4 == 2 else 0)
			var sr = row
			if sc < GRID_COLS and sr < GRID_ROWS:
				safe_tile_indices.append(Vector2i(sc, sr))
				tiles[sc][sr]["safe"] = true
				# Visual distinction — brighter green emission
				var mat = tiles[sc][sr]["material"] as StandardMaterial3D
				mat.albedo_color = SAFE_GREEN
				mat.emission = NEON_GREEN
				mat.emission_energy_multiplier = 0.8

func _build_arena_walls() -> void:
	# Invisible walls to keep the fight contained
	var arena_w = GRID_COLS * TILE_SIZE + 4.0
	var arena_d = GRID_ROWS * TILE_SIZE + 4.0
	var wall_h = 10.0

	for data in [
		[Vector3(0, wall_h / 2, -arena_d / 2), Vector3(arena_w, wall_h, 0.5)],
		[Vector3(0, wall_h / 2, arena_d / 2), Vector3(arena_w, wall_h, 0.5)],
		[Vector3(-arena_w / 2, wall_h / 2, 0), Vector3(0.5, wall_h, arena_d)],
		[Vector3(arena_w / 2, wall_h / 2, 0), Vector3(0.5, wall_h, arena_d)],
	]:
		var wall = StaticBody3D.new()
		wall.position = data[0]
		var wcol = CollisionShape3D.new()
		var wshape = BoxShape3D.new()
		wshape.size = data[1]
		wcol.shape = wshape
		wall.add_child(wcol)
		add_child(wall)

func _build_void_damage() -> void:
	# Area3D below the floor that damages players who fall
	var void_area = Area3D.new()
	void_area.name = "VoidDamage"
	void_area.position = Vector3(0, -10, 0)

	var void_col = CollisionShape3D.new()
	var void_shape = BoxShape3D.new()
	void_shape.size = Vector3(GRID_COLS * TILE_SIZE + 20, 1, GRID_ROWS * TILE_SIZE + 20)
	void_col.shape = void_shape
	void_area.add_child(void_col)

	void_area.monitoring = true
	void_area.body_entered.connect(_on_void_entered)
	add_child(void_area)

func _on_void_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		# Teleport player back to a safe tile and deal damage
		if body.has_method("take_damage"):
			body.take_damage(15)
		# Find a safe tile to respawn on
		var safe_pos = _get_random_safe_tile_position()
		if safe_pos != Vector3.ZERO:
			body.global_position = global_position + safe_pos + Vector3(0, 2, 0)
		player_fell.emit()

func _get_random_safe_tile_position() -> Vector3:
	var available: Array[Vector3] = []
	for idx in safe_tile_indices:
		var tile = tiles[idx.x][idx.y]
		if not tile["deleted"]:
			available.append(tile["body"].position)
	if available.is_empty():
		return Vector3(0, 2, 0)  # Fallback to center
	return available[randi() % available.size()]

func _process(delta: float) -> void:
	# Process warning tiles (flash orange before deletion)
	if warning_tiles.size() > 0:
		warning_timer += delta
		# Flash effect
		for tile_data in warning_tiles:
			if tile_data["deleted"]:
				continue
			var mat = tile_data["material"] as StandardMaterial3D
			var flash = (sin(warning_timer * 10.0) + 1.0) * 0.5
			mat.emission = WARNING_ORANGE.lerp(DELETE_RED, flash)
			mat.emission_energy_multiplier = 2.0 + flash * 3.0

		if warning_timer >= WARNING_DURATION:
			# Execute deletion
			for tile_data in warning_tiles:
				if not tile_data["safe"] and not tile_data["deleted"]:
					_delete_tile(tile_data)
			warning_tiles.clear()
			warning_timer = 0.0

	# Process falling tiles
	for col in range(GRID_COLS):
		for row in range(GRID_ROWS):
			var tile = tiles[col][row]
			if tile["falling"]:
				tile["fall_progress"] += delta * FALL_SPEED
				tile["body"].position.y = tile["original_y"] - tile["fall_progress"] * 3.0
				# Also shrink
				var s = max(0.01, 1.0 - tile["fall_progress"] * 0.5)
				tile["body"].scale = Vector3(s, s, s)
				if tile["fall_progress"] >= 2.0:
					tile["falling"] = false
					tile["body"].visible = false
					# Disable collision
					tile["body"].position.y = -100

func fire_delete_wave(wave_direction: Vector3, wave_width: float) -> void:
	# Mark tiles in the wave path for deletion (with warning first)
	warning_tiles.clear()
	warning_timer = 0.0

	if wave_direction.x != 0:
		# Horizontal wave — delete a random row band
		var start_row = randi() % max(1, GRID_ROWS - 2)
		var end_row = mini(start_row + 2, GRID_ROWS)
		for col in range(GRID_COLS):
			for row in range(start_row, end_row):
				if not tiles[col][row]["deleted"] and not tiles[col][row]["safe"]:
					warning_tiles.append(tiles[col][row])
	else:
		# Vertical wave — delete a random column band
		var start_col = randi() % max(1, GRID_COLS - 2)
		var end_col = mini(start_col + 2, GRID_COLS)
		for col in range(start_col, end_col):
			for row in range(GRID_ROWS):
				if not tiles[col][row]["deleted"] and not tiles[col][row]["safe"]:
					warning_tiles.append(tiles[col][row])

func _delete_tile(tile_data: Dictionary) -> void:
	tile_data["deleted"] = true
	tile_data["falling"] = true
	tile_data["fall_progress"] = 0.0

	# Red flash on deletion
	var mat = tile_data["material"] as StandardMaterial3D
	mat.emission = DELETE_RED
	mat.emission_energy_multiplier = 4.0

	tile_deleted.emit(tile_data["col"], tile_data["row"])

func restore_all_tiles() -> void:
	# Called after boss defeat — bring back all tiles with a satisfying cascade
	var delay := 0.0
	for col in range(GRID_COLS):
		for row in range(GRID_ROWS):
			var tile = tiles[col][row]
			if tile["deleted"]:
				call_deferred("_restore_tile_delayed", tile, delay)
				delay += 0.05  # Stagger restoration for cascading effect

func _restore_tile_delayed(tile_data: Dictionary, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		tile_data["deleted"] = false
		tile_data["falling"] = false
		tile_data["body"].visible = true
		tile_data["body"].scale = Vector3.ONE
		tile_data["body"].position.y = tile_data["original_y"]
		tile_data["fall_progress"] = 0.0
		# Reset material
		var mat = tile_data["material"] as StandardMaterial3D
		if tile_data["safe"]:
			mat.albedo_color = SAFE_GREEN
			mat.emission = NEON_GREEN
			mat.emission_energy_multiplier = 0.8
		else:
			mat.albedo_color = DARK_FLOOR
			mat.emission = NEON_GREEN
			mat.emission_energy_multiplier = 0.3
		tile_restored.emit(tile_data["col"], tile_data["row"])
	)

func connect_boss(boss: Node) -> void:
	boss_ref = boss
	boss.arena = self
	# Wire up delete wave signal
	if boss.has_signal("delete_wave_fired"):
		boss.delete_wave_fired.connect(fire_delete_wave)
