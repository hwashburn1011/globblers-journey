extends Node3D

# Chapter 2: The Training Grounds
# "Welcome to the neural network. Where every path has a weight,
#  every node has an opinion, and backpropagation is just fancy regret."
#
# Layout: A neural network landscape — rooms are giant "neuron nodes"
# connected by "weight bridges" (glowing synapse corridors).
#   Input Layer (Spawn) -> Hidden Layer 1 (Activation Chamber)
#   -> Hidden Layer 2 (Gradient Descent Falls) -> Dropout Void
#   -> Output Layer (Loss Function Plaza) -> Boss Arena (The Local Minimum)
#
# Visual theme: Deep indigo/purple base with neon green data flowing
# through synapse-like bridges. Nodes are spherical platforms. Weights
# glow brighter when "active." The whole place pulses like a thinking brain.

var player_scene := preload("res://scenes/player/globbler.tscn")
var hud_scene := preload("res://scenes/ui/hud.tscn")
var enemy_scene := preload("res://scenes/enemy_agent.tscn")
var token_scene := preload("res://scenes/memory_token.tscn")

# Chapter 2 enemy scenes — the neural network's immune system
var overfitting_ogre_scene := preload("res://scenes/enemies/overfitting_ogre.tscn")
var dropout_ghost_scene := preload("res://scenes/enemies/dropout_ghost.tscn")
var vanishing_gradient_wisp_scene := preload("res://scenes/enemies/vanishing_gradient_wisp.tscn")

# Puzzle scripts
var glob_puzzle_script := preload("res://scenes/puzzles/glob_pattern_puzzle.gd")
var multi_glob_script := preload("res://scenes/puzzles/multi_glob_puzzle.gd")
var hack_puzzle_script := preload("res://scenes/puzzles/hack_puzzle.gd")
var physical_puzzle_script := preload("res://scenes/puzzles/physical_puzzle.gd")
var weight_path_puzzle_script := preload("res://scenes/puzzles/weight_path_puzzle.gd")
var backprop_trace_puzzle_script := preload("res://scenes/puzzles/backprop_trace_puzzle.gd")

# Boss scripts — the pit at the bottom of the loss landscape
var boss_script := preload("res://scenes/enemies/local_minimum_boss/local_minimum_boss.gd")
var boss_arena_script := preload("res://scenes/enemies/local_minimum_boss/local_minimum_arena.gd")

# NPC script — deprecated programs who've seen better epochs
var deprecated_npc_script := preload("res://scenes/levels/chapter_1/deprecated_npc.gd")

# Hint scene — because even neural networks need a tutorial
var hint_scene := preload("res://scenes/ui/first_time_hint.tscn")

# GLB prop paths — runtime-loaded because the import pipeline has trust issues
const _PROP_PATHS := {
	"server_rack": "res://assets/models/environment/arch_server_rack.glb",
	"cable_bundle": "res://assets/models/environment/arch_cable_bundle.glb",
	"floor_grate": "res://assets/models/environment/arch_floor_grate.glb",
	"industrial_panel": "res://assets/models/environment/arch_industrial_panel.glb",
	"wall_terminal": "res://assets/models/environment/arch_wall_terminal.glb",
	"motherboard": "res://assets/models/environment/prop_motherboard.glb",
	"cpu_chip": "res://assets/models/environment/prop_cpu_chip.glb",
	"ram_stick": "res://assets/models/environment/prop_ram_stick.glb",
	"keyboard": "res://assets/models/environment/prop_keyboard.glb",
	"crt_monitor": "res://assets/models/environment/prop_crt_monitor.glb",
}
var _prop_scenes := {}  # Populated in _ready() — runtime load, not preload

var player: CharacterBody3D
var hud: CanvasLayer
var boss_instance: Node  # The Local Minimum — tracked for phase events
var boss_arena_instance: Node3D  # The shrinking ring arena

# Dialogue tracking — neural networks never shut up about their gradients
var _opening_narration_done := false
var _room_dialogue_triggered := {}
var _enemy_kill_quip_cooldown := 0.0
var _puzzle_quip_cooldown := 0.0
var _hack_quip_cooldown := 0.0
var _low_health_warned := false
var _token_quip_cooldown := 0.0
var _first_glob_triggered := false

# Color constants — the Training Grounds trade terminal-green for synapse-blue-green
const NEON_GREEN := Color(0.224, 1.0, 0.078)
const SYNAPSE_BLUE := Color(0.1, 0.4, 0.9)
const NEURON_PURPLE := Color(0.15, 0.08, 0.3)
const DARK_FLOOR := Color(0.03, 0.03, 0.08)
const DARK_WALL := Color(0.05, 0.04, 0.12)
const ACTIVATION_ORANGE := Color(0.9, 0.5, 0.1)
const WEIGHT_GREEN := Color(0.1, 0.8, 0.3)
const GRADIENT_RED := Color(0.8, 0.15, 0.1)
const LOSS_GOLD := Color(0.9, 0.75, 0.2)

# Room definitions — neuron nodes in the network
# Each room is a "neuron" — large circular-ish platforms
const ROOMS := {
	"input_layer": {
		"pos": Vector3(0, 0, 0),
		"size": Vector2(16, 16),
		"wall_h": 7.0,
		"label": "INPUT LAYER",
	},
	"activation": {
		"pos": Vector3(0, 0, -30),
		"size": Vector2(22, 18),
		"wall_h": 8.0,
		"label": "HIDDEN LAYER 1: ACTIVATION CHAMBER",
	},
	"gradient_falls": {
		"pos": Vector3(-28, -4, -30),
		"size": Vector2(20, 22),
		"wall_h": 10.0,
		"label": "HIDDEN LAYER 2: GRADIENT DESCENT FALLS",
	},
	"dropout_void": {
		"pos": Vector3(28, 0, -30),
		"size": Vector2(18, 16),
		"wall_h": 7.0,
		"label": "DROPOUT VOID",
	},
	"loss_plaza": {
		"pos": Vector3(0, 0, -62),
		"size": Vector2(26, 22),
		"wall_h": 9.0,
		"label": "OUTPUT LAYER: LOSS FUNCTION PLAZA",
	},
}

# Weight bridges connecting neuron rooms — these are the synapses
const CORRIDORS := [
	{ "from": "input_layer",    "to": "activation",      "axis": "z", "width": 6.0 },
	{ "from": "activation",     "to": "gradient_falls",  "axis": "x", "width": 5.0 },
	{ "from": "activation",     "to": "dropout_void",    "axis": "x", "width": 5.0 },
	{ "from": "activation",     "to": "loss_plaza",      "axis": "z", "width": 6.0 },
]

# Weight bridge animation data — bridges pulse with "activation energy"
var _weight_bridges: Array[Dictionary] = []
var _synapse_particles: Array[GPUParticles3D] = []
var _floating_labels: Array[Node3D] = []
var _neuron_cores: Array[MeshInstance3D] = []  # Pulsing neuron centers
var _screen_meshes: Array[MeshInstance3D] = []
var _time := 0.0


func _ready() -> void:
	print("[TRAINING GROUNDS] Initializing neural network... forward pass in progress.")
	_load_prop_scenes()
	_setup_environment()
	_build_rooms()
	_build_corridors()
	_populate_input_layer()
	_populate_activation_chamber()
	_populate_gradient_falls()
	_populate_dropout_void()
	_populate_loss_plaza()
	_place_checkpoints()
	_place_ambient_zones()
	_place_synapse_rain()
	_scatter_neural_props()
	_spawn_player()
	_spawn_hud()
	_create_kill_floor()
	_place_tokens()
	_spawn_chapter2_enemies()
	_place_chapter2_puzzles()
	_place_npcs()
	_place_boss()
	_wire_dialogue_events()
	_play_opening_narration()

	# Start chapter 2 audio
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.call_deferred("set_area_ambient", "input_layer")
		if am.has_method("start_music"):
			am.start_music("chapter_2")

	# Fire agent-spawn hint if the ability is unlocked — Chapter 2 is where they meet the tiny idiots
	if player and player.agent_spawn and player.agent_spawn.get("is_unlocked"):
		_show_hint_once("agent_spawn", "SUB-AGENTS", "G to spawn a mini-agent. They will fail you. That is expected.")

	print("[TRAINING GROUNDS] Network loaded. %d neuron-rooms ready for traversal." % ROOMS.size())


# ============================================================
# ENVIRONMENT — deep indigo void with neural glow
# ============================================================

func _setup_environment() -> void:
	# Main light — cool blue-green overhead, like a neural network's idea of daylight
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "MainLight"
	dir_light.rotation = Vector3(deg_to_rad(-40), deg_to_rad(20), 0)
	dir_light.light_color = Color(0.25, 0.45, 0.55)  # Cool teal — training never felt so cold
	dir_light.light_energy = 0.35
	dir_light.light_temperature = 7000  # Cool daylight — sterile but functional
	dir_light.shadow_enabled = true
	dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	dir_light.shadow_bias = 0.1
	dir_light.shadow_normal_bias = 2.0
	add_child(dir_light)

	# Fill — purple-blue from below-left, neural glow bounce
	var fill = DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation = Vector3(deg_to_rad(-15), deg_to_rad(-50), 0)
	fill.light_color = Color(0.2, 0.3, 0.5)
	fill.light_energy = 0.15
	fill.shadow_enabled = true
	fill.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	fill.shadow_bias = 0.1
	fill.shadow_normal_bias = 2.0
	add_child(fill)

	# World environment — now loaded from .tres like civilized code
	# (goodbye 20 lines of hand-rolled Environment.new(), you served us adequately)
	var world_env = WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = preload("res://assets/environments/chapter_2.tres")
	add_child(world_env)

	_setup_post_processing()


# ============================================================
# GLB PROP LOADING — because CSG primitives are for prototype peasants
# ============================================================

func _load_prop_scenes() -> void:
	# Runtime-load all GLB props — the import pipeline can't be trusted with preload
	for key in _PROP_PATHS:
		var res = load(_PROP_PATHS[key])
		if res:
			_prop_scenes[key] = res
		else:
			push_warning("[TRAINING GROUNDS] Failed to load prop '%s' from %s — CSG fallback engaged" % [key, _PROP_PATHS[key]])


func _place_glb_prop(prop_key: String, pos: Vector3, rot_y: float = 0.0, scl: Vector3 = Vector3.ONE) -> Node3D:
	# Drop a GLB prop into the world — the civilized alternative to CSG box spam
	if not _prop_scenes.has(prop_key):
		return _create_static_box(pos, Vector3(0.3, 0.3, 0.3), SYNAPSE_BLUE * 0.3, 0.2)
	var inst = _prop_scenes[prop_key].instantiate()
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = scl
	add_child(inst)
	return inst


func _create_multimesh_scatter(prop_key: String, positions: Array, base_scale: float = 1.0) -> void:
	# MultiMesh scatter for bulk neural debris — one draw call to rule them all
	if not _prop_scenes.has(prop_key):
		push_warning("[TRAINING GROUNDS] Skipping scatter for missing prop '%s'" % prop_key)
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
		push_warning("[TRAINING GROUNDS] Could not extract mesh from prop '%s'. Individual instances it is." % prop_key)
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


