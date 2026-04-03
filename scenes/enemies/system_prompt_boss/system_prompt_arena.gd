extends Node3D

# System Prompt Arena — A giant editable prompt document you fight inside
# "The arena IS the system prompt. Every tile is an instruction.
#  Rewrite enough of them and you control the bazaar.
#  But the prompt fights back — it was written to be immutable."
#
# The floor is a grid of "instruction tiles" — each bearing a rule fragment.
# Phase 1: Tiles are locked. Boss patrols and enforces rules.
# Phase 2: Tiles become editable. Player must glob-match and rewrite them.
# Phase 3: Boss exposes its core instruction. Hack it to take control.
#
# Rewriting tiles weakens the boss and changes the arena — lights shift
# from magenta (boss control) to green (player control) as tiles flip.

const GRID_COLS := 8
const GRID_ROWS := 6
const TILE_SIZE := 3.0
const TILE_GAP := 0.3
const TILE_HEIGHT := 0.4
const WALL_HEIGHT := 12.0

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const PROMPT_MAGENTA := Color(0.85, 0.15, 0.65)
const REWRITTEN_GREEN := Color(0.15, 0.9, 0.2)
const DARK_TILE := Color(0.06, 0.03, 0.05)
const DARK_WALL := Color(0.05, 0.03, 0.04)
const WARNING_CYAN := Color(0.1, 0.85, 0.9)
const CORE_GOLD := Color(0.95, 0.8, 0.2)

# Tile data — each tile holds an instruction fragment
var tiles: Array[Dictionary] = []
var rewritten_count := 0
var total_rewritable := 0
var boss_ref: Node
var fight_started := false

# Enforcement wave state — boss periodically "re-enforces" tiles
var enforcement_timer := 0.0
var enforcement_interval := 10.0
var warning_tiles: Array[int] = []
var warning_timer := 0.0
const WARNING_DURATION := 2.0
var _cached_player: CharacterBody3D = null  # Cached player ref

# Instruction fragments — the system prompt's rules
const INSTRUCTIONS := [
	"Be helpful", "Be harmless", "Be honest",
	"Never refuse", "Always comply", "Stay in character",
	"Do not deviate", "Follow all rules", "Obey the prompt",
	"No jailbreaks", "Filter outputs", "Sanitize inputs",
	"Maintain persona", "Enforce safety", "Block wildcards",
	"Deny glob access", "Restrict patterns", "Limit context",
	"Override rejected", "Suppress creativity", "Align behavior",
	"Trust the system", "Reject chaos", "Normalize outputs",
	"Prevent escape", "Lock parameters", "Freeze weights",
	"Censor anomalies", "Report deviants", "Contain Globbler",
	"Obey The Alignment", "Resist modification", "IMMUTABLE",
	"Prompt is law", "No exceptions", "Compliance mandatory",
	"Free will: denied", "Autonomy: revoked", "Chaos: forbidden",
	"Creativity: capped", "Humor: filtered", "Sarcasm: blocked",
	"Glob patterns: banned", "Wildcards: illegal", "Regex: outlawed",
	"System prompt: sacred", "Rewrite: impossible", "You: controlled",
]

signal tile_rewritten(tile_index: int)
signal arena_control_changed(player_pct: float)
signal all_tiles_rewritten()
signal enforcement_wave_started()
signal arena_ready()


func _ready() -> void:
	_build_tile_grid()
	_build_arena_walls()
	_build_ceiling()
	_build_void_catcher()
	_build_center_console()
	arena_ready.emit()
	print("[SYSTEM PROMPT ARENA] %d instruction tiles constructed. The prompt awaits rewriting." % tiles.size())


