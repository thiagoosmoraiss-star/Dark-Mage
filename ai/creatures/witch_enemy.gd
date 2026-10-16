class_name WitchEnemy
extends Enemy
## Bruxa do Pântano: mantém distância, lança projéteis lentos e, a cada poucos
## segundos, cura e protege o aliado mais ferido com um feixe verde. Prioridade de alvo.

const HEAL_RANGE: float = 16.0
const HEAL_AMOUNT: float = 0.3


func _think(delta: float) -> Vector3:
	if target != null and cooldowns.ready(&"heal") and state != State.ATTACK_WINDUP:
		var ally: Enemy = _most_wounded_ally()
		if ally != null:
			_heal(ally)
	return super._think(delta)


func _most_wounded_ally() -> Enemy:
	var best: Enemy = null
	var worst_ratio: float = 0.85
	for e: Node in get_tree().get_nodes_in_group(&"enemy"):
		var en: Enemy = e as Enemy
		if en == null or en == self or not en.is_alive():
			continue
		if en.global_position.distance_to(global_position) > HEAL_RANGE:
			continue
		var r: float = en.health / en.max_health
		if r < worst_ratio:
			worst_ratio = r
			best = en
	return best


func _heal(ally: Enemy) -> void:
	cooldowns.start(&"heal", 6.0)
	ally.health = minf(ally.max_health, ally.health + ally.max_health * HEAL_AMOUNT)
	model.play_once(&"Spellcast_Raise")
	var vfx: Vfx = Vfx.get_for(self)
	if vfx != null:
		vfx.lightning(PackedVector3Array([global_position + Vector3.UP * 1.6, ally.global_position + Vector3.UP * 1.2]),
			Color("7fff9e"), 0.5)
		vfx.impact(ally.global_position + Vector3.UP, Color("7fff9e"), 1.0, 24)
	Audio.play(&"barrier", global_position, -4.0)
