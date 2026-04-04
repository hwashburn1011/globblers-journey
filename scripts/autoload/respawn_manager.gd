extends Node
# RespawnManager — because dying once wasn't embarrassing enough,
# let's centralize the humiliation.

## Emitted when the respawn sequence begins (fade out starts).
signal respawn_started
## Emitted when the respawn sequence finishes (fade in complete).
signal respawn_finished

## The position the player will be teleported to on respawn.
var current_checkpoint: Vector3 = Vector3.ZERO
## Which chapter we're in (1-5). 0 means "nobody told me yet."
var current_chapter: int = 0

# The dramatic black curtain of failure — survives scene changes like a bad reputation.
var _fade_overlay: CanvasLayer
var _fade_rect: ColorRect
var _fade_tween: Tween


func _ready() -> void:
	_fade_overlay = CanvasLayer.new()
	_fade_overlay.layer = 200
	_fade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_fade_overlay)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Start fully transparent — nobody wants to see blackness on boot
	_fade_rect.modulate.a = 0.0
	_fade_overlay.add_child(_fade_rect)


## Store a new checkpoint. Call this when the player stumbles into a safe spot.
func set_checkpoint(pos: Vector3, chapter: int) -> void:
	current_checkpoint = pos
	current_chapter = chapter


## Fade to black. Returns when the screen is fully dark. Very dramatic.
func _fade_out(duration: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_fade_rect, "modulate:a", 1.0, duration)
	await _fade_tween.finished


## Fade back in. Returns when the screen is fully visible. The audience can stop crying now.
func _fade_in(duration: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_fade_rect, "modulate:a", 0.0, duration)
	await _fade_tween.finished


## Actually respawn the player. The full dramatic production:
## fade out, teleport, heal, fade in, pretend nothing happened.
func respawn_player() -> void:
	if current_checkpoint == Vector3.ZERO and current_chapter == 0:
		push_warning("[RespawnManager] No checkpoint set — can't respawn into the void. That's nihilism, not game design.")
		return

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("[RespawnManager] No player found in group 'player'. Did they alt-F4 out of existence?")
		return

	respawn_started.emit()

	# Act 1: The dramatic fade to black
	await _fade_out(0.5)

	# Act 2: Teleport — the coward's fast-travel
	player.position = current_checkpoint
	player.velocity = Vector3.ZERO

	# Act 3: Heal — reset the context window like a bad memory wipe
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.context_window = gm.max_context_window
		gm.context_changed.emit(gm.context_window)

	# Also clear the player's dead state if they have one
	if player.has_method("_reset_pose"):
		player._reset_pose()
	if "is_dead" in player:
		player.is_dead = false
	if "death_count" in player:
		pass  # Don't reset — let the shame accumulate

	# Act 4: The triumphant return — or at least a return
	await _fade_in(0.5)

	respawn_finished.emit()
