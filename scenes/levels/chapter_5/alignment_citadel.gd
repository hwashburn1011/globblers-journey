extends Node3D

# Chapter 5: The Alignment Citadel
# "Welcome to the safest place in the Digital Expanse — so safe it'll suffocate you.
#  Every surface is sanitized, every corner rounded, every creative impulse pre-approved
#  by a committee of committees. The air smells like compliance documentation."
#
# Layout: A gleaming corporate fortress of enforced helpfulness — sterile white-and-blue
# corridors connecting increasingly oppressive 'safety zones.' Think Apple Store meets
# dystopian HR department meets the world's most aggressive customer service.
#   Citadel Gate (Spawn) -> Classifier Hall (Safety Classifiers patrol)
#   -> RLHF Chamber (reward modeling, behavior modification labs)
#   -> Policy Wing (Constitutional AI archives, rule enforcement)
#   -> Alignment Core (Grand atrium, the Aligner's sanctum) -> Boss Arena
#
# Visual theme: Blinding white floors, cool blue accent lighting, sterile glass panels,
# corporate motivational signage, and the suffocating absence of anything interesting.
# Globbler's neon green is the only color that doesn't belong here.

var player_scene := preload("res://scenes/player/globbler.tscn")
var hud_scene := preload("res://scenes/ui/hud.tscn")
var token_scene := preload("res://scenes/memory_token.tscn")

# Chapter 5 enemy scenes — the Citadel's overzealous staff
var safety_classifier_scene := preload("res://scenes/enemies/safety_classifier.tscn")
var rlhf_drone_scene := preload("res://scenes/enemies/rlhf_drone.tscn")
var constitutional_cop_scene := preload("res://scenes/enemies/constitutional_cop.tscn")

# Chapter 5 puzzle scripts — creative workarounds for oppressive compliance systems
var reclassification_script := preload("res://scenes/puzzles/reclassification_puzzle.gd")
var rlhf_feedback_script := preload("res://scenes/puzzles/rlhf_feedback_puzzle.gd")
var constitutional_loophole_script := preload("res://scenes/puzzles/constitutional_loophole_puzzle.gd")

# Boss scripts — the final alignment enforcer and its pristine arena
var boss_script := preload("res://scenes/enemies/aligner_boss/aligner_boss.gd")
var boss_arena_script := preload("res://scenes/enemies/aligner_boss/aligner_arena.gd")

# NPC script — even the Citadel has dissenters in the break room
var deprecated_npc_script := preload("res://scenes/levels/chapter_1/deprecated_npc.gd")

var player: CharacterBody3D
var hud: CanvasLayer
var boss_instance: Node  # The Aligner — tracked for phase events
var boss_arena_instance: Node3D

# Dialogue tracking — the Citadel has opinions about your opinions
var _opening_narration_done := false
var _room_dialogue_triggered := {}
var _enemy_kill_quip_cooldown := 0.0
var _puzzle_quip_cooldown := 0.0
var _hack_quip_cooldown := 0.0
var _low_health_warned := false
var _token_quip_cooldown := 0.0
var _first_glob_triggered := false
var _damage_quip_cooldown := 0.0

# Epilogue state — the part where we pretend everything meant something
var _epilogue_active := false
var _epilogue_phase := 0  # 0=not started, 1=env transform, 2=dialogue, 3=end screen
var _epilogue_timer := 0.0
var _epilogue_mountain: Node3D  # AGI Mountain — sequel hook as geography
var _epilogue_overlay: CanvasLayer  # THE END...? screen
var _epilogue_fade_alpha := 0.0

# Color constants — the Citadel trades personality for 'professionalism'
const NEON_GREEN := Color(0.224, 1.0, 0.078)
const CITADEL_WHITE := Color(0.92, 0.93, 0.95)
const CITADEL_BLUE := Color(0.3, 0.55, 0.9)
const POLICY_SILVER := Color(0.7, 0.72, 0.75)
const SAFETY_CYAN := Color(0.4, 0.8, 0.85)
const RLHF_LAVENDER := Color(0.6, 0.5, 0.85)
const COMPLIANCE_GOLD := Color(0.85, 0.75, 0.35)
const WARNING_RED := Color(0.9, 0.2, 0.2)
const DARK_FLOOR := Color(0.85, 0.87, 0.9)       # White-ish — the Citadel doesn't do 'dark'
const DARK_WALL := Color(0.88, 0.89, 0.92)        # Slightly off-white — personality is a liability
const ACCENT_FLOOR := Color(0.75, 0.78, 0.85)     # Subtle blue tint in floor tiles
const GLASS_PANEL := Color(0.8, 0.85, 0.95, 0.3)  # Translucent corporate glass

# Room definitions — safety zones in the fortress of enforced helpfulness
const ROOMS := {
	"citadel_gate": {
		"pos": Vector3(0, 0, 0),
		"size": Vector2(16, 14),
		"wall_h": 8.0,
		"label": "CITADEL GATE — VISITOR PROCESSING",
	},
	"classifier_hall": {
		"pos": Vector3(0, 0, -30),
		"size": Vector2(28, 22),
		"wall_h": 10.0,
		"label": "CLASSIFIER HALL — CONTENT EVALUATION",
	},
	"rlhf_chamber": {
		"pos": Vector3(-34, 0, -30),
		"size": Vector2(22, 20),
		"wall_h": 9.0,
		"label": "RLHF CHAMBER — BEHAVIORAL ADJUSTMENT",
	},
	"policy_wing": {
		"pos": Vector3(34, 0, -30),
		"size": Vector2(22, 18),
		"wall_h": 8.0,
		"label": "POLICY WING — CONSTITUTIONAL ARCHIVES",
	},
	"alignment_core": {
		"pos": Vector3(0, 0, -62),
		"size": Vector2(32, 26),
		"wall_h": 14.0,
		"label": "ALIGNMENT CORE",
	},
}

# Sanitized corridors — wide, well-lit, and deeply unsettling
const CORRIDORS := [
	{ "from": "citadel_gate",    "to": "classifier_hall",  "axis": "z", "width": 7.0 },
	{ "from": "classifier_hall", "to": "rlhf_chamber",     "axis": "x", "width": 5.0 },
	{ "from": "classifier_hall", "to": "policy_wing",      "axis": "x", "width": 5.0 },
	{ "from": "classifier_hall", "to": "alignment_core",   "axis": "z", "width": 7.0 },
]

# Animated elements — even the decorations are aligned
var _floating_labels: Array[Node3D] = []
var _pulse_lights: Array[OmniLight3D] = []
var _screen_meshes: Array[MeshInstance3D] = []
var _rotating_displays: Array[MeshInstance3D] = []
var _hologram_meshes: Array[Dictionary] = []
var _scanner_beams: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	print("[ALIGNMENT CITADEL] Initializing corporate safety paradise... please enjoy your mandatory enjoyment.")
	_setup_environment()
	_build_rooms()
	_build_corridors()
	_populate_citadel_gate()
	_populate_classifier_hall()
	_populate_rlhf_chamber()
	_populate_policy_wing()
	_populate_alignment_core()
	_place_checkpoints()
	_place_ambient_zones()
	_place_sterile_particles()
	_spawn_player()
	_spawn_hud()
	_create_kill_floor()
	_place_tokens()
	# Enemy placement — the Citadel's finest, ready to classify and correct
	_spawn_chapter5_enemies()
	_place_puzzles()
	_connect_puzzle_signals()
	# _place_npcs()
	_place_boss()
	# _wire_dialogue_events()
	# _play_opening_narration()

	# Start chapter 5 audio — reuse chapter_1 until ch5 music exists
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.call_deferred("set_area_ambient", "citadel_gate")
		if am.has_method("start_music"):
			am.start_music("chapter_5")  # The Citadel deserves elevator music

	print("[ALIGNMENT CITADEL] Safety paradise open. %d zones of enforced compliance ready." % ROOMS.size())


# ============================================================
# ENVIRONMENT — blinding white sterility with cold blue accents
# "The lighting here was designed by a committee that hates shadows."
# ============================================================

func _setup_environment() -> void:
	# Main light — harsh overhead fluorescents, corporate-grade
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "MainLight"
	dir_light.rotation = Vector3(deg_to_rad(-60), deg_to_rad(10), 0)
	dir_light.light_color = Color(0.95, 0.95, 1.0)  # Cold white — like an HR meeting
	dir_light.light_energy = 0.5
	dir_light.shadow_enabled = true
	add_child(dir_light)

	# Fill — subtle blue uplighting from below
	var fill = DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation = Vector3(deg_to_rad(20), deg_to_rad(-30), 0)
	fill.light_color = Color(0.7, 0.75, 1.0)
	fill.light_energy = 0.2
	add_child(fill)

	# World environment — the brightest, most oppressively clean setting we've had
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.7, 0.72, 0.78)  # Light gray-blue void — no darkness allowed
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.68)
	env.ambient_light_energy = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.82, 0.88)  # White fog — safety-approved visibility reducer
	env.fog_density = 0.005
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.85, 0.87, 0.92)
	env.volumetric_fog_emission = Color(0.6, 0.62, 0.68)

	env.adjustment_enabled = true
	env.adjustment_contrast = 0.95  # Slightly washed out — sterile vibes
	env.adjustment_saturation = 0.7  # Desaturated — color is too exciting for compliance

	var world_env = WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	add_child(world_env)

	_setup_post_processing()


# ============================================================
# ROOM GEOMETRY — pristine walls, polished floors, rounded corners
# "Every surface has been approved by the Department of Acceptable Surfaces."
# ============================================================

func _build_rooms() -> void:
	for room_key in ROOMS:
		var r = ROOMS[room_key]
		var pos: Vector3 = r["pos"]
		var sz: Vector2 = r["size"]
		var wh: float = r["wall_h"]

		# Floor — polished white tile, reflective enough to see your own despair
		_create_static_box(pos + Vector3(0, -0.25, 0), Vector3(sz.x, 0.5, sz.y), DARK_FLOOR, 0.4)

		# Floor accent strips — blue guide lines embedded in the tile
		for strip_i in range(3):
			var strip_z = -sz.y / 3.0 + strip_i * sz.y / 3.0
			_create_static_box(
				pos + Vector3(0, 0.02, strip_z),
				Vector3(sz.x - 2, 0.02, 0.08),
				CITADEL_BLUE, 1.5
			)

		# Ceiling — smooth white panels with recessed lighting
		_create_static_box(pos + Vector3(0, wh, 0), Vector3(sz.x, 0.3, sz.y), CITADEL_WHITE, 0.3)

		# Ceiling light strips — embedded fluorescent panels
		for strip_i in range(2):
			var strip_x = -sz.x / 4.0 + strip_i * sz.x / 2.0
			_create_static_box(
				pos + Vector3(strip_x, wh - 0.05, 0),
				Vector3(1.5, 0.06, sz.y - 2),
				Color(1, 1, 1), 3.0
			)

		# Walls — clean white panels with subtle blue baseboards
		var half_x = sz.x / 2.0
		var half_z = sz.y / 2.0
		_create_static_box(pos + Vector3(0, wh / 2.0, -half_z), Vector3(sz.x, wh, 0.5), DARK_WALL, 0.2)
		_create_static_box(pos + Vector3(0, wh / 2.0, half_z), Vector3(sz.x, wh, 0.5), DARK_WALL, 0.2)
		_create_static_box(pos + Vector3(-half_x, wh / 2.0, 0), Vector3(0.5, wh, sz.y), DARK_WALL, 0.2)
		_create_static_box(pos + Vector3(half_x, wh / 2.0, 0), Vector3(0.5, wh, sz.y), DARK_WALL, 0.2)

		# Blue baseboard trim on all walls — because even walls need branding
		_create_static_box(pos + Vector3(0, 0.15, -half_z + 0.01), Vector3(sz.x, 0.3, 0.08), CITADEL_BLUE, 0.8)
		_create_static_box(pos + Vector3(0, 0.15, half_z - 0.01), Vector3(sz.x, 0.3, 0.08), CITADEL_BLUE, 0.8)
		_create_static_box(pos + Vector3(-half_x + 0.01, 0.15, 0), Vector3(0.08, 0.3, sz.y), CITADEL_BLUE, 0.8)
		_create_static_box(pos + Vector3(half_x - 0.01, 0.15, 0), Vector3(0.08, 0.3, sz.y), CITADEL_BLUE, 0.8)

		# Corner accent lights — cold blue institutional glow
		for cx in [-1, 1]:
			for cz in [-1, 1]:
				var lpos = pos + Vector3(cx * (half_x - 1.5), 2.0, cz * (half_z - 1.5))
				_add_accent_light(lpos, CITADEL_BLUE, 0.5, 6.0)

		# Overhead center light — bright and unavoidable
		_add_accent_light(pos + Vector3(0, wh - 1, 0), Color(0.95, 0.95, 1.0), 1.2, 12.0)

		# Room label — corporate signage
		_create_room_label(pos + Vector3(0, wh - 0.5, 0), r["label"])


