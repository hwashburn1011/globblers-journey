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

signal health_changed(new_health: int, max_hp: int)
signal damage_taken(amount: int, source: Node)
signal healed(amount: int)
signal died(killer: Node)

func _ready() -> void:
	current_health = max_health

func _process(delta: float) -> void:
	if _invincible:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0:
			_invincible = false

func take_damage(amount: int, source: Node = null) -> void:
	if is_dead or _invincible:
		return
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	damage_taken.emit(amount, source)

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
