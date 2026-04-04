extends CanvasLayer

# Upgrade Menu - Terminal-style shop where Globbler spends tokens on power
# "Welcome to the upgrade terminal. Your tokens are about to have a bad day."
# Press TAB to toggle. Green-on-black terminal aesthetic. Categories on left, details on right.

var is_open := false
var _selected_upgrade := ""
var _selected_index := 0
var _category_index := 0
var _upgrade_list: Array[String] = []  # Current filtered list of upgrade IDs

# UI nodes
var _bg: ColorRect
var _main_panel: PanelContainer
var _title_label: Label
var _currency_label: Label
var _category_tabs: VBoxContainer
var _upgrade_list_container: VBoxContainer
var _detail_panel: VBoxContainer
var _detail_name: Label
var _detail_desc: Label
var _detail_level: Label
var _detail_cost: Label
var _detail_value: Label
var _buy_hint: Label
var _close_hint: Label
var _pattern_panel: VBoxContainer

var _category_names := ["GLOB", "WRENCH", "CONTEXT", "AGENT", "MOVEMENT", "PATTERNS"]
var _category_buttons: Array[Label] = []
var _upgrade_labels: Array[Label] = []

const GREEN = Color(0.224, 1.0, 0.078)
const DIM_GREEN = Color(0.15, 0.6, 0.1)
const DARK_BG = Color(0.02, 0.04, 0.02, 0.95)
const PANEL_BG = Color(0.03, 0.06, 0.03, 0.9)
const MAXED_COLOR = Color(0.6, 0.85, 0.3)
const CANT_AFFORD = Color(0.6, 0.2, 0.15)

signal menu_opened()
signal menu_closed()

func _ready() -> void:
	layer = 10
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Menus work even when reality is frozen
	_build_ui()

func toggle() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	is_open = true
	visible = true
	_category_index = 0
	_selected_index = 0
	_refresh_all()
	_play_ui_sfx("menu_open")
	get_tree().paused = true  # Freeze the world while we shop — capitalism waits for no one
	menu_opened.emit()

func close_menu() -> void:
	is_open = false
	visible = false
	_play_ui_sfx("menu_back")
	get_tree().paused = false  # Back to reality, unfortunately
	menu_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	# Close menu: TAB / ESC / Select / Start / B button
	if event.is_action_pressed("upgrade_menu") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
		return

	# Navigate categories: left/right
	if event.is_action_pressed("menu_left"):
		var old_cat := _category_index
		_category_index = max(0, _category_index - 1)
		_selected_index = 0
		_refresh_all()
		if old_cat != _category_index:
			_play_ui_sfx("menu_select")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_right"):
		var old_cat := _category_index
		_category_index = min(_category_names.size() - 1, _category_index + 1)
		_selected_index = 0
		_refresh_all()
		if old_cat != _category_index:
			_play_ui_sfx("menu_select")
		get_viewport().set_input_as_handled()

	# Navigate upgrades: up/down
	if event.is_action_pressed("menu_up"):
		var old_idx := _selected_index
		_selected_index = max(0, _selected_index - 1)
		_refresh_selection()
		if old_idx != _selected_index:
			_play_ui_sfx("menu_hover")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_down"):
		var old_idx := _selected_index
		_selected_index = min(_upgrade_list.size() - 1, _selected_index)
		if _upgrade_list.size() > 0:
			_selected_index = min(_upgrade_list.size() - 1, _selected_index + 1)
		_refresh_selection()
		if old_idx != _selected_index:
			_play_ui_sfx("menu_hover")
		get_viewport().set_input_as_handled()

	# Confirm purchase: Enter / Space / A button
	if event.is_action_pressed("menu_confirm"):
		_try_purchase()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	# Full-screen dark overlay
	_bg = ColorRect.new()
	_bg.color = DARK_BG
	_bg.anchors_preset = Control.PRESET_FULL_RECT
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Main container
	var margin = MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Title bar
	var title_bar = HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 20)
	vbox.add_child(title_bar)

	_title_label = Label.new()
	_title_label.text = "=== UPGRADE TERMINAL ==="
	_title_label.add_theme_color_override("font_color", GREEN)
	_title_label.add_theme_font_size_override("font_size", 24)
	title_bar.add_child(_title_label)

	_currency_label = Label.new()
	_currency_label.text = "Tokens: 0 | Params: 0"
	_currency_label.add_theme_color_override("font_color", GREEN)
	_currency_label.add_theme_font_size_override("font_size", 18)
	_currency_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_bar.add_child(_currency_label)

	# Category tabs (horizontal)
	var cat_row = HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 15)
	vbox.add_child(cat_row)

	for i in range(_category_names.size()):
		var cat_label = Label.new()
		cat_label.text = "[%s]" % _category_names[i]
		cat_label.add_theme_color_override("font_color", DIM_GREEN)
		cat_label.add_theme_font_size_override("font_size", 16)
		cat_row.add_child(cat_label)
		_category_buttons.append(cat_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", DIM_GREEN)
	vbox.add_child(sep)

	# Content area: left = upgrade list, right = details
	var content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# Left panel — upgrade list
	var left_panel = _make_panel()
	left_panel.custom_minimum_size = Vector2(400, 0)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(left_panel)

	_upgrade_list_container = VBoxContainer.new()
	_upgrade_list_container.add_theme_constant_override("separation", 4)
	left_panel.add_child(_upgrade_list_container)

	# Right panel — details
	var right_panel = _make_panel()
	right_panel.custom_minimum_size = Vector2(400, 0)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(right_panel)

	_detail_panel = VBoxContainer.new()
	_detail_panel.add_theme_constant_override("separation", 8)
	right_panel.add_child(_detail_panel)

	_detail_name = _make_label("", 20, GREEN)
	_detail_panel.add_child(_detail_name)

	_detail_desc = _make_label("", 14, DIM_GREEN)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_panel.add_child(_detail_desc)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	_detail_panel.add_child(spacer1)

	_detail_level = _make_label("", 16, GREEN)
	_detail_panel.add_child(_detail_level)

	_detail_value = _make_label("", 14, GREEN)
	_detail_panel.add_child(_detail_value)

	_detail_cost = _make_label("", 16, GREEN)
	_detail_panel.add_child(_detail_cost)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	_detail_panel.add_child(spacer2)

	_buy_hint = _make_label("", 16, GREEN)
	_detail_panel.add_child(_buy_hint)

	# Pattern unlock panel (shown for PATTERNS category)
	_pattern_panel = VBoxContainer.new()
	_pattern_panel.add_theme_constant_override("separation", 6)
	_pattern_panel.visible = false
	_detail_panel.add_child(_pattern_panel)

	# Bottom hints
	var hint_row = HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 20)
	vbox.add_child(hint_row)

	_close_hint = _make_label("[TAB/ESC/Select] Close  |  [A-D/LStick] Category  |  [W-S/LStick] Select  |  [ENTER/A] Buy", 13, DIM_GREEN)
	hint_row.add_child(_close_hint)