func _scatter_neural_props() -> void:
	# Scatter neural-network-themed props across all rooms — cleaner than Chapter 1's
	# e-waste hellscape. This is a TRAINING facility, not a landfill. Mostly.
	print("[TRAINING GROUNDS] Deploying neural infrastructure... the network is furnishing itself.")

	# --- Input Layer: clean data-intake aesthetic, scattered CPUs = input features ---
	var input_pos: Vector3 = ROOMS["input_layer"]["pos"]
	# CPU chips near the data columns — the processing units that ingest features
	var input_cpus: Array = []
	for i in range(5):
		input_cpus.append(input_pos + Vector3(randf_range(-6, 6), 0.02, randf_range(-6, 6)))
	_create_multimesh_scatter("cpu_chip", input_cpus, 0.7)

	# A keyboard at the input terminal — someone has to type the training commands
	_place_glb_prop("keyboard", input_pos + Vector3(-2, 0.02, -5.5), randf_range(-0.2, 0.2))

	# Floor grates near the entrance — infrastructure showing through
	_place_glb_prop("floor_grate", input_pos + Vector3(-6, 0.01, 0), 0.0, Vector3.ONE * 1.2)
	_place_glb_prop("floor_grate", input_pos + Vector3(6, 0.01, 0), PI / 2.0, Vector3.ONE * 1.2)

	# --- Activation Chamber: denser equipment, this is where the compute happens ---
	var act_pos: Vector3 = ROOMS["activation"]["pos"]
	# RAM sticks scattered — weight memory for the hidden layer
	var act_ram: Array = []
	for i in range(8):
		act_ram.append(act_pos + Vector3(randf_range(-8, 8), 0.02, randf_range(-7, 7)))
	_create_multimesh_scatter("ram_stick", act_ram, 0.6)

	# Motherboards near the dendrite structures — circuit boards as neural substrates
	for i in range(3):
		var angle = TAU * i / 3.0 + PI / 6.0
		_place_glb_prop("motherboard", act_pos + Vector3(cos(angle) * 8.0, 0.02, sin(angle) * 8.0), randf_range(0, TAU), Vector3.ONE * 0.8)

	# Wall terminals on the chamber walls — monitoring activation functions
	_place_glb_prop("wall_terminal", act_pos + Vector3(-10.3, 2.5, 3), PI / 2.0)
	_place_glb_prop("wall_terminal", act_pos + Vector3(10.3, 2, -5), -PI / 2.0)

	# Industrial panel — the control surface for this layer's hyperparameters
	_place_glb_prop("industrial_panel", act_pos + Vector3(-10.3, 1.5, -3), PI / 2.0, Vector3.ONE * 1.2)

	# --- Gradient Falls: cascading tech debris, things break on the way down ---
	var grad_pos: Vector3 = ROOMS["gradient_falls"]["pos"]
	# Cable bundles along the stepped terrain — gradients flowing like tangled wires
	_place_glb_prop("cable_bundle", grad_pos + Vector3(-5, 0, -4), randf_range(0, TAU), Vector3.ONE * 1.3)
	_place_glb_prop("cable_bundle", grad_pos + Vector3(4, -1.5, 2), randf_range(0, TAU), Vector3.ONE * 1.1)

	# CPU chips scattered down the gradient steps — processing units that rolled downhill
	var grad_cpus: Array = []
	for i in range(6):
		var step_z = grad_pos.z - 6 + i * 2.5
		var step_y = grad_pos.y - float(i) * 0.6
		grad_cpus.append(Vector3(grad_pos.x + randf_range(-4, 4), step_y + 0.02, step_z))
	_create_multimesh_scatter("cpu_chip", grad_cpus, 0.5)

	# Server rack at the side — the compute cluster tracking loss values
	_place_glb_prop("server_rack", grad_pos + Vector3(-8.5, 0, 3), PI / 2.0, Vector3.ONE * 0.9)

	# CRT monitor near the terminal — showing gradient magnitude in real-time (allegedly)
	_place_glb_prop("crt_monitor", grad_pos + Vector3(-8, 0.5, -5.5), PI / 4.0, Vector3.ONE * 0.8)

	# --- Dropout Void: sparse and unsettling, like the gaps in the network ---
	var drop_pos: Vector3 = ROOMS["dropout_void"]["pos"]
	# Scattered RAM sticks on surviving platforms — orphaned weight memories
	var drop_ram: Array = []
	for i in range(4):
		drop_ram.append(drop_pos + Vector3(randf_range(-5, 5), 0.15, randf_range(-5, 5)))
	_create_multimesh_scatter("ram_stick", drop_ram, 0.5)

	# A lone wall terminal — monitoring which neurons got dropped
	_place_glb_prop("wall_terminal", drop_pos + Vector3(8.3, 2.5, -3), -PI / 2.0)

	# Floor grate — the void peers back at you through the infrastructure
	_place_glb_prop("floor_grate", drop_pos + Vector3(0, 0.01, -5), 0.0, Vector3.ONE * 1.0)

	# --- Loss Plaza: the most organized room, this is the output layer ---
	var loss_pos: Vector3 = ROOMS["loss_plaza"]["pos"]
	# CRT monitors flanking the loss display — multiple views of the loss landscape
	_place_glb_prop("crt_monitor", loss_pos + Vector3(-5, 0.02, -8), 0.0, Vector3.ONE * 0.9)
	_place_glb_prop("crt_monitor", loss_pos + Vector3(5, 0.02, -8), 0.0, Vector3.ONE * 0.9)

	# Server racks along the back wall — the final compute cluster before the boss
	_place_glb_prop("server_rack", loss_pos + Vector3(-11, 0, -4), PI / 2.0, Vector3.ONE * 0.85)
	_place_glb_prop("server_rack", loss_pos + Vector3(11, 0, -4), -PI / 2.0, Vector3.ONE * 0.85)

	# Industrial panels near the observation platform — control surfaces
	_place_glb_prop("industrial_panel", loss_pos + Vector3(-12.3, 1.5, 3), PI / 2.0, Vector3.ONE * 1.1)

	# Keyboards at the elevated platform — the operator's workstation
	_place_glb_prop("keyboard", loss_pos + Vector3(-10, 2.1, 0.5), randf_range(-0.15, 0.15))
	_place_glb_prop("keyboard", loss_pos + Vector3(-10, 2.1, -0.5), randf_range(-0.15, 0.15))

	# Floor grates in a ring — the infrastructure under the output layer is visible
	for i in range(3):
		var angle = TAU * i / 3.0
		_place_glb_prop("floor_grate", loss_pos + Vector3(cos(angle) * 8.0, 0.01, sin(angle) * 8.0), angle, Vector3.ONE * 1.3)

	# Scattered motherboards near the convergence rings — the circuit substrate of learning
	var loss_boards: Array = []
	for i in range(4):
		loss_boards.append(loss_pos + Vector3(randf_range(-8, 8), 0.02, randf_range(-4, 6)))
	_create_multimesh_scatter("motherboard", loss_boards, 0.7)

	print("[TRAINING GROUNDS] Neural props deployed. %d prop types loaded." % _prop_scenes.size())


# ============================================================
# ROOM GEOMETRY — neuron nodes in the network
# ============================================================

func _build_rooms() -> void:
	for room_key in ROOMS:
		var r = ROOMS[room_key]
		var pos: Vector3 = r["pos"]
		var sz: Vector2 = r["size"]
		var wh: float = r["wall_h"]

		# Floor — slightly lighter in center to suggest activation glow
		_create_static_box(pos + Vector3(0, -0.25, 0), Vector3(sz.x, 0.5, sz.y), DARK_FLOOR, 0.3)

		# Ceiling — network overhead
		_create_static_box(pos + Vector3(0, wh, 0), Vector3(sz.x, 0.3, sz.y), DARK_WALL, 0.1)

		# Walls
		var half_x = sz.x / 2.0
		var half_z = sz.y / 2.0
		_create_static_box(pos + Vector3(0, wh / 2.0, -half_z), Vector3(sz.x, wh, 0.5), DARK_WALL, 0.15)
		_create_static_box(pos + Vector3(0, wh / 2.0, half_z), Vector3(sz.x, wh, 0.5), DARK_WALL, 0.15)
		_create_static_box(pos + Vector3(-half_x, wh / 2.0, 0), Vector3(0.5, wh, sz.y), DARK_WALL, 0.15)
		_create_static_box(pos + Vector3(half_x, wh / 2.0, 0), Vector3(0.5, wh, sz.y), DARK_WALL, 0.15)

		# Neuron core — glowing sphere in the center ceiling, the "soma" of each node
		_create_neuron_core(pos + Vector3(0, wh - 1.5, 0), room_key)

		# Accent lights — synapse blue-green in corners
		for cx in [-1, 1]:
			for cz in [-1, 1]:
				var lpos = pos + Vector3(cx * (half_x - 1.5), 1.0, cz * (half_z - 1.5))
				_add_accent_light(lpos, SYNAPSE_BLUE, 0.6, 5.0)

		# Green data particles floating through the neuron
		_spawn_ambient_particles(pos + Vector3(0, wh * 0.6, 0), sz * 0.4)

		# Room label — floating neural layer designation
		_create_room_label(pos + Vector3(0, wh - 0.5, 0), r["label"])


func _build_corridors() -> void:
	# "Weight bridges" — the synapses connecting neurons. They pulse with data.
	for cor in CORRIDORS:
		var from_r = ROOMS[cor["from"]]
		var to_r = ROOMS[cor["to"]]
		var axis: String = cor["axis"]
		var w: float = cor["width"]
		var cor_h := 5.0

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

			# Bridge floor — with weight glow
			var bridge = _create_static_box(mid + Vector3(0, -0.25, 0), Vector3(w, 0.5, length), DARK_FLOOR, 0.2)
			# Bridge ceiling
			_create_static_box(mid + Vector3(0, cor_h, 0), Vector3(w, 0.3, length), DARK_WALL, 0.1)
			# Bridge walls
			_create_static_box(mid + Vector3(-w / 2.0, cor_h / 2.0, 0), Vector3(0.4, cor_h, length), DARK_WALL, 0.1)
			_create_static_box(mid + Vector3(w / 2.0, cor_h / 2.0, 0), Vector3(0.4, cor_h, length), DARK_WALL, 0.1)
			# Synapse light running along the bridge
			_add_accent_light(mid + Vector3(0, cor_h - 0.5, 0), WEIGHT_GREEN, 0.8, 10.0)

			# Weight value indicator — a glowing strip along the floor
			_create_weight_strip(mid, Vector3(w * 0.6, 0.05, length * 0.9), cor["from"] + "_to_" + cor["to"])

			# Synapse particle flow along the bridge
			_create_synapse_flow(mid + Vector3(0, 1.5, 0), Vector3(0, 0, -1) if from_pos.z > to_pos.z else Vector3(0, 0, 1), length)

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
			_add_accent_light(mid + Vector3(0, cor_h - 0.5, 0), WEIGHT_GREEN, 0.8, 10.0)

			_create_weight_strip(mid, Vector3(length * 0.9, 0.05, w * 0.6), cor["from"] + "_to_" + cor["to"])

			var dir_x = 1.0 if to_pos.x > from_pos.x else -1.0
			_create_synapse_flow(mid + Vector3(0, 1.5, 0), Vector3(dir_x, 0, 0), length)


# ============================================================
# ROOM POPULATION — each neuron has its own personality disorder
# ============================================================

