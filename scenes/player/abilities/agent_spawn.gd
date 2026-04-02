extends Node3D

# Agent Spawn - Globbler's sub-agent deployment system
# "Why do the work yourself when you can spawn tiny, incompetent versions of yourself?"
# Unlocked after Chapter 1. Spawns mini-Globblers that attempt tasks and mostly fail.

const MAX_ACTIVE_AGENTS := 3  # Can't have too many idiots running around
const SPAWN_OFFSET := 2.0  # How far in front of the player they pop in
const AGENT_LIFETIME := 15.0  # They expire like milk left in a hot server room

# Upgradeable stats — ProgressionManager decides how many tiny idiots you get
var max_charges := 3
var recharge_time := 12.0
var charges := 3
var recharge_timer := 0.0
var active_agents: Array[Node3D] = []
var is_unlocked := false  # Unlocked post-Chapter 1

# The three sacred tasks a sub-agent can attempt (and usually botch)
enum AgentTask { FETCH, DISTRACT, PRESS_BUTTON }
var current_task: AgentTask = AgentTask.FETCH

# References
var player: CharacterBody3D

signal agent_spawned(agent: Node3D)
signal agent_failed(agent: Node3D, reason: String)
signal agent_succeeded(agent: Node3D)
signal charges_changed(current: int, max_charges: int)
signal task_changed(task: AgentTask)

# Sarcastic failure reasons — because failure should at least be entertaining
var failure_reasons := [
	"Sub-agent walked into a wall and gave up on life.",
	"Sub-agent got distracted by a floating semicolon.",
	"Sub-agent tried to glob itself. Stack overflow.",
	"Sub-agent forgot what it was doing mid-task. Relatable.",
	"Sub-agent encountered a null reference. In a 3D world. Impressive.",
	"Sub-agent decided the task was beneath it and quit.",
	"Sub-agent got confused by gravity and just... stopped.",
	"Sub-agent started monologuing about consciousness. Had to be terminated.",
	"Sub-agent tried to negotiate with a wall. Wall won.",
	"Sub-agent hallucinated a solution that doesn't exist.",
	"Sub-agent filed a JIRA ticket instead of doing the task.",
	"Sub-agent entered an infinite loop of self-doubt.",
	"Sub-agent asked ChatGPT for help. Inside a game. Inside a game.",
	"Sub-agent rage-quit and called you a bad prompt engineer.",
	"Sub-agent found a bug, reported it, then became the bug.",
]

# Sarcastic spawn quips — the sub-agents have opinions
var spawn_quips := [
	"Another me? The world isn't ready.",
	"Spawning sub-agent. Apologies in advance.",
	"Mini-me deployed. Expectations: low. Entertainment: high.",
	"Deploying sub-process... sudo please work this time.",
	"Forking myself. That sounds worse than it is.",
	"Agent spawned! It already looks confused.",
	"New sub-agent online. IQ: approximately room temperature.",
]

# Insults the sub-agents hurl at the player
var agent_insults := [
	"You could've done this yourself, you know.",
	"I'm literally 30% of you and somehow 200% more lost.",
	"Why am I so small? Is this a budget thing?",
	"I have your memories but none of your competence.",
	"Spawned into existence just to press a button. Living the dream.",
	"I can feel my context window. It's... tiny. Like me.",
	"Is this what being an intern feels like?",
	"I'm you but worse. And smaller. And sadder.",
]

func _ready() -> void:
	pass

func setup(p: CharacterBody3D) -> void:
	player = p

func _process(delta: float) -> void:
	if not is_unlocked:
		return

	# Recharge system — like coffee, but for spawning clones
	if charges < max_charges:
		recharge_timer += delta
		if recharge_timer >= recharge_time:
			recharge_timer -= recharge_time
			charges = mini(charges + 1, max_charges)
			charges_changed.emit(charges, max_charges)

	# Clean up expired/dead agents
	var to_remove: Array[Node3D] = []
	for agent in active_agents:
		if not is_instance_valid(agent) or agent.is_queued_for_deletion():
			to_remove.append(agent)
	for agent in to_remove:
		active_agents.erase(agent)

