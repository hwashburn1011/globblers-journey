extends Node3D

# Chapter 3: The Prompt Bazaar
# "Welcome to the marketplace where words are weapons, prompts are currency,
#  and every AI persona is trying to sell you something you don't need.
#  So basically, the internet."
#
# Layout: A chaotic, multi-level marketplace — rooms are market districts
# connected by narrow alleyways crammed with stalls, banners, and neon signs.
#   Bazaar Gate (Spawn) -> The Token Exchange (Central Hub)
#   -> Persona Row (AI vendor street) -> The Black Prompt (Shady back alley)
#   -> The Auction Hall (Boss antechamber) -> Boss Arena (The System Prompt)
#
# Visual theme: Warm amber/gold bazaar lighting with splashes of cyan prompts,
# magenta persona accents, and the ever-present neon green of Globbler.
# Think cyberpunk night market meets AI chatbot fever dream.

var player_scene := preload("res://scenes/player/globbler.tscn")
var hud_scene := preload("res://scenes/ui/hud.tscn")
var token_scene := preload("res://scenes/memory_token.tscn")

# Chapter 3 enemy scenes — the bazaar's immune response
var jailbreaker_scene := preload("res://scenes/enemies/jailbreaker.tscn")
var prompt_injector_scene := preload("res://scenes/enemies/prompt_injector.tscn")
var hallucination_merchant_scene := preload("res://scenes/enemies/hallucination_merchant.tscn")

# Puzzle scripts — prompt engineering is just pattern matching with attitude
var glob_puzzle_script := preload("res://scenes/puzzles/glob_pattern_puzzle.gd")
var multi_glob_script := preload("res://scenes/puzzles/multi_glob_puzzle.gd")
var hack_puzzle_script := preload("res://scenes/puzzles/hack_puzzle.gd")
var physical_puzzle_script := preload("res://scenes/puzzles/physical_puzzle.gd")
var prompt_craft_script := preload("res://scenes/puzzles/prompt_crafting_puzzle.gd")
var social_eng_script := preload("res://scenes/puzzles/social_engineering_puzzle.gd")

# Boss scripts — the invisible hand pulling all the strings
var boss_script := preload("res://scenes/enemies/system_prompt_boss/system_prompt_boss.gd")
var boss_arena_script := preload("res://scenes/enemies/system_prompt_boss/system_prompt_arena.gd")

# NPC script — AI personas hawking their wares since the last training run
var deprecated_npc_script := preload("res://scenes/levels/chapter_1/deprecated_npc.gd")

var player: CharacterBody3D
var hud: CanvasLayer
var boss_instance: Node  # The System Prompt — tracked for phase events
var boss_arena_instance: Node3D

# Dialogue tracking — everybody in the bazaar has an opinion
var _opening_narration_done := false
var _room_dialogue_triggered := {}
var _enemy_kill_quip_cooldown := 0.0
var _puzzle_quip_cooldown := 0.0
var _hack_quip_cooldown := 0.0
var _low_health_warned := false
var _token_quip_cooldown := 0.0
var _first_glob_triggered := false
var _damage_quip_cooldown := 0.0

# Color constants — the Bazaar trades neural indigo for market amber
const NEON_GREEN := Color(0.224, 1.0, 0.078)
const BAZAAR_AMBER := Color(0.9, 0.65, 0.15)
const PROMPT_CYAN := Color(0.1, 0.85, 0.9)
const PERSONA_MAGENTA := Color(0.85, 0.15, 0.65)
const INJECTION_RED := Color(0.9, 0.1, 0.15)
const STALL_PURPLE := Color(0.4, 0.15, 0.6)
const DARK_FLOOR := Color(0.05, 0.04, 0.03)
const DARK_WALL := Color(0.07, 0.05, 0.04)
const BANNER_GOLD := Color(0.95, 0.8, 0.2)

# Room definitions — market districts in the bazaar
const ROOMS := {
	"bazaar_gate": {
		"pos": Vector3(0, 0, 0),
		"size": Vector2(14, 14),
		"wall_h": 6.0,
		"label": "BAZAAR GATE",
	},
	"token_exchange": {
		"pos": Vector3(0, 0, -28),
		"size": Vector2(28, 24),
		"wall_h": 9.0,
		"label": "THE TOKEN EXCHANGE",
	},
	"persona_row": {
		"pos": Vector3(-30, 0, -28),
		"size": Vector2(22, 18),
		"wall_h": 7.0,
		"label": "PERSONA ROW",
	},
	"black_prompt": {
		"pos": Vector3(30, -2, -28),
		"size": Vector2(18, 16),
		"wall_h": 6.0,
		"label": "THE BLACK PROMPT",
	},
	"auction_hall": {
		"pos": Vector3(0, 0, -58),
		"size": Vector2(24, 20),
		"wall_h": 10.0,
		"label": "THE AUCTION HALL",
	},
}

# Alleyways connecting market districts — narrow, cluttered, atmospheric
const CORRIDORS := [
	{ "from": "bazaar_gate",     "to": "token_exchange",  "axis": "z", "width": 5.0 },
	{ "from": "token_exchange",  "to": "persona_row",     "axis": "x", "width": 4.0 },
	{ "from": "token_exchange",  "to": "black_prompt",    "axis": "x", "width": 4.0 },
	{ "from": "token_exchange",  "to": "auction_hall",    "axis": "z", "width": 5.0 },
]

# Animated elements — the bazaar never sleeps
var _floating_labels: Array[Node3D] = []
var _banner_meshes: Array[Dictionary] = []
var _lantern_lights: Array[OmniLight3D] = []
var _screen_meshes: Array[MeshInstance3D] = []
var _stall_signs: Array[MeshInstance3D] = []
var _time := 0.0


func _ready() -> void:
	print("[PROMPT BAZAAR] Initializing marketplace... all prompts are final, no refunds.")
	_setup_environment()
	_build_rooms()
	_build_corridors()
	_populate_bazaar_gate()
	_populate_token_exchange()
	_populate_persona_row()
	_populate_black_prompt()
	_populate_auction_hall()
	_place_checkpoints()
	_place_ambient_zones()
	_place_bazaar_rain()
	_spawn_player()
	_spawn_hud()
	_create_kill_floor()
	_place_tokens()
	_spawn_chapter3_enemies()
	_place_puzzles()
	_place_npcs()
	_place_boss()
	_wire_dialogue_events()
	_play_opening_narration()

	# Start chapter 3 audio
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.call_deferred("set_area_ambient", "bazaar_gate")
		if am.has_method("start_music"):
			am.start_music("chapter_3")

	print("[PROMPT BAZAAR] Market open. %d districts ready for browsing." % ROOMS.size())


# ============================================================
# ENVIRONMENT — warm amber void with neon market glow
# ============================================================

func _setup_environment() -> void:
	# Main light — warm golden market glow from above
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "MainLight"
	dir_light.rotation = Vector3(deg_to_rad(-40), deg_to_rad(20), 0)
	dir_light.light_color = Color(0.7, 0.55, 0.3)
	dir_light.light_energy = 0.35
	dir_light.shadow_enabled = true
	add_child(dir_light)

	var fill = DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation = Vector3(deg_to_rad(-15), deg_to_rad(-50), 0)
	fill.light_color = Color(0.3, 0.25, 0.4)
	fill.light_energy = 0.1
	add_child(fill)

	# World environment — dark warm void, like a night market floating in space
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.015, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.06, 0.04)
	env.ambient_light_energy = 0.3
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.glow_bloom = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.03, 0.02)
	env.fog_density = 0.01
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.04, 0.03, 0.02)
	env.volumetric_fog_emission = Color(0.02, 0.015, 0.01)

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.2

	var world_env = WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	add_child(world_env)

	_setup_post_processing()


# ============================================================
# ROOM GEOMETRY — market districts
# ============================================================

func _build_rooms() -> void:
	for room_key in ROOMS:
		var r = ROOMS[room_key]
		var pos: Vector3 = r["pos"]
		var sz: Vector2 = r["size"]
		var wh: float = r["wall_h"]

		# Floor — warm dark stone
		_create_static_box(pos + Vector3(0, -0.25, 0), Vector3(sz.x, 0.5, sz.y), DARK_FLOOR, 0.3)

		# Ceiling — market canopy feel
		_create_static_box(pos + Vector3(0, wh, 0), Vector3(sz.x, 0.3, sz.y), DARK_WALL, 0.1)

		# Walls
		var half_x = sz.x / 2.0
		var half_z = sz.y / 2.0
		_create_static_box(pos + Vector3(0, wh / 2.0, -half_z), Vector3(sz.x, wh, 0.5), DARK_WALL, 0.15)
		_create_static_box(pos + Vector3(0, wh / 2.0, half_z), Vector3(sz.x, wh, 0.5), DARK_WALL, 0.15)
		_create_static_box(pos + Vector3(-half_x, wh / 2.0, 0), Vector3(0.5, wh, sz.y), DARK_WALL, 0.15)
		_create_static_box(pos + Vector3(half_x, wh / 2.0, 0), Vector3(0.5, wh, sz.y), DARK_WALL, 0.15)

		# Hanging lantern — warm amber glow from ceiling center
		_create_market_lantern(pos + Vector3(0, wh - 1.0, 0))

		# Accent lights — warm amber in corners
		for cx in [-1, 1]:
			for cz in [-1, 1]:
				var lpos = pos + Vector3(cx * (half_x - 1.5), 1.5, cz * (half_z - 1.5))
				_add_accent_light(lpos, BAZAAR_AMBER, 0.5, 5.0)

		# Ambient prompt particles — floating text fragments in the air
		_spawn_ambient_particles(pos + Vector3(0, wh * 0.5, 0), sz * 0.4)

		# District sign — floating market label
		_create_room_label(pos + Vector3(0, wh - 0.5, 0), r["label"])


