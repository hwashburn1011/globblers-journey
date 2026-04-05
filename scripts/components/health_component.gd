extends Node

# Health Component - Attachable health system for anything that can take a beating
# "HP: Hit Points, or 'How Pathetic' — depends on the number."

class_name HealthComponent

@export var max_health: int = 100
@export var current_health: int = 100
@export var invincibility_time: float = 0.5

var is_dead := false
var _invincible := false
var _invincibility_timer := 0.0

# Damage flash shader — because pain needs a visual exclamation mark
var _flash_shader: Shader = null
var _flash_materials: Array[ShaderMaterial] = []
var _flash_tween: Tween = null

signal health_changed(new_health: int, max_hp: int)
signal damage_taken(amount: int, source: Node)
signal healed(amount: int)
signal died(killer: Node)

func _ready() -> void:
	current_health = max_health
	# Defer flash setup so the owner's scene tree is fully built
	call_deferred("_setup_damage_flash")

func _process(delta: float) -> void:
	if _invincible:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0:
			_invincible = false

func take_damage(amount: int, source: Node = null) -> void:
	if is_dead or _invincible:
		return
	# "Difficulty scaling: because even masochism should have a slider."
	var final_amount := amount
	if get_parent() and get_parent().is_in_group("player"):
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("get_difficulty_damage_multiplier"):
			final_amount = int(ceil(float(amount) * gm.get_difficulty_damage_multiplier()))
	current_health = max(0, current_health - final_amount)
	health_changed.emit(current_health, max_health)
	damage_taken.emit(amount, source)
	_trigger_damage_flash()

	if invincibility_time > 0:
		_invincible = true
		_invincibility_timer = invincibility_time

	if current_health <= 0:
		is_dead = true
		died.emit(source)

func heal(amount: int) -> void:
	if is_dead:
		return
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	healed.emit(amount)

func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)

func is_alive() -> bool:
	return not is_dead

func reset() -> void:
	is_dead = false
	current_health = max_health
	_invincible = false
	health_changed.emit(current_health, max_health)

# --- Damage flash shader wiring ---
# Finds all MeshInstance3D children on the owner and chains a flash shader
# onto each surface via next_pass. Because getting hurt should look dramatic.

func _setup_damage_flash() -> void:
	_flash_shader = load("res://assets/shaders/damage_flash.gdshader")
	if not _flash_shader:
		return  # Shader missing? Silently degrade — no flash, just vibes
	var owner_node = get_parent()
	if not owner_node:
		return
	_collect_flash_materials(owner_node)

func _collect_flash_materials(node: Node) -> void:
	# Recursively find every MeshInstance3D and attach flash as next_pass
	# on surface 0 — the main body material. Skip if already has a next_pass
	# chain (don't clobber the rim-light shader the player might have).
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		for surf_idx in range(mesh_inst.mesh.get_surface_count() if mesh_inst.mesh else 0):
			var mat = mesh_inst.get_active_material(surf_idx)
			if mat:
				# Walk the next_pass chain to find the tail — we append, not replace
				var tail_mat: Material = mat
				while tail_mat.next_pass:
					tail_mat = tail_mat.next_pass
				var flash_mat := ShaderMaterial.new()
				flash_mat.shader = _flash_shader
				flash_mat.set_shader_parameter("flash_intensity", 0.0)
				# Duplicate so we don't pollute shared resources
				if not mesh_inst.get_surface_override_material(surf_idx):
					var mat_copy = mat.duplicate()
					mesh_inst.set_surface_override_material(surf_idx, mat_copy)
					tail_mat = mat_copy
					while tail_mat.next_pass:
						tail_mat = tail_mat.next_pass
				tail_mat.next_pass = flash_mat
				_flash_materials.append(flash_mat)
	for child in node.get_children():
		_collect_flash_materials(child)

func _trigger_damage_flash() -> void:
	if _flash_materials.is_empty():
		return
	# Kill any in-progress flash tween — new hit = fresh flash, no queuing
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	# Set all flash materials to full intensity, then tween down to zero
	for mat in _flash_materials:
		mat.set_shader_parameter("flash_intensity", 1.0)
	# Use the first material as the tween target; callback syncs the rest
	_flash_tween = create_tween()
	_flash_tween.tween_method(_update_flash_intensity, 1.0, 0.0, 0.15)

func _update_flash_intensity(value: float) -> void:
	for mat in _flash_materials:
		mat.set_shader_parameter("flash_intensity", value)
