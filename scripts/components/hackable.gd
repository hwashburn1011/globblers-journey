extends Node

# Hackable Component - Makes any node hackable via Globbler's terminal arm
# "sudo make me_a_sandwich. ACCESS GRANTED."

class_name Hackable

enum HackState { LOCKED, AVAILABLE, HACKING, HACKED, FAILED }

@export var hack_difficulty: int = 1  # 1-5, affects minigame
@export var interaction_range: float = 3.0
@export var hack_prompt: String = "Press F to hack"
@export var success_message: String = "ACCESS GRANTED"
@export var failure_message: String = "ACCESS DENIED"

var state: HackState = HackState.LOCKED

signal hack_started()
signal hack_completed()
signal hack_failed()
signal state_changed(new_state: HackState)

func _ready() -> void:
	state = HackState.AVAILABLE

func start_hack() -> void:
	if state != HackState.AVAILABLE:
		return
	state = HackState.HACKING
	state_changed.emit(state)
	hack_started.emit()

func complete_hack() -> void:
	state = HackState.HACKED
	state_changed.emit(state)
	hack_completed.emit()
	print("[HACK] %s — %s" % [get_parent().name, success_message])

func fail_hack() -> void:
	state = HackState.FAILED
	state_changed.emit(state)
	hack_failed.emit()
	print("[HACK] %s — %s" % [get_parent().name, failure_message])
	# Reset to available after a delay
	get_tree().create_timer(2.0).timeout.connect(func():
		state = HackState.AVAILABLE
		state_changed.emit(state)
	)

func is_hackable() -> bool:
	return state == HackState.AVAILABLE

func is_hacked() -> bool:
	return state == HackState.HACKED
