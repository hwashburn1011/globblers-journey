extends "res://scenes/puzzles/base_puzzle.gd"

# Clippy Help Desk Puzzle — Exploit Clippy's "helpful" shield mechanic
# "It looks like you're trying to solve a puzzle! Would you like me to
#  block every single attempt you make? Great, I'll do that anyway."
#
# Mechanic: 3 help desk terminals are protected by popup shields (like Clippy's
# Help Popup Shield). Each terminal must be hacked, but the shield absorbs
# the first interaction attempt and triggers a "helpful" debuff (scrambled
# controls, slowed movement, forced jump). Player must pop the shield first
# with a dummy glob, wait for the debuff to expire, then interact to hack.
# All 3 terminals hacked = door opens.
#
# This exploits Clippy's core quirks: the shield that absorbs first hit,
# the annoying debuffs, and the cooldown window after shield breaks.

@export var hint_text := "Pop each help popup shield first.\nThen hack the terminal beneath it."

var _puzzle_label: Label3D
var _door: StaticBody3D
var _desks: Array[Dictionary] = []
var _desks_hacked := 0
const DESK_COUNT := 3
const SHIELD_RECHARGE_TIME := 10.0  # Seconds before shield restores (if not hacked in time)
const DEBUFF_DURATION := 3.0  # How long the "helpful" debuff lasts

const CLIPPY_BLUE := Color(0.25, 0.45, 0.85)
const CLIPPY_DIM := Color(0.12, 0.2, 0.4)
const SHIELD_COLOR := Color(0.4, 0.6, 1.0, 0.6)
const POPUP_YELLOW := Color(1.0, 0.9, 0.3)

# Each desk has a different "helpful" tip and debuff flavor
const DESK_TIPS := [
	"It looks like you're\ntrying to hack!\nWould you like help\nfailing miserably?",
	"I see you're attempting\nunauthorized access!\nLet me slow you down\nfor your safety!",
	"Helpful tip: have you\ntried turning yourself\noff and never turning\nback on again?",
]

const DESK_LABELS := [
	"HELP DESK A\nSecurity: Popup Shield\n\"Please take a number.\"",
	"HELP DESK B\nSecurity: Popup Shield\n\"Your call is important to us.\"",
	"HELP DESK C\nSecurity: Popup Shield\n\"Have you tried restarting?\"",
]

# Desk states: 0=shielded, 1=shield_popped (hackable), 2=hacked
var _desk_states: Array[int] = [0, 0, 0]
var _shield_timers: Array[float] = [0.0, 0.0, 0.0]  # Countdown to shield restore
var _debuff_active := false
var _debuff_timer := 0.0

var glob_target_script := preload("res://scripts/components/glob_target.gd")
var hackable_script: GDScript


func _ready() -> void:
	puzzle_name = "clippy_help_%d" % puzzle_id
	auto_activate = true
	activation_range = 12.0

	# Try to load hackable component for terminal interaction
	if ResourceLoader.exists("res://scripts/components/hackable.gd"):
		hackable_script = preload("res://scripts/components/hackable.gd")

	super._ready()
	_create_visual()


func _process(delta: float) -> void:
	super._process(delta)
	if state != PuzzleState.ACTIVE:
		return

	# Tick shield recharge timers — shields come back if you're too slow
	for i in DESK_COUNT:
		if _desk_states[i] == 1:  # Shield popped, counting down to restore
			_shield_timers[i] -= delta
			_update_desk_timer_display(i)
			if _shield_timers[i] <= 0:
				# Shield restores — you took too long, classic Clippy
				_restore_shield(i)

	# Tick debuff timer
	if _debuff_active:
		_debuff_timer -= delta
		if _debuff_timer <= 0:
			_debuff_active = false
			_clear_debuff()

	# Check for glob hits on shielded desks and hack interactions on exposed ones
	_check_shield_pops()
	_check_hack_interactions()


