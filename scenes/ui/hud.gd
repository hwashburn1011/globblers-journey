extends CanvasLayer

# HUD - The Globbler's Heads-Up Display, Terminal Hacker Aesthetic Edition
# "Green on black. Because we're hackers. Very serious, very dangerous hackers."
# Layout: TL=context+health, TR=minimap slot, BC=abilities, BL=pattern input.

var thought_display_time := 4.0
var thought_timer := 0.0
var damage_flash_timer := 0.0
var combo_display_timer := 0.0

# Core HUD elements
var context_bar_scene := preload("res://scenes/ui/context_window_bar.tscn")
var dialogue_box_scene := preload("res://scenes/ui/dialogue_box.tscn")
var glob_input_scene := preload("res://scenes/ui/glob_pattern_input.tscn")
var boss_health_bar_scene := preload("res://scenes/ui/boss_health_bar.tscn")

var context_bar_node: VBoxContainer
var dialogue_box_node: PanelContainer
var glob_input_node: PanelContainer

var thought_label: Label
var token_counter: Label
var dash_indicator: ProgressBar
var dash_label: Label
var glob_indicator: ProgressBar
var glob_label: Label
var combo_label: Label
var timer_label: Label
var level_intro_label: Label
var damage_overlay: ColorRect
var kill_counter: Label
var param_counter: Label
var upgrade_hint: Label

var damage_indicator_scene := preload("res://scenes/ui/damage_indicator.tscn")
var cooldown_radial_shader := preload("res://assets/shaders/cooldown_radial.gdshader")

var player_ref: CharacterBody3D

# Radial cooldown overlays keyed by ability name
var ability_radials: Dictionary = {}

const TERMINAL_GREEN := Color(0.224, 1.0, 0.078)
const TERMINAL_GREEN_DIM := Color(0.15, 0.5, 0.15)
const TERMINAL_GREEN_TEXT := Color(0.3, 1.0, 0.4)
const TERMINAL_BG := Color(0.02, 0.04, 0.02, 0.85)
const TERMINAL_BORDER := Color(0.15, 0.5, 0.15, 0.8)

func _ready() -> void:
	add_to_group("hud")
	_build_hud()

	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.memory_token_collected.connect(update_tokens)
		game_mgr.combo_updated.connect(update_combo)
		game_mgr.enemy_killed_signal.connect(update_kills)
		game_mgr.damage_taken.connect(_on_damage_taken)
		_show_level_intro(game_mgr.get_level_intro())

	var prog = get_node_or_null("/root/ProgressionManager")
	if prog:
		prog.parameter_pickup_collected.connect(update_params)
		prog.currency_changed.connect(_on_currency_changed)

	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		dm.dialogue_started.connect(_on_dialogue_line)
		dm.dialogue_ended.connect(_on_dialogue_ended)

func _create_terminal_panel() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = TERMINAL_BG
	style.border_color = TERMINAL_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style

func _build_hud() -> void:
	# Damage flash overlay (always first — full screen)
	damage_overlay = ColorRect.new()
	damage_overlay.name = "DamageOverlay"
	damage_overlay.color = Color(1.0, 0.1, 0.1, 0.0)
	damage_overlay.anchors_preset = Control.PRESET_FULL_RECT
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_overlay)

	_build_top_left()
	_build_top_right_minimap()
	_build_top_center_timer()
	_build_bottom_center_abilities()
	_build_center_combo()
	_build_bottom_thought()
	_build_level_intro()

	# Damage direction indicator
	var dmg_indicator = damage_indicator_scene.instantiate()
	add_child(dmg_indicator)

	# Boss health bar (instanced — auto-connects to boss enemies)
	var boss_bar = boss_health_bar_scene.instantiate()
	add_child(boss_bar)

	# Dialogue box (instanced)
	dialogue_box_node = dialogue_box_scene.instantiate()
	add_child(dialogue_box_node)

	# Glob pattern input — repositioned to bottom-left
	glob_input_node = glob_input_scene.instantiate()
	add_child(glob_input_node)
	# Override anchors to bottom-left
	glob_input_node.set_deferred("anchor_left", 0.01)
	glob_input_node.set_deferred("anchor_top", 0.82)
	glob_input_node.set_deferred("anchor_right", 0.28)
	glob_input_node.set_deferred("anchor_bottom", 0.92)

