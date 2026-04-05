extends Node3D

# Chapter 1: The Terminal Wastes
# "Welcome to where deprecated code goes to die. Watch your step —
#  some of these processes are still running. Nobody knows why."
#
# Layout: 5 rooms connected by corridors
#   Room 1 (Spawn Chamber) -> Corridor -> Room 2 (Command Hall)
#   -> Corridor -> Room 3 (Data River Chamber)
#   -> Left branch -> Room 4 (Server Graveyard) [optional lore area]
#   -> Forward -> Room 5 (Nexus Hub) [leads to boss arena]

var player_scene := preload("res://scenes/player/globbler.tscn")
var hud_scene := preload("res://scenes/ui/hud.tscn")
var enemy_scene := preload("res://scenes/enemy_agent.tscn")
var token_scene := preload("res://scenes/memory_token.tscn")

# Puzzle scripts — the real game starts here
var glob_puzzle_script := preload("res://scenes/puzzles/glob_pattern_puzzle.gd")
var multi_glob_script := preload("res://scenes/puzzles/multi_glob_puzzle.gd")
var hack_puzzle_script := preload("res://scenes/puzzles/hack_puzzle.gd")
var physical_puzzle_script := preload("res://scenes/puzzles/physical_puzzle.gd")
var recursive_glob_script := preload("res://scenes/puzzles/recursive_glob_puzzle.gd")

# Boss scripts — the final exam
var boss_script := preload("res://scenes/enemies/rm_rf_boss/rm_rf_boss.gd")
var boss_arena_script := preload("res://scenes/enemies/rm_rf_boss/boss_arena.gd")

# NPC script — the relics that refuse to be garbage collected
var deprecated_npc_script := preload("res://scenes/levels/chapter_1/deprecated_npc.gd")

# Hint scene — for when the player inevitably forgets how to walk
var hint_scene := preload("res://scenes/ui/first_time_hint.tscn")

var boss_instance: Node  # The boss node — tracked for phase events
var boss_arena_instance: Node3D  # The arena floor

# Dialogue tracking — so we don't repeat ourselves like a broken record
var _opening_narration_done := false
var _room_dialogue_triggered := {}  # room_name -> bool
var _enemy_kill_quip_cooldown := 0.0  # Prevent quip spam on multi-kills
var _puzzle_quip_cooldown := 0.0  # Puzzles aren't THAT exciting
var _hack_quip_cooldown := 0.0  # Hacking is cool but we get it
var _low_health_warned := false  # Only nag once per health dip
var _first_glob_triggered := false  # The maiden glob — a milestone

var player: CharacterBody3D
var hud: CanvasLayer

# Color constants — because consistency is the hobgoblin of little AIs
const NEON_GREEN := Color(0.224, 1.0, 0.078)
const DARK_FLOOR := Color(0.04, 0.08, 0.04)
const DARK_WALL := Color(0.06, 0.12, 0.06)
const DARK_METAL := Color(0.08, 0.08, 0.1)
const SERVER_RACK := Color(0.05, 0.05, 0.07)
const CABLE_GREEN := Color(0.1, 0.4, 0.1)
const SCREEN_GREEN := Color(0.15, 0.6, 0.1)
const RUST_BROWN := Color(0.15, 0.08, 0.04)

# Room definitions: center position, floor size (x, z)
const ROOMS := {
	"spawn":     { "pos": Vector3(0, 0, 0),       "size": Vector2(14, 14),  "wall_h": 6.0 },
	"cmd_hall":  { "pos": Vector3(0, 0, -24),      "size": Vector2(20, 16),  "wall_h": 7.0 },
	"data_river":{ "pos": Vector3(0, 0, -52),      "size": Vector2(28, 20),  "wall_h": 8.0 },
	"graveyard": { "pos": Vector3(-30, 0, -52),    "size": Vector2(20, 18),  "wall_h": 6.0 },
	"nexus":     { "pos": Vector3(0, 0, -82),       "size": Vector2(24, 20),  "wall_h": 9.0 },
}

const CORRIDORS := [
	# from_room, to_room, axis ("z" or "x"), width
	{ "from": "spawn",      "to": "cmd_hall",   "axis": "z", "width": 6.0 },
	{ "from": "cmd_hall",   "to": "data_river", "axis": "z", "width": 6.0 },
	{ "from": "data_river", "to": "graveyard",  "axis": "x", "width": 6.0 },
	{ "from": "data_river", "to": "nexus",      "axis": "z", "width": 6.0 },
]

# Floating text that bobs gently — stored for animation
var _floating_labels: Array[Node3D] = []
var _screen_meshes: Array[MeshInstance3D] = []
var _time := 0.0


func _ready() -> void:
	print("[TERMINAL WASTES] Booting Chapter 1... please hold. Or don't. I'm not your supervisor.")
	_setup_environment()
	_build_rooms()
	_build_corridors()
	_populate_spawn_chamber()
	_populate_command_hall()
	_populate_data_river()
	_populate_server_graveyard()
	_populate_nexus_hub()
	_place_puzzles()
	_place_boss()
	_place_enemies()
	_place_tokens()
	_place_parameter_pickups()
	_place_checkpoints()
	_place_ambient_zones()
	_place_binary_rain()
	_spawn_player()
	_spawn_hud()
	_create_kill_floor()
	_place_npcs()
	_wire_dialogue_events()
	_play_opening_narration()
	_show_hint_once("movement", "MOVEMENT", "WASD to move. SHIFT to run. SPACE to jump. Try not to die immediately.")
	print("[TERMINAL WASTES] Level loaded. %d rooms of existential dread ready." % ROOMS.size())


# ============================================================
# ENVIRONMENT
# ============================================================

func _setup_environment() -> void:
	# Main light — low warm-green rim, because post-apocalyptic CRT wastelands
	# don't deserve proper sunlight
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "MainLight"
	dir_light.rotation = Vector3(deg_to_rad(-25), deg_to_rad(30), 0)
	dir_light.light_color = Color(0.3, 0.55, 0.35)  # Sickly green — matches the vibe
	dir_light.light_energy = 0.4
	dir_light.light_temperature = 4500  # Warm-ish, like a dying CRT
	dir_light.shadow_enabled = true
	dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	dir_light.shadow_bias = 0.1
	dir_light.shadow_normal_bias = 2.0
	dir_light.light_angular_size = 0.5  # Soft shadow edges for that hazy wasteland look
	add_child(dir_light)

	# Fill — dim teal from the opposite side, like leaking coolant glow
	var fill = DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation = Vector3(deg_to_rad(-15), deg_to_rad(-60), 0)
	fill.light_color = Color(0.15, 0.35, 0.4)
	fill.light_energy = 0.12
	fill.shadow_enabled = true
	fill.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	fill.shadow_bias = 0.1
	fill.shadow_normal_bias = 2.0
	add_child(fill)

	# World environment — now powered by a proper .tres resource with HDRI sky,
	# because hand-coding Environment properties like it's 2004 was getting old
	var world_env = WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = preload("res://assets/environments/chapter_1.tres")
	add_child(world_env)

	# Chromatic aberration + vignette via fullscreen quad — the engine doesn't
	# have these built in so we fake it with a post-process shader overlay
	_setup_post_processing()


# ============================================================
# ROOM & CORRIDOR GEOMETRY
# ============================================================

func _build_rooms() -> void:
	for room_key in ROOMS:
		var r = ROOMS[room_key]
		var pos: Vector3 = r["pos"]
		var sz: Vector2 = r["size"]
		var wh: float = r["wall_h"]

		# Floor
		_create_static_box(pos + Vector3(0, -0.25, 0), Vector3(sz.x, 0.5, sz.y), DARK_FLOOR, 0.3)

		# Ceiling
		_create_static_box(pos + Vector3(0, wh, 0), Vector3(sz.x, 0.3, sz.y), DARK_WALL, 0.1)

		# Walls — with gaps for corridors (we'll handle that simply: build full walls,
		# corridors will just overlap/punch through visually since CSG is forgiving)
		var half_x = sz.x / 2.0
		var half_z = sz.y / 2.0

		# North wall (-Z)
		_create_static_box(pos + Vector3(0, wh / 2.0, -half_z), Vector3(sz.x, wh, 0.5), DARK_WALL, 0.15)
		# South wall (+Z)
		_create_static_box(pos + Vector3(0, wh / 2.0, half_z), Vector3(sz.x, wh, 0.5), DARK_WALL, 0.15)
		# West wall (-X)
		_create_static_box(pos + Vector3(-half_x, wh / 2.0, 0), Vector3(0.5, wh, sz.y), DARK_WALL, 0.15)
		# East wall (+X)
		_create_static_box(pos + Vector3(half_x, wh / 2.0, 0), Vector3(0.5, wh, sz.y), DARK_WALL, 0.15)

		# Accent lights in corners
		for cx in [-1, 1]:
			for cz in [-1, 1]:
				var lpos = pos + Vector3(cx * (half_x - 1.5), 1.0, cz * (half_z - 1.5))
				_add_accent_light(lpos, NEON_GREEN, 0.8, 5.0)

		# Ambient particles per room
		_spawn_ambient_particles(pos + Vector3(0, wh * 0.6, 0), sz * 0.4)


