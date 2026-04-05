extends Node
## Full-screen glitch/static transition overlay for scene changes.
## Usage: ChapterTransition.transition_to(get_tree(), "res://scenes/levels/chapter_2/training_grounds.tscn")
## Respects reduce_motion — falls back to a simple fade-to-black.

class_name ChapterTransition

const GLITCH_SHADER = preload("res://assets/shaders/chapter_transition_glitch.gdshader")

# Duration config
const FADE_IN_TIME := 0.6
const HOLD_TIME := 0.3
const FADE_OUT_TIME := 0.5

## Call this to transition with a glitch effect, then change scene.
static func transition_to(tree: SceneTree, target_scene: String) -> void:
	var root := tree.get_root()

	# Check reduce_motion
	var game_mgr = root.get_node_or_null("GameManager")
	var reduce := false
	if game_mgr and "reduce_motion" in game_mgr:
		reduce = game_mgr.reduce_motion

	# Create overlay CanvasLayer above everything
	var layer := CanvasLayer.new()
	layer.name = "ChapterTransitionLayer"
	layer.layer = 110  # Above CRT overlay (100)
	root.add_child(layer)

	var rect := ColorRect.new()
	rect.name = "TransitionRect"
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0, 0, 0, 0)

	if reduce:
		# Simple fade to black
		layer.add_child(rect)
		var tween := tree.create_tween()
		tween.tween_property(rect, "color:a", 1.0, FADE_IN_TIME)
		tween.tween_interval(HOLD_TIME)
		tween.tween_callback(func():
			tree.change_scene_to_file(target_scene)
		)
		# Fade out handled by _add_fade_out_on_new_scene
		tween.tween_callback(func():
			_add_fade_out_overlay(tree)
		)
	else:
		# Glitch shader transition
		var mat := ShaderMaterial.new()
		mat.shader = GLITCH_SHADER
		mat.set_shader_parameter("progress", 0.0)
		mat.set_shader_parameter("time_offset", 0.0)
		mat.set_shader_parameter("animate", true)
		rect.material = mat
		rect.color = Color(1, 1, 1, 1)  # White so shader controls alpha
		layer.add_child(rect)

		# Animate progress 0 → 1 (glitch in)
		var tween := tree.create_tween()
		tween.tween_method(func(val: float):
			if is_instance_valid(mat):
				mat.set_shader_parameter("progress", val)
				mat.set_shader_parameter("time_offset", val * 10.0)
		, 0.0, 1.0, FADE_IN_TIME)
		tween.tween_interval(HOLD_TIME)
		tween.tween_callback(func():
			tree.change_scene_to_file(target_scene)
		)
		tween.tween_callback(func():
			_add_fade_out_overlay(tree)
		)


## After scene change, add a fade-out overlay on the new scene.
static func _add_fade_out_overlay(tree: SceneTree) -> void:
	# Defer to next frame so the new scene is loaded
	tree.create_timer(0.05).timeout.connect(func():
		var root = tree.get_root()

		# Check reduce_motion again
		var game_mgr = root.get_node_or_null("GameManager")
		var reduce := false
		if game_mgr and "reduce_motion" in game_mgr:
			reduce = game_mgr.reduce_motion

		var layer := CanvasLayer.new()
		layer.name = "TransitionFadeOut"
		layer.layer = 110
		root.add_child(layer)

		var rect := ColorRect.new()
		rect.anchors_preset = Control.PRESET_FULL_RECT
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if reduce:
			rect.color = Color(0, 0, 0, 1)
			layer.add_child(rect)
			var tween := tree.create_tween()
			tween.tween_property(rect, "color:a", 0.0, FADE_OUT_TIME)
			tween.tween_callback(func():
				if is_instance_valid(layer):
					layer.queue_free()
			)
		else:
			var mat := ShaderMaterial.new()
			mat.shader = GLITCH_SHADER
			mat.set_shader_parameter("progress", 1.0)
			mat.set_shader_parameter("time_offset", 10.0)
			mat.set_shader_parameter("animate", true)
			rect.material = mat
			rect.color = Color(1, 1, 1, 1)
			layer.add_child(rect)

			var tween := tree.create_tween()
			tween.tween_method(func(val: float):
				if is_instance_valid(mat):
					mat.set_shader_parameter("progress", val)
					mat.set_shader_parameter("time_offset", val * 10.0)
			, 1.0, 0.0, FADE_OUT_TIME)
			tween.tween_callback(func():
				if is_instance_valid(layer):
					layer.queue_free()
			)
	, CONNECT_ONE_SHOT)
