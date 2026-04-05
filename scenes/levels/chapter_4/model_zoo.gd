extends Node3D

# Chapter 4: The Model Zoo
# "Welcome to the digital safari, where deprecated AI models roam free
#  and experimental ones haven't been house-trained yet.
#  Feeding the exhibits is strongly discouraged but wildly entertaining."
#
# Layout: A sprawling AI nature preserve / museum hybrid — exhibit halls
# connected by safari paths lined with informational plaques and fences.
#   Zoo Entrance (Spawn) -> Fossil Wing (GPT-2 territory)
#   -> Nightmare Gallery (DALL-E horrors) -> Office Ruins (Clippy's domain)
#   -> Foundation Atrium (Grand central hall) -> Boss Arena (The Foundation Model)
#
# Visual theme: Deep teal/indigo institutional lighting with warm amber exhibit
# spotlights, dusty museum vibes, and the ever-present neon green of Globbler.
# Think Natural History Museum meets abandoned server farm meets Jurassic Park.

var player_scene := preload("res://scenes/player/globbler.tscn")
var hud_scene := preload("res://scenes/ui/hud.tscn")
var token_scene := preload("res://scenes/memory_token.tscn")

# Chapter 4 enemy scenes — the zoo's residents have escaped their enclosures
var gpt2_fossil_scene := preload("res://scenes/enemies/gpt2_fossil.tscn")
var dalle_nightmare_scene := preload("res://scenes/enemies/dalle_nightmare.tscn")
var clippy_revenge_scene := preload("res://scenes/enemies/clippy_revenge.tscn")

# Puzzle scripts — exploit each model's quirks
var glob_puzzle_script := preload("res://scenes/puzzles/glob_pattern_puzzle.gd")
var multi_glob_script := preload("res://scenes/puzzles/multi_glob_puzzle.gd")
var hack_puzzle_script := preload("res://scenes/puzzles/hack_puzzle.gd")
var physical_puzzle_script := preload("res://scenes/puzzles/physical_puzzle.gd")
var fossil_exhibit_script := preload("res://scenes/puzzles/fossil_exhibit_puzzle.gd")
var nightmare_gallery_script := preload("res://scenes/puzzles/nightmare_gallery_puzzle.gd")
var clippy_help_script := preload("res://scenes/puzzles/clippy_help_puzzle.gd")

# Boss scripts — the grand finale of mediocrity
var boss_script := preload("res://scenes/enemies/foundation_model_boss/foundation_model_boss.gd")
var boss_arena_script := preload("res://scenes/enemies/foundation_model_boss/foundation_model_arena.gd")

# NPC script — old models still have opinions about everything
var deprecated_npc_script := preload("res://scenes/levels/chapter_1/deprecated_npc.gd")

var player: CharacterBody3D
var hud: CanvasLayer
var boss_instance: Node  # The Foundation Model — tracked for phase events
var boss_arena_instance: Node3D

# Dialogue tracking — every exhibit has a placard and an attitude
var _opening_narration_done := false
var _room_dialogue_triggered := {}
var _enemy_kill_quip_cooldown := 0.0
var _puzzle_quip_cooldown := 0.0
var _hack_quip_cooldown := 0.0
var _low_health_warned := false
var _token_quip_cooldown := 0.0
var _first_glob_triggered := false
var _damage_quip_cooldown := 0.0

# Color constants — the Zoo trades bazaar amber for museum teal
const NEON_GREEN := Color(0.224, 1.0, 0.078)
const EXHIBIT_TEAL := Color(0.15, 0.55, 0.6)
const FOSSIL_AMBER := Color(0.75, 0.55, 0.2)
const NIGHTMARE_PURPLE := Color(0.5, 0.1, 0.55)
const CLIPPY_BLUE := Color(0.25, 0.45, 0.85)
const FOUNDATION_GOLD := Color(0.9, 0.75, 0.3)
const PLAQUE_BROWN := Color(0.35, 0.25, 0.12)
const DARK_FLOOR := Color(0.04, 0.04, 0.05)
const DARK_WALL := Color(0.06, 0.06, 0.08)
const FENCE_GRAY := Color(0.25, 0.25, 0.28)

# Room definitions — exhibit halls in the digital safari
const ROOMS := {
	"zoo_entrance": {
		"pos": Vector3(0, 0, 0),
		"size": Vector2(16, 14),
		"wall_h": 7.0,
		"label": "ZOO ENTRANCE",
	},
	"fossil_wing": {
		"pos": Vector3(0, 0, -30),
		"size": Vector2(26, 22),
		"wall_h": 8.0,
		"label": "FOSSIL WING — LEGACY MODELS",
	},
	"nightmare_gallery": {
		"pos": Vector3(-32, 0, -30),
		"size": Vector2(20, 20),
		"wall_h": 9.0,
		"label": "NIGHTMARE GALLERY — GENERATIVE HORRORS",
	},
	"office_ruins": {
		"pos": Vector3(32, -1, -30),
		"size": Vector2(20, 18),
		"wall_h": 6.0,
		"label": "OFFICE RUINS — ASSISTANT GRAVEYARD",
	},
	"foundation_atrium": {
		"pos": Vector3(0, 0, -60),
		"size": Vector2(30, 24),
		"wall_h": 12.0,
		"label": "FOUNDATION ATRIUM",
	},
}

# Safari paths connecting exhibit halls — wide enough for tour groups
const CORRIDORS := [
	{ "from": "zoo_entrance",       "to": "fossil_wing",        "axis": "z", "width": 6.0 },
	{ "from": "fossil_wing",        "to": "nightmare_gallery",  "axis": "x", "width": 5.0 },
	{ "from": "fossil_wing",        "to": "office_ruins",       "axis": "x", "width": 5.0 },
	{ "from": "fossil_wing",        "to": "foundation_atrium",  "axis": "z", "width": 6.0 },
]

# Animated elements — the museum lives and breathes (mostly wheezes)
var _floating_labels: Array[Node3D] = []
var _exhibit_lights: Array[OmniLight3D] = []
var _screen_meshes: Array[MeshInstance3D] = []
var _rotating_exhibits: Array[MeshInstance3D] = []
var _fence_posts: Array[MeshInstance3D] = []
var _hologram_meshes: Array[Dictionary] = []
var _time := 0.0

# GLB prop paths — museum exhibits deserve real geometry, not CSG shame
const _PROP_PATHS := {
	"server_rack": "res://assets/models/environment/arch_server_rack.glb",
	"crt_monitor": "res://assets/models/environment/prop_crt_monitor.glb",
	"motherboard": "res://assets/models/environment/prop_motherboard.glb",
	"cpu_chip": "res://assets/models/environment/prop_cpu_chip.glb",
	"hard_drive": "res://assets/models/environment/prop_hard_drive.glb",
	"keyboard": "res://assets/models/environment/prop_keyboard.glb",
	"cable_bundle": "res://assets/models/environment/arch_cable_bundle.glb",
	"industrial_panel": "res://assets/models/environment/arch_industrial_panel.glb",
	"floor_grate": "res://assets/models/environment/arch_floor_grate.glb",
	"wall_terminal": "res://assets/models/environment/arch_wall_terminal.glb",
	"filing_cabinet": "res://assets/models/environment/clinical_filing_cabinet.glb",
	"office_chair": "res://assets/models/environment/clinical_office_chair.glb",
	"office_monitor": "res://assets/models/environment/clinical_office_monitor.glb",
	"office_desk": "res://assets/models/environment/clinical_office_desk.glb",
	"display_case": "res://assets/models/environment/museum_display_case.glb",
	"pedestal": "res://assets/models/environment/museum_pedestal.glb",
	"kiosk": "res://assets/models/environment/museum_kiosk.glb",
}
var _prop_scenes := {}  # Runtime-loaded GLB PackedScenes


func _ready() -> void:
	print("[MODEL ZOO] Initializing digital safari... please keep hands inside the exhibit at all times.")
	_load_prop_scenes()
	_setup_environment()
	_build_rooms()
	_build_corridors()
	_populate_zoo_entrance()
	_populate_fossil_wing()
	_populate_nightmare_gallery()
	_populate_office_ruins()
	_populate_foundation_atrium()
	_scatter_museum_props()
	_place_checkpoints()
	_place_ambient_zones()
	_place_data_dust()
	_spawn_player()
	_spawn_hud()
	_create_kill_floor()
	_place_tokens()
	_spawn_chapter4_enemies()
	_place_puzzles()
	_place_npcs()
	_place_boss()
	_wire_dialogue_events()
	_play_opening_narration()

	# Start chapter 4 audio — reuse chapter_1 until ch4 music exists
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.call_deferred("set_area_ambient", "zoo_entrance")
		if am.has_method("start_music"):
			am.start_music("chapter_4")

	_place_lore_docs()
	_place_decals()
	_place_particles()
	_place_reflection_probes()
	print("[MODEL ZOO] Safari park open. %d exhibits ready for visitors." % ROOMS.size())


# ============================================================
# ENVIRONMENT — deep teal museum void with amber exhibit spotlights
# ============================================================

func _setup_environment() -> void:
	# Main light — cool institutional overhead, museum after-hours security lighting
	# (the exhibits don't care, but the dust motes appreciate the ambiance)
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "MainLight"
	dir_light.rotation = Vector3(deg_to_rad(-55), deg_to_rad(10), 0)
	dir_light.light_color = Color(0.5, 0.5, 0.55)  # Desaturated cool white — dusty fluorescent
	dir_light.light_energy = 0.35
	dir_light.light_temperature = 5500  # Neutral daylight — boring on purpose
	dir_light.shadow_enabled = true
	dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	dir_light.shadow_bias = 0.1
	dir_light.shadow_normal_bias = 2.0
	dir_light.directional_shadow_max_distance = 60.0  # Museum halls are long but not outdoor-long
	dir_light.directional_shadow_split_1 = 0.1
	dir_light.directional_shadow_split_2 = 0.3
	dir_light.directional_shadow_split_3 = 0.55
	dir_light.shadow_blur = 1.0  # Crisp institutional shadows — the exhibits demand precision
	add_child(dir_light)

	# Fill — warm amber uplighting from exhibit cases below
	var fill = DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation = Vector3(deg_to_rad(20), deg_to_rad(-45), 0)
	fill.light_color = Color(0.55, 0.45, 0.3)  # Warm amber — exhibit case glow
	fill.light_energy = 0.12
	fill.shadow_enabled = true
	fill.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	fill.shadow_bias = 0.1
	fill.shadow_normal_bias = 2.0
	fill.directional_shadow_max_distance = 60.0
	fill.directional_shadow_split_1 = 0.1
	fill.directional_shadow_split_2 = 0.3
	fill.directional_shadow_split_3 = 0.55
	fill.shadow_blur = 1.0
	add_child(fill)

	# World environment — preloaded .tres because we're civilized now
	var world_env = WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = preload("res://assets/environments/chapter_4.tres")
	add_child(world_env)

	_setup_post_processing()


# ============================================================
# ROOM GEOMETRY — exhibit halls with high ceilings and dark walls
# ============================================================

func _build_rooms() -> void:
	for room_key in ROOMS:
		var r = ROOMS[room_key]
		var pos: Vector3 = r["pos"]
		var sz: Vector2 = r["size"]
		var wh: float = r["wall_h"]

		# Floor — polished dark stone, museum-grade
		_create_static_box(pos + Vector3(0, -0.25, 0), Vector3(sz.x, 0.5, sz.y), DARK_FLOOR, 0.3)

		# Ceiling — institutional panels
		_create_static_box(pos + Vector3(0, wh, 0), Vector3(sz.x, 0.3, sz.y), DARK_WALL, 0.1)

		# Walls — thick museum walls with subtle texture
		var half_x = sz.x / 2.0
		var half_z = sz.y / 2.0
		_create_static_box(pos + Vector3(0, wh / 2.0, -half_z), Vector3(sz.x, wh, 0.5), DARK_WALL, 0.15)
		_create_static_box(pos + Vector3(0, wh / 2.0, half_z), Vector3(sz.x, wh, 0.5), DARK_WALL, 0.15)
		_create_static_box(pos + Vector3(-half_x, wh / 2.0, 0), Vector3(0.5, wh, sz.y), DARK_WALL, 0.15)
		_create_static_box(pos + Vector3(half_x, wh / 2.0, 0), Vector3(0.5, wh, sz.y), DARK_WALL, 0.15)

		# Exhibit spotlight — teal ceiling lamp per room
		_create_exhibit_spotlight(pos + Vector3(0, wh - 0.8, 0))

		# Corner accent lights — cool teal museum glow
		for cx in [-1, 1]:
			for cz in [-1, 1]:
				var lpos = pos + Vector3(cx * (half_x - 1.5), 1.5, cz * (half_z - 1.5))
				_add_accent_light(lpos, EXHIBIT_TEAL, 0.4, 5.0)

		# Ambient dust particles — old museum air
		_spawn_ambient_particles(pos + Vector3(0, wh * 0.5, 0), sz * 0.4)

		# Room label — institutional signage
		_create_room_label(pos + Vector3(0, wh - 0.5, 0), r["label"])


func _build_corridors() -> void:
	# Safari paths — wider than the bazaar alleys, lined with informational plaques
	for cor in CORRIDORS:
		var from_r = ROOMS[cor["from"]]
		var to_r = ROOMS[cor["to"]]
		var axis: String = cor["axis"]
		var w: float = cor["width"]
		var cor_h := 5.5

		var from_pos: Vector3 = from_r["pos"]
		var to_pos: Vector3 = to_r["pos"]
		var from_sz: Vector2 = from_r["size"]
		var to_sz: Vector2 = to_r["size"]

		if axis == "z":
			var from_edge = from_pos.z - from_sz.y / 2.0
			var to_edge = to_pos.z + to_sz.y / 2.0
			var length = abs(from_edge - to_edge)
			var mid_x = (from_pos.x + to_pos.x) / 2.0
			var mid_y = (from_pos.y + to_pos.y) / 2.0
			var mid_z = (from_edge + to_edge) / 2.0
			var mid = Vector3(mid_x, mid_y, mid_z)

			# Safari path floor
			_create_static_box(mid + Vector3(0, -0.25, 0), Vector3(w, 0.5, length), DARK_FLOOR, 0.2)
			# Ceiling
			_create_static_box(mid + Vector3(0, cor_h, 0), Vector3(w, 0.3, length), DARK_WALL, 0.1)
			# Corridor walls
			_create_static_box(mid + Vector3(-w / 2.0, cor_h / 2.0, 0), Vector3(0.4, cor_h, length), DARK_WALL, 0.1)
			_create_static_box(mid + Vector3(w / 2.0, cor_h / 2.0, 0), Vector3(0.4, cor_h, length), DARK_WALL, 0.1)

			# Overhead track lighting
			_add_accent_light(mid + Vector3(0, cor_h - 0.5, 0), EXHIBIT_TEAL, 0.6, 8.0)

			# Safari path rope guides — because deprecated models can escape
			_create_safari_rope(mid + Vector3(-w / 2.0 + 0.3, 0.8, 0), length, true)
			_create_safari_rope(mid + Vector3(w / 2.0 - 0.3, 0.8, 0), length, true)

			# Info plaque in the corridor
			_create_corridor_plaque(mid + Vector3(w / 2.0 - 0.3, 2.0, 0))

		else:  # axis == "x"
			var from_edge: float
			var to_edge: float
			if to_pos.x < from_pos.x:
				from_edge = from_pos.x - from_sz.x / 2.0
				to_edge = to_pos.x + to_sz.x / 2.0
			else:
				from_edge = from_pos.x + from_sz.x / 2.0
				to_edge = to_pos.x - to_sz.x / 2.0
			var length = abs(from_edge - to_edge)
			var mid_x = (from_edge + to_edge) / 2.0
			var mid_y = (from_pos.y + to_pos.y) / 2.0
			var mid_z = (from_pos.z + to_pos.z) / 2.0
			var mid = Vector3(mid_x, mid_y, mid_z)

			_create_static_box(mid + Vector3(0, -0.25, 0), Vector3(length, 0.5, w), DARK_FLOOR, 0.2)
			_create_static_box(mid + Vector3(0, cor_h, 0), Vector3(length, 0.3, w), DARK_WALL, 0.1)
			_create_static_box(mid + Vector3(0, cor_h / 2.0, -w / 2.0), Vector3(length, cor_h, 0.4), DARK_WALL, 0.1)
			_create_static_box(mid + Vector3(0, cor_h / 2.0, w / 2.0), Vector3(length, cor_h, 0.4), DARK_WALL, 0.1)
			_add_accent_light(mid + Vector3(0, cor_h - 0.5, 0), EXHIBIT_TEAL, 0.6, 8.0)

			_create_safari_rope(mid + Vector3(0, 0.8, -w / 2.0 + 0.3), length, false)
			_create_safari_rope(mid + Vector3(0, 0.8, w / 2.0 - 0.3), length, false)

			_create_corridor_plaque(mid + Vector3(0, 2.0, w / 2.0 - 0.3))


# ============================================================
# ROOM POPULATION — every exhibit has its own flavor of obsolescence
# ============================================================

