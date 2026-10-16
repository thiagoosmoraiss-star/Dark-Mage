class_name CombatDirector
extends Node
## Coordena os inimigos: no máximo MAX_ATTACKERS atacando ao mesmo tempo
## (os demais rodeiam e esperam a vez). Um por mundo, grupo "combat_director".

const MAX_ATTACKERS: int = 2

var _holders: Dictionary[int, float] = {}  # instance_id -> tempo segurando


static func get_for(n: Node) -> CombatDirector:
	return n.get_tree().get_first_node_in_group(&"combat_director") as CombatDirector


func _ready() -> void:
	add_to_group(&"combat_director")


func request_token(enemy: Node) -> bool:
	var id: int = enemy.get_instance_id()
	if _holders.has(id):
		return true
	_cleanup()
	if _holders.size() >= MAX_ATTACKERS:
		return false
	_holders[id] = 0.0
	return true


func release_token(enemy: Node) -> void:
	_holders.erase(enemy.get_instance_id())


func attackers() -> int:
	_cleanup()
	return _holders.size()


func _physics_process(delta: float) -> void:
	for id: int in _holders.keys():
		_holders[id] += delta
		# Ninguém segura a vez para sempre (falha de segurança).
		if _holders[id] > 6.0:
			_holders.erase(id)


func _cleanup() -> void:
	for id: int in _holders.keys():
		var o: Object = instance_from_id(id)
		if o == null or not is_instance_valid(o) or not o.call(&"is_alive"):
			_holders.erase(id)