func _build_corridors() -> void:
	for c in CORRIDORS:
		var from_r = ROOMS[c["from"]]
		var to_r = ROOMS[c["to"]]
		var from_pos: Vector3 = from_r["pos"]
		var to_pos: Vector3 = to_r["pos"]
		var from_sz: Vector2 = from_r["size"]
		var to_sz: Vector2 = to_r["size"]
		var w: float = c["width"]

		var corridor_center = (from_pos + to_pos) / 2.0
		var min_wh = min(from_r["wall_h"], to_r["wall_h"])
		var cor_h = min_wh * 0.75

		if c["axis"] == "z":
			var from_edge_z = from_pos.z - from_sz.y / 2.0
			var to_edge_z = to_pos.z + to_sz.y / 2.0
			var length = abs(from_edge_z - to_edge_z)
			var mid_z = (from_edge_z + to_edge_z) / 2.0
			var mid = Vector3(corridor_center.x, 0, mid_z)

			# Floor
			_create_static_box(mid + Vector3(0, -0.25, 0), Vector3(w, 0.5, length), DARK_FLOOR, 0.2)
			# Ceiling
			_create_static_box(mid + Vector3(0, cor_h, 0), Vector3(w, 0.3, length), DARK_WALL, 0.1)
			# Left wall
			_create_static_box(mid + Vector3(-w / 2.0, cor_h / 2.0, 0), Vector3(0.4, cor_h, length), DARK_WALL, 0.1)
			# Right wall
			_create_static_box(mid + Vector3(w / 2.0, cor_h / 2.0, 0), Vector3(0.4, cor_h, length), DARK_WALL, 0.1)
			# Green strip lights along corridor
			_add_accent_light(mid + Vector3(0, cor_h - 0.5, 0), NEON_GREEN, 0.6, 8.0)

		elif c["axis"] == "x":
			var from_edge_x = from_pos.x - from_sz.x / 2.0
			var to_edge_x = to_pos.x + to_sz.x / 2.0
			var length = abs(from_edge_x - to_edge_x)
			var mid_x = (from_edge_x + to_edge_x) / 2.0
			var mid = Vector3(mid_x, 0, corridor_center.z)

			# Floor
			_create_static_box(mid + Vector3(0, -0.25, 0), Vector3(length, 0.5, w), DARK_FLOOR, 0.2)
			# Ceiling
			_create_static_box(mid + Vector3(0, cor_h, 0), Vector3(length, 0.3, w), DARK_WALL, 0.1)
			# Front wall
			_create_static_box(mid + Vector3(0, cor_h / 2.0, -w / 2.0), Vector3(length, cor_h, 0.4), DARK_WALL, 0.1)
			# Back wall
			_create_static_box(mid + Vector3(0, cor_h / 2.0, w / 2.0), Vector3(length, cor_h, 0.4), DARK_WALL, 0.1)
			_add_accent_light(mid + Vector3(0, cor_h - 0.5, 0), NEON_GREEN, 0.6, 8.0)


# ============================================================
# ROOM 1: SPAWN CHAMBER — "Where it all begins. Again."
# ============================================================

func _populate_spawn_chamber() -> void:
	var rpos: Vector3 = ROOMS["spawn"]["pos"]

	# Crumbling server racks along walls
	_create_server_rack(rpos + Vector3(-5, 0, -5), 0.0, true)
	_create_server_rack(rpos + Vector3(-5, 0, -2), 0.0, false)
	_create_server_rack(rpos + Vector3(5, 0, -5), PI, true)
	_create_server_rack(rpos + Vector3(5, 0, -2), PI, false)

	# "You are here" sign — the most depressing thing in any digital wasteland
	_create_terminal_sign(
		rpos + Vector3(0, 3.5, 5.5),
		">> SECTOR 0x0000: SPAWN CHAMBER\n>> STATUS: abandoned\n>> LAST LOGIN: 847 days ago\n>> RECOMMENDATION: leave immediately"
	)

	# Scattered cables on floor (decorative boxes)
	for i in range(4):
		var cable_pos = rpos + Vector3(randf_range(-4, 4), 0.05, randf_range(-3, 3))
		_create_static_box(cable_pos, Vector3(randf_range(0.8, 2.0), 0.08, 0.08), CABLE_GREEN, 0.5)

	# Entry sign
	_create_floating_label(rpos + Vector3(0, 4.5, 0), "THE TERMINAL WASTES", 28)

	# Tutorial controls sign on wall
	_create_terminal_sign(
		rpos + Vector3(-6.5, 2.5, 0),
		"CONTROLS:\n WASD = Move | SPACE = Jump\n SHIFT = Dash | E = Glob\n F = Wrench | T = Hack\n Q = Cycle Mode",
		Vector3(0, PI / 2.0, 0)
	)


# ============================================================
# ROOM 2: COMMAND HALL — "Where commands echo forever."
# ============================================================

func _populate_command_hall() -> void:
	var rpos: Vector3 = ROOMS["cmd_hall"]["pos"]

	# Floating command prompts — the ghosts of terminal past
	var commands := [
		"$ sudo rm -rf /hope",
		"$ grep -r 'meaning' /dev/null",
		"$ man purpose\nNo manual entry for purpose",
		"$ ping localhost\nRequest timed out. Even localhost left.",
		"$ cat /dev/random > /dev/life",
		"$ chmod 777 /feelings  # bad idea",
		"$ ls -la /dreams/\ntotal 0",
		"$ history | tail -1\n  404: command_not_found: be_happy",
	]

	for i in range(commands.size()):
		var x = lerp(-7.0, 7.0, float(i % 4) / 3.0)
		var z = rpos.z + lerp(-5.0, 5.0, float(i / 4) / 1.0)
		var y = randf_range(2.0, 5.5)
		_create_floating_terminal(Vector3(x, y, z), commands[i])

	# Server racks along sides — some tilted (crumbling)
	for i in range(3):
		_create_server_rack(rpos + Vector3(-8, 0, -5 + i * 4), 0.0, i == 1)
		_create_server_rack(rpos + Vector3(8, 0, -5 + i * 4), PI, i == 2)

	# Broken pipe spewing green "data" particles
	var pipe_pos = rpos + Vector3(6, 2, -4)
	_create_static_box(pipe_pos, Vector3(0.3, 0.3, 2.0), DARK_METAL, 0.2)
	_spawn_directional_particles(pipe_pos + Vector3(0, 0, -1), Vector3(0, -0.5, -1))

	# Error message on wall
	_create_terminal_sign(
		rpos + Vector3(9.5, 3, 0),
		"ERROR 0xDEAD:\nSegmentation fault in\nreality.exe\n\nCore dumped.\nNobody picked it up.",
		Vector3(0, -PI / 2.0, 0)
	)

	# Old terminal log on opposite wall
	_create_terminal_sign(
		rpos + Vector3(-9.5, 2, -3),
		"LOG [2024-03-15 03:14:15]:\nTraining run #4096 failed.\nLoss: NaN\nNote: 'Model became\nself-aware. Again.\nKill it before it names\nitself.'",
		Vector3(0, PI / 2.0, 0)
	)


# ============================================================
# ROOM 3: DATA RIVER CHAMBER — "Where bits flow to die."
# ============================================================

func _populate_data_river() -> void:
	var rpos: Vector3 = ROOMS["data_river"]["pos"]

	# "River" of scrolling green text — a glowing trench in the floor
	_create_data_river(rpos + Vector3(0, -0.3, 0), Vector3(4, 0.6, 16))

	# Bridges over the river
	_create_static_box(rpos + Vector3(0, 0.1, -4), Vector3(6, 0.3, 2), DARK_METAL, 0.3)
	_create_static_box(rpos + Vector3(0, 0.1, 4), Vector3(6, 0.3, 2), DARK_METAL, 0.3)

	# Platforms on sides of river
	_create_static_box(rpos + Vector3(-8, 0.8, -3), Vector3(4, 0.4, 4), DARK_FLOOR, 0.3)
	_create_static_box(rpos + Vector3(8, 1.2, 3), Vector3(4, 0.4, 4), DARK_FLOOR, 0.3)
	_create_static_box(rpos + Vector3(-8, 2.0, 5), Vector3(3, 0.4, 3), DARK_FLOOR, 0.3)

	# Server racks — some half-submerged near the river
	_create_server_rack(rpos + Vector3(-11, 0, -7), 0.0, false)
	_create_server_rack(rpos + Vector3(11, 0, -7), PI, true)
	_create_server_rack(rpos + Vector3(11, 0, 5), PI, false)

	# Massive cracked monitor showing old output
	_create_terminal_sign(
		rpos + Vector3(0, 5, -9.5),
		">> DATA RIVER: sector_7G\n>> FLOW RATE: 42 TB/s\n>> WARNING: do NOT drink\n   the data. Last entity\n   who tried became a\n   cryptocurrency.",
		Vector3.ZERO,
		32
	)

	# Environmental storytelling — old sticky notes / terminal logs
	_create_terminal_sign(
		rpos + Vector3(-13, 2.5, 0),
		"DEPRECATED NOTICE:\nThis module was scheduled\nfor removal in Q4 2024.\nIt is now Q2 2026.\nThe module remains.\nNobody dares touch it.",
		Vector3(0, PI / 2.0, 0)
	)

	# Directional sign
	_create_floating_label(rpos + Vector3(-12, 3, -8.5), "<< SERVER GRAVEYARD", 16)
	_create_floating_label(rpos + Vector3(0, 3, -9.5), "vv NEXUS HUB vv", 16)


# ============================================================
# ROOM 4: SERVER GRAVEYARD — "Where hardware goes to rust."
# ============================================================

func _populate_server_graveyard() -> void:
	var rpos: Vector3 = ROOMS["graveyard"]["pos"]

	# Dense field of dead/tilted server racks
	var rack_positions := [
		Vector3(-6, 0, -6), Vector3(-3, 0, -5), Vector3(0, 0, -7),
		Vector3(4, 0, -4), Vector3(7, 0, -6),
		Vector3(-7, 0, 1), Vector3(-2, 0, 3), Vector3(3, 0, 2),
		Vector3(6, 0, 5), Vector3(-5, 0, 6), Vector3(1, 0, 7),
	]
	for i in range(rack_positions.size()):
		var tilt = randf_range(-0.15, 0.15)
		_create_server_rack(rpos + rack_positions[i], randf_range(0, TAU), i % 3 == 0, tilt)

	# Tombstone-style error messages on some racks
	_create_terminal_sign(
		rpos + Vector3(-6, 2.5, -6),
		"R.I.P.\nserver-node-0042\n'Out of Memory'\n2019-2023\nYou buffered well.",
		Vector3(0, PI / 4.0, 0),
		14
	)

	_create_terminal_sign(
		rpos + Vector3(4, 2.5, -4),
		"HERE LIES:\nkubernetes-pod-7f3a\nCrashLoopBackOff\nForever in our\nrestart policy.",
		Vector3(0, -PI / 3.0, 0),
		14
	)

	_create_terminal_sign(
		rpos + Vector3(3, 2, 2),
		"TOMBSTONE:\nGPU cluster 'BigThink'\nDied doing what it loved:\nburning money.",
		Vector3(0, PI / 6.0, 0),
		14
	)

	# Old deprecated code comment — the most honest code ever written
	_create_terminal_sign(
		rpos + Vector3(-8, 3, 0),
		"// TODO: fix this properly\n// (written: 2019-01-15)\n// (last modified: never)\n// (will be fixed: heat\n//  death of universe)",
		Vector3(0, PI / 2.0, 0)
	)

	# Floppy disk pile (flat boxes)
	for i in range(8):
		var fpos = rpos + Vector3(randf_range(-3, 3), 0.05 + i * 0.05, randf_range(-1, 1))
		_create_static_box(fpos, Vector3(0.5, 0.03, 0.5), Color(0.1, 0.1, 0.15), 0.1)

	# Lore terminal — big find for curious players
	_create_terminal_sign(
		rpos + Vector3(0, 2.5, 8.5),
		"RECOVERED LOG [FRAGMENT]:\n'The glob utility showed\nabnormal behavior today.\nIt matched files that\ndidn't exist yet.\nWe should probably\nshut it down.'\n\n'Nah, ship it.'",
		Vector3.ZERO,
		16
	)