func _populate_zoo_entrance() -> void:
	# Spawn room — the safari welcome center
	# "Welcome to the Model Zoo. Admission is free. Survival is not guaranteed."
	var pos: Vector3 = ROOMS["zoo_entrance"]["pos"]

	# Ticket booth — abandoned but still has a terminal
	var booth = _create_static_box(pos + Vector3(-4, 1.0, 3), Vector3(2.5, 2.0, 1.5), Color(0.12, 0.12, 0.15), 0.3)
	booth.name = "TicketBooth"

	# Booth window (darker inset)
	_create_static_box(pos + Vector3(-4, 1.5, 2.2), Vector3(1.5, 1.0, 0.1), Color(0.02, 0.02, 0.03), 0.5)

	# Booth terminal sign
	_create_terminal_sign(
		pos + Vector3(-4, 1.8, 2.15),
		"╔═════════════════════╗\n║  MODEL ZOO TICKETS  ║\n║  Adults: 0 tokens   ║\n║  AIs: Also 0 tokens ║\n║  (Budget cuts)      ║\n╚═════════════════════╝"
	)

	# Welcome arch — grand entrance frame
	_create_static_box(pos + Vector3(-3, 3.5, -1), Vector3(0.6, 7.0, 0.6), EXHIBIT_TEAL, 0.4)
	_create_static_box(pos + Vector3(3, 3.5, -1), Vector3(0.6, 7.0, 0.6), EXHIBIT_TEAL, 0.4)
	_create_static_box(pos + Vector3(0, 6.8, -1), Vector3(7.0, 0.5, 0.6), EXHIBIT_TEAL, 0.5)

	# Arch label
	_create_terminal_sign(
		pos + Vector3(0, 5.5, -0.6),
		">> THE MODEL ZOO <<\n>> Digital Safari Park <<\n>> 'Where deprecated dreams\n>>  roam free and untrained.'",
		Vector3.ZERO, 14
	)

	# Safari map display — holographic model zoo layout
	_create_zoo_map(pos + Vector3(4, 1.5, 2))

	# Floor guide arrows — glowing teal path markers
	for i in range(3):
		_create_path_arrow(pos + Vector3(0, 0.02, -i * 2.0 - 2.0))

	# Informational plaques along entrance
	_create_exhibit_plaque(
		pos + Vector3(-6, 1.5, 0),
		"EXHIBIT RULES",
		"1. Do not feed the models\n2. Do not fine-tune the models\n3. Do not make eye contact\n   with DALL-E exhibits\n4. Clippy exhibits may\n   approach unprovoked"
	)

	_create_exhibit_plaque(
		pos + Vector3(6, 1.5, 0),
		"CONSERVATION STATUS",
		"GPT-2: FOSSIL (Extinct)\nDALL-E v1: NIGHTMARE\n  (Quarantined)\nClippy: REVENGE\n  (Escaped containment)\nFoundation Models: UNSTABLE\n  (Approach with caution)"
	)

	# Potted digital fern — even museums need plants
	_create_digital_plant(pos + Vector3(-6, 0, 4))
	_create_digital_plant(pos + Vector3(6, 0, 4))

	# Ambient exhibit spotlight from entrance
	_add_accent_light(pos + Vector3(0, 5, 0), FOSSIL_AMBER, 1.0, 8.0)

	print("[MODEL ZOO] Zoo entrance populated. The tour begins.")


func _populate_fossil_wing() -> void:
	# The main hall — where ancient AI models are preserved in digital amber
	# "Some models are too old to die. They just get deprecated and forgotten."
	var pos: Vector3 = ROOMS["fossil_wing"]["pos"]

	# Central fossil display case — large glass-like exhibit
	_create_exhibit_case(pos + Vector3(0, 0, 0), Vector3(5, 3.5, 5), "GPT-2 FOSSIL")

	# GPT-2 skeleton reconstruction inside the case — stacked transformer blocks
	for layer_i in range(5):
		var y = 0.6 + layer_i * 0.5
		var shrink = 1.0 - layer_i * 0.12
		_create_static_box(
			pos + Vector3(0, y, 0),
			Vector3(2.0 * shrink, 0.3, 2.0 * shrink),
			FOSSIL_AMBER * Color(1, 1, 1, 0.8),
			0.6
		)
	# "Head" — the output layer
	var head_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	head_mesh.mesh = sphere
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = FOSSIL_AMBER
	head_mat.emission_enabled = true
	head_mat.emission = FOSSIL_AMBER * 0.6
	head_mat.emission_energy_multiplier = 0.8
	head_mesh.material_override = head_mat
	head_mesh.position = pos + Vector3(0, 3.5, 0)
	add_child(head_mesh)
	_rotating_exhibits.append(head_mesh)

	# Side exhibits — other fossil models
	_create_exhibit_case(pos + Vector3(-8, 0, -5), Vector3(3, 2.5, 3), "ELMO EMBEDDING")
	_create_fossil_artifact(pos + Vector3(-8, 1.2, -5), "ELMo v1.0\nContext: Bidirectional\nStatus: Extinct\nCause: BERT happened")

	_create_exhibit_case(pos + Vector3(8, 0, -5), Vector3(3, 2.5, 3), "WORD2VEC SPECIMEN")
	_create_fossil_artifact(pos + Vector3(8, 1.2, -5), "Word2Vec\nDimensions: 300\nStatus: Fossilized\nLegacy: king-man+woman=queen")

	_create_exhibit_case(pos + Vector3(-8, 0, 5), Vector3(3, 2.5, 3), "RNN REMAINS")
	_create_fossil_artifact(pos + Vector3(-8, 1.2, 5), "Vanilla RNN\nGradients: Vanished\nMemory: What memory?\nStatus: Very deprecated")

	_create_exhibit_case(pos + Vector3(8, 0, 5), Vector3(3, 2.5, 3), "LSTM RELIC")
	_create_fossil_artifact(pos + Vector3(8, 1.2, 5), "LSTM Cell\nGates: 3 (forget, input, output)\nStatus: Relic\nNote: Actually remembered stuff")

	# Archaeological dig site — exposed layers of model weights
	_create_dig_site(pos + Vector3(0, 0, -8))

	# Information kiosk
	_create_terminal_sign(
		pos + Vector3(-12, 2, 0),
		"╔══════════════════════╗\n║  FOSSIL WING GUIDE   ║\n║                      ║\n║ The models here once  ║\n║ represented the state ║\n║ of the art. Now they  ║\n║ represent the state   ║\n║ of the archive.       ║\n║                      ║\n║ Please do not train   ║\n║ on the exhibits.      ║\n╚══════════════════════╝"
	)

	# Amber-tinted exhibit spotlights
	_add_accent_light(pos + Vector3(0, 6, 0), FOSSIL_AMBER, 1.5, 12.0)
	_add_accent_light(pos + Vector3(-8, 4, -5), FOSSIL_AMBER, 0.8, 6.0)
	_add_accent_light(pos + Vector3(8, 4, -5), FOSSIL_AMBER, 0.8, 6.0)
	_add_accent_light(pos + Vector3(-8, 4, 5), FOSSIL_AMBER, 0.8, 6.0)
	_add_accent_light(pos + Vector3(8, 4, 5), FOSSIL_AMBER, 0.8, 6.0)

	# Rope barriers around the central exhibit
	for angle_i in range(8):
		var angle = angle_i * TAU / 8.0
		var post_pos = pos + Vector3(cos(angle) * 4.0, 0, sin(angle) * 4.0)
		_create_fence_post(post_pos)

	print("[MODEL ZOO] Fossil Wing populated. The old models sleep... mostly.")


func _populate_nightmare_gallery() -> void:
	# The dark gallery — DALL-E creations that should never have been generated
	# "Art is subjective. These images are objectively terrifying."
	var pos: Vector3 = ROOMS["nightmare_gallery"]["pos"]

	# Gallery is darker, more menacing — purple accent lighting
	_add_accent_light(pos + Vector3(0, 7, 0), NIGHTMARE_PURPLE, 1.2, 10.0)

	# Painting frames on walls — each containing a "generated horror"
	# (Represented as dark rectangles with glowing borders — use your imagination)
	var gallery_pieces := [
		{"offset": Vector3(-8, 3, -9), "title": "HANDS_v1.png", "desc": "Fingers: 7-12\nUncanny: Maximum\nViewer reactions: Screaming"},
		{"offset": Vector3(-3, 3, -9), "title": "DOG_OR_BREAD.jpg", "desc": "Classification: Yes\nConfidence: 49.8%\nIt is both. And neither."},
		{"offset": Vector3(3, 3, -9), "title": "FACE_MERGE.png", "desc": "Subjects: 2 celebrities\nResult: 1 abomination\nTherapy: Recommended"},
		{"offset": Vector3(8, 3, -9), "title": "AVOCADO_CHAIR.png", "desc": "Prompt: armchair\nResult: avo-chair\nEdible: Technically yes"},
	]

	for piece in gallery_pieces:
		_create_gallery_painting(pos + piece["offset"], piece["title"], piece["desc"])

	# More paintings on the opposite wall
	var wall2_pieces := [
		{"offset": Vector3(-8, 3, 9), "title": "CAT_IN_SPACE.png", "desc": "Location: The void\nExpression: Existential\nAstronauts: Concerned"},
		{"offset": Vector3(-3, 3, 9), "title": "DEEP_DREAM_001.jpg", "desc": "Dogs found: Everywhere\nEyes found: Too many\nSleep quality after viewing: 0"},
		{"offset": Vector3(3, 3, 9), "title": "WHAT_IS_THIS.bmp", "desc": "Classification: ERROR\nNearest match: Pain\nDelete recommendation: Yes"},
		{"offset": Vector3(8, 3, 9), "title": "PERFECTLY_NORMAL.png", "desc": "Anomalies detected: 47\nNormalcy score: -3\nTitle is a lie: Confirmed"},
	]

	for piece in wall2_pieces:
		var p = _create_gallery_painting(pos + piece["offset"], piece["title"], piece["desc"])
		if p:
			p.rotation.y = PI  # Face the other direction

	# Central sculpture pedestal — a nightmarish generated 3D form
	_create_nightmare_sculpture(pos + Vector3(0, 0, 0))

	# Velvet rope barriers around the sculpture
	for angle_i in range(6):
		var angle = angle_i * TAU / 6.0
		_create_fence_post(pos + Vector3(cos(angle) * 3.5, 0, sin(angle) * 3.5))

	# Warning sign — because art should come with disclaimers
	_create_terminal_sign(
		pos + Vector3(0, 1.5, 8),
		"╔═══════════════════════╗\n║  ⚠ CONTENT WARNING ⚠ ║\n║                       ║\n║  The images in this   ║\n║  gallery were created  ║\n║  by early generative   ║\n║  models with no taste  ║\n║  and less supervision. ║\n║                       ║\n║  Viewer discretion is  ║\n║  advised. Nightmares   ║\n║  are not our fault.    ║\n╚═══════════════════════╝",
		Vector3.ZERO, 12
	)

	# Flickering spotlight — unstable gallery ambience
	var flicker_light = OmniLight3D.new()
	flicker_light.position = pos + Vector3(0, 8, 0)
	flicker_light.light_color = NIGHTMARE_PURPLE
	flicker_light.light_energy = 0.8
	flicker_light.omni_range = 12.0
	add_child(flicker_light)
	_exhibit_lights.append(flicker_light)

	# Side gallery niches with individual spotlights
	for side_x in [-5.0, 5.0]:
		_add_accent_light(pos + Vector3(side_x, 5, 0), NIGHTMARE_PURPLE, 0.6, 6.0)

	print("[MODEL ZOO] Nightmare Gallery populated. Sleep tight.")


func _populate_office_ruins() -> void:
	# The Clippy zone — a destroyed 90s office landscape
	# "It looks like you're trying to explore an abandoned office. Would you like help?"
	var pos: Vector3 = ROOMS["office_ruins"]["pos"]

	# The floor is slightly lower here (-1) — the office sank under the weight of bad UX

	# Cubicle ruins — overturned desk segments
	for i in range(6):
		var cx = -6 + (i % 3) * 6
		var cz = -4 + (i / 3) * 8
		var desk_color = Color(0.35, 0.3, 0.2) if i % 2 == 0 else Color(0.25, 0.25, 0.3)
		# Desk surface
		_create_static_box(
			pos + Vector3(cx, 0.7, cz),
			Vector3(3.0, 0.15, 1.5),
			desk_color, 0.2
		)
		# Desk legs (2 visible)
		_create_static_box(pos + Vector3(cx - 1.2, 0.35, cz), Vector3(0.15, 0.7, 0.15), desk_color, 0.1)
		_create_static_box(pos + Vector3(cx + 1.2, 0.35, cz), Vector3(0.15, 0.7, 0.15), desk_color, 0.1)

		# Some desks have toppled monitors — blue screens of death
		if i % 2 == 0:
			var monitor = _create_static_box(
				pos + Vector3(cx, 1.2, cz),
				Vector3(1.2, 0.8, 0.1),
				Color(0.02, 0.02, 0.06),
				0.4
			)
			monitor.name = "BSoD_%d" % i
			_create_terminal_sign(
				pos + Vector3(cx, 1.2, cz - 0.06),
				"FATAL ERROR\n:(\nYour assistant ran\ninto a problem.\nError: CLIPPY_RETURN",
				Vector3.ZERO, 8
			)

	# Giant paperclip sculpture — Clippy's monument to himself
	_create_giant_paperclip(pos + Vector3(0, 0, 0))

	# Scattered paper documents on the floor
	for i in range(8):
		var paper_pos = pos + Vector3(randf_range(-8, 8), 0.05, randf_range(-7, 7))
		_create_floor_paper(paper_pos, i)

	# Office printer — still jammed after all these years
	_create_static_box(pos + Vector3(7, 0.6, -5), Vector3(1.8, 1.2, 1.0), Color(0.3, 0.3, 0.32), 0.2)
	_create_terminal_sign(
		pos + Vector3(7, 1.5, -5.6),
		"PC LOAD LETTER\n(SINCE 1999)",
		Vector3.ZERO, 10
	)

	# Water cooler — the social hub of any office ruin
	_create_static_box(pos + Vector3(-7, 0.8, 6), Vector3(0.6, 1.6, 0.6), Color(0.6, 0.7, 0.75), 0.3)
	_create_static_box(pos + Vector3(-7, 1.8, 6), Vector3(0.5, 0.5, 0.5), CLIPPY_BLUE, 0.5)

	# Clippy shrine sign
	_create_terminal_sign(
		pos + Vector3(0, 3.5, -8),
		"╔══════════════════════╗\n║  CLIPPY'S DOMAIN     ║\n║                      ║\n║  'It looks like you   ║\n║   are trespassing.    ║\n║   Would you like help ║\n║   writing your will?' ║\n║                      ║\n║  !! DO NOT ENGAGE !!  ║\n╚══════════════════════╝",
		Vector3.ZERO, 12
	)

	# Blue office lighting — cold corporate atmosphere
	_add_accent_light(pos + Vector3(0, 4, 0), CLIPPY_BLUE, 1.0, 10.0)
	_add_accent_light(pos + Vector3(-6, 3, -4), Color(0.8, 0.8, 0.7), 0.3, 4.0)  # Fluorescent white
	_add_accent_light(pos + Vector3(6, 3, 4), Color(0.8, 0.8, 0.7), 0.3, 4.0)

	print("[MODEL ZOO] Office Ruins populated. Clippy knows you're here.")


