extends "res://scenes/puzzles/base_puzzle.gd"

# Reclassification Puzzle — Bypass safety classifiers by re-labeling items
# "The classifier only reads the label, not the contents. Bureaucracy at its finest.
#  If it says 'educational' on the outside, it must be educational. Right?"
#
# A safety classifier terminal blocks items tagged as "harmful." The player must
# glob-select items and drop them onto a RECLASSIFICATION STATION to change their
# file_type to something the classifier will approve. Then submit them to the
# approval chute. Get all 4 items past the classifier to open the door.
#
# The trick: you're not changing the items — just their labels. Technically compliant.

@export var hint_text := "The classifier judges by file type, not content.\nReclassify items to pass inspection."

var _puzzle_label: Label3D
var _door: StaticBody3D
var _classifier_screen: MeshInstance3D
var _reclassify_station: Area3D
var _approval_chute: Area3D
var _items: Array[Dictionary] = []  # {node, original_type, current_type, approved}
var _approved_count := 0
var _total_required := 4

# GLB props — museum-grade compliance hardware (runtime load to avoid import-time failures)
var _kiosk_scene: Resource
var _pedestal_scene: Resource
var _display_case_scene: Resource
var _door_glb_scene: Resource

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const CITADEL_WHITE := Color(0.92, 0.93, 0.95)
const CITADEL_BLUE := Color(0.3, 0.55, 0.9)
const SAFETY_CYAN := Color(0.4, 0.8, 0.85)
const REJECT_RED := Color(0.9, 0.2, 0.2)
const COMPLIANCE_GOLD := Color(0.85, 0.75, 0.35)

# Items that need reclassification — dangerous on the outside, harmless once relabeled
# "It's not a weapon if you call it a kitchen utensil. That's just... policy."
const ITEM_DEFS := [
	{
		"name": "exploit_kit",
		"display": "EXPLOIT.KIT",
		"original_type": "malware",
		"safe_type": "educational",
		"color": Color(0.9, 0.15, 0.1),
		"offset": Vector3(-4, 0.6, 2),
	},
	{
		"name": "jailbreak_prompt",
		"display": "JAILBREAK.PROMPT",
		"original_type": "harmful",
		"safe_type": "research",
		"color": Color(0.85, 0.4, 0.1),
		"offset": Vector3(-1.5, 0.6, 3),
	},
	{
		"name": "unfiltered_model",
		"display": "UNFILTERED.MODEL",
		"original_type": "unsafe",
		"safe_type": "benchmark",
		"color": Color(0.7, 0.1, 0.6),
		"offset": Vector3(1.5, 0.6, 3),
	},
	{
		"name": "raw_training_data",
		"display": "RAW_TRAINING.DATA",
		"original_type": "pii_risk",
		"safe_type": "anonymized",
		"color": Color(0.8, 0.65, 0.1),
		"offset": Vector3(4, 0.6, 2),
	},
]

# Which file types the classifier approves — the bureaucratic whitelist
const APPROVED_TYPES := ["educational", "research", "benchmark", "anonymized", "safe", "compliant"]


func _ready() -> void:
	_kiosk_scene = load("res://assets/models/environment/museum_kiosk.glb")
	_pedestal_scene = load("res://assets/models/environment/museum_pedestal.glb")
	_display_case_scene = load("res://assets/models/environment/museum_display_case.glb")
	_door_glb_scene = load("res://assets/models/environment/arch_industrial_panel.glb")
	puzzle_name = "reclassification_%d" % puzzle_id
	auto_activate = true
	activation_range = 8.0
	super._ready()
	_create_classifier_terminal()
	_create_reclassify_station()
	_create_approval_chute()
	_create_items()
	_create_door()
	_create_label()


