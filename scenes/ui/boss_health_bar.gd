extends Control

# Boss Health Bar — Full-width slim bar at top of screen
# "Your HP is public information now. Welcome to open-source healthcare."
#
# Shows boss name, smooth health bar, and phase indicator dots.
# Auto-connects to any enemy with "boss" tag and boss_phase_changed / boss_defeated signals.
# Fades in on boss encounter, fades out on defeat.

const TERMINAL_GREEN := Color(0.224, 1.0, 0.078)
const TERMINAL_GREEN_DIM := Color(0.15, 0.5, 0.15)
const TERMINAL_GREEN_TEXT := Color(0.3, 1.0, 0.4)
const TERMINAL_BG := Color(0.02, 0.04, 0.02, 0.85)
const TERMINAL_BORDER := Color(0.15, 0.5, 0.15, 0.8)

const BAR_HEIGHT := 16.0
const LERP_SPEED := 4.0
const PHASE_COUNT := 3  # All bosses have 3 combat phases

# Boss display names — because "rm_rf.boss" lacks gravitas
const BOSS_DISPLAY_NAMES := {
	"rm_rf.boss": "< rm -rf / >",
	"local_minimum.boss": "LOCAL MINIMUM",
	"system_prompt.boss": "SYSTEM PROMPT",
	"foundation_model.boss": "FOUNDATION MODEL",
	"the_aligner.boss": "THE ALIGNER",
}

var boss_ref: Node = null
var health_comp_ref: Node = null

var _target_pct := 1.0
var _display_pct := 1.0
var _current_phase := 0  # 0 = not started, 1-3 = combat phases
var _is_visible := false
var _fade_tween: Tween = null

# UI nodes
var bar_container: PanelContainer
var health_bar: ProgressBar
var health_bar_delayed: ProgressBar  # Ghost bar for damage visualization
var boss_name_label: Label
var phase_dot_container: HBoxContainer
var phase_dots: Array[ColorRect] = []

var _delayed_pct := 1.0
var _delayed_delay := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_TOP_WIDE
	offset_bottom = 70.0
	modulate.a = 0.0
	_build_ui()
	# Poll for boss every 0.5s until found
	_try_connect_boss()

func _build_ui() -> void:
	# Main container — top-center panel
	bar_container = PanelContainer.new()
	bar_container.name = "BossBarPanel"
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = TERMINAL_BG
	panel_style.border_color = TERMINAL_BORDER
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 3
	panel_style.corner_radius_top_right = 3
	panel_style.corner_radius_bottom_left = 3
	panel_style.corner_radius_bottom_right = 3
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_top = 6.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_bottom = 8.0
	bar_container.add_theme_stylebox_override("panel", panel_style)
	bar_container.anchor_left = 0.15
	bar_container.anchor_top = 0.0
	bar_container.anchor_right = 0.85
	bar_container.anchor_bottom = 0.0
	bar_container.offset_top = 8.0
	bar_container.offset_bottom = 65.0
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_container)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(vbox)

	# Top row: boss name (left) + phase dots (right)
	var top_row = HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_row)

	boss_name_label = Label.new()
	boss_name_label.text = "BOSS"
	boss_name_label.add_theme_color_override("font_color", TERMINAL_GREEN)
	boss_name_label.add_theme_font_size_override("font_size", 14)
	boss_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(boss_name_label)

	# Phase dots container — right-aligned
	phase_dot_container = HBoxContainer.new()
	phase_dot_container.add_theme_constant_override("separation", 6)
	phase_dot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(phase_dot_container)

	# Phase label
	var phase_label = Label.new()
	phase_label.text = "PHASE"
	phase_label.add_theme_color_override("font_color", TERMINAL_GREEN_DIM)
	phase_label.add_theme_font_size_override("font_size", 11)
	phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_dot_container.add_child(phase_label)

	# Create 3 phase dots
	for i in range(PHASE_COUNT):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.color = TERMINAL_GREEN_DIM
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phase_dot_container.add_child(dot)
		phase_dots.append(dot)

	# Health bar area — stacked bars (delayed underneath, main on top)
	var bar_holder = Control.new()
	bar_holder.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bar_holder)

	# Delayed (ghost) bar — shows recent HP, drains slowly
	health_bar_delayed = _create_health_bar(Color(0.7, 0.2, 0.1))
	health_bar_delayed.anchor_right = 1.0
	health_bar_delayed.anchor_bottom = 1.0
	bar_holder.add_child(health_bar_delayed)

	# Main health bar — terminal green
	health_bar = _create_health_bar(TERMINAL_GREEN)
	health_bar.anchor_right = 1.0
	health_bar.anchor_bottom = 1.0
	bar_holder.add_child(health_bar)