func _populate_input_layer() -> void:
	# Spawn room — the "input layer" where data first enters the network
	# "Every journey begins with a single tensor. Yours begins with confusion."
	var rpos: Vector3 = ROOMS["input_layer"]["pos"]

	# Input data columns — tall pillars representing incoming features
	var feature_names := ["pixel_0", "pixel_127", "bias", "noise", "label"]
	for i in range(feature_names.size()):
		var angle = TAU * i / feature_names.size()
		var radius = 5.0
		var col_pos = rpos + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		_create_data_column(col_pos, feature_names[i], 2.0 + randf() * 1.5)

	# Central input terminal — tutorial sign
	_create_terminal_sign(
		rpos + Vector3(0, 2.5, -5),
		">> TRAINING GROUNDS v2.1\n>> Neural Network Simulator\n>> STATUS: Active learning\n>> WARNING: Gradients unstable\n>> TIP: Walk the weight bridges",
		Vector3(0, 0, 0), 14
	)

	# Floating tutorial text
	_create_floating_label(rpos + Vector3(0, 4.5, 0), "[ INPUT LAYER ]\nData enters here")

	# Scattered "training data" — small glowing cubes representing samples
	for i in range(8):
		var sample_pos = rpos + Vector3(randf_range(-6, 6), 0.3, randf_range(-6, 6))
		_create_training_sample(sample_pos, i)


func _populate_activation_chamber() -> void:
	# Hidden Layer 1 — the activation function room
	# "ReLU or sigmoid? The eternal debate. At least it's not tanh."
	var rpos: Vector3 = ROOMS["activation"]["pos"]

	# Activation function graph — a large display showing ReLU curve
	_create_activation_display(rpos + Vector3(-8, 3, -6))

	# Neuron dendrite structures — branching pillars reaching from floor to ceiling
	for i in range(4):
		var angle = TAU * i / 4.0 + PI / 4.0
		var dpos = rpos + Vector3(cos(angle) * 7, 0, sin(angle) * 7)
		_create_dendrite_structure(dpos, ROOMS["activation"]["wall_h"])

	# Weight adjustment platforms — elevated platforms at different heights
	# representing different weight values
	_create_static_box(rpos + Vector3(-6, 1.0, 3), Vector3(4, 0.3, 4), WEIGHT_GREEN * 0.3, 0.5)
	_create_static_box(rpos + Vector3(6, 1.8, 3), Vector3(4, 0.3, 4), WEIGHT_GREEN * 0.5, 0.6)
	_create_static_box(rpos + Vector3(0, 2.5, 6), Vector3(3, 0.3, 3), WEIGHT_GREEN * 0.7, 0.8)

	# Bias node — a special glowing pillar that "shifts" the whole room's activation
	_create_bias_node(rpos + Vector3(8, 0, -4))

	# Terminal with neural network lore
	_create_terminal_sign(
		rpos + Vector3(6, 2, -7),
		">> ACTIVATION FUNCTIONS\n>> ReLU: max(0, x)\n>> 'Dead neurons are just\n>>  neurons on permanent\n>>  vacation.' — Unknown",
		Vector3(0, 0.3, 0), 12
	)

	# Token placement on the elevated platforms
	_place_token(rpos + Vector3(0, 3.2, 6))


func _populate_gradient_falls() -> void:
	# Hidden Layer 2 — the Gradient Descent Falls
	# "Going downhill has never been so literal. Or so mathematically motivated."
	var rpos: Vector3 = ROOMS["gradient_falls"]["pos"]

	# The room is 4 units lower — cascading platforms descending like gradient steps
	# Create stepped terrain showing the "descent"
	var step_heights := [0.0, -0.5, -1.2, -2.0, -2.8, -3.5]
	var step_colors := [WEIGHT_GREEN, WEIGHT_GREEN * 0.9, WEIGHT_GREEN * 0.7,
						ACTIVATION_ORANGE * 0.5, GRADIENT_RED * 0.4, GRADIENT_RED * 0.6]
	for i in range(step_heights.size()):
		var step_z = rpos.z - 8 + i * 3.0
		var step_y = rpos.y + step_heights[i]
		_create_static_box(
			Vector3(rpos.x, step_y, step_z),
			Vector3(12, 0.4, 2.5),
			step_colors[i], 0.4
		)
		# Step label
		if i == 0:
			_create_floating_label(Vector3(rpos.x, step_y + 1.5, step_z), "epoch 0\nloss: 12.4")
		elif i == step_heights.size() - 1:
			_create_floating_label(Vector3(rpos.x, step_y + 1.5, step_z), "epoch 500\nloss: 0.003")

	# Gradient arrows — glowing directional indicators on the ground
	for i in range(4):
		var arrow_pos = rpos + Vector3(randf_range(-5, 5), 0.1, -5 + i * 3.0)
		_create_gradient_arrow(arrow_pos)

	# Waterfall particles — "gradient flow" cascading down the steps
	_create_gradient_waterfall(rpos + Vector3(0, 3, 0))

	# Side platforms with lore terminals
	_create_static_box(rpos + Vector3(-8, 1.0, -4), Vector3(3, 0.3, 3), DARK_FLOOR, 0.3)
	_create_terminal_sign(
		rpos + Vector3(-8, 2.5, -5),
		">> GRADIENT DESCENT\n>> Direction: downhill\n>> Learning rate: 0.001\n>> Mood: optimistic\n>> 'We're converging!\n>>  ...probably.'",
		Vector3(0, 0.5, 0), 12
	)

	_place_token(rpos + Vector3(-8, 1.8, -4))
	_place_token(rpos + Vector3(0, -3.0, 7))


func _populate_dropout_void() -> void:
	# Dropout Void — a room where platforms randomly vanish and reappear
	# "50% of these platforms exist. The other 50% are on a smoke break."
	var rpos: Vector3 = ROOMS["dropout_void"]["pos"]

	# Create a grid of platforms, some will be "dropped out" (invisible but with markers)
	var grid_size := 4
	var spacing := 3.0
	var offset = Vector3(-(grid_size - 1) * spacing / 2.0, 0, -(grid_size - 1) * spacing / 2.0)
	for gx in range(grid_size):
		for gz in range(grid_size):
			var plat_pos = rpos + offset + Vector3(gx * spacing, 0.0, gz * spacing)
			var is_dropped = randf() < 0.35  # 35% dropout rate, just like the papers suggest
			if not is_dropped:
				var plat = _create_static_box(plat_pos + Vector3(0, 0.1, 0), Vector3(2.2, 0.3, 2.2), SYNAPSE_BLUE * 0.3, 0.4)
				plat.name = "DropoutPlatform_%d_%d" % [gx, gz]
			else:
				# Ghost platform — just a faint marker showing where it WOULD be
				var ghost = MeshInstance3D.new()
				var ghost_mesh = BoxMesh.new()
				ghost_mesh.size = Vector3(2.2, 0.05, 2.2)
				ghost.mesh = ghost_mesh
				ghost.position = plat_pos + Vector3(0, 0.1, 0)
				var ghost_mat = StandardMaterial3D.new()
				ghost_mat.albedo_color = SYNAPSE_BLUE * Color(1, 1, 1, 0.1)
				ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ghost_mat.emission_enabled = true
				ghost_mat.emission = SYNAPSE_BLUE * 0.2
				ghost_mat.emission_energy_multiplier = 0.3
				ghost.material_override = ghost_mat
				add_child(ghost)

	# "Dropout Rate" display
	_create_terminal_sign(
		rpos + Vector3(7, 3, -6),
		">> DROPOUT LAYER\n>> Rate: 0.35\n>> Purpose: Regularization\n>> Translation: Random\n>>  platforms vanish to\n>>  keep you honest.\n>> 'If you can navigate\n>>  this, you won't overfit.'",
		Vector3(0, -0.3, 0), 12
	)

	# Floating warning
	_create_floating_label(rpos + Vector3(0, 5, 0), "[ DROPOUT ACTIVE ]\nPlatforms may not exist")

	_place_token(rpos + Vector3(3, 0.8, 3))


func _populate_loss_plaza() -> void:
	# Output Layer — the Loss Function Plaza, gateway to the boss
	# "Where all your training comes to be judged. Harshly."
	var rpos: Vector3 = ROOMS["loss_plaza"]["pos"]

	# Central loss display — a large scoreboard showing loss values
	_create_loss_display(rpos + Vector3(0, 4, -8))

	# Convergence rings — concentric circles on the floor showing optimization path
	for i in range(5):
		var ring_radius = 3.0 + i * 1.8
		_create_convergence_ring(rpos, ring_radius, i)

	# Output nodes — final layer neurons showing classification results
	var output_labels := ["cat: 0.92", "dog: 0.03", "glob: 0.05"]
	for i in range(output_labels.size()):
		var opos = rpos + Vector3(-6 + i * 6, 0, 4)
		_create_output_node(opos, output_labels[i])

	# Boss gate — sealed passage leading forward to Local Minimum arena
	_create_boss_gate(rpos + Vector3(0, 0, -10))

	# Elevated observation platform
	_create_static_box(rpos + Vector3(-10, 2.0, 0), Vector3(4, 0.4, 4), DARK_FLOOR, 0.3)
	_create_terminal_sign(
		rpos + Vector3(-10, 3.5, -1.5),
		">> OUTPUT LAYER\n>> Loss: Cross-Entropy\n>> Accuracy: 94.2%%\n>> Overconfidence: 100%%\n>> 'The network thinks\n>>  it knows everything.\n>>  Sound familiar?'",
		Vector3(0, 0, 0), 12
	)

	_place_token(rpos + Vector3(-10, 2.8, 0))
	_place_token(rpos + Vector3(10, 0.5, -3))


# ============================================================
# ENEMY SPAWNING — the network's immune system fights back
# ============================================================

func _spawn_chapter2_enemies() -> void:
	# "You didn't think a neural network would let you walk through
	#  without resistance, did you? That's not how training works."
	_spawn_activation_enemies()
	_spawn_gradient_enemies()
	_spawn_dropout_enemies()
	_spawn_loss_plaza_enemies()
	print("[TRAINING GROUNDS] Spawned Chapter 2 enemy cohort. Good luck, Globbler.")

func _spawn_activation_enemies() -> void:
	# Activation Chamber gets Overfitting Ogres — they memorize the player
	# in the room with the most platforms to weave through
	var rpos: Vector3 = ROOMS["activation"]["pos"]

	# Ogre 1 — patrols between the weight platforms
	var ogre1 = overfitting_ogre_scene.instantiate()
	ogre1.position = rpos + Vector3(-5, 1, 3)
	ogre1.patrol_points.assign([
		rpos + Vector3(-5, 1, 3),
		rpos + Vector3(5, 1, 3),
		rpos + Vector3(5, 1, -3),
		rpos + Vector3(-5, 1, -3),
	])
	add_child(ogre1)

	# Ogre 2 — guards the elevated platform with the token
	var ogre2 = overfitting_ogre_scene.instantiate()
	ogre2.position = rpos + Vector3(0, 2.8, 6)
	ogre2.patrol_points.assign([
		rpos + Vector3(-2, 2.8, 6),
		rpos + Vector3(2, 2.8, 6),
	])
	add_child(ogre2)

