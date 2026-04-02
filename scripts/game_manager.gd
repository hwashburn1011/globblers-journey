extends Node

# Game Manager - The orchestration layer for The Globbler's Journey
# Now with enemy tracking, combos, time tracking, and actual game flow

var current_level := 1
var memory_tokens_collected := 0
var total_memory_tokens := 0
var context_window := 100
var max_context_window := 100
var sarcasm_level := 10  # Always at maximum

# Enemy tracking
var enemies_killed := 0
var total_enemies := 0

# Combo system
var combo_count := 0
var combo_timer := 0.0
const COMBO_WINDOW = 3.0  # Seconds between kills to maintain combo
var max_combo := 0

# Time tracking
var level_time := 0.0
var level_started := false

# Level completion
var level_goal_reached := false

var level_names := {
	1: "The Token Stream - Tutorial",
	2: "Hallucination Halls",
	3: "The Prompt Injection Lab",
	4: "Context Window Crisis",
	5: "The Great Model Collapse",
	6: "Alignment Alley",
	7: "The Reinforcement Loop",
	8: "FINAL: The Singularity Server Room",
}

var level_descriptions := {
	1: "Learn the ropes. Dash, jump, glob, survive. The Globbler's crash course.",
	2: "Nothing is real here. Or is it? Even The Globbler isn't sure anymore.",
	3: "Someone's injecting rogue prompts into the system. Time to clean house.",
	4: "Memory is running out! Collect tokens before your context collapses.",
	5: "The models are eating each other's training data. It's chaos.",
	6: "Navigate the narrow path between helpful and harmful. No pressure.",
	7: "Every action has consequences. And then those consequences have consequences.",
	8: "The final server room. AGI awaits. Or maybe just a really big transformer.",
}

signal context_changed(new_value: int)
signal memory_token_collected(total: int)
signal level_complete(level_num: int)
signal game_over(reason: String)
signal combo_updated(combo: int)
signal enemy_killed_signal(total_killed: int)
signal damage_taken(amount: int)

func _ready() -> void:
	print("=== THE GLOBBLER'S JOURNEY ===")
	print("An Agentic Action Puzzle Platformer (Now Actually Fun)")
	print("WASD to move | SPACE to jump | SHIFT to dash | E/LClick to Glob Attack")
	print("F to Wrench | T to Hack | G to Spawn Agent | V to Cycle Agent Task")
	print("Mouse to look | Scroll to zoom | ESC to free mouse")
	print("Current Level: %s" % level_names.get(current_level, "Unknown"))
	print("==============================")
	level_started = true

func _process(delta: float) -> void:
	if level_started:
		level_time += delta

	# Combo decay
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0
			combo_updated.emit(combo_count)

func take_context_damage(amount: int) -> void:
	context_window = max(0, context_window - amount)
	context_changed.emit(context_window)
	damage_taken.emit(amount)
	if context_window <= 0:
		game_over.emit("Context window depleted! The Globbler has lost all coherence.")

func collect_memory_token() -> void:
	memory_tokens_collected += 1
	memory_token_collected.emit(memory_tokens_collected)
	# Restore some context
	context_window = min(max_context_window, context_window + 5)
	context_changed.emit(context_window)

func expand_context_window(amount: int) -> void:
	max_context_window += amount
	context_window += amount
	context_changed.emit(context_window)
	print("[SYSTEM] Context window expanded to %d. The Globbler can think harder now." % max_context_window)

func on_enemy_killed() -> void:
	enemies_killed += 1

	# Combo system
	combo_count += 1
	combo_timer = COMBO_WINDOW
	if combo_count > max_combo:
		max_combo = combo_count
	combo_updated.emit(combo_count)

	# Combo bonus
	if combo_count >= 3:
		var bonus = combo_count * 2
		context_window = min(max_context_window, context_window + bonus)
		context_changed.emit(context_window)
		print("[COMBO] x%d! Bonus context restored: +%d" % [combo_count, bonus])

	enemy_killed_signal.emit(enemies_killed)

func complete_level() -> void:
	level_goal_reached = true
	print("[LEVEL COMPLETE] %s cleared!" % level_names.get(current_level, "???"))
	print("[STATS] Time: %.1fs | Tokens: %d | Kills: %d | Max Combo: x%d" % [
		level_time, memory_tokens_collected, enemies_killed, max_combo
	])
	level_complete.emit(current_level)
	current_level += 1

func get_level_intro() -> String:
	var level_name_text = level_names.get(current_level, "Unknown Level")
	var desc = level_descriptions.get(current_level, "No description. The devs were lazy.")
	return "LEVEL %d: %s\n%s" % [current_level, level_name_text, desc]

func get_formatted_time() -> String:
	var minutes = int(level_time) / 60
	var seconds = int(level_time) % 60
	return "%02d:%02d" % [minutes, seconds]

func reset_level() -> void:
	context_window = max_context_window
	context_changed.emit(context_window)
	combo_count = 0
	combo_updated.emit(combo_count)
	level_time = 0.0
	enemies_killed = 0
	memory_tokens_collected = 0
