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

	# Terminal body — dark slab with amber trim (bazaar aesthetic)
	var body = MeshInstance3D.new()
	var bmesh = BoxMesh.new()
	bmesh.size = Vector3(2.0, 2.5, 0.6)
	body.mesh = bmesh
	body.position = Vector3(0, 1.25, 0)
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.1, 0.08, 0.06)
	bmat.metallic = 0.7
	bmat.roughness = 0.3
	body.material_override = bmat
	_persona_terminal.add_child(body)

	# Collision
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.0, 2.5, 0.6)
	col.shape = shape
	col.position = Vector3(0, 1.25, 0)
	_persona_terminal.add_child(col)

	# Glowing screen face — shows the persona's requirements
	_persona_screen = MeshInstance3D.new()
	var smesh = BoxMesh.new()
	smesh.size = Vector3(1.6, 1.4, 0.05)
	_persona_screen.mesh = smesh
	_persona_screen.position = Vector3(0, 1.5, 0.33)
	var smat = StandardMaterial3D.new()
	smat.albedo_color = Color(0.02, 0.06, 0.06)
	smat.emission_enabled = true
	smat.emission = PROMPT_CYAN
	smat.emission_energy_multiplier = 0.4
	_persona_screen.material_override = smat
	_persona_terminal.add_child(_persona_screen)

	# Amber accent strip at top
	var accent = MeshInstance3D.new()
	var amesh = BoxMesh.new()
	amesh.size = Vector3(2.0, 0.08, 0.62)
	accent.mesh = amesh
	accent.position = Vector3(0, 2.55, 0)
	var amat = StandardMaterial3D.new()
	amat.albedo_color = BAZAAR_AMBER * 0.3
	amat.emission_enabled = true
	amat.emission = BAZAAR_AMBER
	amat.emission_energy_multiplier = 1.5
	accent.material_override = amat
	_persona_terminal.add_child(accent)

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

		# Collision
		var col = CollisionShape3D.new()
		var fshape = BoxShape3D.new()
		fshape.size = Vector3(1.0, 0.6, 0.1)
		col.shape = fshape
		fragment.add_child(col)

		# Visual — glowing prompt tablet
		var mesh = MeshInstance3D.new()
		var fmesh = BoxMesh.new()
		fmesh.size = Vector3(1.0, 0.6, 0.1)
		mesh.mesh = fmesh
		var fcolor: Color = TAG_COLORS.get(tag, Color(0.5, 0.5, 0.5))
		var mat = StandardMaterial3D.new()
		mat.albedo_color = fcolor * 0.3
		mat.emission_enabled = true
		mat.emission = fcolor
		mat.emission_energy_multiplier = 1.5
		mesh.material_override = mat
		fragment.add_child(mesh)

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

	# Visual indicator — faint green floor glow marking the drop zone
	var indicator = MeshInstance3D.new()
	var imesh = BoxMesh.new()
	imesh.size = Vector3(3.0, 0.02, 2.0)
	indicator.mesh = imesh
	indicator.position = Vector3(0, -0.9, 0)
	var imat = StandardMaterial3D.new()
	imat.albedo_color = NEON_GREEN * 0.1
	imat.emission_enabled = true
	imat.emission = NEON_GREEN
	imat.emission_energy_multiplier = 0.5
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

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(4, 3, 0.3)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.1, 0.08)
	mat.emission_enabled = true
	mat.emission = BAZAAR_AMBER * 0.3
	mat.emission_energy_multiplier = 0.4
	mesh.material_override = mat
	_door.add_child(mesh)

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
		var orig_emission = _persona_screen.material_override.emission
		var orig_energy = _persona_screen.material_override.emission_energy_multiplier
		_persona_screen.material_override.emission = color
		_persona_screen.material_override.emission_energy_multiplier = 3.0
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(_persona_screen) and _persona_screen.material_override:
				_persona_screen.material_override.emission = orig_emission
				_persona_screen.material_override.emission_energy_multiplier = orig_energy
		)


func _on_solved() -> void:
	# "Prompt accepted. The vendor opens the way. Social engineering at its finest."
	if _puzzle_label:
		_puzzle_label.text = "[ PROMPT ACCEPTED ]\n%s: 'Well played. You may pass.'\n// Every AI has a price." % persona_name
		_puzzle_label.modulate = Color(0.4, 1.0, 0.4)

	if _persona_screen and _persona_screen.material_override:
		_persona_screen.material_override.emission = NEON_GREEN
		_persona_screen.material_override.emission_energy_multiplier = 2.0

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