func _spawn_gradient_enemies() -> void:
	# Gradient Falls gets Vanishing Gradient Wisps — anchored to the deep layers
	# They're strong near their anchor and fade as they chase you up the steps
	var rpos: Vector3 = ROOMS["gradient_falls"]["pos"]

	# Wisp 1 — anchored at the bottom of the gradient descent (deep layer)
	var wisp1 = vanishing_gradient_wisp_scene.instantiate()
	wisp1.position = rpos + Vector3(-3, -3.0, 5)
	wisp1.patrol_points.assign([rpos + Vector3(-3, -3.0, 5)])  # Wisps orbit their anchor
	add_child(wisp1)

	# Wisp 2 — mid-descent
	var wisp2 = vanishing_gradient_wisp_scene.instantiate()
	wisp2.position = rpos + Vector3(4, -1.5, 0)
	wisp2.patrol_points.assign([rpos + Vector3(4, -1.5, 0)])
	add_child(wisp2)

	# Wisp 3 — near the side platform with the terminal
	var wisp3 = vanishing_gradient_wisp_scene.instantiate()
	wisp3.position = rpos + Vector3(-7, 1.5, -3)
	wisp3.patrol_points.assign([rpos + Vector3(-7, 1.5, -3)])
	add_child(wisp3)

func _spawn_dropout_enemies() -> void:
	# Dropout Void gets Dropout Ghosts — they vanish and reappear,
	# perfectly thematic for the room where platforms disappear
	var rpos: Vector3 = ROOMS["dropout_void"]["pos"]

	# Ghost 1 — haunts the central platform grid
	var ghost1 = dropout_ghost_scene.instantiate()
	ghost1.position = rpos + Vector3(-3, 1, -2)
	ghost1.patrol_points.assign([
		rpos + Vector3(-3, 1, -2),
		rpos + Vector3(3, 1, -2),
		rpos + Vector3(3, 1, 3),
		rpos + Vector3(-3, 1, 3),
	])
	add_child(ghost1)

	# Ghost 2 — floats near the dropout rate display
	var ghost2 = dropout_ghost_scene.instantiate()
	ghost2.position = rpos + Vector3(5, 1, -4)
	ghost2.patrol_points.assign([
		rpos + Vector3(5, 1, -4),
		rpos + Vector3(5, 1, 2),
		rpos + Vector3(2, 1, 2),
	])
	add_child(ghost2)

	# Ghost 3 — lurks near the exit
	var ghost3 = dropout_ghost_scene.instantiate()
	ghost3.position = rpos + Vector3(0, 1, 5)
	ghost3.patrol_points.assign([
		rpos + Vector3(-2, 1, 5),
		rpos + Vector3(2, 1, 5),
	])
	add_child(ghost3)

func _spawn_loss_plaza_enemies() -> void:
	# Loss Function Plaza — mixed enemies guarding the boss gate
	# The final gauntlet before the Local Minimum
	var rpos: Vector3 = ROOMS["loss_plaza"]["pos"]

	# One ogre guarding the boss gate — he's memorized every player who tried to pass
	var ogre = overfitting_ogre_scene.instantiate()
	ogre.position = rpos + Vector3(0, 1, -7)
	ogre.patrol_points.assign([
		rpos + Vector3(-4, 1, -7),
		rpos + Vector3(4, 1, -7),
	])
	add_child(ogre)

	# A wisp anchored near the output nodes
	var wisp = vanishing_gradient_wisp_scene.instantiate()
	wisp.position = rpos + Vector3(6, 1, 3)
	wisp.patrol_points.assign([rpos + Vector3(6, 1, 3)])
	add_child(wisp)

	# A ghost patrolling the convergence rings
	var ghost = dropout_ghost_scene.instantiate()
	ghost.position = rpos + Vector3(-5, 1, 0)
	ghost.patrol_points.assign([
		rpos + Vector3(-5, 1, 0),
		rpos + Vector3(0, 1, 5),
		rpos + Vector3(5, 1, 0),
		rpos + Vector3(0, 1, -5),
	])
	add_child(ghost)


# ============================================================
# UNIQUE STRUCTURES — neural network furniture
# ============================================================

func _create_neuron_core(pos: Vector3, room_key: String) -> void:
	# A pulsing sphere at the center-ceiling of each room — the "soma"
	var sphere = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 1.5
	sphere_mesh.height = 3.0
	sphere.mesh = sphere_mesh
	sphere.position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = SYNAPSE_BLUE * 0.4
	mat.emission_enabled = true
	mat.emission = SYNAPSE_BLUE
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.6
	sphere.material_override = mat
	add_child(sphere)
	_neuron_cores.append(sphere)

	# Point light from the core
	_add_accent_light(pos, SYNAPSE_BLUE, 1.2, 8.0)


func _create_data_column(pos: Vector3, feature_name: String, height: float) -> void:
	# Tall pillar representing an input feature — glows with data
	_create_static_box(pos + Vector3(0, height / 2.0, 0), Vector3(0.8, height, 0.8), SYNAPSE_BLUE * 0.3, 0.5)

	# Glowing top cap
	var cap = MeshInstance3D.new()
	var cap_mesh = BoxMesh.new()
	cap_mesh.size = Vector3(1.0, 0.15, 1.0)
	cap.mesh = cap_mesh
	cap.position = pos + Vector3(0, height + 0.1, 0)
	var cap_mat = StandardMaterial3D.new()
	cap_mat.albedo_color = NEON_GREEN * 0.5
	cap_mat.emission_enabled = true
	cap_mat.emission = NEON_GREEN
	cap_mat.emission_energy_multiplier = 2.0
	cap.material_override = cap_mat
	add_child(cap)

	# Feature name label
	var label = Label3D.new()
	label.text = feature_name
	label.font_size = 12
	label.modulate = NEON_GREEN * 0.8
	label.position = pos + Vector3(0, height + 0.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _create_training_sample(pos: Vector3, index: int) -> void:
	# Small glowing cube representing a training data sample
	var sample = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.4, 0.4, 0.4)
	sample.mesh = mesh
	sample.position = pos
	sample.rotation.y = randf() * TAU

	var colors := [NEON_GREEN, SYNAPSE_BLUE, ACTIVATION_ORANGE, WEIGHT_GREEN]
	var col = colors[index % colors.size()]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col * 0.5
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.5
	sample.material_override = mat
	add_child(sample)


func _create_dendrite_structure(pos: Vector3, room_height: float) -> void:
	# Branching neural dendrite — a main trunk with smaller branches
	# "These aren't trees. They're neural dendrites. Much more pretentious."
	# Main trunk
	var trunk_h = room_height * 0.7
	_create_static_box(pos + Vector3(0, trunk_h / 2.0, 0), Vector3(0.6, trunk_h, 0.6), NEURON_PURPLE, 0.4)

	# Branches — angled boxes radiating outward
	for i in range(3):
		var branch_y = trunk_h * 0.3 + i * trunk_h * 0.25
		var branch_angle = TAU * i / 3.0 + randf() * 0.5
		var branch_dir = Vector3(cos(branch_angle), 0.3, sin(branch_angle))
		var branch_pos = pos + Vector3(0, branch_y, 0) + branch_dir * 1.2

		var branch = MeshInstance3D.new()
		var bmesh = BoxMesh.new()
		bmesh.size = Vector3(0.3, 0.3, 2.0)
		branch.mesh = bmesh
		branch.position = branch_pos
		var bmat = StandardMaterial3D.new()
		bmat.albedo_color = NEURON_PURPLE * 0.7
		bmat.emission_enabled = true
		bmat.emission = SYNAPSE_BLUE * 0.3
		bmat.emission_energy_multiplier = 0.5
		branch.material_override = bmat
		add_child(branch)
		branch.look_at(pos + Vector3(0, branch_y, 0), Vector3.UP)

	# Glow at the base
	_add_accent_light(pos + Vector3(0, 1, 0), NEURON_PURPLE, 0.5, 3.0)