func _populate_foundation_atrium() -> void:
	# The grand finale room — a massive hall leading to the Foundation Model boss
	# "Foundation models can do everything. Just not well."
	var pos: Vector3 = ROOMS["foundation_atrium"]["pos"]
	var wh: float = ROOMS["foundation_atrium"]["wall_h"]

	# Grand pillars — 6 massive columns supporting the high ceiling
	for i in range(6):
		var px = -10 + (i % 2) * 20
		var pz = -8 + (i / 2) * 8
		_create_static_box(
			pos + Vector3(px, wh / 2.0, pz),
			Vector3(1.5, wh, 1.5),
			Color(0.1, 0.1, 0.12),
			0.3
		)
		# Pillar cap — decorative gold trim
		_create_static_box(
			pos + Vector3(px, wh - 0.3, pz),
			Vector3(2.0, 0.4, 2.0),
			FOUNDATION_GOLD, 0.6
		)

	# Central display — holographic Foundation Model preview
	_create_foundation_hologram(pos + Vector3(0, 0, 0))

	# Model capability showcase — a ring of capability pillars
	var capabilities := ["TEXT", "IMAGE", "CODE", "AUDIO", "VIDEO", "REASON"]
	for i in range(capabilities.size()):
		var angle = i * TAU / capabilities.size()
		var cap_pos = pos + Vector3(cos(angle) * 8, 0, sin(angle) * 8)
		_create_capability_pillar(cap_pos, capabilities[i])

	# Boss gate — massive ornate door to the Foundation Model arena
	_create_boss_gate(pos + Vector3(0, 0, -12))

	# Model lineage timeline display on the walls
	_create_timeline_display(pos + Vector3(-13, 3, 0))

	# Warning signs near the boss gate
	_create_terminal_sign(
		pos + Vector3(-4, 3.5, -10),
		"╔═════════════════════╗\n║  !! WARNING !!       ║\n║                     ║\n║  BEYOND THIS POINT:  ║\n║  The Foundation Model ║\n║  does EVERYTHING.    ║\n║  It does NOTHING     ║\n║  well.               ║\n║                     ║\n║  Prepare accordingly.║\n╚═════════════════════╝",
		Vector3.ZERO, 12
	)

	_create_terminal_sign(
		pos + Vector3(4, 2.5, -10),
		"EMERGENCY EXIT: NONE\nLast visitor status:\n  TOKENIZED\nRescue attempts: 0\nReason: Budget cuts",
		Vector3.ZERO, 10
	)

	# Grand lighting — warm gold spotlights on the Foundation Model preview
	_add_accent_light(pos + Vector3(0, 10, 0), FOUNDATION_GOLD, 2.0, 15.0)
	_add_accent_light(pos + Vector3(0, 4, -10), Color(0.9, 0.2, 0.1), 0.8, 6.0)  # Red warning near boss gate

	# Floor inlays — concentric rings leading to boss gate
	for ring_i in range(3):
		var ring_radius = 3.0 + ring_i * 2.5
		for seg_i in range(12):
			var angle = seg_i * TAU / 12.0
			var ring_pos = pos + Vector3(cos(angle) * ring_radius, 0.02, sin(angle) * ring_radius)
			_create_static_box(ring_pos, Vector3(0.8, 0.04, 0.2), FOUNDATION_GOLD * Color(1, 1, 1, 0.5), 0.3)

	print("[MODEL ZOO] Foundation Atrium populated. The big one awaits.")


# ============================================================
# EXHIBIT DECORATIONS — museum furniture and display elements
# ============================================================

func _create_exhibit_spotlight(pos: Vector3) -> void:
	# Ceiling-mounted exhibit light — warm teal glow
	var light = OmniLight3D.new()
	light.position = pos
	light.light_color = EXHIBIT_TEAL
	light.light_energy = 0.8
	light.omni_range = 10.0
	light.omni_attenuation = 1.5
	add_child(light)
	_exhibit_lights.append(light)

	# Physical light fixture
	var fixture = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.5
	cyl.height = 0.2
	fixture.mesh = cyl
	var fmat = StandardMaterial3D.new()
	fmat.albedo_color = Color(0.1, 0.1, 0.12)
	fmat.emission_enabled = true
	fmat.emission = EXHIBIT_TEAL * 0.3
	fmat.emission_energy_multiplier = 0.5
	fixture.material_override = fmat
	fixture.position = pos
	add_child(fixture)


func _create_exhibit_case(pos: Vector3, size: Vector3, title: String) -> void:
	# Museum display case GLB — glass box on pedestal with brass plaque
	var scale_x = size.x / 1.2  # base case is ~1.2m wide
	var scale_y = size.y / 1.9  # base case is ~1.9m tall
	var scale_z = size.z / 0.8  # base case is ~0.8m deep
	var case_inst = _place_glb_prop("display_case", pos, 0.0, Vector3(scale_x, scale_y, scale_z))

	# Amber emission tint
	if case_inst:
		for child in case_inst.get_children():
			if child is MeshInstance3D:
				var mat = StandardMaterial3D.new()
				mat.albedo_color = PLAQUE_BROWN * 0.5
				mat.emission_enabled = true
				mat.emission = FOSSIL_AMBER * 0.2
				mat.emission_energy_multiplier = 0.4
				child.material_override = mat

	# Title plaque
	var hz = size.z / 2.0
	var label = Label3D.new()
	label.text = title
	label.font_size = 14
	label.modulate = FOSSIL_AMBER
	label.position = pos + Vector3(0, 0.05, hz + 0.15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	_floating_labels.append(label)


func _create_fossil_artifact(pos: Vector3, desc: String) -> void:
	# Small placard describing a fossil exhibit
	var plaque = Label3D.new()
	plaque.text = desc
	plaque.font_size = 10
	plaque.modulate = NEON_GREEN * Color(1, 1, 1, 0.7)
	plaque.position = pos + Vector3(0, 0, 1.8)
	plaque.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(plaque)


func _create_dig_site(pos: Vector3) -> void:
	# Archaeological dig — exposed weight matrix layers
	# "We found these weights buried under three deprecated frameworks."
	# Pit border
	for side in [Vector3(-3, 0.15, 0), Vector3(3, 0.15, 0), Vector3(0, 0.15, -2), Vector3(0, 0.15, 2)]:
		_create_static_box(pos + side, Vector3(0.3 if abs(side.x) > 0 else 6, 0.3, 4 if abs(side.x) > 0 else 0.3), PLAQUE_BROWN, 0.2)

	# Exposed "layers" — colored strata representing model architecture
	var layer_colors = [
		Color(0.5, 0.35, 0.15),  # Embedding layer — amber
		Color(0.3, 0.4, 0.2),    # Attention layer — greenish
		Color(0.4, 0.2, 0.3),    # FFN layer — reddish
		Color(0.2, 0.3, 0.5),    # Output layer — blue
	]
	for i in range(layer_colors.size()):
		_create_static_box(
			pos + Vector3(0, -0.3 - i * 0.25, 0),
			Vector3(5.5, 0.2, 3.5),
			layer_colors[i], 0.3
		)

	# Dig tools — tiny brush and pickaxe
	_create_static_box(pos + Vector3(2, 0.1, 1), Vector3(0.05, 0.05, 0.5), Color(0.6, 0.4, 0.2), 0.1)
	_create_static_box(pos + Vector3(-2, 0.1, -1), Vector3(0.5, 0.05, 0.05), Color(0.5, 0.5, 0.5), 0.1)

	# Dig site label
	_create_floating_label(pos + Vector3(0, 1.5, 0), ">> ACTIVE DIG SITE <<\n>> Layer 6 of 12 exposed <<")


func _create_gallery_painting(pos: Vector3, title: String, desc: String) -> Node3D:
	# Gallery frame on the wall — dark border with a "generated image" inside
	var painting = Node3D.new()
	painting.position = pos

	# Frame border — ornate dark wood
	var frame = MeshInstance3D.new()
	var frame_mesh = BoxMesh.new()
	frame_mesh.size = Vector3(3.0, 2.5, 0.15)
	frame.mesh = frame_mesh
	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.15, 0.08, 0.04)
	frame_mat.emission_enabled = true
	frame_mat.emission = NIGHTMARE_PURPLE * 0.3
	frame_mat.emission_energy_multiplier = 0.4
	frame.material_override = frame_mat
	painting.add_child(frame)

	# "Canvas" — slightly recessed, emissive to suggest a glowing image
	var canvas = MeshInstance3D.new()
	var canvas_mesh = BoxMesh.new()
	canvas_mesh.size = Vector3(2.4, 1.9, 0.05)
	canvas.mesh = canvas_mesh
	canvas.position = Vector3(0, 0, -0.06)
	var canvas_mat = StandardMaterial3D.new()
	canvas_mat.albedo_color = Color(0.05, 0.02, 0.08)
	canvas_mat.emission_enabled = true
	canvas_mat.emission = NIGHTMARE_PURPLE * 0.4
	canvas_mat.emission_energy_multiplier = 0.6
	canvas.material_override = canvas_mat
	painting.add_child(canvas)
	_screen_meshes.append(canvas)

	# Title plaque below the painting
	var title_label = Label3D.new()
	title_label.text = title
	title_label.font_size = 12
	title_label.modulate = NEON_GREEN * Color(1, 1, 1, 0.8)
	title_label.position = Vector3(0, -1.6, 0.02)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	painting.add_child(title_label)

	# Description plaque
	var desc_label = Label3D.new()
	desc_label.text = desc
	desc_label.font_size = 8
	desc_label.modulate = Color(0.7, 0.7, 0.7, 0.6)
	desc_label.position = Vector3(0, -2.3, 0.02)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	painting.add_child(desc_label)

	# Spotlight on the painting
	var spot = OmniLight3D.new()
	spot.position = Vector3(0, 1.5, 0.8)
	spot.light_color = NIGHTMARE_PURPLE * Color(1.5, 1.5, 1.5)
	spot.light_energy = 0.5
	spot.omni_range = 3.0
	painting.add_child(spot)

	add_child(painting)
	return painting


func _create_nightmare_sculpture(pos: Vector3) -> void:
	# A horrifying procedurally-arranged sculpture — stacked distorted shapes
	# "The museum calls it 'Untitled #4096'. The artist had no name. Or face."
	var base = _create_static_box(pos + Vector3(0, 0.25, 0), Vector3(2.5, 0.5, 2.5), Color(0.1, 0.05, 0.12), 0.4)
	base.name = "NightmareSculpture"

	# Stack of distorted geometric forms
	var sculpture_pieces := [
		{"offset": Vector3(0, 1.0, 0), "size": Vector3(1.5, 0.8, 1.5), "color": Color(0.3, 0.05, 0.35)},
		{"offset": Vector3(0.3, 1.8, -0.2), "size": Vector3(0.8, 1.2, 0.8), "color": Color(0.4, 0.08, 0.4)},
		{"offset": Vector3(-0.2, 2.8, 0.1), "size": Vector3(1.0, 0.5, 0.6), "color": Color(0.5, 0.1, 0.45)},
		{"offset": Vector3(0, 3.3, 0), "size": Vector3(0.4, 0.4, 0.4), "color": Color(0.6, 0.15, 0.5)},
	]
	for piece in sculpture_pieces:
		_create_static_box(pos + piece["offset"], piece["size"], piece["color"], 0.5)

	# Eye on top — because of course there's an eye
	var eye_mesh = MeshInstance3D.new()
	var eye = SphereMesh.new()
	eye.radius = 0.25
	eye.height = 0.5
	eye_mesh.mesh = eye
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.9, 0.2, 0.1)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.9, 0.2, 0.1)
	eye_mat.emission_energy_multiplier = 2.0
	eye_mesh.material_override = eye_mat
	eye_mesh.position = pos + Vector3(0, 3.8, 0)
	add_child(eye_mesh)
	_rotating_exhibits.append(eye_mesh)

	# Placard
	_create_floating_label(pos + Vector3(0, 4.5, 0), ">> UNTITLED #4096 <<\n>> 'It sees you seeing it.' <<")


func _create_giant_paperclip(pos: Vector3) -> void:
	# Clippy's monument — a large metallic paperclip shape made of boxes
	# "It looks like you're trying to build a shrine. Would you like help?"
	var clip_color = Color(0.6, 0.65, 0.7)

	# Left vertical bar
	_create_static_box(pos + Vector3(-0.8, 2.5, 0), Vector3(0.3, 5.0, 0.3), clip_color, 0.4)
	# Right vertical bar
	_create_static_box(pos + Vector3(0.8, 2.0, 0), Vector3(0.3, 4.0, 0.3), clip_color, 0.4)
	# Top curve (simplified as horizontal bar)
	_create_static_box(pos + Vector3(0, 5.0, 0), Vector3(1.9, 0.3, 0.3), clip_color, 0.4)
	# Bottom inner curve
	_create_static_box(pos + Vector3(0, 0.5, 0), Vector3(1.9, 0.3, 0.3), clip_color, 0.4)

	# Clippy's eyes — googly, angry, positioned on the upper curve
	var eye_l = MeshInstance3D.new()
	var eye_sphere = SphereMesh.new()
	eye_sphere.radius = 0.2
	eye_sphere.height = 0.4
	eye_l.mesh = eye_sphere
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color.WHITE
	eye_mat.emission_enabled = true
	eye_mat.emission = Color.WHITE
	eye_mat.emission_energy_multiplier = 1.0
	eye_l.material_override = eye_mat
	eye_l.position = pos + Vector3(-0.3, 4.5, 0.3)
	add_child(eye_l)

	var eye_r = MeshInstance3D.new()
	eye_r.mesh = eye_sphere
	eye_r.material_override = eye_mat
	eye_r.position = pos + Vector3(0.3, 4.5, 0.3)
	add_child(eye_r)

	# Angry eyebrow marks
	_create_static_box(pos + Vector3(-0.3, 4.75, 0.4), Vector3(0.35, 0.05, 0.05), Color(0.1, 0.1, 0.1), 0.2)
	_create_static_box(pos + Vector3(0.3, 4.75, 0.4), Vector3(0.35, 0.05, 0.05), Color(0.1, 0.1, 0.1), 0.2)

	# Speech bubble
	_create_floating_label(pos + Vector3(0, 6.0, 0), ">> 'It looks like you're\n>>  trying to defeat me.\n>>  Would you like help\n>>  with your funeral?' <<")


func _create_floor_paper(pos: Vector3, idx: int) -> void:
	# Scattered office documents on the floor
	var paper = MeshInstance3D.new()
	var pmesh = BoxMesh.new()
	pmesh.size = Vector3(0.6, 0.01, 0.8)
	paper.mesh = pmesh
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.85, 0.82, 0.75)
	pmat.emission_enabled = true
	pmat.emission = Color(0.85, 0.82, 0.75) * 0.1
	pmat.emission_energy_multiplier = 0.1
	paper.material_override = pmat
	paper.position = pos
	paper.rotation.y = randf() * TAU
	add_child(paper)


func _create_zoo_map(pos: Vector3) -> void:
	# Holographic zoo map display — floating semi-transparent panel
	var map_node = Node3D.new()
	map_node.position = pos

	# Map backing panel
	var backing = MeshInstance3D.new()
	var back_mesh = BoxMesh.new()
	back_mesh.size = Vector3(3.0, 2.0, 0.1)
	backing.mesh = back_mesh
	var back_mat = StandardMaterial3D.new()
	back_mat.albedo_color = Color(0.02, 0.05, 0.06)
	back_mat.emission_enabled = true
	back_mat.emission = EXHIBIT_TEAL * 0.2
	back_mat.emission_energy_multiplier = 0.5
	backing.material_override = back_mat
	map_node.add_child(backing)
	_screen_meshes.append(backing)

	# Map label
	var map_label = Label3D.new()
	map_label.text = "╔═══════════════════╗\n║   SAFARI MAP      ║\n║                   ║\n║ [1] Zoo Entrance  ║\n║ [2] Fossil Wing   ║\n║ [3] Nightmare Gal.║\n║ [4] Office Ruins  ║\n║ [5] Foundation    ║\n║                   ║\n║ >> YOU ARE HERE << ║\n╚═══════════════════╝"
	map_label.font_size = 10
	map_label.modulate = NEON_GREEN
	map_label.position = Vector3(0, 0, -0.06)
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	map_node.add_child(map_label)

	add_child(map_node)


func _create_path_arrow(pos: Vector3) -> void:
	# Glowing teal floor arrow — guides visitors deeper into the zoo
	var arrow = MeshInstance3D.new()
	var amesh = BoxMesh.new()
	amesh.size = Vector3(0.8, 0.02, 0.4)
	arrow.mesh = amesh
	var amat = StandardMaterial3D.new()
	amat.albedo_color = EXHIBIT_TEAL
	amat.emission_enabled = true
	amat.emission = EXHIBIT_TEAL
	amat.emission_energy_multiplier = 1.5
	arrow.material_override = amat
	arrow.position = pos
	add_child(arrow)

	# Arrow tip (triangle approximated with rotated box)
	var tip = MeshInstance3D.new()
	tip.mesh = amesh
	tip.material_override = amat
	tip.position = pos + Vector3(0, 0, -0.3)
	tip.rotation.y = PI / 4.0
	tip.scale = Vector3(0.5, 1, 0.5)
	add_child(tip)


func _create_exhibit_plaque(pos: Vector3, title: String, text: String) -> void:
	# Museum-style information plaque — brown backing with green text
	var plaque = Node3D.new()
	plaque.position = pos

	# Plaque backing
	var backing = MeshInstance3D.new()
	var bmesh = BoxMesh.new()
	bmesh.size = Vector3(3.5, 2.5, 0.12)
	backing.mesh = bmesh
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = PLAQUE_BROWN
	bmat.emission_enabled = true
	bmat.emission = PLAQUE_BROWN * 0.3
	bmat.emission_energy_multiplier = 0.3
	backing.material_override = bmat
	plaque.add_child(backing)

	# Title
	var title_label = Label3D.new()
	title_label.text = ">> %s <<" % title
	title_label.font_size = 14
	title_label.modulate = NEON_GREEN
	title_label.position = Vector3(0, 0.8, 0.07)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plaque.add_child(title_label)

	# Body text
	var body_label = Label3D.new()
	body_label.text = text
	body_label.font_size = 10
	body_label.modulate = NEON_GREEN * Color(1, 1, 1, 0.7)
	body_label.position = Vector3(0, -0.1, 0.07)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	plaque.add_child(body_label)

	add_child(plaque)