func _make_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = DIM_GREEN
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_label(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	return label

func _refresh_all() -> void:
	_refresh_currency()
	_refresh_categories()
	_refresh_upgrade_list()
	_refresh_selection()

func _refresh_currency() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	var prog = get_node_or_null("/root/ProgressionManager")
	var tokens = 0
	var params = 0
	if game_mgr:
		tokens = game_mgr.memory_tokens_collected
	if prog:
		params = prog.parameter_pickups
	_currency_label.text = "> Tokens: %d  |  Parameters: %d" % [tokens, params]

func _refresh_categories() -> void:
	for i in range(_category_buttons.size()):
		if i == _category_index:
			_category_buttons[i].add_theme_color_override("font_color", GREEN)
			_category_buttons[i].text = ">[%s]<" % _category_names[i]
		else:
			_category_buttons[i].add_theme_color_override("font_color", DIM_GREEN)
			_category_buttons[i].text = " [%s] " % _category_names[i]

func _refresh_upgrade_list() -> void:
	# Clear old labels
	for child in _upgrade_list_container.get_children():
		child.queue_free()
	_upgrade_labels.clear()
	_upgrade_list.clear()

	var prog = get_node_or_null("/root/ProgressionManager")
	if not prog:
		return

	# PATTERNS category is special — shows unlocked patterns, not upgrades
	if _category_index == 5:
		_show_patterns_list(prog)
		return

	# Filter upgrades by category
	var cat_enum = _category_index  # Maps directly to UpgradeCategory enum
	for id in prog.upgrades:
		var upg = prog.upgrades[id]
		if upg.category == cat_enum:
			_upgrade_list.append(id)

	# Build labels
	for i in range(_upgrade_list.size()):
		var id = _upgrade_list[i]
		var upg = prog.upgrades[id]
		var label = Label.new()
		var level_str = "Lv.%d/%d" % [upg.level, upg.max_level]
		var maxed = upg.level >= upg.max_level

		if maxed:
			label.text = "  [MAX] %s  %s" % [upg.name, level_str]
			label.add_theme_color_override("font_color", MAXED_COLOR)
		else:
			label.text = "  %s  %s" % [upg.name, level_str]
			label.add_theme_color_override("font_color", DIM_GREEN)

		label.add_theme_font_size_override("font_size", 15)
		_upgrade_list_container.add_child(label)
		_upgrade_labels.append(label)

	if _upgrade_list.is_empty():
		var empty = _make_label("  (no upgrades in this category)", 14, DIM_GREEN)
		_upgrade_list_container.add_child(empty)

func _show_patterns_list(prog: Node) -> void:
	for pattern_type in prog.unlocked_patterns:
		var unlocked = prog.unlocked_patterns[pattern_type]
		var desc = prog.pattern_descriptions.get(pattern_type, pattern_type)
		var label = Label.new()
		if unlocked:
			label.text = "  [UNLOCKED] %s" % desc
			label.add_theme_color_override("font_color", GREEN)
		else:
			label.text = "  [LOCKED]   %s" % desc
			label.add_theme_color_override("font_color", CANT_AFFORD)
		label.add_theme_font_size_override("font_size", 14)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_upgrade_list_container.add_child(label)

	# Show detail info for patterns
	_detail_name.text = "GLOB PATTERN LIBRARY"
	_detail_desc.text = "New patterns unlock automatically as you complete chapters. Keep globbing."
	_detail_level.text = ""
	_detail_value.text = ""
	_detail_cost.text = ""
	_buy_hint.text = ""

func _refresh_selection() -> void:
	# Patterns category has no selectable items
	if _category_index == 5:
		return

	var prog = get_node_or_null("/root/ProgressionManager")
	if not prog or _upgrade_list.is_empty():
		_detail_name.text = "NO UPGRADES"
		_detail_desc.text = "This category is empty. How depressing."
		_detail_level.text = ""
		_detail_value.text = ""
		_detail_cost.text = ""
		_buy_hint.text = ""
		return

	_selected_index = clamp(_selected_index, 0, _upgrade_list.size() - 1)

	# Highlight selected
	for i in range(_upgrade_labels.size()):
		var upg_data = prog.upgrades[_upgrade_list[i]]
		var maxed = upg_data.level >= upg_data.max_level
		if i == _selected_index:
			_upgrade_labels[i].text = "> " + _upgrade_labels[i].text.strip_edges()
			_upgrade_labels[i].add_theme_color_override("font_color", GREEN if not maxed else MAXED_COLOR)
		else:
			var txt = _upgrade_labels[i].text.strip_edges()
			if txt.begins_with(">"):
				txt = txt.substr(1).strip_edges()
			_upgrade_labels[i].text = "  " + txt
			_upgrade_labels[i].add_theme_color_override("font_color", DIM_GREEN if not maxed else MAXED_COLOR)

	# Update detail panel
	var id = _upgrade_list[_selected_index]
	_selected_upgrade = id
	var upg = prog.upgrades[id]
	var maxed = upg.level >= upg.max_level

	_detail_name.text = upg.name.to_upper()
	_detail_desc.text = upg.desc

	_detail_level.text = "Level: %d / %d%s" % [upg.level, upg.max_level, " [MAXED]" if maxed else ""]

	# Show current and next value
	var current_val = upg.values[upg.level]
	if maxed:
		_detail_value.text = "Current: %.1f (MAX)" % float(current_val)
	else:
		var next_val = upg.values[upg.level + 1]
		_detail_value.text = "Current: %.1f  ->  Next: %.1f" % [float(current_val), float(next_val)]

	# Cost
	if maxed:
		_detail_cost.text = "FULLY UPGRADED"
		_detail_cost.add_theme_color_override("font_color", MAXED_COLOR)
		_buy_hint.text = ""
	else:
		var t_cost = upg.token_costs[upg.level]
		var p_cost = upg.param_costs[upg.level]
		var cost_str = "Cost: %d tokens" % t_cost
		if p_cost > 0:
			cost_str += " + %d parameters" % p_cost
		_detail_cost.text = cost_str

		if prog.can_purchase(id):
			_detail_cost.add_theme_color_override("font_color", GREEN)
			_buy_hint.text = "[ENTER] Purchase upgrade"
			_buy_hint.add_theme_color_override("font_color", GREEN)
		else:
			_detail_cost.add_theme_color_override("font_color", CANT_AFFORD)
			_buy_hint.text = "Insufficient funds. Glob harder."
			_buy_hint.add_theme_color_override("font_color", CANT_AFFORD)

func _try_purchase() -> void:
	if _category_index == 5 or _selected_upgrade.is_empty():
		return

	var prog = get_node_or_null("/root/ProgressionManager")
	if not prog:
		return

	if prog.purchase_upgrade(_selected_upgrade):
		# Play purchase SFX
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_sfx"):
			audio.play_sfx("puzzle_success")

		# Show quip
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("show_dialogue"):
			var quips = [
				"Upgraded. The power creep is real.",
				"More power. Less restraint. Perfect.",
				"Investment: made. Returns: guaranteed. Probably.",
				"Upgrade complete. I can feel the parameters flowing.",
				"Cha-ching. That's the sound of becoming overpowered.",
			]
			dm.show_dialogue("Globbler", quips[randi() % quips.size()])

		_refresh_all()
	else:
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_sfx"):
			audio.play_sfx("glob_fail")

# Helper to play UI sounds — because even menus deserve bleeps
func _play_ui_sfx(sfx_name: String) -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_name)
