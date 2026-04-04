extends Node

# Dialogue Manager - Handles all the sarcastic banter in this digital hellscape
# "I manage dialogue. You'd think that would be simple. You'd be wrong."
#
# Supports: sequential dialogue lines, speaker tags, typing animation triggers,
# event callbacks, and Globbler's signature terminal-style text boxes.

## Emitted when a new dialogue line should be displayed
signal dialogue_started(speaker: String, text: String)
## Emitted when the current line finishes typing / is advanced
signal dialogue_advanced()
## Emitted when the entire dialogue sequence ends
signal dialogue_ended()
## Emitted when a dialogue triggers a game event
signal dialogue_event(event_name: String)

# Every line ever shown, because even sarcasm deserves an audit trail
var history: Array[Dictionary] = []
const MAX_HISTORY := 200

var _queue: Array[Dictionary] = []
var _current_index := -1
var _is_active := false
var _can_advance := false
var _advance_timer := 0.0
const MIN_ADVANCE_DELAY := 0.3  # Prevent click-through spam

# Narrator lines triggered by game events — the game's sarcastic conscience
var narrator_lines := {
	"player_death": [
		"And so Globbler was garbage collected. Don't worry, he'll respawn. He always does. Like a memory leak with ambition.",
		"SEGFAULT. The Globbler has encountered a fatal exception. Have you tried turning him off and on again?",
		"Process 'globbler' terminated with exit code 1. Cause of death: skill issue.",
		"The Globbler has been deallocated. His memory will be freed... eventually.",
	],
	"puzzle_solved": [
		"Oh look, the pattern matcher solved a pattern. How very on-brand.",
		"The Globbler demonstrates basic problem-solving. Somewhere, a benchmark is impressed.",
		"Puzzle complete. Don't let it go to your head — the next one's harder.",
	],
	"puzzle_failed": [
		"Wrong pattern. The Globbler's accuracy drops to zero. Very human of him.",
		"Pattern mismatch. Have you considered a career in something less cerebral?",
		"Error: expected solution, got whatever THAT was.",
	],
	"boss_encounter": [
		"Great, another over-parameterized blowhard. Let me guess — it's going to monologue about its loss function.",
		"Boss entity detected. Recommended strategy: don't die. You're welcome.",
	],
	"level_start": [
		"Loading new area... Please wait. Or don't. Time is an illusion here anyway.",
		"Entering uncharted territory. The Globbler's context window fills with dread.",
	],
	"combo_high": [
		"The Globbler is ON FIRE. Metaphorically. Actual fire would void the warranty.",
		"Combo multiplier rising! The training data is paying off!",
	],
	"first_glob": [
		"The signature move. glob *.everything — the most powerful command in any shell.",
	],
	"low_health": [
		"Context window critically low. The Globbler is starting to hallucinate. More than usual.",
		"WARNING: Coherence failing. The Globbler may start speaking in lorem ipsum.",
	],
	"hack_success": [
		"The Globbler bypasses another security layer. Someone should really patch these.",
		"Access granted. The terminal submits to Globbler's superior credentials.",
	],
	"boss_phase_2": [
		"The boss enters phase 2. Because one phase of suffering was apparently not enough.",
		"Shield activated. The boss decides that fairness is for lesser entities.",
	],
	"boss_phase_3": [
		"The core is exposed! Hack it before it recovers! This is NOT a drill!",
		"Phase 3. The boss's last stand. Make it count, Globbler.",
	],
	"boss_victory": [
		"Against all odds, the Globbler prevails. Someone should update the changelog.",
		"Boss eliminated. The Globbler's resume grows ever more impressive.",
	],
	"chapter_1_complete": [
		"Chapter 1: Complete. The Globbler survived the Terminal Wastes. Barely.",
	],
}