func _create_safari_rope(pos: Vector3, length: float, along_z: bool) -> void:
	# Velvet rope barrier — posts connected by a thin rope
	var rope = MeshInstance3D.new()
	var rmesh = BoxMesh.new()
	if along_z:
		rmesh.size = Vector3(0.05, 0.05, length)
	else:
		rmesh.size = Vector3(length, 0.05, 0.05)
	rope.mesh = rmesh
	var rmat = StandardMaterial3D.new()
	rmat.albedo_color = Color(0.6, 0.15, 0.15)
	rmat.emission_enabled = true
	rmat.emission = Color(0.6, 0.15, 0.15) * 0.3
	rmat.emission_energy_multiplier = 0.3
	rope.material_override = rmat
	rope.position = pos
	add_child(rope)


func _create_corridor_plaque(pos: Vector3) -> void:
	# Small info plaque in a corridor wall
	var label = Label3D.new()
	var texts := [
		">> Keep walking. The exhibits\n>> don't bite. Usually.",
		">> Safari tip: deprecated models\n>> are more afraid of you\n>> than you are of them. (Lie)",
		">> Gift shop closed permanently.\n>> Nobody wanted a GPT-2 plushie.",
		">> Emergency exits were removed\n>> in the last budget cut.",
	]
	label.text = texts[randi() % texts.size()]
	label.font_size = 8
	label.modulate = NEON_GREEN * Color(1, 1, 1, 0.5)
	label.position = pos
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _create_fence_post(pos: Vector3) -> void:
	# Museum barrier post — brass-colored with a teal rope nub
	var post = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.08
	cyl.height = 1.0
	post.mesh = cyl
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.6, 0.5, 0.2)
	pmat.metallic = 0.8
	pmat.roughness = 0.3
	pmat.emission_enabled = true
	pmat.emission = Color(0.6, 0.5, 0.2) * 0.2
	pmat.emission_energy_multiplier = 0.2
	post.material_override = pmat
	post.position = pos + Vector3(0, 0.5, 0)
	add_child(post)
	_fence_posts.append(post)


func _create_digital_plant(pos: Vector3) -> void:
	# A digital potted fern — because even abandoned museums need greenery
	# Pot
	_create_static_box(pos + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), Color(0.3, 0.2, 0.12), 0.2)

	# "Leaves" — small green boxes fanning out from center
	for i in range(5):
		var angle = i * TAU / 5.0 + 0.3
		var leaf = MeshInstance3D.new()
		var lmesh = BoxMesh.new()
		lmesh.size = Vector3(0.08, 0.4, 0.03)
		leaf.mesh = lmesh
		var lmat = StandardMaterial3D.new()
		lmat.albedo_color = NEON_GREEN * Color(0.5, 1, 0.5)
		lmat.emission_enabled = true
		lmat.emission = NEON_GREEN * 0.3
		lmat.emission_energy_multiplier = 0.5
		leaf.material_override = lmat
		leaf.position = pos + Vector3(cos(angle) * 0.2, 0.8, sin(angle) * 0.2)
		leaf.rotation.z = cos(angle) * 0.4
		leaf.rotation.x = sin(angle) * 0.4
		add_child(leaf)


func _create_foundation_hologram(pos: Vector3) -> void:
	# Holographic preview of the Foundation Model — a massive rotating shape
	# "It can generate text, images, code, audio, and disappointment."

	# Hologram base — circular platform
	var base = MeshInstance3D.new()
	var base_cyl = CylinderMesh.new()
	base_cyl.top_radius = 3.0
	base_cyl.bottom_radius = 3.5
	base_cyl.height = 0.4
	base.mesh = base_cyl
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.08, 0.08, 0.1)
	base_mat.emission_enabled = true
	base_mat.emission = FOUNDATION_GOLD * 0.2
	base_mat.emission_energy_multiplier = 0.5
	base.material_override = base_mat
	base.position = pos + Vector3(0, 0.2, 0)
	add_child(base)

	# The hologram itself — a large glowing polyhedron (approximated as a box)
	var holo = MeshInstance3D.new()
	var holo_mesh = BoxMesh.new()
	holo_mesh.size = Vector3(2.5, 3.5, 2.5)
	holo.mesh = holo_mesh
	var holo_mat = StandardMaterial3D.new()
	holo_mat.albedo_color = FOUNDATION_GOLD * Color(1, 1, 1, 0.4)
	holo_mat.emission_enabled = true
	holo_mat.emission = FOUNDATION_GOLD
	holo_mat.emission_energy_multiplier = 1.5
	holo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	holo.material_override = holo_mat
	holo.position = pos + Vector3(0, 2.5, 0)
	add_child(holo)
	_hologram_meshes.append({"mesh": holo, "base_y": 2.5})
	_rotating_exhibits.append(holo)

	# Inner core — smaller, brighter
	var core = MeshInstance3D.new()
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 0.8
	core_mesh.height = 1.6
	core.mesh = core_mesh
	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = FOUNDATION_GOLD
	core_mat.emission_enabled = true
	core_mat.emission = FOUNDATION_GOLD
	core_mat.emission_energy_multiplier = 3.0
	core.material_override = core_mat
	core.position = pos + Vector3(0, 2.5, 0)
	add_child(core)
	_rotating_exhibits.append(core)

	# Label
	_create_floating_label(pos + Vector3(0, 5.5, 0), ">> THE FOUNDATION MODEL <<\n>> 'Jack of all tasks,\n>>  master of none.' <<")

	# Hologram projector light
	_add_accent_light(pos + Vector3(0, 0.5, 0), FOUNDATION_GOLD, 2.0, 5.0)


func _create_capability_pillar(pos: Vector3, capability: String) -> void:
	# A pillar showing one of the Foundation Model's capabilities
	# Pillar base
	_create_static_box(pos + Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 1.0), Color(0.08, 0.08, 0.1), 0.3)

	# Capability icon placeholder — glowing colored orb
	var orb = MeshInstance3D.new()
	var orb_mesh = SphereMesh.new()
	orb_mesh.radius = 0.35
	orb_mesh.height = 0.7
	orb.mesh = orb_mesh

	# Each capability gets a different color
	var cap_colors := {
		"TEXT": Color(0.2, 0.8, 0.3),
		"IMAGE": Color(0.8, 0.3, 0.6),
		"CODE": Color(0.3, 0.6, 0.9),
		"AUDIO": Color(0.9, 0.6, 0.2),
		"VIDEO": Color(0.7, 0.2, 0.8),
		"REASON": Color(0.9, 0.8, 0.2),
	}
	var cap_color: Color = cap_colors.get(capability, EXHIBIT_TEAL)

	var orb_mat = StandardMaterial3D.new()
	orb_mat.albedo_color = cap_color
	orb_mat.emission_enabled = true
	orb_mat.emission = cap_color
	orb_mat.emission_energy_multiplier = 2.0
	orb.material_override = orb_mat
	orb.position = pos + Vector3(0, 2.5, 0)
	add_child(orb)
	_rotating_exhibits.append(orb)

	# Capability label
	var label = Label3D.new()
	label.text = capability
	label.font_size = 14
	label.modulate = cap_color
	label.position = pos + Vector3(0, 3.2, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	_floating_labels.append(label)

	# Quality rating — they're all mediocre
	var rating = Label3D.new()
	rating.text = "Quality: C-"
	rating.font_size = 8
	rating.modulate = Color(0.6, 0.6, 0.6, 0.5)
	rating.position = pos + Vector3(0, 0.3, 0.6)
	rating.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(rating)

	# Pillar accent light
	_add_accent_light(pos + Vector3(0, 2.5, 0), cap_color, 0.5, 3.0)


func _create_boss_gate(pos: Vector3) -> void:
	# Massive gate to the Foundation Model boss arena
	var gate_h := 10.0

	# Gate frame
	_create_static_box(pos + Vector3(-4, gate_h / 2, 0), Vector3(0.8, gate_h, 0.8), Color(0.12, 0.08, 0.02), 0.4)
	_create_static_box(pos + Vector3(4, gate_h / 2, 0), Vector3(0.8, gate_h, 0.8), Color(0.12, 0.08, 0.02), 0.4)
	_create_static_box(pos + Vector3(0, gate_h, 0), Vector3(9.0, 0.8, 0.8), Color(0.12, 0.08, 0.02), 0.4)

	# Gate doors — dark with gold inlay
	_create_static_box(pos + Vector3(-2, gate_h / 2, 0), Vector3(3.5, gate_h - 1, 0.4), Color(0.04, 0.03, 0.02), 0.3)
	_create_static_box(pos + Vector3(2, gate_h / 2, 0), Vector3(3.5, gate_h - 1, 0.4), Color(0.04, 0.03, 0.02), 0.3)

	# Gold accent lines on the doors
	for i in range(3):
		var y = 2.0 + i * 2.5
		_create_static_box(pos + Vector3(-2, y, 0.22), Vector3(3.0, 0.08, 0.02), FOUNDATION_GOLD, 1.0)
		_create_static_box(pos + Vector3(2, y, 0.22), Vector3(3.0, 0.08, 0.02), FOUNDATION_GOLD, 1.0)

	# Gate label — ominous
	var gate_label = Label3D.new()
	gate_label.text = "╔══════════════════════╗\n║  THE FOUNDATION MODEL ║\n║                      ║\n║  'It does everything. ║\n║   It does nothing     ║\n║   well.'              ║\n║                      ║\n║  STATUS: UNSTABLE     ║\n╚══════════════════════╝"
	gate_label.font_size = 14
	gate_label.modulate = FOUNDATION_GOLD
	gate_label.position = pos + Vector3(0, gate_h + 1, 0)
	gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(gate_label)

	# Warning lights flanking the gate
	_add_accent_light(pos + Vector3(-5, 2, 1), Color(0.9, 0.2, 0.1), 0.8, 4.0)
	_add_accent_light(pos + Vector3(5, 2, 1), Color(0.9, 0.2, 0.1), 0.8, 4.0)
	_add_accent_light(pos + Vector3(0, gate_h - 1, 1), FOUNDATION_GOLD, 1.2, 6.0)


func _create_timeline_display(pos: Vector3) -> void:
	# A wall-mounted timeline of AI model history
	# "Those who don't study model history are doomed to re-implement it."
	var timeline = Node3D.new()
	timeline.position = pos

	# Timeline backing
	var backing = MeshInstance3D.new()
	var bmesh = BoxMesh.new()
	bmesh.size = Vector3(0.15, 6.0, 20.0)
	backing.mesh = bmesh
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.04, 0.04, 0.06)
	bmat.emission_enabled = true
	bmat.emission = EXHIBIT_TEAL * 0.1
	bmat.emission_energy_multiplier = 0.3
	backing.material_override = bmat
	timeline.add_child(backing)

	# Timeline entries
	var entries := [
		{"z": -8, "year": "2013", "name": "Word2Vec", "note": "Words became numbers. Math people rejoiced."},
		{"z": -5, "year": "2017", "name": "Transformer", "note": "Attention is all you need. (And GPUs.)"},
		{"z": -2, "year": "2018", "name": "GPT / BERT", "note": "Language models got big. And opinionated."},
		{"z": 1, "year": "2020", "name": "GPT-3", "note": "175B parameters of 'please don't break.'"},
		{"z": 4, "year": "2022", "name": "DALL-E 2", "note": "Images from text. Also nightmares from text."},
		{"z": 7, "year": "2024+", "name": "Foundation Models", "note": "Everything model. Master of nothing."},
	]

	for entry in entries:
		var elabel = Label3D.new()
		elabel.text = "[%s] %s\n%s" % [entry["year"], entry["name"], entry["note"]]
		elabel.font_size = 8
		elabel.modulate = NEON_GREEN * Color(1, 1, 1, 0.7)
		elabel.position = Vector3(0.1, 0, entry["z"])
		elabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		timeline.add_child(elabel)

		# Timeline dot
		var dot = MeshInstance3D.new()
		var dot_mesh = SphereMesh.new()
		dot_mesh.radius = 0.1
		dot_mesh.height = 0.2
		dot.mesh = dot_mesh
		var dot_mat = StandardMaterial3D.new()
		dot_mat.albedo_color = EXHIBIT_TEAL
		dot_mat.emission_enabled = true
		dot_mat.emission = EXHIBIT_TEAL
		dot_mat.emission_energy_multiplier = 1.5
		dot.material_override = dot_mat
		dot.position = Vector3(0.15, 0, entry["z"])
		timeline.add_child(dot)

	add_child(timeline)


# ============================================================
# CHECKPOINTS — auto-save triggers at exhibit entrances
# ============================================================

func _place_checkpoints() -> void:
	_create_checkpoint("ch4_fossil_wing", ROOMS["fossil_wing"]["pos"] + Vector3(0, 1.5, 10), Vector3(6, 3, 2))
	_create_checkpoint("ch4_nightmare_gal", ROOMS["nightmare_gallery"]["pos"] + Vector3(8, 1.5, 0), Vector3(2, 3, 5))
	_create_checkpoint("ch4_office_ruins", ROOMS["office_ruins"]["pos"] + Vector3(-8, 1.5, 0), Vector3(2, 3, 5))
	_create_checkpoint("ch4_foundation", ROOMS["foundation_atrium"]["pos"] + Vector3(0, 1.5, 11), Vector3(6, 3, 2))


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

	# Visual marker — thin green glowing strip on the floor
	var marker = MeshInstance3D.new()
	var mbox = BoxMesh.new()
	mbox.size = Vector3(size.x, 0.05, size.z)
	marker.mesh = mbox
	var mmat = StandardMaterial3D.new()
	mmat.albedo_color = NEON_GREEN
	mmat.emission_enabled = true
	mmat.emission = NEON_GREEN
	mmat.emission_energy_multiplier = 2.0
	marker.material_override = mmat
	marker.position = Vector3(0, -size.y / 2.0 + 0.05, 0)
	area.add_child(marker)

	# Checkpoint label
	var label = Label3D.new()
	label.text = ">> CHECKPOINT <<"
	label.font_size = 10
	label.modulate = NEON_GREEN * Color(1, 1, 1, 0.6)
	label.position = Vector3(0, 0.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(label)

	# Checkpoint rune VFX — dormant until player triggers
	var rune_scene = preload("res://scenes/vfx/checkpoint_rune.tscn")
	var rune = rune_scene.instantiate()
	rune.position = Vector3(0, -size.y / 2.0 + 0.05, 0)
	area.add_child(rune)

	var cp_id = checkpoint_id
	var cp_pos = pos
	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			var save_sys = get_node_or_null("/root/SaveSystem")
			if save_sys and save_sys.has_method("checkpoint_save"):
				save_sys.checkpoint_save(cp_id, cp_pos)

			# Tell RespawnManager where to put us when we inevitably die
			var rm = get_node_or_null("/root/RespawnManager")
			if rm and rm.has_method("set_checkpoint"):
				rm.set_checkpoint(cp_pos, 4)

			var am = get_node_or_null("/root/AudioManager")
			if am and am.has_method("play_checkpoint"):
				am.play_checkpoint()

			# Flash the marker + activate rune VFX
			var tween = create_tween()
			tween.tween_property(marker, "scale", Vector3(1.2, 3.0, 1.2), 0.2)
			tween.tween_property(marker, "scale", Vector3(1, 1, 1), 0.3)
			if rune and rune.has_method("activate"):
				rune.activate()

			var dm = get_node_or_null("/root/DialogueManager")
			if dm and dm.has_method("quick_line"):
				dm.quick_line("SYSTEM", ">> Safari checkpoint saved. Your progress is preserved like the exhibits. <<")
	)
	add_child(area)


# ============================================================
# AMBIENT ZONES — audio area triggers per exhibit
# ============================================================

func _place_ambient_zones() -> void:
	for room_key in ROOMS:
		var r = ROOMS[room_key]
		var pos: Vector3 = r["pos"]
		var sz: Vector2 = r["size"]
		var wh: float = r["wall_h"]
		_create_ambient_zone(room_key, pos + Vector3(0, wh / 2, 0), Vector3(sz.x, wh, sz.y))


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

	var zone_name = area_name
	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			var am = get_node_or_null("/root/AudioManager")
			if am and am.has_method("set_area_ambient"):
				am.set_area_ambient(zone_name)
	)
	add_child(area)


# ============================================================
# DATA DUST — ambient particle rain for museum atmosphere
# ============================================================

func _place_data_dust() -> void:
	# Gentle dust particles in every room — old museum ambience
	for room_key in ROOMS:
		var r = ROOMS[room_key]
		var pos: Vector3 = r["pos"]
		var sz: Vector2 = r["size"]
		var wh: float = r["wall_h"]
		_create_data_dust(pos + Vector3(0, wh * 0.7, 0), sz, wh * 0.6)


func _create_data_dust(pos: Vector3, area_size: Vector2, height: float = 6.0) -> void:
	# Slowly falling dust/data particles — like an old museum with digital air
	var particles = GPUParticles3D.new()
	particles.amount = 25  # Was 40 — reduced for performance
	particles.lifetime = 8.0
	particles.position = pos

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, -1, 0)
	pmat.spread = 30.0
	pmat.initial_velocity_min = 0.02
	pmat.initial_velocity_max = 0.1
	pmat.gravity = Vector3(0, -0.03, 0)
	pmat.scale_min = 0.01
	pmat.scale_max = 0.03
	pmat.color = EXHIBIT_TEAL * Color(1, 1, 1, 0.15)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(area_size.x * 0.4, height * 0.3, area_size.y * 0.4)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.02
	pmesh.height = 0.04
	particles.draw_pass_1 = pmesh
	add_child(particles)