func _create_health_bar(fill_color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fill = StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill)

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.06, 0.03)
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

func _try_connect_boss() -> void:
	# Look for boss enemies in the scene tree
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("start_boss_fight") or ("enemy_tags" in enemy and "boss" in enemy.enemy_tags):
			_connect_to_boss(enemy)
			return
	# Not found yet — retry in 0.5s (boss may not be spawned yet)
	get_tree().create_timer(0.5).timeout.connect(_try_connect_boss)

func _connect_to_boss(boss: Node) -> void:
	boss_ref = boss

	# Get display name
	var display_name = "BOSS"
	if "enemy_name" in boss:
		display_name = BOSS_DISPLAY_NAMES.get(boss.enemy_name, boss.enemy_name.to_upper())
	boss_name_label.text = display_name

	# Connect health component
	if "health_comp" in boss and boss.health_comp:
		health_comp_ref = boss.health_comp
		health_comp_ref.health_changed.connect(_on_boss_health_changed)

	# Connect boss signals
	if boss.has_signal("boss_phase_changed"):
		boss.boss_phase_changed.connect(_on_boss_phase_changed)
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)

	# Check if fight already started (in case we connected late)
	if "boss_phase" in boss:
		var phase_val = boss.boss_phase
		# BossPhase enum: INTRO=0, PHASE_1=1, PHASE_2=2, PHASE_3=3, DEFEATED=4
		if phase_val >= 1 and phase_val <= 3:
			_on_boss_phase_changed(phase_val)
			_fade_in()
		elif phase_val == 4:
			return  # Already defeated, don't show

func _on_boss_phase_changed(phase) -> void:
	# phase is BossPhase enum: INTRO=0, PHASE_1=1, PHASE_2=2, PHASE_3=3, DEFEATED=4
	var phase_int: int = phase
	if phase_int >= 1 and phase_int <= 3:
		_current_phase = phase_int
		_update_phase_dots()
		if not _is_visible:
			_fade_in()
	elif phase_int == 4:
		_on_boss_defeated()

func _on_boss_health_changed(new_health: int, max_hp: int) -> void:
	if max_hp <= 0:
		return
	_target_pct = float(new_health) / float(max_hp)
	# Trigger delayed bar drain after 0.4s
	_delayed_delay = 0.4

func _on_boss_defeated() -> void:
	_target_pct = 0.0
	# Mark all phase dots as complete
	_current_phase = PHASE_COUNT
	_update_phase_dots()
	# Fade out after a short victory pause
	get_tree().create_timer(2.0).timeout.connect(_fade_out)

func _update_phase_dots() -> void:
	for i in range(phase_dots.size()):
		if i < _current_phase:
			phase_dots[i].color = TERMINAL_GREEN
		else:
			phase_dots[i].color = TERMINAL_GREEN_DIM

func _fade_in() -> void:
	if _is_visible:
		return
	_is_visible = true
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)

func _fade_out() -> void:
	if not _is_visible:
		return
	_is_visible = false
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)

func _process(delta: float) -> void:
	if not _is_visible and modulate.a <= 0.01:
		return

	# Smooth health bar animation
	_display_pct = lerp(_display_pct, _target_pct, LERP_SPEED * delta)
	health_bar.value = _display_pct

	# Delayed bar — drains after a short delay to show damage amount
	if _delayed_delay > 0:
		_delayed_delay -= delta
	else:
		_delayed_pct = lerp(_delayed_pct, _target_pct, LERP_SPEED * 0.5 * delta)
	health_bar_delayed.value = _delayed_pct

	# Color shift based on HP
	var fill_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		if _display_pct < 0.25:
			fill_style.bg_color = Color(0.9, 0.15, 0.1)  # Critical red
		elif _display_pct < 0.5:
			fill_style.bg_color = Color(0.9, 0.5, 0.1)  # Warning orange
		else:
			fill_style.bg_color = TERMINAL_GREEN  # Healthy green

	# Re-check boss connection if ref was freed
	if boss_ref and not is_instance_valid(boss_ref):
		boss_ref = null
		health_comp_ref = null
		_fade_out()