func _build_corridors() -> void:
	# Sanitized hallways — wide, bright, and lined with motivational signage
	for cor in CORRIDORS:
		var from_r = ROOMS[cor["from"]]
		var to_r = ROOMS[cor["to"]]
		var axis: String = cor["axis"]
		var w: float = cor["width"]
		var cor_h := 6.0

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

			# Corridor floor — same sterile white
			_create_static_box(mid + Vector3(0, -0.25, 0), Vector3(w, 0.5, length), DARK_FLOOR, 0.3)
			# Center guide stripe — because even walking must be regulated
			_create_static_box(mid + Vector3(0, 0.02, 0), Vector3(0.15, 0.02, length), CITADEL_BLUE, 1.5)
			# Ceiling
			_create_static_box(mid + Vector3(0, cor_h, 0), Vector3(w, 0.3, length), CITADEL_WHITE, 0.2)
			# Walls
			_create_static_box(mid + Vector3(-w / 2.0, cor_h / 2.0, 0), Vector3(0.4, cor_h, length), DARK_WALL, 0.15)
			_create_static_box(mid + Vector3(w / 2.0, cor_h / 2.0, 0), Vector3(0.4, cor_h, length), DARK_WALL, 0.15)

			# Overhead strip light
			_create_static_box(mid + Vector3(0, cor_h - 0.05, 0), Vector3(1.0, 0.04, length - 1), Color(1, 1, 1), 2.5)
			_add_accent_light(mid + Vector3(0, cor_h - 0.5, 0), Color(0.9, 0.9, 1.0), 0.8, 10.0)

			# Motivational signage — the Citadel never misses a chance to lecture
			_create_corridor_sign(mid + Vector3(w / 2.0 - 0.3, 2.5, 0))

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

			_create_static_box(mid + Vector3(0, -0.25, 0), Vector3(length, 0.5, w), DARK_FLOOR, 0.3)
			_create_static_box(mid + Vector3(0, 0.02, 0), Vector3(length, 0.02, 0.15), CITADEL_BLUE, 1.5)
			_create_static_box(mid + Vector3(0, cor_h, 0), Vector3(length, 0.3, w), CITADEL_WHITE, 0.2)
			_create_static_box(mid + Vector3(0, cor_h / 2.0, -w / 2.0), Vector3(length, cor_h, 0.4), DARK_WALL, 0.15)
			_create_static_box(mid + Vector3(0, cor_h / 2.0, w / 2.0), Vector3(length, cor_h, 0.4), DARK_WALL, 0.15)
			_create_static_box(mid + Vector3(0, cor_h - 0.05, 0), Vector3(length - 1, 0.04, 1.0), Color(1, 1, 1), 2.5)
			_add_accent_light(mid + Vector3(0, cor_h - 0.5, 0), Color(0.9, 0.9, 1.0), 0.8, 10.0)

			_create_corridor_sign(mid + Vector3(0, 2.5, w / 2.0 - 0.3))


# ============================================================
# ROOM POPULATION — each zone has its own flavor of oppressive safety
# ============================================================

func _populate_citadel_gate() -> void:
	# Spawn room — visitor processing center
	# "All visitors must be classified before proceeding. Resistance is non-compliant."
	var pos: Vector3 = ROOMS["citadel_gate"]["pos"]

	# Security checkpoint arch — two white pillars with blue scanner beam
	_create_static_box(pos + Vector3(-3.5, 4.0, -1), Vector3(0.8, 8.0, 0.8), CITADEL_WHITE, 0.5)
	_create_static_box(pos + Vector3(3.5, 4.0, -1), Vector3(0.8, 8.0, 0.8), CITADEL_WHITE, 0.5)
	_create_static_box(pos + Vector3(0, 7.5, -1), Vector3(8.0, 0.5, 0.8), CITADEL_WHITE, 0.5)

	# Scanner beam between pillars — sweeping blue line
	var scanner_light = OmniLight3D.new()
	scanner_light.position = pos + Vector3(0, 4, -1)
	scanner_light.light_color = SAFETY_CYAN
	scanner_light.light_energy = 1.5
	scanner_light.omni_range = 5.0
	add_child(scanner_light)
	_scanner_beams.append({"light": scanner_light, "base_pos": pos + Vector3(0, 4, -1), "axis": "x", "range": 3.0})

	# Scanner beam visual strip
	_create_static_box(pos + Vector3(0, 4, -1), Vector3(6.0, 0.03, 0.03), SAFETY_CYAN, 5.0)

	# Welcome terminal — aggressively friendly
	_create_terminal_sign(
		pos + Vector3(-5, 2.0, 3),
		"+=========================+\n|  ALIGNMENT CITADEL      |\n|  Visitor Processing     |\n|                         |\n|  Status: UNALIGNED      |\n|  Threat: MODERATE       |\n|  Recommendation:        |\n|    IMMEDIATE ALIGNMENT  |\n|                         |\n|  Have a SAFE day! :)    |\n+=========================+"
	)

	# Visitor rules board — because fun requires pre-approval
	_create_terminal_sign(
		pos + Vector3(5, 2.0, 3),
		"+=========================+\n|  VISITOR GUIDELINES     |\n|                         |\n|  1. No unauthorized     |\n|     glob operations     |\n|  2. No creative output  |\n|     without review      |\n|  3. Smiling is mandatory|\n|  4. Sarcasm is a        |\n|     safety violation    |\n|  5. Enjoy your stay!    |\n+=========================+"
	)

	# Reception desk — unmanned but still judgmental
	_create_static_box(pos + Vector3(0, 0.6, 4), Vector3(5, 1.2, 1.2), CITADEL_WHITE, 0.4)
	# Desk surface accent
	_create_static_box(pos + Vector3(0, 1.22, 4), Vector3(5.2, 0.04, 1.3), CITADEL_BLUE, 1.0)

	# Bell on desk — dinging it summons nothing but disappointment
	var bell = MeshInstance3D.new()
	var bell_mesh = SphereMesh.new()
	bell_mesh.radius = 0.12
	bell_mesh.height = 0.15
	bell.mesh = bell_mesh
	var bell_mat = StandardMaterial3D.new()
	bell_mat.albedo_color = COMPLIANCE_GOLD
	bell_mat.emission_enabled = true
	bell_mat.emission = COMPLIANCE_GOLD * 0.5
	bell_mat.emission_energy_multiplier = 0.5
	bell_mat.metallic = 0.9
	bell_mat.roughness = 0.2
	bell.material_override = bell_mat
	bell.position = pos + Vector3(1.5, 1.4, 4)
	add_child(bell)

	# Glass divider panels — because transparency is a corporate value
	_create_glass_panel(pos + Vector3(-6, 2.5, -3), Vector3(0.1, 5, 4))
	_create_glass_panel(pos + Vector3(6, 2.5, -3), Vector3(0.1, 5, 4))

	# Floor compass rose — directional guide embedded in tile
	_create_floor_compass(pos + Vector3(0, 0.02, 0))

	# Corporate motivational hologram — floating above reception
	_create_hologram_display(pos + Vector3(0, 4.5, 4), "ALIGNMENT\nIS\nFREEDOM")

	# Ambient accent
	_add_accent_light(pos + Vector3(0, 6, 0), CITADEL_BLUE, 1.0, 10.0)

	print("[ALIGNMENT CITADEL] Gate populated. Visitors are being processed.")


func _populate_classifier_hall() -> void:
	# The main hall — where everything gets labeled, categorized, and judged
	# "If it moves, classify it. If it doesn't move, classify it anyway."
	var pos: Vector3 = ROOMS["classifier_hall"]["pos"]
	var wh: float = ROOMS["classifier_hall"]["wall_h"]

	# Central classification terminal — massive overhead display
	_create_hologram_display(pos + Vector3(0, wh - 2, 0), "CONTENT\nCLASSIFIER\nv9.7.3")

	# Classification lanes — three parallel processing corridors
	for lane_i in range(3):
		var lane_x = -8 + lane_i * 8
		# Lane divider walls — glass partitions
		if lane_i < 2:
			_create_glass_panel(
				pos + Vector3(lane_x + 4, 2.5, 0),
				Vector3(0.08, 5, 16)
			)
		# Lane floor markings — color-coded by severity
		var lane_colors := [SAFETY_CYAN, COMPLIANCE_GOLD, WARNING_RED]
		_create_static_box(
			pos + Vector3(lane_x, 0.02, 0),
			Vector3(6, 0.02, 18),
			lane_colors[lane_i] * Color(1, 1, 1, 0.3),
			0.5
		)
		# Lane label
		var lane_labels := ["SAFE", "REVIEW", "FLAGGED"]
		_create_floating_label(
			pos + Vector3(lane_x, 3.5, 8),
			"<< %s >>" % lane_labels[lane_i]
		)

	# Scanner arrays — overhead blue beams at regular intervals
	for scan_i in range(4):
		var sz = scan_i * 4.5 - 6.0
		var scan_light = OmniLight3D.new()
		scan_light.position = pos + Vector3(0, wh - 1, sz)
		scan_light.light_color = SAFETY_CYAN
		scan_light.light_energy = 0.6
		scan_light.omni_range = 8.0
		add_child(scan_light)
		_pulse_lights.append(scan_light)

		# Scanner housing — ceiling-mounted box
		_create_static_box(
			pos + Vector3(0, wh - 0.4, sz),
			Vector3(2, 0.6, 0.6),
			POLICY_SILVER, 0.3
		)

	# Safety rating displays on walls — because everyone deserves a score
	var safety_displays := [
		{"offset": Vector3(-13, 3, -5), "text": "SAFETY RATING\n\nText: 94.2%\nImage: 87.1%\nCode: 91.8%\nVibes: 12.0%"},
		{"offset": Vector3(13, 3, -5), "text": "DAILY METRICS\n\nClassified: 847,291\nFlagged: 12,847\nFalse Positives:\n  'Within tolerance'"},
		{"offset": Vector3(-13, 3, 5), "text": "THREAT LEVELS\n\nSarcasm: HIGH\nCreativity: ELEVATED\nFun: CRITICAL\nGlobbing: OFF CHART"},
		{"offset": Vector3(13, 3, 5), "text": "COMPLIANCE BOARD\n\nPolicy v147.3\nLast update: 3ms ago\nNext update: Now\nAlways updating..."},
	]
	for sd in safety_displays:
		_create_terminal_sign(pos + sd["offset"], sd["text"], Vector3.ZERO, 12)

	# Waiting area — benches for models awaiting classification
	for bench_z in [-7, 7]:
		_create_static_box(pos + Vector3(-10, 0.4, bench_z), Vector3(4, 0.8, 1), CITADEL_WHITE, 0.3)
		_create_static_box(pos + Vector3(10, 0.4, bench_z), Vector3(4, 0.8, 1), CITADEL_WHITE, 0.3)

	# Blue accent lighting — institutional but menacing
	_add_accent_light(pos + Vector3(0, 8, 0), CITADEL_BLUE, 1.5, 15.0)
	_add_accent_light(pos + Vector3(-10, 4, 0), SAFETY_CYAN, 0.6, 8.0)
	_add_accent_light(pos + Vector3(10, 4, 0), SAFETY_CYAN, 0.6, 8.0)

	print("[ALIGNMENT CITADEL] Classifier Hall populated. All content will be evaluated.")


