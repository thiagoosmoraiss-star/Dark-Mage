class_name StatusEffects
extends RefCounted
## Efeitos de status de uma entidade: congelado, enraizado, lento, queimando,
## atordoado e vulnerável. Lógica pura (testável); o dono chama tick().

enum Kind { FROZEN, ROOTED, SLOWED, BURNING, STUNNED, VULNERABLE }

signal applied(kind: Kind)
signal expired(kind: Kind)

## kind -> {"time": restante, "power": intensidade}
var active: Dictionary[int, Dictionary] = {}
## Resistências por tipo (0 = nenhuma, 1 = imune).
var resist: Dictionary[int, float] = {}


func apply(kind: Kind, duration: float, power: float = 1.0) -> void:
	var r: float = resist.get(kind, 0.0)
	if r >= 1.0:
		return
	var t: float = duration * (1.0 - r)
	var cur: Dictionary = active.get(kind, {})
	if cur.is_empty():
		active[kind] = {"time": t, "power": power}
		applied.emit(kind)
	else:
		cur["time"] = maxf(JsonUtil.get_f(cur, "time"), t)
		cur["power"] = maxf(JsonUtil.get_f(cur, "power"), power)


func has(kind: Kind) -> bool:
	return active.has(kind)


func remove(kind: Kind) -> void:
	if active.erase(kind):
		expired.emit(kind)


## Avança o tempo; devolve o dano por tempo (queimadura) desse intervalo.
func tick(delta: float) -> float:
	var dot: float = 0.0
	for kind: int in active.keys():
		var e: Dictionary = active[kind]
		if kind == Kind.BURNING:
			dot += JsonUtil.get_f(e, "power") * delta
		e["time"] = JsonUtil.get_f(e, "time") - delta
		if JsonUtil.get_f(e, "time") <= 0.0:
			active.erase(kind)
			expired.emit(kind)
	return dot


## Multiplicador de velocidade de movimento.
func speed_multiplier() -> float:
	if has(Kind.FROZEN) or has(Kind.ROOTED) or has(Kind.STUNNED):
		return 0.0
	if has(Kind.SLOWED):
		return clampf(1.0 - JsonUtil.get_f(active[Kind.SLOWED], "power", 0.5), 0.1, 1.0)
	return 1.0


func can_act() -> bool:
	return not (has(Kind.FROZEN) or has(Kind.STUNNED))


## Multiplicador de dano recebido.
func damage_taken_multiplier() -> float:
	var m: float = 1.0
	if has(Kind.VULNERABLE):
		m *= 1.0 + JsonUtil.get_f(active[Kind.VULNERABLE], "power", 0.3)
	if has(Kind.FROZEN):
		m *= 1.25  # quebrar o gelo dói
	return m
