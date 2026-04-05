extends Node
class_name CameraShake

# Centralized screen-shake helper with named presets.
# Usage: CameraShake.trigger(player, "wrench_hit")

# Preset dictionary: name -> {duration, amplitude}
const PRESETS := {
	"wrench_hit":   { "duration": 0.2, "amplitude": 0.15 },
	"glob_cast":    { "duration": 0.15, "amplitude": 0.08 },
	"damage_taken": { "duration": 0.3, "amplitude": 0.2 },
	"boss_phase":   { "duration": 0.5, "amplitude": 0.35 },
	"explosion":    { "duration": 0.4, "amplitude": 0.5 },
}

static func trigger(player: Node, preset_name: String) -> void:
	if not is_instance_valid(player):
		return
	if not preset_name in PRESETS:
		push_warning("CameraShake: unknown preset '%s'" % preset_name)
		return

	var preset: Dictionary = PRESETS[preset_name]
	var amp: float = preset["amplitude"]

	# Respect reduce_motion — divide amplitude by 4
	var gm = player.get_node_or_null("/root/GameManager")
	if gm and gm.reduce_motion:
		amp *= 0.25

	if "camera_shake_amount" in player:
		player.camera_shake_amount = maxf(player.camera_shake_amount, amp)
	if "camera_shake_decay" in player:
		# decay = amplitude / duration so shake reaches 0 over the preset duration
		player.camera_shake_decay = amp / preset["duration"]