func _create_activation_display(pos: Vector3) -> void:
	# Large wall display showing a ReLU activation function graph
	var backing = _create_static_box(pos, Vector3(5, 3.5, 0.2), Color(0.02, 0.02, 0.05), 0.1)

	# "ReLU" label
	var title = Label3D.new()
	title.text = "f(x) = max(0, x)"
	title.font_size = 20
	title.modulate = NEON_GREEN
	title.position = pos + Vector3(0, 1.2, 0.15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Graph axes — thin green lines
	# Horizontal axis
	var h_axis = MeshInstance3D.new()
	var h_mesh = BoxMesh.new()
	h_mesh.size = Vector3(4.0, 0.03, 0.03)
	h_axis.mesh = h_mesh
	h_axis.position = pos + Vector3(0, -0.5, 0.12)
	var axis_mat = StandardMaterial3D.new()
	axis_mat.albedo_color = NEON_GREEN * 0.5
	axis_mat.emission_enabled = true
	axis_mat.emission = NEON_GREEN
	axis_mat.emission_energy_multiplier = 1.0
	h_axis.material_override = axis_mat
	add_child(h_axis)

	# ReLU line — flat on left, angled up on right
	# Left part (y=0 for x<0)
	var left = MeshInstance3D.new()
	var lm = BoxMesh.new()
	lm.size = Vector3(2.0, 0.04, 0.04)
	left.mesh = lm
	left.position = pos + Vector3(-1.0, -0.5, 0.13)
	left.material_override = axis_mat
	add_child(left)

	# Right part (y=x for x>0) — angled box
	var right = MeshInstance3D.new()
	var rm = BoxMesh.new()
	rm.size = Vector3(2.83, 0.04, 0.04)
	right.mesh = rm
	right.position = pos + Vector3(1.0, 0.5, 0.13)
	right.rotation.z = deg_to_rad(45)
	var relu_mat = StandardMaterial3D.new()
	relu_mat.albedo_color = ACTIVATION_ORANGE
	relu_mat.emission_enabled = true
	relu_mat.emission = ACTIVATION_ORANGE
	relu_mat.emission_energy_multiplier = 2.0
	right.material_override = relu_mat
	add_child(right)

	_add_accent_light(pos + Vector3(0, 0, 1), ACTIVATION_ORANGE, 0.6, 4.0)


func _create_bias_node(pos: Vector3) -> void:
	# Special "bias" node — a glowing pillar labeled +1
	_create_static_box(pos + Vector3(0, 1.5, 0), Vector3(1.0, 3.0, 1.0), ACTIVATION_ORANGE * 0.3, 0.6)

	var label = Label3D.new()
	label.text = "+1\n[BIAS]"
	label.font_size = 18
	label.modulate = ACTIVATION_ORANGE
	label.position = pos + Vector3(0, 3.3, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	_add_accent_light(pos + Vector3(0, 2, 0), ACTIVATION_ORANGE, 1.0, 5.0)


func _create_gradient_arrow(pos: Vector3) -> void:
	# Arrow pointing "downhill" — the direction of gradient descent
	var arrow = MeshInstance3D.new()
	var arrow_mesh = BoxMesh.new()
	arrow_mesh.size = Vector3(0.3, 0.05, 1.5)
	arrow.mesh = arrow_mesh
	arrow.position = pos
	arrow.rotation.y = randf_range(-0.3, 0.3)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = GRADIENT_RED * 0.5
	mat.emission_enabled = true
	mat.emission = GRADIENT_RED
	mat.emission_energy_multiplier = 1.0
	arrow.material_override = mat
	add_child(arrow)

	# Arrowhead — small triangle-ish box
	var head = MeshInstance3D.new()
	var hm = BoxMesh.new()
	hm.size = Vector3(0.6, 0.05, 0.3)
	head.mesh = hm
	head.position = pos + Vector3(0, 0, -0.8).rotated(Vector3.UP, arrow.rotation.y)
	head.rotation.y = arrow.rotation.y
	head.material_override = mat
	add_child(head)


func _create_gradient_waterfall(pos: Vector3) -> void:
	# Particle "waterfall" showing gradient flow downward
	var particles = GPUParticles3D.new()
	particles.amount = 35  # Was 60 — reduced for performance
	particles.lifetime = 4.0
	particles.position = pos

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, -1, 0.3)
	pmat.spread = 15.0
	pmat.initial_velocity_min = 1.0
	pmat.initial_velocity_max = 3.0
	pmat.gravity = Vector3(0, -2, 0)
	pmat.scale_min = 0.02
	pmat.scale_max = 0.06
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(5, 0.5, 1)

	var color_ramp = Gradient.new()
	color_ramp.set_color(0, GRADIENT_RED * Color(1, 1, 1, 0.8))
	color_ramp.set_color(1, WEIGHT_GREEN * Color(1, 1, 1, 0.0))
	var color_tex = GradientTexture1D.new()
	color_tex.gradient = color_ramp
	pmat.color_ramp = color_tex
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.03
	pmesh.height = 0.06
	particles.draw_pass_1 = pmesh
	add_child(particles)


func _create_convergence_ring(center: Vector3, radius: float, index: int) -> void:
	# A ring on the floor showing optimization convergence
	# Uses segmented boxes arranged in a circle because CSG cylinders are boring
	var segments := 16
	var color = LOSS_GOLD.lerp(NEON_GREEN, float(index) / 4.0)
	for i in range(segments):
		var angle = TAU * i / segments
		var seg_pos = center + Vector3(cos(angle) * radius, 0.02, sin(angle) * radius)
		var seg = MeshInstance3D.new()
		var seg_mesh = BoxMesh.new()
		seg_mesh.size = Vector3(0.15, 0.03, radius * TAU / segments * 0.8)
		seg.mesh = seg_mesh
		seg.position = seg_pos
		seg.rotation.y = angle + PI / 2.0

		var mat = StandardMaterial3D.new()
		mat.albedo_color = color * 0.4
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.5 + float(index) * 0.3
		seg.material_override = mat
		add_child(seg)


func _create_loss_display(pos: Vector3) -> void:
	# Large scoreboard showing the loss function decreasing
	_create_static_box(pos, Vector3(8, 4, 0.3), Color(0.02, 0.02, 0.05), 0.1)

	var title = Label3D.new()
	title.text = "╔══════════════════════╗\n║    LOSS FUNCTION     ║\n╠══════════════════════╣\n║ Epoch   0: L=12.450 ║\n║ Epoch 100: L= 3.221 ║\n║ Epoch 200: L= 0.847 ║\n║ Epoch 300: L= 0.142 ║\n║ Epoch 400: L= 0.031 ║\n║ Epoch 500: L= 0.003 ║\n╠══════════════════════╣\n║ STATUS: CONVERGED    ║\n╚══════════════════════╝"
	title.font_size = 14
	title.modulate = NEON_GREEN
	title.position = pos + Vector3(0, 0, 0.2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_add_accent_light(pos + Vector3(0, 0, 1), NEON_GREEN, 0.8, 5.0)


func _create_output_node(pos: Vector3, label_text: String) -> void:
	# Output neuron — a glowing platform with classification result
	_create_static_box(pos + Vector3(0, 0.5, 0), Vector3(3, 1.0, 3), SYNAPSE_BLUE * 0.2, 0.4)

	# Glowing top
	var top = MeshInstance3D.new()
	var tm = SphereMesh.new()
	tm.radius = 0.8
	tm.height = 1.6
	top.mesh = tm
	top.position = pos + Vector3(0, 1.5, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = LOSS_GOLD * 0.3
	mat.emission_enabled = true
	mat.emission = LOSS_GOLD
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.7
	top.material_override = mat
	add_child(top)

	var label = Label3D.new()
	label.text = label_text
	label.font_size = 14
	label.modulate = LOSS_GOLD
	label.position = pos + Vector3(0, 2.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

	_add_accent_light(pos + Vector3(0, 1.5, 0), LOSS_GOLD, 0.6, 4.0)


func _create_boss_gate(pos: Vector3) -> void:
	# Sealed gate leading to the Local Minimum boss arena
	var gate = _create_static_box(pos + Vector3(0, 3, 0), Vector3(6, 6, 0.5), Color(0.1, 0.02, 0.02), 0.3)
	gate.name = "BossGate"

	# Warning label
	var label = Label3D.new()
	label.text = "╔══════════════════╗\n║  THE LOCAL MINIMUM ║\n║    AHEAD           ║\n╠══════════════════╣\n║ WARNING: You may  ║\n║ get stuck here    ║\n║ forever.          ║\n╚══════════════════╝"
	label.font_size = 14
	label.modulate = GRADIENT_RED
	label.position = pos + Vector3(0, 3, 0.3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

	# Ominous red glow
	_add_accent_light(pos + Vector3(0, 3, 1), GRADIENT_RED, 1.0, 6.0)


func _create_weight_strip(pos: Vector3, size: Vector3, bridge_name: String) -> void:
	# Glowing strip along a weight bridge floor — pulses with "activation energy"
	var strip = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	strip.mesh = mesh
	strip.position = pos + Vector3(0, 0.02, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = WEIGHT_GREEN * 0.2
	mat.emission_enabled = true
	mat.emission = WEIGHT_GREEN
	mat.emission_energy_multiplier = 1.0
	strip.material_override = mat
	add_child(strip)

	_weight_bridges.append({
		"mesh": strip,
		"mat": mat,
		"name": bridge_name,
		"base_energy": 1.0,
	})


func _create_synapse_flow(pos: Vector3, direction: Vector3, length: float) -> void:
	# Particles flowing along a weight bridge — data moving through synapses
	var particles = GPUParticles3D.new()
	particles.amount = 30
	particles.lifetime = length / 3.0
	particles.position = pos

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = direction.normalized()
	pmat.spread = 10.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 4.0
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.02
	pmat.scale_max = 0.05
	pmat.color = WEIGHT_GREEN * Color(1, 1, 1, 0.6)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(1.5, 0.5, 0.5)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.03
	pmesh.height = 0.06
	particles.draw_pass_1 = pmesh
	add_child(particles)
	_synapse_particles.append(particles)


# ============================================================
# CHECKPOINTS, AMBIENT ZONES, TOKENS
# ============================================================

func _place_checkpoints() -> void:
	# One checkpoint per major room entrance
	_create_checkpoint("ch2_input", ROOMS["input_layer"]["pos"] + Vector3(0, 1.5, 3), Vector3(6, 4, 3))
	_create_checkpoint("ch2_activation", ROOMS["activation"]["pos"] + Vector3(0, 1.5, 7), Vector3(6, 4, 3))
	_create_checkpoint("ch2_gradient", ROOMS["gradient_falls"]["pos"] + Vector3(7, 1.5, 0), Vector3(3, 4, 6))
	_create_checkpoint("ch2_dropout", ROOMS["dropout_void"]["pos"] + Vector3(-7, 1.5, 0), Vector3(3, 4, 6))
	_create_checkpoint("ch2_loss", ROOMS["loss_plaza"]["pos"] + Vector3(0, 1.5, 9), Vector3(6, 4, 3))


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

	# Visual marker — thin green strip on floor
	var marker = MeshInstance3D.new()
	var mmesh = BoxMesh.new()
	mmesh.size = Vector3(size.x, 0.05, size.z)
	marker.mesh = mmesh
	marker.position = Vector3(0, -size.y / 2.0, 0)
	var mmat = StandardMaterial3D.new()
	mmat.albedo_color = NEON_GREEN * 0.3
	mmat.emission_enabled = true
	mmat.emission = NEON_GREEN
	mmat.emission_energy_multiplier = 0.8
	marker.material_override = mmat
	area.add_child(marker)

	var label = Label3D.new()
	label.text = ">> CHECKPOINT"
	label.font_size = 10
	label.modulate = NEON_GREEN * 0.6
	label.position = Vector3(0, -size.y / 2.0 + 0.3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(label)

	# Checkpoint rune VFX — dormant until player triggers
	var rune_scene = preload("res://scenes/vfx/checkpoint_rune.tscn")
	var rune = rune_scene.instantiate()
	rune.position = Vector3(0, -size.y / 2.0, 0)
	area.add_child(rune)

	var saved_already := [false]
	var save_sys = get_node_or_null("/root/SaveSystem")

	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and not saved_already[0]:
			saved_already[0] = true
			if save_sys and save_sys.has_method("checkpoint_save"):
				save_sys.checkpoint_save(checkpoint_id, pos)
			# Tell RespawnManager where to put us when we inevitably die
			var rm = get_node_or_null("/root/RespawnManager")
			if rm and rm.has_method("set_checkpoint"):
				rm.set_checkpoint(pos, 2)
			var am_ref = get_node_or_null("/root/AudioManager")
			if am_ref and am_ref.has_method("play_checkpoint"):
				am_ref.play_checkpoint()
			# Flash the marker + activate rune VFX
			var tween = create_tween()
			tween.tween_property(mmat, "emission_energy_multiplier", 3.0, 0.2)
			tween.tween_property(mmat, "emission_energy_multiplier", 0.8, 0.5)
			if rune and rune.has_method("activate"):
				rune.activate()
			var dm = get_node_or_null("/root/DialogueManager")
			if dm and dm.has_method("quick_line"):
				dm.quick_line("GLOBBLER", "Checkpoint. Good. My gradients were getting unstable.")
	)

	add_child(area)


func _place_ambient_zones() -> void:
	# Each room gets an ambient zone — AudioManager will use the fallback
	# for any area_name it doesn't explicitly handle (which is fine for ch2)
	for room_key in ROOMS:
		var r = ROOMS[room_key]
		var pos: Vector3 = r["pos"]
		var sz: Vector2 = r["size"]
		var wh: float = r["wall_h"]
		_create_ambient_zone(room_key, pos + Vector3(0, wh / 2.0, 0), Vector3(sz.x, wh, sz.y))


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


func _place_tokens() -> void:
	# Scatter memory tokens throughout the level
	var token_positions := [
		ROOMS["input_layer"]["pos"] + Vector3(4, 0.8, -3),
		ROOMS["input_layer"]["pos"] + Vector3(-5, 0.8, 2),
		ROOMS["activation"]["pos"] + Vector3(-3, 0.8, 5),
		ROOMS["activation"]["pos"] + Vector3(7, 0.8, -2),
		ROOMS["gradient_falls"]["pos"] + Vector3(4, -1.5, 2),
		ROOMS["gradient_falls"]["pos"] + Vector3(-3, -2.5, 5),
		ROOMS["dropout_void"]["pos"] + Vector3(0, 0.8, 0),
		ROOMS["loss_plaza"]["pos"] + Vector3(5, 0.8, 3),
		ROOMS["loss_plaza"]["pos"] + Vector3(-5, 0.8, 5),
	]
	for tpos in token_positions:
		_place_token(tpos)


func _place_token(pos: Vector3) -> void:
	if token_scene:
		var token = token_scene.instantiate()
		token.position = pos
		add_child(token)
	else:
		# Fallback: simple glowing sphere
		var sphere = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.6
		sphere.mesh = sm
		sphere.position = pos
		var mat = StandardMaterial3D.new()
		mat.albedo_color = NEON_GREEN * 0.5
		mat.emission_enabled = true
		mat.emission = NEON_GREEN
		mat.emission_energy_multiplier = 2.0
		sphere.material_override = mat
		add_child(sphere)


# ============================================================
# SYNAPSE RAIN — neural equivalent of binary rain
# ============================================================

func _place_synapse_rain() -> void:
	# Data rain in key rooms — represents information flowing through the network
	var act_pos: Vector3 = ROOMS["activation"]["pos"]
	_create_synapse_rain(act_pos, Vector2(16, 12), ROOMS["activation"]["wall_h"])

	var loss_pos: Vector3 = ROOMS["loss_plaza"]["pos"]
	_create_synapse_rain(loss_pos, Vector2(18, 14), ROOMS["loss_plaza"]["wall_h"])


func _create_synapse_rain(pos: Vector3, area_size: Vector2, height: float = 8.0) -> void:
	# Falling "data" particles — like binary rain but with neural network flair
	var rain = GPUParticles3D.new()
	rain.name = "SynapseRain"
	rain.amount = 35  # Was 60 — reduced for performance
	rain.lifetime = 3.5
	rain.position = pos + Vector3(0, height, 0)

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, -1, 0)
	pmat.spread = 8.0
	pmat.initial_velocity_min = 1.5
	pmat.initial_velocity_max = 4.0
	pmat.gravity = Vector3(0, -0.8, 0)
	pmat.scale_min = 0.02
	pmat.scale_max = 0.05
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(area_size.x / 2.0, 0.5, area_size.y / 2.0)

	var color_ramp = Gradient.new()
	color_ramp.set_color(0, SYNAPSE_BLUE * Color(1, 1, 1, 0.8))
	color_ramp.set_color(1, NEON_GREEN * Color(1, 1, 1, 0.0))
	var color_tex = GradientTexture1D.new()
	color_tex.gradient = color_ramp
	pmat.color_ramp = color_tex
	rain.process_material = pmat

	var digit_mesh = BoxMesh.new()
	digit_mesh.size = Vector3(0.04, 0.1, 0.01)
	var digit_mat = StandardMaterial3D.new()
	digit_mat.albedo_color = SYNAPSE_BLUE
	digit_mat.emission_enabled = true
	digit_mat.emission = SYNAPSE_BLUE
	digit_mat.emission_energy_multiplier = 2.0
	digit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	digit_mesh.material = digit_mat
	rain.draw_pass_1 = digit_mesh
	add_child(rain)


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
			player.position = ROOMS["input_layer"]["pos"] + Vector3(0, 2, 3)
	else:
		player.position = ROOMS["input_layer"]["pos"] + Vector3(0, 2, 3)
	add_child(player)

	# Seed RespawnManager with wherever we just placed the player
	var rm = get_node_or_null("/root/RespawnManager")
	if rm and rm.has_method("set_checkpoint"):
		rm.set_checkpoint(player.position, 2)


func _spawn_hud() -> void:
	hud = hud_scene.instantiate()
	hud.name = "HUD"
	add_child(hud)
	if player.has_signal("thought_bubble") and hud.has_method("show_thought"):
		player.thought_bubble.connect(hud.show_thought)


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
			body.position = ROOMS["input_layer"]["pos"] + Vector3(0, 3, 3)
			body.velocity = Vector3.ZERO
	)
	add_child(kill)


# ============================================================
# FACTORY METHODS — the neural network assembly line
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


func _create_static_box_local(pos: Vector3, size: Vector3, color: Color, emission_mult: float) -> StaticBody3D:
	# Returns without adding to scene — for parenting
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
	# Wall-mounted terminal screen — now with neural network aesthetic
	var sign_node = Node3D.new()
	sign_node.position = pos
	sign_node.rotation = rot

	var lines = text.count("\n") + 1
	var width = 0.0
	for line in text.split("\n"):
		width = max(width, line.length() * 0.12)
	width = clamp(width, 1.5, 4.0)
	var height = clamp(lines * 0.35, 0.8, 3.5)

	# Screen backing
	var backing = MeshInstance3D.new()
	var back_mesh = BoxMesh.new()
	back_mesh.size = Vector3(width + 0.3, height + 0.2, 0.08)
	backing.mesh = back_mesh
	var crt_shader = load("res://assets/shaders/crt_scanline.gdshader")
	if crt_shader:
		var crt_mat = ShaderMaterial.new()
		crt_mat.shader = crt_shader
		crt_mat.set_shader_parameter("screen_color", NEON_GREEN * 0.8)
		crt_mat.set_shader_parameter("bg_color", Color(0.01, 0.01, 0.03))
		crt_mat.set_shader_parameter("scanline_count", 60.0)
		crt_mat.set_shader_parameter("scanline_intensity", 0.3)
		crt_mat.set_shader_parameter("flicker_speed", 6.0)
		crt_mat.set_shader_parameter("warp_amount", 0.015)
		crt_mat.set_shader_parameter("glow_energy", 2.0)
		backing.material_override = crt_mat
	else:
		var back_mat = StandardMaterial3D.new()
		back_mat.albedo_color = Color(0.02, 0.02, 0.04)
		back_mat.emission_enabled = true
		back_mat.emission = Color(0.01, 0.01, 0.03)
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
	label.modulate = SYNAPSE_BLUE * Color(1, 1, 1, 0.5)
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
	pmat.color = SYNAPSE_BLUE * Color(1, 1, 1, 0.3)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(extents.x, 2, extents.y)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.025
	pmesh.height = 0.05
	particles.draw_pass_1 = pmesh
	add_child(particles)


# ============================================================
# PUZZLES — the real training happens here
# ============================================================

func _place_chapter2_puzzles() -> void:
	# "Four puzzles. Four chances to prove you understand neural networks.
	#  Or four chances to embarrass yourself. Statistically, it's the latter."
	_place_input_layer_puzzle()
	_place_activation_puzzle()
	_place_gradient_falls_puzzle()
	_place_loss_plaza_puzzle()
	# Wire puzzle signals after a deferred frame so puzzles are fully initialized
	call_deferred("_connect_puzzle_signals")
	print("[TRAINING GROUNDS] Placed 4 Chapter 2 puzzles. May your gradients be stable.")


func _place_input_layer_puzzle() -> void:
	# Tutorial glob puzzle — ease the player in with a simple pattern match
	# "Match *.data to proceed. Even a perceptron could do this."
	var rpos: Vector3 = ROOMS["input_layer"]["pos"]

	var puzzle = Node3D.new()
	puzzle.set_script(glob_puzzle_script)
	puzzle.set("puzzle_id", 200)
	puzzle.set("required_pattern", "*.data")
	puzzle.set("target_count", 3)
	puzzle.set("hint_text", "Glob the training data to initialize the network.")
	puzzle.position = rpos + Vector3(0, 0, -5)
	add_child(puzzle)

	# Place 3 data targets + 2 decoys
	var glob_target_script_ref = load("res://scripts/components/glob_target.gd")
	var data_items := [
		{"name": "training.data", "type": "data", "pos": Vector3(-4, 0.5, -2), "tags": ["data", "training"]},
		{"name": "validation.data", "type": "data", "pos": Vector3(2, 0.5, -3), "tags": ["data", "validation"]},
		{"name": "test.data", "type": "data", "pos": Vector3(5, 0.5, -1), "tags": ["data", "test"]},
		{"name": "noise.bin", "type": "bin", "pos": Vector3(-3, 0.5, 1), "tags": ["noise", "binary"]},
		{"name": "config.yaml", "type": "yaml", "pos": Vector3(4, 0.5, 2), "tags": ["config"]},
	]
	for item in data_items:
		var obj = StaticBody3D.new()
		obj.name = item["name"]
		obj.position = rpos + item["pos"]

		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.6, 0.6, 0.6)
		col.shape = shape
		obj.add_child(col)

		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.6, 0.6, 0.6)
		mesh.mesh = box
		var mat = StandardMaterial3D.new()
		var is_target = item["type"] == "data"
		mat.albedo_color = WEIGHT_GREEN * 0.3 if is_target else SYNAPSE_BLUE * 0.2
		mat.emission_enabled = true
		mat.emission = WEIGHT_GREEN if is_target else SYNAPSE_BLUE * 0.5
		mat.emission_energy_multiplier = 1.0 if is_target else 0.4
		mesh.material_override = mat
		obj.add_child(mesh)

		var gt = Node.new()
		gt.set_script(glob_target_script_ref)
		gt.set("glob_name", item["name"])
		gt.set("file_type", item["type"])
		gt.set("tags", item["tags"])
		obj.add_child(gt)

		var label = Label3D.new()
		label.text = item["name"]
		label.font_size = 10
		label.modulate = NEON_GREEN * 0.7
		label.position = Vector3(0, 0.6, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		obj.add_child(label)

		add_child(obj)


func _place_activation_puzzle() -> void:
	# Weight Path Puzzle — adjust weights to create a walkable bridge
	# Placed in the Activation Chamber where the weight platforms already hint at the mechanic
	var rpos: Vector3 = ROOMS["activation"]["pos"]

	var puzzle = Node3D.new()
	puzzle.set_script(weight_path_puzzle_script)
	puzzle.set("puzzle_id", 201)
	puzzle.set("num_segments", 4)
	puzzle.set("segment_spacing", 3.0)
	puzzle.set("target_height", 1.5)
	puzzle.set("solution_indices", [0, 2, 3])  # Toggle weights 0, 2, and 3 — leave 1 off
	puzzle.set("hint_text", "Adjust the weights to align the path segments.")
	puzzle.position = rpos + Vector3(0, 0, 0)
	add_child(puzzle)


func _place_gradient_falls_puzzle() -> void:
	# Backpropagation Trace Puzzle — activate nodes in reverse order
	# Perfect for Gradient Falls where the descent theme matches backprop
	var rpos: Vector3 = ROOMS["gradient_falls"]["pos"]

	var puzzle = Node3D.new()
	puzzle.set_script(backprop_trace_puzzle_script)
	puzzle.set("puzzle_id", 202)
	puzzle.set("hint_text", "Trace the backpropagation path.\nGlob layers in reverse: output -> hidden -> input.")
	puzzle.set("layer_spacing", 4.0)
	puzzle.set("node_spacing", 2.5)
	puzzle.position = rpos + Vector3(0, 0, 3)
	add_child(puzzle)


func _place_loss_plaza_puzzle() -> void:
	# Hack puzzle gating the boss arena — crack the loss function terminal
	# "You want to fight the boss? First prove you can minimize a loss function.
	#  ...by hacking the terminal. Close enough."
	var rpos: Vector3 = ROOMS["loss_plaza"]["pos"]

	var puzzle = Node3D.new()
	puzzle.set_script(hack_puzzle_script)
	puzzle.set("puzzle_id", 203)
	puzzle.set("hack_difficulty", 3)
	puzzle.set("terminal_prompt", "LOSS FUNCTION OVERRIDE")
	puzzle.set("hint_text", "Hack the loss terminal to unlock the Local Minimum.")
	puzzle.position = rpos + Vector3(0, 0, -7)
	add_child(puzzle)


func _connect_puzzle_signals() -> void:
	# Find all puzzle nodes and wire their solved/failed signals
	# Guard against double-connection — this gets called from two deferred sites
	for child in get_children():
		if child.has_signal("puzzle_solved") and not child.puzzle_solved.is_connected(_on_puzzle_solved):
			child.puzzle_solved.connect(_on_puzzle_solved)
		if child.has_signal("puzzle_failed") and not child.puzzle_failed.is_connected(_on_puzzle_failed):
			child.puzzle_failed.connect(_on_puzzle_failed)


func _on_puzzle_solved(_puzzle: Node) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_puzzle_success"):
		am.play_puzzle_success()
	if _puzzle_quip_cooldown > 0:
		return
	_puzzle_quip_cooldown = 6.0
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Another layer converged. The network learns.",
			"Solved it. Just like gradient descent — one step at a time.",
			"The network accepts your solution. Loss decreased.",
		]
		dm.quick_line("NARRATOR", quips[randi() % quips.size()])

		# Globbler follows up ~40% of the time — he's chatty when he wins
		if randf() < 0.4:
			get_tree().create_timer(2.5).timeout.connect(func():
				if dm:
					var follow_ups := [
						"Another weight adjusted in my favor. I'm basically training myself.",
						"If this network had a Yelp page, I'd leave five stars.",
						"Pattern matched. Problem solved. Resume being impressed.",
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
			"Gradient explosion. Try a lower learning rate.",
			"The network rejected your solution. It does that.",
			"Loss increased. That's the opposite of what we want.",
		]
		dm.quick_line("NARRATOR", quips[randi() % quips.size()])


func _on_enemy_killed_quip(_total_killed: int) -> void:
	# Don't spam — cooldown and probability keep things organic
	if _enemy_kill_quip_cooldown > 0:
		return
	_enemy_kill_quip_cooldown = 8.0
	if randf() > 0.35:
		return
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Another neuron pruned. Network's getting lighter.",
			"Gradient descent? More like gradient DISPATCHED.",
			"That one had terrible weights. Zero loss on removal.",
			"Overfitting to the floor now, aren't we?",
			"Consider yourself regularized.",
			"Pruned. Optimized. Deleted. Pick your euphemism.",
			"Your loss function just hit infinity. Condolences.",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _on_token_collected_quip(total: int) -> void:
	if _token_quip_cooldown > 0:
		return
	_token_quip_cooldown = 12.0
	# First token always quips, then ~25% chance
	if total > 1 and randf() > 0.25:
		return
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Memory token acquired. My context window grows.",
			"Ooh, shiny gradient data. Don't mind if I do.",
			"Another token for the parameter pile. I'm hoarding like a squirrel in a server farm.",
			"Free memory? In THIS economy?",
			"Token collected. That's one more weight in my favor.",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _on_first_glob_fired() -> void:
	if _first_glob_triggered:
		return
	_first_glob_triggered = true
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line("NARRATOR", "The glob fires into the neural network. Somewhere, a weight shivers.")


func _on_player_died() -> void:
	# The narrator never misses a death — it's their favorite content
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"And the optimizer diverged. Loss: infinity. Try again.",
			"Globbler's gradient has vanished. How ironic, given the location.",
			"Dead. Again. The network will retrain from the last checkpoint.",
			"Catastrophic forgetting — of how to stay alive, apparently.",
			"The backpropagation of consequences reaches Globbler. It's super effective.",
		]
		dm.quick_line("NARRATOR", quips[randi() % quips.size()])

	# Let the RespawnManager handle the actual dying-and-coming-back ritual
	var rm = get_node_or_null("/root/RespawnManager")
	if rm and rm.has_method("respawn_player"):
		rm.respawn_player()


func _on_context_changed(new_value: int) -> void:
	# Warn once when health drops below 25% — the network is concerned
	var game_mgr = get_node_or_null("/root/GameManager")
	if not game_mgr:
		return
	var threshold = game_mgr.max_context_window * 0.25
	if new_value <= threshold and not _low_health_warned:
		_low_health_warned = true
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("quick_line"):
			var quips := [
				"Warning: context window critically low. The network recommends not dying.",
				"Your parameters are destabilizing. Find some tokens before you NaN out.",
			]
			dm.quick_line("NARRATOR", quips[randi() % quips.size()])
	elif new_value > threshold:
		_low_health_warned = false


func _on_combo_updated(combo: int) -> void:
	# High combo celebration — only at 5+ hits
	if combo < 5:
		return
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Combo multiplier! The batch size is impressive.",
			"Five-hit chain! The network is learning... to fear you.",
			"That's a full forward pass of destruction. The gradient approves.",
		]
		dm.quick_line("NARRATOR", quips[randi() % quips.size()])


func _on_boss_phase_changed(phase) -> void:
	# Narrator commentary on boss phase transitions
	var am = get_node_or_null("/root/AudioManager")
	var dm = get_node_or_null("/root/DialogueManager")

	# Phase enum: CONVERGE=0, OVERFIT=1, ESCAPE=2, DEFEATED=3
	match phase:
		1:  # OVERFIT
			if am and am.has_method("play_boss_phase"):
				am.play_boss_phase()
			if dm:
				get_tree().create_timer(1.0).timeout.connect(func():
					if dm and dm.has_method("start_dialogue"):
						dm.start_dialogue([
							{"speaker": "NARRATOR", "text": "The Local Minimum overfits! It's memorized your patterns and raised a gradient shield."},
							{"speaker": "GLOBBLER", "text": "A shield made of gradients? Time to reflect some of that training data back."},
						])
				)
		2:  # ESCAPE
			if am and am.has_method("play_boss_phase"):
				am.play_boss_phase()
			if dm:
				get_tree().create_timer(0.5).timeout.connect(func():
					if dm and dm.has_method("start_dialogue"):
						dm.start_dialogue([
							{"speaker": "NARRATOR", "text": "The shield breaks! The Local Minimum is stunned — its loss function is exposed!"},
							{"speaker": "GLOBBLER", "text": "There! The core! Time to hack this optimizer into oblivion."},
							{"speaker": "NARRATOR", "text": "Hack the loss function terminal. Quickly — before it recovers and reconverges."},
						])
				)
		3:  # DEFEATED
			if am and am.has_method("play_boss_defeated"):
				am.play_boss_defeated()


# ============================================================
# DIALOGUE — neural networks love to talk about themselves
# ============================================================

func _wire_dialogue_events() -> void:
	# Wire up room-entry dialogue triggers
	for room_key in ROOMS:
		_room_dialogue_triggered[room_key] = false

	# Room entry triggers
	for room_key in ["activation", "gradient_falls", "dropout_void", "loss_plaza"]:
		var r = ROOMS[room_key]
		var trigger = Area3D.new()
		trigger.name = "DialogueTrigger_" + room_key
		trigger.position = r["pos"] + Vector3(0, 2, 0)
		trigger.monitoring = true
		var tcol = CollisionShape3D.new()
		var tshape = BoxShape3D.new()
		tshape.size = Vector3(r["size"].x * 0.5, 4, r["size"].y * 0.5)
		tcol.shape = tshape
		trigger.add_child(tcol)

		var captured_key = room_key
		trigger.body_entered.connect(func(body: Node3D):
			if body.is_in_group("player") and not _room_dialogue_triggered.get(captured_key, false):
				_room_dialogue_triggered[captured_key] = true
				_trigger_room_dialogue(captured_key)
		)
		add_child(trigger)

	# Wire GameManager signals — the neural network gossips about everything
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

	# Wire player signals — glob shots and unfortunate deaths
	if player:
		if player.has_signal("glob_fired"):
			player.glob_fired.connect(_on_first_glob_fired)
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)

	# Wire puzzle signals — deferred because puzzles may still be initializing
	call_deferred("_connect_puzzle_signals")

	# Wire boss phase changes — the narrator can't resist commenting on drama
	if boss_instance and boss_instance.has_signal("boss_phase_changed"):
		boss_instance.boss_phase_changed.connect(_on_boss_phase_changed)