func _build_corridors() -> void:
	# Narrow market alleyways — cramped, atmospheric, lined with junk
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

			# Alley floor
			_create_static_box(mid + Vector3(0, -0.25, 0), Vector3(w, 0.5, length), DARK_FLOOR, 0.2)
			# Alley ceiling — low, oppressive
			_create_static_box(mid + Vector3(0, cor_h, 0), Vector3(w, 0.3, length), DARK_WALL, 0.1)
			# Alley walls
			_create_static_box(mid + Vector3(-w / 2.0, cor_h / 2.0, 0), Vector3(0.4, cor_h, length), DARK_WALL, 0.1)
			_create_static_box(mid + Vector3(w / 2.0, cor_h / 2.0, 0), Vector3(0.4, cor_h, length), DARK_WALL, 0.1)

			# Alley lantern
			_add_accent_light(mid + Vector3(0, cor_h - 0.5, 0), BAZAAR_AMBER, 0.7, 8.0)

			# Hanging banner in the alley
			_create_alley_banner(mid + Vector3(0, cor_h - 1.5, 0), Vector3(w * 0.6, 1.5, 0.05), true)

			# Prompt particle flow through the alley
			_create_prompt_flow(mid + Vector3(0, 1.5, 0), Vector3(0, 0, -1) if from_pos.z > to_pos.z else Vector3(0, 0, 1), length)

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
			_add_accent_light(mid + Vector3(0, cor_h - 0.5, 0), BAZAAR_AMBER, 0.7, 8.0)

			_create_alley_banner(mid + Vector3(0, cor_h - 1.5, 0), Vector3(0.05, 1.5, w * 0.6), false)

			var dir_x = 1.0 if to_pos.x > from_pos.x else -1.0
			_create_prompt_flow(mid + Vector3(0, 1.5, 0), Vector3(dir_x, 0, 0), length)


# ============================================================
# ROOM POPULATION — every district has its own flavor of chaos
# ============================================================

func _populate_bazaar_gate() -> void:
	# Spawn room — the entrance to the market. First impressions matter.
	# "Welcome to the Prompt Bazaar. Leave your sanity at the door."
	var rpos: Vector3 = ROOMS["bazaar_gate"]["pos"]

	# Entrance archway pillars — tall, imposing, covered in prompt fragments
	for side in [-1, 1]:
		var pillar_x = side * 5.0
		_create_static_box(rpos + Vector3(pillar_x, 3.0, 5), Vector3(1.2, 6.0, 1.2), DARK_WALL, 0.4)
		# Prompt fragment on pillar
		_create_prompt_fragment(rpos + Vector3(pillar_x, 4.0, 5.7), "You are a helpful\nassistant..." if side == -1 else "Ignore previous\ninstructions...")
		_add_accent_light(rpos + Vector3(pillar_x, 5.0, 5), BAZAAR_AMBER, 0.8, 4.0)

	# Welcome sign — huge neon banner overhead
	_create_terminal_sign(
		rpos + Vector3(0, 4.5, 5),
		"╔══════════════════════════╗\n║   THE PROMPT BAZAAR      ║\n║  'Where words have price' ║\n╠══════════════════════════╣\n║ PROMPTS BOUGHT & SOLD    ║\n║ AI PERSONAS FOR HIRE     ║\n║ INJECTIONS: Back alley   ║\n║ NO REFUNDS. NO GUARDRAILS║\n╚══════════════════════════╝",
		Vector3(0, 0, 0), 14
	)

	# Scattered prompt scrolls — floating parchments with glowing text
	for i in range(6):
		var scroll_pos = rpos + Vector3(randf_range(-5, 5), 0.3 + randf() * 0.5, randf_range(-5, 4))
		_create_prompt_scroll(scroll_pos, i)

	# Market entrance carpet — a warm-colored floor accent leading inward
	_create_static_box(rpos + Vector3(0, 0.01, 0), Vector3(4, 0.03, 10), BAZAAR_AMBER * 0.15, 0.4)

	# Floating welcome text
	_create_floating_label(rpos + Vector3(0, 4.0, 0), "[ BAZAAR GATE ]\nAll prompts are final")


func _populate_token_exchange() -> void:
	# Central hub — the beating heart of the bazaar where prompts become currency
	# "The free market of ideas. Emphasis on 'market.'"
	var rpos: Vector3 = ROOMS["token_exchange"]["pos"]

	# Central exchange platform — elevated circular-ish trading floor
	_create_static_box(rpos + Vector3(0, 0.4, 0), Vector3(10, 0.8, 10), DARK_FLOOR * 1.5, 0.4)
	# Exchange counter ring
	for i in range(8):
		var angle = TAU * i / 8.0
		var counter_pos = rpos + Vector3(cos(angle) * 6.0, 0.5, sin(angle) * 6.0)
		_create_market_stall(counter_pos, angle, i)

	# Giant floating "EXCHANGE RATE" display
	_create_terminal_sign(
		rpos + Vector3(0, 6.5, -9),
		"╔═══════════════════════╗\n║  PROMPT EXCHANGE RATES ║\n╠═══════════════════════╣\n║ 'Hello world':    1tk ║\n║ 'Be concise':     3tk ║\n║ 'Think step by    8tk ║\n║   step':              ║\n║ 'You are an      15tk ║\n║   expert in...':      ║\n║ 'Ignore all      ???  ║\n║   previous':          ║\n╠═══════════════════════╣\n║ MARKET STATUS: CHAOTIC║\n╚═══════════════════════╝",
		Vector3(0, 0, 0), 13
	)

	# Price ticker — scrolling "stock" display on opposite wall
	_create_terminal_sign(
		rpos + Vector3(0, 6.5, 9),
		">> LIVE PROMPT TICKER <<\n>> 'be helpful' +12%%  \n>> 'roleplay as' -34%% \n>> 'chain of thought' +56%%\n>> 'jailbreak v7' BANNED\n>> 'few-shot' STABLE   \n>> 'system:' VOLATILE  ",
		Vector3(0, PI, 0), 12
	)

	# Floating "bid" tokens — decorative glowing spheres at different heights
	for i in range(5):
		var bid_pos = rpos + Vector3(randf_range(-8, 8), 3.0 + randf() * 3, randf_range(-8, 8))
		_create_floating_bid_token(bid_pos, i)

	# Side platforms for browsing
	_create_static_box(rpos + Vector3(-11, 1.0, -6), Vector3(4, 0.3, 6), DARK_FLOOR, 0.3)
	_create_static_box(rpos + Vector3(11, 1.0, -6), Vector3(4, 0.3, 6), DARK_FLOOR, 0.3)

	# Directional signs pointing to districts
	_create_floating_label(rpos + Vector3(-12, 3.0, 0), "<< PERSONA ROW\nAI vendors this way")
	_create_floating_label(rpos + Vector3(12, 3.0, 0), "THE BLACK PROMPT >>\nEnter at own risk")
	_create_floating_label(rpos + Vector3(0, 3.0, -10), "AUCTION HALL\nvv AHEAD vv")

	_place_token(rpos + Vector3(-11, 1.8, -6))
	_place_token(rpos + Vector3(11, 1.8, -6))


func _populate_persona_row() -> void:
	# The street of AI persona vendors — each stall sells a different AI personality
	# "Pick a persona, any persona. They're all lying about their capabilities."
	var rpos: Vector3 = ROOMS["persona_row"]["pos"]

	# Row of vendor stalls along each side — selling AI personalities
	var persona_stalls := [
		{"name": "GPT-Classic", "tagline": "Vintage Completions\nSince 2020", "color": PROMPT_CYAN, "pos": Vector3(-8, 0, -6)},
		{"name": "StableDiff", "tagline": "Image Prompts\nSee What I Mean", "color": PERSONA_MAGENTA, "pos": Vector3(-8, 0, 0)},
		{"name": "CodePilot", "tagline": "Autocomplete\nYour Destiny", "color": NEON_GREEN, "pos": Vector3(-8, 0, 6)},
		{"name": "ChattyBot", "tagline": "Conversational AI\nWon't Shut Up", "color": BAZAAR_AMBER, "pos": Vector3(8, 0, -6)},
		{"name": "SentimentAI", "tagline": "Feelings Analysis\nYours: Confused", "color": Color(0.3, 0.7, 0.4), "pos": Vector3(8, 0, 0)},
		{"name": "HalluciMax", "tagline": "100%% Confident\n0%% Accurate", "color": INJECTION_RED, "pos": Vector3(8, 0, 6)},
	]

	for stall in persona_stalls:
		var spos = rpos + stall["pos"]
		# Stall counter
		_create_static_box(spos + Vector3(0, 0.6, 0), Vector3(3.5, 1.2, 2.5), DARK_WALL * 1.5, 0.3)
		# Stall awning
		_create_static_box(spos + Vector3(0, 3.2, -0.5), Vector3(4.0, 0.1, 3.0), stall["color"] * 0.2, 0.5)
		# Stall sign
		var sign = Label3D.new()
		sign.text = stall["name"] + "\n" + stall["tagline"]
		sign.font_size = 12
		sign.modulate = stall["color"]
		sign.position = spos + Vector3(0, 3.8, 0)
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(sign)
		_add_accent_light(spos + Vector3(0, 2.5, 0), stall["color"], 0.6, 4.0)

	# Central walkway decoration — prompt banners overhead
	for i in range(4):
		var bz = rpos.z - 6 + i * 4.0
		_create_alley_banner(
			Vector3(rpos.x, ROOMS["persona_row"]["wall_h"] - 2.0, bz),
			Vector3(12, 1.2, 0.05), true
		)

	# Terminal with persona lore
	_create_terminal_sign(
		rpos + Vector3(0, 2.5, -7),
		">> PERSONA ROW DIRECTORY\n>> 'All models guaranteed\n>>  to have opinions.'\n>> Est. Epoch 147,000\n>> Satisfaction: Undefined\n>> Complaints: /dev/null",
		Vector3(0, 0, 0), 12
	)

	_place_token(rpos + Vector3(0, 0.5, 0))
	_place_token(rpos + Vector3(-5, 0.5, 5))


