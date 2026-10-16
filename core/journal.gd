class_name Journal
extends RefCounted
## Diário de missões (roteiro 4.7). As missões são derivadas do GameState (flags,
## fogueiras, purificação), então não há estado extra para salvar ou migrar.

const GUARDIAN_REGIONS: Array[StringName] = [&"forest", &"peaks", &"burnt", &"swamp"]


## Lista de missões: {id, main, title, desc, progress, total, done, locked}.
static func quests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var valley_lit: bool = GameState.has_flag("beacon:beacon_valley")
	out.append(_q("awaken", true, 1 if valley_lit else 0, 1))
	out.append(_q("beacons", true, _count_flags(&"beacon", "beacon"), WorldPois.by_kind(&"beacon").size()))
	var g: int = 0
	for r: StringName in GUARDIAN_REGIONS:
		if GameState.has_flag("guardian:" + String(r)):
			g += 1
	out.append(_q("guardians", true, g, GUARDIAN_REGIONS.size(), not valley_lit))
	out.append(_q("citadel", true, 1 if GameState.has_flag("final:fear") else 0, 1, g < GUARDIAN_REGIONS.size()))
	out.append(_q("shrines", false, _count_flags(&"shrine", "shrine_done"), WorldPois.by_kind(&"shrine").size()))
	out.append(_q("chests", false, _count_flags(&"chest", "chest"), WorldPois.by_kind(&"chest").size()))
	out.append(_q("viewpoints", false, _count_flags(&"viewpoint", "viewpoint"), WorldPois.by_kind(&"viewpoint").size()))
	out.append(_q("stories", false, _count_flags(&"story", "story"), WorldPois.by_kind(&"story").size()))
	out.append(_q("bonfires", false, GameState.discovered_bonfires.size(), WorldPois.by_kind(&"bonfire").size()))
	var pure: int = 0
	var regions: Array[StringName] = [&"valley", &"forest", &"peaks", &"burnt", &"swamp", &"coast"]
	for r: StringName in regions:
		if GameState.corruption(r) <= 0.001:
			pure += 1
	out.append(_q("purify", false, pure, regions.size()))
	return out


## Próximo objetivo principal ainda aberto (para a HUD); {} se a campanha acabou.
static func current_objective() -> Dictionary:
	for q: Dictionary in quests():
		if q["main"] and not q["done"] and not q["locked"]:
			return q
	return {}


static func _q(id: String, main: bool, progress: int, total: int, locked: bool = false) -> Dictionary:
	var key: String = "QUEST_" + id.to_upper()
	return {
		"id": id, "main": main, "title": TranslationServer.translate(key),
		"desc": TranslationServer.translate(key + "_DESC"), "progress": mini(progress, total), "total": total,
		"done": progress >= total, "locked": locked,
	}


static func _count_flags(kind: StringName, prefix: String) -> int:
	var n: int = 0
	for poi: Dictionary in WorldPois.by_kind(kind):
		if GameState.has_flag("%s:%s" % [prefix, String(poi["id"] as StringName)]):
			n += 1
	return n