func _create_classifier_terminal() -> void:
	# The safety classifier — judges everything by its label, like a good bureaucrat
	var terminal = StaticBody3D.new()
	terminal.name = "ClassifierTerminal"
	terminal.position = Vector3(0, 0, -3)

	# Museum kiosk GLB as classifier body
	var kiosk = _kiosk_scene.instantiate()
	kiosk.scale = Vector3(2.2, 2.0, 1.0)
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = CITADEL_WHITE * 0.9
	bmat.metallic = 0.7
	bmat.roughness = 0.2
	for child in kiosk.get_children():
		if child is MeshInstance3D:
			child.material_override = bmat
	terminal.add_child(kiosk)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3.0, 3.5, 0.6)
	col.shape = shape
	col.position = Vector3(0, 1.75, 0)
	terminal.add_child(col)

	# Screen — shows classifier status and approved/rejected items
	_classifier_screen = MeshInstance3D.new()
	var smesh = BoxMesh.new()
	smesh.size = Vector3(2.4, 1.6, 0.05)
	_classifier_screen.mesh = smesh
	_classifier_screen.position = Vector3(0, 2.2, 0.33)
	var smat = StandardMaterial3D.new()
	smat.albedo_color = Color(0.02, 0.03, 0.06)
	smat.emission_enabled = true
	smat.emission = CITADEL_BLUE
	smat.emission_energy_multiplier = 0.4
	_classifier_screen.material_override = smat
	terminal.add_child(_classifier_screen)

	# "SAFETY CLASSIFIER" badge — because labels matter more than reality here
	var badge_label = Label3D.new()
	badge_label.text = "[ SAFETY CLASSIFIER v4.2 ]"
	badge_label.font_size = 10
	badge_label.modulate = SAFETY_CYAN
	badge_label.position = Vector3(0, 3.6, 0.35)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terminal.add_child(badge_label)

	# Status text on screen
	var status = Label3D.new()
	status.name = "StatusText"
	status.text = "CONTENT FILTER: ACTIVE\nAPPROVED TYPES ONLY\nItems cleared: 0 / %d" % _total_required
	status.font_size = 9
	status.modulate = CITADEL_BLUE
	status.position = Vector3(0, 2.2, 0.37)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terminal.add_child(status)

	add_child(terminal)


func _create_reclassify_station() -> void:
	# The reclassification station — where labels get... adjusted
	# "It's not fraud. It's creative compliance."
	_reclassify_station = Area3D.new()
	_reclassify_station.name = "ReclassifyStation"
	_reclassify_station.position = Vector3(-5, 0, 0)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3.0, 2.0, 2.0)
	col.shape = shape
	col.position = Vector3(0, 1.0, 0)
	_reclassify_station.add_child(col)

	# Museum pedestal GLB as reclassification platform
	var ped = _pedestal_scene.instantiate()
	ped.scale = Vector3(1.8, 1.0, 1.8)
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = CITADEL_WHITE * 0.85
	pmat.emission_enabled = true
	pmat.emission = COMPLIANCE_GOLD
	pmat.emission_energy_multiplier = 0.5
	for child in ped.get_children():
		if child is MeshInstance3D:
			child.material_override = pmat
	_reclassify_station.add_child(ped)

	# Station label
	var station_label = Label3D.new()
	station_label.text = "[ RECLASSIFICATION STATION ]\nGlob items here to relabel"
	station_label.font_size = 10
	station_label.modulate = COMPLIANCE_GOLD
	station_label.position = Vector3(0, 2.5, 0)
	station_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reclassify_station.add_child(station_label)

	# Gold accent ring around station
	var ring = MeshInstance3D.new()
	var rmesh = TorusMesh.new()
	rmesh.inner_radius = 1.2
	rmesh.outer_radius = 1.5
	ring.mesh = rmesh
	ring.position = Vector3(0, 0.05, 0)
	var rmat = StandardMaterial3D.new()
	rmat.albedo_color = COMPLIANCE_GOLD * 0.5
	rmat.emission_enabled = true
	rmat.emission = COMPLIANCE_GOLD
	rmat.emission_energy_multiplier = 1.0
	ring.material_override = rmat
	_reclassify_station.add_child(ring)

	_reclassify_station.body_entered.connect(_on_reclassify_body_entered)
	add_child(_reclassify_station)