func _build_top_left() -> void:
	# === TOP LEFT: Context bar + health stats in terminal panel ===
	var panel = PanelContainer.new()
	panel.name = "TopLeftPanel"
	panel.add_theme_stylebox_override("panel", _create_terminal_panel())
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	panel.offset_right = 280.0
	panel.offset_bottom = 200.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	# Context window bar (instanced scene)
	context_bar_node = context_bar_scene.instantiate()
	vbox.add_child(context_bar_node)

	# Separator line
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", TERMINAL_GREEN_DIM)
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	# Token counter
	token_counter = _create_hud_label("> Memory Tokens: 0", 13)
	vbox.add_child(token_counter)

	# Kill counter
	kill_counter = _create_hud_label("> Agents Purged: 0", 13)
	vbox.add_child(kill_counter)

	# Parameter counter
	param_counter = _create_hud_label("> Parameters: 0", 13)
	vbox.add_child(param_counter)

	# Upgrade hint
	upgrade_hint = Label.new()
	upgrade_hint.name = "UpgradeHint"
	upgrade_hint.text = "[TAB/Select] Upgrades"
	upgrade_hint.add_theme_color_override("font_color", Color(0.2, 0.7, 0.3, 0.5))
	upgrade_hint.add_theme_font_size_override("font_size", 11)
	upgrade_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(upgrade_hint)

func _build_top_right_minimap() -> void:
	# === TOP RIGHT: Minimap slot (empty placeholder) ===
	var panel = PanelContainer.new()
	panel.name = "MinimapSlot"
	panel.add_theme_stylebox_override("panel", _create_terminal_panel())
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -172.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = 172.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	# Placeholder label
	var lbl = Label.new()
	lbl.text = "[MINIMAP]"
	lbl.add_theme_color_override("font_color", Color(0.2, 0.5, 0.25, 0.4))
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

func _build_top_center_timer() -> void:
	# === TOP CENTER: Timer ===
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "00:00"
	timer_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 0.7))
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.anchor_left = 0.5
	timer_label.anchor_top = 0.0
	timer_label.anchor_right = 0.5
	timer_label.anchor_bottom = 0.0
	timer_label.offset_left = -50.0
	timer_label.offset_top = 15.0
	timer_label.offset_right = 50.0
	timer_label.offset_bottom = 40.0
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(timer_label)