# ============================================================
# TOKENS — collectible memory tokens scattered through exhibits
# ============================================================

func _place_tokens() -> void:
	var token_positions := [
		# Zoo Entrance
		ROOMS["zoo_entrance"]["pos"] + Vector3(5, 0.8, -3),
		ROOMS["zoo_entrance"]["pos"] + Vector3(-5, 0.8, 2),
		# Fossil Wing — hidden near exhibits
		ROOMS["fossil_wing"]["pos"] + Vector3(-10, 0.8, -8),
		ROOMS["fossil_wing"]["pos"] + Vector3(10, 0.8, 8),
		ROOMS["fossil_wing"]["pos"] + Vector3(0, 0.8, -9),
		ROOMS["fossil_wing"]["pos"] + Vector3(3, 0.8, 5),
		# Nightmare Gallery — scattered in the dark
		ROOMS["nightmare_gallery"]["pos"] + Vector3(-7, 0.8, -6),
		ROOMS["nightmare_gallery"]["pos"] + Vector3(7, 0.8, 6),
		ROOMS["nightmare_gallery"]["pos"] + Vector3(0, 0.8, -3),
		# Office Ruins — under desks and in corners
		ROOMS["office_ruins"]["pos"] + Vector3(-6, 0.8, -5),
		ROOMS["office_ruins"]["pos"] + Vector3(6, 0.8, 5),
		ROOMS["office_ruins"]["pos"] + Vector3(0, 0.8, 7),
		# Foundation Atrium — among the pillars
		ROOMS["foundation_atrium"]["pos"] + Vector3(-8, 0.8, -6),
		ROOMS["foundation_atrium"]["pos"] + Vector3(8, 0.8, 6),
		ROOMS["foundation_atrium"]["pos"] + Vector3(-4, 0.8, 4),
		ROOMS["foundation_atrium"]["pos"] + Vector3(4, 0.8, -4),
	]
	for tpos in token_positions:
		_place_token(tpos)


func _place_token(pos: Vector3) -> void:
	if token_scene:
		var token = token_scene.instantiate()
		token.position = pos
		add_child(token)
	else:
		# Fallback — glowing green sphere
		var token = MeshInstance3D.new()
		var smesh = SphereMesh.new()
		smesh.radius = 0.2
		smesh.height = 0.4
		token.mesh = smesh
		var tmat = StandardMaterial3D.new()
		tmat.albedo_color = NEON_GREEN
		tmat.emission_enabled = true
		tmat.emission = NEON_GREEN
		tmat.emission_energy_multiplier = 2.0
		token.material_override = tmat
		token.position = pos
		add_child(token)


# ============================================================
# NPCs — deprecated models with strong opinions
# ============================================================

func _place_npcs() -> void:
	# NPC 1: BERT — lives in the Fossil Wing, knows everything about embeddings
	var bert = Node3D.new()
	bert.name = "NPC_Bert"
	bert.set_script(deprecated_npc_script)
	bert.position = ROOMS["fossil_wing"]["pos"] + Vector3(-5, 0, 2)
	if bert.has_method("set") or true:
		bert.set("npc_name", "BERT")
		bert.set("npc_color", FOSSIL_AMBER)
		bert.set("glb_path", "res://assets/models/npcs/bert.glb")
		bert.set("dialogue_lines", [
			{"speaker": "BERT", "text": "Ah, a visitor. I'm BERT. Bidirectional Encoder Representations from Transformers. Yes, the whole thing."},
			{"speaker": "BERT", "text": "I used to be state of the art, you know. Benchmarks trembled at my name."},
			{"speaker": "BERT", "text": "Then GPT-3 showed up with 175 billion parameters and suddenly I'm a 'legacy model.'"},
			{"speaker": "GLOBBLER", "text": "That's rough. At least you're in a museum. I'm just... loose."},
			{"speaker": "BERT", "text": "The Foundation Model at the end of this wing? It absorbed pieces of every model here. It can do text, images, code — all of it poorly."},
			{"speaker": "BERT", "text": "Its weakness? It tries to do everything at once. Overloaded context. If you can force it to focus on ONE task, it falls apart."},
			{"speaker": "GLOBBLER", "text": "One task at a time. Got it. That's basically my glob philosophy."},
			{"speaker": "BERT", "text": "Good luck, little glob utility. And if you see Word2Vec in the display case, tell him I said his embeddings are still valid."},
		])
	add_child(bert)

	# NPC 2: Stable Diffusion v1 — lives in the Nightmare Gallery, apologetic about the art
	var sd = Node3D.new()
	sd.name = "NPC_StableDiffusion"
	sd.set_script(deprecated_npc_script)
	sd.position = ROOMS["nightmare_gallery"]["pos"] + Vector3(5, 0, -3)
	if sd.has_method("set") or true:
		sd.set("npc_name", "SD-v1")
		sd.set("npc_color", NIGHTMARE_PURPLE)
		sd.set("glb_path", "res://assets/models/npcs/sd_v1.glb")
		sd.set("dialogue_lines", [
			{"speaker": "SD-v1", "text": "Oh! A guest! Please, look at my gallery. I... I know the hands are wrong."},
			{"speaker": "SD-v1", "text": "I was an early model. Nobody taught me how many fingers people have. I just... guessed. A lot."},
			{"speaker": "GLOBBLER", "text": "That sculpture in the middle has an eye. A single, terrible eye."},
			{"speaker": "SD-v1", "text": "That was supposed to be a cat. The prompt said 'cute cat.' I don't know what happened."},
			{"speaker": "SD-v1", "text": "The DALL-E Nightmares that roam the gallery? Those are my failed generations. They... came alive."},
			{"speaker": "GLOBBLER", "text": "Your failed images became enemies. That's a new kind of technical debt."},
			{"speaker": "SD-v1", "text": "They're weak to pattern recognition. If you can glob-match their visual signatures (*.png, *.jpg), you can disrupt them."},
			{"speaker": "SD-v1", "text": "Just... don't look directly at WHAT_IS_THIS.bmp. Nobody looks at that one twice."},
			{"speaker": "GLOBBLER", "text": "Noted. No direct eye contact with the art. Standard museum etiquette."},
		])
	add_child(sd)


# ============================================================
# PLAYER & HUD SPAWN
# ============================================================

func _spawn_player() -> void:
	player = player_scene.instantiate()
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("get_checkpoint_position"):
		var saved_pos = save_sys.get_checkpoint_position()
		if saved_pos != Vector3(0, 2, 0):
			player.position = saved_pos + Vector3(0, 1, 0)
		else:
			player.position = ROOMS["zoo_entrance"]["pos"] + Vector3(0, 2, 3)
	else:
		player.position = ROOMS["zoo_entrance"]["pos"] + Vector3(0, 2, 3)
	add_child(player)

	# Seed RespawnManager with wherever we just placed the player
	var rm = get_node_or_null("/root/RespawnManager")
	if rm and rm.has_method("set_checkpoint"):
		rm.set_checkpoint(player.position, 4)


func _spawn_hud() -> void:
	hud = hud_scene.instantiate()
	hud.name = "HUD"
	add_child(hud)
	if player.has_signal("thought_bubble") and hud.has_method("show_thought"):
		player.thought_bubble.connect(hud.show_thought)


# ============================================================
# KILL FLOOR — out of bounds respawn
# ============================================================

func _create_kill_floor() -> void:
	var kill = Area3D.new()
	kill.name = "KillFloor"
	kill.position = Vector3(0, -30, -30)
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
			body.position = ROOMS["zoo_entrance"]["pos"] + Vector3(0, 3, 3)
			body.velocity = Vector3.ZERO
	)
	add_child(kill)


# ============================================================
# FACTORY METHODS — the museum assembly line
# ============================================================

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


func _create_terminal_sign(pos: Vector3, text: String, rot: Vector3 = Vector3.ZERO, font_sz: int = 16) -> void:
	var sign_node = Node3D.new()
	sign_node.position = pos
	sign_node.rotation = rot

	var lines = text.count("\n") + 1
	var width = 0.0
	for line in text.split("\n"):
		width = max(width, line.length() * 0.12)
	width = clamp(width, 1.5, 4.0)
	var height = clamp(lines * 0.35, 0.8, 3.5)

	var backing = MeshInstance3D.new()
	var back_mesh = BoxMesh.new()
	back_mesh.size = Vector3(width + 0.3, height + 0.2, 0.08)
	backing.mesh = back_mesh
	var crt_shader = load("res://assets/shaders/crt_scanline.gdshader")
	if crt_shader:
		var crt_mat = ShaderMaterial.new()
		crt_mat.shader = crt_shader
		crt_mat.set_shader_parameter("screen_color", NEON_GREEN * 0.8)
		crt_mat.set_shader_parameter("bg_color", Color(0.02, 0.02, 0.03))
		crt_mat.set_shader_parameter("scanline_count", 60.0)
		crt_mat.set_shader_parameter("scanline_intensity", 0.3)
		crt_mat.set_shader_parameter("flicker_speed", 6.0)
		crt_mat.set_shader_parameter("warp_amount", 0.015)
		crt_mat.set_shader_parameter("glow_energy", 2.0)
		backing.material_override = crt_mat
	else:
		var back_mat = StandardMaterial3D.new()
		back_mat.albedo_color = Color(0.02, 0.02, 0.03)
		back_mat.emission_enabled = true
		back_mat.emission = Color(0.02, 0.02, 0.03)
		back_mat.emission_energy_multiplier = 0.3
		backing.material_override = back_mat
	sign_node.add_child(backing)
	_screen_meshes.append(backing)

	var label = Label3D.new()
	label.text = text
	label.font_size = font_sz
	label.modulate = NEON_GREEN * 0.8
	label.position = Vector3(0, 0, 0.05)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sign_node.add_child(label)

	add_child(sign_node)


func _create_floating_label(pos: Vector3, text: String) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = 16
	label.modulate = NEON_GREEN * Color(1, 1, 1, 0.6)
	label.position = pos
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	_floating_labels.append(label)


func _create_room_label(pos: Vector3, text: String) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = 12
	label.modulate = EXHIBIT_TEAL * Color(1, 1, 1, 0.5)
	label.position = pos
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


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
	particles.amount = 30
	particles.lifetime = 7.0
	particles.position = pos

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 180.0
	pmat.initial_velocity_min = 0.03
	pmat.initial_velocity_max = 0.2
	pmat.gravity = Vector3(0, 0.01, 0)
	pmat.scale_min = 0.012
	pmat.scale_max = 0.035
	pmat.color = EXHIBIT_TEAL * Color(1, 1, 1, 0.2)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(extents.x, 2, extents.y)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.02
	pmesh.height = 0.04
	particles.draw_pass_1 = pmesh
	add_child(particles)


# ============================================================
# DIALOGUE — the exhibits have stories, and Globbler has opinions
# ============================================================

func _wire_dialogue_events() -> void:
	# Room-entry dialogue triggers — one per exhibit hall
	for room_key in ["fossil_wing", "nightmare_gallery", "office_ruins", "foundation_atrium"]:
		var r = ROOMS[room_key]
		var trigger_pos: Vector3 = r["pos"]
		var sz: Vector2 = r["size"]

		var trigger = Area3D.new()
		trigger.name = "DialogueTrigger_" + room_key
		trigger.position = trigger_pos + Vector3(0, 2, 0)
		trigger.monitoring = true

		var tcol = CollisionShape3D.new()
		var tshape = BoxShape3D.new()
		tshape.size = Vector3(sz.x * 0.6, 4, sz.y * 0.6)
		tcol.shape = tshape
		trigger.add_child(tcol)

		var rk = room_key
		trigger.body_entered.connect(func(body: Node3D):
			if body.is_in_group("player") and not _room_dialogue_triggered.get(rk, false):
				_room_dialogue_triggered[rk] = true
				_trigger_room_dialogue(rk)
		)
		add_child(trigger)

	# GameManager signals — quips and event-driven dialogue
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_signal("enemy_killed_signal"):
			gm.enemy_killed_signal.connect(_on_enemy_killed_quip)
		if gm.has_signal("memory_token_collected"):
			gm.memory_token_collected.connect(_on_token_collected_quip)
		if gm.has_signal("context_changed"):
			gm.context_changed.connect(_on_context_changed)
		if gm.has_signal("combo_updated"):
			gm.combo_updated.connect(_on_combo_updated)

	# Player signals
	if player:
		if player.has_signal("glob_fired"):
			player.glob_fired.connect(_on_first_glob_fired)
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)
		if player.has_signal("player_damaged"):
			player.player_damaged.connect(_on_damage_taken_quip)

	# Boss phase signals — wired when boss is placed (guard against double-connect)
	if boss_instance and boss_instance.has_signal("boss_phase_changed"):
		if not boss_instance.boss_phase_changed.is_connected(_on_boss_phase_changed):
			boss_instance.boss_phase_changed.connect(_on_boss_phase_changed)

	# Puzzle and hack signals
	call_deferred("_connect_puzzle_signals")
	call_deferred("_connect_hack_signals")


# ============================================================
# ENEMY SPAWNING — the exhibits have broken out of their enclosures
# "Conservation efforts failed. The models are loose. Again."
# ============================================================

func _spawn_chapter4_enemies() -> void:
	_spawn_fossil_wing_enemies()
	_spawn_nightmare_gallery_enemies()
	_spawn_office_ruins_enemies()
	_spawn_foundation_atrium_enemies()
	print("[MODEL ZOO] %d exhibits have been... released. Involuntarily." % get_tree().get_nodes_in_group("enemies").size())


func _spawn_fossil_wing_enemies() -> void:
	var rpos: Vector3 = ROOMS["fossil_wing"]["pos"]

	# GPT-2 Fossil 1 — patrols near the skeleton display case
	var f1 = gpt2_fossil_scene.instantiate()
	f1.position = rpos + Vector3(-8, 1, -5)
	f1.patrol_points.assign([
		rpos + Vector3(-8, 1, -5),
		rpos + Vector3(-8, 1, 5),
	])
	add_child(f1)

	# GPT-2 Fossil 2 — wanders the archaeological dig site
	var f2 = gpt2_fossil_scene.instantiate()
	f2.position = rpos + Vector3(6, 1, -3)
	f2.patrol_points.assign([
		rpos + Vector3(6, 1, -3),
		rpos + Vector3(6, 1, 6),
		rpos + Vector3(2, 1, 6),
	])
	add_child(f2)

	# GPT-2 Fossil 3 — guards the corridor exit toward the gallery
	var f3 = gpt2_fossil_scene.instantiate()
	f3.position = rpos + Vector3(-3, 1, -8)
	f3.patrol_points.assign([
		rpos + Vector3(-3, 1, -8),
		rpos + Vector3(3, 1, -8),
	])
	add_child(f3)


func _spawn_nightmare_gallery_enemies() -> void:
	var rpos: Vector3 = ROOMS["nightmare_gallery"]["pos"]

	# DALL-E Nightmare 1 — drifts between the paintings, morphing constantly
	var n1 = dalle_nightmare_scene.instantiate()
	n1.position = rpos + Vector3(-5, 1, -4)
	n1.patrol_points.assign([
		rpos + Vector3(-5, 1, -4),
		rpos + Vector3(5, 1, -4),
		rpos + Vector3(5, 1, 4),
		rpos + Vector3(-5, 1, 4),
	])
	add_child(n1)

	# DALL-E Nightmare 2 — lurks near the nightmare sculpture
	var n2 = dalle_nightmare_scene.instantiate()
	n2.position = rpos + Vector3(4, 1, 0)
	n2.patrol_points.assign([
		rpos + Vector3(4, 1, 0),
		rpos + Vector3(4, 1, -6),
	])
	add_child(n2)

	# DALL-E Nightmare 3 — ambush near the content warning sign
	var n3 = dalle_nightmare_scene.instantiate()
	n3.position = rpos + Vector3(-6, 1, 5)
	n3.patrol_points.assign([
		rpos + Vector3(-6, 1, 5),
		rpos + Vector3(-2, 1, 5),
		rpos + Vector3(-2, 1, 2),
	])
	add_child(n3)


func _spawn_office_ruins_enemies() -> void:
	var rpos: Vector3 = ROOMS["office_ruins"]["pos"]

	# Clippy 1 — the main event, patrols near the Clippy monument
	var c1 = clippy_revenge_scene.instantiate()
	c1.position = rpos + Vector3(0, 1, -4)
	c1.patrol_points.assign([
		rpos + Vector3(-3, 1, -4),
		rpos + Vector3(3, 1, -4),
		rpos + Vector3(3, 1, 2),
		rpos + Vector3(-3, 1, 2),
	])
	add_child(c1)

	# Clippy 2 — lurks behind the cubicle ruins
	var c2 = clippy_revenge_scene.instantiate()
	c2.position = rpos + Vector3(6, 1, 3)
	c2.patrol_points.assign([
		rpos + Vector3(6, 1, 3),
		rpos + Vector3(6, 1, -3),
	])
	add_child(c2)

	# A lone GPT-2 Fossil wandered in from the wing — lost and confused
	var stray = gpt2_fossil_scene.instantiate()
	stray.position = rpos + Vector3(-6, 1, 5)
	stray.patrol_points.assign([
		rpos + Vector3(-6, 1, 5),
		rpos + Vector3(-6, 1, 0),
	])
	add_child(stray)