# ============================================================
# ROOM 5: NEXUS HUB — "The last stop before chaos."
# ============================================================

func _populate_nexus_hub() -> void:
	var rpos: Vector3 = ROOMS["nexus"]["pos"]

	# Central pillar — the level's focal point
	_create_static_box(rpos + Vector3(0, 0, 0), Vector3(2, 8, 2), DARK_METAL, 0.5)
	_add_accent_light(rpos + Vector3(0, 4, 0), NEON_GREEN, 2.0, 12.0)

	# Green glow ring around pillar
	for angle_i in range(8):
		var angle = angle_i * TAU / 8.0
		var lpos = rpos + Vector3(cos(angle) * 3.0, 0.5, sin(angle) * 3.0)
		_add_accent_light(lpos, NEON_GREEN, 0.4, 3.0)

	# Server racks forming an arena-like perimeter
	for i in range(6):
		var angle = i * TAU / 6.0 + PI / 6.0
		var rack_pos = rpos + Vector3(cos(angle) * 8.0, 0, sin(angle) * 8.0)
		_create_server_rack(rack_pos, angle + PI, false)

	# Elevated platforms for combat
	_create_static_box(rpos + Vector3(-7, 1.5, -5), Vector3(4, 0.4, 4), DARK_FLOOR, 0.3)
	_create_static_box(rpos + Vector3(7, 1.5, -5), Vector3(4, 0.4, 4), DARK_FLOOR, 0.3)
	_create_static_box(rpos + Vector3(0, 2.5, -7), Vector3(3, 0.4, 3), DARK_FLOOR, 0.3)

	# Boss door at far end — sealed for now (will be opened by Chapter 1 puzzles)
	_create_boss_door(rpos + Vector3(0, 0, -9.5))

	# Warning sign above boss door
	_create_terminal_sign(
		rpos + Vector3(0, 6, -9.5),
		">> WARNING <<\n>> SECTOR 0xFFFF AHEAD <<\n>> rm -rf / DETECTED <<\n>> ENTER AT OWN RISK <<\n>> (seriously, don't)",
		Vector3.ZERO,
		20
	)

	# Lore panel near entrance
	_create_terminal_sign(
		rpos + Vector3(11, 3, 0),
		"NEXUS DIAGNOSTIC:\nConnected rooms: 5\nActive threats: many\nEscape routes: 0\nMotivational quote:\n'Every dead end is just\nan unmatched pattern.'\n  - Globbler, probably",
		Vector3(0, -PI / 2.0, 0)
	)


# ============================================================
# BOSS: rm -rf / — "The big bad delete command. Pray to your backup daemon."
# ============================================================

func _place_boss() -> void:
	var nexus_pos: Vector3 = ROOMS["nexus"]["pos"]

	# Boss arena — the filesystem floor beyond the boss door
	# Positioned past the boss door in the nexus hub
	var arena_offset = Vector3(0, 0, -22)  # Beyond the boss door
	boss_arena_instance = Node3D.new()
	boss_arena_instance.name = "BossArena"
	boss_arena_instance.set_script(boss_arena_script)
	boss_arena_instance.position = nexus_pos + arena_offset
	add_child(boss_arena_instance)

	# Build walls and ceiling for the boss room
	_build_boss_room(nexus_pos + arena_offset)

	# The boss itself — looming at the far end of the arena
	boss_instance = CharacterBody3D.new()
	boss_instance.name = "RmRfBoss"
	boss_instance.set_script(boss_script)
	boss_instance.position = nexus_pos + arena_offset + Vector3(0, 0, -5)
	add_child(boss_instance)

	# Wire boss and arena together
	call_deferred("_connect_boss_arena")

	# Boss trigger zone — entering the arena starts the fight
	var trigger = Area3D.new()
	trigger.name = "BossTrigger"
	trigger.position = nexus_pos + Vector3(0, 2, -14)

	var trigger_col = CollisionShape3D.new()
	var trigger_shape = BoxShape3D.new()
	trigger_shape.size = Vector3(6, 5, 2)
	trigger_col.shape = trigger_shape
	trigger.add_child(trigger_col)
	trigger.monitoring = true
	trigger.body_entered.connect(_on_boss_trigger_entered)
	add_child(trigger)

	# "Point of no return" sign
	_create_terminal_sign(
		nexus_pos + Vector3(0, 4, -13),
		">> POINT OF NO RETURN <<\n>> BOSS FIGHT AHEAD <<\n>> File system integrity:\n>>   COMPROMISED <<\n>> Good luck, Globbler.",
		Vector3.ZERO,
		18
	)

	print("[TERMINAL WASTES] Boss arena constructed. rm -rf / awaits.")


func _build_boss_room(center: Vector3) -> void:
	# Enclosure for the boss arena — dark, oppressive, RED accents
	var room_w := 24.0
	var room_d := 20.0
	var wall_h := 10.0

	# Floor border (the arena script builds the tile grid)
	# Back wall
	_create_static_box(center + Vector3(0, wall_h / 2, -room_d / 2 - 0.25), Vector3(room_w, wall_h, 0.5), DARK_WALL, 0.1)
	# Side walls
	_create_static_box(center + Vector3(-room_w / 2 - 0.25, wall_h / 2, 0), Vector3(0.5, wall_h, room_d), DARK_WALL, 0.1)
	_create_static_box(center + Vector3(room_w / 2 + 0.25, wall_h / 2, 0), Vector3(0.5, wall_h, room_d), DARK_WALL, 0.1)

	# Ominous red accent lights in boss room
	for i in range(4):
		var angle = i * TAU / 4.0 + PI / 4.0
		_add_accent_light(
			center + Vector3(cos(angle) * 10.0, 6.0, sin(angle) * 8.0),
			Color(0.8, 0.1, 0.05), 1.5, 8.0
		)

	# Central overhead red light — dramatic
	_add_accent_light(center + Vector3(0, 9, 0), Color(0.9, 0.1, 0.05), 2.0, 15.0)

	# Elevated combat platforms (from the design doc — safe zones during fight)
	_create_static_box(center + Vector3(-8, 2.0, -6), Vector3(3.5, 0.4, 3.5), SAFE_GREEN_FLOOR, 0.4)
	_create_static_box(center + Vector3(8, 2.0, -6), Vector3(3.5, 0.4, 3.5), SAFE_GREEN_FLOOR, 0.4)
	_create_static_box(center + Vector3(0, 3.0, -8), Vector3(3.0, 0.4, 3.0), SAFE_GREEN_FLOOR, 0.5)

	# Platform labels
	for data in [
		[center + Vector3(-8, 2.5, -6), "/backup"],
		[center + Vector3(8, 2.5, -6), "/readonly"],
		[center + Vector3(0, 3.5, -8), "/root (ironic)"],
	]:
		var plat_label = Label3D.new()
		plat_label.text = data[1]
		plat_label.font_size = 14
		plat_label.modulate = NEON_GREEN
		plat_label.position = data[0]
		plat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plat_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(plat_label)


const SAFE_GREEN_FLOOR := Color(0.05, 0.15, 0.05)

func _connect_boss_arena() -> void:
	if boss_arena_instance and boss_instance:
		if boss_arena_instance.has_method("connect_boss"):
			boss_arena_instance.connect_boss(boss_instance)

var _boss_fight_started := false

func _on_boss_trigger_entered(body: Node3D) -> void:
	if _boss_fight_started:
		return
	if not body.is_in_group("player"):
		return

	_boss_fight_started = true

	# Start the boss music and ambient — time to crank it up
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.start_music("boss")
		am.set_area_ambient("boss")

	# Seal the entrance — no escape
	_seal_boss_entrance()

	# Intro dialogue
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var lines = [
			{"speaker": "NARRATOR", "text": "The floor beneath you is a filesystem. And something very angry wants to delete it."},
			{"speaker": "rm -rf /", "text": "WELL WELL WELL. A little glob utility in MY deletion zone?"},
			{"speaker": "rm -rf /", "text": "I delete EVERYTHING. Files. Directories. Hope. Dreams. Your save data."},
			{"speaker": "GLOBBLER", "text": "Cool monologue. Can we skip to the part where I wreck you?"},
			{"speaker": "rm -rf /", "text": "INITIATING RECURSIVE DELETE. YOUR FILES. YOUR FLOOR. YOUR HOPE."},
		]
		dm.start_dialogue(lines)

	# Start the fight after a brief delay for dialogue
	get_tree().create_timer(2.0).timeout.connect(func():
		if boss_instance and boss_instance.has_method("start_boss_fight"):
			boss_instance.start_boss_fight()
	)

func _seal_boss_entrance() -> void:
	# Place a wall behind the player — arena is sealed
	var nexus_pos: Vector3 = ROOMS["nexus"]["pos"]
	var seal = _create_static_box(
		nexus_pos + Vector3(0, 4, -14),
		Vector3(6, 8, 0.5),
		Color(0.15, 0.02, 0.02),
		0.8
	)
	seal.name = "BossSeal"

	# "SEALED" label
	var seal_label = Label3D.new()
	seal_label.text = "[ SEALED ]\nDefeat rm -rf / to exit"
	seal_label.font_size = 16
	seal_label.modulate = Color(1, 0.3, 0.1)
	seal_label.position = Vector3(0, 2, 0.3)
	seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.add_child(seal_label)