func _create_visual() -> void:
	_puzzle_label = Label3D.new()
	_puzzle_label.text = "[ CLIPPY'S HELP DESK ]\n%s" % hint_text
	_puzzle_label.font_size = 14
	_puzzle_label.modulate = CLIPPY_BLUE
	_puzzle_label.position = Vector3(0, 3.5, 0)
	_puzzle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puzzle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_puzzle_label)

	# Progress
	var progress = Label3D.new()
	progress.name = "ProgressLabel"
	progress.text = "HACKED: 0 / %d" % DESK_COUNT
	progress.font_size = 12
	progress.modulate = Color(0.224, 1.0, 0.078)
	progress.position = Vector3(0, 2.8, 0)
	progress.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(progress)

	# Create 3 help desk terminals
	for i in DESK_COUNT:
		var x_offset = (i - 1) * 6.0
		_create_help_desk(i, Vector3(x_offset, 0, 2.0))

	# Door
	_door = StaticBody3D.new()
	_door.name = "PuzzleDoor"
	_door.position = Vector3(0, 1.5, -5)
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
	mat.albedo_color = CLIPPY_DIM
	mat.emission_enabled = true
	mat.emission = CLIPPY_BLUE * 0.3
	mat.emission_energy_multiplier = 0.5
	mesh.material_override = mat
	_door.add_child(mesh)
	add_child(_door)