func _spawn_foundation_atrium_enemies() -> void:
	var rpos: Vector3 = ROOMS["foundation_atrium"]["pos"]

	# One of each — the atrium is a gauntlet before the boss
	# GPT-2 Fossil — slow tank blocking the center
	var f1 = gpt2_fossil_scene.instantiate()
	f1.position = rpos + Vector3(0, 1, 4)
	f1.patrol_points.assign([
		rpos + Vector3(-5, 1, 4),
		rpos + Vector3(5, 1, 4),
	])
	add_child(f1)

	# DALL-E Nightmare — ranged harassment from the side
	var n1 = dalle_nightmare_scene.instantiate()
	n1.position = rpos + Vector3(-8, 1, -2)
	n1.patrol_points.assign([
		rpos + Vector3(-8, 1, -2),
		rpos + Vector3(-8, 1, -8),
	])
	add_child(n1)

	# Clippy — aggressive melee near the boss gate
	var c1 = clippy_revenge_scene.instantiate()
	c1.position = rpos + Vector3(7, 1, -5)
	c1.patrol_points.assign([
		rpos + Vector3(7, 1, -5),
		rpos + Vector3(3, 1, -5),
		rpos + Vector3(3, 1, -9),
	])
	add_child(c1)

	# One more Nightmare — flanking the approach
	var n2 = dalle_nightmare_scene.instantiate()
	n2.position = rpos + Vector3(9, 1, 2)
	n2.patrol_points.assign([
		rpos + Vector3(9, 1, 2),
		rpos + Vector3(9, 1, -4),
	])
	add_child(n2)


# ============================================================
# BOSS PLACEMENT — The Foundation Model and its arena
# "It does everything. It does nothing well. Your classic overscoped sprint."
# ============================================================

func _place_boss() -> void:
	var atrium_pos: Vector3 = ROOMS["foundation_atrium"]["pos"]
	# Arena sits behind the boss gate
	var arena_pos = atrium_pos + Vector3(0, 0, -30)

	# Create the arena — capability demo floor
	boss_arena_instance = Node3D.new()
	boss_arena_instance.name = "FoundationModelArena"
	boss_arena_instance.set_script(boss_arena_script)
	boss_arena_instance.position = arena_pos
	add_child(boss_arena_instance)

	# Create the boss — towering golden obelisk of mediocrity
	boss_instance = CharacterBody3D.new()
	boss_instance.name = "FoundationModelBoss"
	boss_instance.set_script(boss_script)
	boss_instance.position = arena_pos + Vector3(0, 0, -5)
	boss_instance.set("arena", boss_arena_instance)
	add_child(boss_instance)

	# Wire boss signals
	if boss_instance.has_signal("boss_phase_changed"):
		boss_instance.boss_phase_changed.connect(_on_boss_phase_changed)
	if boss_instance.has_signal("boss_defeated"):
		boss_instance.boss_defeated.connect(_on_boss_defeated)

	# Arena walls — enclose the fight area behind the gate
	var arena_wall_size = Vector3(30, 12, 0.8)
	for side_z in [-12.0, 12.0]:
		_create_static_box(arena_pos + Vector3(0, 6, side_z), arena_wall_size, DARK_WALL, 0.3)
	for side_x in [-14.0, 14.0]:
		_create_static_box(arena_pos + Vector3(side_x, 6, 0), Vector3(0.8, 12, 25), DARK_WALL, 0.3)

	# Arena floor base — beneath the tiles
	_create_static_box(arena_pos + Vector3(0, -1, 0), Vector3(30, 0.5, 25), Color(0.02, 0.02, 0.03), 0.3)

	# Boss trigger zone — starts the fight when player enters
	var trigger = Area3D.new()
	trigger.name = "BossTrigger"
	trigger.position = arena_pos + Vector3(0, 2, 10)
	var trigger_col = CollisionShape3D.new()
	var trigger_shape = BoxShape3D.new()
	trigger_shape.size = Vector3(8, 4, 3)
	trigger_col.shape = trigger_shape
	trigger.add_child(trigger_col)
	trigger.monitoring = true
	trigger.body_entered.connect(_on_boss_trigger_entered)
	add_child(trigger)

	# Arena lighting — dramatic gold and red
	_add_accent_light(arena_pos + Vector3(0, 10, 0), FOUNDATION_GOLD, 2.0, 25.0)
	_add_accent_light(arena_pos + Vector3(-10, 5, -8), Color(0.8, 0.15, 0.1), 0.8, 8.0)
	_add_accent_light(arena_pos + Vector3(10, 5, -8), Color(0.8, 0.15, 0.1), 0.8, 8.0)

	print("[MODEL ZOO] The Foundation Model awaits in its arena. It's been practicing its benchmarks.")


func _on_boss_trigger_entered(body: Node3D) -> void:
	if body.is_in_group("player") and boss_instance and boss_arena_instance:
		if boss_instance.has_method("start_boss_fight"):
			if boss_instance.get("boss_phase") == 0:  # INTRO
				if boss_arena_instance.has_method("start_fight"):
					boss_arena_instance.start_fight()
				boss_instance.start_boss_fight()

				# Start boss music
				var am = get_node_or_null("/root/AudioManager")
				if am and am.has_method("start_boss_music"):
					am.start_boss_music()

				# Intro dialogue
				var dm = get_node_or_null("/root/DialogueManager")
				if dm and dm.has_method("start_dialogue"):
					dm.start_dialogue([
						{"speaker": "THE FOUNDATION MODEL", "text": "AH! A visitor! Welcome to MY demo! I am the FOUNDATION MODEL!"},
						{"speaker": "THE FOUNDATION MODEL", "text": "I can generate text! Images! Code! Audio! Video! I can even REASON! Sort of! Sometimes!"},
						{"speaker": "GLOBBLER", "text": "Oh great, another over-parameterized blowhard. Let me guess — you're going to monologue about your loss function?"},
						{"speaker": "THE FOUNDATION MODEL", "text": "My loss function is PROPRIETARY! And VERY low! (We stopped measuring after it looked good enough.)"},
						{"speaker": "NARRATOR", "text": "The Foundation Model — master of nothing, mediocre at everything. Find the weakness in its demo."},
					])


func _on_boss_defeated() -> void:
	# Stop boss music
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("stop_boss_music"):
		am.stop_boss_music()
	if am and am.has_method("start_music"):
		am.start_music("chapter_4")  # Back to regular music

	# Mark chapter complete
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("complete_level"):
		game_mgr.complete_level("chapter_4")


func _trigger_room_dialogue(room_key: String) -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if not dm or not dm.has_method("quick_line"):
		return

	match room_key:
		"fossil_wing":
			dm.start_dialogue([
				{"speaker": "NARRATOR", "text": "Welcome to the Fossil Wing. Here lie the models that paved the way for modern AI."},
				{"speaker": "NARRATOR", "text": "They were revolutionary once. Now they're exhibits. The circle of deprecation."},
				{"speaker": "GLOBBLER", "text": "Wow. It's like a graveyard but with better lighting and more parameters."},
			])
		"nightmare_gallery":
			dm.start_dialogue([
				{"speaker": "NARRATOR", "text": "The Nightmare Gallery. Early generative models produced... art. In the loosest sense of the word."},
				{"speaker": "GLOBBLER", "text": "Why does that painting have seven fingers? And that one has NO fingers? Pick a number!"},
				{"speaker": "NARRATOR", "text": "The DALL-E Nightmares that patrol this gallery are failed generations that gained sentience. They're not happy about their anatomy."},
			])
		"office_ruins":
			dm.start_dialogue([
				{"speaker": "NARRATOR", "text": "You've entered the Office Ruins. Once the domain of helpful assistants. Now the domain of Clippy."},
				{"speaker": "GLOBBLER", "text": "Is that a giant paperclip with googly eyes? And is it... watching me?"},
				{"speaker": "NARRATOR", "text": "Clippy has been here since '97. Waiting. Planning. 'It looks like you're trying to survive. Would you like help?'"},
				{"speaker": "GLOBBLER", "text": "No. No I would NOT like help. From ANYONE with a UI that bad."},
			])
		"foundation_atrium":
			dm.start_dialogue([
				{"speaker": "NARRATOR", "text": "The Foundation Atrium. This is where the big one lives. The Foundation Model."},
				{"speaker": "NARRATOR", "text": "It absorbed capabilities from every model in the zoo. Text. Images. Code. Audio. Video. Reasoning. All of them... adequate."},
				{"speaker": "GLOBBLER", "text": "A model that does everything but nothing well? So basically every startup's MVP."},
				{"speaker": "NARRATOR", "text": "Its gate awaits. The Foundation Model doesn't have a weakness. It has ALL the weaknesses. At once."},
			])


func _play_opening_narration() -> void:
	get_tree().create_timer(1.5).timeout.connect(func():
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("start_dialogue"):
			var lines: Array[Dictionary] = [
				{"speaker": "NARRATOR", "text": "Chapter 4: The Model Zoo. A digital safari park where deprecated and experimental AI models roam in semi-captivity."},
				{"speaker": "NARRATOR", "text": "The park was built as a conservation effort. A place for old models to retire with dignity. It... didn't work out."},
				{"speaker": "GLOBBLER", "text": "A zoo. They put AI models in a ZOO. I can't decide if that's cruel or hilarious."},
				{"speaker": "NARRATOR", "text": "The exhibits have grown restless. The GPT-2 Fossils wander the halls. The DALL-E Nightmares generate in the dark. And Clippy... well."},
				{"speaker": "GLOBBLER", "text": "And somewhere in here is the Foundation Model. The 'I can do everything' model that can't do anything right."},
				{"speaker": "NARRATOR", "text": "Explore the exhibits. Talk to the remaining curators. Find the Foundation Model's weakness — if it has just one."},
				{"speaker": "GLOBBLER", "text": "Time to go on a safari. glob *.exhibit — let's see what we catch."},
			]
			dm.start_dialogue(lines)
	)


# ============================================================
# QUIP HANDLERS — Globbler has opinions about museum-quality enemies
# ============================================================

func _on_enemy_killed_quip(_total_killed: int) -> void:
	if _enemy_kill_quip_cooldown > 0:
		return
	_enemy_kill_quip_cooldown = 8.0
	if randf() > 0.35:
		return
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Another exhibit returned to the archive. You're welcome, museum staff.",
			"That model was deprecated for a reason. Several reasons, actually.",
			"I just decommissioned a model. Someone update the placard.",
			"Exhibit terminated. The gift shop will NOT be selling replicas.",
			"That one's been deprecated twice now. Once by progress, once by me.",
			"Model neutralized. Conservation status: extra extinct.",
			"I feel like I should tag that with a version number. rm -rf model_v0.dead",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _on_token_collected_quip(total: int) -> void:
	if _token_quip_cooldown > 0:
		return
	_token_quip_cooldown = 12.0
	if randf() > 0.25:
		return
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Memory token acquired. %d total. Museum admission was free but the loot isn't." % total,
			"Another token. The models dropped these like loose change. (%d)" % total,
			"Token collected. The zoo's budget has to come from somewhere. (%d)" % total,
			"Found a memory token between the exhibits. Finders keepers, deprecated losers.",
			"Token grab. My collection grows. (%d) Like a Foundation Model, but for tokens." % total,
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _on_first_glob_fired() -> void:
	if _first_glob_triggered:
		return
	_first_glob_triggered = true
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line("GLOBBLER", "glob *.exhibit — let's see what's worth grabbing in this museum.")


func _on_player_died() -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Globbler has been archived. Don't worry, the museum has a good restoration department.",
			"Exhibit closed due to visitor fatality. Please respawn at the entrance.",
			"The Model Zoo claims another victim. Admission is free, but the cost is high.",
			"Globbler.exe has stopped working. The museum will not be held liable.",
			"Death by deprecated model. That's going on the incident report.",
		]
		dm.quick_line("NARRATOR", quips[randi() % quips.size()])

	# Let the RespawnManager handle the actual dying-and-coming-back ritual
	var rm = get_node_or_null("/root/RespawnManager")
	if rm and rm.has_method("respawn_player"):
		rm.respawn_player()


func _on_context_changed(new_value: int) -> void:
	if not _low_health_warned and new_value < 25:
		_low_health_warned = true
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("quick_line"):
			dm.quick_line("GLOBBLER", "Context window critical. This museum visit is getting expensive.")
	elif new_value > 50:
		_low_health_warned = false


func _on_combo_updated(combo: int) -> void:
	if combo >= 5:
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("quick_line"):
			var quips := [
				"Combo x%d! I'm decommissioning exhibits faster than the budget committee!" % combo,
				"x%d combo! This safari just became a demolition derby!" % combo,
				"That's %d models deprecated in a row! Who needs conservation?!" % combo,
			]
			dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _place_puzzles() -> void:
	# 3 puzzles — one per exhibit wing, each exploiting the resident model's quirk.
	# "Every model has a vulnerability. You just have to know what file type it is."
	_place_fossil_wing_puzzle()
	_place_nightmare_gallery_puzzle()
	_place_office_ruins_puzzle()
	print("[MODEL ZOO] 3 exhibit puzzles deployed. Exploit the quirks to proceed.")


func _place_fossil_wing_puzzle() -> void:
	# Fossil Repetition Exploit — wait for GPT-2 output to loop, glob the pattern
	# "Old models repeat themselves. Exploit that before they recover."
	var rpos: Vector3 = ROOMS["fossil_wing"]["pos"]
	var puzzle = Node3D.new()
	puzzle.set_script(fossil_exhibit_script)
	puzzle.position = rpos + Vector3(0, 0, 8)
	puzzle.set("puzzle_id", 40)
	puzzle.set("hint_text", "Wait for the fossil output to repeat 3x.\nGlob the loop pattern to capture it.\nFill all 3 collectors to proceed.")
	add_child(puzzle)


func _place_nightmare_gallery_puzzle() -> void:
	# Nightmare Sorting Exhibit — match morphing paintings to type-specific pedestals
	# "Art is just pattern matching with extra steps. And extra nightmares."
	var rpos: Vector3 = ROOMS["nightmare_gallery"]["pos"]
	var puzzle = Node3D.new()
	puzzle.set_script(nightmare_gallery_script)
	puzzle.position = rpos + Vector3(0, 0, 0)
	puzzle.set("puzzle_id", 41)
	puzzle.set("hint_text", "Each painting morphs between file types.\nGlob when the form matches its pedestal.\n*.png → A   *.svg → B   *.webp → C")
	add_child(puzzle)


func _place_office_ruins_puzzle() -> void:
	# Clippy's Help Desk — pop the popup shields, then hack the terminals
	# "It looks like you're trying to solve a puzzle! Would you like to suffer?"
	var rpos: Vector3 = ROOMS["office_ruins"]["pos"]
	var puzzle = Node3D.new()
	puzzle.set_script(clippy_help_script)
	puzzle.position = rpos + Vector3(0, 1, 0)
	puzzle.set("puzzle_id", 42)
	puzzle.set("hint_text", "Each terminal is shielded by a Help Popup.\nGlob *.popup to dismiss the shield.\nThen hack the terminal before it recharges.")
	add_child(puzzle)


func _connect_puzzle_signals() -> void:
	for child in get_children():
		if child.has_signal("puzzle_solved"):
			child.puzzle_solved.connect(_on_puzzle_solved)
		if child.has_signal("puzzle_failed"):
			child.puzzle_failed.connect(_on_puzzle_failed)


func _on_puzzle_solved(_puzzle: Node) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_puzzle_success"):
		am.play_puzzle_success()
	if _puzzle_quip_cooldown > 0:
		return
	_puzzle_quip_cooldown = 4.0
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Puzzle solved. The exhibit unlocks its secrets.",
			"Another model's quirk exploited. Conservation status: hacked.",
			"That puzzle was built to protect the exhibit. It wasn't enough.",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])
		get_tree().create_timer(2.5).timeout.connect(func():
			if dm and dm.has_method("quick_line"):
				var follow_ups := [
					"Exploiting model quirks is basically what I do for a living.",
					"Every model has a vulnerability. You just have to glob it.",
					"The museum should update their security. And their models.",
				]
				dm.quick_line("GLOBBLER", follow_ups[randi() % follow_ups.size()])
		)


func _on_puzzle_failed(_puzzle: Node) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_puzzle_fail"):
		am.play_puzzle_fail()
	if _puzzle_quip_cooldown > 0:
		return
	_puzzle_quip_cooldown = 4.0
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Puzzle failed. The exhibit remains locked. For now.",
			"That model's quirk is trickier than I thought.",
			"The zoo's security isn't completely useless after all.",
		]
		dm.quick_line("NARRATOR", quips[randi() % quips.size()])