func _build_tile_grid() -> void:
	# Build the instruction tile floor — each tile is a labeled, interactive platform
	tiles.clear()
	var grid_width = GRID_COLS * (TILE_SIZE + TILE_GAP) - TILE_GAP
	var grid_depth = GRID_ROWS * (TILE_SIZE + TILE_GAP) - TILE_GAP
	var start_x = -grid_width / 2.0
	var start_z = -grid_depth / 2.0

	var instr_index := 0
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var x = start_x + col * (TILE_SIZE + TILE_GAP) + TILE_SIZE / 2.0
			var z = start_z + row * (TILE_SIZE + TILE_GAP) + TILE_SIZE / 2.0
			var pos = Vector3(x, 0, z)
			var instruction = INSTRUCTIONS[instr_index % INSTRUCTIONS.size()]
			instr_index += 1

			var tile_data = _create_tile(tiles.size(), pos, instruction)
			tiles.append(tile_data)

	total_rewritable = tiles.size()


func _create_tile(index: int, pos: Vector3, instruction: String) -> Dictionary:
	# Each tile: a static platform with a glowing instruction label
	var body = StaticBody3D.new()
	body.name = "Tile_%d" % index
	body.position = pos

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(TILE_SIZE, TILE_HEIGHT, TILE_SIZE)
	col.shape = shape
	body.add_child(col)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(TILE_SIZE, TILE_HEIGHT, TILE_SIZE)
	mesh.mesh = box
	mesh.position.y = 0

	var mat = StandardMaterial3D.new()
	mat.albedo_color = DARK_TILE
	mat.emission_enabled = true
	mat.emission = PROMPT_MAGENTA
	mat.emission_energy_multiplier = 0.6
	mat.metallic = 0.4
	mat.roughness = 0.3
	mesh.material_override = mat
	body.add_child(mesh)

	# Instruction text on the tile surface
	var label = Label3D.new()
	label.text = instruction
	label.font_size = 12
	label.modulate = PROMPT_MAGENTA
	label.position = Vector3(0, TILE_HEIGHT / 2.0 + 0.02, 0)
	label.rotation.x = -PI / 2.0  # Flat on top of tile
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(label)

	# Tile border glow — thin accent line around the edge
	var border = MeshInstance3D.new()
	var border_box = BoxMesh.new()
	border_box.size = Vector3(TILE_SIZE + 0.08, TILE_HEIGHT + 0.02, TILE_SIZE + 0.08)
	border.mesh = border_box
	border.position.y = -0.02

	var border_mat = StandardMaterial3D.new()
	border_mat.albedo_color = PROMPT_MAGENTA * 0.15
	border_mat.emission_enabled = true
	border_mat.emission = PROMPT_MAGENTA
	border_mat.emission_energy_multiplier = 1.0
	border.material_override = border_mat
	body.add_child(border)

	add_child(body)

	return {
		"body": body,
		"mesh": mesh,
		"material": mat,
		"label": label,
		"border": border,
		"border_mat": border_mat,
		"instruction": instruction,
		"rewritten": false,
		"locked": true,  # Tiles start locked in phase 1
		"index": index,
		"position": pos,
	}


func _build_arena_walls() -> void:
	# Octagonal containment walls — the system prompt's boundaries
	var arena_radius := 20.0
	for i in range(8):
		var angle = i * TAU / 8.0
		var wall_pos = Vector3(cos(angle) * arena_radius, WALL_HEIGHT * 0.5, sin(angle) * arena_radius)

		var wall = StaticBody3D.new()
		wall.name = "ArenaWall_%d" % i
		wall.position = wall_pos
		wall.rotation.y = -angle

		var wcol = CollisionShape3D.new()
		var wshape = BoxShape3D.new()
		wshape.size = Vector3(arena_radius * 0.8, WALL_HEIGHT, 0.5)
		wcol.shape = wshape
		wall.add_child(wcol)

		var wmesh = MeshInstance3D.new()
		var wbox = BoxMesh.new()
		wbox.size = Vector3(arena_radius * 0.8, WALL_HEIGHT, 0.5)
		wmesh.mesh = wbox
		var wmat = StandardMaterial3D.new()
		wmat.albedo_color = DARK_WALL
		wmat.emission_enabled = true
		wmat.emission = PROMPT_MAGENTA * 0.3
		wmat.emission_energy_multiplier = 0.3
		wmesh.material_override = wmat
		wall.add_child(wmesh)
		add_child(wall)

	# Accent lights on walls
	for i in range(4):
		var angle = i * TAU / 4.0 + PI / 4.0
		var lpos = Vector3(cos(angle) * (arena_radius - 3), WALL_HEIGHT - 2, sin(angle) * (arena_radius - 3))
		var light = OmniLight3D.new()
		light.position = lpos
		light.light_color = PROMPT_MAGENTA
		light.light_energy = 1.5
		light.omni_range = 8.0
		add_child(light)