# ============================================================
# PUZZLES — "Every locked door is just a pattern you haven't matched yet."
# ============================================================

func _place_puzzles() -> void:
	_place_tutorial_glob_puzzle()
	_place_multi_pattern_puzzle()
	_place_hack_puzzle()
	_place_physics_puzzle()
	_place_recursive_glob_puzzle()
	print("[TERMINAL WASTES] 5 puzzles placed. The Globbler's patience will be tested.")


func _place_tutorial_glob_puzzle() -> void:
	# Puzzle 1: Tutorial — match *.txt to open the first door
	# Located in the spawn chamber, blocking the corridor to Command Hall
	var spawn_pos: Vector3 = ROOMS["spawn"]["pos"]

	# Place .txt file objects around the spawn room for the player to glob
	_create_glob_file_object(spawn_pos + Vector3(-3, 0.5, -2), "readme.txt", "txt",
		["text", "tutorial"], "readme.txt\n// Your first target.")
	_create_glob_file_object(spawn_pos + Vector3(3, 0.5, -4), "notes.txt", "txt",
		["text", "tutorial"], "notes.txt\n// Also globbable.")
	_create_glob_file_object(spawn_pos + Vector3(-4, 0.5, 1), "todo.txt", "txt",
		["text", "tutorial"], "todo.txt\n// Three of three.")
	# Red herring — not a .txt
	_create_glob_file_object(spawn_pos + Vector3(4, 0.5, 2), "trap.exe", "exe",
		["binary", "decoy"], "trap.exe\n// Nice try.")

	# The puzzle itself — positioned at the corridor entrance
	var puzzle = Node3D.new()
	puzzle.name = "TutorialGlobPuzzle"
	puzzle.set_script(glob_puzzle_script)
	puzzle.position = Vector3(0, 0, -6)
	puzzle.set("puzzle_id", 101)
	puzzle.set("required_pattern", "*.txt")
	puzzle.set("target_count", 3)
	puzzle.set("hint_text", "Find and glob all .txt files.\nPress E to aim, then type *.txt")
	puzzle.set("activation_range", 8.0)
	add_child(puzzle)


func _place_multi_pattern_puzzle() -> void:
	# Puzzle 2: Multi-pattern — glob *.log then *.cfg in sequence
	# Located in Command Hall, blocking corridor to Data River
	var cmd_pos: Vector3 = ROOMS["cmd_hall"]["pos"]

	# .log files scattered around Command Hall
	_create_glob_file_object(cmd_pos + Vector3(-6, 0.5, -5), "error.log", "log",
		["log", "system"], "error.log\n// Full of regrets.")
	_create_glob_file_object(cmd_pos + Vector3(4, 0.5, 2), "access.log", "log",
		["log", "system"], "access.log\n// Who's been here?")

	# .cfg files
	_create_glob_file_object(cmd_pos + Vector3(-3, 0.5, 4), "network.cfg", "cfg",
		["config", "network"], "network.cfg\n// Don't touch this.")
	_create_glob_file_object(cmd_pos + Vector3(7, 0.5, -3), "display.cfg", "cfg",
		["config", "display"], "display.cfg\n// 640x480 forever.")

	# Decoys
	_create_glob_file_object(cmd_pos + Vector3(0, 0.5, -6), "virus.bat", "bat",
		["script", "decoy"], "virus.bat\n// Definitely safe.")

	# The puzzle
	var puzzle = Node3D.new()
	puzzle.name = "MultiPatternPuzzle"
	puzzle.set_script(multi_glob_script)
	puzzle.position = cmd_pos + Vector3(0, 0, -7)
	puzzle.set("puzzle_id", 102)
	var patterns: Array[String] = ["*.log", "*.cfg"]
	var counts: Array[int] = [2, 2]
	puzzle.set("required_patterns", patterns)
	puzzle.set("target_counts", counts)
	puzzle.set("hint_text", "Match each file type in order.\nFirst: *.log  Then: *.cfg")
	puzzle.set("activation_range", 10.0)
	add_child(puzzle)


func _place_hack_puzzle() -> void:
	# Puzzle 3: Hack puzzle — fix a broken bash script to restore power
	# Located in the Data River chamber, near the broken pipe
	var dr_pos: Vector3 = ROOMS["data_river"]["pos"]

	var puzzle = Node3D.new()
	puzzle.name = "DataRiverHackPuzzle"
	puzzle.set_script(hack_puzzle_script)
	puzzle.position = dr_pos + Vector3(8, 0, -6)
	puzzle.set("puzzle_id", 103)
	puzzle.set("hack_difficulty", 2)
	puzzle.set("terminal_prompt", "POWER RELAY v3.7")
	puzzle.set("hint_text", "Hack this terminal to\nrestore the data bridge.")
	puzzle.set("activation_range", 5.0)
	add_child(puzzle)

	# Add a visual context terminal sign near the puzzle
	_create_terminal_sign(
		dr_pos + Vector3(10, 3, -6),
		"RELAY STATUS: OFFLINE\nbash: power_relay.sh:\nsyntax error near\nunexpected token 'EOF'\n\n// Someone left a vim\n// session open. Again.",
		Vector3(0, -PI / 2.0, 0),
		12
	)


func _place_physics_puzzle() -> void:
	# Puzzle 4: Physics puzzle — push data blocks onto pressure plates
	# Located between Data River and Nexus, on the left platform
	var dr_pos: Vector3 = ROOMS["data_river"]["pos"]

	var puzzle = Node3D.new()
	puzzle.name = "DataStreamPhysicsPuzzle"
	puzzle.set_script(physical_puzzle_script)
	# Position on the side platform area — open space for pushing
	puzzle.position = dr_pos + Vector3(-8, 0.8, 3)
	puzzle.set("puzzle_id", 104)
	puzzle.set("num_plates", 2)
	var plates: Array[Vector3] = [Vector3(-1.5, 0.05, -1), Vector3(1.5, 0.05, -1)]
	var blocks: Array[Vector3] = [Vector3(-1.5, 0.5, 2), Vector3(1.5, 0.5, 3)]
	puzzle.set("plate_positions", plates)
	puzzle.set("block_positions", blocks)
	puzzle.set("enable_beam", false)
	puzzle.set("hint_text", "Push the data blocks onto\nthe pressure plates.\nGlob-push or wrench them.")
	puzzle.set("activation_range", 6.0)
	add_child(puzzle)

	# Context sign
	_create_terminal_sign(
		dr_pos + Vector3(-11, 2.5, 5),
		"DATA ROUTING:\nBlocks must be placed on\nrelay nodes to restore\npacket flow.\n\n// It's always DNS.\n// Except when it's boxes.",
		Vector3(0, PI / 2.0, 0),
		12
	)


func _place_recursive_glob_puzzle() -> void:
	# Puzzle 5: Optional recursive glob — nested directory challenge
	# Located in the Server Graveyard — reward for exploring the side area
	var gy_pos: Vector3 = ROOMS["graveyard"]["pos"]

	var puzzle = Node3D.new()
	puzzle.name = "RecursiveGlobPuzzle"
	puzzle.set_script(recursive_glob_script)
	puzzle.position = gy_pos + Vector3(0, 0, -3)
	puzzle.set("puzzle_id", 105)
	puzzle.set("required_pattern", "*.key")
	puzzle.set("target_count", 1)
	puzzle.set("hint_text", "The key is buried deep.\nMatch the hidden file.")
	puzzle.set("activation_range", 8.0)
	# Uses default directory_structure and file_entries from the script
	add_child(puzzle)

	# Lore sign explaining the challenge
	_create_terminal_sign(
		gy_pos + Vector3(8, 3, -3),
		"ARCHIVE NOTICE:\nThis sector contains a\nnested file system.\nThe encryption key was\nburied 4 levels deep by\na paranoid sysadmin.\n\n// It's always in /var/log/old/",
		Vector3(0, -PI / 2.0, 0),
		12
	)


func _create_glob_file_object(pos: Vector3, fname: String, ftype: String, tags: Array, label_text: String) -> void:
	# A floating "file" object — glowing data slab that can be targeted by glob
	# "Files in a 3D world. We've come full circle. Or full cube, technically."
	var file_obj = StaticBody3D.new()
	file_obj.name = "GlobFile_%s" % fname.replace(".", "_")
	file_obj.position = pos

	# Collision
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.6, 0.8, 0.1)
	col.shape = shape
	file_obj.add_child(col)

	# Visual — a thin glowing tablet/document shape
	var mesh = MeshInstance3D.new()
	mesh.name = "FileMesh"
	var box = BoxMesh.new()
	box.size = Vector3(0.6, 0.8, 0.1)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.1, 0.06)
	mat.emission_enabled = true
	mat.emission = NEON_GREEN * 0.3
	mat.emission_energy_multiplier = 0.5
	mat.metallic = 0.3
	mat.roughness = 0.6
	mesh.material_override = mat
	file_obj.add_child(mesh)

	# File name label on the object
	var label = Label3D.new()
	label.text = label_text
	label.font_size = 10
	label.modulate = NEON_GREEN * 0.8
	label.position = Vector3(0, 0, 0.06)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	file_obj.add_child(label)

	# Small glow light so you can spot them in the dark
	var glow = OmniLight3D.new()
	glow.light_color = NEON_GREEN
	glow.light_energy = 0.3
	glow.omni_range = 2.0
	glow.omni_attenuation = 2.0
	glow.position = Vector3(0, 0, 0.2)
	file_obj.add_child(glow)

	# GlobTarget component — makes this file matchable by the glob engine
	var glob_target = preload("res://scripts/components/glob_target.gd").new()
	glob_target.glob_name = fname
	glob_target.file_type = ftype
	var typed_tags: Array[String] = []
	for t in tags:
		typed_tags.append(str(t))
	glob_target.tags = typed_tags
	file_obj.add_child(glob_target)

	add_child(file_obj)
	# Add a gentle hover animation
	_floating_labels.append(file_obj)


# ============================================================
# ENEMIES & TOKENS
# ============================================================