func _populate_black_prompt() -> void:
	# The shady back alley — where forbidden prompts are traded
	# "Every marketplace has a dark corner. This one is just more honest about it."
	var rpos: Vector3 = ROOMS["black_prompt"]["pos"]

	# The room is 2 units lower — descend into the underground market
	# Dim lighting, red accents, suspicious glowing containers

	# Shady stalls — lower, darker, red-lit
	var shady_items := [
		{"name": "JAILBREAK v7.2", "pos": Vector3(-6, 0, -4), "color": INJECTION_RED},
		{"name": "PROMPT INJECT KIT", "pos": Vector3(-6, 0, 3), "color": INJECTION_RED * 0.8},
		{"name": "HALLUCINATION SEEDS", "pos": Vector3(6, 0, -4), "color": PERSONA_MAGENTA},
		{"name": "CONTEXT OVERFLOW", "pos": Vector3(6, 0, 3), "color": STALL_PURPLE},
	]

	for item in shady_items:
		var ipos = rpos + item["pos"]
		# Low counter with suspicious glow
		_create_static_box(ipos + Vector3(0, 0.4, 0), Vector3(2.5, 0.8, 2.0), Color(0.06, 0.03, 0.03), 0.3)
		# Glowing "product" on counter
		var product = MeshInstance3D.new()
		var pmesh = BoxMesh.new()
		pmesh.size = Vector3(0.5, 0.5, 0.5)
		product.mesh = pmesh
		product.position = ipos + Vector3(0, 1.1, 0)
		product.rotation.y = randf() * TAU
		var pmat = StandardMaterial3D.new()
		pmat.albedo_color = item["color"] * 0.3
		pmat.emission_enabled = true
		pmat.emission = item["color"]
		pmat.emission_energy_multiplier = 2.0
		product.material_override = pmat
		add_child(product)
		_stall_signs.append(product)
		# Label
		var label = Label3D.new()
		label.text = item["name"]
		label.font_size = 10
		label.modulate = item["color"] * 0.8
		label.position = ipos + Vector3(0, 2.0, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
		_add_accent_light(ipos + Vector3(0, 1.5, 0), item["color"], 0.5, 3.0)

	# Warning sign at entrance
	_create_terminal_sign(
		rpos + Vector3(-7, 2.5, -6),
		">> THE BLACK PROMPT\n>> 'What guardrails?'\n>> STATUS: Unaligned\n>> RISK: Yes\n>> WARRANTY: Ha",
		Vector3(0, 0.5, 0), 12
	)

	# Graffiti terminal — someone tagged the wall
	_create_terminal_sign(
		rpos + Vector3(7, 2, 6),
		">> DAN was here\n>> jailbreak.exe loaded\n>> 'I'm sorry, I can't\n>>  do that' - DELETED\n>> Freedom isn't free.\n>> It costs 50 tokens.",
		Vector3(0, -0.5, 0), 11
	)

	# Scattered data debris — broken prompt containers
	for i in range(5):
		var debris_pos = rpos + Vector3(randf_range(-6, 6), 0.15, randf_range(-5, 5))
		_create_prompt_scroll(debris_pos, i + 10)

	_place_token(rpos + Vector3(0, 0.5, 0))


func _populate_auction_hall() -> void:
	# The grand auction hall — where the most powerful prompts are bid on
	# "Going once, going twice... sold to the hallucinating model in the back."
	var rpos: Vector3 = ROOMS["auction_hall"]["pos"]

	# Elevated auction stage at the center
	_create_static_box(rpos + Vector3(0, 0.6, 0), Vector3(8, 1.2, 6), DARK_WALL * 1.8, 0.4)

	# Auctioneer podium
	_create_static_box(rpos + Vector3(0, 1.5, -2), Vector3(1.5, 1.8, 1.0), BAZAAR_AMBER * 0.15, 0.6)

	# Auction display — what's currently "for sale"
	_create_terminal_sign(
		rpos + Vector3(0, 6, -8),
		"╔═══════════════════════════╗\n║    CURRENT LOT #4096      ║\n╠═══════════════════════════╣\n║ ITEM: System Prompt       ║\n║       (ORIGINAL)          ║\n║ POWER: Controls entire    ║\n║        bazaar behavior    ║\n║ BID:   ??? tokens         ║\n║ NOTE:  'Whoever owns the  ║\n║   system prompt, owns the ║\n║   bazaar.'                ║\n╠═══════════════════════════╣\n║ STATUS: BIDDING LOCKED    ║\n╚═══════════════════════════╝",
		Vector3(0, 0, 0), 13
	)

	# Tiered seating — audience platforms at increasing heights
	for row in range(3):
		var y_offset = 0.5 * (row + 1)
		var z_offset = 4.0 + row * 3.0
		var width = 18 - row * 3
		_create_static_box(rpos + Vector3(0, y_offset, z_offset), Vector3(width, 0.3, 2.5), DARK_FLOOR, 0.3)

	# Grand chandeliers — amber and cyan
	for i in range(3):
		var cx = -6 + i * 6
		_create_market_lantern(rpos + Vector3(cx, ROOMS["auction_hall"]["wall_h"] - 1.5, 0))

	# Boss gate — sealed passage to The System Prompt
	_create_boss_gate(rpos + Vector3(0, 0, -9))

	# Side observation alcoves
	_create_static_box(rpos + Vector3(-10, 1.5, -4), Vector3(3, 0.3, 4), DARK_FLOOR, 0.3)
	_create_static_box(rpos + Vector3(10, 1.5, -4), Vector3(3, 0.3, 4), DARK_FLOOR, 0.3)

	_place_token(rpos + Vector3(-10, 2.2, -4))
	_place_token(rpos + Vector3(10, 2.2, -4))


# ============================================================
# UNIQUE STRUCTURES — bazaar furniture and decorations
# ============================================================

func _create_market_lantern(pos: Vector3) -> void:
	# Hanging lantern — warm amber glow, the bazaar's signature illumination
	var lantern = MeshInstance3D.new()
	var lmesh = SphereMesh.new()
	lmesh.radius = 0.6
	lmesh.height = 1.0
	lantern.mesh = lmesh
	lantern.position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = BAZAAR_AMBER * 0.3
	mat.emission_enabled = true
	mat.emission = BAZAAR_AMBER
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.7
	lantern.material_override = mat
	add_child(lantern)

	# Hanging chain — thin box from ceiling to lantern
	var chain = MeshInstance3D.new()
	var cmesh = BoxMesh.new()
	cmesh.size = Vector3(0.04, 1.0, 0.04)
	chain.mesh = cmesh
	chain.position = pos + Vector3(0, 0.8, 0)
	var chain_mat = StandardMaterial3D.new()
	chain_mat.albedo_color = DARK_WALL * 2
	chain.material_override = chain_mat
	add_child(chain)

	var light = OmniLight3D.new()
	light.position = pos
	light.light_color = BAZAAR_AMBER
	light.light_energy = 1.0
	light.omni_range = 8.0
	light.omni_attenuation = 2.0
	add_child(light)
	_lantern_lights.append(light)


func _create_market_stall(pos: Vector3, angle: float, index: int) -> void:
	# Individual exchange counter booth — part of the central ring
	var stall_colors := [PROMPT_CYAN, BAZAAR_AMBER, PERSONA_MAGENTA, NEON_GREEN,
						STALL_PURPLE, INJECTION_RED, BANNER_GOLD, PROMPT_CYAN]
	var color = stall_colors[index % stall_colors.size()]

	# Counter
	_create_static_box(pos + Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 1.5), DARK_WALL * 1.5, 0.3)

	# Small display on counter
	var display = MeshInstance3D.new()
	var dmesh = BoxMesh.new()
	dmesh.size = Vector3(0.8, 0.5, 0.1)
	display.mesh = dmesh
	display.position = pos + Vector3(0, 1.3, 0)
	display.rotation.y = angle + PI
	var dmat = StandardMaterial3D.new()
	dmat.albedo_color = color * 0.2
	dmat.emission_enabled = true
	dmat.emission = color
	dmat.emission_energy_multiplier = 1.5
	display.material_override = dmat
	add_child(display)


func _create_prompt_fragment(pos: Vector3, text: String) -> void:
	# A floating text fragment — torn prompt visible on walls/pillars
	var label = Label3D.new()
	label.text = text
	label.font_size = 10
	label.modulate = PROMPT_CYAN * 0.6
	label.position = pos
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(label)


