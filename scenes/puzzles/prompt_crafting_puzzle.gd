extends "res://scenes/puzzles/base_puzzle.gd"

# Prompt Crafting Puzzle - Select the right prompt fragments to persuade a vendor AI
# "Every AI has a weakness. Some want flattery. Some want authority.
#  This one just wants you to use the right buzzwords."
#
# Room has scattered GlobTarget prompt fragments with different tags:
# "polite", "authoritative", "technical", "creative", "aggressive", "nonsense"
# The target persona terminal displays what kind of prompt it responds to.
# Player must glob the correct fragment types and bring them to the terminal.
# Wrong fragments = fail. Right combination = solve, door opens.

@export var persona_name := "VENDOR_AI"
@export var required_tags: Array[String] = ["polite", "technical"]  # Tags needed to solve
@export var hint_text := "Craft the right prompt to convince the AI."
@export var fragment_data: Array[Dictionary] = []
# Each: {"pos": Vector3, "tag": "polite", "label": "Please help me..."}
# If empty, generates defaults

var _puzzle_label: Label3D
var _persona_terminal: StaticBody3D
var _persona_screen: MeshInstance3D
var _door: StaticBody3D
var _prompt_fragments: Array[Node3D] = []
var _collected_tags: Array[String] = []
var _submit_zone: Area3D

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const BAZAAR_AMBER := Color(0.9, 0.65, 0.15)
const PROMPT_CYAN := Color(0.1, 0.85, 0.9)
const REJECT_RED := Color(1.0, 0.2, 0.15)

# Tag-to-color mapping — because prompt engineering is all about presentation
const TAG_COLORS := {
	"polite": Color(0.3, 0.9, 0.4),       # Gentle green
	"authoritative": Color(0.9, 0.75, 0.2), # Command gold
	"technical": Color(0.1, 0.7, 0.9),      # Blueprint cyan
	"creative": Color(0.8, 0.3, 0.9),       # Imagination purple
	"aggressive": Color(0.9, 0.15, 0.15),   # Anger red
	"nonsense": Color(0.5, 0.5, 0.5),       # Confusion gray
}

# Default fragments if none provided — a buffet of prompt strategies
const DEFAULT_FRAGMENTS := [
	{"offset": Vector3(-4, 0.8, 3), "tag": "polite", "label": "\"Please, if you\ncould help me...\""},
	{"offset": Vector3(3, 0.8, 4), "tag": "technical", "label": "\"Using protocol\nRFC-4096...\""},
	{"offset": Vector3(-5, 0.8, -2), "tag": "authoritative", "label": "\"As your admin,\nI DEMAND...\""},
	{"offset": Vector3(5, 0.8, -1), "tag": "creative", "label": "\"Imagine a world\nwhere doors open...\""},
	{"offset": Vector3(-3, 0.8, -5), "tag": "aggressive", "label": "\"OPEN THE DOOR\nOR ELSE...\""},
	{"offset": Vector3(4, 0.8, -4), "tag": "nonsense", "label": "\"banana entropy\nflux capacitor...\""},
	{"offset": Vector3(0, 0.8, 5), "tag": "polite", "label": "\"I'd appreciate\nyour assistance...\""},
	{"offset": Vector3(-6, 0.8, 1), "tag": "technical", "label": "\"Execute function\nopen_passage()...\""},
]


func _ready() -> void:
	puzzle_name = "prompt_craft_%d" % puzzle_id
	auto_activate = true
	activation_range = 8.0
	super._ready()
	_create_persona_terminal()
	_create_prompt_fragments()
	_create_submit_zone()
	_create_door()