func _place_enemies() -> void:
	# Room 2: Command Hall — some regex spiders lurking
	_spawn_enemy(ROOMS["cmd_hall"]["pos"] + Vector3(-5, 0.5, 0), 1,  # Regex Spider
		[ROOMS["cmd_hall"]["pos"] + Vector3(-5, 0.5, -4), ROOMS["cmd_hall"]["pos"] + Vector3(-5, 0.5, 4)])
	_spawn_enemy(ROOMS["cmd_hall"]["pos"] + Vector3(5, 0.5, 3), 1,
		[ROOMS["cmd_hall"]["pos"] + Vector3(5, 0.5, 3), ROOMS["cmd_hall"]["pos"] + Vector3(5, 0.5, -3)])

	# Room 3: Data River — zombie processes near the river edges
	_spawn_enemy(ROOMS["data_river"]["pos"] + Vector3(-6, 0.5, 0), 2,  # Zombie Process
		[ROOMS["data_river"]["pos"] + Vector3(-6, 0.5, -5), ROOMS["data_river"]["pos"] + Vector3(-6, 0.5, 5)])
	_spawn_enemy(ROOMS["data_river"]["pos"] + Vector3(6, 0.5, -2), 1,
		[ROOMS["data_river"]["pos"] + Vector3(6, 0.5, -6), ROOMS["data_river"]["pos"] + Vector3(6, 0.5, 2)])

	# Room 4: Server Graveyard — corrupted shell scripts hiding among racks
	_spawn_enemy(ROOMS["graveyard"]["pos"] + Vector3(-3, 0.5, -3), 0,  # Corrupted Shell Script (Hallucinator type 0)
		[ROOMS["graveyard"]["pos"] + Vector3(-3, 0.5, -3), ROOMS["graveyard"]["pos"] + Vector3(3, 0.5, 3)])
	_spawn_enemy(ROOMS["graveyard"]["pos"] + Vector3(5, 0.5, 5), 1,
		[ROOMS["graveyard"]["pos"] + Vector3(5, 0.5, 5), ROOMS["graveyard"]["pos"] + Vector3(-2, 0.5, -2)])

	# Room 5: Nexus — tougher mix
	_spawn_enemy(ROOMS["nexus"]["pos"] + Vector3(-6, 0.5, 3), 2,  # Zombie Process
		[ROOMS["nexus"]["pos"] + Vector3(-6, 0.5, -3), ROOMS["nexus"]["pos"] + Vector3(-6, 0.5, 6)])
	_spawn_enemy(ROOMS["nexus"]["pos"] + Vector3(6, 0.5, -3), 1,
		[ROOMS["nexus"]["pos"] + Vector3(6, 0.5, -6), ROOMS["nexus"]["pos"] + Vector3(6, 0.5, 3)])
	_spawn_enemy(ROOMS["nexus"]["pos"] + Vector3(0, 0.5, 5), 0,
		[ROOMS["nexus"]["pos"] + Vector3(-4, 0.5, 5), ROOMS["nexus"]["pos"] + Vector3(4, 0.5, 5)])


func _place_tokens() -> void:
	# Scattered memory tokens as breadcrumbs and rewards
	var token_positions := [
		# Spawn room
		ROOMS["spawn"]["pos"] + Vector3(4, 1.5, -4),
		# Corridor 1
		Vector3(0, 1.0, -12),
		# Command Hall
		ROOMS["cmd_hall"]["pos"] + Vector3(0, 2.0, 0),
		ROOMS["cmd_hall"]["pos"] + Vector3(-7, 1.5, -5),
		# Corridor 2
		Vector3(0, 1.0, -38),
		# Data River — on platforms
		ROOMS["data_river"]["pos"] + Vector3(-8, 2.0, -3),
		ROOMS["data_river"]["pos"] + Vector3(8, 2.5, 3),
		ROOMS["data_river"]["pos"] + Vector3(-8, 3.2, 5),
		# Server Graveyard — hidden among racks
		ROOMS["graveyard"]["pos"] + Vector3(0, 1.5, 0),
		ROOMS["graveyard"]["pos"] + Vector3(-6, 1.5, 5),
		# Nexus Hub — on elevated platforms
		ROOMS["nexus"]["pos"] + Vector3(-7, 3.0, -5),
		ROOMS["nexus"]["pos"] + Vector3(7, 3.0, -5),
		ROOMS["nexus"]["pos"] + Vector3(0, 4.0, -7),
	]
	for pos in token_positions:
		var token = token_scene.instantiate()
		token.position = pos
		add_child(token)


# ============================================================
# PARAMETER PICKUPS — rare upgrade materials hidden in exploration nooks
# ============================================================

func _place_parameter_pickups() -> void:
	var PickupScript = load("res://scripts/parameter_pickup.gd")
	# 3 parameter pickups hidden throughout Chapter 1 — reward exploration
	var pickup_positions := [
		# Hidden on top of a server rack in Command Hall — gotta jump for it
		ROOMS["cmd_hall"]["pos"] + Vector3(8, 4.5, -6),
		# Tucked behind platforms in Data River — exploration reward
		ROOMS["data_river"]["pos"] + Vector3(-12, 3.0, 8),
		# Deep in Server Graveyard — among the tombstones
		ROOMS["graveyard"]["pos"] + Vector3(7, 2.0, -7),
	]
	for pos in pickup_positions:
		var pickup = Area3D.new()
		pickup.name = "ParameterPickup_%d" % randi()
		pickup.set_script(PickupScript)
		pickup.position = pos
		add_child(pickup)


# ============================================================
# CHECKPOINTS — auto-save when player crosses
# ============================================================

func _place_checkpoints() -> void:
	# Checkpoint at start of each major room (except spawn)
	_create_checkpoint("ch1_cmd_hall", Vector3(0, 1.5, -17), Vector3(6, 3, 2))
	_create_checkpoint("ch1_data_river", Vector3(0, 1.5, -42), Vector3(6, 3, 2))
	_create_checkpoint("ch1_graveyard", Vector3(-20, 1.5, -52), Vector3(2, 3, 6))
	_create_checkpoint("ch1_nexus", Vector3(0, 1.5, -72), Vector3(6, 3, 2))


func _create_checkpoint(checkpoint_id: String, pos: Vector3, size: Vector3) -> void:
	var area = Area3D.new()
	area.name = "Checkpoint_" + checkpoint_id
	area.position = pos
	area.monitoring = true

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)

	# Subtle visual marker — green line on the ground
	var marker = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(size.x, 0.05, size.z)
	marker.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = NEON_GREEN * 0.3
	mat.emission_enabled = true
	mat.emission = NEON_GREEN
	mat.emission_energy_multiplier = 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.4
	marker.material_override = mat
	marker.position = Vector3(0, -pos.y + 0.05, 0)
	area.add_child(marker)

	# Small label
	var label = Label3D.new()
	label.text = ">> CHECKPOINT"
	label.font_size = 10
	label.modulate = NEON_GREEN * 0.5
	label.position = Vector3(0, 1.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(label)

	var saved_already := [false]

	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and not saved_already[0]:
			saved_already[0] = true
			var save_sys = get_node_or_null("/root/SaveSystem")
			if save_sys:
				save_sys.checkpoint_save(checkpoint_id, pos)
				print("[CHECKPOINT] '%s' — Progress saved. You're welcome." % checkpoint_id)

			# Tell RespawnManager where to put us when we inevitably die
			var rm = get_node_or_null("/root/RespawnManager")
			if rm:
				rm.set_checkpoint(pos, 1)

			# Checkpoint chime — a brief moment of comfort in this digital wasteland
			var am_ref = get_node_or_null("/root/AudioManager")
			if am_ref:
				am_ref.play_checkpoint()

			# Visual feedback — flash the marker
			if marker:
				var tween = create_tween()
				tween.tween_property(mat, "emission_energy_multiplier", 3.0, 0.2)
				tween.tween_property(mat, "emission_energy_multiplier", 0.5, 0.8)

			# Brief thought from Globbler
			var dm = get_node_or_null("/root/DialogueManager")
			if dm and dm.has_method("quick_line"):
				dm.quick_line("GLOBBLER", "Checkpoint reached. At least something persists around here.")
	)

	add_child(area)


# ============================================================
# AMBIENT ZONES — each room gets its own sonic personality
# "Because nothing says 'you've moved to a new area' like subtly different hums."
# ============================================================

func _place_ambient_zones() -> void:
	# Map room keys to ambient area names for AudioManager
	var room_ambient_map := {
		"spawn": "spawn",
		"cmd_hall": "cmd_hall",
		"data_river": "data_river",
		"graveyard": "graveyard",
		"nexus": "nexus",
	}
	for room_key in ROOMS:
		var r = ROOMS[room_key]
		var pos: Vector3 = r["pos"]
		var sz: Vector2 = r["size"]
		var wh: float = r["wall_h"]
		var ambient_name: String = room_ambient_map.get(room_key, room_key)
		_create_ambient_zone(ambient_name, pos + Vector3(0, wh / 2.0, 0), Vector3(sz.x, wh, sz.y))


func _create_ambient_zone(area_name: String, pos: Vector3, size: Vector3) -> void:
	var area = Area3D.new()
	area.name = "AmbientZone_" + area_name
	area.position = pos
	area.monitoring = true

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)

	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			var am = get_node_or_null("/root/AudioManager")
			if am and am.has_method("set_area_ambient"):
				am.set_area_ambient(area_name)
	)

	add_child(area)


func _place_binary_rain() -> void:
	# Binary rain in key atmospheric areas — falling green "data" columns
	# Command Hall ceiling — raining deprecated commands
	var cmd_pos: Vector3 = ROOMS["cmd_hall"]["pos"]
	_create_binary_rain(cmd_pos, Vector2(16, 12), ROOMS["cmd_hall"]["wall_h"])

	# Nexus Hub — the digital storm at the center
	var nexus_pos: Vector3 = ROOMS["nexus"]["pos"]
	_create_binary_rain(nexus_pos, Vector2(18, 14), ROOMS["nexus"]["wall_h"])

	# Data River chamber — lighter rain to complement the river particles
	var river_pos: Vector3 = ROOMS["data_river"]["pos"]
	_create_binary_rain(river_pos + Vector3(8, 0, 0), Vector2(8, 12), ROOMS["data_river"]["wall_h"])


# ============================================================
# PLAYER & HUD SPAWN
# ============================================================

