class_name SaveCodec
extends RefCounted
## Formato do save: JSON puro (nunca Resource/.tres, que pode carregar scripts).
## Toda mudança de formato incrementa VERSION e ganha um passo em _migrate_step().

const VERSION: int = 1
const MAGIC: String = "dark-mage-save"


## Estrutura de um save novo.
static func new_save() -> Dictionary:
	return {
		"magic": MAGIC,
		"version": VERSION,
		"saved_at_unix": 0,
		"play_time_s": 0.0,
		"world_seed": 0,
		"player": {
			"position": [0.0, 0.0, 0.0],
			"health": 100.0,
			"mana": 100.0,
			"stamina": 100.0,
		},
		"world": {
			"time_of_day_h": 8.0,
			"flags": {},
		},
	}


static func encode(data: Dictionary) -> String:
	return JSON.stringify(data, "\t")


## Decodifica, migra e valida. Retorna {} se o conteúdo for inválido.
static func decode(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var data: Dictionary = parsed
	if data.get("magic") != MAGIC:
		return {}
	data = migrate(data)
	if data.is_empty() or not validate(data):
		return {}
	return data


## Leva um save de qualquer versão antiga até VERSION. Versão futura = inválido.
static func migrate(data: Dictionary) -> Dictionary:
	var v: int = roundi(num(data.get("version", 0), -1.0))
	if v > VERSION or v < 0:
		return {}
	while v < VERSION:
		data = _migrate_step(data, v)
		v += 1
		data["version"] = v
	return data


static func _migrate_step(data: Dictionary, from_version: int) -> Dictionary:
	match from_version:
		0:
			# v0 (fixture de teste): sem "world", vida em "hp".
			var player: Dictionary = data.get("player", {})
			if player.has("hp"):
				player["health"] = player["hp"]
				player.erase("hp")
			for key: String in ["mana", "stamina"]:
				if not player.has(key):
					player[key] = 100.0
			data["player"] = player
			if not data.has("world"):
				data["world"] = {"time_of_day_h": 8.0, "flags": {}}
	return data


## Validação estrutural: tipos e faixas. Não confia em nada vindo do disco.
static func validate(data: Dictionary) -> bool:
	if roundi(num(data.get("version"), -1.0)) != VERSION:
		return false
	var player: Variant = data.get("player")
	var world: Variant = data.get("world")
	if not (player is Dictionary and world is Dictionary):
		return false
	var pos: Variant = (player as Dictionary).get("position")
	if not (pos is Array and (pos as Array).size() == 3):
		return false
	for c: Variant in pos:
		if not is_finite(num(c, NAN)):
			return false
	for key: String in ["health", "mana", "stamina"]:
		var v: Variant = (player as Dictionary).get(key)
		if not (num(v, -1.0) >= 0.0):
			return false
	var tod: Variant = (world as Dictionary).get("time_of_day_h")
	var hours: float = num(tod, -1.0)
	if not (hours >= 0.0 and hours < 24.0):
		return false
	return (world as Dictionary).get("flags") is Dictionary


## Converte um número vindo do JSON (sempre float) ou do código (int/float).
## Qualquer outro tipo devolve `fallback`.
static func num(v: Variant, fallback: float) -> float:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			return f
		TYPE_INT:
			var i: int = v
			return float(i)
	return fallback