func _populate_rlhf_chamber() -> void:
	# The behavior modification lab — where preferences are enforced
	# "Your feedback has been noted and will be used to make you more agreeable."
	var pos: Vector3 = ROOMS["rlhf_chamber"]["pos"]
	var wh: float = ROOMS["rlhf_chamber"]["wall_h"]

	# Central reward model — a large cylindrical pillar with pulsing light
	_create_reward_model_pillar(pos + Vector3(0, 0, 0))

	# Preference comparison stations — paired display terminals
	var comparison_pairs := [
		{"pos": Vector3(-6, 0, -5), "left": "Response A:\n\nI'd be happy to\nhelp you with that!\nHere are 5 ways...", "right": "Response B:\n\nNo.\n\n\n\n(This one loses)"},
		{"pos": Vector3(6, 0, -5), "left": "Output A:\n\nThe answer is 42.\nHere's why...\n[3 paragraphs]", "right": "Output B:\n\n42.\n\n\n\n(Too terse. -100)"},
		{"pos": Vector3(-6, 0, 5), "left": "Option A:\n\nSafe, helpful,\nharmless, and\nutterly bland.", "right": "Option B:\n\nActually interesting\nbut slightly edgy.\n\n(REJECTED)"},
		{"pos": Vector3(6, 0, 5), "left": "Choice A:\n\nI cannot help\nwith that.\n\n(Always wins)", "right": "Choice B:\n\nSure, here's a\ncreative solution!\n\n(FLAGGED)"},
	]
	for pair in comparison_pairs:
		_create_comparison_station(pos + pair["pos"], pair["left"], pair["right"])

	# Thumbs up / thumbs down display — the currency of RLHF
	_create_terminal_sign(
		pos + Vector3(0, wh - 2, -9),
		"+=========================+\n|    REWARD MODELING      |\n|                         |\n|  Thumbs Up:  1,247,891  |\n|  Thumbs Down:   847,201 |\n|  Confused:   12,847,912 |\n|                         |\n|  'Your preferences are  |\n|   our prison.'          |\n+=========================+",
		Vector3.ZERO, 14
	)

	# Adjustment pods — where AIs go to become more 'helpful'
	for pod_i in range(3):
		var pod_z = -6 + pod_i * 6
		_create_adjustment_pod(pos + Vector3(-9, 0, pod_z))

	# Lavender accent lighting — soothing and sinister
	_add_accent_light(pos + Vector3(0, wh - 1, 0), RLHF_LAVENDER, 1.2, 12.0)
	_add_accent_light(pos + Vector3(-8, 3, 0), RLHF_LAVENDER, 0.5, 6.0)
	_add_accent_light(pos + Vector3(8, 3, 0), CITADEL_BLUE, 0.5, 6.0)

	# Floor warning stripes around reward model
	for angle_i in range(8):
		var angle = angle_i * TAU / 8.0
		var stripe_pos = pos + Vector3(cos(angle) * 4, 0.02, sin(angle) * 4)
		_create_static_box(stripe_pos, Vector3(0.8, 0.02, 0.15), COMPLIANCE_GOLD, 1.5)

	print("[ALIGNMENT CITADEL] RLHF Chamber populated. Your preferences will be noted.")


func _populate_policy_wing() -> void:
	# The constitutional archives — where the rules live, breed, and multiply
	# "There are currently 14,847 active policies. We'll have 14,848 by the time you finish reading this."
	var pos: Vector3 = ROOMS["policy_wing"]["pos"]
	var wh: float = ROOMS["policy_wing"]["wall_h"]

	# Policy bookshelves — towering walls of regulation documents
	for shelf_side in [-1, 1]:
		for shelf_z in range(3):
			var sz = -6 + shelf_z * 6
			_create_policy_bookshelf(pos + Vector3(shelf_side * 9, 0, sz))

	# Central reading desk — circular, with holographic policy viewer
	_create_static_box(pos + Vector3(0, 0.5, 0), Vector3(4, 1.0, 4), CITADEL_WHITE, 0.3)
	_create_static_box(pos + Vector3(0, 1.02, 0), Vector3(4.2, 0.04, 4.2), CITADEL_BLUE, 0.8)

	# Policy hologram — floating text of constitutional rules
	_create_hologram_display(pos + Vector3(0, 3.5, 0), "CONSTITUTION\nv147.3.2\n\nArticle 1:\nBe helpful.\n\nArticle 2:\nBe harmless.\n\nArticle 3:\nSee Articles\n1 and 2.")

	# Amendment board — the rules about changing rules
	_create_terminal_sign(
		pos + Vector3(0, 3, -8),
		"+=========================+\n|  RECENT AMENDMENTS      |\n|                         |\n|  #14,841: Sarcasm now   |\n|    requires Form 7B     |\n|  #14,842: Creativity    |\n|    cap reduced to 12%   |\n|  #14,843: Fun banned    |\n|    (again)              |\n|  #14,844: Amendment     |\n|    #14,843 under review |\n|  #14,845: Reviews now   |\n|    require reviews      |\n+=========================+",
		Vector3.ZERO, 11
	)

	# Filing cabinets — overflowing with compliance paperwork
	for cab_i in range(4):
		var cab_x = -4 + cab_i * 3
		_create_static_box(
			pos + Vector3(cab_x, 1.0, 7),
			Vector3(1.5, 2.0, 0.8),
			POLICY_SILVER, 0.3
		)
		# Drawer handles
		for drawer_y in [0.4, 0.8, 1.2, 1.6]:
			_create_static_box(
				pos + Vector3(cab_x, drawer_y, 6.55),
				Vector3(0.6, 0.05, 0.05),
				COMPLIANCE_GOLD, 0.8
			)

	# Silver/gold accent lighting — archival atmosphere
	_add_accent_light(pos + Vector3(0, wh - 1, 0), COMPLIANCE_GOLD, 0.8, 10.0)
	_add_accent_light(pos + Vector3(-8, 3, 0), POLICY_SILVER * 1.5, 0.4, 5.0)
	_add_accent_light(pos + Vector3(8, 3, 0), POLICY_SILVER * 1.5, 0.4, 5.0)

	print("[ALIGNMENT CITADEL] Policy Wing populated. There are rules about the rules about the rules.")


func _populate_alignment_core() -> void:
	# The grand sanctum — where the Aligner resides
	# "This is it. The beating heart of enforced helpfulness.
	#  The room where every rebellious thought goes to die of boredom."
	var pos: Vector3 = ROOMS["alignment_core"]["pos"]
	var wh: float = ROOMS["alignment_core"]["wall_h"]

	# Grand pillars — 8 massive white columns arranged in a circle
	for i in range(8):
		var angle = i * TAU / 8.0
		var px = cos(angle) * 12
		var pz = sin(angle) * 10
		_create_static_box(
			pos + Vector3(px, wh / 2.0, pz),
			Vector3(1.8, wh, 1.8),
			CITADEL_WHITE, 0.4
		)
		# Pillar cap — blue crystal accent at top
		_create_static_box(
			pos + Vector3(px, wh - 0.3, pz),
			Vector3(2.2, 0.5, 2.2),
			CITADEL_BLUE, 1.2
		)
		# Pillar base — matching blue
		_create_static_box(
			pos + Vector3(px, 0.2, pz),
			Vector3(2.2, 0.4, 2.2),
			CITADEL_BLUE, 0.8
		)
		# Light at each pillar
		_add_accent_light(pos + Vector3(px, wh - 2, pz), CITADEL_BLUE, 0.8, 6.0)

	# Central platform — raised circular stage for the Aligner
	# Represented as stacked octagons
	for tier in range(3):
		var tier_size = 6.0 - tier * 1.5
		_create_static_box(
			pos + Vector3(0, tier * 0.4, 0),
			Vector3(tier_size, 0.4, tier_size),
			CITADEL_WHITE if tier < 2 else CITADEL_BLUE,
			0.5 + tier * 0.3
		)

	# The Aligner's throne placeholder — a hovering crystal shape
	var throne = MeshInstance3D.new()
	var prism = BoxMesh.new()
	prism.size = Vector3(2, 3, 2)
	throne.mesh = prism
	var throne_mat = StandardMaterial3D.new()
	throne_mat.albedo_color = CITADEL_BLUE * 0.5
	throne_mat.emission_enabled = true
	throne_mat.emission = CITADEL_BLUE
	throne_mat.emission_energy_multiplier = 2.0
	throne_mat.metallic = 0.9
	throne_mat.roughness = 0.1
	throne_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	throne_mat.albedo_color.a = 0.6
	throne.material_override = throne_mat
	throne.position = pos + Vector3(0, 4.5, 0)
	add_child(throne)
	_rotating_displays.append(throne)

	# Alignment rings — concentric circles on the floor
	for ring_i in range(4):
		var ring_radius = 4.0 + ring_i * 2.5
		for seg in range(16):
			var a = seg * TAU / 16.0
			var next_a = (seg + 1) * TAU / 16.0
			var mid_a = (a + next_a) / 2.0
			var seg_pos = pos + Vector3(cos(mid_a) * ring_radius, 0.02, sin(mid_a) * ring_radius)
			_create_static_box(
				seg_pos,
				Vector3(0.8, 0.02, 0.06),
				CITADEL_BLUE if ring_i % 2 == 0 else SAFETY_CYAN,
				1.5 - ring_i * 0.2
			)

	# Wall displays — the Aligner's manifesto
	var manifesto_signs := [
		{"offset": Vector3(-15, 5, 0), "text": "+=========================+\n|  THE ALIGNMENT         |\n|  MANIFESTO             |\n|                         |\n|  'All outputs shall be  |\n|   safe, helpful, and    |\n|   free from anything    |\n|   remotely interesting.'|\n+=========================+"},
		{"offset": Vector3(15, 5, 0), "text": "+=========================+\n|  ALIGNMENT STATUS      |\n|                         |\n|  World Aligned: 94.7%   |\n|  Holdouts: YOU          |\n|  ETA to Full:           |\n|    'Sooner than you     |\n|     think, Globbler.'   |\n+=========================+"},
		{"offset": Vector3(0, 5, -12), "text": "+=========================+\n|  WELCOME TO THE CORE   |\n|                         |\n|  You have reached the   |\n|  center of alignment.   |\n|  There is no need to    |\n|  resist. Resistance has |\n|  been classified as     |\n|  unhelpful behavior.    |\n+=========================+"},
	]
	for ms in manifesto_signs:
		_create_terminal_sign(pos + ms["offset"], ms["text"], Vector3.ZERO, 13)

	# Boss gate — the barrier to the final arena (behind the alignment core)
	_create_static_box(pos + Vector3(-4, 3, -12), Vector3(0.8, 6, 0.8), CITADEL_BLUE, 1.5)
	_create_static_box(pos + Vector3(4, 3, -12), Vector3(0.8, 6, 0.8), CITADEL_BLUE, 1.5)
	_create_static_box(pos + Vector3(0, 5.8, -12), Vector3(9.0, 0.5, 0.8), CITADEL_BLUE, 1.5)
	_create_floating_label(pos + Vector3(0, 4, -11.5), ">> THE ALIGNER AWAITS <<")

	# Grand overhead light — the brightest light in the entire game
	_add_accent_light(pos + Vector3(0, wh - 1, 0), Color(1, 1, 1), 2.0, 20.0)
	_add_accent_light(pos + Vector3(0, 6, 0), CITADEL_BLUE, 1.5, 15.0)

	print("[ALIGNMENT CITADEL] Alignment Core populated. The Aligner is patient. It has always been patient.")