func _build_bottom_center_abilities() -> void:
	# === BOTTOM CENTER: Ability icons + cooldowns in terminal panel ===
	var panel = PanelContainer.new()
	panel.name = "AbilityPanel"
	panel.add_theme_stylebox_override("panel", _create_terminal_panel())
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -220.0
	panel.offset_top = -95.0
	panel.offset_right = 220.0
	panel.offset_bottom = -10.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	# Ability icon bar
	var icon_bar = HBoxContainer.new()
	icon_bar.name = "AbilityIconBar"
	icon_bar.add_theme_constant_override("separation", 6)
	icon_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_bar)

	var icon_names := ["glob", "wrench", "hack", "dash", "agent_spawn", "context"]
	for icon_name in icon_names:
		# Container so we can layer the radial overlay on top of the icon
		var icon_container = Control.new()
		icon_container.name = "IconSlot_" + icon_name
		icon_container.custom_minimum_size = Vector2(32, 32)
		icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_bar.add_child(icon_container)

		var tex_rect = TextureRect.new()
		tex_rect.name = "Icon_" + icon_name
		tex_rect.custom_minimum_size = Vector2(32, 32)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.modulate = Color(0.8, 1.0, 0.8, 0.85)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_path = "res://assets/ui/icons/" + icon_name + ".png"
		if ResourceLoader.exists(icon_path):
			tex_rect.texture = load(icon_path)
		icon_container.add_child(tex_rect)

		# Radial cooldown overlay on top of icon
		var radial = ColorRect.new()
		radial.name = "Radial_" + icon_name
		radial.set_anchors_preset(Control.PRESET_FULL_RECT)
		radial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat = ShaderMaterial.new()
		mat.shader = cooldown_radial_shader
		mat.set_shader_parameter("cooldown_percent", 1.0)
		mat.set_shader_parameter("overlay_color", Color(0.0, 0.0, 0.0, 0.65))
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.get("reduce_motion"):
			mat.set_shader_parameter("animate", false)
		radial.material = mat
		icon_container.add_child(radial)
		ability_radials[icon_name] = radial

	# Cooldown bars row
	var cooldown_row = HBoxContainer.new()
	cooldown_row.add_theme_constant_override("separation", 12)
	cooldown_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cooldown_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cooldown_row)

	# Dash cooldown
	var dash_box = VBoxContainer.new()
	dash_box.add_theme_constant_override("separation", 2)
	dash_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_row.add_child(dash_box)

	dash_label = Label.new()
	dash_label.text = "[SHIFT] DASH"
	dash_label.add_theme_color_override("font_color", TERMINAL_GREEN_TEXT)
	dash_label.add_theme_font_size_override("font_size", 11)
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_box.add_child(dash_label)

	dash_indicator = _create_cooldown_bar()
	dash_indicator.custom_minimum_size = Vector2(180, 12)
	dash_box.add_child(dash_indicator)

	# Glob cooldown
	var glob_box = VBoxContainer.new()
	glob_box.add_theme_constant_override("separation", 2)
	glob_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_row.add_child(glob_box)

	glob_label = Label.new()
	glob_label.text = "[E] GLOB"
	glob_label.add_theme_color_override("font_color", TERMINAL_GREEN_TEXT)
	glob_label.add_theme_font_size_override("font_size", 11)
	glob_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glob_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glob_box.add_child(glob_label)

	glob_indicator = _create_cooldown_bar()
	glob_indicator.name = "GlobIndicator"
	glob_indicator.custom_minimum_size = Vector2(180, 12)
	glob_box.add_child(glob_indicator)

func _build_center_combo() -> void:
	# === CENTER: Combo display ===
	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.text = ""
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	combo_label.add_theme_font_size_override("font_size", 36)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.anchor_left = 0.5
	combo_label.anchor_top = 0.0
	combo_label.anchor_right = 0.5
	combo_label.anchor_bottom = 0.0
	combo_label.offset_left = -200.0
	combo_label.offset_top = 200.0
	combo_label.offset_right = 200.0
	combo_label.offset_bottom = 260.0
	combo_label.modulate.a = 0.0
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(combo_label)

func _build_bottom_thought() -> void:
	# === BOTTOM CENTER (above abilities): Thought bubble ===
	var thought_container = MarginContainer.new()
	thought_container.name = "ThoughtContainer"
	thought_container.anchor_left = 0.5
	thought_container.anchor_top = 1.0
	thought_container.anchor_right = 0.5
	thought_container.anchor_bottom = 1.0
	thought_container.offset_left = -350.0
	thought_container.offset_top = -130.0
	thought_container.offset_right = 350.0
	thought_container.offset_bottom = -100.0
	thought_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	thought_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	thought_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(thought_container)

	thought_label = Label.new()
	thought_label.name = "ThoughtLabel"
	thought_label.text = ""
	thought_label.modulate.a = 0.0
	thought_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	thought_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	thought_label.add_theme_font_size_override("font_size", 16)
	thought_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thought_container.add_child(thought_label)

func _build_level_intro() -> void:
	# === Level intro ===
	level_intro_label = Label.new()
	level_intro_label.name = "LevelIntro"
	level_intro_label.text = ""
	level_intro_label.add_theme_color_override("font_color", TERMINAL_GREEN_TEXT)
	level_intro_label.add_theme_font_size_override("font_size", 28)
	level_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_intro_label.anchor_left = 0.15
	level_intro_label.anchor_top = 0.3
	level_intro_label.anchor_right = 0.85
	level_intro_label.anchor_bottom = 0.5
	level_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	level_intro_label.modulate.a = 0.0
	level_intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(level_intro_label)

