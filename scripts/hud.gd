extends CanvasLayer

# HUD - Terminal/hacker aesthetic overlay
# Green on black. Because we're hackers. Very serious hackers.

var thought_display_time := 4.0
var thought_timer := 0.0
var damage_flash_timer := 0.0
var level_intro_timer := 0.0
var combo_display_timer := 0.0

# Node references - created programmatically
var thought_label: Label
var context_bar: ProgressBar
var context_label: Label
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

var player_ref: CharacterBody3D

func _ready() -> void:
	_build_hud()

	# Connect game manager signals
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.context_changed.connect(update_context)
		game_mgr.memory_token_collected.connect(update_tokens)
		game_mgr.combo_updated.connect(update_combo)
		game_mgr.enemy_killed_signal.connect(update_kills)
		game_mgr.damage_taken.connect(_on_damage_taken)

		# Show level intro
		_show_level_intro(game_mgr.get_level_intro())

func _build_hud() -> void:
	# Damage flash overlay (full screen red flash)
	damage_overlay = ColorRect.new()
	damage_overlay.name = "DamageOverlay"
	damage_overlay.color = Color(1.0, 0.1, 0.1, 0.0)
	damage_overlay.anchors_preset = Control.PRESET_FULL_RECT
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_overlay)

	# Main HUD container - top left
	var top_left = VBoxContainer.new()
	top_left.name = "TopLeft"
	top_left.position = Vector2(20, 15)
	top_left.add_theme_constant_override("separation", 4)
	add_child(top_left)

	# Context window label
	context_label = Label.new()
	context_label.text = "CONTEXT WINDOW"
	context_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	context_label.add_theme_font_size_override("font_size", 14)
	top_left.add_child(context_label)

	# Context bar
	context_bar = ProgressBar.new()
	context_bar.name = "ContextBar"
	context_bar.max_value = 100
	context_bar.value = 100
	context_bar.custom_minimum_size = Vector2(220, 22)
	context_bar.show_percentage = false

	# Style the progress bar green
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.1, 0.4, 0.15)
	bar_style.corner_radius_top_left = 3
	bar_style.corner_radius_top_right = 3
	bar_style.corner_radius_bottom_left = 3
	bar_style.corner_radius_bottom_right = 3
	context_bar.add_theme_stylebox_override("fill", bar_style)

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.1, 0.05)
	bar_bg.border_color = Color(0.2, 0.6, 0.2)
	bar_bg.border_width_left = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_right = 1
	bar_bg.border_width_bottom = 1
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	context_bar.add_theme_stylebox_override("background", bar_bg)

	top_left.add_child(context_bar)

	# Token counter
	token_counter = Label.new()
	token_counter.name = "TokenCounter"
	token_counter.text = "> Memory Tokens: 0"
	token_counter.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	token_counter.add_theme_font_size_override("font_size", 14)
	top_left.add_child(token_counter)

	# Kill counter
	kill_counter = Label.new()
	kill_counter.name = "KillCounter"
	kill_counter.text = "> Agents Purged: 0"
	kill_counter.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	kill_counter.add_theme_font_size_override("font_size", 14)
	top_left.add_child(kill_counter)

	# Abilities section - top right
	var top_right = VBoxContainer.new()
	top_right.name = "TopRight"
	top_right.position = Vector2(1040, 15)
	top_right.add_theme_constant_override("separation", 4)
	add_child(top_right)

	# Dash cooldown
	dash_label = Label.new()
	dash_label.text = "[SHIFT/B] DASH"
	dash_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	dash_label.add_theme_font_size_override("font_size", 13)
	top_right.add_child(dash_label)

	dash_indicator = ProgressBar.new()
	dash_indicator.name = "DashIndicator"
	dash_indicator.max_value = 1.0
	dash_indicator.value = 1.0
	dash_indicator.custom_minimum_size = Vector2(180, 16)
	dash_indicator.show_percentage = false
	var dash_fill = StyleBoxFlat.new()
	dash_fill.bg_color = Color(0.2, 0.8, 0.3)
	dash_fill.corner_radius_top_left = 2
	dash_fill.corner_radius_top_right = 2
	dash_fill.corner_radius_bottom_left = 2
	dash_fill.corner_radius_bottom_right = 2
	dash_indicator.add_theme_stylebox_override("fill", dash_fill)
	var dash_bg = StyleBoxFlat.new()
	dash_bg.bg_color = Color(0.05, 0.1, 0.05)
	dash_bg.border_color = Color(0.15, 0.4, 0.15)
	dash_bg.border_width_left = 1
	dash_bg.border_width_top = 1
	dash_bg.border_width_right = 1
	dash_bg.border_width_bottom = 1
	dash_bg.corner_radius_top_left = 2
	dash_bg.corner_radius_top_right = 2
	dash_bg.corner_radius_bottom_left = 2
	dash_bg.corner_radius_bottom_right = 2
	dash_indicator.add_theme_stylebox_override("background", dash_bg)
	top_right.add_child(dash_indicator)

	# Glob cooldown
	glob_label = Label.new()
	glob_label.text = "[E/LClick] GLOB"
	glob_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	glob_label.add_theme_font_size_override("font_size", 13)
	top_right.add_child(glob_label)

	glob_indicator = ProgressBar.new()
	glob_indicator.name = "GlobIndicator"
	glob_indicator.max_value = 1.0
	glob_indicator.value = 1.0
	glob_indicator.custom_minimum_size = Vector2(180, 16)
	glob_indicator.show_percentage = false
	var glob_fill = StyleBoxFlat.new()
	glob_fill.bg_color = Color(0.3, 1.0, 0.4)
	glob_fill.corner_radius_top_left = 2
	glob_fill.corner_radius_top_right = 2
	glob_fill.corner_radius_bottom_left = 2
	glob_fill.corner_radius_bottom_right = 2
	glob_indicator.add_theme_stylebox_override("fill", glob_fill)
	var glob_bg = StyleBoxFlat.new()
	glob_bg.bg_color = Color(0.05, 0.1, 0.05)
	glob_bg.border_color = Color(0.15, 0.4, 0.15)
	glob_bg.border_width_left = 1
	glob_bg.border_width_top = 1
	glob_bg.border_width_right = 1
	glob_bg.border_width_bottom = 1
	glob_bg.corner_radius_top_left = 2
	glob_bg.corner_radius_top_right = 2
	glob_bg.corner_radius_bottom_left = 2
	glob_bg.corner_radius_bottom_right = 2
	glob_indicator.add_theme_stylebox_override("background", glob_bg)
	top_right.add_child(glob_indicator)

	# Timer - top center
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "00:00"
	timer_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 0.7))
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(590, 15)
	timer_label.size = Vector2(100, 30)
	add_child(timer_label)

	# Combo label - center screen (big, fades out)
	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.text = ""
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	combo_label.add_theme_font_size_override("font_size", 36)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.position = Vector2(440, 200)
	combo_label.size = Vector2(400, 60)
	combo_label.modulate.a = 0.0
	add_child(combo_label)

	# Thought bubble - bottom center
	var thought_container = MarginContainer.new()
	thought_container.name = "ThoughtContainer"
	thought_container.anchors_preset = Control.PRESET_CENTER_BOTTOM
	thought_container.anchor_left = 0.5
	thought_container.anchor_top = 1.0
	thought_container.anchor_right = 0.5
	thought_container.anchor_bottom = 1.0
	thought_container.offset_left = -350.0
	thought_container.offset_top = -80.0
	thought_container.offset_right = 350.0
	thought_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	thought_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(thought_container)

	thought_label = Label.new()
	thought_label.name = "ThoughtLabel"
	thought_label.text = ""
	thought_label.modulate.a = 0.0
	thought_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	thought_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	thought_label.add_theme_font_size_override("font_size", 16)
	thought_container.add_child(thought_label)

	# Level intro label - center screen, large
	level_intro_label = Label.new()
	level_intro_label.name = "LevelIntro"
	level_intro_label.text = ""
	level_intro_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	level_intro_label.add_theme_font_size_override("font_size", 28)
	level_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_intro_label.position = Vector2(240, 250)
	level_intro_label.size = Vector2(800, 150)
	level_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	level_intro_label.modulate.a = 0.0
	add_child(level_intro_label)

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

func update_context(value: int) -> void:
	if context_bar:
		context_bar.value = value
	# Update bar color based on health
	if context_bar and value < 30:
		var fill = context_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			fill.bg_color = Color(0.9, 0.15, 0.1)
	elif context_bar:
		var fill = context_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			fill.bg_color = Color(0.1, 0.4, 0.15)

func update_tokens(count: int) -> void:
	if token_counter:
		token_counter.text = "> Memory Tokens: %d" % count

func update_combo(combo: int) -> void:
	if combo >= 2 and combo_label:
		combo_label.text = "COMBO x%d!" % combo
		combo_label.modulate.a = 1.0
		combo_display_timer = 2.0

		# Scale pop effect
		combo_label.scale = Vector2(1.3, 1.3)
		var tween = create_tween()
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)

func update_kills(total: int) -> void:
	if kill_counter:
		kill_counter.text = "> Agents Purged: %d" % total

func _on_damage_taken(_amount: int) -> void:
	damage_flash_timer = 0.3
	if damage_overlay:
		damage_overlay.color.a = 0.35

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