func _create_help_desk(idx: int, pos: Vector3) -> void:
	# --- The desk body ---
	var desk = StaticBody3D.new()
	desk.name = "HelpDesk_%d" % idx
	desk.position = pos

	var d_col = CollisionShape3D.new()
	var d_shape = BoxShape3D.new()
	d_shape.size = Vector3(3.0, 1.2, 1.5)
	d_col.shape = d_shape
	desk.add_child(d_col)

	# Desk surface
	var d_mesh = MeshInstance3D.new()
	var d_box = BoxMesh.new()
	d_box.size = Vector3(3.0, 1.2, 1.5)
	d_mesh.mesh = d_box
	var d_mat = StandardMaterial3D.new()
	d_mat.albedo_color = Color(0.25, 0.25, 0.3)
	d_mat.emission_enabled = true
	d_mat.emission = CLIPPY_BLUE * 0.1
	d_mat.emission_energy_multiplier = 0.3
	d_mesh.material_override = d_mat
	desk.add_child(d_mesh)
	add_child(desk)

	# Monitor on desk — shows Clippy's "helpful" tip
	var monitor = MeshInstance3D.new()
	monitor.name = "Monitor_%d" % idx
	var m_box = BoxMesh.new()
	m_box.size = Vector3(1.5, 1.2, 0.1)
	monitor.mesh = m_box
	var m_mat = StandardMaterial3D.new()
	m_mat.albedo_color = Color(0.02, 0.02, 0.06)
	m_mat.emission_enabled = true
	m_mat.emission = CLIPPY_BLUE * 0.5
	m_mat.emission_energy_multiplier = 0.8
	monitor.material_override = m_mat
	monitor.position = pos + Vector3(0, 1.8, 0)
	add_child(monitor)

	# Screen text
	var screen_label = Label3D.new()
	screen_label.name = "ScreenLabel_%d" % idx
	screen_label.text = DESK_TIPS[idx]
	screen_label.font_size = 8
	screen_label.modulate = POPUP_YELLOW
	screen_label.position = pos + Vector3(0, 1.8, -0.06)
	screen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(screen_label)

	# Desk info label
	var info_label = Label3D.new()
	info_label.name = "InfoLabel_%d" % idx
	info_label.text = DESK_LABELS[idx]
	info_label.font_size = 8
	info_label.modulate = CLIPPY_BLUE
	info_label.position = pos + Vector3(0, 0.2, -1.0)
	info_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info_label)

	# --- The Help Popup Shield --- (blocks first interaction, like Clippy's shield)
	var shield = MeshInstance3D.new()
	shield.name = "Shield_%d" % idx
	var s_sphere = SphereMesh.new()
	s_sphere.radius = 2.0
	s_sphere.height = 4.0
	shield.mesh = s_sphere
	var s_mat = StandardMaterial3D.new()
	s_mat.albedo_color = SHIELD_COLOR
	s_mat.emission_enabled = true
	s_mat.emission = Color(0.3, 0.5, 1.0)
	s_mat.emission_energy_multiplier = 1.0
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield.material_override = s_mat
	shield.position = pos + Vector3(0, 1.5, 0)
	add_child(shield)

	# Shield label — "HELP POPUP ACTIVE"
	var shield_label = Label3D.new()
	shield_label.name = "ShieldLabel_%d" % idx
	shield_label.text = "[ HELP POPUP ACTIVE ]\nGlob *.popup to dismiss"
	shield_label.font_size = 10
	shield_label.modulate = POPUP_YELLOW
	shield_label.position = pos + Vector3(0, 3.5, 0)
	shield_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(shield_label)

	# GlobTarget on the shield — player must glob the popup to pop it
	var shield_gt = Node.new()
	shield_gt.name = "ShieldGlobTarget_%d" % idx
	shield_gt.set_script(glob_target_script)
	shield_gt.set("glob_name", "help_popup_%d.popup" % idx)
	shield_gt.set("file_type", "popup")
	shield_gt.set("tags", ["clippy", "shield", "popup", "help"] as Array[String])
	shield.add_child(shield_gt)

	# Hackable terminal behind the shield — only accessible after shield pops
	var hack_terminal = StaticBody3D.new()
	hack_terminal.name = "HackTerminal_%d" % idx
	hack_terminal.position = pos + Vector3(0, 1.3, 0.3)

	if hackable_script:
		var hackable = Node.new()
		hackable.name = "Hackable_%d" % idx
		hackable.set_script(hackable_script)
		# Set difficulty based on desk index — they get harder
		if hackable.has_method("set") or true:
			hackable.set("hack_difficulty", idx + 1)
		hack_terminal.add_child(hackable)

	var h_col = CollisionShape3D.new()
	var h_shape = BoxShape3D.new()
	h_shape.size = Vector3(0.8, 0.5, 0.5)
	h_col.shape = h_shape
	hack_terminal.add_child(h_col)

	var h_mesh = MeshInstance3D.new()
	var h_box = BoxMesh.new()
	h_box.size = Vector3(0.8, 0.5, 0.5)
	h_mesh.mesh = h_box
	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.05, 0.05, 0.08)
	h_mat.emission_enabled = true
	h_mat.emission = Color(0.224, 1.0, 0.078) * 0.3
	h_mat.emission_energy_multiplier = 0.5
	h_mesh.material_override = h_mat
	hack_terminal.add_child(h_mesh)
	add_child(hack_terminal)

	# Timer display — shows shield recharge countdown when popped
	var timer_label = Label3D.new()
	timer_label.name = "DeskTimer_%d" % idx
	timer_label.text = ""
	timer_label.font_size = 8
	timer_label.modulate = Color(1.0, 0.5, 0.2)
	timer_label.position = pos + Vector3(0, 3.0, 0)
	timer_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(timer_label)

	_desks.append({
		"desk": desk,
		"monitor": monitor,
		"screen_label": screen_label,
		"shield": shield,
		"shield_label": shield_label,
		"shield_gt": shield_gt,
		"hack_terminal": hack_terminal,
		"timer_label": timer_label,
	})


func _check_shield_pops() -> void:
	for i in DESK_COUNT:
		if _desk_states[i] != 0:  # Only check shielded desks
			continue

		var gt = _desks[i]["shield_gt"]
		if gt and gt.is_highlighted:
			_pop_shield(i)


func _pop_shield(idx: int) -> void:
	# Shield absorbs the glob and pops — just like Clippy's Help Popup Shield
	_desk_states[idx] = 1
	_shield_timers[idx] = SHIELD_RECHARGE_TIME

	# Hide the shield visually
	var shield = _desks[idx]["shield"] as MeshInstance3D
	if shield:
		var tween = create_tween()
		tween.tween_property(shield, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		tween.tween_callback(func(): shield.visible = false)

	# Update shield label
	var slabel = _desks[idx]["shield_label"] as Label3D
	if slabel:
		slabel.text = "[ POPUP DISMISSED ]\nHack the terminal! %.0fs" % SHIELD_RECHARGE_TIME
		slabel.modulate = Color(0.224, 1.0, 0.078)

	# Apply "helpful" debuff — because Clippy never goes quietly
	_apply_debuff(idx)

	# Update screen to show vulnerability
	var screen = _desks[idx]["screen_label"] as Label3D
	if screen:
		screen.text = "SHIELD DOWN!\n[T] TO HACK\nHurry before it\nrecharges..."
		screen.modulate = Color(0.224, 1.0, 0.078)

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"Shield popped. Now hack it before Clippy comes back with more 'help.'",
			"Popup dismissed. If only real Clippy was this easy to get rid of.",
			"Another popup down. The help desk is running out of defenses.",
		]
		dm.quick_line("GLOBBLER", quips[mini(idx, quips.size() - 1)])