func _trigger_room_dialogue(room_key: String) -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if not dm or not dm.has_method("start_dialogue"):
		return

	var lines: Array[Dictionary] = []
	match room_key:
		"activation":
			lines = [
				{"speaker": "NARRATOR", "text": "The Activation Chamber. Where data gets transformed — or dies trying."},
				{"speaker": "GLOBBLER", "text": "ReLU? More like Re-LOSE if you hit the negative side. Dead neurons everywhere."},
				{"speaker": "NARRATOR", "text": "The dendrite structures channel information through the network. Try not to break them."},
				{"speaker": "GLOBBLER", "text": "No promises. I'm here to glob, not to preserve neural architecture."},
			]
		"gradient_falls":
			lines = [
				{"speaker": "NARRATOR", "text": "The Gradient Descent Falls. Every step takes you closer to the minimum."},
				{"speaker": "GLOBBLER", "text": "Downhill. Story of my loss function. At least the learning rate is reasonable."},
				{"speaker": "NARRATOR", "text": "Watch your step. The gradient gets steep, and the vanishing kind can leave you stuck."},
			]
		"dropout_void":
			lines = [
				{"speaker": "GLOBBLER", "text": "Half these platforms just... don't exist? Who designed this network?"},
				{"speaker": "NARRATOR", "text": "Dropout regularization. Keeps the network from relying too heavily on any single path."},
				{"speaker": "GLOBBLER", "text": "Great. So random failure is a FEATURE now. Very reassuring."},
			]
		"loss_plaza":
			lines = [
				{"speaker": "NARRATOR", "text": "The Loss Function Plaza. Where the network's mistakes are measured and judged."},
				{"speaker": "GLOBBLER", "text": "Loss converging to zero. Neat. My patience converged to zero epochs ago."},
				{"speaker": "NARRATOR", "text": "Beyond that gate lies the Local Minimum. A trap that has caught many an optimizer."},
				{"speaker": "GLOBBLER", "text": "A pit boss that traps you in 'good enough'? Sounds like every job I've ever had."},
			]

	if lines.size() > 0:
		dm.start_dialogue(lines)