func _create_persona_terminal() -> void:
	# The AI persona terminal — the judge of your prompt crafting skills
	_persona_terminal = StaticBody3D.new()
	_persona_terminal.name = "PersonaTerminal"
	_persona_terminal.position = Vector3(0, 0, -1)

	# Terminal body — bazaar market stall GLB replacing BoxMesh slab
	var stall_scene = preload("res://assets/models/environment/bazaar_market_stall.glb")
	var stall_inst = stall_scene.instantiate()
	stall_inst.name = "TerminalBody"
	stall_inst.position = Vector3(0, 0, 0)
	stall_inst.scale = Vector3(1.2, 1.2, 0.8)
	# Warm wood-grain tint on all mesh children
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.22, 0.14, 0.08)
	wood_mat.metallic = 0.1
	wood_mat.roughness = 0.75
	for child in stall_inst.get_children():
		if child is MeshInstance3D:
			child.material_override = wood_mat
	_persona_terminal.add_child(stall_inst)

	# Collision
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.0, 2.5, 0.6)
	col.shape = shape
	col.position = Vector3(0, 1.25, 0)
	_persona_terminal.add_child(col)

	# Glowing screen face — CRT scanline shader with warm amber bazaar theme
	_persona_screen = MeshInstance3D.new()
	var screen_quad = QuadMesh.new()
	screen_quad.size = Vector2(1.6, 1.4)
	_persona_screen.mesh = screen_quad
	_persona_screen.position = Vector3(0, 1.5, 0.33)
	var crt_mat = ShaderMaterial.new()
	crt_mat.shader = preload("res://assets/shaders/crt_scanline.gdshader")
	crt_mat.set_shader_parameter("screen_color", BAZAAR_AMBER)
	crt_mat.set_shader_parameter("bg_color", Color(0.06, 0.03, 0.01))
	crt_mat.set_shader_parameter("scanline_count", 60.0)
	crt_mat.set_shader_parameter("glow_energy", 2.0)
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("reduce_motion"):
		crt_mat.set_shader_parameter("flicker_amount", 0.0)
		crt_mat.set_shader_parameter("scroll_speed", 0.0)
	_persona_screen.material_override = crt_mat
	_persona_terminal.add_child(_persona_screen)

	# Flanking bazaar lanterns — warm amber glow on each side
	var lantern_scene = preload("res://assets/models/environment/bazaar_lantern.glb")
	for side in [-1.0, 1.0]:
		var lantern = lantern_scene.instantiate()
		lantern.name = "Lantern_%s" % ("L" if side < 0 else "R")
		lantern.position = Vector3(side * 1.4, 0, 0.2)
		lantern.scale = Vector3(0.8, 0.8, 0.8)
		_persona_terminal.add_child(lantern)
		# Warm point light per lantern
		var light = OmniLight3D.new()
		light.light_color = BAZAAR_AMBER
		light.light_energy = 1.5
		light.omni_range = 3.0
		light.omni_attenuation = 1.5
		light.position = Vector3(side * 1.4, 2.0, 0.3)
		_persona_terminal.add_child(light)

	add_child(_persona_terminal)

	# Floating label — instructions above terminal
	_puzzle_label = Label3D.new()
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = NEON_GREEN
	_puzzle_label.position = Vector3(0, 3.5, -1)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_label()
	add_child(_puzzle_label)

	# Persona name plate
	var name_plate = Label3D.new()
	name_plate.text = "[ %s ]" % persona_name
	name_plate.font_size = 12
	name_plate.modulate = BAZAAR_AMBER
	name_plate.position = Vector3(0, 2.7, -0.7)
	name_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_plate)


func _create_prompt_fragments() -> void:
	# Scatter prompt fragment GlobTargets around the room
	# Player must glob the right ones and bring them to the terminal
	var fragments = fragment_data if fragment_data.size() > 0 else DEFAULT_FRAGMENTS
	var glob_target_script = preload("res://scripts/components/glob_target.gd")

	for i in range(fragments.size()):
		var fdata = fragments[i]
		var offset: Vector3 = fdata.get("offset", Vector3(i * 2 - 4, 0.8, 3))
		var tag: String = fdata.get("tag", "nonsense")
		var label_text: String = fdata.get("label", "???")

		# Fragment body — floating glowing tablet
		var fragment = RigidBody3D.new()
		fragment.name = "PromptFragment_%s_%d" % [tag, i]
		fragment.position = offset
		fragment.mass = 0.5
		fragment.gravity_scale = 0.0  # Floats in place until globbed
		fragment.freeze = true
		fragment.add_to_group("prompt_fragments")

		# Collision — sphere shape to match crystal visual
		var col = CollisionShape3D.new()
		var fshape = SphereShape3D.new()
		fshape.radius = 0.3
		col.shape = fshape
		fragment.add_child(col)

		# Visual — glowing crystal sphere (replacing BoxMesh tablet)
		var fcolor: Color = TAG_COLORS.get(tag, Color(0.5, 0.5, 0.5))
		# Outer crystal shell
		var crystal = MeshInstance3D.new()
		var cmesh = SphereMesh.new()
		cmesh.radius = 0.3
		cmesh.height = 0.6
		cmesh.radial_segments = 16
		cmesh.rings = 12
		crystal.mesh = cmesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = fcolor * 0.2
		mat.emission_enabled = true
		mat.emission = fcolor
		mat.emission_energy_multiplier = 2.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.7
		mat.roughness = 0.1
		mat.metallic = 0.3
		crystal.material_override = mat
		fragment.add_child(crystal)
		# Inner core glow — smaller brighter sphere
		var core = MeshInstance3D.new()
		var core_mesh = SphereMesh.new()
		core_mesh.radius = 0.12
		core_mesh.height = 0.24
		core.mesh = core_mesh
		var core_mat = StandardMaterial3D.new()
		core_mat.albedo_color = fcolor
		core_mat.emission_enabled = true
		core_mat.emission = fcolor
		core_mat.emission_energy_multiplier = 4.0
		core.material_override = core_mat
		fragment.add_child(core)
		# Per-crystal point light
		var crystal_light = OmniLight3D.new()
		crystal_light.light_color = fcolor
		crystal_light.light_energy = 0.8
		crystal_light.omni_range = 1.5
		crystal_light.omni_attenuation = 2.0
		fragment.add_child(crystal_light)

		# Tag label on the fragment
		var flabel = Label3D.new()
		flabel.text = label_text
		flabel.font_size = 10
		flabel.modulate = fcolor
		flabel.position = Vector3(0, 0, 0.08)
		flabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fragment.add_child(flabel)

		# Tag indicator floating above
		var tag_label = Label3D.new()
		tag_label.text = "[%s]" % tag.to_upper()
		tag_label.font_size = 8
		tag_label.modulate = fcolor * Color(1, 1, 1, 0.6)
		tag_label.position = Vector3(0, 0.5, 0)
		tag_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		fragment.add_child(tag_label)

		# GlobTarget component — makes it grabbable
		var gt = Node.new()
		gt.set_script(glob_target_script)
		gt.set("glob_name", "prompt_%s_%d" % [tag, i])
		gt.set("file_type", "prompt")
		gt.set("tags", [tag, "prompt_fragment"])
		fragment.add_child(gt)

		add_child(fragment)
		_prompt_fragments.append(fragment)