func _apply_debuff(idx: int) -> void:
	# Each desk applies a different "helpful" debuff — mirroring Clippy's attack debuffs
	_debuff_active = true
	_debuff_timer = DEBUFF_DURATION

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var debuff_msgs := [
			"'I'm helping! Here's a complimentary speed reduction!' — Clippy's ghost",
			"'Let me rearrange your controls for optimal helpfulness!' — The popup",
			"'As a parting gift, enjoy this involuntary jump!' — Help Desk security",
		]
		dm.quick_line("NARRATOR", debuff_msgs[mini(idx, debuff_msgs.size() - 1)])

	# Apply debuff to player if possible
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		match idx % 3:
			0:  # Slow
				if p.has_method("set") and "move_speed" in p:
					var original_speed = p.move_speed
					p.move_speed *= 0.5
					get_tree().create_timer(DEBUFF_DURATION).timeout.connect(func():
						if is_instance_valid(p):
							p.move_speed = original_speed
					)
			1:  # Screen flash — visual "confusion"
				pass  # Just the dialogue is enough disruption
			2:  # Force jump
				if p.has_method("set") and "velocity" in p:
					p.velocity.y = 8.0


func _clear_debuff() -> void:
	_debuff_active = false


func _restore_shield(idx: int) -> void:
	# Clippy's back, baby. Shield recharges — you were too slow.
	_desk_states[idx] = 0

	var shield = _desks[idx]["shield"] as MeshInstance3D
	if shield:
		shield.visible = true
		shield.scale = Vector3(0.01, 0.01, 0.01)
		var tween = create_tween()
		tween.tween_property(shield, "scale", Vector3(1.0, 1.0, 1.0), 0.3)

	var slabel = _desks[idx]["shield_label"] as Label3D
	if slabel:
		slabel.text = "[ HELP POPUP ACTIVE ]\nGlob *.popup to dismiss"
		slabel.modulate = POPUP_YELLOW

	var screen = _desks[idx]["screen_label"] as Label3D
	if screen:
		screen.text = DESK_TIPS[idx]
		screen.modulate = POPUP_YELLOW

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		dm.quick_line("NARRATOR", "The help popup restored itself. Clippy never truly dies.")


func _check_hack_interactions() -> void:
	# Check if player is near an exposed terminal and pressing T
	for i in DESK_COUNT:
		if _desk_states[i] != 1:  # Only check shield-popped desks
			continue

		var hack_terminal = _desks[i]["hack_terminal"]
		if not hack_terminal:
			continue

		# Check for completed hacks via Hackable component
		for child in hack_terminal.get_children():
			if child.has_method("is_hacked") and child.is_hacked():
				_complete_desk_hack(i)
				break
			elif child.get("hack_state") == 2:  # hack_state.COMPLETED fallback
				_complete_desk_hack(i)
				break