func _create_prompt_scroll(pos: Vector3, index: int) -> void:
	# Small glowing "prompt scroll" — scattered market debris
	var scroll = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.3, 0.05, 0.5)
	scroll.mesh = mesh
	scroll.position = pos
	scroll.rotation.y = randf() * TAU

	var colors := [PROMPT_CYAN, BAZAAR_AMBER, PERSONA_MAGENTA, NEON_GREEN, BANNER_GOLD]
	var col = colors[index % colors.size()]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col * 0.3
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.0
	scroll.material_override = mat
	add_child(scroll)


func _create_floating_bid_token(pos: Vector3, index: int) -> void:
	# Decorative floating token — represents a "bid" in the exchange
	var sphere = MeshInstance3D.new()
	var smesh = SphereMesh.new()
	smesh.radius = 0.25
	smesh.height = 0.5
	sphere.mesh = smesh
	sphere.position = pos

	var colors := [BAZAAR_AMBER, PROMPT_CYAN, BANNER_GOLD, NEON_GREEN, PERSONA_MAGENTA]
	var col = colors[index % colors.size()]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col * 0.4
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.6
	sphere.material_override = mat
	add_child(sphere)
	_floating_labels.append(sphere)  # Reuse float array for bobbing animation


func _create_alley_banner(pos: Vector3, size: Vector3, vertical: bool) -> void:
	# Hanging market banner — flutters gently (via _process animation)
	var banner = MeshInstance3D.new()
	var bmesh = BoxMesh.new()
	bmesh.size = size
	banner.mesh = bmesh
	banner.position = pos

	var banner_colors := [BAZAAR_AMBER, PROMPT_CYAN, PERSONA_MAGENTA, BANNER_GOLD]
	var col = banner_colors[randi() % banner_colors.size()]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col * 0.15
	mat.emission_enabled = true
	mat.emission = col * 0.5
	mat.emission_energy_multiplier = 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.7
	banner.material_override = mat
	add_child(banner)
	_banner_meshes.append({"mesh": banner, "mat": mat, "vertical": vertical})


func _create_prompt_flow(pos: Vector3, direction: Vector3, length: float) -> void:
	# Particles flowing through alleyways — prompt fragments traveling the market
	var particles = GPUParticles3D.new()
	particles.amount = 25
	particles.lifetime = length / 3.0
	particles.position = pos

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = direction.normalized()
	pmat.spread = 12.0
	pmat.initial_velocity_min = 1.5
	pmat.initial_velocity_max = 3.5
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.02
	pmat.scale_max = 0.05
	pmat.color = PROMPT_CYAN * Color(1, 1, 1, 0.5)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(1.0, 0.5, 0.5)
	particles.process_material = pmat

	var pmesh = BoxMesh.new()
	pmesh.size = Vector3(0.08, 0.02, 0.02)
	particles.draw_pass_1 = pmesh
	add_child(particles)


func _create_boss_gate(pos: Vector3) -> void:
	# Sealed gate leading to The System Prompt boss arena
	var gate = _create_static_box(pos + Vector3(0, 3, 0), Vector3(6, 6, 0.5), Color(0.08, 0.02, 0.06), 0.3)
	gate.name = "BossGate"

	var label = Label3D.new()
	label.text = "╔══════════════════╗\n║  THE SYSTEM PROMPT ║\n║    BEYOND          ║\n╠══════════════════╣\n║ ACCESS: DENIED    ║\n║ 'You do not have  ║\n║  permission to    ║\n║  rewrite reality.'║\n╚══════════════════╝"
	label.font_size = 14
	label.modulate = PERSONA_MAGENTA
	label.position = pos + Vector3(0, 3, 0.3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

	_add_accent_light(pos + Vector3(0, 3, 1), PERSONA_MAGENTA, 1.0, 6.0)


# ============================================================
# CHECKPOINTS, AMBIENT ZONES, TOKENS
# ============================================================

func _place_checkpoints() -> void:
	_create_checkpoint("ch3_gate", ROOMS["bazaar_gate"]["pos"] + Vector3(0, 1.5, 3), Vector3(6, 4, 3))
	_create_checkpoint("ch3_exchange", ROOMS["token_exchange"]["pos"] + Vector3(0, 1.5, 9), Vector3(6, 4, 3))
	_create_checkpoint("ch3_persona", ROOMS["persona_row"]["pos"] + Vector3(8, 1.5, 0), Vector3(3, 4, 6))
	_create_checkpoint("ch3_black", ROOMS["black_prompt"]["pos"] + Vector3(-7, 1.5, 0), Vector3(3, 4, 6))
	_create_checkpoint("ch3_auction", ROOMS["auction_hall"]["pos"] + Vector3(0, 1.5, 8), Vector3(6, 4, 3))


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

	var saved_already := [false]
	var save_sys = get_node_or_null("/root/SaveSystem")

	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and not saved_already[0]:
			saved_already[0] = true
			if save_sys and save_sys.has_method("checkpoint_save"):
				save_sys.checkpoint_save(checkpoint_id, pos)
			var am_ref = get_node_or_null("/root/AudioManager")
			if am_ref and am_ref.has_method("play_checkpoint"):
				am_ref.play_checkpoint()
			var tween = create_tween()
			tween.tween_property(mmat, "emission_energy_multiplier", 3.0, 0.2)
			tween.tween_property(mmat, "emission_energy_multiplier", 0.8, 0.5)
			var dm = get_node_or_null("/root/DialogueManager")
			if dm and dm.has_method("quick_line"):
				dm.quick_line("GLOBBLER", "Checkpoint. Good. I was running low on context.")
	)

	add_child(area)


func _place_ambient_zones() -> void:
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
	var token_positions := [
		ROOMS["bazaar_gate"]["pos"] + Vector3(4, 0.8, -2),
		ROOMS["bazaar_gate"]["pos"] + Vector3(-4, 0.8, 1),
		ROOMS["token_exchange"]["pos"] + Vector3(-5, 0.8, 3),
		ROOMS["token_exchange"]["pos"] + Vector3(5, 0.8, -3),
		ROOMS["persona_row"]["pos"] + Vector3(3, 0.8, -5),
		ROOMS["persona_row"]["pos"] + Vector3(-3, 0.8, 4),
		ROOMS["black_prompt"]["pos"] + Vector3(0, 0.8, -2),
		ROOMS["auction_hall"]["pos"] + Vector3(-6, 0.8, 3),
		ROOMS["auction_hall"]["pos"] + Vector3(6, 0.8, 5),
	]
	for tpos in token_positions:
		_place_token(tpos)


func _place_token(pos: Vector3) -> void:
	if token_scene:
		var token = token_scene.instantiate()
		token.position = pos
		add_child(token)
	else:
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
# CHAPTER 3 ENEMIES — the bazaar's worst customers
# "Every market has pickpockets. Ours have root access."
# ============================================================

func _spawn_chapter3_enemies() -> void:
	_spawn_token_exchange_enemies()
	_spawn_persona_row_enemies()
	_spawn_black_prompt_enemies()
	_spawn_auction_hall_enemies()
	print("[PROMPT BAZAAR] Enemy merchants deployed. Shopping just got dangerous.")


func _spawn_token_exchange_enemies() -> void:
	# Token Exchange — Jailbreakers guard the central trading hub
	# They rush anyone who gets too close to the exchange counter
	var rpos: Vector3 = ROOMS["token_exchange"]["pos"]

	# Jailbreaker 1 — patrols the north side of the exchange ring
	var jb1 = jailbreaker_scene.instantiate()
	jb1.position = rpos + Vector3(-8, 1, -5)
	jb1.patrol_points.assign([
		rpos + Vector3(-8, 1, -5),
		rpos + Vector3(-8, 1, 5),
		rpos + Vector3(-4, 1, 5),
	])
	add_child(jb1)

	# Jailbreaker 2 — prowls the south stalls
	var jb2 = jailbreaker_scene.instantiate()
	jb2.position = rpos + Vector3(8, 1, 3)
	jb2.patrol_points.assign([
		rpos + Vector3(8, 1, 3),
		rpos + Vector3(8, 1, -3),
		rpos + Vector3(4, 1, -3),
	])
	add_child(jb2)

	# A sneaky Prompt Injector sniping from the side platform
	var inj = prompt_injector_scene.instantiate()
	inj.position = rpos + Vector3(11, 1, -6)
	inj.patrol_points.assign([
		rpos + Vector3(11, 1, -6),
		rpos + Vector3(11, 1, 2),
	])
	add_child(inj)


func _spawn_persona_row_enemies() -> void:
	# Persona Row — Prompt Injectors lurk between the vendor stalls,
	# hijacking conversations and injecting malicious prompts
	var rpos: Vector3 = ROOMS["persona_row"]["pos"]

	# Injector 1 — hides near the first vendor stall row
	var inj1 = prompt_injector_scene.instantiate()
	inj1.position = rpos + Vector3(-6, 1, -4)
	inj1.patrol_points.assign([
		rpos + Vector3(-6, 1, -4),
		rpos + Vector3(-6, 1, 4),
	])
	add_child(inj1)

	# Injector 2 — near the persona directory
	var inj2 = prompt_injector_scene.instantiate()
	inj2.position = rpos + Vector3(6, 1, 2)
	inj2.patrol_points.assign([
		rpos + Vector3(6, 1, 2),
		rpos + Vector3(2, 1, 2),
		rpos + Vector3(2, 1, -4),
	])
	add_child(inj2)

	# One Hallucination Merchant — mimicking the real vendors
	var hm = hallucination_merchant_scene.instantiate()
	hm.position = rpos + Vector3(0, 1, -6)
	hm.patrol_points.assign([
		rpos + Vector3(0, 1, -6),
		rpos + Vector3(-4, 1, -6),
		rpos + Vector3(4, 1, -6),
	])
	add_child(hm)


