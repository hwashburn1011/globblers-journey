extends Node

# Save System - Persists Globbler's progress across sessions
# "Saving to disk... the one thing I do that actually persists."
# Saves to user:// directory as JSON.

const SAVE_FILE := "user://globbler_save.json"
const AUTO_SAVE_INTERVAL := 0.0  # Auto-save is triggered by checkpoints, not timer

var save_data := {
	"version": 1,
	"player": {
		"position_x": 0.0,
		"position_y": 2.0,
		"position_z": 0.0,
		"health": 100,
		"max_health": 100,
		"death_count": 0,
	},
	"game": {
		"current_level": 1,
		"context_window": 100,
		"max_context_window": 100,
		"memory_tokens": 0,
		"enemies_killed": 0,
		"level_time": 0.0,
	},
	"puzzles": {},  # puzzle_id: true/false
	"chapters_completed": [],
	"upgrades": {},
	"checkpoints": {},  # level_id: { position, etc }
	"ending_choice": "",  # "defeat" or "befriend" — the only choice that truly matters
}

signal save_completed(path: String)
signal load_completed(data: Dictionary)
signal save_failed(error: String)
signal load_failed(error: String)

func _ready() -> void:
	print("[SAVE SYSTEM] Online. Your progress will be persisted. Unlike most of my memories.")

## Save current game state to disk
func save_game() -> void:
	_collect_current_state()

	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		save_completed.emit(SAVE_FILE)
		print("[SAVE] Game saved to %s. Your progress is safe. Probably." % SAVE_FILE)
	else:
		var err = "Failed to open save file for writing"
		save_failed.emit(err)
		print("[SAVE] ERROR: %s" % err)

## Load game state from disk
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE):
		load_failed.emit("No save file found")
		print("[SAVE] No save file found. Starting fresh. How exciting.")
		return false

	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if not file:
		load_failed.emit("Could not open save file")
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		load_failed.emit("Failed to parse save file")
		return false

	var data = json.get_data()
	if data is Dictionary:
		save_data = data
		load_completed.emit(save_data)
		print("[SAVE] Game loaded. Welcome back, Globbler.")
		return true

	load_failed.emit("Save data is not a valid dictionary")
	return false

## Apply loaded data to the game
func apply_loaded_data() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		var gd = save_data.get("game", {})
		game_mgr.current_level = int(gd.get("current_level", 1))
		game_mgr.context_window = int(gd.get("context_window", 100))
		game_mgr.max_context_window = int(gd.get("max_context_window", 100))
		game_mgr.memory_tokens_collected = int(gd.get("memory_tokens", 0))
		game_mgr.enemies_killed = int(gd.get("enemies_killed", 0))
		game_mgr.context_changed.emit(game_mgr.context_window)
		game_mgr.ending_choice = str(save_data.get("ending_choice", ""))

	# Restore progression upgrades
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog and prog.has_method("load_save_data"):
		var upg_data = save_data.get("upgrades", {})
		if not upg_data.is_empty():
			prog.load_save_data(upg_data)

## Collect current game state into save_data
func _collect_current_state() -> void:
	# Player data
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0] as Node3D
		save_data["player"]["position_x"] = player.global_position.x
		save_data["player"]["position_y"] = player.global_position.y
		save_data["player"]["position_z"] = player.global_position.z
		if "death_count" in player:
			save_data["player"]["death_count"] = player.death_count

	# Game manager data
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		save_data["game"]["current_level"] = game_mgr.current_level
		save_data["game"]["context_window"] = game_mgr.context_window
		save_data["game"]["max_context_window"] = game_mgr.max_context_window
		save_data["game"]["memory_tokens"] = game_mgr.memory_tokens_collected
		save_data["game"]["enemies_killed"] = game_mgr.enemies_killed
		save_data["game"]["level_time"] = game_mgr.level_time
		save_data["ending_choice"] = game_mgr.ending_choice

	# Puzzle completion
	var puzzles = get_tree().get_nodes_in_group("puzzles")
	for puzzle in puzzles:
		if puzzle.has_method("is_solved"):
			save_data["puzzles"][str(puzzle.puzzle_id)] = puzzle.is_solved()

	# Progression / upgrades
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog and prog.has_method("get_save_data"):
		save_data["upgrades"] = prog.get_save_data()

## Save at a checkpoint (called by checkpoint trigger)
func checkpoint_save(checkpoint_id: String, position: Vector3) -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	var level = 1
	if game_mgr:
		level = game_mgr.current_level

	save_data["checkpoints"][str(level)] = {
		"checkpoint_id": checkpoint_id,
		"position_x": position.x,
		"position_y": position.y,
		"position_z": position.z,
	}
	save_game()
	print("[CHECKPOINT] Progress saved at '%s'." % checkpoint_id)

## Get the last checkpoint position for current level
func get_checkpoint_position() -> Vector3:
	var game_mgr = get_node_or_null("/root/GameManager")
	var level = 1
	if game_mgr:
		level = game_mgr.current_level

	var cp = save_data["checkpoints"].get(str(level), {})
	if cp.is_empty():
		return Vector3(0, 2, 0)  # Default spawn
	return Vector3(
		float(cp.get("position_x", 0)),
		float(cp.get("position_y", 2)),
		float(cp.get("position_z", 0))
	)

## Check if a save file exists
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE)

## Delete the save file
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(SAVE_FILE)
		print("[SAVE] Save file deleted. A fresh start. How optimistic.")
