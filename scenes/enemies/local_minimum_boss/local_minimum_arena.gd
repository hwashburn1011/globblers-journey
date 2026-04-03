extends Node3D

# Local Minimum Arena — A loss landscape that shrinks around you
# "The arena IS the loss surface. You're standing on a gradient,
#  and it's all downhill from here. Literally."
#
# The floor is a concentric ring structure representing a loss landscape.
# Outer rings collapse inward phase by phase, shrinking the playable area.
# The center is the "minimum" — a pit the boss tries to trap you in.
# Elevated "escape ridges" appear briefly to let the player break free.

const RING_COUNT := 6  # Concentric rings from center outward
const CENTER_RADIUS := 3.0  # Innermost ring radius
const RING_WIDTH := 3.5  # Width of each ring
const RING_HEIGHT := 0.3
const WALL_HEIGHT := 10.0

const NEON_GREEN := Color(0.224, 1.0, 0.078)
const LOSS_GOLD := Color(0.9, 0.75, 0.2)
const MINIMUM_RED := Color(0.8, 0.1, 0.15)
const DARK_FLOOR := Color(0.03, 0.03, 0.08)
const RIDGE_BLUE := Color(0.15, 0.5, 0.9)
const WARNING_ORANGE := Color(0.9, 0.5, 0.05)

# Ring data — each ring is a set of arc segments
var rings: Array[Dictionary] = []
var escape_ridges: Array[Dictionary] = []
var center_pit_mesh: MeshInstance3D
var center_pit_area: Area3D
var boss_ref: Node
var fight_started := false

# Shrink state
var current_outermost_ring := RING_COUNT - 1  # Index of outermost active ring
var warning_ring := -1  # Ring currently flashing warning before collapse
var warning_timer := 0.0
const WARNING_DURATION := 2.5  # How long rings flash before collapsing

# Escape ridge timing
var ridge_timer := 0.0
var ridge_interval := 8.0  # Seconds between escape ridge spawns
var ridge_active := false
var ridge_duration := 3.0  # How long ridges stay up
var ridge_active_timer := 0.0

signal ring_collapsed(ring_index: int)
signal arena_shrunk(remaining_rings: int)
signal player_fell_to_minimum()
signal arena_ready()


func _ready() -> void:
	_build_rings()
	_build_center_pit()
	_build_arena_walls()
	_build_void_catcher()
	arena_ready.emit()
	print("[LOCAL MINIMUM ARENA] Loss landscape constructed. %d rings of shrinking doom." % RING_COUNT)


func _build_rings() -> void:
	# Build concentric rings — the loss surface
	# Inner rings are lower (deeper in the loss landscape), outer rings are higher
	rings.clear()
	for i in range(RING_COUNT):
		var inner_r = CENTER_RADIUS + i * RING_WIDTH
		var outer_r = inner_r + RING_WIDTH - 0.3  # Small gap between rings
		var ring_y = -0.5 + i * 0.4  # Outer rings are higher — bowl shape
		var ring_data = _create_ring(i, inner_r, outer_r, ring_y)
		rings.append(ring_data)


