class_name Cooldowns
extends RefCounted
## Recargas por id (feitiços, ataques de inimigos). Lógica pura.

var _remaining: Dictionary[StringName, float] = {}
var _total: Dictionary[StringName, float] = {}
## Multiplicador global (equipamentos/amuletos que reduzem recarga).
var rate: float = 1.0


func start(id: StringName, seconds: float) -> void:
	_remaining[id] = seconds
	_total[id] = seconds


func tick(delta: float) -> void:
	for id: StringName in _remaining.keys():
		var r: float = _remaining[id] - delta * rate
		if r <= 0.0:
			_remaining.erase(id)
		else:
			_remaining[id] = r


func ready(id: StringName) -> bool:
	return not _remaining.has(id)


func remaining(id: StringName) -> float:
	return _remaining.get(id, 0.0)


## Fração restante (1 = acabou de começar, 0 = pronto), para a HUD.
func fraction(id: StringName) -> float:
	if not _remaining.has(id):
		return 0.0
	var total: float = _total.get(id, 1.0)
	return _remaining[id] / maxf(total, 0.0001)


func reset() -> void:
	_remaining.clear()