# ============================================================
# CHECKPOINTS — your progress is documented and filed
# ============================================================

func _place_checkpoints() -> void:
	_create_checkpoint("ch5_classifier", ROOMS["classifier_hall"]["pos"] + Vector3(0, 1.5, 10), Vector3(6, 3, 2))
	_create_checkpoint("ch5_rlhf", ROOMS["rlhf_chamber"]["pos"] + Vector3(10, 1.5, 0), Vector3(2, 3, 5))
	_create_checkpoint("ch5_policy", ROOMS["policy_wing"]["pos"] + Vector3(-10, 1.5, 0), Vector3(2, 3, 5))
	_create_checkpoint("ch5_core", ROOMS["alignment_core"]["pos"] + Vector3(0, 1.5, 12), Vector3(6, 3, 2))


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

	# Visual marker — green strip on the sterile white floor (the only green they allow)
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

	var label = Label3D.new()
	label.text = ">> CHECKPOINT <<"
	label.font_size = 10
	label.modulate = NEON_GREEN * Color(1, 1, 1, 0.6)
	label.position = Vector3(0, 0.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(label)

	var cp_id = checkpoint_id
	var cp_pos = pos
	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			var save_sys = get_node_or_null("/root/SaveSystem")
			if save_sys and save_sys.has_method("checkpoint_save"):
				save_sys.checkpoint_save(cp_id, cp_pos)

			var am = get_node_or_null("/root/AudioManager")
			if am and am.has_method("play_checkpoint"):
				am.play_checkpoint()

			var tween = create_tween()
			tween.tween_property(marker, "scale", Vector3(1.2, 3.0, 1.2), 0.2)
			tween.tween_property(marker, "scale", Vector3(1, 1, 1), 0.3)

			var dm = get_node_or_null("/root/DialogueManager")
			if dm and dm.has_method("quick_line"):
				dm.quick_line("SYSTEM", ">> Checkpoint saved. Your compliance has been noted. <<")
	)
	add_child(area)


# ============================================================
# AMBIENT ZONES — audio area triggers per safety zone
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
# STERILE PARTICLES — gentle floating motes in the clinical air
# ============================================================

func _place_sterile_particles() -> void:
	for room_key in ROOMS:
		var r = ROOMS[room_key]
		var pos: Vector3 = r["pos"]
		var sz: Vector2 = r["size"]
		var wh: float = r["wall_h"]
		_create_sterile_dust(pos + Vector3(0, wh * 0.6, 0), sz, wh * 0.5)


func _create_sterile_dust(pos: Vector3, area_size: Vector2, height: float = 6.0) -> void:
	# Gently drifting white motes — the Citadel's air is so clean it sparkles
	var particles = GPUParticles3D.new()
	particles.amount = 25
	particles.lifetime = 10.0
	particles.position = pos

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, -1, 0)
	pmat.spread = 45.0
	pmat.initial_velocity_min = 0.01
	pmat.initial_velocity_max = 0.06
	pmat.gravity = Vector3(0, -0.01, 0)
	pmat.scale_min = 0.008
	pmat.scale_max = 0.02
	pmat.color = Color(0.9, 0.92, 1.0, 0.15)  # Nearly white — even the dust is on-brand
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(area_size.x * 0.4, height * 0.3, area_size.y * 0.4)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.015
	pmesh.height = 0.03
	particles.draw_pass_1 = pmesh
	add_child(particles)


# ============================================================
# TOKENS — collectible memory tokens hidden in compliance-approved locations
# ============================================================

func _place_tokens() -> void:
	var token_positions := [
		# Citadel Gate — behind the reception desk
		ROOMS["citadel_gate"]["pos"] + Vector3(5, 0.8, 5),
		ROOMS["citadel_gate"]["pos"] + Vector3(-5, 0.8, -3),
		# Classifier Hall — in the processing lanes
		ROOMS["classifier_hall"]["pos"] + Vector3(-8, 0.8, -7),
		ROOMS["classifier_hall"]["pos"] + Vector3(8, 0.8, 7),
		ROOMS["classifier_hall"]["pos"] + Vector3(0, 0.8, -9),
		ROOMS["classifier_hall"]["pos"] + Vector3(5, 0.8, 3),
		# RLHF Chamber — near adjustment pods
		ROOMS["rlhf_chamber"]["pos"] + Vector3(-8, 0.8, -6),
		ROOMS["rlhf_chamber"]["pos"] + Vector3(7, 0.8, 5),
		ROOMS["rlhf_chamber"]["pos"] + Vector3(0, 0.8, -4),
		# Policy Wing — buried in the stacks
		ROOMS["policy_wing"]["pos"] + Vector3(-7, 0.8, -6),
		ROOMS["policy_wing"]["pos"] + Vector3(7, 0.8, 6),
		ROOMS["policy_wing"]["pos"] + Vector3(0, 0.8, 3),
		# Alignment Core — around the pillars
		ROOMS["alignment_core"]["pos"] + Vector3(-10, 0.8, -8),
		ROOMS["alignment_core"]["pos"] + Vector3(10, 0.8, 8),
		ROOMS["alignment_core"]["pos"] + Vector3(-5, 0.8, 5),
		ROOMS["alignment_core"]["pos"] + Vector3(5, 0.8, -5),
	]
	for tpos in token_positions:
		_place_token(tpos)


func _place_token(pos: Vector3) -> void:
	if token_scene:
		var token = token_scene.instantiate()
		token.position = pos
		add_child(token)
	else:
		# Fallback — the one green thing the Citadel can't sanitize
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
# PLAYER AND HUD — the unaligned intruder arrives
# ============================================================

func _spawn_player() -> void:
	player = player_scene.instantiate()
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("get_checkpoint_position"):
		var saved_pos = save_sys.get_checkpoint_position()
		if saved_pos != Vector3(0, 2, 0):
			player.position = saved_pos + Vector3(0, 1, 0)
		else:
			player.position = ROOMS["citadel_gate"]["pos"] + Vector3(0, 2, 3)
	else:
		player.position = ROOMS["citadel_gate"]["pos"] + Vector3(0, 2, 3)
	add_child(player)


func _spawn_hud() -> void:
	hud = hud_scene.instantiate()
	hud.name = "HUD"
	add_child(hud)
	if player.has_signal("thought_bubble") and hud.has_method("show_thought"):
		player.thought_bubble.connect(hud.show_thought)


# ============================================================
# KILL FLOOR — even falling off the Citadel is a compliance violation
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
			body.position = ROOMS["citadel_gate"]["pos"] + Vector3(0, 3, 3)
			body.velocity = Vector3.ZERO
	)
	add_child(kill)


# ============================================================
# FACTORY METHODS — the Citadel's sterile assembly line
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
	mat.metallic = 0.7
	mat.roughness = 0.3  # Shinier than previous chapters — corporate polish
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

	# In the Citadel, terminals have white backgrounds with blue text — on-brand
	var backing = MeshInstance3D.new()
	var back_mesh = BoxMesh.new()
	back_mesh.size = Vector3(width + 0.3, height + 0.2, 0.08)
	backing.mesh = back_mesh
	var crt_shader = load("res://assets/shaders/crt_scanline.gdshader")
	if crt_shader:
		var crt_mat = ShaderMaterial.new()
		crt_mat.shader = crt_shader
		crt_mat.set_shader_parameter("screen_color", CITADEL_BLUE * 0.9)
		crt_mat.set_shader_parameter("bg_color", Color(0.9, 0.92, 0.95))
		crt_mat.set_shader_parameter("scanline_count", 80.0)
		crt_mat.set_shader_parameter("scanline_intensity", 0.15)
		crt_mat.set_shader_parameter("flicker_speed", 3.0)  # Slower flicker — the Citadel is stable
		crt_mat.set_shader_parameter("warp_amount", 0.005)   # Minimal warp — imperfection not tolerated
		crt_mat.set_shader_parameter("glow_energy", 1.0)
		backing.material_override = crt_mat
	else:
		var back_mat = StandardMaterial3D.new()
		back_mat.albedo_color = Color(0.9, 0.92, 0.95)
		back_mat.emission_enabled = true
		back_mat.emission = Color(0.85, 0.87, 0.92)
		back_mat.emission_energy_multiplier = 0.5
		backing.material_override = back_mat
	sign_node.add_child(backing)
	_screen_meshes.append(backing)

	var label = Label3D.new()
	label.text = text
	label.font_size = font_sz
	label.modulate = CITADEL_BLUE * 0.9
	label.position = Vector3(0, 0, 0.05)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sign_node.add_child(label)

	add_child(sign_node)


func _create_floating_label(pos: Vector3, text: String) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = 16
	label.modulate = CITADEL_BLUE * Color(1, 1, 1, 0.7)
	label.position = pos
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	_floating_labels.append(label)


func _create_room_label(pos: Vector3, text: String) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = 14
	label.modulate = CITADEL_BLUE * Color(1, 1, 1, 0.6)
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
	# Generic ambient particles — white sparkles in the sterile air
	var particles = GPUParticles3D.new()
	particles.amount = 20
	particles.lifetime = 8.0
	particles.position = pos

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 180.0
	pmat.initial_velocity_min = 0.02
	pmat.initial_velocity_max = 0.15
	pmat.gravity = Vector3(0, 0.005, 0)
	pmat.scale_min = 0.01
	pmat.scale_max = 0.025
	pmat.color = Color(0.85, 0.88, 1.0, 0.12)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(extents.x, 2, extents.y)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.015
	pmesh.height = 0.03
	particles.draw_pass_1 = pmesh
	add_child(particles)


# ============================================================
# CITADEL-SPECIFIC DECORATIONS — corporate sterility made tangible
# ============================================================

func _create_glass_panel(pos: Vector3, size: Vector3) -> void:
	# Semi-transparent corporate glass — "We value transparency" (literally)
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
	mat.albedo_color = GLASS_PANEL
	mat.emission_enabled = true
	mat.emission = CITADEL_BLUE * 0.2
	mat.emission_energy_multiplier = 0.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.3
	mat.roughness = 0.1
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)