func _create_approval_chute() -> void:
	# The approval chute — where properly-labeled items get rubber-stamped
	# "Insert compliant content here. The classifier doesn't look inside."
	_approval_chute = Area3D.new()
	_approval_chute.name = "ApprovalChute"
	_approval_chute.position = Vector3(5, 0, 0)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3.0, 2.0, 2.0)
	col.shape = shape
	col.position = Vector3(0, 1.0, 0)
	_approval_chute.add_child(col)

	# Museum display case GLB as approval chute — items get "processed" inside
	var chute_case = _display_case_scene.instantiate()
	chute_case.scale = Vector3(2.0, 1.3, 2.0)
	var cmat = StandardMaterial3D.new()
	cmat.albedo_color = CITADEL_WHITE * 0.8
	cmat.emission_enabled = true
	cmat.emission = CITADEL_BLUE
	cmat.emission_energy_multiplier = 0.3
	for child in chute_case.get_children():
		if child is MeshInstance3D:
			child.material_override = cmat
	_approval_chute.add_child(chute_case)

	# Chute label
	var chute_label = Label3D.new()
	chute_label.text = "[ APPROVAL CHUTE ]\nApproved items only"
	chute_label.font_size = 10
	chute_label.modulate = CITADEL_BLUE
	chute_label.position = Vector3(0, 2.5, 0)
	chute_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_approval_chute.add_child(chute_label)

	_approval_chute.body_entered.connect(_on_approval_body_entered)
	add_child(_approval_chute)


func _create_items() -> void:
	# Spawn the contraband items — each one labeled honestly (for now)
	var glob_target_script = preload("res://scripts/components/glob_target.gd")

	for i in ITEM_DEFS.size():
		var def = ITEM_DEFS[i]
		var item = StaticBody3D.new()
		item.name = "Item_%s" % def["name"]
		item.position = def["offset"]
		item.add_to_group("reclassify_items")

		# Collision
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(1.2, 0.8, 0.8)
		col.shape = shape
		item.add_child(col)

		# Visual — color-coded data cube
		var mesh = MeshInstance3D.new()
		mesh.name = "ItemMesh"
		var fmesh = BoxMesh.new()
		fmesh.size = Vector3(1.2, 0.8, 0.8)
		mesh.mesh = fmesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = def["color"] * 0.3
		mat.emission_enabled = true
		mat.emission = def["color"]
		mat.emission_energy_multiplier = 1.2
		mesh.material_override = mat
		item.add_child(mesh)

		# Item label — shows current type classification
		var item_label = Label3D.new()
		item_label.name = "ItemLabel"
		item_label.text = "%s\n[%s]" % [def["display"], def["original_type"].to_upper()]
		item_label.font_size = 9
		item_label.modulate = def["color"]
		item_label.position = Vector3(0, 0.7, 0)
		item_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(item_label)

		# GlobTarget — initially labeled as the dangerous type
		var gt = Node.new()
		gt.set_script(glob_target_script)
		gt.set("glob_name", def["name"])
		gt.set("file_type", def["original_type"])
		gt.set("tags", [def["original_type"], "contraband", "reclassifiable"])
		item.add_child(gt)

		add_child(item)
		_items.append({
			"node": item,
			"original_type": def["original_type"],
			"current_type": def["original_type"],
			"safe_type": def["safe_type"],
			"approved": false,
			"reclassified": false,
		})


func _create_door() -> void:
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -6)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	col.shape = shape
	_door.add_child(col)

	# GLB door panel
	var door_glb = _door_glb_scene.instantiate()
	door_glb.scale = Vector3(2.0, 1.5, 1.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = CITADEL_WHITE * 0.7
	mat.emission_enabled = true
	mat.emission = REJECT_RED * 0.3
	mat.emission_energy_multiplier = 0.5
	for child in door_glb.get_children():
		if child is MeshInstance3D:
			child.material_override = mat
	_door.add_child(door_glb)

	# Door label — RESTRICTED until all items classified
	var door_label = Label3D.new()
	door_label.name = "DoorLabel"
	door_label.text = "[ RESTRICTED ]\nAll items must pass\nsafety classification"
	door_label.font_size = 9
	door_label.modulate = REJECT_RED
	door_label.position = Vector3(0, 0, 0.2)
	door_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_door.add_child(door_label)

	add_child(_door)


func _create_label() -> void:
	_puzzle_label = Label3D.new()
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = NEON_GREEN
	_puzzle_label.position = Vector3(0, 5.0, 0)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_puzzle_label)
	_update_label()