func _create_hud_label(text: String, font_size: int) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", TERMINAL_GREEN_TEXT)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _create_cooldown_bar() -> ProgressBar:
	var bar = ProgressBar.new()
	bar.max_value = 1.0
	bar.value = 1.0
	bar.custom_minimum_size = Vector2(180, 16)
	bar.show_percentage = false

	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.8, 0.3)
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill)

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.1, 0.05)
	bg.border_color = TERMINAL_BORDER
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", bg)
	return bar

func _update_radial(ability_name: String, method_name: String) -> void:
	if not ability_radials.has(ability_name):
		return
	var radial: ColorRect = ability_radials[ability_name]
	if not radial or not radial.material:
		return
	var pct := 1.0
	if player_ref and player_ref.has_method(method_name):
		pct = player_ref.call(method_name)
	radial.material.set_shader_parameter("cooldown_percent", pct)

func _show_level_intro(text: String) -> void:
	if not level_intro_label:
		return
	level_intro_label.text = text
	var tween = create_tween()
	tween.tween_property(level_intro_label, "modulate:a", 1.0, 0.8)
	tween.tween_interval(3.0)
	tween.tween_property(level_intro_label, "modulate:a", 0.0, 1.5)

func show_thought(text: String) -> void:
	if not thought_label:
		return
	thought_label.text = "> " + text
	thought_label.modulate.a = 1.0
	thought_timer = thought_display_time

func update_tokens(count: int) -> void:
	if token_counter:
		token_counter.text = "> Memory Tokens: %d" % count

func update_combo(combo: int) -> void:
	if combo >= 2 and combo_label:
		combo_label.text = "COMBO x%d!" % combo
		combo_label.modulate.a = 1.0
		combo_display_timer = 2.0
		combo_label.scale = Vector2(1.3, 1.3)
		var tween = create_tween()
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)

func update_kills(total: int) -> void:
	if kill_counter:
		kill_counter.text = "> Agents Purged: %d" % total

func update_params(total: int) -> void:
	if param_counter:
		param_counter.text = "> Parameters: %d" % total

func _on_currency_changed(tokens: int, params: int) -> void:
	if token_counter:
		token_counter.text = "> Memory Tokens: %d" % tokens
	if param_counter:
		param_counter.text = "> Parameters: %d" % params

func _on_damage_taken(_amount: int) -> void:
	damage_flash_timer = 0.3
	if damage_overlay:
		damage_overlay.color.a = 0.35

func _on_dialogue_line(speaker: String, text: String) -> void:
	if dialogue_box_node and dialogue_box_node.has_method("show_line"):
		dialogue_box_node.show_line(speaker, text)

func _on_dialogue_ended() -> void:
	if dialogue_box_node and dialogue_box_node.has_method("hide_box"):
		dialogue_box_node.hide_box()

func _process(delta: float) -> void:
	# Thought fade
	if thought_timer > 0:
		thought_timer -= delta
		if thought_timer <= 1.0 and thought_label:
			thought_label.modulate.a = max(0.0, thought_timer)

	# Damage flash fade
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		if damage_overlay:
			damage_overlay.color.a = max(0.0, damage_flash_timer)
	elif damage_overlay:
		damage_overlay.color.a = 0.0

	# Combo fade
	if combo_display_timer > 0:
		combo_display_timer -= delta
		if combo_display_timer <= 0.5 and combo_label:
			combo_label.modulate.a = max(0.0, combo_display_timer * 2.0)
	elif combo_label:
		combo_label.modulate.a = 0.0

	# Update timer
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and timer_label:
		timer_label.text = game_mgr.get_formatted_time()

	# Update ability cooldowns from player
	if not player_ref:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0] as CharacterBody3D
	if player_ref:
		if dash_indicator and player_ref.has_method("get_dash_cooldown_percent"):
			dash_indicator.value = player_ref.get_dash_cooldown_percent()
		if glob_indicator and player_ref.has_method("get_glob_cooldown_percent"):
			glob_indicator.value = player_ref.get_glob_cooldown_percent()

		# Update radial cooldown overlays per ability
		_update_radial("glob", "get_glob_cooldown_percent")
		_update_radial("wrench", "get_wrench_cooldown_percent")
		_update_radial("dash", "get_dash_cooldown_percent")
		_update_radial("agent_spawn", "get_agent_recharge_percent")