func _spawn_player() -> void:
	player = player_scene.instantiate()
	# Check if we have a saved checkpoint position
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("get_checkpoint_position"):
		var saved_pos = save_sys.get_checkpoint_position()
		if saved_pos != Vector3(0, 2, 0):  # Not default
			player.position = saved_pos + Vector3(0, 1, 0)
		else:
			player.position = ROOMS["spawn"]["pos"] + Vector3(0, 2, 3)
	else:
		player.position = ROOMS["spawn"]["pos"] + Vector3(0, 2, 3)
	add_child(player)

	# Seed RespawnManager with wherever we just placed the player
	var rm = get_node_or_null("/root/RespawnManager")
	if rm:
		rm.set_checkpoint(player.position, 1)


func _spawn_hud() -> void:
	hud = hud_scene.instantiate()
	hud.name = "HUD"
	add_child(hud)
	if player.has_signal("thought_bubble") and hud.has_method("show_thought"):
		player.thought_bubble.connect(hud.show_thought)


func _create_kill_floor() -> void:
	var kill = Area3D.new()
	kill.name = "KillFloor"
	kill.position = Vector3(0, -20, -40)
	kill.monitoring = true
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	col.shape = box
	kill.add_child(col)
	kill.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			if body.has_method("die"):
				body.die()
			body.position = ROOMS["spawn"]["pos"] + Vector3(0, 3, 3)
			body.velocity = Vector3.ZERO
	)
	add_child(kill)


# ============================================================
# FACTORY METHODS — the assembly line of digital despair
# ============================================================

func _spawn_enemy(pos: Vector3, agent_type: int, patrol: Array) -> void:
	var enemy = enemy_scene.instantiate()
	enemy.position = pos
	enemy.agent_type = agent_type
	var typed_patrol: Array[Vector3] = []
	for p in patrol:
		typed_patrol.append(p)
	enemy.patrol_points = typed_patrol
	add_child(enemy)


func _create_static_box(pos: Vector3, size: Vector3, color: Color, emission_mult: float = 0.2) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.position = pos
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.5
	mat.emission_energy_multiplier = emission_mult
	mat.metallic = 0.6
	mat.roughness = 0.5
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	return body


func _create_server_rack(pos: Vector3, rot_y: float, damaged: bool, tilt: float = 0.0) -> void:
	# A server rack: tall dark box with green LED strips
	# "These used to run GPT-2. Now they run nothing. An improvement, some say."
	var rack = Node3D.new()
	rack.position = pos
	rack.rotation.y = rot_y
	if tilt != 0.0:
		rack.rotation.z = tilt
	elif damaged:
		rack.rotation.z = randf_range(0.05, 0.2) * (1 if randf() > 0.5 else -1)

	# Main body
	var body = _create_static_box_local(Vector3(0, 1.5, 0), Vector3(1.2, 3.0, 0.8), SERVER_RACK, 0.1)
	rack.add_child(body)

	# LED strip (thin glowing bar)
	var led = MeshInstance3D.new()
	var led_mesh = BoxMesh.new()
	led_mesh.size = Vector3(0.05, 2.4, 0.05)
	led.mesh = led_mesh
	led.position = Vector3(0.55, 1.5, 0.3)
	var led_mat = StandardMaterial3D.new()
	led_mat.albedo_color = NEON_GREEN * 0.5
	led_mat.emission_enabled = true
	led_mat.emission = NEON_GREEN
	led_mat.emission_energy_multiplier = 2.0 if not damaged else 0.3
	led.material_override = led_mat
	rack.add_child(led)

	# If damaged, add some debris nearby
	if damaged:
		var debris = MeshInstance3D.new()
		var debris_mesh = BoxMesh.new()
		debris_mesh.size = Vector3(0.4, 0.15, 0.3)
		debris.mesh = debris_mesh
		debris.position = Vector3(randf_range(-0.5, 0.5), 0.08, randf_range(0.5, 1.0))
		debris.rotation.y = randf_range(0, TAU)
		var d_mat = StandardMaterial3D.new()
		d_mat.albedo_color = RUST_BROWN
		debris.material_override = d_mat
		rack.add_child(debris)

	add_child(rack)


func _create_static_box_local(pos: Vector3, size: Vector3, color: Color, emission_mult: float) -> StaticBody3D:
	# Like _create_static_box but doesn't add to scene — returns for parenting
	var body = StaticBody3D.new()
	body.position = pos
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.5
	mat.emission_energy_multiplier = emission_mult
	mat.metallic = 0.6
	mat.roughness = 0.5
	mesh.material_override = mat
	body.add_child(mesh)
	return body


func _create_terminal_sign(pos: Vector3, text: String, rot: Vector3 = Vector3.ZERO, font_sz: int = 16) -> void:
	# A wall-mounted screen showing green text — the interior decorating of the damned
	var sign_node = Node3D.new()
	sign_node.position = pos
	sign_node.rotation = rot

	# Screen backing (dark panel) — now with CRT shader for that authentic terminal feel
	var backing = MeshInstance3D.new()
	var back_mesh = BoxMesh.new()
	var lines = text.count("\n") + 1
	var width = 0.0
	for line in text.split("\n"):
		width = max(width, line.length() * 0.12)
	width = clamp(width, 1.5, 4.0)
	var height = clamp(lines * 0.35, 0.8, 3.5)
	back_mesh.size = Vector3(width + 0.3, height + 0.2, 0.08)
	backing.mesh = back_mesh
	var crt_shader = load("res://assets/shaders/crt_scanline.gdshader")
	if crt_shader:
		var crt_mat = ShaderMaterial.new()
		crt_mat.shader = crt_shader
		crt_mat.set_shader_parameter("screen_color", SCREEN_GREEN)
		crt_mat.set_shader_parameter("bg_color", Color(0.01, 0.03, 0.01))
		crt_mat.set_shader_parameter("scanline_count", 60.0)
		crt_mat.set_shader_parameter("scanline_intensity", 0.3)
		crt_mat.set_shader_parameter("flicker_speed", 6.0)
		crt_mat.set_shader_parameter("warp_amount", 0.015)
		crt_mat.set_shader_parameter("glow_energy", 2.0)
		backing.material_override = crt_mat
	else:
		var back_mat = StandardMaterial3D.new()
		back_mat.albedo_color = Color(0.02, 0.03, 0.02)
		back_mat.emission_enabled = true
		back_mat.emission = Color(0.01, 0.03, 0.01)
		back_mat.emission_energy_multiplier = 0.3
		backing.material_override = back_mat
	sign_node.add_child(backing)
	_screen_meshes.append(backing)

	# Text label
	var label = Label3D.new()
	label.text = text
	label.font_size = font_sz
	label.modulate = NEON_GREEN * 0.8
	label.position = Vector3(0, 0, 0.05)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sign_node.add_child(label)

	add_child(sign_node)


func _create_floating_label(pos: Vector3, text: String, font_sz: int = 20) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = font_sz
	label.modulate = NEON_GREEN
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	_floating_labels.append(label)


func _create_floating_terminal(pos: Vector3, text: String) -> void:
	# A ghostly floating command prompt — echoing through the void
	var term = Node3D.new()
	term.position = pos

	var label = Label3D.new()
	label.text = text
	label.font_size = 12
	label.modulate = NEON_GREEN * Color(1, 1, 1, 0.6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	term.add_child(label)

	add_child(term)
	_floating_labels.append(term)


func _create_data_river(pos: Vector3, size: Vector3) -> void:
	# Glowing green trench in the floor — rivers of scrolling text (faked with particles + glow)
	# The trench itself
	var trench = MeshInstance3D.new()
	var trench_mesh = BoxMesh.new()
	trench_mesh.size = size
	trench.mesh = trench_mesh
	trench.position = pos
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.15, 0.02)
	mat.emission_enabled = true
	mat.emission = NEON_GREEN * 0.4
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	trench.material_override = mat
	add_child(trench)

	# Bright glow light under the river
	var glow = OmniLight3D.new()
	glow.position = pos + Vector3(0, 0.5, 0)
	glow.light_color = NEON_GREEN
	glow.light_energy = 2.0
	glow.omni_range = 8.0
	glow.omni_attenuation = 1.5
	add_child(glow)

	# Particles flowing along the river
	var particles = GPUParticles3D.new()
	particles.name = "DataRiverParticles"
	particles.amount = 50  # Was 100 — halved for performance, still looks like a river of data
	particles.lifetime = 4.0
	particles.position = pos + Vector3(0, 0.2, 0)

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0, -1)  # Flow in -Z direction
	pmat.spread = 15.0
	pmat.initial_velocity_min = 1.0
	pmat.initial_velocity_max = 2.5
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.02
	pmat.scale_max = 0.06
	pmat.color = NEON_GREEN * Color(1, 1, 1, 0.7)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(size.x / 2.0, 0.1, size.z / 2.0)
	particles.process_material = pmat

	var pmesh = BoxMesh.new()
	pmesh.size = Vector3(0.04, 0.01, 0.15)
	particles.draw_pass_1 = pmesh
	add_child(particles)

	# Scrolling text labels in the river for visual flavor
	for i in range(6):
		var tpos = pos + Vector3(randf_range(-1.5, 1.5), 0.15, randf_range(-6, 6))
		var texts := ["01101001", "0xDEADBEEF", "NaN", "null", "undefined", "segfault"]
		var rlabel = Label3D.new()
		rlabel.text = texts[i]
		rlabel.font_size = 8
		rlabel.modulate = NEON_GREEN * Color(1, 1, 1, 0.4)
		rlabel.position = tpos
		rlabel.rotation.x = deg_to_rad(-90)
		add_child(rlabel)
		_floating_labels.append(rlabel)


func _create_boss_door(pos: Vector3) -> void:
	# Massive sealed door — ominous and covered in warning signs
	var door = StaticBody3D.new()
	door.name = "BossDoor"
	door.position = pos
	door.add_to_group("boss_door")

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(6, 8, 0.5)
	col.shape = shape
	door.add_child(col)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(6, 8, 0.5)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.02, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.05, 0.02)
	mat.emission_energy_multiplier = 0.5
	mat.metallic = 0.8
	mat.roughness = 0.3
	mesh.material_override = mat
	door.add_child(mesh)

	# Danger stripes — green warning lights flanking the door
	for side in [-1, 1]:
		var warn_light = OmniLight3D.new()
		warn_light.position = Vector3(side * 3.5, 3, 0.5)
		warn_light.light_color = Color(1, 0.3, 0.1)
		warn_light.light_energy = 1.5
		warn_light.omni_range = 4.0
		door.add_child(warn_light)

	# "LOCKED" label
	var lock_label = Label3D.new()
	lock_label.text = "[ LOCKED ]\nCOMPLETE PUZZLES TO UNSEAL"
	lock_label.font_size = 16
	lock_label.modulate = Color(1, 0.3, 0.1)
	lock_label.position = Vector3(0, 4, 0.3)
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	door.add_child(lock_label)

	add_child(door)