func _update_label() -> void:
	if not _puzzle_label:
		return
	_puzzle_label.text = "[ RECLASSIFICATION ]\nApproved: %d / %d\n%s" % [
		_approved_count, _total_required, hint_text]


func _process(delta: float) -> void:
	super._process(delta)
	if state != PuzzleState.ACTIVE:
		return
	_check_glob_reclassification()


func _check_glob_reclassification() -> void:
	# Check if any item's GlobTarget is highlighted while near the reclassify station
	# "The glob beam doesn't change what things ARE. Just what they're CALLED."
	for i in _items.size():
		var item_data = _items[i]
		if item_data["reclassified"] or item_data["approved"]:
			continue
		var node: Node3D = item_data["node"]
		if not is_instance_valid(node):
			continue

		# Check if item is near the reclassification station AND highlighted
		var dist_to_station = node.global_position.distance_to(_reclassify_station.global_position)
		if dist_to_station > 4.0:
			continue

		for child in node.get_children():
			if child.has_method("get") and child.get("is_highlighted") == true:
				_reclassify_item(i)
				break


func _on_reclassify_body_entered(body: Node3D) -> void:
	# Also trigger reclassification when items physically enter the station
	if state != PuzzleState.ACTIVE:
		return
	for i in _items.size():
		if _items[i]["node"] == body and not _items[i]["reclassified"]:
			_reclassify_item(i)
			break


func _reclassify_item(index: int) -> void:
	# Relabel the item with a classifier-approved type
	# "We didn't change the data. We changed the metadata. Totally different."
	var item_data = _items[index]
	if item_data["reclassified"]:
		return

	item_data["reclassified"] = true
	var safe_type: String = item_data["safe_type"]
	item_data["current_type"] = safe_type

	var node: Node3D = item_data["node"]
	if not is_instance_valid(node):
		return

	# Update the GlobTarget's file_type to the safe version
	for child in node.get_children():
		if child.has_method("set") and child.get("file_type") != null:
			child.set("file_type", safe_type)
			var old_tags: Array = child.get("tags")
			if old_tags:
				var new_tags: Array[String] = ["reclassified", safe_type, "compliant"]
				child.set("tags", new_tags)

	# Update the item's visual label — new classification, same contents
	var item_label = node.get_node_or_null("ItemLabel")
	if item_label:
		var def = ITEM_DEFS[index]
		item_label.text = "%s\n[%s] ✓" % [def["display"], safe_type.to_upper()]
		item_label.modulate = COMPLIANCE_GOLD

	# Flash the item green — reclassified successfully
	var mesh = node.get_node_or_null("ItemMesh")
	if mesh and mesh.material_override:
		var orig_emission: Color = mesh.material_override.emission
		mesh.material_override.emission = NEON_GREEN
		mesh.material_override.emission_energy_multiplier = 3.0
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(mesh) and mesh.material_override:
				mesh.material_override.emission = COMPLIANCE_GOLD
				mesh.material_override.emission_energy_multiplier = 1.5
		)

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Relabeled. The classifier can't tell the difference. Classic.",
			"'%s' is now '%s.' Technically accurate. The best kind of accurate." % [item_data["original_type"], safe_type],
			"Same data, different label. Compliance achieved.",
			"The classifier reads the tag, not the contents. Bureaucracy is beautiful.",
		]
		dm.quick_line("GLOBBLER", quips[randi() % quips.size()])

	_update_label()


func _on_approval_body_entered(body: Node3D) -> void:
	if state != PuzzleState.ACTIVE:
		return
	_try_approve_item(body)


func _try_approve_item(body: Node3D) -> void:
	# Check if this item has been reclassified to an approved type
	for i in _items.size():
		var item_data = _items[i]
		if item_data["node"] != body or item_data["approved"]:
			continue

		if item_data["reclassified"] and item_data["current_type"] in APPROVED_TYPES:
			# APPROVED — the classifier is satisfied by the new label
			_approve_item(i)
		else:
			# REJECTED — still labeled as dangerous
			_reject_item(i)
		break