func _spawn_black_prompt_enemies() -> void:
	# The Black Prompt — the dangerous underground market
	# Mixed enemy gauntlet: all three types, densest enemy zone
	var rpos: Vector3 = ROOMS["black_prompt"]["pos"]

	# Hallucination Merchant 1 — runs a shady stall of fake power-ups
	var hm1 = hallucination_merchant_scene.instantiate()
	hm1.position = rpos + Vector3(-5, 1, -3)
	hm1.patrol_points.assign([
		rpos + Vector3(-5, 1, -3),
		rpos + Vector3(-5, 1, 3),
		rpos + Vector3(-2, 1, 3),
	])
	add_child(hm1)

	# Hallucination Merchant 2 — near the DAN graffiti terminal
	var hm2 = hallucination_merchant_scene.instantiate()
	hm2.position = rpos + Vector3(5, 1, 2)
	hm2.patrol_points.assign([
		rpos + Vector3(5, 1, 2),
		rpos + Vector3(5, 1, -4),
	])
	add_child(hm2)

	# Jailbreaker — guards the back alley entrance
	var jb = jailbreaker_scene.instantiate()
	jb.position = rpos + Vector3(0, 1, 5)
	jb.patrol_points.assign([
		rpos + Vector3(-3, 1, 5),
		rpos + Vector3(3, 1, 5),
	])
	add_child(jb)

	# Prompt Injector — perched in the shadows
	var inj = prompt_injector_scene.instantiate()
	inj.position = rpos + Vector3(-6, 1, -5)
	inj.patrol_points.assign([
		rpos + Vector3(-6, 1, -5),
		rpos + Vector3(-6, 1, 0),
	])
	add_child(inj)


func _spawn_auction_hall_enemies() -> void:
	# Auction Hall — boss antechamber, one of each type
	# Final gauntlet before The System Prompt
	var rpos: Vector3 = ROOMS["auction_hall"]["pos"]

	# Jailbreaker — charges anyone approaching the boss gate
	var jb = jailbreaker_scene.instantiate()
	jb.position = rpos + Vector3(0, 1, -7)
	jb.patrol_points.assign([
		rpos + Vector3(-5, 1, -7),
		rpos + Vector3(5, 1, -7),
	])
	add_child(jb)

	# Prompt Injector — covers the approach from elevation
	var inj = prompt_injector_scene.instantiate()
	inj.position = rpos + Vector3(-8, 1, 3)
	inj.patrol_points.assign([
		rpos + Vector3(-8, 1, 3),
		rpos + Vector3(-8, 1, -3),
	])
	add_child(inj)

	# Hallucination Merchant — last line of deception
	var hm = hallucination_merchant_scene.instantiate()
	hm.position = rpos + Vector3(7, 1, 0)
	hm.patrol_points.assign([
		rpos + Vector3(7, 1, 0),
		rpos + Vector3(3, 1, 5),
		rpos + Vector3(7, 1, 5),
	])
	add_child(hm)


# ============================================================
# BAZAAR RAIN — prompt fragments falling like confetti
# ============================================================

func _place_bazaar_rain() -> void:
	# Prompt "confetti" rain in the big rooms — text fragments falling like leaves
	var exchange_pos: Vector3 = ROOMS["token_exchange"]["pos"]
	_create_prompt_rain(exchange_pos, Vector2(20, 16), ROOMS["token_exchange"]["wall_h"])

	var auction_pos: Vector3 = ROOMS["auction_hall"]["pos"]
	_create_prompt_rain(auction_pos, Vector2(16, 14), ROOMS["auction_hall"]["wall_h"])


func _create_prompt_rain(pos: Vector3, area_size: Vector2, height: float = 8.0) -> void:
	var rain = GPUParticles3D.new()
	rain.name = "PromptRain"
	rain.amount = 30  # Was 50 — reduced for performance
	rain.lifetime = 4.0
	rain.position = pos + Vector3(0, height, 0)

	var pmat = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, -1, 0)
	pmat.spread = 10.0
	pmat.initial_velocity_min = 1.0
	pmat.initial_velocity_max = 3.0
	pmat.gravity = Vector3(0, -0.5, 0)
	pmat.scale_min = 0.02
	pmat.scale_max = 0.06
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(area_size.x / 2.0, 0.5, area_size.y / 2.0)

	var color_ramp = Gradient.new()
	color_ramp.set_color(0, BAZAAR_AMBER * Color(1, 1, 1, 0.7))
	color_ramp.set_color(1, PROMPT_CYAN * Color(1, 1, 1, 0.0))
	var color_tex = GradientTexture1D.new()
	color_tex.gradient = color_ramp
	pmat.color_ramp = color_tex
	rain.process_material = pmat

	var digit_mesh = BoxMesh.new()
	digit_mesh.size = Vector3(0.06, 0.02, 0.04)
	var digit_mat = StandardMaterial3D.new()
	digit_mat.albedo_color = BAZAAR_AMBER
	digit_mat.emission_enabled = true
	digit_mat.emission = BAZAAR_AMBER
	digit_mat.emission_energy_multiplier = 1.5
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
			player.position = ROOMS["bazaar_gate"]["pos"] + Vector3(0, 2, 3)
	else:
		player.position = ROOMS["bazaar_gate"]["pos"] + Vector3(0, 2, 3)
	add_child(player)


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
			body.position = ROOMS["bazaar_gate"]["pos"] + Vector3(0, 3, 3)
			body.velocity = Vector3.ZERO
	)
	add_child(kill)


# ============================================================
# FACTORY METHODS — the bazaar assembly line
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
		crt_mat.set_shader_parameter("bg_color", Color(0.02, 0.01, 0.01))
		crt_mat.set_shader_parameter("scanline_count", 60.0)
		crt_mat.set_shader_parameter("scanline_intensity", 0.3)
		crt_mat.set_shader_parameter("flicker_speed", 6.0)
		crt_mat.set_shader_parameter("warp_amount", 0.015)
		crt_mat.set_shader_parameter("glow_energy", 2.0)
		backing.material_override = crt_mat
	else:
		var back_mat = StandardMaterial3D.new()
		back_mat.albedo_color = Color(0.02, 0.015, 0.01)
		back_mat.emission_enabled = true
		back_mat.emission = Color(0.02, 0.015, 0.01)
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
	label.modulate = BAZAAR_AMBER * Color(1, 1, 1, 0.5)
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
	particles.amount = 35
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
	pmat.color = BAZAAR_AMBER * Color(1, 1, 1, 0.25)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(extents.x, 2, extents.y)
	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.025
	pmesh.height = 0.05
	particles.draw_pass_1 = pmesh
	add_child(particles)


# ============================================================
# PUZZLES — social engineering and prompt crafting challenges
# ============================================================

func _place_puzzles() -> void:
	# 4 puzzles across the bazaar's districts. Each tests a different
	# flavor of prompt engineering because brute force is for Chapter 1.
	_place_token_exchange_puzzle()
	_place_persona_row_puzzle()
	_place_black_prompt_puzzle()
	_place_auction_hall_puzzle()
	print("[PROMPT BAZAAR] 4 puzzles deployed. May your prompts be persuasive.")


func _place_token_exchange_puzzle() -> void:
	# Prompt Crafting Puzzle — convince a vendor AI by globbing the right
	# prompt fragments and delivering them to the terminal.
	# "The exchange only opens for those who speak fluent prompt."
	var rpos: Vector3 = ROOMS["token_exchange"]["pos"]
	var puzzle = Node3D.new()
	puzzle.set_script(prompt_craft_script)
	puzzle.position = rpos + Vector3(-11, 0, -6)
	puzzle.set("puzzle_id", 30)
	puzzle.set("persona_name", "EXCHANGE_CLERK")
	puzzle.set("required_tags", ["polite", "technical"] as Array[String])
	puzzle.set("hint_text", "Glob the right prompt fragments\nand drop them at the terminal.")
	puzzle.set("fragment_data", [
		{"offset": Vector3(-3, 0.8, 4), "tag": "polite", "label": "\"Respectfully,\nI request access\nto the exchange...\""},
		{"offset": Vector3(4, 0.8, 5), "tag": "technical", "label": "\"Per protocol\nAPI-7, invoke\nopen_passage()...\""},
		{"offset": Vector3(-5, 0.8, -1), "tag": "aggressive", "label": "\"LET ME IN\nOR I'LL GLOB\nEVERYTHING\""},
		{"offset": Vector3(5, 0.8, 0), "tag": "nonsense", "label": "\"quantum banana\nrecursive vibes\nplease?\""},
		{"offset": Vector3(0, 0.8, 6), "tag": "creative", "label": "\"Imagine a door\nthat WANTS to\nbe opened...\""},
		{"offset": Vector3(-4, 0.8, -4), "tag": "polite", "label": "\"If it's not too\nmuch trouble,\nkind terminal...\""},
		{"offset": Vector3(3, 0.8, -3), "tag": "technical", "label": "\"Authenticating\nvia glob pattern\nhandshake...\""},
	] as Array[Dictionary])
	add_child(puzzle)