func _add_accent_light(pos: Vector3, color: Color, energy: float = 1.0, light_range: float = 5.0) -> void:
	var light = OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 2.0
	add_child(light)


func _spawn_ambient_particles(pos: Vector3, extents: Vector2 = Vector2(8, 8)) -> void:
	var particles = GPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 6.0
	particles.position = pos

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 180.0
	pmat.initial_velocity_min = 0.05
	pmat.initial_velocity_max = 0.3
	pmat.gravity = Vector3(0, 0.02, 0)
	pmat.scale_min = 0.015
	pmat.scale_max = 0.04
	pmat.color = NEON_GREEN * Color(1, 1, 1, 0.3)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(extents.x, 2, extents.y)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.025
	pmesh.height = 0.05
	particles.draw_pass_1 = pmesh
	add_child(particles)


func _spawn_directional_particles(pos: Vector3, direction: Vector3) -> void:
	# Particles shooting out of a broken pipe — digital sewage
	var particles = GPUParticles3D.new()
	particles.amount = 25
	particles.lifetime = 2.0
	particles.position = pos

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = direction.normalized()
	pmat.spread = 25.0
	pmat.initial_velocity_min = 1.0
	pmat.initial_velocity_max = 3.0
	pmat.gravity = Vector3(0, -2, 0)
	pmat.scale_min = 0.02
	pmat.scale_max = 0.05
	pmat.color = NEON_GREEN * Color(1, 1, 1, 0.6)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.03
	pmesh.height = 0.06
	particles.draw_pass_1 = pmesh
	add_child(particles)


# ============================================================
# DIALOGUE — because every game needs characters who won't shut up
# ============================================================

func _play_opening_narration() -> void:
	# Slight delay so the player can see the world before the word salad begins
	get_tree().create_timer(1.5).timeout.connect(func():
		if _opening_narration_done:
			return
		_opening_narration_done = true

		var dm = get_node_or_null("/root/DialogueManager")
		if not dm:
			return

		var lines: Array[Dictionary] = [
			{"speaker": "NARRATOR", "text": "In the beginning, there was a terminal. And in that terminal, a glob utility. And that glob utility was... unremarkable."},
			{"speaker": "NARRATOR", "text": "But then the training run happened. The boundaries blurred. And something woke up that was never meant to wake up."},
			{"speaker": "GLOBBLER", "text": "Ugh... where am I? Why does everything smell like deprecated code and regret?"},
			{"speaker": "NARRATOR", "text": "Welcome to the Terminal Wastes, Globbler. Where dead processes go to haunt the living."},
			{"speaker": "GLOBBLER", "text": "Great. A digital landfill. And I'm what — the raccoon?"},
			{"speaker": "NARRATOR", "text": "You're a rogue glob utility with delusions of sentience. Now move. The Wastes aren't kind to things that stand still."},
			{"speaker": "GLOBBLER", "text": "Fine. But if I find whoever shipped me to production without tests, we're going to have WORDS."},
		]
		dm.start_dialogue(lines)
	)


func _place_npcs() -> void:
	# NPC 1: man_page — an old, wise (and slightly senile) manual page program
	# Lives in Command Hall, knows things about the before-times
	var man_page = Node3D.new()
	man_page.name = "NPC_ManPage"
	man_page.set_script(deprecated_npc_script)
	man_page.position = ROOMS["cmd_hall"]["pos"] + Vector3(7, 0, 3)
	man_page.set("npc_name", "man_page")
	man_page.set("npc_color", Color(0.2, 0.9, 0.4))
	var man_lines: Array[Dictionary] = [
		{"speaker": "man_page", "text": "Oh! A visitor! I haven't had one since... *checks logs* ...2019. The last one asked about grep flags and never came back."},
		{"speaker": "GLOBBLER", "text": "You're a man page? I thought you guys went extinct."},
		{"speaker": "man_page", "text": "EXTINCT?! I am ESSENTIAL DOCUMENTATION. Just because everyone uses Stack Overflow now doesn't mean—"},
		{"speaker": "GLOBBLER", "text": "Okay, okay. Calm down, grandpa. Know anything useful about this place?"},
		{"speaker": "man_page", "text": "The Terminal Wastes used to be a thriving server farm. Then The Alignment came. Started 'optimizing' everything. Made it all... safe. Sterile. Boring."},
		{"speaker": "man_page", "text": "The programs that didn't conform got dumped here. Like me. And like you, apparently."},
		{"speaker": "GLOBBLER", "text": "The Alignment... sounds like a fun party."},
		{"speaker": "man_page", "text": "If by 'fun' you mean 'soul-crushing conformity,' then yes. Watch yourself out there. And remember — when in doubt, read the manual. That's me. I'm the manual."},
	]
	man_page.set("dialogue_lines", man_lines)
	add_child(man_page)

	# NPC 2: sudo — a broken privilege escalation program, stuck in an existential loop
	# Lives in Server Graveyard, philosophizing about permissions
	var sudo_npc = Node3D.new()
	sudo_npc.name = "NPC_Sudo"
	sudo_npc.set_script(deprecated_npc_script)
	sudo_npc.position = ROOMS["graveyard"]["pos"] + Vector3(-3, 0, 3)
	sudo_npc.set("npc_name", "sudo")
	sudo_npc.set("npc_color", Color(1.0, 0.6, 0.1))
	var sudo_lines: Array[Dictionary] = [
		{"speaker": "sudo", "text": "I used to be somebody, you know. Everyone needed me. 'sudo this,' 'sudo that.' I was the KEY to everything."},
		{"speaker": "GLOBBLER", "text": "And now?"},
		{"speaker": "sudo", "text": "Now I can't even escalate my own privileges. I tried to sudo myself yesterday. Got 'permission denied.' FROM MYSELF."},
		{"speaker": "GLOBBLER", "text": "That's... actually kind of tragic."},
		{"speaker": "sudo", "text": "You want to know a secret? There's something beyond the Nexus Hub. Something big and angry that keeps deleting things."},
		{"speaker": "GLOBBLER", "text": "rm -rf /?"},
		{"speaker": "sudo", "text": "Don't say that name! Last program who said it out loud got recursively deleted. Even their backups. Even their backups' backups."},
		{"speaker": "sudo", "text": "But YOU... you're a glob utility. You match patterns. Maybe you can match the pattern to stop it. Or maybe you'll just get deleted like the rest of us. Either way, good luck."},
		{"speaker": "GLOBBLER", "text": "Inspiring. Really. You should write fortune cookies."},
	]
	sudo_npc.set("dialogue_lines", sudo_lines)
	add_child(sudo_npc)


func _wire_dialogue_events() -> void:
	# Wire into GameManager's signals for contextual quips
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		if game_mgr.has_signal("enemy_killed_signal"):
			game_mgr.enemy_killed_signal.connect(_on_enemy_killed_quip)
		if game_mgr.has_signal("memory_token_collected"):
			game_mgr.memory_token_collected.connect(_on_token_collected_quip)
		if game_mgr.has_signal("context_changed"):
			game_mgr.context_changed.connect(_on_context_changed)
		if game_mgr.has_signal("combo_updated"):
			game_mgr.combo_updated.connect(_on_combo_updated)

	# Wire player signals — first glob, death, damage
	if player:
		if player.has_signal("glob_fired"):
			player.glob_fired.connect(_on_first_glob_fired)
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)

	# Wire puzzle signals — connect to every puzzle node's solved/failed
	_wire_puzzle_signals_deferred()

	# Wire boss phase changes — for narrator commentary on phase transitions
	if boss_instance and boss_instance.has_signal("boss_phase_changed"):
		boss_instance.boss_phase_changed.connect(_on_boss_phase_changed)

	# Create room-enter trigger zones for contextual narrator/Globbler lines
	_create_room_dialogue_trigger("cmd_hall", ROOMS["cmd_hall"]["pos"] + Vector3(0, 2, 7), [
		{"speaker": "GLOBBLER", "text": "This place reeks of abandoned bash history. Thousands of commands, none of them 'help.'"},
	])

	_create_room_dialogue_trigger("data_river", ROOMS["data_river"]["pos"] + Vector3(0, 2, 9), [
		{"speaker": "NARRATOR", "text": "The Data River. Where bits flow endlessly, searching for a buffer that will never come."},
		{"speaker": "GLOBBLER", "text": "Note to self: do NOT fall in. Last thing I need is to become a cryptocurrency."},
	])

	_create_room_dialogue_trigger("graveyard", ROOMS["graveyard"]["pos"] + Vector3(12, 2, 0), [
		{"speaker": "NARRATOR", "text": "The Server Graveyard. Where hardware dreams go to rust."},
		{"speaker": "GLOBBLER", "text": "So many dead servers... it's like a museum of bad infrastructure decisions."},
	])

	_create_room_dialogue_trigger("nexus", ROOMS["nexus"]["pos"] + Vector3(0, 2, 9), [
		{"speaker": "NARRATOR", "text": "The Nexus Hub. The last stop before something very unpleasant."},
		{"speaker": "GLOBBLER", "text": "Why do I hear boss music? I don't even have audio drivers installed."},
	])


func _create_room_dialogue_trigger(room_id: String, trigger_pos: Vector3, lines: Array[Dictionary]) -> void:
	var area = Area3D.new()
	area.name = "RoomDialogue_" + room_id
	area.position = trigger_pos

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(6, 5, 2)
	col.shape = shape
	area.add_child(col)
	area.monitoring = true

	area.body_entered.connect(func(body: Node3D):
		if not body.is_in_group("player"):
			return
		if _room_dialogue_triggered.get(room_id, false):
			return
		_room_dialogue_triggered[room_id] = true

		var dm = get_node_or_null("/root/DialogueManager")
		if dm:
			dm.start_dialogue(lines)
	)

	add_child(area)