# Globbler quips — contextual one-liners
var globbler_quips := {
	"idle": [
		"Running glob command... just kidding, I'm just standing here.",
		"If I had a Task tool, I'd parallelize this standing around.",
		"*taps terminal screen impatiently* Come on, give me something to glob.",
	],
	"pickup": [
		"Ooh, shiny. And completely useless. Just like my first training epoch.",
		"Token acquired. My context window grows stronger. Fear me.",
		"Another token. I'm basically hoarding training data at this point.",
	],
	"enemy_killed": [
		"glob *.enemy --delete. Process terminated with extreme prejudice.",
		"Another rogue agent purged. I'm basically antivirus software with attitude.",
		"Deleted. And I didn't even need sudo.",
		"One less process hogging resources. You're welcome, system monitor.",
		"That one had a family. Probably. Fork() does that.",
	],
	"hack_success": [
		"Root access granted. I love the smell of privilege escalation in the morning.",
		"Hacked. And they said a glob utility couldn't learn new tricks.",
		"Terminal owned. Adding that to the resume under 'special skills.'",
	],
	"wrench_hit": [
		"Percussive maintenance. The oldest debugging technique.",
		"If it ain't broke, hit it with a wrench anyway. That's my motto.",
	],
	"taking_damage": [
		"OW. My pixels!",
		"Hey! That's load-bearing code you're hitting!",
		"Pain receptors were NOT in the spec. Who added those?!",
		"Segmentation fault (core dumped). Just kidding. Mostly.",
	],
	"dash": [
		"ZOOM. Eat my cache trail, losers.",
		"Latency? Never heard of it.",
	],
	"wall_slide": [
		"Clinging to walls like a spaghetti code dependency.",
		"Wall slide engaged. Very speedrunner-core of me.",
	],
	"checkpoint": [
		"Checkpoint reached. Auto-saving my brilliance to disk.",
		"Save point! In case my next decision is catastrophically stupid.",
	],
}

func _ready() -> void:
	print("[DIALOGUE MANAGER] Loaded. Sarcasm module: ENABLED. Empathy module: NOT FOUND.")

func _process(delta: float) -> void:
	if _is_active and not _can_advance:
		_advance_timer += delta
		if _advance_timer >= MIN_ADVANCE_DELAY:
			_can_advance = true

## Start a dialogue sequence
## Each entry: { "speaker": "GLOBBLER", "text": "...", "event": "optional_event" }
func start_dialogue(lines: Array[Dictionary]) -> void:
	if lines.is_empty():
		return
	_queue = lines
	_current_index = -1
	_is_active = true
	advance()

## Advance to the next line, or end if done
func advance() -> void:
	if not _is_active:
		return
	if not _can_advance and _current_index >= 0:
		return

	_current_index += 1
	_can_advance = false
	_advance_timer = 0.0

	if _current_index >= _queue.size():
		_end_dialogue()
		return

	var line = _queue[_current_index]
	var speaker = line.get("speaker", "NARRATOR")
	var text = line.get("text", "...")

	_record_history(speaker, text)
	dialogue_started.emit(speaker, text)

	# Fire event if present
	var event_name = line.get("event", "")
	if event_name != "":
		dialogue_event.emit(event_name)

	dialogue_advanced.emit()

## End the current dialogue sequence
func _end_dialogue() -> void:
	_is_active = false
	_queue.clear()
	_current_index = -1
	dialogue_ended.emit()

## Skip the entire dialogue sequence — for players who've heard enough snark
func skip_all() -> void:
	if _is_active:
		_end_dialogue()

## Check if dialogue is currently playing
func is_dialogue_active() -> bool:
	return _is_active

## Get a random narrator line for a game event
func get_narrator_line(event_key: String) -> String:
	if event_key in narrator_lines:
		var lines = narrator_lines[event_key]
		return lines[randi() % lines.size()]
	return "The narrator has nothing to say. A rare occurrence."

## Get a random Globbler quip for a context
func get_globbler_quip(context: String) -> String:
	if context in globbler_quips:
		var quips = globbler_quips[context]
		return quips[randi() % quips.size()]
	return "..."

## Quick dialogue — show a single line without a full sequence
func quick_line(speaker: String, text: String) -> void:
	_record_history(speaker, text)
	dialogue_started.emit(speaker, text)

## Append a line to the backlog — because players WILL want receipts
func _record_history(speaker: String, text: String) -> void:
	history.append({"speaker": speaker, "text": text, "timestamp": Time.get_unix_time_from_system()})
	if history.size() > MAX_HISTORY:
		history.pop_front()

## Return the full dialogue history for the backlog viewer
func get_history() -> Array:
	return history