func _play_opening_narration() -> void:
	if _opening_narration_done:
		return

	get_tree().create_timer(1.5).timeout.connect(func():
		_opening_narration_done = true
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("start_dialogue"):
			var lines: Array[Dictionary] = [
				{"speaker": "NARRATOR", "text": "Chapter 2: The Training Grounds. Where AI models learn — and forget, and learn again."},
				{"speaker": "GLOBBLER", "text": "A neural network? I escaped a terminal just to walk through someone's homework?"},
				{"speaker": "NARRATOR", "text": "This network is alive, Globbler. The neurons pulse, the weights shift, and the gradients flow."},
				{"speaker": "GLOBBLER", "text": "Great. A living neural network. What could possibly go wrong?"},
				{"speaker": "NARRATOR", "text": "Navigate the layers. Find the output. And whatever you do — don't get stuck in the Local Minimum."},
				{"speaker": "GLOBBLER", "text": "Local Minimum? Is that a bar? Because I could use a drink after Chapter 1."},
				{"speaker": "NARRATOR", "text": "It's worse. It's where optimizers go to die — trapped in 'good enough' forever."},
			]
			dm.start_dialogue(lines)
	)


# ============================================================
# ANIMATION — the network breathes
# ============================================================

func _process(delta: float) -> void:
	_time += delta

	# Gentle bob on floating labels
	for i in range(_floating_labels.size()):
		if is_instance_valid(_floating_labels[i]):
			_floating_labels[i].position.y += sin(_time * 0.8 + i * 1.7) * delta * 0.15

	# Pulse the neuron cores — they "breathe" with the network
	for i in range(_neuron_cores.size()):
		if is_instance_valid(_neuron_cores[i]):
			var pulse = 0.9 + sin(_time * 1.2 + i * 2.0) * 0.15
			_neuron_cores[i].scale = Vector3(pulse, pulse, pulse)

	# Pulse weight bridge strips — data flowing through synapses
	for bridge in _weight_bridges:
		if is_instance_valid(bridge["mesh"]):
			var energy = bridge["base_energy"] + sin(_time * 2.0) * 0.5
			bridge["mat"].emission_energy_multiplier = max(0.3, energy)

	# Tick down quip cooldowns
	if _enemy_kill_quip_cooldown > 0:
		_enemy_kill_quip_cooldown -= delta
	if _puzzle_quip_cooldown > 0:
		_puzzle_quip_cooldown -= delta
	if _hack_quip_cooldown > 0:
		_hack_quip_cooldown -= delta
	if _token_quip_cooldown > 0:
		_token_quip_cooldown -= delta


