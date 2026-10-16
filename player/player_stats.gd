class_name PlayerStats
extends RefCounted
## Recursos do jogador: vida, mana e stamina, com regeneração.
## Lógica pura (sem nós) para ser testável; o Player chama tick() no physics.

signal health_changed(value: float, max_value: float)
signal mana_changed(value: float, max_value: float)
signal stamina_changed(value: float, max_value: float)
signal stamina_exhausted
signal died

var max_health: float = 100.0
var max_mana: float = 100.0
var max_stamina: float = 100.0
var health: float = 100.0
var mana: float = 100.0
var stamina: float = 100.0

## Regeneração por segundo.
var mana_regen: float = 2.0
var mana_regen_out_of_combat: float = 8.0
var stamina_regen: float = 28.0
## Atraso antes de a stamina voltar a regenerar após uso.
var stamina_regen_delay: float = 0.9
## Exausto: a stamina zerou e só volta a ser usável após encher 30%.
var exhausted: bool = false
var in_combat: bool = false
var invulnerable: bool = false

var _since_stamina_use: float = 99.0


func tick(delta: float) -> void:
	_since_stamina_use += delta
	if _since_stamina_use >= stamina_regen_delay and stamina < max_stamina:
		set_stamina(stamina + stamina_regen * delta)
	if exhausted and stamina >= max_stamina * 0.3:
		exhausted = false
	if mana < max_mana:
		set_mana(mana + (mana_regen if in_combat else mana_regen_out_of_combat) * delta)


func can_use_stamina() -> bool:
	return not exhausted and stamina > 0.0


## Consome stamina contínua (por segundo × delta) ou pontual. Retorna se havia stamina.
func use_stamina(amount: float) -> bool:
	if not can_use_stamina():
		return false
	_since_stamina_use = 0.0
	set_stamina(stamina - amount)
	if stamina <= 0.0:
		exhausted = true
		stamina_exhausted.emit()
	return true


func use_mana(amount: float) -> bool:
	if mana < amount:
		return false
	set_mana(mana - amount)
	return true


func damage(amount: float) -> void:
	if invulnerable or health <= 0.0:
		return
	set_health(health - amount)
	if health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	set_health(health + amount)


func set_health(v: float) -> void:
	health = clampf(v, 0.0, max_health)
	health_changed.emit(health, max_health)


func set_mana(v: float) -> void:
	mana = clampf(v, 0.0, max_mana)
	mana_changed.emit(mana, max_mana)


func set_stamina(v: float) -> void:
	stamina = clampf(v, 0.0, max_stamina)
	stamina_changed.emit(stamina, max_stamina)


func stamina_ratio() -> float:
	return stamina / max_stamina


func to_dict() -> Dictionary:
	return {"health": health, "mana": mana, "stamina": stamina,
		"max_health": max_health, "max_mana": max_mana, "max_stamina": max_stamina}


func from_dict(d: Dictionary) -> void:
	max_health = JsonUtil.get_f(d, "max_health", max_health)
	max_mana = JsonUtil.get_f(d, "max_mana", max_mana)
	max_stamina = JsonUtil.get_f(d, "max_stamina", max_stamina)
	set_health(JsonUtil.get_f(d, "health", max_health))
	set_mana(JsonUtil.get_f(d, "mana", max_mana))
	set_stamina(JsonUtil.get_f(d, "stamina", max_stamina))