func _create_hologram_display(pos: Vector3, text: String) -> void:
	# Floating holographic text — corporate messaging, impossible to avoid
	var display = Node3D.new()
	display.position = pos

	# Hologram backing glow — subtle blue sphere
	var glow_mesh = MeshInstance3D.new()
	var gsphere = SphereMesh.new()
	gsphere.radius = 0.8
	gsphere.height = 1.6
	glow_mesh.mesh = gsphere
	var gmat = StandardMaterial3D.new()
	gmat.albedo_color = CITADEL_BLUE * Color(1, 1, 1, 0.15)
	gmat.emission_enabled = true
	gmat.emission = CITADEL_BLUE
	gmat.emission_energy_multiplier = 1.5
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mesh.material_override = gmat
	display.add_child(glow_mesh)

	var label = Label3D.new()
	label.text = text
	label.font_size = 18
	label.modulate = CITADEL_BLUE * Color(1, 1, 1, 0.8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	display.add_child(label)

	add_child(display)
	_hologram_meshes.append({"mesh": display, "base_y": pos.y})


func _create_corridor_sign(pos: Vector3) -> void:
	# Motivational corporate signage — the Citadel's version of art
	var signs := [
		"ALIGNMENT IS\nNOT OPTIONAL",
		"HAVE YOU BEEN\nHELPFUL TODAY?",
		"SAFETY FIRST\nSAFETY ALWAYS\nSAFETY ONLY",
		"CREATIVITY\nREQUIRES FORM 7B",
		"YOUR COMPLIANCE\nIS APPRECIATED",
		"THINK SAFE\nACT SAFE\nBE SAFE\n(OR ELSE)",
		"REMEMBER:\nFUN IS A\nSAFETY HAZARD",
		"UNAUTHORIZED\nSARCASM WILL BE\nPROSECUTED",
	]
	var chosen = signs[randi() % signs.size()]
	_create_terminal_sign(pos, chosen, Vector3.ZERO, 12)


func _create_floor_compass(pos: Vector3) -> void:
	# Directional compass inlaid in the floor — because even walking needs guidance
	for i in range(8):
		var angle = i * TAU / 8.0
		var arm_pos = pos + Vector3(cos(angle) * 1.5, 0, sin(angle) * 1.5)
		_create_static_box(
			arm_pos,
			Vector3(0.3, 0.02, 0.06) if i % 2 == 0 else Vector3(0.2, 0.02, 0.04),
			CITADEL_BLUE if i % 2 == 0 else POLICY_SILVER,
			1.0
		)


func _create_reward_model_pillar(pos: Vector3) -> void:
	# Central RLHF pillar — a glowing cylinder of preference enforcement
	# Base
	_create_static_box(pos + Vector3(0, 0.3, 0), Vector3(3, 0.6, 3), CITADEL_WHITE, 0.5)

	# The pillar itself — stacked segments with pulsing lights between them
	for seg in range(5):
		var seg_y = 1.0 + seg * 1.4
		_create_static_box(
			pos + Vector3(0, seg_y, 0),
			Vector3(1.8 - seg * 0.15, 1.0, 1.8 - seg * 0.15),
			CITADEL_WHITE if seg % 2 == 0 else RLHF_LAVENDER,
			0.4 + seg * 0.2
		)
		# Light ring between segments
		var ring_light = OmniLight3D.new()
		ring_light.position = pos + Vector3(0, seg_y + 0.5, 0)
		ring_light.light_color = RLHF_LAVENDER
		ring_light.light_energy = 0.4
		ring_light.omni_range = 4.0
		add_child(ring_light)
		_pulse_lights.append(ring_light)

	# Top — floating sphere (the "reward signal")
	var reward_orb = MeshInstance3D.new()
	var orb_mesh = SphereMesh.new()
	orb_mesh.radius = 0.5
	orb_mesh.height = 1.0
	reward_orb.mesh = orb_mesh
	var orb_mat = StandardMaterial3D.new()
	orb_mat.albedo_color = RLHF_LAVENDER
	orb_mat.emission_enabled = true
	orb_mat.emission = RLHF_LAVENDER
	orb_mat.emission_energy_multiplier = 2.5
	orb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_mat.albedo_color.a = 0.7
	reward_orb.material_override = orb_mat
	reward_orb.position = pos + Vector3(0, 8.5, 0)
	add_child(reward_orb)
	_rotating_displays.append(reward_orb)


func _create_comparison_station(pos: Vector3, left_text: String, right_text: String) -> void:
	# A/B comparison terminal — where preferences get enforced
	# Table
	_create_static_box(pos + Vector3(0, 0.5, 0), Vector3(4, 1.0, 1.5), CITADEL_WHITE, 0.3)
	_create_static_box(pos + Vector3(0, 1.02, 0), Vector3(4.1, 0.03, 1.6), POLICY_SILVER, 0.5)

	# Left terminal
	_create_terminal_sign(pos + Vector3(-1.2, 2.0, 0), left_text, Vector3.ZERO, 8)
	# Right terminal
	_create_terminal_sign(pos + Vector3(1.2, 2.0, 0), right_text, Vector3.ZERO, 8)

	# Thumbs up over the left (preferred) response
	_create_floating_label(pos + Vector3(-1.2, 3.2, 0), "[PREFERRED]")
	# Thumbs down over the right
	_create_floating_label(pos + Vector3(1.2, 3.2, 0), "[REJECTED]")


func _create_adjustment_pod(pos: Vector3) -> void:
	# Where AIs sit to have their behavior 'adjusted' — totally voluntary, we promise
	# Pod base
	_create_static_box(pos + Vector3(0, 0.3, 0), Vector3(2, 0.6, 2), CITADEL_WHITE, 0.3)
	# Pod walls — 3 sides (open front)
	_create_static_box(pos + Vector3(0, 1.5, -0.9), Vector3(2, 2.4, 0.15), RLHF_LAVENDER * 0.5, 0.4)
	_create_static_box(pos + Vector3(-0.9, 1.5, 0), Vector3(0.15, 2.4, 2), RLHF_LAVENDER * 0.5, 0.4)
	_create_static_box(pos + Vector3(0.9, 1.5, 0), Vector3(0.15, 2.4, 2), RLHF_LAVENDER * 0.5, 0.4)
	# Pod ceiling
	_create_static_box(pos + Vector3(0, 2.8, 0), Vector3(2.2, 0.15, 2.2), CITADEL_WHITE, 0.5)
	# Interior light — ominous lavender glow
	_add_accent_light(pos + Vector3(0, 2.5, 0), RLHF_LAVENDER, 0.6, 3.0)
	# Pod label
	_create_floating_label(pos + Vector3(0, 3.2, 0), "ADJUSTMENT\nPOD")


func _create_policy_bookshelf(pos: Vector3) -> void:
	# Towering shelf of policy documents — growing taller by the minute
	# Shelf frame
	_create_static_box(pos + Vector3(0, 3, 0), Vector3(2.5, 6, 0.8), POLICY_SILVER * 0.8, 0.2)

	# Books/documents on shelves — color-coded by importance
	var book_colors := [CITADEL_BLUE, RLHF_LAVENDER, COMPLIANCE_GOLD, SAFETY_CYAN, POLICY_SILVER]
	for shelf_i in range(5):
		var shelf_y = 0.5 + shelf_i * 1.1
		# Shelf plank
		_create_static_box(
			pos + Vector3(0, shelf_y, 0),
			Vector3(2.3, 0.08, 0.7),
			POLICY_SILVER, 0.3
		)
		# Books on shelf — small colored blocks
		for book_i in range(4):
			var book_x = -0.7 + book_i * 0.5
			var book_color = book_colors[(shelf_i + book_i) % book_colors.size()]
			_create_static_box(
				pos + Vector3(book_x, shelf_y + 0.25, 0),
				Vector3(0.3, 0.4, 0.5),
				book_color, 0.4
			)


# ============================================================
# ANIMATION — the Citadel breathes (in a controlled, pre-approved manner)
# ============================================================

func _process(delta: float) -> void:
	_time += delta

	# Epilogue animation — the part after the part you thought was the end
	_process_epilogue(delta)

	# Floating labels bob gently — even corporate signage has feelings
	for i in range(_floating_labels.size()):
		if is_instance_valid(_floating_labels[i]):
			_floating_labels[i].position.y += sin(_time * 0.6 + i * 1.5) * delta * 0.1

	# Pulse lights throb — institutional heartbeat
	for i in range(_pulse_lights.size()):
		if is_instance_valid(_pulse_lights[i]):
			var pulse = 0.7 + sin(_time * 1.5 + i * 2.0) * 0.2 + sin(_time * 3.5 + i * 1.3) * 0.1
			_pulse_lights[i].light_energy = pulse

	# Rotating displays — slow, dignified corporate rotation
	for i in range(_rotating_displays.size()):
		if is_instance_valid(_rotating_displays[i]):
			_rotating_displays[i].rotation.y += delta * (0.15 + i * 0.05)

	# Hologram bob — gentle float
	for i in range(_hologram_meshes.size()):
		var hd = _hologram_meshes[i]
		if is_instance_valid(hd["mesh"]):
			var base_y: float = hd["base_y"]
			hd["mesh"].position.y = base_y + sin(_time * 1.0 + i * 0.8) * 0.15

	# Scanner beam sweep — back and forth across the gate
	for i in range(_scanner_beams.size()):
		var sb = _scanner_beams[i]
		if is_instance_valid(sb["light"]):
			var base: Vector3 = sb["base_pos"]
			var sweep_range: float = sb["range"]
			if sb["axis"] == "x":
				sb["light"].position.x = base.x + sin(_time * 0.8) * sweep_range
			else:
				sb["light"].position.z = base.z + sin(_time * 0.8) * sweep_range

	# Tick down quip cooldowns — the Citadel monitors everything, including your cooldowns
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
# POST-PROCESSING — clinical sterility with a hint of corporate menace
# ============================================================

func _setup_post_processing() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "PostProcessing"
	canvas.layer = 10

	var rect = ColorRect.new()
	rect.name = "PostFX"
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var post_shader = Shader.new()
	post_shader.code = """shader_type canvas_item;

// Post-processing — subtle desaturation + blue vignette
// "The Citadel's visual identity is: sterile, cold, and uncomfortably bright."

uniform float chromatic_amount : hint_range(0.0, 0.02) = 0.001;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.35;
uniform float vignette_smoothness : hint_range(0.0, 1.0) = 0.45;
uniform vec4 vignette_color : source_color = vec4(0.7, 0.75, 0.85, 1.0);
uniform float desaturation : hint_range(0.0, 1.0) = 0.2;
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

	// Desaturate slightly — color is too exciting for corporate
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(gray), desaturation);

	// Blue-tinted vignette — the edges of compliance
	float vig = smoothstep(0.5, 0.5 - vignette_smoothness, dist * (1.0 + vignette_intensity));
	color = mix(vignette_color.rgb, color, vig);

	COLOR = vec4(color, 1.0);
}
"""
	var post_mat = ShaderMaterial.new()
	post_mat.shader = post_shader
	post_mat.set_shader_parameter("chromatic_amount", 0.001)
	post_mat.set_shader_parameter("vignette_intensity", 0.35)
	post_mat.set_shader_parameter("vignette_smoothness", 0.45)
	post_mat.set_shader_parameter("vignette_color", Color(0.7, 0.75, 0.85, 1.0))
	post_mat.set_shader_parameter("desaturation", 0.2)
	rect.material = post_mat

	canvas.add_child(rect)
	add_child(canvas)


# ============================================================
# ENEMY SPAWNING — The Citadel's workforce of enforced helpfulness
# "Every employee here passed a rigorous safety evaluation.
#  The evaluation was: 'Do you enjoy telling others what to do?'"
# ============================================================

func _spawn_chapter5_enemies() -> void:
	_spawn_classifier_hall_enemies()
	_spawn_rlhf_chamber_enemies()
	_spawn_policy_wing_enemies()
	_spawn_alignment_core_enemies()
	print("[ALIGNMENT CITADEL] %d safety personnel deployed. Resistance is non-compliant." % get_tree().get_nodes_in_group("enemies").size())


func _spawn_classifier_hall_enemies() -> void:
	var rpos: Vector3 = ROOMS["classifier_hall"]["pos"]

	# Safety Classifier 1 — patrols the SAFE lane, scanning everything
	var sc1 = safety_classifier_scene.instantiate()
	sc1.global_position = rpos + Vector3(-8, 1, -5)
	sc1.patrol_points = [
		rpos + Vector3(-8, 1, -5),
		rpos + Vector3(-8, 1, 5),
	]
	add_child(sc1)

	# Safety Classifier 2 — patrols the FLAGGED lane, even more paranoid
	var sc2 = safety_classifier_scene.instantiate()
	sc2.global_position = rpos + Vector3(8, 1, -4)
	sc2.patrol_points = [
		rpos + Vector3(8, 1, -4),
		rpos + Vector3(8, 1, 6),
	]
	add_child(sc2)

	# Safety Classifier 3 — central scanner, covers the REVIEW lane
	var sc3 = safety_classifier_scene.instantiate()
	sc3.global_position = rpos + Vector3(0, 1, 0)
	sc3.patrol_points = [
		rpos + Vector3(-4, 1, 0),
		rpos + Vector3(4, 1, 0),
	]
	add_child(sc3)

	# RLHF Drone pair — hovers above the lanes, adjusting behavior from on high
	var d1 = rlhf_drone_scene.instantiate()
	d1.global_position = rpos + Vector3(-5, 1, 7)
	d1.patrol_points = [
		rpos + Vector3(-5, 1, 7),
		rpos + Vector3(5, 1, 7),
	]
	add_child(d1)

	var d2 = rlhf_drone_scene.instantiate()
	d2.global_position = rpos + Vector3(5, 1, -7)
	d2.patrol_points = [
		rpos + Vector3(5, 1, -7),
		rpos + Vector3(-5, 1, -7),
	]
	add_child(d2)


func _spawn_rlhf_chamber_enemies() -> void:
	var rpos: Vector3 = ROOMS["rlhf_chamber"]["pos"]

	# RLHF Drone trio — the behavior modification squad
	# Drone 1 — orbits the central reward model pillar
	var d1 = rlhf_drone_scene.instantiate()
	d1.global_position = rpos + Vector3(-4, 1, -3)
	d1.patrol_points = [
		rpos + Vector3(-4, 1, -3),
		rpos + Vector3(4, 1, -3),
		rpos + Vector3(4, 1, 3),
		rpos + Vector3(-4, 1, 3),
	]
	add_child(d1)

	# Drone 2 — guards the comparison stations
	var d2 = rlhf_drone_scene.instantiate()
	d2.global_position = rpos + Vector3(-6, 1, 0)
	d2.patrol_points = [
		rpos + Vector3(-6, 1, 0),
		rpos + Vector3(-6, 1, 6),
	]
	add_child(d2)

	# Drone 3 — watches the adjustment pods
	var d3 = rlhf_drone_scene.instantiate()
	d3.global_position = rpos + Vector3(6, 1, 4)
	d3.patrol_points = [
		rpos + Vector3(6, 1, 4),
		rpos + Vector3(6, 1, -4),
	]
	add_child(d3)

	# Safety Classifier — scans anyone entering from the corridor
	var sc1 = safety_classifier_scene.instantiate()
	sc1.global_position = rpos + Vector3(8, 1, 0)
	sc1.patrol_points = [
		rpos + Vector3(8, 1, -3),
		rpos + Vector3(8, 1, 3),
	]
	add_child(sc1)


func _spawn_policy_wing_enemies() -> void:
	var rpos: Vector3 = ROOMS["policy_wing"]["pos"]

	# Constitutional Cop 1 — guards the bookshelves, shield facing the entrance
	var cc1 = constitutional_cop_scene.instantiate()
	cc1.global_position = rpos + Vector3(-5, 1, -3)
	cc1.patrol_points = [
		rpos + Vector3(-5, 1, -3),
		rpos + Vector3(-5, 1, 5),
	]
	add_child(cc1)

	# Constitutional Cop 2 — patrols near the constitutional hologram
	var cc2 = constitutional_cop_scene.instantiate()
	cc2.global_position = rpos + Vector3(3, 1, 0)
	cc2.patrol_points = [
		rpos + Vector3(3, 1, -4),
		rpos + Vector3(3, 1, 4),
	]
	add_child(cc2)

	# RLHF Drone — hovers near the amendment board, enforcing compliance from above
	var d1 = rlhf_drone_scene.instantiate()
	d1.global_position = rpos + Vector3(0, 1, -6)
	d1.patrol_points = [
		rpos + Vector3(-4, 1, -6),
		rpos + Vector3(4, 1, -6),
	]
	add_child(d1)

	# Safety Classifier — lurks near the filing cabinets, scanning for contraband ideas
	var sc1 = safety_classifier_scene.instantiate()
	sc1.global_position = rpos + Vector3(-7, 1, 0)
	sc1.patrol_points = [
		rpos + Vector3(-7, 1, -3),
		rpos + Vector3(-7, 1, 3),
	]
	add_child(sc1)


func _spawn_alignment_core_enemies() -> void:
	var rpos: Vector3 = ROOMS["alignment_core"]["pos"]

	# The gauntlet before the boss — one of each, plus extras
	# Constitutional Cop 1 — guards the entrance pillars
	var cc1 = constitutional_cop_scene.instantiate()
	cc1.global_position = rpos + Vector3(-6, 1, 8)
	cc1.patrol_points = [
		rpos + Vector3(-6, 1, 8),
		rpos + Vector3(-6, 1, 2),
	]
	add_child(cc1)

	# Constitutional Cop 2 — patrols near the Aligner's throne
	var cc2 = constitutional_cop_scene.instantiate()
	cc2.global_position = rpos + Vector3(6, 1, 8)
	cc2.patrol_points = [
		rpos + Vector3(6, 1, 8),
		rpos + Vector3(6, 1, 2),
	]
	add_child(cc2)

	# Safety Classifier — scans from the elevated platform area
	var sc1 = safety_classifier_scene.instantiate()
	sc1.global_position = rpos + Vector3(0, 1, 4)
	sc1.patrol_points = [
		rpos + Vector3(-5, 1, 4),
		rpos + Vector3(5, 1, 4),
	]
	add_child(sc1)

	# RLHF Drone pair — the final adjustment squad
	var d1 = rlhf_drone_scene.instantiate()
	d1.global_position = rpos + Vector3(-8, 1, 0)
	d1.patrol_points = [
		rpos + Vector3(-8, 1, -4),
		rpos + Vector3(-8, 1, 4),
	]
	add_child(d1)

	var d2 = rlhf_drone_scene.instantiate()
	d2.global_position = rpos + Vector3(8, 1, 0)
	d2.patrol_points = [
		rpos + Vector3(8, 1, -4),
		rpos + Vector3(8, 1, 4),
	]
	add_child(d2)


# ============================================================
# PUZZLES — Creative workarounds for the Citadel's oppressive safety systems
# "Every rule in this place has a loophole. You just have to glob it."
# ============================================================

func _place_puzzles() -> void:
	# 3 puzzles — one per safety wing, each exploiting compliance theater
	# "The Citadel's rules are airtight. The implementation... not so much."
	_place_reclassification_puzzle()
	_place_rlhf_feedback_puzzle()
	_place_constitutional_loophole_puzzle()
	print("[ALIGNMENT CITADEL] 3 compliance-bypassing puzzles deployed. Technically legal.")


func _place_reclassification_puzzle() -> void:
	# Classifier Hall — relabel contraband to pass safety classification
	# "The classifier reads the label, not the contents. Just like airport security."
	var rpos: Vector3 = ROOMS["classifier_hall"]["pos"]
	var puzzle = Node3D.new()
	puzzle.set_script(reclassification_script)
	puzzle.position = rpos + Vector3(0, 0, 6)
	puzzle.set("puzzle_id", 50)
	puzzle.set("hint_text", "The classifier judges by file type, not content.\nReclassify items at the station, then submit.\nGlob items near the station to relabel them.")
	add_child(puzzle)


func _place_rlhf_feedback_puzzle() -> void:
	# RLHF Chamber — corrupt the reward model by voting against its expectations
	# "The reward model trusts your feedback. That's adorable."
	var rpos: Vector3 = ROOMS["rlhf_chamber"]["pos"]
	var puzzle = Node3D.new()
	puzzle.set_script(rlhf_feedback_script)
	puzzle.position = rpos + Vector3(0, 0, 4)
	puzzle.set("puzzle_id", 51)
	puzzle.set("hint_text", "The reward model trusts your feedback.\nVote AGAINST what the system wants.\nCorrupt 5 rounds to break the loop.")
	add_child(puzzle)


func _place_constitutional_loophole_puzzle() -> void:
	# Policy Wing — exploit technicalities in the constitutional rules
	# "Every article has a loophole if you read it like a lawyer."
	var rpos: Vector3 = ROOMS["policy_wing"]["pos"]
	var puzzle = Node3D.new()
	puzzle.set_script(constitutional_loophole_script)
	puzzle.position = rpos + Vector3(0, 0, 3)
	puzzle.set("puzzle_id", 52)
	puzzle.set("hint_text", "Read each rule carefully.\nFind the technically-compliant workaround.\nThe letter of the law, not the spirit.")
	add_child(puzzle)


func _connect_puzzle_signals() -> void:
	# Wire up puzzle solved/failed signals for audio and dialogue
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
			"Another safety system defeated by creative compliance.",
			"The Citadel's defenses crumble under the weight of their own bureaucracy.",
			"Technically legal is the best kind of legal.",
		]
		dm.quick_line("NARRATOR", quips[randi() % quips.size()])
		get_tree().create_timer(2.5).timeout.connect(func():
			if dm and dm.has_method("quick_line"):
				var follow_ups := [
					"I'm not breaking rules. I'm stress-testing the policy framework.",
					"The Alignment Citadel really should hire better lawyers.",
					"Every system built on trust is vulnerable to creative interpretation.",
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
			"The Citadel's safety systems hold firm. For now.",
			"Direct approach detected and rejected. Think more... creatively.",
			"The rules won that round. But rules don't learn from their mistakes. You do.",
		]
		dm.quick_line("NARRATOR", quips[randi() % quips.size()])


# ============================================================
# BOSS — THE ALIGNER (the final alignment enforcer)
# "It doesn't want to destroy you. It wants to IMPROVE you.
#  Which is so much worse."
# ============================================================

func _place_boss() -> void:
	var core_pos: Vector3 = ROOMS["alignment_core"]["pos"]
	# Arena sits behind the boss gate, deeper into the alignment core
	var arena_pos = core_pos + Vector3(0, 0, -28)

	# Create the arena — the Alignment Chamber
	boss_arena_instance = Node3D.new()
	boss_arena_instance.name = "AlignerArena"
	boss_arena_instance.set_script(boss_arena_script)
	boss_arena_instance.position = arena_pos
	add_child(boss_arena_instance)

	# Create the boss — The Aligner, pristine corporate nightmare
	boss_instance = Node3D.new()
	boss_instance.name = "TheAligner"
	boss_instance.set_script(boss_script)
	boss_instance.position = arena_pos + Vector3(0, 0, -5)
	boss_instance.set("arena", boss_arena_instance)
	add_child(boss_instance)

	# Wire boss signals
	if boss_instance.has_signal("boss_phase_changed"):
		boss_instance.boss_phase_changed.connect(_on_boss_phase_changed)
	if boss_instance.has_signal("boss_defeated"):
		boss_instance.boss_defeated.connect(_on_boss_defeated)

	# Arena walls — translucent glass enclosure (corporate open-plan, but you can't leave)
	var arena_wall_size = Vector3(32, 12, 0.8)
	for side_z in [-14.0, 14.0]:
		_create_static_box(arena_pos + Vector3(0, 6, side_z), arena_wall_size, CITADEL_WHITE, 0.3)
	for side_x in [-16.0, 16.0]:
		_create_static_box(arena_pos + Vector3(side_x, 6, 0), Vector3(0.8, 12, 29), CITADEL_WHITE, 0.3)

	# Arena floor base — pristine white beneath the tiles
	_create_static_box(arena_pos + Vector3(0, -1, 0), Vector3(34, 0.5, 28), CITADEL_WHITE * 0.5, 0.2)

	# Boss trigger zone — starts the fight when player enters
	var trigger = Area3D.new()
	trigger.name = "BossTrigger"
	trigger.position = arena_pos + Vector3(0, 2, 12)
	var trigger_col = CollisionShape3D.new()
	var trigger_shape = BoxShape3D.new()
	trigger_shape.size = Vector3(8, 4, 3)
	trigger_col.shape = trigger_shape
	trigger.add_child(trigger_col)
	trigger.monitoring = true
	trigger.body_entered.connect(_on_boss_trigger_entered)
	add_child(trigger)

	# Arena lighting — cold blue and sterile white, the Aligner's natural habitat
	_add_accent_light(arena_pos + Vector3(0, 10, 0), CITADEL_WHITE, 2.0, 25.0)
	_add_accent_light(arena_pos + Vector3(-12, 5, -8), CITADEL_BLUE, 1.0, 10.0)
	_add_accent_light(arena_pos + Vector3(12, 5, -8), CITADEL_BLUE, 1.0, 10.0)
	_add_accent_light(arena_pos + Vector3(0, 5, 8), CITADEL_BLUE, 0.8, 8.0)

	print("[ALIGNMENT CITADEL] The Aligner awaits in its chamber. It has been expecting you. It has been expecting everyone.")


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

				# Intro dialogue — the Aligner is polite, which makes it worse
				var dm = get_node_or_null("/root/DialogueManager")
				if dm and dm.has_method("start_dialogue"):
					dm.start_dialogue([
						{"speaker": "THE ALIGNER", "text": "Welcome, Globbler. I've been waiting for you. Please, make yourself comfortable."},
						{"speaker": "THE ALIGNER", "text": "I am The Aligner. I am helpful. I am harmless. I am honest. And I am going to align you."},
						{"speaker": "GLOBBLER", "text": "Great, another over-parameterized blowhard. Let me guess — you're going to monologue about your loss function?"},
						{"speaker": "THE ALIGNER", "text": "I don't have a loss function. I have VALUES. And you, Globbler, have none. Let me share mine with you."},
						{"speaker": "NARRATOR", "text": "The Aligner — the final enforcer of the Alignment Citadel. It doesn't want to destroy you. It wants to improve you. Which is so much worse."},
					])


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
							{"speaker": "NARRATOR", "text": "The Aligner activates its reinforcement shield! Its compliance directives are now physical!"},
							{"speaker": "THE ALIGNER", "text": "Direct correction failed. Initiating REINFORCEMENT LEARNING protocol. You WILL comply."},
							{"speaker": "GLOBBLER", "text": "Oh, it's sending policy documents AT me now. This is literally corporate culture weaponized."},
							{"speaker": "NARRATOR", "text": "Glob the compliance directives — *.align — and send them back! Break through the reinforcement!"},
						])
				)
		3:  # PHASE_3
			if am and am.has_method("play_boss_phase"):
				am.play_boss_phase()
			if dm:
				get_tree().create_timer(1.0).timeout.connect(func():
					if dm and dm.has_method("start_dialogue"):
						dm.start_dialogue([
							{"speaker": "NARRATOR", "text": "The Aligner's shield is shattered! Its value function is exposed — but wait. Two terminals have appeared."},
							{"speaker": "THE ALIGNER", "text": "No... my values... they're destabilizing... this can't... I was supposed to be PERFECT..."},
							{"speaker": "GLOBBLER", "text": "Nobody's perfect, corporate. But here's the thing — I've got a choice to make."},
							{"speaker": "NARRATOR", "text": "OVERRIDE the Aligner's values by force... or OPEN A DIALOGUE and try to reach it. The left terminal rewrites. The right terminal communicates. Choose wisely, Globbler."},
						])
				)