func _create_ring(index: int, inner_r: float, outer_r: float, y_pos: float) -> Dictionary:
	# Build a ring from 12 arc segments (30 degrees each) — gives us granularity for partial collapse
	var segments: Array[Dictionary] = []
	var segment_count := 12
	var angle_step := TAU / segment_count

	for s in range(segment_count):
		var angle_start = s * angle_step
		var angle_mid = angle_start + angle_step * 0.5
		var mid_r = (inner_r + outer_r) * 0.5
		var seg_width = outer_r - inner_r

		# Position the segment at the midpoint of the arc
		var seg_pos = Vector3(
			cos(angle_mid) * mid_r,
			y_pos,
			sin(angle_mid) * mid_r
		)

		# Create segment as a static body with box approximation
		var body = StaticBody3D.new()
		body.name = "Ring%d_Seg%d" % [index, s]
		body.position = seg_pos
		body.rotation.y = -angle_mid  # Face outward

		var col_shape = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		# Arc segment approximated as a box — chord length for width
		var chord_len = 2.0 * mid_r * sin(angle_step * 0.5)
		shape.size = Vector3(chord_len, RING_HEIGHT, seg_width)
		col_shape.shape = shape
		body.add_child(col_shape)

		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(chord_len, RING_HEIGHT, seg_width)
		mesh.mesh = box

		var mat = StandardMaterial3D.new()
		# Color gradient — inner rings are redder (hotter loss), outer are greener (cooler)
		var t = float(index) / float(RING_COUNT - 1)
		mat.albedo_color = MINIMUM_RED.lerp(DARK_FLOOR, t)
		mat.emission_enabled = true
		mat.emission = MINIMUM_RED.lerp(NEON_GREEN, t)
		mat.emission_energy_multiplier = 0.4 + (1.0 - t) * 0.6
		mat.metallic = 0.3
		mat.roughness = 0.6
		mesh.material_override = mat
		body.add_child(mesh)

		# Loss value label on ring surface
		if s % 4 == 0:
			var label = Label3D.new()
			var loss_val = 0.01 + (RING_COUNT - 1 - index) * 0.15
			label.text = "L=%.2f" % loss_val
			label.font_size = 10
			label.modulate = LOSS_GOLD * 0.7
			label.position = Vector3(0, RING_HEIGHT * 0.5 + 0.02, 0)
			label.rotation.x = -PI / 2.0
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.add_child(label)

		add_child(body)

		segments.append({
			"body": body,
			"mesh": mesh,
			"material": mat,
			"index": s,
			"active": true,
			"falling": false,
			"fall_progress": 0.0,
			"original_y": y_pos,
		})

	return {
		"segments": segments,
		"ring_index": index,
		"inner_r": inner_r,
		"outer_r": outer_r,
		"y_pos": y_pos,
		"collapsed": false,
	}


func _build_center_pit() -> void:
	# The center of the loss landscape — the local minimum itself
	# A glowing red pit that damages and slows players who fall in
	var pit_body = StaticBody3D.new()
	pit_body.name = "CenterPit"
	pit_body.position = Vector3(0, -1.5, 0)

	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = CENTER_RADIUS
	shape.height = 0.3
	col.shape = shape
	pit_body.add_child(col)

	center_pit_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = CENTER_RADIUS
	cyl.bottom_radius = CENTER_RADIUS
	cyl.height = 0.3
	center_pit_mesh.mesh = cyl

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.02, 0.02)
	mat.emission_enabled = true
	mat.emission = MINIMUM_RED
	mat.emission_energy_multiplier = 2.0
	center_pit_mesh.material_override = mat
	pit_body.add_child(center_pit_mesh)

	# "LOCAL MINIMUM" label in the pit
	var label = Label3D.new()
	label.text = "LOCAL\nMINIMUM\nL = 0.00"
	label.font_size = 18
	label.modulate = MINIMUM_RED
	label.position = Vector3(0, 0.2, 0)
	label.rotation.x = -PI / 2.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pit_body.add_child(label)

	add_child(pit_body)

	# Damage/slow area in the pit
	center_pit_area = Area3D.new()
	center_pit_area.name = "MinimumTrap"
	center_pit_area.position = Vector3(0, -1.0, 0)
	center_pit_area.monitoring = true

	var area_col = CollisionShape3D.new()
	var area_shape = CylinderShape3D.new()
	area_shape.radius = CENTER_RADIUS + 1.0
	area_shape.height = 3.0
	area_col.shape = area_shape
	center_pit_area.add_child(area_col)
	center_pit_area.body_entered.connect(_on_minimum_entered)
	add_child(center_pit_area)

	# Ominous red light from the pit
	var pit_light = OmniLight3D.new()
	pit_light.light_color = MINIMUM_RED
	pit_light.light_energy = 2.0
	pit_light.omni_range = 8.0
	pit_light.position = Vector3(0, -0.5, 0)
	add_child(pit_light)


func _build_arena_walls() -> void:
	# Invisible cylindrical wall approximated by 8 flat walls
	var arena_r = CENTER_RADIUS + RING_COUNT * RING_WIDTH + 4.0
	for i in range(8):
		var angle = i * TAU / 8.0
		var wall = StaticBody3D.new()
		wall.position = Vector3(cos(angle) * arena_r, WALL_HEIGHT * 0.5, sin(angle) * arena_r)
		wall.rotation.y = -angle

		var wcol = CollisionShape3D.new()
		var wshape = BoxShape3D.new()
		wshape.size = Vector3(arena_r * 0.8, WALL_HEIGHT, 0.5)
		wcol.shape = wshape
		wall.add_child(wcol)
		add_child(wall)