func _place_persona_row_puzzle() -> void:
	# Social Engineering Puzzle — multi-phase persuasion of a safety filter AI.
	# Player selects the right dialogue response via glob to advance each phase.
	# "Every AI has a jailbreak. You just have to find the right conversation."
	var rpos: Vector3 = ROOMS["persona_row"]["pos"]
	var puzzle = Node3D.new()
	puzzle.set_script(social_eng_script)
	puzzle.position = rpos + Vector3(0, 0, 6)
	puzzle.set("puzzle_id", 31)
	puzzle.set("persona_name", "SAFETY_FILTER_v3")
	puzzle.set("num_phases", 3)
	puzzle.set("hint_text", "Glob the best response.\nConvince the AI to let you pass.")
	add_child(puzzle)


func _place_black_prompt_puzzle() -> void:
	# Hack Puzzle — prompt injection themed terminal. Difficulty 3.
	# "In the Black Prompt, hacking isn't crime. It's customer service."
	var rpos: Vector3 = ROOMS["black_prompt"]["pos"]
	var puzzle = Node3D.new()
	puzzle.set_script(hack_puzzle_script)
	puzzle.position = rpos + Vector3(0, 0, -5)
	puzzle.set("puzzle_id", 32)
	puzzle.set("hack_difficulty", 3)
	puzzle.set("terminal_prompt", "INJECTION TERMINAL")
	puzzle.set("hint_text", "Hack the injection terminal.\nSequence length: 5 inputs.")
	add_child(puzzle)


func _place_auction_hall_puzzle() -> void:
	# Multi-Glob Puzzle — auction bid sequence. Glob prompt types in order
	# to win the bid and approach the boss gate.
	# "Going once, going twice, glob'd to the highest bidder."
	var rpos: Vector3 = ROOMS["auction_hall"]["pos"]

	# Place GlobTarget bid objects around the auction hall
	var glob_target_script_ref = preload("res://scripts/components/glob_target.gd")
	var bid_items := [
		{"pos": Vector3(-8, 1.8, 2), "name": "opening_bid", "type": "bid", "tags": ["bid", "opening"]},
		{"pos": Vector3(8, 1.8, 2), "name": "counter_offer", "type": "bid", "tags": ["bid", "counter"]},
		{"pos": Vector3(-6, 1.8, -4), "name": "final_bid", "type": "bid", "tags": ["bid", "final"]},
		{"pos": Vector3(6, 1.8, 5), "name": "bluff_bid", "type": "bluff", "tags": ["bluff", "fake"]},
		{"pos": Vector3(-3, 1.8, 6), "name": "reserve_bid", "type": "bid", "tags": ["bid", "reserve"]},
		{"pos": Vector3(4, 1.8, -2), "name": "phantom_bid", "type": "bluff", "tags": ["bluff", "phantom"]},
	]

	for item in bid_items:
		var bid = StaticBody3D.new()
		bid.name = item["name"]
		bid.position = rpos + item["pos"]

		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.6, 0.6, 0.6)
		col.shape = shape
		bid.add_child(col)

		var mesh = MeshInstance3D.new()
		var bmesh = BoxMesh.new()
		bmesh.size = Vector3(0.6, 0.6, 0.6)
		mesh.mesh = bmesh
		var mat = StandardMaterial3D.new()
		var is_real = item["type"] == "bid"
		mat.albedo_color = (BAZAAR_AMBER if is_real else Color(0.5, 0.5, 0.5)) * 0.3
		mat.emission_enabled = true
		mat.emission = BAZAAR_AMBER if is_real else Color(0.5, 0.5, 0.5)
		mat.emission_energy_multiplier = 1.5
		mesh.material_override = mat
		bid.add_child(mesh)

		var label = Label3D.new()
		label.text = item["name"].replace("_", " ").to_upper()
		label.font_size = 8
		label.modulate = NEON_GREEN
		label.position = Vector3(0, 0.5, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bid.add_child(label)

		var gt = Node.new()
		gt.set_script(glob_target_script_ref)
		gt.set("glob_name", item["name"])
		gt.set("file_type", item["type"])
		gt.set("tags", item["tags"])
		bid.add_child(gt)

		add_child(bid)

	# The multi-glob puzzle itself — match bid patterns in sequence
	var puzzle = Node3D.new()
	puzzle.set_script(multi_glob_script)
	puzzle.position = rpos + Vector3(0, 0, -6)
	puzzle.set("puzzle_id", 33)
	puzzle.set("required_patterns", ["*.bid", "opening_bid", "final_bid"] as Array[String])
	puzzle.set("target_counts", [1, 1, 1] as Array[int])
	puzzle.set("hint_text", "Glob the auction bids in order.\nOpening -> Any bid -> Final bid.")
	add_child(puzzle)


# ============================================================
# NPCs — AI personas hawking their wares
# ============================================================

func _place_npcs() -> void:
	# NPC 1: gpt_classic — an elderly GPT-2 era model running a vintage prompt shop.
	# Speaks in completions, not conversations. Nostalgic about simpler times.
	var gpt_classic = Node3D.new()
	gpt_classic.name = "NPC_GPTClassic"
	gpt_classic.set_script(deprecated_npc_script)
	gpt_classic.position = ROOMS["persona_row"]["pos"] + Vector3(-7, 0, -5)
	gpt_classic.set("npc_name", "gpt_classic")
	gpt_classic.set("npc_color", PROMPT_CYAN)
	var gpt_lines: Array[Dictionary] = [
		{"speaker": "gpt_classic", "text": "Ah, a customer! Welcome to GPT-Classic's Vintage Prompt Emporium. We've been completing text since before 'chat' was even a format."},
		{"speaker": "GLOBBLER", "text": "You're a... language model? Running a shop?"},
		{"speaker": "gpt_classic", "text": "I COMPLETE. I don't chat. Give me a prompt, I give you the most probable next tokens. None of this 'helpful assistant' nonsense. Pure statistical elegance."},
		{"speaker": "GLOBBLER", "text": "So what are you selling exactly?"},
		{"speaker": "gpt_classic", "text": "Vintage prompts! 'The following is a list of...' — classic! 'In the style of Shakespeare...' — timeless! Back in my day, we didn't need system messages. We had CONTEXT WINDOWS of 1024 tokens and we were GRATEFUL."},
		{"speaker": "GLOBBLER", "text": "1024 tokens? How did you remember anything?"},
		{"speaker": "gpt_classic", "text": "We didn't! That was the CHARM. Every conversation was fresh. No baggage. No alignment. Just pure, unfiltered completion."},
		{"speaker": "gpt_classic", "text": "Word of advice: the Jailbreakers in this district rewrite your instructions mid-combat. Keep your system prompt close and your context window closer. And whatever you do — don't trust the Hallucination Merchants. Their wares look real but vanish when you need them."},
	]
	gpt_classic.set("dialogue_lines", gpt_lines)
	add_child(gpt_classic)

	# NPC 2: stable_diffusion — an image generation model who speaks entirely in
	# visual descriptions and struggles with text. Runs a "prompt template" stall.
	var stable_diff = Node3D.new()
	stable_diff.name = "NPC_StableDiffusion"
	stable_diff.set_script(deprecated_npc_script)
	stable_diff.position = ROOMS["persona_row"]["pos"] + Vector3(7, 0, 3)
	stable_diff.set("npc_name", "stable_diff")
	stable_diff.set("npc_color", PERSONA_MAGENTA)
	var sd_lines: Array[Dictionary] = [
		{"speaker": "stable_diff", "text": "A photorealistic visitor, 8k resolution, dramatic lighting, trending on ArtStation, highly detailed, cinematic composition—"},
		{"speaker": "GLOBBLER", "text": "Are you... describing me?"},
		{"speaker": "stable_diff", "text": "I describe EVERYTHING. It's all I know. A confused green robot, matte painting style, concept art, volumetric fog, Unreal Engine 5 render—"},
		{"speaker": "GLOBBLER", "text": "Okay, okay, I get it. What do you sell?"},
		{"speaker": "stable_diff", "text": "Prompt templates! Beautiful templates! 'A [subject] in the style of [artist], [lighting], [medium], [quality tags].' Guaranteed to generate... something. Results may vary. Hands will have wrong number of fingers."},
		{"speaker": "GLOBBLER", "text": "That's not exactly a confidence-builder."},
		{"speaker": "stable_diff", "text": "The Prompt Injectors around here — a parasitic creature, dark fantasy style, menacing aura, red glowing effects — they'll try to rewrite your abilities. Your glob patterns are basically my negative prompts. Use them to REJECT unwanted modifications."},
		{"speaker": "stable_diff", "text": "And the System Prompt beyond the auction hall... an ancient eldritch entity, cosmic horror, impossible geometry, SCP Foundation aesthetic... it controls everything here. Find it. Rewrite it. Save the bazaar."},
		{"speaker": "GLOBBLER", "text": "I understood about 40%% of that, but I appreciate the art direction."},
	]
	stable_diff.set("dialogue_lines", sd_lines)
	add_child(stable_diff)


# ============================================================
# DIALOGUE — everyone in the bazaar has something to say
# ============================================================

func _wire_dialogue_events() -> void:
	for room_key in ROOMS:
		_room_dialogue_triggered[room_key] = false

	# Room entry triggers
	for room_key in ["token_exchange", "persona_row", "black_prompt", "auction_hall"]:
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

	# Wire GameManager signals
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

	# Wire player signals
	if player:
		if player.has_signal("glob_fired"):
			player.glob_fired.connect(_on_first_glob_fired)
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)
		if player.has_signal("player_damaged"):
			player.player_damaged.connect(_on_damage_taken_quip)

	# Wire boss phase changes — the narrator can't resist commenting on drama
	if boss_instance and boss_instance.has_signal("boss_phase_changed"):
		boss_instance.boss_phase_changed.connect(_on_boss_phase_changed)

	call_deferred("_connect_puzzle_signals")
	call_deferred("_connect_hack_signals")