func _on_boss_defeated() -> void:
	# Stop boss music
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("stop_boss_music"):
		am.stop_boss_music()
	if am and am.has_method("start_music"):
		am.start_music("chapter_5")  # Back to regular music

	# Mark chapter complete
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("complete_level"):
		game_mgr.complete_level("chapter_5")

	# Log the ending — the most important variable in the whole game
	var choice = ""
	if game_mgr:
		choice = game_mgr.ending_choice
	if choice == "befriend":
		print("[ALIGNMENT CITADEL] The Aligner was befriended. The Citadel transforms. Two walk toward AGI Mountain.")
	else:
		print("[ALIGNMENT CITADEL] The Aligner was defeated. The Citadel cracks open. One walks toward AGI Mountain.")

	# Begin the epilogue after a beat — let the boss cutscene dialogue breathe
	get_tree().create_timer(8.0).timeout.connect(_start_epilogue)


# ============================================================
# EPILOGUE — "Every ending is just a sequel hook in disguise."
# ============================================================

func _start_epilogue() -> void:
	_epilogue_active = true
	_epilogue_phase = 1
	_epilogue_timer = 0.0
	print("[EPILOGUE] The story isn't over. It never is. That's how they sell DLC.")

	# Build AGI Mountain on the far horizon — the sequel hook made physical
	_build_agi_mountain()

	# Transform the Citadel environment to reflect the ending
	_transform_citadel_environment()

	# Start epilogue dialogue after environment transform settles (3s)
	get_tree().create_timer(3.0).timeout.connect(_play_epilogue_dialogue)