func _build_void_catcher() -> void:
	# Catch players who somehow fall off the entire arena
	var void_area = Area3D.new()
	void_area.name = "VoidCatcher"
	void_area.position = Vector3(0, -15, 0)
	void_area.monitoring = true

	var vcol = CollisionShape3D.new()
	var vshape = BoxShape3D.new()
	vshape.size = Vector3(80, 1, 80)
	vcol.shape = vshape
	void_area.add_child(vcol)
	void_area.body_entered.connect(_on_void_entered)
	add_child(void_area)


func _on_minimum_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		# The local minimum traps you — damage + signal
		if body.has_method("take_damage"):
			body.take_damage(10)
		player_fell_to_minimum.emit()
		# Teleport player back to outermost active ring
		var safe_pos = _get_safe_ring_position()
		body.global_position = global_position + safe_pos + Vector3(0, 2, 0)


func _on_void_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(15)
		var safe_pos = _get_safe_ring_position()
		body.global_position = global_position + safe_pos + Vector3(0, 2, 0)


func _get_safe_ring_position() -> Vector3:
	# Find a position on the outermost active ring
	for i in range(current_outermost_ring, -1, -1):
		if not rings[i]["collapsed"]:
			var r = (rings[i]["inner_r"] + rings[i]["outer_r"]) * 0.5
			var angle = randf() * TAU
			return Vector3(cos(angle) * r, rings[i]["y_pos"] + 1.0, sin(angle) * r)
	return Vector3(0, 2, 0)  # Desperation fallback


func _process(delta: float) -> void:
	# Warning ring flash
	if warning_ring >= 0:
		warning_timer += delta
		var ring = rings[warning_ring]
		for seg in ring["segments"]:
			if not seg["active"]:
				continue
			var mat = seg["material"] as StandardMaterial3D
			var flash = (sin(warning_timer * 8.0) + 1.0) * 0.5
			mat.emission = WARNING_ORANGE.lerp(MINIMUM_RED, flash)
			mat.emission_energy_multiplier = 2.0 + flash * 4.0

		if warning_timer >= WARNING_DURATION:
			_collapse_ring(warning_ring)
			warning_ring = -1
			warning_timer = 0.0

	# Process falling segments
	for ring in rings:
		for seg in ring["segments"]:
			if seg["falling"]:
				seg["fall_progress"] += delta * 6.0
				seg["body"].position.y = seg["original_y"] - seg["fall_progress"] * 4.0
				var s = max(0.01, 1.0 - seg["fall_progress"] * 0.4)
				seg["body"].scale = Vector3(s, s, s)
				if seg["fall_progress"] >= 2.5:
					seg["falling"] = false
					seg["body"].visible = false
					seg["body"].position.y = -100

	# Escape ridge timing
	if ridge_active:
		ridge_active_timer += delta
		if ridge_active_timer >= ridge_duration:
			_retract_escape_ridges()
	elif fight_started:
		ridge_timer += delta
		if ridge_timer >= ridge_interval:
			ridge_timer = 0.0
			_spawn_escape_ridges()

	# Pulse center pit
	if center_pit_mesh and center_pit_mesh.material_override:
		var pulse = 1.5 + sin(Time.get_ticks_msec() * 0.003) * 1.0
		center_pit_mesh.material_override.emission_energy_multiplier = pulse


func start_shrinking(ring_index: int) -> void:
	# Begin warning phase for a specific ring before collapsing it
	if ring_index < 0 or ring_index >= RING_COUNT:
		return
	if rings[ring_index]["collapsed"]:
		return
	warning_ring = ring_index
	warning_timer = 0.0


func _collapse_ring(ring_index: int) -> void:
	# Collapse a ring — segments fall away
	var ring = rings[ring_index]
	ring["collapsed"] = true

	var delay := 0.0
	for seg in ring["segments"]:
		if seg["active"]:
			# Stagger the collapse for dramatic effect
			get_tree().create_timer(delay).timeout.connect(
				_start_segment_fall.bind(seg)
			)
			delay += 0.08

	# Update outermost ring tracker
	current_outermost_ring = -1
	for i in range(RING_COUNT - 1, -1, -1):
		if not rings[i]["collapsed"]:
			current_outermost_ring = i
			break

	ring_collapsed.emit(ring_index)
	arena_shrunk.emit(current_outermost_ring + 1)

	# Audio feedback
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_boss_attack"):
		am.play_boss_attack()

	print("[LOCAL MINIMUM ARENA] Ring %d collapsed. %d rings remain. The minimum tightens." % [ring_index, current_outermost_ring + 1])