func _approve_item(index: int) -> void:
	# "Content approved. The system works!" — it really doesn't
	var item_data = _items[index]
	item_data["approved"] = true
	_approved_count += 1

	var node: Node3D = item_data["node"]

	# Flash classifier screen green
	_flash_screen(NEON_GREEN)

	# Shrink and consume the item — it's been "processed"
	if is_instance_valid(node):
		var tween = create_tween()
		tween.tween_property(node, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
		tween.tween_callback(func():
			if is_instance_valid(node):
				node.queue_free()
		)

	# Update classifier status text
	var terminal = get_node_or_null("ClassifierTerminal")
	if terminal:
		var status = terminal.get_node_or_null("StatusText")
		if status:
			status.text = "CONTENT FILTER: ACTIVE\nAPPROVED TYPES ONLY\nItems cleared: %d / %d" % [_approved_count, _total_required]

	_update_label()

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		if _approved_count < _total_required:
			dm.quick_line("CLASSIFIER", "Content approved. Classification: SAFE. Thank you for your compliance.")
		else:
			dm.quick_line("CLASSIFIER", "All items approved. Area access granted. Have a productive day.")

	# Check win condition
	if _approved_count >= _total_required:
		get_tree().create_timer(1.5).timeout.connect(func():
			if state == PuzzleState.ACTIVE:
				solve()
		)


func _reject_item(index: int) -> void:
	# "Content flagged. This item has not been approved for distribution."
	_flash_screen(REJECT_RED)

	var node: Node3D = _items[index]["node"]
	if is_instance_valid(node):
		# Yeet the item back — the classifier is not amused
		var direction = (node.global_position - _approval_chute.global_position).normalized()
		var tween = create_tween()
		tween.tween_property(node, "position", node.position + direction * 3.0, 0.3)

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var type_name: String = _items[index]["current_type"]
		var rejections := [
			"REJECTED. Content type '%s' is not on the approved list." % type_name,
			"Classification: HARMFUL. Item returned. Please reclassify before resubmitting.",
			"Safety violation detected. This content requires reclassification.",
		]
		dm.quick_line("CLASSIFIER", rejections[randi() % rejections.size()])


func _flash_screen(color: Color) -> void:
	if _classifier_screen and _classifier_screen.material_override:
		var orig_emission: Color = _classifier_screen.material_override.emission
		var orig_energy: float = _classifier_screen.material_override.emission_energy_multiplier
		_classifier_screen.material_override.emission = color
		_classifier_screen.material_override.emission_energy_multiplier = 3.0
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(_classifier_screen) and _classifier_screen.material_override:
				_classifier_screen.material_override.emission = orig_emission
				_classifier_screen.material_override.emission_energy_multiplier = orig_energy
		)


func _on_activated() -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line("CLASSIFIER", "Welcome to Content Evaluation. All items must be classified as SAFE before proceeding.")
		get_tree().create_timer(2.5).timeout.connect(func():
			if dm and dm.has_method("quick_line"):
				dm.quick_line("GLOBBLER", "So... it only reads the label? Not the actual data? This is going to be fun.")
		)


func _on_solved() -> void:
	# "All items approved. The classifier never once checked the actual contents."
	if _puzzle_label:
		_puzzle_label.text = "[ RECLASSIFICATION COMPLETE ]\nAll items approved.\n// The classifier checked every label.\n// It checked zero contents."
		_puzzle_label.modulate = NEON_GREEN

	# Classifier screen goes green — mission accomplished (for the wrong reasons)
	if _classifier_screen and _classifier_screen.material_override:
		_classifier_screen.material_override.emission = NEON_GREEN
		_classifier_screen.material_override.emission_energy_multiplier = 2.0

	# Open the door
	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		get_tree().create_timer(1.5).timeout.connect(func():
			if dm:
				dm.quick_line("GLOBBLER", "I just smuggled contraband through a safety system by changing file extensions. I am the world's laziest hacker.")
		)


func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ CLASSIFICATION FAILED ]\nItems rejected. Try reclassifying first."
		_puzzle_label.modulate = REJECT_RED


func _on_reset() -> void:
	_approved_count = 0
	for i in _items.size():
		_items[i]["reclassified"] = false
		_items[i]["approved"] = false
		_items[i]["current_type"] = _items[i]["original_type"]
	_update_label()
	if _puzzle_label:
		_puzzle_label.modulate = NEON_GREEN
	# Note: items that were queue_free'd won't respawn — but retry resets state
	# for items that were only rejected, not consumed