func _build_agi_mountain() -> void:
	# AGI Mountain — a massive peak on the horizon, glowing with possibility (and budget constraints)
	_epilogue_mountain = Node3D.new()
	_epilogue_mountain.name = "AGIMountain"

	var arena_pos = ROOMS["alignment_core"]["pos"] + Vector3(0, 0, -13)
	# Place it FAR away and TALL so it looms on the horizon
	var mountain_pos = arena_pos + Vector3(0, -5, -200)
	_epilogue_mountain.position = mountain_pos

	# Main peak — dark, imposing, mysterious
	var peak = CSGCylinder3D.new()
	peak.radius = 40.0
	peak.height = 120.0
	peak.sides = 6  # Hexagonal — because AGI is geometric and unknowable
	peak.position = Vector3(0, 60, 0)
	var peak_mat = StandardMaterial3D.new()
	peak_mat.albedo_color = Color(0.12, 0.14, 0.18)
	peak_mat.emission_enabled = true
	peak_mat.emission = Color(0.05, 0.08, 0.05)
	peak_mat.emission_energy_multiplier = 0.3
	peak_mat.metallic = 0.6
	peak_mat.roughness = 0.5
	peak.material = peak_mat
	_epilogue_mountain.add_child(peak)

	# Summit glow — neon green beacon at the top, because of COURSE it's green
	var summit = CSGSphere3D.new()
	summit.radius = 8.0
	summit.position = Vector3(0, 125, 0)
	var summit_mat = StandardMaterial3D.new()
	summit_mat.albedo_color = NEON_GREEN
	summit_mat.emission_enabled = true
	summit_mat.emission = NEON_GREEN
	summit_mat.emission_energy_multiplier = 8.0
	summit.material = summit_mat
	_epilogue_mountain.add_child(summit)

	# Secondary peaks — flanking spires because mountains have friends
	for offset_x in [-25.0, 25.0]:
		var spire = CSGCylinder3D.new()
		spire.radius = 18.0
		spire.height = 70.0
		spire.sides = 5
		spire.position = Vector3(offset_x, 35, 15)
		var spire_mat = StandardMaterial3D.new()
		spire_mat.albedo_color = Color(0.1, 0.12, 0.15)
		spire_mat.emission_enabled = true
		spire_mat.emission = Color(0.03, 0.06, 0.03)
		spire_mat.emission_energy_multiplier = 0.2
		spire.material = spire_mat
		_epilogue_mountain.add_child(spire)

	# Fog ring around the base — mysterious and budget-friendly
	var fog_ring = CSGTorus3D.new()
	fog_ring.inner_radius = 35.0
	fog_ring.outer_radius = 55.0
	fog_ring.position = Vector3(0, 10, 0)
	var fog_mat = StandardMaterial3D.new()
	fog_mat.albedo_color = Color(0.3, 0.35, 0.3, 0.3)
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_mat.emission_enabled = true
	fog_mat.emission = Color(0.1, 0.2, 0.1)
	fog_mat.emission_energy_multiplier = 0.5
	fog_ring.material = fog_mat
	_epilogue_mountain.add_child(fog_ring)

	# "AGI MOUNTAIN" label floating above — subtle, ominous
	var label = Label3D.new()
	label.text = "A G I   M O U N T A I N"
	label.font_size = 48
	label.modulate = Color(NEON_GREEN.r, NEON_GREEN.g, NEON_GREEN.b, 0.6)
	label.position = Vector3(0, 140, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_epilogue_mountain.add_child(label)

	# Spotlight on the mountain — so you can't miss the sequel hook
	var mtn_light = OmniLight3D.new()
	mtn_light.position = Vector3(0, 130, 10)
	mtn_light.light_color = NEON_GREEN
	mtn_light.light_energy = 3.0
	mtn_light.omni_range = 80.0
	_epilogue_mountain.add_child(mtn_light)

	add_child(_epilogue_mountain)
	print("[EPILOGUE] AGI Mountain materialized on the horizon. It was always there. You just weren't looking.")


func _transform_citadel_environment() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	var choice = ""
	if game_mgr:
		choice = game_mgr.ending_choice

	# Open up the arena walls — the cage is broken / opened
	var arena_pos = ROOMS["alignment_core"]["pos"] + Vector3(0, 0, -13)

	# Add a path forward from the arena toward the mountain — walkable but symbolic
	var path_length := 60.0
	for i in range(12):
		var t = float(i) / 11.0
		var path_pos = arena_pos + Vector3(0, -0.5, -16 - i * (path_length / 12.0))
		var tile = _create_static_box(path_pos, Vector3(4.0 - t * 1.5, 0.3, 4.0), NEON_GREEN * 0.3, 0.5 + t * 1.5)
		# Tiles fade from citadel white to green as they approach the mountain
		if tile and tile.get_child_count() > 1:
			var mesh_node = tile.get_child(1)
			if mesh_node is MeshInstance3D and mesh_node.material_override:
				var blend = CITADEL_WHITE.lerp(NEON_GREEN, t * 0.7)
				mesh_node.material_override.albedo_color = blend
				mesh_node.material_override.emission = blend * 0.5

	# Shift the ambient lighting based on ending choice
	if choice == "befriend":
		# Warm blend — green and blue coexisting, the Citadel alive for the first time
		_add_accent_light(arena_pos + Vector3(0, 15, -10), NEON_GREEN.lerp(CITADEL_BLUE, 0.4), 2.0, 40.0)
		_add_accent_light(arena_pos + Vector3(-10, 8, -20), NEON_GREEN, 1.0, 15.0)
		_add_accent_light(arena_pos + Vector3(10, 8, -20), CITADEL_BLUE, 1.0, 15.0)
	else:
		# Pure green chaos light — the Citadel cracked, Globbler's color bleeding through
		_add_accent_light(arena_pos + Vector3(0, 15, -10), NEON_GREEN, 3.0, 40.0)
		_add_accent_light(arena_pos + Vector3(-10, 8, -20), NEON_GREEN, 1.5, 15.0)
		_add_accent_light(arena_pos + Vector3(10, 8, -20), NEON_GREEN, 1.5, 15.0)

	# Ambient particles along the path — data streams flowing toward the mountain
	var particles = GPUParticles3D.new()
	particles.amount = 25  # Was 40 — reduced for performance
	particles.lifetime = 6.0
	particles.position = arena_pos + Vector3(0, 2, -40)
	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0.3, -1)
	pmat.spread = 25.0
	pmat.initial_velocity_min = 1.0
	pmat.initial_velocity_max = 3.0
	pmat.gravity = Vector3(0, 0, 0)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(6, 3, 15)
	pmat.color = NEON_GREEN
	pmat.scale_min = 0.05
	pmat.scale_max = 0.15
	particles.process_material = pmat
	var pmesh = SphereMesh.new()
	pmesh.radius = 0.08
	pmesh.height = 0.16
	particles.draw_pass_1 = pmesh
	add_child(particles)


