extends Node3D

# Base Puzzle - Framework for all puzzles in Globbler's digital maze
# "Every puzzle is just a pattern waiting to be globbed."
# States: Locked -> Active -> Solved or Failed

class_name BasePuzzle

enum PuzzleState { LOCKED, ACTIVE, SOLVED, FAILED }

@export var puzzle_id := 0
@export var puzzle_name := "unknown_puzzle"
@export var auto_activate := false  # Activate when player enters area
@export var activation_range := 5.0
@export var can_retry := true

var state: PuzzleState = PuzzleState.LOCKED
var player_ref: CharacterBody3D

signal puzzle_activated(puzzle: Node)
signal puzzle_solved(puzzle: Node)
signal puzzle_failed(puzzle: Node)
signal puzzle_reset(puzzle: Node)

func _ready() -> void:
	add_to_group("puzzles")
	if auto_activate:
		state = PuzzleState.ACTIVE

func _process(delta: float) -> void:
	# Auto-activate when player is near
	if state == PuzzleState.LOCKED and auto_activate:
		_check_player_proximity()

func _check_player_proximity() -> void:
	if not player_ref:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0] as CharacterBody3D
	if player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < activation_range:
			activate()

func activate() -> void:
	if state != PuzzleState.LOCKED:
		return
	state = PuzzleState.ACTIVE
	puzzle_activated.emit(self)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_puzzle_activate()
	_on_activated()
	print("[PUZZLE] '%s' activated. Good luck, you'll need it." % puzzle_name)

func solve() -> void:
	if state != PuzzleState.ACTIVE:
		return
	state = PuzzleState.SOLVED
	puzzle_solved.emit(self)
	_on_solved()

	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var line = dm.get_narrator_line("puzzle_solved")
		dm.quick_line("NARRATOR", line)

	print("[PUZZLE] '%s' solved! The Globbler's pattern-matching pays off." % puzzle_name)

func fail() -> void:
	if state != PuzzleState.ACTIVE:
		return
	state = PuzzleState.FAILED
	puzzle_failed.emit(self)
	_on_failed()

	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		var line = dm.get_narrator_line("puzzle_failed")
		dm.quick_line("NARRATOR", line)

	print("[PUZZLE] '%s' failed. Not very sentient AI of you." % puzzle_name)

	if can_retry:
		# Reset after delay
		get_tree().create_timer(2.0).timeout.connect(reset)

func reset() -> void:
	state = PuzzleState.LOCKED
	puzzle_reset.emit(self)
	_on_reset()

# Override these in subclasses
func _on_activated() -> void:
	pass

func _on_solved() -> void:
	pass

func _on_failed() -> void:
	pass

func _on_reset() -> void:
	pass

func is_solved() -> bool:
	return state == PuzzleState.SOLVED

func is_active() -> bool:
	return state == PuzzleState.ACTIVE
