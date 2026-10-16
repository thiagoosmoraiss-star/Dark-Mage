extends Node
## Estado de progresso da partida (só dados): flags do mundo (baús abertos,
## faróis acesos, segredos), moeda, experiência, fogueiras descobertas e
## purificação por região. Serializado para o save por to_dict()/from_dict().

signal changed(key: StringName)
signal leveled_up(level: int)

const BASE_CORRUPTION: Dictionary = {
	&"valley": 0.0, &"coast": 0.15, &"forest": 0.55, &"peaks": 0.4, &"burnt": 0.5, &"swamp": 1.0, &"citadel": 0.85,
	&"sea": 0.1,
}

var flags: Dictionary[String, bool] = {}
var souls: int = 0
var crystals: int = 0
var materials: Dictionary[String, int] = {}
var xp: int = 0
var level: int = 1
var attribute_points: int = 0
var attributes: Dictionary[String, int] = {"health": 0, "mana": 0, "stamina": 0, "power": 0}
var discovered_bonfires: Array[String] = []
var respawn_bonfire: String = ""
var purification: Dictionary[String, float] = {}
var play_time_s: float = 0.0
## Sigilos dos santuários: +10 de vida / +10 de mana cada.
var sigils_health: int = 0
var sigils_mana: int = 0


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time_s += delta


func reset() -> void:
	flags.clear()
	souls = 0
	crystals = 0
	materials.clear()
	xp = 0
	level = 1
	attribute_points = 0
	attributes = {"health": 0, "mana": 0, "stamina": 0, "power": 0}
	discovered_bonfires.clear()
	respawn_bonfire = ""
	purification.clear()
	play_time_s = 0.0
	sigils_health = 0
	sigils_mana = 0


func has_flag(id: String) -> bool:
	return flags.get(id, false)


func set_flag(id: String, value: bool = true) -> void:
	flags[id] = value
	changed.emit(StringName(id))


func add_souls(n: int) -> void:
	souls = maxi(0, souls + n)
	changed.emit(&"souls")


func add_crystals(n: int) -> void:
	crystals = maxi(0, crystals + n)
	changed.emit(&"crystals")


func add_material(id: String, n: int) -> void:
	var cur: int = materials.get(id, 0)
	materials[id] = maxi(0, cur + n)
	changed.emit(&"materials")


## XP necessário para passar do nível `lv` para o seguinte.
static func xp_to_next(lv: int) -> int:
	return roundi(60.0 * pow(float(lv), 1.35))


## Gasta um ponto de atributo (vida, mana, stamina ou poder).
func spend_point(stat: String) -> bool:
	if attribute_points <= 0 or not attributes.has(stat):
		return false
	attribute_points -= 1
	attributes[stat] += 1
	changed.emit(&"attributes")
	return true


func add_xp(n: int) -> void:
	xp += n
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		attribute_points += 1
		leveled_up.emit(level)
	changed.emit(&"xp")


## Corrupção atual de uma região (0..1), já descontada a purificação.
func corruption(region: StringName) -> float:
	var base: float = BASE_CORRUPTION.get(region, 0.0)
	var pure: float = purification.get(String(region), 0.0)
	return base * (1.0 - pure)


func purify(region: StringName, amount: float) -> void:
	var key: String = String(region)
	var cur: float = purification.get(key, 0.0)
	purification[key] = clampf(cur + amount, 0.0, 1.0)
	changed.emit(&"purification")
	Events.region_purified.emit(region)


func discover_bonfire(id: String) -> void:
	if not discovered_bonfires.has(id):
		discovered_bonfires.append(id)
		changed.emit(&"bonfires")


func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(), "souls": souls, "crystals": crystals, "materials": materials.duplicate(),
		"xp": xp, "level": level, "attribute_points": attribute_points, "attributes": attributes.duplicate(),
		"discovered_bonfires": discovered_bonfires.duplicate(), "respawn_bonfire": respawn_bonfire,
		"purification": purification.duplicate(), "play_time_s": play_time_s,
		"sigils_health": sigils_health, "sigils_mana": sigils_mana,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	var f: Variant = d.get("flags", {})
	if f is Dictionary:
		for k: Variant in (f as Dictionary):
			flags[str(k)] = (f as Dictionary)[k] == true
	souls = JsonUtil.get_i(d, "souls")
	crystals = JsonUtil.get_i(d, "crystals")
	var m: Variant = d.get("materials", {})
	if m is Dictionary:
		for k: Variant in (m as Dictionary):
			materials[str(k)] = roundi(JsonUtil.num((m as Dictionary)[k]))
	xp = JsonUtil.get_i(d, "xp")
	level = maxi(1, JsonUtil.get_i(d, "level", 1))
	attribute_points = JsonUtil.get_i(d, "attribute_points")
	var a: Variant = d.get("attributes", {})
	if a is Dictionary:
		for k: String in attributes.keys():
			attributes[k] = roundi(JsonUtil.num((a as Dictionary).get(k, 0)))
	var b: Variant = d.get("discovered_bonfires", [])
	if b is Array:
		for v: Variant in (b as Array):
			discovered_bonfires.append(str(v))
	respawn_bonfire = JsonUtil.get_s(d, "respawn_bonfire")
	var p: Variant = d.get("purification", {})
	if p is Dictionary:
		for k: Variant in (p as Dictionary):
			purification[str(k)] = clampf(JsonUtil.num((p as Dictionary)[k]), 0.0, 1.0)
	play_time_s = JsonUtil.get_f(d, "play_time_s")
	sigils_health = JsonUtil.get_i(d, "sigils_health")
	sigils_mana = JsonUtil.get_i(d, "sigils_mana")