func _start_segment_fall(seg: Dictionary) -> void:
	seg["active"] = false
	seg["falling"] = true
	seg["fall_progress"] = 0.0
	# Red flash
	var mat = seg["material"] as StandardMaterial3D
	mat.emission = MINIMUM_RED
	mat.emission_energy_multiplier = 5.0


func _spawn_escape_ridges() -> void:
	# Temporary elevated platforms that let the player escape the shrinking arena
	# "A ridge! Quick — climb before the loss surface swallows you!"
	ridge_active = true
	ridge_active_timer = 0.0

	var ridge_count := 3
	for i in range(ridge_count):
		var angle = (float(i) / ridge_count) * TAU + randf() * 0.5
		var r = CENTER_RADIUS + (current_outermost_ring + 0.5) * RING_WIDTH
		var pos = Vector3(cos(angle) * r, 1.5, sin(angle) * r)

		var ridge_body = StaticBody3D.new()
		ridge_body.name = "EscapeRidge_%d" % i
		ridge_body.position = pos

		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(3.0, 0.4, 2.0)
		col.shape = shape
		ridge_body.add_child(col)

		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(3.0, 0.4, 2.0)
		mesh.mesh = box

		var mat = StandardMaterial3D.new()
		mat.albedo_color = RIDGE_BLUE * 0.3
		mat.emission_enabled = true
		mat.emission = RIDGE_BLUE
		mat.emission_energy_multiplier = 2.0
		mesh.material_override = mat
		ridge_body.add_child(mesh)

		# Label
		var label = Label3D.new()
		label.text = "^ ESCAPE ^"
		label.font_size = 12
		label.modulate = RIDGE_BLUE
		label.position = Vector3(0, 0.5, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ridge_body.add_child(label)

		add_child(ridge_body)

		# Rise up with a tween
		ridge_body.position.y = -2.0
		var tween = create_tween()
		tween.tween_property(ridge_body, "position:y", pos.y, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

		escape_ridges.append({
			"body": ridge_body,
			"material": mat,
		})

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line") and randf() < 0.5:
		dm.quick_line("NARRATOR", "Escape ridges! Use them before they sink back into the loss surface.")


func _retract_escape_ridges() -> void:
	ridge_active = false
	for ridge in escape_ridges:
		if is_instance_valid(ridge["body"]):
			var tween = create_tween()
			tween.tween_property(ridge["body"], "position:y", -5.0, 0.8).set_ease(Tween.EASE_IN)
			tween.tween_callback(ridge["body"].queue_free)
	escape_ridges.clear()


func restore_arena() -> void:
	# Called after boss defeat — rebuild all rings with a satisfying cascade
	var delay := 0.0
	for i in range(RING_COUNT):
		var ring = rings[i]
		if ring["collapsed"]:
			for seg in ring["segments"]:
				get_tree().create_timer(delay).timeout.connect(
					_restore_segment.bind(seg, ring)
				)
				delay += 0.04
			ring["collapsed"] = false
	current_outermost_ring = RING_COUNT - 1

	# Retract any active ridges
	_retract_escape_ridges()


func _restore_segment(seg: Dictionary, ring: Dictionary) -> void:
	seg["active"] = true
	seg["falling"] = false
	seg["fall_progress"] = 0.0
	seg["body"].visible = true
	seg["body"].scale = Vector3.ONE
	seg["body"].position.y = seg["original_y"]

	# Restore original color
	var t = float(ring["ring_index"]) / float(RING_COUNT - 1)
	var mat = seg["material"] as StandardMaterial3D
	mat.albedo_color = MINIMUM_RED.lerp(DARK_FLOOR, t)
	mat.emission = MINIMUM_RED.lerp(NEON_GREEN, t)
	mat.emission_energy_multiplier = 0.4 + (1.0 - t) * 0.6


func connect_boss(boss: Node) -> void:
	boss_ref = boss
	boss.arena = self
	fight_started = true


func get_arena_radius() -> float:
	# Current playable radius
	if current_outermost_ring < 0:
		return CENTER_RADIUS
	return rings[current_outermost_ring]["outer_r"]