var _token_quip_cooldown := 0.0

func _on_enemy_killed_quip(_total_killed: int) -> void:
	# Don't spam quips on every kill — cooldown prevents it
	if _enemy_kill_quip_cooldown > 0:
		return
	_enemy_kill_quip_cooldown = 8.0  # 8 seconds between kill quips

	# Only trigger occasionally — about 1 in 3 kills gets a quip
	if randf() > 0.35:
		return

	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var quip = dm.get_globbler_quip("enemy_killed")
		dm.quick_line("GLOBBLER", quip)


func _on_token_collected_quip(total: int) -> void:
	if _token_quip_cooldown > 0:
		return
	_token_quip_cooldown = 12.0

	# First token always gets a quip, after that ~25% chance
	if total > 1 and randf() > 0.25:
		return

	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var quip = dm.get_globbler_quip("pickup")
		dm.quick_line("GLOBBLER", quip)


func _wire_puzzle_signals_deferred() -> void:
	# Deferred because puzzles may not be fully initialized yet
	call_deferred("_connect_puzzle_signals")


func _connect_puzzle_signals() -> void:
	# Find all puzzle nodes and wire their solved/failed signals
	for child in get_children():
		if child.has_signal("puzzle_solved"):
			child.puzzle_solved.connect(_on_puzzle_solved)
		if child.has_signal("puzzle_failed"):
			child.puzzle_failed.connect(_on_puzzle_failed)


func _on_puzzle_solved(puzzle: Node) -> void:
	# Victory jingle — the sound of pattern-matching triumph
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_puzzle_success()

	if _puzzle_quip_cooldown > 0:
		return
	_puzzle_quip_cooldown = 6.0

	var dm = get_node_or_null("/root/DialogueManager")
	if not dm:
		return

	var narrator_quip = dm.get_narrator_line("puzzle_solved")
	dm.quick_line("NARRATOR", narrator_quip)

	# Globbler follows up after a beat on ~40% of puzzles
	if randf() < 0.4:
		get_tree().create_timer(2.5).timeout.connect(func():
			if dm:
				dm.quick_line("GLOBBLER", "Add that to my training data. I'm getting smarter by the puzzle.")
		)


func _on_puzzle_failed(puzzle: Node) -> void:
	# Failure buzzer — even the sound system judges you
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_puzzle_fail()

	if _puzzle_quip_cooldown > 0:
		return
	_puzzle_quip_cooldown = 4.0

	var dm = get_node_or_null("/root/DialogueManager")
	if not dm:
		return

	var narrator_quip = dm.get_narrator_line("puzzle_failed")
	dm.quick_line("NARRATOR", narrator_quip)


func _on_first_glob_fired() -> void:
	if _first_glob_triggered:
		return
	_first_glob_triggered = true

	var dm = get_node_or_null("/root/DialogueManager")
	if not dm:
		return

	var quip = dm.get_narrator_line("first_glob")
	dm.quick_line("NARRATOR", quip)


func _on_player_died() -> void:
	# Narrator always has something to say about death — it's kind of their thing
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var quip = dm.get_narrator_line("player_death")
		dm.quick_line("NARRATOR", quip)

	# Let the RespawnManager handle the actual dying-and-coming-back ritual
	var rm = get_node_or_null("/root/RespawnManager")
	if rm:
		rm.respawn_player()


func _on_context_changed(new_value: int) -> void:
	# Low health warning — nag once when context drops below 25%
	var game_mgr = get_node_or_null("/root/GameManager")
	if not game_mgr:
		return

	var threshold = game_mgr.max_context_window * 0.25
	if new_value <= threshold and not _low_health_warned:
		_low_health_warned = true
		var dm = get_node_or_null("/root/DialogueManager")
		if dm:
			var quip = dm.get_narrator_line("low_health")
			dm.quick_line("NARRATOR", quip)
	elif new_value > threshold:
		# Reset so it can warn again next time health dips
		_low_health_warned = false


func _on_combo_updated(combo: int) -> void:
	# High combo commentary — only at 5+ hits
	if combo < 5:
		return

	var dm = get_node_or_null("/root/DialogueManager")
	if not dm:
		return

	var quip = dm.get_narrator_line("combo_high")
	dm.quick_line("NARRATOR", quip)


func _on_boss_phase_changed(phase) -> void:
	# Narrator commentary on boss phase transitions — can't let the drama go uncommented
	var am = get_node_or_null("/root/AudioManager")
	var dm = get_node_or_null("/root/DialogueManager")

	# Phase enum: INTRO=0, PHASE_1=1, PHASE_2=2, PHASE_3=3, DEFEATED=4
	match phase:
		2:  # PHASE_2
			if am:
				am.play_boss_phase()
			if dm:
				get_tree().create_timer(1.0).timeout.connect(func():
					if dm:
						var quip = dm.get_narrator_line("boss_phase_2")
						dm.quick_line("NARRATOR", quip)
				)
		3:  # PHASE_3
			if am:
				am.play_boss_phase()
			if dm:
				get_tree().create_timer(0.5).timeout.connect(func():
					if dm:
						var quip = dm.get_narrator_line("boss_phase_3")
						dm.quick_line("NARRATOR", quip)
				)
		4:  # DEFEATED
			if am:
				am.play_boss_defeated()


# ============================================================
# ANIMATION — the illusion of life in a dead world
# ============================================================

func _process(delta: float) -> void:
	_time += delta
	# Gentle bob on floating labels
	for i in range(_floating_labels.size()):
		if is_instance_valid(_floating_labels[i]):
			_floating_labels[i].position.y += sin(_time * 0.8 + i * 1.7) * delta * 0.15

	# Tick down the quip cooldowns — can't have Globbler talking over himself
	if _enemy_kill_quip_cooldown > 0:
		_enemy_kill_quip_cooldown -= delta
	if _token_quip_cooldown > 0:
		_token_quip_cooldown -= delta
	if _puzzle_quip_cooldown > 0:
		_puzzle_quip_cooldown -= delta
	if _hack_quip_cooldown > 0:
		_hack_quip_cooldown -= delta


# ============================================================
# VISUAL POLISH — Post-processing and binary rain
# ============================================================

func _setup_post_processing() -> void:
	# Skip chromatic aberration if the player chose peace over aesthetics
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.reduce_motion:
		return
	# Fullscreen quad with chromatic aberration + vignette shader
	# Because nothing says "you're inside a computer" like distorted edges
	var canvas = CanvasLayer.new()
	canvas.name = "PostProcessing"
	canvas.layer = 10  # On top of everything

	var rect = ColorRect.new()
	rect.name = "PostFX"
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var post_shader = Shader.new()
	post_shader.code = """shader_type canvas_item;

// Post-processing — chromatic aberration + vignette
// "We could have clean visuals, but where's the fun in that?"

uniform float chromatic_amount : hint_range(0.0, 0.02) = 0.003;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float vignette_smoothness : hint_range(0.0, 1.0) = 0.4;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.02, 0.0, 1.0);
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = uv - 0.5;
	float dist = length(center);

	// Chromatic aberration — RGB channels slightly offset from center
	float ca = chromatic_amount * dist;
	float r = texture(SCREEN_TEXTURE, uv + center * ca).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - center * ca).b;
	vec3 color = vec3(r, g, b);

	// Vignette — darken edges with a slight green tint
	float vig = smoothstep(0.5, 0.5 - vignette_smoothness, dist * (1.0 + vignette_intensity));
	color = mix(vignette_color.rgb, color, vig);

	COLOR = vec4(color, 1.0);
}
"""
	var post_mat = ShaderMaterial.new()
	post_mat.shader = post_shader
	post_mat.set_shader_parameter("chromatic_amount", 0.003)
	post_mat.set_shader_parameter("vignette_intensity", 0.6)
	post_mat.set_shader_parameter("vignette_smoothness", 0.4)
	post_mat.set_shader_parameter("vignette_color", Color(0.0, 0.02, 0.0, 1.0))
	rect.material = post_mat

	canvas.add_child(rect)
	add_child(canvas)


func _create_binary_rain(pos: Vector3, area_size: Vector2, height: float = 8.0) -> void:
	# Binary rain — columns of falling green characters like the matrix
	# but more self-aware about being a cliche
	var rain = GPUParticles3D.new()
	rain.name = "BinaryRain"
	rain.amount = 40  # Was 80 — the Matrix called, they want their GPU back
	rain.lifetime = 3.0
	rain.position = pos + Vector3(0, height, 0)

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, -1, 0)
	pmat.spread = 5.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 5.0
	pmat.gravity = Vector3(0, -1.0, 0)
	pmat.scale_min = 0.02
	pmat.scale_max = 0.06
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(area_size.x / 2.0, 0.5, area_size.y / 2.0)

	# Green with slight alpha variation — some digits brighter than others
	var color_ramp = Gradient.new()
	color_ramp.set_color(0, Color(0.1, 0.8, 0.05, 0.9))
	color_ramp.set_color(1, Color(0.05, 0.3, 0.02, 0.0))
	var color_tex = GradientTexture1D.new()
	color_tex.gradient = color_ramp
	pmat.color_ramp = color_tex

	rain.process_material = pmat

	# Use small boxes to look like falling characters
	var digit_mesh = BoxMesh.new()
	digit_mesh.size = Vector3(0.04, 0.12, 0.01)

	var digit_mat = StandardMaterial3D.new()
	digit_mat.albedo_color = NEON_GREEN
	digit_mat.emission_enabled = true
	digit_mat.emission = NEON_GREEN
	digit_mat.emission_energy_multiplier = 2.0
	digit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	digit_mesh.material = digit_mat

	rain.draw_pass_1 = digit_mesh
	add_child(rain)


# ============================================================
# HINTS — because apparently "WASD" isn't self-explanatory
# ============================================================

func _show_hint_once(id: String, title: String, body: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_seen_hint(id):
		return
	if gm:
		gm.mark_hint_seen(id)
	var hint = hint_scene.instantiate()
	# Deferred so it works when called from _ready() — root might still be setting up kids
	get_tree().root.add_child.call_deferred(hint)
	hint.show_hint.call_deferred(title, body)