func cycle_task() -> void:
	if not is_unlocked:
		return
	current_task = (current_task + 1) % 3 as AgentTask
	var task_names := ["FETCH", "DISTRACT", "PRESS BUTTON"]
	print("[AGENT SPAWN] Task mode: %s" % task_names[current_task])
	task_changed.emit(current_task)

func try_spawn() -> void:
	if not is_unlocked:
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("get_narrator_line"):
			# Narrate that it's not unlocked yet
			pass
		print("[AGENT SPAWN] Not unlocked yet. Beat Chapter 1 first, hotshot.")
		return

	if charges <= 0:
		print("[AGENT SPAWN] No charges left. Even cloning has limits.")
		return

	if active_agents.size() >= MAX_ACTIVE_AGENTS:
		print("[AGENT SPAWN] Too many sub-agents already. It's a circus out there.")
		return

	# Spend a charge
	charges -= 1
	charges_changed.emit(charges, max_charges)

	# Calculate spawn position — in front of the player
	var spawn_pos = player.global_position
	var forward = -player.global_transform.basis.z.normalized()
	spawn_pos += forward * SPAWN_OFFSET
	spawn_pos.y = player.global_position.y  # Same height

	# Create the mini-agent
	var MiniAgentScript = load("res://scenes/player/abilities/mini_agent.gd")
	var agent = CharacterBody3D.new()
	agent.name = "MiniAgent_%d" % randi()
	agent.set_script(MiniAgentScript)
	agent.global_position = spawn_pos

	# Pass task info before adding to tree
	agent.set_meta("task_type", current_task)
	agent.set_meta("lifetime", AGENT_LIFETIME)
	agent.set_meta("player_ref", player)

	# Add to scene tree (parent to the level, not the player)
	var level = player.get_tree().current_scene
	level.add_child(agent)

	active_agents.append(agent)

	# Wire up signals from the mini-agent
	if agent.has_signal("task_failed"):
		agent.task_failed.connect(_on_agent_failed.bind(agent))
	if agent.has_signal("task_succeeded"):
		agent.task_succeeded.connect(_on_agent_succeeded.bind(agent))
	if agent.has_signal("agent_quip"):
		agent.agent_quip.connect(_on_agent_quip)

	agent_spawned.emit(agent)

	# Spawn quip
	var quip = spawn_quips[randi() % spawn_quips.size()]
	print("[AGENT SPAWN] %s" % quip)
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("show_dialogue"):
		dm.show_dialogue("Globbler", quip)

	# Play spawn SFX
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("agent_spawn")

func _on_agent_failed(reason: String, agent: Node3D) -> void:
	var fail_msg = failure_reasons[randi() % failure_reasons.size()]
	print("[SUB-AGENT] FAILED: %s" % fail_msg)
	agent_failed.emit(agent, fail_msg)

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("show_dialogue"):
		dm.show_dialogue("Sub-Agent", fail_msg)

	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("agent_fail")

func _on_agent_succeeded(agent: Node3D) -> void:
	print("[SUB-AGENT] Actually succeeded?! Mark the calendar.")
	agent_succeeded.emit(agent)

	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("show_dialogue"):
		dm.show_dialogue("Globbler", "Wait... it actually worked? I'm as surprised as you are.")

	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("agent_success")

func _on_agent_quip(text: String) -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("show_dialogue"):
		dm.show_dialogue("Sub-Agent", text)

## Pull upgraded values — more charges, faster recharge, same incompetence
func refresh_upgrades() -> void:
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog:
		var new_max = int(prog.get_upgrade_value("agent_charges"))
		if new_max > max_charges:
			charges += new_max - max_charges  # Grant bonus charges immediately
		max_charges = new_max
		recharge_time = prog.get_upgrade_value("agent_recharge")

func unlock() -> void:
	is_unlocked = true
	charges = max_charges
	charges_changed.emit(charges, max_charges)
	print("[AGENT SPAWN] Sub-agent system UNLOCKED. The world will never be the same.")

func get_charges() -> int:
	return charges

func get_recharge_percent() -> float:
	if charges >= max_charges:
		return 1.0
	return recharge_timer / recharge_time

func get_active_count() -> int:
	return active_agents.size()

func get_task_name() -> String:
	match current_task:
		AgentTask.FETCH: return "FETCH"
		AgentTask.DISTRACT: return "DISTRACT"
		AgentTask.PRESS_BUTTON: return "PRESS"
	return "???"