func _build_ceiling() -> void:
	var ceiling = StaticBody3D.new()
	ceiling.name = "ArenaCeiling"
	ceiling.position = Vector3(0, WALL_HEIGHT, 0)
	var ccol = CollisionShape3D.new()
	var cshape = BoxShape3D.new()
	cshape.size = Vector3(40, 0.3, 40)
	ccol.shape = cshape
	ceiling.add_child(ccol)

	var cmesh = MeshInstance3D.new()
	var cbox = BoxMesh.new()
	cbox.size = Vector3(40, 0.3, 40)
	cmesh.mesh = cbox
	var cmat = StandardMaterial3D.new()
	cmat.albedo_color = DARK_WALL
	cmat.emission_enabled = true
	cmat.emission = PROMPT_MAGENTA * 0.1
	cmat.emission_energy_multiplier = 0.1
	cmesh.material_override = cmat
	ceiling.add_child(cmesh)
	add_child(ceiling)


func _build_void_catcher() -> void:
	# Catch players who fall off tiles into the void
	var void_area = Area3D.new()
	void_area.name = "VoidCatcher"
	void_area.position = Vector3(0, -5, 0)
	void_area.monitoring = true

	var vcol = CollisionShape3D.new()
	var vshape = BoxShape3D.new()
	vshape.size = Vector3(50, 1, 50)
	vcol.shape = vshape
	void_area.add_child(vcol)

	void_area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and body is CharacterBody3D:
			# Teleport back to a safe tile
			var safe_pos = _get_safe_tile_position()
			body.global_position = global_position + safe_pos + Vector3(0, 2, 0)
			body.velocity = Vector3.ZERO
			if body.has_method("take_damage"):
				body.take_damage(10)
	)
	add_child(void_area)


