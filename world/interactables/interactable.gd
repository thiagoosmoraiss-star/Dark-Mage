class_name Interactable
extends Node3D
## Base dos objetos com os quais o jogador interage (tecla G / X no gamepad):
## baús, faróis, fogueiras, mirantes, histórias. O Interactor do jogador escolhe
## o mais próximo à frente e mostra o prompt.

@export var prompt_key: String = "INTERACT"
@export var interact_range: float = 2.6
## Id persistente (flag no GameState) — vazio = sem estado salvo.
@export var poi_id: String = ""


func _ready() -> void:
	add_to_group(&"interactable")


func can_interact(_player: Player) -> bool:
	return true


## Ponto de referência para distância e prompt (pode ser sobrescrito).
func interact_point() -> Vector3:
	return global_position


func prompt_text() -> String:
	return tr(prompt_key)


func interact(_player: Player) -> void:
	pass


func flag_key() -> String:
	return "%s:%s" % [get_class_tag(), poi_id]


func get_class_tag() -> String:
	return "poi"
