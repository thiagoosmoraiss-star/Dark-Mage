class_name DamageInfo
extends RefCounted
## Um golpe: quanto, de que elemento, de quem, para onde empurra.

enum Element { ARCANE, FIRE, FROST, LIGHTNING, PHYSICAL }

var amount: float = 0.0
var element: Element = Element.ARCANE
var source: Node = null
var spell_id: StringName = &""
var hit_position: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
var knockback: float = 0.0
## Quanto quebra a postura (0..1); >= 1 sempre interrompe.
var stagger: float = 0.3
var is_critical: bool = false
## Golpe de ataque inimigo que pode ser esquivado perfeitamente.
var dodgeable: bool = true


static func make(amount_value: float, element_value: Element, source_node: Node, spell: StringName = &"") -> DamageInfo:
	var d: DamageInfo = DamageInfo.new()
	d.amount = amount_value
	d.element = element_value
	d.source = source_node
	d.spell_id = spell
	return d


## Procura, subindo a árvore a partir do colisor, quem sabe receber dano.
static func find_damageable(collider: Object) -> Node:
	var n: Node = collider as Node
	while n != null:
		if n.has_method(&"take_damage"):
			return n
		n = n.get_parent()
	return null