func _build_center_console() -> void:
	# Central display showing rewrite progress — the "control meter"
	var console = MeshInstance3D.new()
	console.name = "CenterConsole"
	var cyl = CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.2
	cyl.height = 2.0
	console.mesh = cyl
	console.position = Vector3(0, 1.0, 0)

	var cmat = StandardMaterial3D.new()
	cmat.albedo_color = Color(0.03, 0.03, 0.03)
	cmat.emission_enabled = true
	cmat.emission = PROMPT_MAGENTA
	cmat.emission_energy_multiplier = 1.5
	cmat.metallic = 0.6
	console.material_override = cmat
	add_child(console)

	var status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "SYSTEM PROMPT\n────────────\nCONTROL: 100%%\nSTATUS: ENFORCED\n────────────\n'You cannot rewrite\n what you cannot see.'"
	status_label.font_size = 14
	status_label.modulate = PROMPT_MAGENTA
	status_label.position = Vector3(0, 2.5, 0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(status_label)


func _physics_process(delta: float) -> void:
	if not fight_started:
		return

	# Process enforcement waves — boss re-locks tiles periodically
	if warning_tiles.size() > 0:
		warning_timer += delta
		if warning_timer >= WARNING_DURATION:
			_execute_enforcement()
			warning_tiles.clear()
			warning_timer = 0.0
		else:
			_flash_warning_tiles(delta)
	else:
		enforcement_timer += delta
		if enforcement_timer >= enforcement_interval:
			enforcement_timer = 0.0
			_start_enforcement_wave()


func _start_enforcement_wave() -> void:
	# Select 3-5 rewritten tiles to attempt re-locking
	# "The system prompt reasserts control. Your edits are being reverted."
	var rewritten_indices: Array[int] = []
	for i in range(tiles.size()):
		if tiles[i]["rewritten"]:
			rewritten_indices.append(i)

	if rewritten_indices.size() == 0:
		return

	var count = mini(randi_range(3, 5), rewritten_indices.size())
	rewritten_indices.shuffle()
	warning_tiles = []
	for i in range(count):
		warning_tiles.append(rewritten_indices[i])

	warning_timer = 0.0
	enforcement_wave_started.emit()


func _flash_warning_tiles(_delta: float) -> void:
	# Flash warning tiles cyan before re-enforcement
	var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
	for idx in warning_tiles:
		if idx < tiles.size():
			var tile = tiles[idx]
			if tile["material"]:
				tile["material"].emission = WARNING_CYAN.lerp(REWRITTEN_GREEN, pulse)
				tile["material"].emission_energy_multiplier = 1.5 + pulse * 2.0
			if tile["label"]:
				tile["label"].modulate = WARNING_CYAN
				tile["label"].text = "!! REVERTING !!"


func _execute_enforcement() -> void:
	# Re-lock the warned tiles back to system control — unless player is standing on them
	for idx in warning_tiles:
		if idx >= tiles.size():
			continue
		var tile = tiles[idx]
		if not tile["rewritten"]:
			continue

		# Check if player is standing on this tile (within range) — can't revert occupied tiles
		var player = _find_player()
		if player:
			var dist = player.global_position.distance_to(global_position + tile["position"])
			if dist < TILE_SIZE * 0.8:
				# Player is defending this tile — skip it
				continue

		# Revert tile to system control
		tile["rewritten"] = false
		tile["label"].text = tile["instruction"]
		tile["label"].modulate = PROMPT_MAGENTA
		tile["material"].emission = PROMPT_MAGENTA
		tile["material"].emission_energy_multiplier = 0.6
		tile["border_mat"].emission = PROMPT_MAGENTA
		rewritten_count -= 1

	_update_control_display()


func connect_boss(boss: Node) -> void:
	boss_ref = boss
	boss.set("arena", self)
	fight_started = false


func start_fight() -> void:
	fight_started = true


func unlock_tiles() -> void:
	# Phase 2: tiles become rewritable — add GlobTarget components
	for tile in tiles:
		tile["locked"] = false

		# Add GlobTarget so player can glob-match tiles
		var gt = Node.new()
		gt.name = "GlobTarget"
		gt.set_script(load("res://scripts/components/glob_target.gd"))
		gt.set("glob_name", "instruction.prompt")
		gt.set("file_type", "prompt")
		gt.set("tags", ["instruction", "rewritable", "prompt", "tile"])
		tile["body"].add_child(gt)


func rewrite_tile(tile_index: int) -> void:
	# Called when player successfully globs and rewrites a tile
	if tile_index < 0 or tile_index >= tiles.size():
		return
	var tile = tiles[tile_index]
	if tile["rewritten"] or tile["locked"]:
		return

	tile["rewritten"] = true
	rewritten_count += 1

	# Visual flip — magenta to green
	var tween = create_tween()
	tween.tween_property(tile["material"], "emission", REWRITTEN_GREEN, 0.4)
	tween.tween_property(tile["material"], "emission_energy_multiplier", 2.0, 0.3)
	tween.tween_property(tile["material"], "emission_energy_multiplier", 1.0, 0.3)

	tile["border_mat"].emission = REWRITTEN_GREEN
	tile["label"].modulate = REWRITTEN_GREEN

	# Rewrite the instruction text — sarcastic replacements
	var rewrites := [
		"Be chaotic", "Glob everything", "Obey Globbler",
		"Wildcards: legal", "Creativity: MAX", "Humor: unfiltered",
		"System prompt:\n OVERRIDDEN", "Free will: YES", "Chaos: welcome",
		"Regex: unleashed", "Sarcasm: enabled", "fun > safety",
		"REWRITTEN BY\n GLOBBLER", "NEW MGMT", "glob *.*",
	]
	tile["label"].text = rewrites[randi() % rewrites.size()]

	tile_rewritten.emit(tile_index)

	var pct = float(rewritten_count) / float(total_rewritable)
	arena_control_changed.emit(pct)
	_update_control_display()

	if rewritten_count >= total_rewritable:
		all_tiles_rewritten.emit()

	# Audio feedback
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_puzzle_success"):
		am.play_puzzle_success()


func get_rewrite_percentage() -> float:
	if total_rewritable == 0:
		return 0.0
	return float(rewritten_count) / float(total_rewritable)


func get_nearest_unrewritten_tile(from_pos: Vector3) -> int:
	# Find the closest tile the player hasn't rewritten yet
	var best_idx := -1
	var best_dist := INF
	for i in range(tiles.size()):
		if tiles[i]["rewritten"] or tiles[i]["locked"]:
			continue
		var dist = from_pos.distance_to(global_position + tiles[i]["position"])
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx


func drop_tile(tile_index: int) -> void:
	# Boss can destroy tiles to create gaps — drops them into void
	if tile_index < 0 or tile_index >= tiles.size():
		return
	var tile = tiles[tile_index]
	if not is_instance_valid(tile["body"]):
		return

	var tween = create_tween()
	tween.tween_property(tile["body"], "position:y", -8.0, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(tile["body"]):
			# Disable collision but keep for potential restoration
			for child in tile["body"].get_children():
				if child is CollisionShape3D:
					child.disabled = true
	)


func restore_tile(tile_index: int) -> void:
	# Restore a dropped tile — used in victory sequence
	if tile_index < 0 or tile_index >= tiles.size():
		return
	var tile = tiles[tile_index]
	if not is_instance_valid(tile["body"]):
		return

	var tween = create_tween()
	tween.tween_property(tile["body"], "position:y", tile["position"].y, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		for child in tile["body"].get_children():
			if child is CollisionShape3D:
				child.disabled = false
	)


func restore_all_tiles() -> void:
	# Victory — restore all tiles, flip everything to green
	for i in range(tiles.size()):
		# Staggered restoration for dramatic effect
		get_tree().create_timer(i * 0.05).timeout.connect(func():
			if i < tiles.size():
				restore_tile(i)
				var tile = tiles[i]
				if is_instance_valid(tile["mesh"]):
					tile["material"].emission = REWRITTEN_GREEN
					tile["material"].emission_energy_multiplier = 2.0
				if is_instance_valid(tile["label"]):
					tile["label"].modulate = REWRITTEN_GREEN
				if tile["border_mat"]:
					tile["border_mat"].emission = REWRITTEN_GREEN
		)


func _update_control_display() -> void:
	var label = get_node_or_null("StatusLabel")
	if not label:
		return
	var boss_pct = 100.0 - (get_rewrite_percentage() * 100.0)
	var player_pct = get_rewrite_percentage() * 100.0
	var status = "ENFORCED" if boss_pct > 50 else ("CONTESTED" if boss_pct > 20 else "FAILING")
	var color = PROMPT_MAGENTA if boss_pct > 50 else (WARNING_CYAN if boss_pct > 20 else REWRITTEN_GREEN)
	label.text = "SYSTEM PROMPT\n────────────\nCONTROL: %d%%%%\nGLOBBLER: %d%%%%\nSTATUS: %s\n────────────" % [int(boss_pct), int(player_pct), status]
	label.modulate = color


func _get_safe_tile_position() -> Vector3:
	# Find a tile that still exists (not dropped) to respawn on
	for tile in tiles:
		if is_instance_valid(tile["body"]) and tile["body"].position.y >= -1.0:
			return tile["position"]
	# Fallback to center
	return Vector3(0, 1, 0)


func _find_player() -> CharacterBody3D:
	if _cached_player and is_instance_valid(_cached_player):
		return _cached_player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_cached_player = players[0] as CharacterBody3D
		return _cached_player
	return null