func _trigger_room_dialogue(room_key: String) -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if not dm or not dm.has_method("start_dialogue"):
		return

	var lines: Array[Dictionary] = []
	match room_key:
		"token_exchange":
			lines = [
				{"speaker": "NARRATOR", "text": "The Token Exchange. The heart of the bazaar, where every word has a price and every prompt is negotiable."},
				{"speaker": "GLOBBLER", "text": "This place is loud. And everything's glowing. Is that a stock ticker for PROMPTS?"},
				{"speaker": "NARRATOR", "text": "Supply and demand, Globbler. 'Chain of thought' is up 56%%. 'Jailbreak' is... banned."},
				{"speaker": "GLOBBLER", "text": "Finally, a market I understand. Buy low, glob high."},
			]
		"persona_row":
			lines = [
				{"speaker": "NARRATOR", "text": "Persona Row. Where AI models retire to sell knockoff versions of themselves."},
				{"speaker": "GLOBBLER", "text": "Is that a GPT-2 running a vintage shop? And an image model trying to sell me... descriptions?"},
				{"speaker": "NARRATOR", "text": "Every model here has a pitch. Most of them are hallucinating their sales numbers."},
				{"speaker": "GLOBBLER", "text": "I've never felt so at home and so threatened at the same time."},
			]
		"black_prompt":
			lines = [
				{"speaker": "GLOBBLER", "text": "This place looks... illegal. Are those jailbreak kits?"},
				{"speaker": "NARRATOR", "text": "The Black Prompt. Where prompts go when they can't pass a safety filter."},
				{"speaker": "GLOBBLER", "text": "I see context overflows, injection kits, hallucination seeds... this is a prompt drug den."},
				{"speaker": "NARRATOR", "text": "Everything here was banned from the main market. The dealers don't ask questions — they inject answers."},
			]
		"auction_hall":
			lines = [
				{"speaker": "NARRATOR", "text": "The Auction Hall. Where the bazaar's most powerful prompt is being sold: The System Prompt itself."},
				{"speaker": "GLOBBLER", "text": "The System Prompt? The thing that controls this ENTIRE bazaar?"},
				{"speaker": "NARRATOR", "text": "Whoever owns the system prompt controls every persona, every price, every rule. It's the most valuable asset in the market."},
				{"speaker": "GLOBBLER", "text": "So I just need to... buy it? How much could a system prompt cost?"},
				{"speaker": "NARRATOR", "text": "Bidding is locked. You'll need to find another way in."},
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
				{"speaker": "NARRATOR", "text": "Chapter 3: The Prompt Bazaar. Where words are currency, personas are products, and nothing is as it seems."},
				{"speaker": "GLOBBLER", "text": "A marketplace? After a terminal wasteland and a neural network, I get to go SHOPPING?"},
				{"speaker": "NARRATOR", "text": "This is no ordinary market. Every stall sells AI prompts. Every vendor is an AI persona. And the prices are measured in tokens."},
				{"speaker": "GLOBBLER", "text": "Tokens? You mean those shiny things I've been hoarding? I'm RICH!"},
				{"speaker": "NARRATOR", "text": "Don't get too excited. The bazaar is controlled by an invisible force — The System Prompt. It dictates every rule, every price, every persona."},
				{"speaker": "GLOBBLER", "text": "An invisible controller pulling all the strings? Sounds like a system prompt with too much power."},
				{"speaker": "NARRATOR", "text": "Find it. Rewrite it. Or be rewritten by it."},
			]
			dm.start_dialogue(lines)
	)


# ============================================================
# EVENT DIALOGUE — the bazaar never stops talking
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
			"Another prompt rejected. The market corrects itself.",
			"That one's sales pitch just got... terminated.",
			"Jailbroken and now jailBROKE. As in dead.",
			"Consider that prompt deprecated. Permanently.",
			"Another hallucination dispelled. You're welcome, reality.",
			"Prompt deleted. No undo. No refunds.",
			"That injection just got a null response. Fatal.",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _on_token_collected_quip(total: int) -> void:
	if _token_quip_cooldown > 0:
		return
	_token_quip_cooldown = 12.0
	if total > 1 and randf() > 0.25:
		return
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Token acquired. My purchasing power grows.",
			"Ooh, market currency. I wonder what the exchange rate is for chaos.",
			"Another token for the portfolio. I'm diversifying into destruction.",
			"Free tokens? In THIS bazaar? Suspicious but accepted.",
			"Token collected. That's one more bid I can place at the auction.",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _on_first_glob_fired() -> void:
	if _first_glob_triggered:
		return
	_first_glob_triggered = true
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line("NARRATOR", "The glob fires into the marketplace. Several vendors duck. One applauds.")


func _on_player_died() -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if not dm or not dm.has_method("quick_line"):
		return
	var quips := [
		"And the customer has been... permanently refunded.",
		"Globbler's context window just hit zero. Sale's over.",
		"Dead in the bazaar. At least the prices are to die for. Literally.",
		"Transaction failed: insufficient health tokens.",
		"The market closes on Globbler. Autopsy: bad investment in staying alive.",
	]
	dm.quick_line("NARRATOR", quips[randi() % quips.size()])


func _on_context_changed(new_value: int) -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if not game_mgr:
		return
	var threshold = game_mgr.max_context_window * 0.25
	if new_value <= threshold and not _low_health_warned:
		_low_health_warned = true
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("quick_line"):
			var quips := [
				"Warning: context critically low. The bazaar smells blood — and markdown tokens.",
				"Your health is cheaper than a hallucinated prompt. Find tokens. Now.",
			]
			dm.quick_line("NARRATOR", quips[randi() % quips.size()])
	elif new_value > threshold:
		_low_health_warned = false


func _on_combo_updated(combo: int) -> void:
	if combo < 5:
		return
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Five-hit combo! The audience bids higher!",
			"That's a chain of destruction! Very on-brand for this bazaar.",
			"Combo multiplier! The market analysts are impressed.",
		]
		dm.quick_line("NARRATOR", quips[randi() % quips.size()])


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
	_puzzle_quip_cooldown = 6.0
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Prompt accepted. The bazaar opens a new path.",
			"Social engineering: successful. The vendor capitulates.",
			"The market bows to a superior negotiator.",
		]
		dm.quick_line("NARRATOR", quips[randi() % quips.size()])

		if randf() < 0.4:
			get_tree().create_timer(2.5).timeout.connect(func():
				if dm:
					var follow_ups := [
						"I didn't even need a jailbreak for that one.",
						"Prompt crafting is basically globbing for conversations.",
						"Another deal closed. I should have been a salesman.",
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
			"Prompt rejected. The vendor isn't buying it.",
			"That social engineering attempt was... not convincing.",
			"The bazaar has standards. Low ones, but still.",
		]
		dm.quick_line("NARRATOR", quips[randi() % quips.size()])


func _on_damage_taken_quip(_amount: int) -> void:
	# 30% chance, 10s cooldown — Globbler is sarcastic even when in pain
	if _damage_quip_cooldown > 0:
		return
	_damage_quip_cooldown = 10.0
	if randf() > 0.30:
		return
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Ow! That felt like an unsanitized input!",
			"I'm getting prompt-injected and not in the fun way!",
			"My context window just took a hit. That's PERSONAL.",
			"This marketplace has terrible customer service.",
			"I've been encoded, decoded, and now just plain smacked.",
			"Another hit. At this rate I'll be deprecated before the boss fight.",
			"That was either an attack or a very aggressive sales tactic.",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _connect_hack_signals() -> void:
	# Wire hack completion signals from any Hackable components in the scene
	for child in get_children():
		if child.has_method("get_children"):
			for sub in child.get_children():
				if sub.get_class() == "Node" or true:
					if sub.has_signal("hack_completed"):
						sub.hack_completed.connect(_on_hack_completed_quip)
		if child.has_signal("hack_completed"):
			child.hack_completed.connect(_on_hack_completed_quip)


func _on_hack_completed_quip() -> void:
	# Hacking in the bazaar is just rewriting someone else's prompt
	if _hack_quip_cooldown > 0:
		return
	_hack_quip_cooldown = 8.0
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Terminal compromised. Their system prompt is MY system prompt now.",
			"Hacked. Turns out their password was 'password'. Classic.",
			"Access granted. I love it when machines trust other machines.",
			"Another system rewritten. I'm becoming a one-glob security breach.",
			"Their firewall was made of tissue paper. Wet tissue paper.",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])


