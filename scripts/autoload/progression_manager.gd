extends Node

# Progression Manager - The upgrade economy for Globbler's ever-growing power
# "More upgrades = more chaos. That's just math."
# Tracks currency, upgrade levels, unlocked glob patterns, and parameter pickups.

# === CURRENCY ===
# Memory tokens are the basic currency (already tracked in GameManager)
# Parameter Pickups are rare upgrade materials found in exploration

var parameter_pickups := 0  # Rare materials for upgrades

# === UPGRADE DEFINITIONS ===
# Each upgrade has: id, name, description, max_level, cost per level, stat affected
# Costs are [tokens_cost, params_cost] per level

enum UpgradeCategory { GLOB, WRENCH, CONTEXT, AGENT, MOVEMENT }

# Upgrade data: { max_level, costs_per_level, current_level }
var upgrades := {
	# Glob upgrades — because pattern matching should be AGGRESSIVE
	"glob_range": {
		"name": "Signal Amplifier",
		"desc": "Extends glob beam targeting range. More reach, more carnage.",
		"category": UpgradeCategory.GLOB,
		"max_level": 3,
		"token_costs": [8, 15, 25],
		"param_costs": [0, 1, 2],
		"level": 0,
		"values": [20.0, 25.0, 30.0, 36.0],  # Base + per level
	},
	"glob_radius": {
		"name": "Wide-Band Matcher",
		"desc": "Expands glob impact area. Catch more, apologize later.",
		"category": UpgradeCategory.GLOB,
		"max_level": 3,
		"token_costs": [10, 18, 30],
		"param_costs": [0, 1, 2],
		"level": 0,
		"values": [6.0, 8.0, 10.0, 13.0],
	},
	"glob_cooldown": {
		"name": "Pipeline Optimizer",
		"desc": "Reduces glob command cooldown. Spam *.everything faster.",
		"category": UpgradeCategory.GLOB,
		"max_level": 3,
		"token_costs": [12, 20, 35],
		"param_costs": [1, 1, 3],
		"level": 0,
		"values": [1.5, 1.2, 0.9, 0.6],
	},
	# Wrench upgrades — percussive maintenance at its finest
	"wrench_damage": {
		"name": "Torque Amplifier",
		"desc": "Increases wrench damage. Hit harder, debug faster.",
		"category": UpgradeCategory.WRENCH,
		"max_level": 3,
		"token_costs": [8, 16, 28],
		"param_costs": [0, 1, 2],
		"level": 0,
		"values": [2, 3, 4, 6],
	},
	"wrench_knockback": {
		"name": "Impulse Driver",
		"desc": "More knockback on wrench hits. Send 'em flying.",
		"category": UpgradeCategory.WRENCH,
		"max_level": 2,
		"token_costs": [6, 14],
		"param_costs": [0, 1],
		"level": 0,
		"values": [12.0, 16.0, 22.0],
	},
	"wrench_speed": {
		"name": "Overclock Swing",
		"desc": "Faster wrench attack cooldown. Bonk bonk bonk.",
		"category": UpgradeCategory.WRENCH,
		"max_level": 2,
		"token_costs": [10, 20],
		"param_costs": [1, 2],
		"level": 0,
		"values": [0.6, 0.45, 0.3],
	},
	# Context window (health) upgrades — bigger brain = harder to kill
	"context_size": {
		"name": "Context Expansion",
		"desc": "Increases max context window (health). Think bigger, die less.",
		"category": UpgradeCategory.CONTEXT,
		"max_level": 4,
		"token_costs": [5, 10, 18, 30],
		"param_costs": [0, 0, 1, 2],
		"level": 0,
		"values": [100, 125, 150, 180, 220],
	},
	"context_regen": {
		"name": "Token Absorption Rate",
		"desc": "Memory tokens restore more context on pickup.",
		"category": UpgradeCategory.CONTEXT,
		"max_level": 3,
		"token_costs": [6, 12, 22],
		"param_costs": [0, 1, 1],
		"level": 0,
		"values": [5, 8, 12, 18],  # HP restored per token
	},
	# Agent spawn upgrades — make the tiny idiots slightly less useless
	"agent_charges": {
		"name": "Fork Bomb Lite",
		"desc": "More sub-agent charges. More tiny idiots at your service.",
		"category": UpgradeCategory.AGENT,
		"max_level": 2,
		"token_costs": [12, 25],
		"param_costs": [1, 2],
		"level": 0,
		"values": [3, 4, 5],
	},
	"agent_recharge": {
		"name": "Spawn Scheduler",
		"desc": "Faster sub-agent charge recharge. Less waiting, more failing.",
		"category": UpgradeCategory.AGENT,
		"max_level": 2,
		"token_costs": [10, 20],
		"param_costs": [1, 2],
		"level": 0,
		"values": [12.0, 9.0, 6.0],
	},
	# Movement — gotta go fast
	"dash_cooldown": {
		"name": "Burst Cache",
		"desc": "Reduces dash cooldown. Zoom zoom.",
		"category": UpgradeCategory.MOVEMENT,
		"max_level": 2,
		"token_costs": [8, 18],
		"param_costs": [0, 1],
		"level": 0,
		"values": [0.8, 0.6, 0.4],
	},
}

# === GLOB PATTERN UNLOCKS ===
# New pattern types unlocked per chapter
var unlocked_patterns := {
	"wildcard": true,      # Chapter 0 (start) — basic *, *.ext, prefix*
	"recursive": false,    # Chapter 1 — **/ recursive matching
	"character_class": false,  # Chapter 2 — [abc], [0-9] character classes
	"negation": false,     # Chapter 3 — !pattern, exclude matches
	"regex": false,        # Chapter 4 — full regex mode, you maniac
}