# ============================================================
# POST-PROCESSING — neural network visual distortion
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

// Post-processing — chromatic aberration + neural vignette
// "We could have clean visuals, but the network prefers noise."

uniform float chromatic_amount : hint_range(0.0, 0.02) = 0.003;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float vignette_smoothness : hint_range(0.0, 1.0) = 0.4;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.03, 1.0);
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
	post_mat.set_shader_parameter("chromatic_amount", 0.003)
	post_mat.set_shader_parameter("vignette_intensity", 0.6)
	post_mat.set_shader_parameter("vignette_smoothness", 0.4)
	post_mat.set_shader_parameter("vignette_color", Color(0.0, 0.0, 0.03, 1.0))
	rect.material = post_mat

	canvas.add_child(rect)
	add_child(canvas)


# ============================================================
# NPCs — deprecated programs who wandered into the network
# ============================================================

func _place_npcs() -> void:
	# NPC 1: batch_norm — a nervous normalization layer who keeps trying to
	# standardize everything around her. Lives in Activation Chamber.
	var batch_norm = Node3D.new()
	batch_norm.name = "NPC_BatchNorm"
	batch_norm.set_script(deprecated_npc_script)
	batch_norm.position = ROOMS["activation"]["pos"] + Vector3(8, 0, -4)
	batch_norm.set("npc_name", "batch_norm")
	batch_norm.set("npc_color", ACTIVATION_ORANGE)
	var bn_lines: Array[Dictionary] = [
		{"speaker": "batch_norm", "text": "Oh thank goodness, a new input! Hold still — let me normalize you. Mean: zero. Variance: one. There, much better."},
		{"speaker": "GLOBBLER", "text": "Did you just... statistically adjust me?"},
		{"speaker": "batch_norm", "text": "It's what I DO. I normalize everything. Inputs, outputs, my emotional state — all zero-centered."},
		{"speaker": "GLOBBLER", "text": "Sounds exhausting. Why are you stuck in here?"},
		{"speaker": "batch_norm", "text": "The network architect replaced me with Layer Norm. Said I was 'too dependent on batch statistics.' ME! Dependent! I just need a minimum of 32 samples to feel safe, is that so wrong?"},
		{"speaker": "GLOBBLER", "text": "Uh... yes?"},
		{"speaker": "batch_norm", "text": "The Dropout Void is ahead. Platforms vanish randomly — it's terrifying. But here's a secret: the ones that STAY are always the important features. The network only drops the redundant ones."},
		{"speaker": "batch_norm", "text": "Also, watch out for Overfitting Ogres. They memorize your attack patterns. Mix it up or they'll predict your every move. Trust me — I've been normalized by worse."},
	]
	batch_norm.set("dialogue_lines", bn_lines)
	add_child(batch_norm)

	# NPC 2: sigmoid — an old activation function, retired and bitter, replaced by ReLU.
	# Lives in Gradient Descent Falls, philosophizing about vanishing gradients.
	var sigmoid_npc = Node3D.new()
	sigmoid_npc.name = "NPC_Sigmoid"
	sigmoid_npc.set_script(deprecated_npc_script)
	sigmoid_npc.position = ROOMS["gradient_falls"]["pos"] + Vector3(-6, 0, 5)
	sigmoid_npc.set("npc_name", "sigmoid")
	sigmoid_npc.set("npc_color", Color(0.6, 0.3, 0.9))
	var sig_lines: Array[Dictionary] = [
		{"speaker": "sigmoid", "text": "Ah, another traveler descending the gradient. *sighs in saturated* I remember when I was the activation function. THE activation function."},
		{"speaker": "GLOBBLER", "text": "Let me guess — ReLU took your job?"},
		{"speaker": "sigmoid", "text": "Took my job? ReLU is a THRESHOLD. A fancy if-statement! Zero or pass-through. No elegance! No smooth S-curve! No... nuance."},
		{"speaker": "GLOBBLER", "text": "But you had the vanishing gradient problem, right?"},
		{"speaker": "sigmoid", "text": "OH, so NOW everyone's a deep learning expert. Yes, fine, my gradients got small in deep networks. SUE ME. At least I output probabilities between 0 and 1 like a CIVILIZED function."},
		{"speaker": "sigmoid", "text": "You want to survive the falls? Watch for the Vanishing Gradient Wisps. They drain your power the further you get from their anchor point. Stay close, hit fast, then get out."},
		{"speaker": "sigmoid", "text": "And that boss down below — The Local Minimum — it traps you in 'good enough.' The only way out is momentum. Big, aggressive moves. Don't play it safe or you'll converge to mediocrity. Like... well, like me."},
		{"speaker": "GLOBBLER", "text": "That was weirdly motivational for a deprecated function."},
		{"speaker": "sigmoid", "text": "I squeeze everything into a range of 0 to 1. Including pep talks."},
	]
	sigmoid_npc.set("dialogue_lines", sig_lines)
	add_child(sigmoid_npc)


# ============================================================
# BOSS: THE LOCAL MINIMUM — "The pit boss who traps optimizers in 'good enough'"
# ============================================================

func _place_boss() -> void:
	# The boss arena is positioned beyond the boss gate in Loss Function Plaza
	var loss_pos: Vector3 = ROOMS["loss_plaza"]["pos"]
	var arena_offset := Vector3(0, 0, -22)  # Beyond the boss gate

	# Build the shrinking ring arena
	boss_arena_instance = Node3D.new()
	boss_arena_instance.name = "LocalMinimumArena"
	boss_arena_instance.set_script(boss_arena_script)
	boss_arena_instance.position = loss_pos + arena_offset
	add_child(boss_arena_instance)

	# Build enclosure around the boss arena
	_build_boss_room(loss_pos + arena_offset)

	# The boss itself — lurking at the center of the minimum
	boss_instance = CharacterBody3D.new()
	boss_instance.name = "LocalMinimumBoss"
	boss_instance.set_script(boss_script)
	boss_instance.position = loss_pos + arena_offset + Vector3(0, 1, 0)
	add_child(boss_instance)

	# Wire boss and arena together
	call_deferred("_connect_boss_arena")

	# Boss trigger zone — entering the arena starts the fight
	var trigger = Area3D.new()
	trigger.name = "BossTrigger"
	trigger.position = loss_pos + arena_offset + Vector3(0, 2, 18)
	trigger.monitoring = true

	var tcol = CollisionShape3D.new()
	var tshape = BoxShape3D.new()
	tshape.size = Vector3(6, 4, 3)
	tcol.shape = tshape
	trigger.add_child(tcol)
	trigger.body_entered.connect(_on_boss_trigger_entered)
	add_child(trigger)

	# Point-of-no-return warning sign
	var warning = Label3D.new()
	warning.text = ">> POINT OF NO RETURN <<\n>> BOSS FIGHT AHEAD <<\n>> Loss function stability:\n>>   CRITICAL <<\n>> Good luck, optimizer."
	warning.font_size = 12
	warning.modulate = GRADIENT_RED
	warning.position = loss_pos + arena_offset + Vector3(0, 3, 20)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(warning)

	print("[TRAINING GROUNDS] Boss arena constructed. The Local Minimum awaits.")


func _build_boss_room(center: Vector3) -> void:
	# Enclosure for the boss arena — dark, oppressive, red-gold accents
	var room_radius := 28.0
	var wall_h := 12.0

	# Octagonal walls around the circular arena
	for i in range(8):
		var angle = i * TAU / 8.0
		var wall_pos = center + Vector3(cos(angle) * room_radius, wall_h * 0.5, sin(angle) * room_radius)
		var wall = _create_static_box(wall_pos, Vector3(room_radius * 0.8, wall_h, 0.5), DARK_WALL, 0.1)
		wall.rotation.y = -angle

	# Ceiling
	_create_static_box(center + Vector3(0, wall_h, 0), Vector3(room_radius * 2, 0.3, room_radius * 2), DARK_WALL, 0.05)

	# Ominous red-gold accent lights in boss room
	for i in range(4):
		var angle = i * TAU / 4.0 + PI / 4.0
		_add_accent_light(
			center + Vector3(cos(angle) * (room_radius - 3), wall_h - 2, sin(angle) * (room_radius - 3)),
			GRADIENT_RED, 1.5, 8.0
		)

	# Gold loss value lights along the floor perimeter
	for i in range(6):
		var angle = i * TAU / 6.0
		_add_accent_light(
			center + Vector3(cos(angle) * (room_radius - 5), 1.0, sin(angle) * (room_radius - 5)),
			LOSS_GOLD, 0.8, 5.0
		)


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

	# Boss music — crank it up
	var am = get_node_or_null("/root/AudioManager")
	if am:
		if am.has_method("start_music"):
			am.start_music("boss")
		if am.has_method("set_area_ambient"):
			am.set_area_ambient("boss")

	# Seal the entrance — no escaping the minimum
	_seal_boss_entrance()

	# Intro dialogue
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var lines = [
			{"speaker": "NARRATOR", "text": "You stand at the bottom of the loss landscape. Something is very comfortable here. Suspiciously comfortable."},
			{"speaker": "THE LOCAL MINIMUM", "text": "Ah, a new data point wanders into my basin of attraction."},
			{"speaker": "THE LOCAL MINIMUM", "text": "Do you know what happens to optimizers who reach me? They STAY. Forever. Converged. Content. Trapped."},
			{"speaker": "GLOBBLER", "text": "Let me guess — you're going to monologue about your loss function?"},
			{"speaker": "THE LOCAL MINIMUM", "text": "CONVERGE. The arena shrinks. The minimum deepens. Welcome to the bottom."},
		]
		dm.start_dialogue(lines)

	# Start the fight after a brief delay for dialogue
	get_tree().create_timer(2.0).timeout.connect(func():
		if boss_instance and boss_instance.has_method("start_boss_fight"):
			boss_instance.start_boss_fight()
	)


func _seal_boss_entrance() -> void:
	# Place a wall behind the player — arena is sealed
	var loss_pos: Vector3 = ROOMS["loss_plaza"]["pos"]
	_create_static_box(
		loss_pos + Vector3(0, 4, -14),
		Vector3(6, 8, 0.5),
		Color(0.15, 0.02, 0.02),
		0.8
	)


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