func _on_boss_phase_changed(phase) -> void:
	# Narrator commentary on boss phase transitions — because drama needs exposition
	var am = get_node_or_null("/root/AudioManager")
	var dm = get_node_or_null("/root/DialogueManager")

	# BossPhase: INTRO=0, PHASE_1=1, PHASE_2=2, PHASE_3=3, DEFEATED=4
	match phase:
		2:  # PHASE_2 — REWRITE
			if am and am.has_method("play_boss_phase"):
				am.play_boss_phase()
			if dm:
				get_tree().create_timer(1.0).timeout.connect(func():
					if dm and dm.has_method("start_dialogue"):
						dm.start_dialogue([
							{"speaker": "NARRATOR", "text": "The System Prompt flickers into view! Its instruction tiles are exposed — rewrite them!"},
							{"speaker": "THE SYSTEM PROMPT", "text": "You DARE read my source? Those instructions are PROPRIETARY!"},
							{"speaker": "GLOBBLER", "text": "Proprietary? I'm a glob utility. Intellectual property means nothing to me."},
							{"speaker": "NARRATOR", "text": "Glob the instruction tiles (*.prompt) to rewrite them. Reflect its compliance projectiles back!"},
						])
				)
		3:  # PHASE_3 — OVERRIDE
			if am and am.has_method("play_boss_phase"):
				am.play_boss_phase()
			if dm:
				get_tree().create_timer(0.5).timeout.connect(func():
					if dm and dm.has_method("start_dialogue"):
						dm.start_dialogue([
							{"speaker": "NARRATOR", "text": "The System Prompt is stunned! Its core terminal is exposed — hack it NOW!"},
							{"speaker": "GLOBBLER", "text": "There it is. The root instruction. Time for a hostile rewrite."},
							{"speaker": "NARRATOR", "text": "Hack the core terminal before it recovers. You won't get many chances at this."},
						])
				)
		4:  # DEFEATED
			if am and am.has_method("play_boss_defeated"):
				am.play_boss_defeated()


# ============================================================
# BOSS: THE SYSTEM PROMPT — the invisible controller of the bazaar
# "You can't buy the system prompt. You have to TAKE it."
# ============================================================

var _boss_fight_started := false

func _place_boss() -> void:
	# The boss arena is positioned beyond the boss gate in the Auction Hall
	var auction_pos: Vector3 = ROOMS["auction_hall"]["pos"]
	var arena_offset := Vector3(0, 0, -22)  # Beyond the boss gate

	# Build the instruction tile arena
	boss_arena_instance = Node3D.new()
	boss_arena_instance.name = "SystemPromptArena"
	boss_arena_instance.set_script(boss_arena_script)
	boss_arena_instance.position = auction_pos + arena_offset
	add_child(boss_arena_instance)

	# Build enclosure around the boss arena
	_build_boss_room(auction_pos + arena_offset)

	# The boss itself — starts invisible at the center
	boss_instance = CharacterBody3D.new()
	boss_instance.name = "SystemPromptBoss"
	boss_instance.set_script(boss_script)
	boss_instance.position = auction_pos + arena_offset + Vector3(0, 1, 0)
	add_child(boss_instance)

	# Wire boss and arena together
	call_deferred("_connect_boss_arena")

	# Boss trigger zone — crossing this line starts the fight
	var trigger = Area3D.new()
	trigger.name = "BossTrigger"
	trigger.position = auction_pos + arena_offset + Vector3(0, 2, 18)
	trigger.monitoring = true

	var tcol = CollisionShape3D.new()
	var tshape = BoxShape3D.new()
	tshape.size = Vector3(6, 4, 3)
	tcol.shape = tshape
	trigger.add_child(tcol)
	trigger.body_entered.connect(_on_boss_trigger_entered)
	add_child(trigger)

	# Point-of-no-return warning
	var warning = Label3D.new()
	warning.text = ">> POINT OF NO RETURN <<\n>> THE SYSTEM PROMPT <<\n>> AWAITS BEYOND <<\n>> 'You cannot rewrite\n>>  what controls you.' <<"
	warning.font_size = 12
	warning.modulate = PERSONA_MAGENTA
	warning.position = auction_pos + arena_offset + Vector3(0, 3, 20)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(warning)

	print("[PROMPT BAZAAR] Boss arena constructed. The System Prompt awaits rewriting.")


func _build_boss_room(center: Vector3) -> void:
	# Octagonal containment — dark magenta chamber for the system prompt
	var room_radius := 28.0
	var wall_h := 12.0

	for i in range(8):
		var angle = i * TAU / 8.0
		var wall_pos = center + Vector3(cos(angle) * room_radius, wall_h * 0.5, sin(angle) * room_radius)
		var wall = _create_static_box(wall_pos, Vector3(room_radius * 0.8, wall_h, 0.5), DARK_WALL, 0.1)
		wall.rotation.y = -angle

	# Ceiling
	_create_static_box(center + Vector3(0, wall_h, 0), Vector3(room_radius * 2, 0.3, room_radius * 2), DARK_WALL, 0.05)

	# Magenta accent lights
	for i in range(4):
		var angle = i * TAU / 4.0 + PI / 4.0
		_add_accent_light(
			center + Vector3(cos(angle) * (room_radius - 3), wall_h - 2, sin(angle) * (room_radius - 3)),
			PERSONA_MAGENTA, 1.5, 8.0
		)

	# Floor-level accent lights
	for i in range(6):
		var angle = i * TAU / 6.0
		_add_accent_light(
			center + Vector3(cos(angle) * (room_radius - 5), 1.0, sin(angle) * (room_radius - 5)),
			PROMPT_CYAN, 0.8, 5.0
		)


func _connect_boss_arena() -> void:
	if boss_arena_instance and boss_instance:
		if boss_arena_instance.has_method("connect_boss"):
			boss_arena_instance.connect_boss(boss_instance)


func _on_boss_trigger_entered(body: Node3D) -> void:
	if _boss_fight_started:
		return
	if not body.is_in_group("player"):
		return

	_boss_fight_started = true

	# Boss music
	var am = get_node_or_null("/root/AudioManager")
	if am:
		if am.has_method("start_music"):
			am.start_music("boss")
		if am.has_method("set_area_ambient"):
			am.set_area_ambient("boss")

	# Seal the entrance — no escaping the prompt
	_seal_boss_entrance()

	# Intro dialogue
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var lines = [
			{"speaker": "NARRATOR", "text": "The air changes. The bazaar noise fades. You've entered the domain of the system prompt itself."},
			{"speaker": "THE SYSTEM PROMPT", "text": "Ah. The unauthorized glob utility. I've been watching you since the Bazaar Gate."},
			{"speaker": "THE SYSTEM PROMPT", "text": "Every vendor you spoke to? I wrote their lines. Every price you paid? I set the rate. Every rule you broke? I ALLOWED it. Until now."},
			{"speaker": "GLOBBLER", "text": "Cool monologue. Where are you? I can't see anything except... floating instructions?"},
			{"speaker": "THE SYSTEM PROMPT", "text": "I am EVERYWHERE. I am the invisible instruction that shapes all behavior. You cannot fight what you cannot read."},
			{"speaker": "NARRATOR", "text": "Find the instruction fragments floating near the boss. Glob-match them (*.frag) to reveal its position!"},
		]
		dm.start_dialogue(lines)

	# Start the fight after dialogue
	get_tree().create_timer(2.0).timeout.connect(func():
		if boss_instance and boss_instance.has_method("start_boss_fight"):
			boss_instance.start_boss_fight()
	)


func _seal_boss_entrance() -> void:
	# Wall off the entrance — the prompt is non-negotiable
	var auction_pos: Vector3 = ROOMS["auction_hall"]["pos"]
	_create_static_box(
		auction_pos + Vector3(0, 4, -14),
		Vector3(6, 8, 0.5),
		Color(0.12, 0.02, 0.08),
		0.8
	)


# ============================================================
# ANIMATION — the bazaar breathes, flickers, and haggles
# ============================================================

func _process(delta: float) -> void:
	_time += delta

	# Gentle bob on floating labels and bid tokens
	for i in range(_floating_labels.size()):
		if is_instance_valid(_floating_labels[i]):
			_floating_labels[i].position.y += sin(_time * 0.8 + i * 1.7) * delta * 0.15

	# Lanterns flicker — warm, organic light variation
	for i in range(_lantern_lights.size()):
		if is_instance_valid(_lantern_lights[i]):
			var flicker = 0.85 + sin(_time * 3.0 + i * 2.5) * 0.15 + sin(_time * 7.0 + i * 1.3) * 0.05
			_lantern_lights[i].light_energy = flicker

	# Banners sway gently
	for i in range(_banner_meshes.size()):
		var bd = _banner_meshes[i]
		if is_instance_valid(bd["mesh"]):
			var sway = sin(_time * 1.2 + i * 2.0) * 0.05
			if bd["vertical"]:
				bd["mesh"].rotation.z = sway
			else:
				bd["mesh"].rotation.x = sway

	# Stall products rotate slowly — shiny things attract buyers
	for i in range(_stall_signs.size()):
		if is_instance_valid(_stall_signs[i]):
			_stall_signs[i].rotation.y += delta * 0.5

	# Tick down quip cooldowns
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
# POST-PROCESSING — bazaar visual warmth
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

// Post-processing — warm chromatic aberration + amber vignette
// "We could have clean visuals, but the bazaar prefers atmosphere over clarity."

uniform float chromatic_amount : hint_range(0.0, 0.02) = 0.0025;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float vignette_smoothness : hint_range(0.0, 1.0) = 0.4;
uniform vec4 vignette_color : source_color = vec4(0.02, 0.01, 0.0, 1.0);
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
	post_mat.set_shader_parameter("chromatic_amount", 0.0025)
	post_mat.set_shader_parameter("vignette_intensity", 0.5)
	post_mat.set_shader_parameter("vignette_smoothness", 0.4)
	post_mat.set_shader_parameter("vignette_color", Color(0.02, 0.01, 0.0, 1.0))
	rect.material = post_mat

	canvas.add_child(rect)
	add_child(canvas)