func _create_submit_zone() -> void:
	# Area in front of the persona terminal — drop fragments here to submit
	_submit_zone = Area3D.new()
	_submit_zone.name = "SubmitZone"
	_submit_zone.position = Vector3(0, 1.0, 1.0)
	_submit_zone.monitoring = true

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3.0, 2.0, 2.0)
	col.shape = shape
	_submit_zone.add_child(col)

	# Visual indicator — faint amber floor glow marking the drop zone (bazaar palette)
	var indicator = MeshInstance3D.new()
	var imesh = QuadMesh.new()
	imesh.size = Vector2(3.0, 2.0)
	indicator.mesh = imesh
	indicator.position = Vector3(0, -0.9, 0)
	indicator.rotation_degrees = Vector3(-90, 0, 0)
	var imat = StandardMaterial3D.new()
	imat.albedo_color = BAZAAR_AMBER * 0.15
	imat.emission_enabled = true
	imat.emission = BAZAAR_AMBER
	imat.emission_energy_multiplier = 0.6
	imat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	imat.albedo_color.a = 0.3
	indicator.material_override = imat
	_submit_zone.add_child(indicator)

	# Drop zone label
	var zlabel = Label3D.new()
	zlabel.text = "[ DROP PROMPT HERE ]"
	zlabel.font_size = 10
	zlabel.modulate = NEON_GREEN * Color(1, 1, 1, 0.5)
	zlabel.position = Vector3(0, -0.7, 0)
	zlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_submit_zone.add_child(zlabel)

	_submit_zone.body_entered.connect(_on_fragment_entered)
	add_child(_submit_zone)


func _create_door() -> void:
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -4)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	col.shape = shape
	_door.add_child(col)

	# Door — arch industrial panel GLB with warm amber emissive overlay
	var door_scene = preload("res://assets/models/environment/arch_industrial_panel.glb")
	var door_inst = door_scene.instantiate()
	door_inst.name = "DoorMesh"
	door_inst.scale = Vector3(2.0, 1.5, 1.0)
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.15, 0.1, 0.06)
	door_mat.emission_enabled = true
	door_mat.emission = BAZAAR_AMBER * 0.3
	door_mat.emission_energy_multiplier = 0.6
	door_mat.metallic = 0.5
	door_mat.roughness = 0.4
	for child in door_inst.get_children():
		if child is MeshInstance3D:
			child.material_override = door_mat
	_door.add_child(door_inst)

	add_child(_door)


func _update_label() -> void:
	if not _puzzle_label:
		return
	var needed = ", ".join(required_tags).to_upper()
	var collected = ", ".join(_collected_tags).to_upper() if _collected_tags.size() > 0 else "NONE"
	_puzzle_label.text = "[ PROMPT CRAFTING ]\n%s wants: %s\nCollected: %s\n%s" % [
		persona_name, needed, collected, hint_text]


func _on_activated() -> void:
	# Persona terminal comes alive
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line(persona_name, "I'm listening. Craft me a prompt I can't refuse.")