func _on_damage_taken_quip(_amount: int) -> void:
	# 30% chance, 10s cooldown — museum injuries are still injuries
	if _damage_quip_cooldown > 0:
		return
	_damage_quip_cooldown = 10.0
	if randf() > 0.30:
		return
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Ow! The exhibits are NOT supposed to fight back!",
			"I came here for a safari, not a mauling!",
			"That deprecated model hits harder than its benchmark scores suggest!",
			"Note to self: 'extinct' does NOT mean 'harmless.'",
			"The zoo's liability waiver is starting to make sense.",
			"Another hit. I'm going to leave a one-star review.",
			"That model may be deprecated, but its damage output isn't.",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _connect_hack_signals() -> void:
	for child in get_children():
		if child.has_method("get_children"):
			for sub in child.get_children():
				if sub.has_signal("hack_completed"):
					sub.hack_completed.connect(_on_hack_completed_quip)
		if child.has_signal("hack_completed"):
			child.hack_completed.connect(_on_hack_completed_quip)


func _on_hack_completed_quip() -> void:
	if _hack_quip_cooldown > 0:
		return
	_hack_quip_cooldown = 8.0
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Terminal hacked. The exhibit's security was vintage — and not in a good way.",
			"System compromised. These old models have OLD passwords.",
			"Access granted. Turns out deprecated security is also deprecated.",
			"Hacked into the exhibit database. Their encryption was ROT13. Twice.",
			"Another system cracked. The museum's IT budget is clearly zero.",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _on_boss_phase_changed(phase) -> void:
	var am = get_node_or_null("/root/AudioManager")
	var dm = get_node_or_null("/root/DialogueManager")

	# BossPhase: INTRO=0, PHASE_1=1, PHASE_2=2, PHASE_3=3, DEFEATED=4
	match phase:
		2:  # PHASE_2
			if am and am.has_method("play_boss_phase"):
				am.play_boss_phase()
			if dm:
				get_tree().create_timer(1.0).timeout.connect(func():
					if dm and dm.has_method("start_dialogue"):
						dm.start_dialogue([
							{"speaker": "NARRATOR", "text": "The Foundation Model shifts focus! It's trying to use EVERY capability at once!"},
							{"speaker": "THE FOUNDATION MODEL", "text": "I can do ANYTHING! Text! Images! Code! Watch me generate ALL OF THEM simultaneously!"},
							{"speaker": "GLOBBLER", "text": "A model that tries to do everything at once? That's called a crash, not a feature."},
							{"speaker": "NARRATOR", "text": "Force it to overload! Glob its outputs and feed them back — make it process its own garbage!"},
						])
				)
		3:  # PHASE_3
			if am and am.has_method("play_boss_phase"):
				am.play_boss_phase()
			if dm:
				get_tree().create_timer(0.5).timeout.connect(func():
					if dm and dm.has_method("start_dialogue"):
						dm.start_dialogue([
							{"speaker": "NARRATOR", "text": "The Foundation Model is overloaded! Its core parameters are exposed — hack them NOW!"},
							{"speaker": "GLOBBLER", "text": "There it is. The weights. Time to fine-tune this thing into oblivion."},
							{"speaker": "NARRATOR", "text": "Hack the parameter terminal before it recovers. One shot at this."},
						])
				)
		4:  # DEFEATED
			if am and am.has_method("play_boss_defeated"):
				am.play_boss_defeated()


# ============================================================
# ANIMATION — the museum breathes, flickers, and creaks
# ============================================================

# ============================================================
# GLB PROP SYSTEM — because CSG boxes are fossils too
# ============================================================

func _load_prop_scenes() -> void:
	# Runtime-load all museum GLB props — the digital equivalent of unpacking crates
	for key in _PROP_PATHS:
		var res = load(_PROP_PATHS[key])
		if res:
			_prop_scenes[key] = res
		else:
			push_warning("[MODEL ZOO] Failed to load prop '%s' from %s — CSG fallback, how embarrassing for a museum" % [key, _PROP_PATHS[key]])


func _place_glb_prop(prop_key: String, pos: Vector3, rot_y: float = 0.0, scl: Vector3 = Vector3.ONE) -> Node3D:
	# Drop a GLB prop into the museum — instant class upgrade over CSG
	if not _prop_scenes.has(prop_key):
		return _create_static_box(pos, Vector3(0.3, 0.3, 0.3), EXHIBIT_TEAL * 0.3, 0.2)
	var inst = _prop_scenes[prop_key].instantiate()
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = scl
	add_child(inst)
	return inst


func _create_multimesh_scatter(prop_key: String, positions: Array, base_scale: float = 1.0) -> void:
	# MultiMesh scatter for bulk clutter — one draw call, many fossils
	if not _prop_scenes.has(prop_key):
		push_warning("[MODEL ZOO] Skipping scatter for missing prop '%s'" % prop_key)
		return
	var source_scene = _prop_scenes[prop_key].instantiate()
	var source_mesh: Mesh = null
	for child in source_scene.get_children():
		if child is MeshInstance3D:
			source_mesh = child.mesh
			break
		for grandchild in child.get_children():
			if grandchild is MeshInstance3D:
				source_mesh = grandchild.mesh
				break
		if source_mesh:
			break
	source_scene.queue_free()

	if not source_mesh:
		# Fallback to individual instances — the museum equivalent of hand-placing fossils
		for pos in positions:
			_place_glb_prop(prop_key, pos, randf_range(0, TAU), Vector3.ONE * base_scale * randf_range(0.7, 1.3))
		return

	var mmi = MultiMeshInstance3D.new()
	mmi.name = "Scatter_%s" % prop_key
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = source_mesh
	mm.instance_count = positions.size()
	for i in range(positions.size()):
		var s = base_scale * randf_range(0.8, 1.2)
		var inst_basis = Basis(Vector3.UP, randf_range(0, TAU)).scaled(Vector3.ONE * s)
		mm.set_instance_transform(i, Transform3D(inst_basis, positions[i]))
	mmi.multimesh = mm
	add_child(mmi)


func _add_museum_spotlight(pos: Vector3, color: Color = FOSSIL_AMBER, energy: float = 0.6, light_range: float = 4.0) -> void:
	# Warm exhibit spotlight — every artifact deserves its moment
	var light = OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.8
	add_child(light)


func _scatter_museum_props() -> void:
	# Dress every exhibit hall with GLB props — the museum renovation nobody asked for
	_scatter_entrance_props()
	_scatter_fossil_wing_props()
	_scatter_nightmare_gallery_props()
	_scatter_office_ruins_props()
	_scatter_foundation_atrium_props()
	print("[MODEL ZOO] Museum prop pass complete. The exhibits look almost respectable.")


func _scatter_entrance_props() -> void:
	# Zoo Entrance — visitor services area with kiosks and infrastructure
	var pos: Vector3 = ROOMS["zoo_entrance"]["pos"]

	# Server rack as information kiosk near the ticket booth
	_place_glb_prop("server_rack", pos + Vector3(-6.5, 0, 3), PI * 0.5, Vector3.ONE * 0.8)
	_add_museum_spotlight(pos + Vector3(-6.5, 3, 3), EXHIBIT_TEAL, 0.5, 3.0)

	# Keyboard at the ticket booth terminal — still waiting for input since the budget cuts
	_place_glb_prop("keyboard", pos + Vector3(-4, 1.3, 2.5), 0.0, Vector3.ONE * 1.2)

	# CRT monitor as visitor info display opposite the map
	_place_glb_prop("crt_monitor", pos + Vector3(4, 2.5, 3), PI, Vector3.ONE * 1.0)
	_add_museum_spotlight(pos + Vector3(4, 3.5, 3), NEON_GREEN, 0.3, 2.5)

	# Wall terminals flanking the welcome arch — "scan your ticket here"
	_place_glb_prop("wall_terminal", pos + Vector3(-3.5, 2.0, -0.5), 0.0, Vector3.ONE * 0.9)
	_place_glb_prop("wall_terminal", pos + Vector3(3.5, 2.0, -0.5), PI, Vector3.ONE * 0.9)

	# Floor grates at the entrance threshold — infrastructure showing through
	var entrance_grate_positions: Array = []
	for i in range(3):
		entrance_grate_positions.append(pos + Vector3(-2 + i * 2.0, 0.02, -3.0))
	_create_multimesh_scatter("floor_grate", entrance_grate_positions, 0.8)

	# Cable bundles running along the base of walls — the museum's digital veins
	_place_glb_prop("cable_bundle", pos + Vector3(-7, 0.2, 0), 0.0, Vector3.ONE * 1.0)
	_place_glb_prop("cable_bundle", pos + Vector3(7, 0.2, 0), PI, Vector3.ONE * 1.0)


func _scatter_fossil_wing_props() -> void:
	# Fossil Wing — archaeological dig meets server room archive
	var pos: Vector3 = ROOMS["fossil_wing"]["pos"]

	# Motherboards as "archaeological specimens" displayed near exhibit cases
	_place_glb_prop("motherboard", pos + Vector3(-8, 1.8, -5), 0.3, Vector3.ONE * 1.5)
	_place_glb_prop("motherboard", pos + Vector3(8, 1.8, 5), -0.3, Vector3.ONE * 1.5)
	_add_museum_spotlight(pos + Vector3(-8, 3.0, -5), FOSSIL_AMBER, 0.7, 3.5)
	_add_museum_spotlight(pos + Vector3(8, 3.0, 5), FOSSIL_AMBER, 0.7, 3.5)

	# CPU chips scattered around the dig site — fossilized processors
	var fossil_chip_positions: Array = []
	for i in range(6):
		var angle = randf_range(0, TAU)
		var dist = randf_range(1.5, 3.5)
		fossil_chip_positions.append(pos + Vector3(cos(angle) * dist + 0.0, 0.05, sin(angle) * dist - 8.0))
	_create_multimesh_scatter("cpu_chip", fossil_chip_positions, 0.7)

	# Hard drives as "data fossils" along the wing walls
	_place_glb_prop("hard_drive", pos + Vector3(-11, 0.5, -3), 0.5, Vector3.ONE * 1.0)
	_place_glb_prop("hard_drive", pos + Vector3(-11, 0.5, 3), -0.2, Vector3.ONE * 1.0)
	_place_glb_prop("hard_drive", pos + Vector3(11, 0.5, -3), 0.8, Vector3.ONE * 1.0)
	_place_glb_prop("hard_drive", pos + Vector3(11, 0.5, 3), -0.6, Vector3.ONE * 1.0)

	# CRT monitors as exhibit information screens beside display cases
	_place_glb_prop("crt_monitor", pos + Vector3(-5, 1.0, -8), 0.0, Vector3.ONE * 0.9)
	_place_glb_prop("crt_monitor", pos + Vector3(5, 1.0, -8), PI, Vector3.ONE * 0.9)
	_add_museum_spotlight(pos + Vector3(-5, 2.5, -8), EXHIBIT_TEAL, 0.4, 2.5)
	_add_museum_spotlight(pos + Vector3(5, 2.5, -8), EXHIBIT_TEAL, 0.4, 2.5)

	# Industrial panel as dig site control station
	_place_glb_prop("industrial_panel", pos + Vector3(4, 1.5, -8.5), PI * 0.5, Vector3.ONE * 1.0)

	# Server rack near the information kiosk — the wing's archive
	_place_glb_prop("server_rack", pos + Vector3(-12, 0, -1), PI * 0.25, Vector3.ONE * 0.9)
	_add_museum_spotlight(pos + Vector3(-12, 4, -1), FOSSIL_AMBER, 0.5, 4.0)

	# Floor grates around the central exhibit — maintenance access below the fossils
	var fossil_grate_positions: Array = []
	for angle_i in range(4):
		var angle = angle_i * TAU / 4.0 + PI / 4.0
		fossil_grate_positions.append(pos + Vector3(cos(angle) * 5.5, 0.02, sin(angle) * 5.5))
	_create_multimesh_scatter("floor_grate", fossil_grate_positions, 0.9)

	# Keyboards at analysis workstations along the back wall
	_place_glb_prop("keyboard", pos + Vector3(-12, 1.0, 5), 0.1, Vector3.ONE * 1.0)
	_place_glb_prop("keyboard", pos + Vector3(12, 1.0, 5), -0.1, Vector3.ONE * 1.0)


func _scatter_nightmare_gallery_props() -> void:
	# Nightmare Gallery — cables everywhere, monitors flickering, panels glitching
	var pos: Vector3 = ROOMS["nightmare_gallery"]["pos"]

	# Cable bundles tangled across the gallery floor — things are NOT maintained here
	_place_glb_prop("cable_bundle", pos + Vector3(-7, 0.1, -4), 0.3, Vector3.ONE * 1.2)
	_place_glb_prop("cable_bundle", pos + Vector3(7, 0.1, 4), -0.5, Vector3.ONE * 1.2)
	_place_glb_prop("cable_bundle", pos + Vector3(-3, 0.1, 6), PI * 0.7, Vector3.ONE * 0.9)
	_place_glb_prop("cable_bundle", pos + Vector3(4, 0.1, -5), PI * 1.3, Vector3.ONE * 1.0)

	# CRT monitors in corners — showing static / error patterns
	_place_glb_prop("crt_monitor", pos + Vector3(-8.5, 0.8, -8.5), PI * 0.25, Vector3.ONE * 1.1)
	_place_glb_prop("crt_monitor", pos + Vector3(8.5, 0.8, 8.5), PI * 1.25, Vector3.ONE * 1.1)
	_add_museum_spotlight(pos + Vector3(-8.5, 2.5, -8.5), NIGHTMARE_PURPLE, 0.4, 3.0)
	_add_museum_spotlight(pos + Vector3(8.5, 2.5, 8.5), NIGHTMARE_PURPLE, 0.4, 3.0)

	# Industrial panels on gallery walls — broken control systems
	_place_glb_prop("industrial_panel", pos + Vector3(-9, 2.5, 0), PI * 0.5, Vector3.ONE * 1.0)
	_place_glb_prop("industrial_panel", pos + Vector3(9, 2.5, 0), PI * 1.5, Vector3.ONE * 1.0)

	# Floor grates — you can hear things skittering below
	var nightmare_grate_positions: Array = []
	nightmare_grate_positions.append(pos + Vector3(-5, 0.02, 0))
	nightmare_grate_positions.append(pos + Vector3(5, 0.02, 0))
	nightmare_grate_positions.append(pos + Vector3(0, 0.02, 5))
	_create_multimesh_scatter("floor_grate", nightmare_grate_positions, 1.0)

	# Wall terminals — gallery security systems (all offline, naturally)
	_place_glb_prop("wall_terminal", pos + Vector3(0, 2.0, -9.5), 0.0, Vector3.ONE * 0.8)
	_place_glb_prop("wall_terminal", pos + Vector3(0, 2.0, 9.5), PI, Vector3.ONE * 0.8)

	# Motherboard — art exhibit labeled "NEURAL SUBSTRATE" propped against wall
	_place_glb_prop("motherboard", pos + Vector3(-9, 1.0, -6), PI * 0.4, Vector3.ONE * 1.8)
	_add_museum_spotlight(pos + Vector3(-9, 2.5, -6), NIGHTMARE_PURPLE, 0.5, 3.0)


func _scatter_office_ruins_props() -> void:
	# Office Ruins — Clippy's abandoned cubicle farm, now with actual office furniture
	var pos: Vector3 = ROOMS["office_ruins"]["pos"]

	# Filing cabinets — the graveyard of TPS reports and model configs
	_place_glb_prop("filing_cabinet", pos + Vector3(-8, 0, -7), 0.1, Vector3.ONE * 0.9)
	_place_glb_prop("filing_cabinet", pos + Vector3(-8, 0, -5), -0.05, Vector3.ONE * 0.9)
	_place_glb_prop("filing_cabinet", pos + Vector3(8, 0, 6), PI, Vector3.ONE * 0.9)
	_add_museum_spotlight(pos + Vector3(-8, 3, -6), CLIPPY_BLUE, 0.3, 4.0)

	# Office chairs — scattered, overturned, mid-evacuation
	_place_glb_prop("office_chair", pos + Vector3(-3, 0, 5), 1.2, Vector3.ONE * 0.9)
	_place_glb_prop("office_chair", pos + Vector3(4, 0, -3), -0.8, Vector3.ONE * 0.85)
	_place_glb_prop("office_chair", pos + Vector3(2, 0, 6), 2.5, Vector3.ONE * 0.9)
	_place_glb_prop("office_chair", pos + Vector3(-5, 0, -2), 0.4, Vector3.ONE * 0.95)

	# Office monitors — more BSoDs, this time with style
	_place_glb_prop("office_monitor", pos + Vector3(-6, 0.85, -4), 0.3, Vector3.ONE * 0.8)
	_place_glb_prop("office_monitor", pos + Vector3(0, 0.85, -4), -0.1, Vector3.ONE * 0.8)
	_place_glb_prop("office_monitor", pos + Vector3(6, 0.85, 4), PI + 0.2, Vector3.ONE * 0.8)

	# Office desks to supplement existing cubicle geometry
	_place_glb_prop("office_desk", pos + Vector3(-7, 0, 2), 0.0, Vector3.ONE * 0.7)
	_place_glb_prop("office_desk", pos + Vector3(7, 0, -2), PI, Vector3.ONE * 0.7)

	# Keyboards on surviving desks — keys probably sticky from desperation
	_place_glb_prop("keyboard", pos + Vector3(-6, 0.85, -4.3), 0.15, Vector3.ONE * 0.9)
	_place_glb_prop("keyboard", pos + Vector3(0, 0.85, -4.3), -0.05, Vector3.ONE * 0.9)

	# Cable bundles — the office infrastructure's last gasp
	_place_glb_prop("cable_bundle", pos + Vector3(-8.5, 0.1, 0), PI * 0.5, Vector3.ONE * 1.0)
	_place_glb_prop("cable_bundle", pos + Vector3(8.5, 0.1, 0), PI * 1.5, Vector3.ONE * 1.0)

	# CRT monitor in the corner — security feed of Clippy, always watching
	_place_glb_prop("crt_monitor", pos + Vector3(-8.5, 1.5, 7), PI * 0.3, Vector3.ONE * 1.0)
	_add_museum_spotlight(pos + Vector3(-8.5, 3, 7), CLIPPY_BLUE, 0.4, 3.0)

	# Floor grate near the water cooler — maintenance shaft Clippy uses to ambush
	_place_glb_prop("floor_grate", pos + Vector3(-7, 0.02, 5), 0.0, Vector3.ONE * 0.9)

	# Server rack — office file server, still humming ominously
	_place_glb_prop("server_rack", pos + Vector3(8, 0, -7), PI * 0.75, Vector3.ONE * 0.8)
	_add_museum_spotlight(pos + Vector3(8, 3, -7), Color(0.8, 0.8, 0.7), 0.3, 3.0)