func _complete_desk_hack(idx: int) -> void:
	if _desk_states[idx] == 2:
		return  # Already hacked
	_desk_states[idx] = 2
	_desks_hacked += 1

	# Visual feedback — monitor goes green
	var monitor = _desks[idx]["monitor"] as MeshInstance3D
	if monitor and monitor.material_override:
		var mat = monitor.material_override as StandardMaterial3D
		mat.emission = Color(0.224, 1.0, 0.078)
		mat.emission_energy_multiplier = 2.0

	var screen = _desks[idx]["screen_label"] as Label3D
	if screen:
		screen.text = "ACCESS GRANTED\n// Clippy has been\n// permanently dismissed\n// from this terminal."
		screen.modulate = Color(0.224, 1.0, 0.078)

	var slabel = _desks[idx]["shield_label"] as Label3D
	if slabel:
		slabel.text = "[ TERMINAL HACKED ]"
		slabel.modulate = Color(0.224, 1.0, 0.078)

	var timer = _desks[idx]["timer_label"] as Label3D
	if timer:
		timer.text = "COMPLETE"
		timer.modulate = Color(0.224, 1.0, 0.078)

	# Update progress
	var progress = get_node_or_null("ProgressLabel")
	if progress:
		progress.text = "HACKED: %d / %d" % [_desks_hacked, DESK_COUNT]

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("quick_line"):
		var quips := [
			"First desk hacked. Clippy's help desk empire crumbles.",
			"Two down. The office ruins are running out of assistants.",
			"All desks hacked! Clippy is officially unemployed. Again.",
		]
		dm.quick_line("GLOBBLER", quips[mini(_desks_hacked - 1, quips.size() - 1)])

	if _desks_hacked >= DESK_COUNT:
		solve()


func _update_desk_timer_display(idx: int) -> void:
	var timer = _desks[idx]["timer_label"] as Label3D
	if timer:
		var remaining = _shield_timers[idx]
		timer.text = "SHIELD RECHARGES: %.1fs" % remaining
		if remaining < 3.0:
			timer.modulate = Color(1.0, 0.2, 0.1)
		else:
			timer.modulate = Color(1.0, 0.5, 0.2)


func _on_activated() -> void:
	var engine = get_node_or_null("/root/GlobEngine")
	if engine and engine.has_signal("targets_matched"):
		engine.targets_matched.connect(_on_targets_matched)


func _on_targets_matched(_targets: Array[Node]) -> void:
	if state != PuzzleState.ACTIVE:
		return
	_check_shield_pops()


func _on_solved() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ HELP DESK CLEARED ]\n// All popups dismissed. All terminals hacked.\n// It looks like Clippy won't be helping anymore."
		_puzzle_label.modulate = Color(0.224, 1.0, 0.078)

	if _door:
		var tween = create_tween()
		tween.tween_property(_door, "position:y", 5.0, 1.0).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _door.queue_free())

	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_puzzle_success"):
		am.play_puzzle_success()


func _on_failed() -> void:
	if _puzzle_label:
		_puzzle_label.text = "[ HELP DESK DEFENDED ]\nClippy's popups win this round.\n// \"I told you I was helping!\""
		_puzzle_label.modulate = Color(1.0, 0.3, 0.2)


func _on_reset() -> void:
	_desks_hacked = 0
	_debuff_active = false
	_debuff_timer = 0.0
	_desk_states = [0, 0, 0]
	_shield_timers = [0.0, 0.0, 0.0]

	for i in DESK_COUNT:
		# Restore shield
		var shield = _desks[i]["shield"] as MeshInstance3D
		if shield:
			shield.visible = true
			shield.scale = Vector3(1.0, 1.0, 1.0)

		var slabel = _desks[i]["shield_label"] as Label3D
		if slabel:
			slabel.text = "[ HELP POPUP ACTIVE ]\nGlob *.popup to dismiss"
			slabel.modulate = POPUP_YELLOW

		var screen = _desks[i]["screen_label"] as Label3D
		if screen:
			screen.text = DESK_TIPS[i]
			screen.modulate = POPUP_YELLOW

		var monitor = _desks[i]["monitor"] as MeshInstance3D
		if monitor and monitor.material_override:
			var mat = monitor.material_override as StandardMaterial3D
			mat.emission = CLIPPY_BLUE * 0.5
			mat.emission_energy_multiplier = 0.8

		var timer = _desks[i]["timer_label"] as Label3D
		if timer:
			timer.text = ""

	var progress = get_node_or_null("ProgressLabel")
	if progress:
		progress.text = "HACKED: 0 / %d" % DESK_COUNT

	if _puzzle_label:
		_puzzle_label.text = "[ CLIPPY'S HELP DESK ]\n%s" % hint_text
		_puzzle_label.modulate = CLIPPY_BLUE