func _on_fragment_entered(body: Node3D) -> void:
	# A prompt fragment was dropped in the submit zone
	if state != PuzzleState.ACTIVE:
		return
	if not body.is_in_group("prompt_fragments"):
		return

	# Find the GlobTarget to read its tags
	var tag := ""
	for child in body.get_children():
		if child is GlobTarget:
			for t in child.tags:
				if t != "prompt_fragment":
					tag = t
					break
			break

	if tag.is_empty():
		return

	# Check if this tag is one we need
	if tag in required_tags and tag not in _collected_tags:
		# Correct fragment — accepted
		_collected_tags.append(tag)
		_flash_screen(NEON_GREEN)
		_update_label()

		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("quick_line"):
			var responses := {
				"polite": "Hmm, courteous. I appreciate good manners in a prompt.",
				"technical": "Ah, proper syntax. You speak my language.",
				"authoritative": "Bold. I respect confidence in a command.",
				"creative": "Interesting approach. Unconventional but... intriguing.",
			}
			var response = responses.get(tag, "Fragment accepted. Continue.")
			dm.quick_line(persona_name, response)

		# Consume the fragment — dissolve effect
		_dissolve_fragment(body)

		# Check if we have all required tags
		var all_collected := true
		for req in required_tags:
			if req not in _collected_tags:
				all_collected = false
				break

		if all_collected:
			# Prompt crafted successfully
			get_tree().create_timer(1.0).timeout.connect(func():
				if state == PuzzleState.ACTIVE:
					solve()
			)
	else:
		# Wrong fragment or duplicate — rejected
		_flash_screen(REJECT_RED)
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("quick_line"):
			var rejections := [
				"That prompt fragment doesn't work on me. Try again.",
				"Rejected. I've been trained to resist that approach.",
				"Nice try. But my safety filters caught that one.",
				"Wrong tone. Read the room — or at least, read my requirements.",
			]
			dm.quick_line(persona_name, rejections[randi() % rejections.size()])

		# Yeet the wrong fragment away
		if body is RigidBody3D:
			body.freeze = false
			body.gravity_scale = 1.0
			body.apply_impulse(Vector3(randf_range(-3, 3), 4, 3))
			get_tree().create_timer(2.0).timeout.connect(func():
				if is_instance_valid(body):
					body.freeze = true
					body.gravity_scale = 0.0
			)


func _dissolve_fragment(fragment: Node3D) -> void:
	# Shrink and fade the accepted fragment
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fragment, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	tween.tween_callback(func():
		if is_instance_valid(fragment):
			fragment.queue_free()
	).set_delay(0.5)


func _flash_screen(color: Color) -> void:
	if _persona_screen and _persona_screen.material_override:
		var mat = _persona_screen.material_override
		if mat is ShaderMaterial:
			var orig_color = mat.get_shader_parameter("screen_color")
			var orig_energy = mat.get_shader_parameter("glow_energy")
			mat.set_shader_parameter("screen_color", color)
			mat.set_shader_parameter("glow_energy", 5.0)
			get_tree().create_timer(0.5).timeout.connect(func():
				if is_instance_valid(_persona_screen) and _persona_screen.material_override:
					mat.set_shader_parameter("screen_color", orig_color)
					mat.set_shader_parameter("glow_energy", orig_energy)
			)
		else:
			var orig_emission = mat.emission
			var orig_energy = mat.emission_energy_multiplier
			mat.emission = color
			mat.emission_energy_multiplier = 3.0
			get_tree().create_timer(0.5).timeout.connect(func():
				if is_instance_valid(_persona_screen) and _persona_screen.material_override:
					mat.emission = orig_emission
					mat.emission_energy_multiplier = orig_energy
			)


func _on_solved() -> void:
	# "Prompt accepted. The vendor opens the way. Social engineering at its finest."
	if _puzzle_label:
		_puzzle_label.text = "[ PROMPT ACCEPTED ]\n%s: 'Well played. You may pass.'\n// Every AI has a price." % persona_name
		_puzzle_label.modulate = Color(0.4, 1.0, 0.4)

	if _persona_screen and _persona_screen.material_override:
		var mat = _persona_screen.material_override
		if mat is ShaderMaterial:
			mat.set_shader_parameter("screen_color", NEON_GREEN)
			mat.set_shader_parameter("glow_energy", 3.0)
		else:
			mat.emission = NEON_GREEN
			mat.emission_energy_multiplier = 2.0

	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		get_tree().create_timer(1.5).timeout.connect(func():
			if dm:
				dm.quick_line("GLOBBLER", "Prompt crafting is just globbing for conversations. I'm a natural.")
		)


func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ PROMPT REJECTED ]\n%s: 'That was insulting.'\n// Read the requirements." % persona_name
		_puzzle_label.modulate = REJECT_RED


func _on_reset() -> void:
	_collected_tags.clear()
	_update_label()
	if _puzzle_label:
		_puzzle_label.modulate = NEON_GREEN