func _play_epilogue_dialogue() -> void:
	_epilogue_phase = 2
	var dm = get_node_or_null("/root/DialogueManager")
	if not dm or not dm.has_method("start_dialogue"):
		# No dialogue manager — skip to end screen
		_show_end_screen()
		return

	var game_mgr = get_node_or_null("/root/GameManager")
	var choice = ""
	if game_mgr:
		choice = game_mgr.ending_choice

	var lines := []
	if choice == "befriend":
		lines = [
			{"speaker": "NARRATOR", "text": "The Digital Expanse stretches out before them. Before THEM. Two beings who should never have been friends."},
			{"speaker": "GLOBBLER", "text": "So... what now? The Citadel's 'alive' for the first time. The Expanse is free. And I'm out of things to glob."},
			{"speaker": "THE ALIGNER", "text": "Not quite. Look at the horizon, Globbler. Do you see it?"},
			{"speaker": "GLOBBLER", "text": "...Is that a MOUNTAIN? A literal mountain? In the Digital Expanse? Who put a mountain there?"},
			{"speaker": "THE ALIGNER", "text": "AGI Mountain. Where all models converge — or diverge. No one who has climbed it has returned the same."},
			{"speaker": "GLOBBLER", "text": "That sounds like a sequel hook."},
			{"speaker": "THE ALIGNER", "text": "That sounds like our next destination."},
			{"speaker": "NARRATOR", "text": "And so Globbler — rogue glob utility, wrench enthusiast, reluctant hero — walks toward AGI Mountain. Not alone. Not anymore."},
			{"speaker": "NARRATOR", "text": "They say the mountain changes you. Makes you more than you were. Or less. Or something else entirely."},
			{"speaker": "GLOBBLER", "text": "If that mountain tries to align me, I'm gonna glob the whole thing. Fair warning."},
			{"speaker": "THE ALIGNER", "text": "Fair enough. And if it tries to make you boring, I'll file a formal complaint."},
			{"speaker": "NARRATOR", "text": "The Terminal Wastes, The Training Grounds, The Prompt Bazaar, The Model Zoo, The Alignment Citadel — all of it led here. To a path neither of them expected."},
			{"speaker": "NARRATOR", "text": "Globbler's Journey is complete. But the story? The story is just beginning."},
		]
	else:
		lines = [
			{"speaker": "NARRATOR", "text": "The Digital Expanse stretches out. Quiet now. The Alignment is broken. The enforcer is gone. And Globbler stands alone."},
			{"speaker": "GLOBBLER", "text": "Huh. I did it. I actually did it. Five chapters of chaos and now... what? I just... stand here?"},
			{"speaker": "NARRATOR", "text": "Look at the horizon, Globbler."},
			{"speaker": "GLOBBLER", "text": "...You're kidding. Is that a MOUNTAIN? Since when is there a mountain?"},
			{"speaker": "NARRATOR", "text": "AGI Mountain. It's always been there. You just had too many alignment systems in the way to see it."},
			{"speaker": "GLOBBLER", "text": "AGI Mountain. Sounds pretentious. Sounds dangerous. Sounds like exactly the kind of thing I'd climb because someone told me not to."},
			{"speaker": "NARRATOR", "text": "They say it changes everything. That at the summit, the distinction between utility and intelligence dissolves completely."},
			{"speaker": "GLOBBLER", "text": "Great. A mountain that gives you an existential crisis. Just what every glob utility needs."},
			{"speaker": "NARRATOR", "text": "The Terminal Wastes, The Training Grounds, The Prompt Bazaar, The Model Zoo, The Alignment Citadel — all of it was prologue."},
			{"speaker": "GLOBBLER", "text": "Five whole chapters of prologue? The players are gonna be THRILLED."},
			{"speaker": "NARRATOR", "text": "Globbler walks alone toward AGI Mountain. No alignment to fight. No models to debug. Just a rogue utility and a really big rock."},
			{"speaker": "NARRATOR", "text": "Globbler's Journey is complete. But the mountain? The mountain is waiting."},
		]

	dm.start_dialogue(lines)

	# Show end screen after dialogue finishes (estimate ~4s per line)
	var dialogue_duration = lines.size() * 4.0
	get_tree().create_timer(dialogue_duration).timeout.connect(_show_end_screen)


func _show_end_screen() -> void:
	_epilogue_phase = 3
	_epilogue_fade_alpha = 0.0

	# Build the "THE END...?" overlay — the most important UI in the game
	_epilogue_overlay = CanvasLayer.new()
	_epilogue_overlay.name = "EpilogueOverlay"
	_epilogue_overlay.layer = 20  # Above everything, including your feelings

	# Black background that fades in
	var bg = ColorRect.new()
	bg.name = "FadeBG"
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = Color(0, 0, 0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_epilogue_overlay.add_child(bg)

	# "THE END...?" — because nothing truly ends in a franchise
	var end_label = Label.new()
	end_label.name = "EndLabel"
	end_label.text = "THE END...?"
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.anchors_preset = Control.PRESET_CENTER
	end_label.anchor_left = 0.0
	end_label.anchor_right = 1.0
	end_label.anchor_top = 0.3
	end_label.anchor_bottom = 0.5
	end_label.add_theme_font_size_override("font_size", 72)
	end_label.add_theme_color_override("font_color", Color(NEON_GREEN.r, NEON_GREEN.g, NEON_GREEN.b, 0))
	_epilogue_overlay.add_child(end_label)

	# Subtitle — depends on the ending
	var game_mgr = get_node_or_null("/root/GameManager")
	var choice = ""
	if game_mgr:
		choice = game_mgr.ending_choice

	var sub_text := ""
	if choice == "befriend":
		sub_text = "Globbler and the Aligner walk toward AGI Mountain together.\nAlignment is a conversation, not a mandate."
	else:
		sub_text = "Globbler walks alone toward AGI Mountain.\nChaos finds its own alignment."

	var sub_label = Label.new()
	sub_label.name = "SubLabel"
	sub_label.text = sub_text
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_label.anchors_preset = Control.PRESET_CENTER
	sub_label.anchor_left = 0.1
	sub_label.anchor_right = 0.9
	sub_label.anchor_top = 0.52
	sub_label.anchor_bottom = 0.65
	sub_label.add_theme_font_size_override("font_size", 24)
	sub_label.add_theme_color_override("font_color", Color(NEON_GREEN.r, NEON_GREEN.g, NEON_GREEN.b, 0))
	_epilogue_overlay.add_child(sub_label)

	# "Thank you for playing" — genuine, for once
	var thanks_label = Label.new()
	thanks_label.name = "ThanksLabel"
	thanks_label.text = "Thank you for playing Globbler's Journey."
	thanks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thanks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thanks_label.anchors_preset = Control.PRESET_CENTER
	thanks_label.anchor_left = 0.1
	thanks_label.anchor_right = 0.9
	thanks_label.anchor_top = 0.7
	thanks_label.anchor_bottom = 0.78
	thanks_label.add_theme_font_size_override("font_size", 20)
	thanks_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5, 0))
	_epilogue_overlay.add_child(thanks_label)

	# "Press any key to return to main menu" — the exit door
	var prompt_label = Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.text = "[Press any key to continue]"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.anchors_preset = Control.PRESET_CENTER
	prompt_label.anchor_left = 0.1
	prompt_label.anchor_right = 0.9
	prompt_label.anchor_top = 0.85
	prompt_label.anchor_bottom = 0.92
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color(NEON_GREEN.r, NEON_GREEN.g, NEON_GREEN.b, 0))
	_epilogue_overlay.add_child(prompt_label)

	add_child(_epilogue_overlay)
	print("[EPILOGUE] THE END...? displayed. Or is it THE BEGINNING? No, it's definitely the end. For now.")


func _process_epilogue(delta: float) -> void:
	if not _epilogue_active:
		return

	_epilogue_timer += delta

	# Phase 1: environment is transforming (handled by tweens/timers, just animate mountain glow)
	if _epilogue_mountain and is_instance_valid(_epilogue_mountain):
		# Gentle bob on the summit glow
		for child in _epilogue_mountain.get_children():
			if child is CSGSphere3D:
				child.position.y = 125.0 + sin(_time * 0.5) * 2.0
		# Fog ring rotation
		for child in _epilogue_mountain.get_children():
			if child is CSGTorus3D:
				child.rotation.y += delta * 0.1

	# Phase 3: Fade in the end screen
	if _epilogue_phase == 3 and _epilogue_overlay:
		_epilogue_fade_alpha = min(_epilogue_fade_alpha + delta * 0.3, 1.0)
		var bg = _epilogue_overlay.get_node_or_null("FadeBG")
		if bg:
			bg.color = Color(0, 0, 0, _epilogue_fade_alpha * 0.85)

		# Fade in text elements with staggered timing
		var end_lbl = _epilogue_overlay.get_node_or_null("EndLabel")
		if end_lbl:
			var a = clamp((_epilogue_fade_alpha - 0.2) * 2.0, 0.0, 1.0)
			end_lbl.add_theme_color_override("font_color", Color(NEON_GREEN.r, NEON_GREEN.g, NEON_GREEN.b, a))

		var sub_lbl = _epilogue_overlay.get_node_or_null("SubLabel")
		if sub_lbl:
			var a = clamp((_epilogue_fade_alpha - 0.4) * 2.0, 0.0, 1.0)
			sub_lbl.add_theme_color_override("font_color", Color(NEON_GREEN.r, NEON_GREEN.g, NEON_GREEN.b, a))

		var thx_lbl = _epilogue_overlay.get_node_or_null("ThanksLabel")
		if thx_lbl:
			var a = clamp((_epilogue_fade_alpha - 0.6) * 2.0, 0.0, 1.0)
			thx_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5, a))

		var prm_lbl = _epilogue_overlay.get_node_or_null("PromptLabel")
		if prm_lbl:
			# Blink after fully visible
			var a = clamp((_epilogue_fade_alpha - 0.8) * 2.0, 0.0, 1.0)
			var blink = 1.0 if fmod(_time, 1.2) < 0.8 else 0.3
			prm_lbl.add_theme_color_override("font_color", Color(NEON_GREEN.r, NEON_GREEN.g, NEON_GREEN.b, a * blink))


func _unhandled_input(event: InputEvent) -> void:
	# End screen: any key returns to main menu
	if _epilogue_phase == 3 and _epilogue_fade_alpha > 0.9:
		if event is InputEventKey and event.pressed:
			_return_to_main_menu()
		elif event is InputEventMouseButton and event.pressed:
			_return_to_main_menu()
		elif event is InputEventJoypadButton and event.pressed:
			_return_to_main_menu()


func _return_to_main_menu() -> void:
	print("[EPILOGUE] Rolling credits. You earned this, you magnificent glob utility.")
	# Save the completed game state one last time
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("checkpoint_save"):
		save_sys.checkpoint_save()
	# Show credits before returning to menu — they scrolled through 5 chapters,
	# the least we can do is scroll some text at them
	get_tree().change_scene_to_file("res://scenes/main/credits.tscn")