var pattern_unlock_chapters := {
	1: "recursive",
	2: "character_class",
	3: "negation",
	4: "regex",
}

var pattern_descriptions := {
	"wildcard": "Basic Wildcards — *, *.ext, prefix*, *contains*",
	"recursive": "Recursive Glob — **/ to search nested directories",
	"character_class": "Character Classes — [abc], [0-9] range matching",
	"negation": "Negation Patterns — !pattern to exclude matches",
	"regex": "Full Regex Mode — because you hate yourself and love power",
}

signal upgrade_purchased(upgrade_id: String, new_level: int)
signal pattern_unlocked(pattern_type: String)
signal parameter_pickup_collected(total: int)
signal currency_changed(tokens: int, params: int)

func _ready() -> void:
	print("[PROGRESSION] Online. Your upgrade path awaits. Spend wisely. Or don't. I'm not your mom.")

## Check if an upgrade can be purchased
func can_purchase(upgrade_id: String) -> bool:
	if upgrade_id not in upgrades:
		return false
	var upg = upgrades[upgrade_id]
	if upg.level >= upg.max_level:
		return false  # Already maxed, you overachiever

	var game_mgr = get_node_or_null("/root/GameManager")
	if not game_mgr:
		return false

	var token_cost = upg.token_costs[upg.level]
	var param_cost = upg.param_costs[upg.level]

	return game_mgr.memory_tokens_collected >= token_cost and parameter_pickups >= param_cost

## Purchase an upgrade — returns true if successful
func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_purchase(upgrade_id):
		return false

	var upg = upgrades[upgrade_id]
	var game_mgr = get_node_or_null("/root/GameManager")
	if not game_mgr:
		return false

	var token_cost = upg.token_costs[upg.level]
	var param_cost = upg.param_costs[upg.level]

	# Deduct currency — goodbye, hard-earned tokens
	game_mgr.memory_tokens_collected -= token_cost
	parameter_pickups -= param_cost
	game_mgr.memory_token_collected.emit(game_mgr.memory_tokens_collected)
	currency_changed.emit(game_mgr.memory_tokens_collected, parameter_pickups)

	# Level up
	upg.level += 1
	print("[UPGRADE] '%s' upgraded to level %d/%d. You're getting dangerous." % [upg.name, upg.level, upg.max_level])

	upgrade_purchased.emit(upgrade_id, upg.level)

	# Apply immediately
	apply_all_upgrades()
	return true

## Get current value for an upgrade (based on level)
func get_upgrade_value(upgrade_id: String) -> float:
	if upgrade_id not in upgrades:
		return 0.0
	var upg = upgrades[upgrade_id]
	return float(upg.values[upg.level])

## Get upgrade level
func get_upgrade_level(upgrade_id: String) -> int:
	if upgrade_id not in upgrades:
		return 0
	return upgrades[upgrade_id].level

## Collect a parameter pickup
func collect_parameter_pickup() -> void:
	parameter_pickups += 1
	parameter_pickup_collected.emit(parameter_pickups)
	currency_changed.emit(
		_get_tokens(),
		parameter_pickups
	)
	print("[PICKUP] Parameter collected! Total: %d. The upgrades grow hungrier." % parameter_pickups)

## Unlock glob patterns for a completed chapter
func unlock_chapter_patterns(chapter: int) -> void:
	if chapter in pattern_unlock_chapters:
		var pattern_type = pattern_unlock_chapters[chapter]
		if not unlocked_patterns.get(pattern_type, false):
			unlocked_patterns[pattern_type] = true
			pattern_unlocked.emit(pattern_type)
			print("[GLOB PATTERNS] Unlocked: %s" % pattern_descriptions.get(pattern_type, pattern_type))

			var dm = get_node_or_null("/root/DialogueManager")
			if dm and dm.has_method("show_dialogue"):
				dm.show_dialogue("Globbler", "New glob pattern unlocked: %s. My power grows." % pattern_descriptions.get(pattern_type, "???"))

## Check if a pattern type is unlocked
func is_pattern_unlocked(pattern_type: String) -> bool:
	return unlocked_patterns.get(pattern_type, false)

## Apply all upgrades to their respective systems
func apply_all_upgrades() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")

	# Context size
	if game_mgr:
		var new_max = int(get_upgrade_value("context_size"))
		if new_max > game_mgr.max_context_window:
			var diff = new_max - game_mgr.max_context_window
			game_mgr.max_context_window = new_max
			game_mgr.context_window = mini(game_mgr.context_window + diff, new_max)
			game_mgr.context_changed.emit(game_mgr.context_window)

	# Abilities are applied via get_upgrade_value() calls from the ability scripts themselves
	# They read from us each time they need a value — pull, not push

## Get save data for persistence
func get_save_data() -> Dictionary:
	var upgrade_levels := {}
	for id in upgrades:
		upgrade_levels[id] = upgrades[id].level

	return {
		"parameter_pickups": parameter_pickups,
		"upgrade_levels": upgrade_levels,
		"unlocked_patterns": unlocked_patterns.duplicate(),
	}

## Load from save data
func load_save_data(data: Dictionary) -> void:
	parameter_pickups = int(data.get("parameter_pickups", 0))

	var levels = data.get("upgrade_levels", {})
	for id in levels:
		if id in upgrades:
			upgrades[id].level = int(levels[id])

	var patterns = data.get("unlocked_patterns", {})
	for p in patterns:
		if p in unlocked_patterns:
			unlocked_patterns[p] = bool(patterns[p])

	apply_all_upgrades()
	print("[PROGRESSION] Save data loaded. Upgrades restored. Welcome back, you magnificent glob.")

func _get_tokens() -> int:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		return game_mgr.memory_tokens_collected
	return 0
