class_name Interactor
extends Node
## Escolhe o Interactable mais próximo à frente do jogador e dispara a interação.

signal focus_changed(target: Interactable)

var player: Player
var focus: Interactable = null
var _scan: float = 0.0


func _ready() -> void:
	player = get_parent() as Player


func _physics_process(delta: float) -> void:
	if player == null or player.state == Player.State.DEAD:
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.1
		var best: Interactable = null
		var best_score: float = INF
		for n: Node in get_tree().get_nodes_in_group(&"interactable"):
			var it: Interactable = n as Interactable
			if it == null or not it.is_visible_in_tree() or not it.can_interact(player):
				continue
			var to: Vector3 = it.interact_point() - player.global_position
			var d: float = to.length()
			if d > it.interact_range:
				continue
			var facing: float = player.facing.dot(Vector3(to.x, 0.0, to.z).normalized()) if d > 0.6 else 1.0
			if facing < -0.2:
				continue
			var score: float = d - facing
			if score < best_score:
				best_score = score
				best = it
		if best != focus:
			focus = best
			focus_changed.emit(focus)
	if focus != null and player.just_pressed(&"interact") and player.state == Player.State.GROUND:
		focus.interact(player)
		if player.model != null:
			player.model.play_oneshot(&"interact", 0.5)
		_scan = 0.0