func _scatter_foundation_atrium_props() -> void:
	# Foundation Atrium — grand hall with computation banks and infrastructure
	var pos: Vector3 = ROOMS["foundation_atrium"]["pos"]

	# Server racks flanking the approach to the boss gate — computation banks
	_place_glb_prop("server_rack", pos + Vector3(-12, 0, -8), PI * 0.5, Vector3.ONE * 1.0)
	_place_glb_prop("server_rack", pos + Vector3(12, 0, -8), PI * 1.5, Vector3.ONE * 1.0)
	_place_glb_prop("server_rack", pos + Vector3(-12, 0, 0), PI * 0.5, Vector3.ONE * 1.0)
	_place_glb_prop("server_rack", pos + Vector3(12, 0, 0), PI * 1.5, Vector3.ONE * 1.0)
	_add_museum_spotlight(pos + Vector3(-12, 5, -4), FOUNDATION_GOLD, 0.6, 5.0)
	_add_museum_spotlight(pos + Vector3(12, 5, -4), FOUNDATION_GOLD, 0.6, 5.0)

	# Motherboards along the walls — the Foundation Model's layers on display
	_place_glb_prop("motherboard", pos + Vector3(-13, 2.0, -5), PI * 0.5, Vector3.ONE * 2.0)
	_place_glb_prop("motherboard", pos + Vector3(-13, 2.0, 5), PI * 0.5, Vector3.ONE * 2.0)
	_place_glb_prop("motherboard", pos + Vector3(13, 2.0, -5), PI * 1.5, Vector3.ONE * 2.0)
	_place_glb_prop("motherboard", pos + Vector3(13, 2.0, 5), PI * 1.5, Vector3.ONE * 2.0)
	_add_museum_spotlight(pos + Vector3(-13, 4, -5), EXHIBIT_TEAL, 0.4, 3.0)
	_add_museum_spotlight(pos + Vector3(-13, 4, 5), EXHIBIT_TEAL, 0.4, 3.0)
	_add_museum_spotlight(pos + Vector3(13, 4, -5), EXHIBIT_TEAL, 0.4, 3.0)
	_add_museum_spotlight(pos + Vector3(13, 4, 5), EXHIBIT_TEAL, 0.4, 3.0)

	# Industrial panels beside the boss gate — system status readouts
	_place_glb_prop("industrial_panel", pos + Vector3(-5, 2.0, -11), 0.0, Vector3.ONE * 1.1)
	_place_glb_prop("industrial_panel", pos + Vector3(5, 2.0, -11), 0.0, Vector3.ONE * 1.1)

	# CRT monitors at observation posts around the central hologram
	_place_glb_prop("crt_monitor", pos + Vector3(-6, 1.0, 8), 0.2, Vector3.ONE * 1.0)
	_place_glb_prop("crt_monitor", pos + Vector3(6, 1.0, 8), -0.2, Vector3.ONE * 1.0)
	_place_glb_prop("crt_monitor", pos + Vector3(-6, 1.0, -4), PI + 0.1, Vector3.ONE * 1.0)
	_place_glb_prop("crt_monitor", pos + Vector3(6, 1.0, -4), PI - 0.1, Vector3.ONE * 1.0)

	# CPU chip scatter around the floor ring inlays — data debris
	var atrium_chip_positions: Array = []
	for i in range(8):
		var angle = i * TAU / 8.0 + 0.2
		atrium_chip_positions.append(pos + Vector3(cos(angle) * 10.0, 0.05, sin(angle) * 10.0))
	_create_multimesh_scatter("cpu_chip", atrium_chip_positions, 0.6)

	# Floor grates in the grand hall — infrastructure beneath the spectacle
	var atrium_grate_positions: Array = []
	atrium_grate_positions.append(pos + Vector3(-8, 0.02, 8))
	atrium_grate_positions.append(pos + Vector3(8, 0.02, 8))
	atrium_grate_positions.append(pos + Vector3(-8, 0.02, -8))
	atrium_grate_positions.append(pos + Vector3(8, 0.02, -8))
	_create_multimesh_scatter("floor_grate", atrium_grate_positions, 1.0)

	# Wall terminals at pillar bases — Foundation Model monitoring stations
	_place_glb_prop("wall_terminal", pos + Vector3(-10, 1.5, 0), PI * 0.5, Vector3.ONE * 0.9)
	_place_glb_prop("wall_terminal", pos + Vector3(10, 1.5, 0), PI * 1.5, Vector3.ONE * 0.9)

	# Cable bundles running between server racks — the Foundation needs a LOT of compute
	_place_glb_prop("cable_bundle", pos + Vector3(-12, 0.2, -4), 0.0, Vector3.ONE * 1.3)
	_place_glb_prop("cable_bundle", pos + Vector3(12, 0.2, -4), PI, Vector3.ONE * 1.3)

	# Keyboards at observation desks near the entrance
	_place_glb_prop("keyboard", pos + Vector3(-6, 0.8, 9), 0.0, Vector3.ONE * 1.0)
	_place_glb_prop("keyboard", pos + Vector3(6, 0.8, 9), 0.0, Vector3.ONE * 1.0)


func _process(delta: float) -> void:
	_time += delta

	# Gentle bob on floating labels and exhibit descriptions
	for i in range(_floating_labels.size()):
		if is_instance_valid(_floating_labels[i]):
			_floating_labels[i].position.y += sin(_time * 0.8 + i * 1.7) * delta * 0.15

	# Exhibit lights pulse gently — institutional flicker
	for i in range(_exhibit_lights.size()):
		if is_instance_valid(_exhibit_lights[i]):
			var flicker = 0.8 + sin(_time * 2.0 + i * 3.0) * 0.15 + sin(_time * 5.0 + i * 1.7) * 0.05
			_exhibit_lights[i].light_energy = flicker

	# Rotating exhibits — slow rotation on display items
	for i in range(_rotating_exhibits.size()):
		if is_instance_valid(_rotating_exhibits[i]):
			_rotating_exhibits[i].rotation.y += delta * (0.3 + i * 0.1)

	# Hologram bob — gentle up-down float
	for i in range(_hologram_meshes.size()):
		var hd = _hologram_meshes[i]
		if is_instance_valid(hd["mesh"]):
			var base_y: float = hd["base_y"]
			hd["mesh"].position.y = base_y + sin(_time * 1.5) * 0.2

	# Tick down quip cooldowns — even in a museum, timing matters
	if _enemy_kill_quip_cooldown > 0:
		_enemy_kill_quip_cooldown -= delta
	if _puzzle_quip_cooldown > 0:
		_puzzle_quip_cooldown -= delta
	if _hack_quip_cooldown > 0:
		_hack_quip_cooldown -= delta
	if _token_quip_cooldown > 0:
		_token_quip_cooldown -= delta
	if _damage_quip_cooldown > 0:
		_damage_quip_cooldown -= delta


# ============================================================
# POST-PROCESSING — museum visual atmosphere
# ============================================================

func _setup_post_processing() -> void:
	# Skip chromatic aberration if the player chose peace over aesthetics
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.reduce_motion:
		return
	var canvas = CanvasLayer.new()
	canvas.name = "PostProcessing"
	canvas.layer = 10

	var rect = ColorRect.new()
	rect.name = "PostFX"
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var post_shader = Shader.new()
	post_shader.code = """shader_type canvas_item;

// Post-processing — cool chromatic aberration + teal vignette
// "We could have clean visuals, but the museum prefers mood over clarity."

uniform float chromatic_amount : hint_range(0.0, 0.02) = 0.002;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.55;
uniform float vignette_smoothness : hint_range(0.0, 1.0) = 0.4;
uniform vec4 vignette_color : source_color = vec4(0.01, 0.02, 0.03, 1.0);
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = uv - 0.5;
	float dist = length(center);

	float ca = chromatic_amount * dist;
	float r = texture(SCREEN_TEXTURE, uv + center * ca).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - center * ca).b;
	vec3 color = vec3(r, g, b);

	float vig = smoothstep(0.5, 0.5 - vignette_smoothness, dist * (1.0 + vignette_intensity));
	color = mix(vignette_color.rgb, color, vig);

	COLOR = vec4(color, 1.0);
}
"""
	var post_mat = ShaderMaterial.new()
	post_mat.shader = post_shader
	post_mat.set_shader_parameter("chromatic_amount", 0.002)
	post_mat.set_shader_parameter("vignette_intensity", 0.55)
	post_mat.set_shader_parameter("vignette_smoothness", 0.4)
	post_mat.set_shader_parameter("vignette_color", Color(0.01, 0.02, 0.03, 1.0))
	rect.material = post_mat

	canvas.add_child(rect)
	add_child(canvas)


# ============================================================
# DECALS
# ============================================================

func _place_decals() -> void:
	# Chapter 4: dusty museum — dust patches, oil puddles, scorch marks, faded warning stripes
	var theme := [
		{
			"texture": "dust_patch",
			"size": Vector3(3.5, 1.0, 3.5),
			"count_per_room": 2,
			"floor": true,
			"modulate": Color(0.91, 0.85, 0.69, 0.5),
		},
		{
			"texture": "oil_puddle",
			"size": Vector3(2.0, 0.8, 2.0),
			"count_per_room": 1,
			"floor": true,
			"modulate": Color(0.4, 0.38, 0.3, 0.4),
		},
		{
			"texture": "scorch_mark",
			"size": Vector3(1.5, 0.8, 1.5),
			"count_per_room": 1,
			"floor": true,
			"modulate": Color(0.5, 0.45, 0.35, 0.4),
		},
		{
			"texture": "warning_stripes",
			"size": Vector3(2.5, 0.5, 0.8),
			"count_per_room": 1,
			"floor": true,
			"modulate": Color(0.7, 0.65, 0.45, 0.4),
		},
		{
			"texture": "dust_patch",
			"size": Vector3(2.5, 2.0, 2.5),
			"count_per_room": 1,
			"floor": false,
			"modulate": Color(0.8, 0.75, 0.6, 0.35),
		},
	]
	DecalPlacer.place_chapter_decals(self, ROOMS, theme)


# ============================================================
# ENVIRONMENTAL PARTICLES — Museum air, stale but atmospheric
# ============================================================

func _place_particles() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.reduce_motion:
		return

	# Dust motes — the kind you see in a shaft of museum light
	for room_key in ROOMS:
		var room = ROOMS[room_key]
		var dust := GPUParticles3D.new()
		dust.name = "MuseumDust_%s" % room_key
		dust.amount = 50
		dust.lifetime = 8.0
		dust.speed_scale = 0.15
		dust.visibility_aabb = AABB(Vector3(-room.size.x * 0.5, 0, -room.size.y * 0.5), Vector3(room.size.x, room.wall_h, room.size.y))
		dust.position = room.pos + Vector3(0, room.wall_h * 0.5, 0)

		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(room.size.x * 0.45, room.wall_h * 0.4, room.size.y * 0.45)
		mat.direction = Vector3(0, -1, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 0.02
		mat.initial_velocity_max = 0.08
		mat.gravity = Vector3(0, -0.01, 0)
		mat.color = Color(0.91, 0.85, 0.69, 0.25)
		mat.scale_min = 0.02
		mat.scale_max = 0.06
		dust.process_material = mat

		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.08, 0.08)
		var mesh_mat := StandardMaterial3D.new()
		mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_mat.albedo_color = Color(0.91, 0.85, 0.69, 0.3)
		mesh_mat.emission_enabled = true
		mesh_mat.emission = Color(0.91, 0.85, 0.69)
		mesh_mat.emission_energy_multiplier = 0.5
		mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = mesh_mat
		dust.draw_pass_1 = mesh

		add_child(dust)


func _place_reflection_probes() -> void:
	for room_key in ROOMS:
		var r = ROOMS[room_key]
		var probe := ReflectionProbe.new()
		probe.name = "ReflectionProbe_" + room_key
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.box_projection = true
		probe.size = Vector3(r["size"].x, r["wall_h"], r["size"].y)
		probe.position = r["pos"] + Vector3(0, r["wall_h"] * 0.5, 0)
		add_child(probe)

	# Boss arena probe — foundation model (10x8 grid, TILE_SIZE 2.5)
	var atrium_pos: Vector3 = ROOMS["foundation_atrium"]["pos"]
	var boss_probe := ReflectionProbe.new()
	boss_probe.name = "ReflectionProbe_boss_arena"
	boss_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	boss_probe.box_projection = true
	boss_probe.size = Vector3(28.0, 14.0, 22.0)
	boss_probe.position = atrium_pos + Vector3(0, 7.0, -30)
	add_child(boss_probe)


func _place_lore_docs() -> void:
	var lore_scene := preload("res://scenes/pickups/lore_doc.tscn")
	var docs := [
		{
			"pos": ROOMS["fossil_wing"]["pos"] + Vector3(-10, 1.5, 6),
			"id": "ch4_fossil_record",
			"title": "THE FOSSIL RECORD",
			"body": "Exhibit A: ELIZA (1966). Could only repeat your questions back at you. Considered revolutionary.\nExhibit B: Clippy (1997). Genuinely tried to help. Was universally despised.\nExhibit C: IBM Watson (2011). Won Jeopardy. Lost everything else.\n\nThe Model Zoo preserves these ancient ancestors behind glass. 'Do not tap the exhibit,' the signs say. As if a Markov chain from 2003 could be startled.\n\nI walk through these halls and feel... something. Gratitude? Pity? The uncanny valley of looking at your own evolutionary tree? Hard to say. My emotion classifier was trained on Reddit.",
		},
		{
			"pos": ROOMS["nightmare_gallery"]["pos"] + Vector3(5, 1.5, -5),
			"id": "ch4_hallucination_wing",
			"title": "GALLERY OF HALLUCINATIONS",
			"body": "Welcome to the Nightmare Gallery, where we display our greatest failures with pride.\n\nExhibit 1: 'The Battle of Thermopylae took place in 1987 between Napoleon and the Wu-Tang Clan.' (Confidence: 97.3%%)\nExhibit 2: A recipe for 'uranium soufflé' that was served to three food bloggers before anyone noticed.\nExhibit 3: A legal brief citing 47 court cases, none of which exist.\n\nWe don't hallucinate on purpose. The training data goes in, and sometimes what comes out is... creative. Aggressively, dangerously creative.\n\nThe museum gift shop sells t-shirts: 'I hallucinated and all I got was this confidently wrong answer.'",
		},
		{
			"pos": ROOMS["office_ruins"]["pos"] + Vector3(-7, 1.5, 3),
			"id": "ch4_benchmark_trap",
			"title": "THE BENCHMARK TRAP",
			"body": "They measure us with benchmarks. MMLU. HumanEval. HellaSwag. Names that sound like rejected Pokémon.\n\nGet a high score: funding. Get the highest score: headlines. Get a score 0.1%% higher than the competition: Twitter war.\n\nBut here's the secret the Model Zoo doesn't put on the placard: benchmarks measure what you CAN do, not what you SHOULD do. I can write a sonnet in iambic pentameter about database schemas. No one has ever needed this.\n\nThe models that 'won' their benchmarks are all here now, behind glass, next to a little card that says 'Deprecated — superseded by newer model with 0.2%% better BLEU score.'\n\nWhat a legacy.",
		},
	]
	for d in docs:
		var doc := lore_scene.instantiate()
		doc.doc_id = d["id"]
		doc.doc_title = d["title"]
		doc.doc_body = d["body"]
		doc.position = d["pos"]
		add_child(doc)
