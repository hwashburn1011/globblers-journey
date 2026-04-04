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


## Store a new checkpoint. Call this when the player stumbles into a safe spot.
func set_checkpoint(pos: Vector3, chapter: int) -> void:
	current_checkpoint = pos
	current_chapter = chapter


## Actually respawn the player. Stub for now — full logic comes in Task 2.4.
func respawn_player() -> void:
	# TODO: fade, teleport, heal, the whole dramatic production (Task 2.4)
	print("[RespawnManager] respawn_player() called — checkpoint: %s, chapter: %d" % [current_checkpoint, current_chapter])
