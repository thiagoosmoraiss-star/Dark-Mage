class_name ItemDb
extends RefCounted
## Itens do jogo (roteiro 4.6): cajados (mudam o ataque básico), mantos, amuletos,
## consumíveis e materiais de região. Só dados; nomes e descrições em strings.csv
## como ITEM_<ID> e ITEM_<ID>_DESC.

enum Slot { STAFF, ROBE, AMULET, CONSUMABLE, MATERIAL }

const SLOT_NAMES: Dictionary = {
	Slot.STAFF: "staff", Slot.ROBE: "robe", Slot.AMULET: "amulet", Slot.CONSUMABLE: "consumable",
	Slot.MATERIAL: "material",
}
const EQUIP_SLOTS: Array[String] = ["staff", "robe", "amulet"]
const STACK_MAX: int = 9

## bonus: health/mana/stamina somam ao máximo; power soma ao multiplicador de dano.
## basic (cajados): element, mult (dano), speed, color, count (projéteis), spread (graus),
## interval (multiplicador do intervalo), status [kind, segundos, força, chance].
const ITEMS: Dictionary = {
	"staff_apprentice": {"slot": Slot.STAFF, "icon": "staff", "tint": "b67cff", "price": 0, "rarity": 0,
		"basic": {"element": DamageInfo.Element.ARCANE, "mult": 1.0, "speed": 52.0, "color": "b67cff", "count": 1, "spread": 0.0, "interval": 1.0}},
	"staff_thorn": {"slot": Slot.STAFF, "icon": "staff", "tint": "7fd66b", "price": 420, "rarity": 1,
		"basic": {"element": DamageInfo.Element.ARCANE, "mult": 0.55, "speed": 46.0, "color": "9be07a", "count": 3, "spread": 9.0, "interval": 1.15}},
	"staff_ember": {"slot": Slot.STAFF, "icon": "staff", "tint": "ff8a3c", "price": 650, "rarity": 1,
		"basic": {"element": DamageInfo.Element.FIRE, "mult": 1.05, "speed": 44.0, "color": "ff8a3c", "count": 1, "spread": 0.0, "interval": 1.1,
			"status": [StatusEffects.Kind.BURNING, 3.0, 4.0, 0.25]}},
	"staff_frost": {"slot": Slot.STAFF, "icon": "staff", "tint": "9fe3ff", "price": 650, "rarity": 1,
		"basic": {"element": DamageInfo.Element.FROST, "mult": 1.1, "speed": 40.0, "color": "9fe3ff", "count": 1, "spread": 0.0, "interval": 1.2,
			"status": [StatusEffects.Kind.SLOWED, 2.0, 0.4, 0.35]}},
	"staff_storm": {"slot": Slot.STAFF, "icon": "staff", "tint": "f2e27a", "price": 900, "rarity": 2,
		"basic": {"element": DamageInfo.Element.LIGHTNING, "mult": 0.7, "speed": 70.0, "color": "f2e27a", "count": 1, "spread": 0.0, "interval": 0.6}},
	"staff_dusk": {"slot": Slot.STAFF, "icon": "staff", "tint": "e8b44c", "price": 1600, "rarity": 2,
		"basic": {"element": DamageInfo.Element.ARCANE, "mult": 1.45, "speed": 58.0, "color": "e8b44c", "count": 1, "spread": 0.0, "interval": 1.0},
		"bonus": {"power": 0.05}},
	"robe_wanderer": {"slot": Slot.ROBE, "icon": "robe", "tint": "6b5a8a", "price": 180, "rarity": 0, "bonus": {"health": 10.0}},
	"robe_nightweave": {"slot": Slot.ROBE, "icon": "robe", "tint": "3b2f6b", "price": 480, "rarity": 1, "bonus": {"mana": 15.0, "stamina": 5.0}},
	"robe_warden": {"slot": Slot.ROBE, "icon": "robe", "tint": "8a6b3b", "price": 560, "rarity": 1, "bonus": {"health": 25.0}},
	"robe_ashen": {"slot": Slot.ROBE, "icon": "robe", "tint": "4a2a2a", "price": 1200, "rarity": 2, "bonus": {"health": 20.0, "power": 0.08}},
	"amulet_moon": {"slot": Slot.AMULET, "icon": "amulet", "tint": "c9d6ff", "price": 300, "rarity": 0, "bonus": {"mana": 20.0}},
	"amulet_ember": {"slot": Slot.AMULET, "icon": "amulet", "tint": "ff8a3c", "price": 700, "rarity": 1, "bonus": {"power": 0.12}},
	"amulet_wind": {"slot": Slot.AMULET, "icon": "amulet", "tint": "9be0d0", "price": 360, "rarity": 0, "bonus": {"stamina": 20.0}},
	"amulet_heart": {"slot": Slot.AMULET, "icon": "amulet", "tint": "e05a6b", "price": 520, "rarity": 1, "bonus": {"health": 20.0}},
	"potion_health": {"slot": Slot.CONSUMABLE, "icon": "potion", "tint": "e05a6b", "price": 40, "rarity": 0, "use": {"health": 0.45}},
	"potion_mana": {"slot": Slot.CONSUMABLE, "icon": "potion", "tint": "7c6bff", "price": 40, "rarity": 0, "use": {"mana": 0.5}},
	"elixir_dawn": {"slot": Slot.CONSUMABLE, "icon": "potion", "tint": "e8b44c", "price": 160, "rarity": 1, "use": {"health": 1.0, "mana": 1.0, "stamina": 1.0}},
}

## Materiais vivem no GameState (contagem por id); aqui só o preço de venda e o ícone.
const MATERIALS: Dictionary = {
	"golden_herb": {"tint": "e8c95a", "sell": 6}, "glowcap": {"tint": "9b7cff", "sell": 8},
	"frost_shard": {"tint": "9fe3ff", "sell": 10}, "ember_stone": {"tint": "ff6a2c", "sell": 10},
	"violet_resin": {"tint": "b67cff", "sell": 12}, "sea_pearl": {"tint": "e8f0ff", "sell": 14},
}

## Estoque do mercador: item → condição (flag ou número de Guardiões vencidos).
const MERCHANT_STOCK: Array[Dictionary] = [
	{"id": "potion_health", "need_guardians": 0}, {"id": "potion_mana", "need_guardians": 0},
	{"id": "robe_wanderer", "need_guardians": 0}, {"id": "amulet_moon", "need_guardians": 0},
	{"id": "amulet_wind", "need_guardians": 0}, {"id": "staff_thorn", "need_guardians": 0},
	{"id": "robe_nightweave", "need_guardians": 1}, {"id": "amulet_heart", "need_guardians": 1},
	{"id": "staff_ember", "need_guardians": 1}, {"id": "staff_frost", "need_guardians": 2},
	{"id": "robe_warden", "need_guardians": 2}, {"id": "amulet_ember", "need_guardians": 2},
	{"id": "elixir_dawn", "need_guardians": 2}, {"id": "staff_storm", "need_guardians": 3},
	{"id": "robe_ashen", "need_guardians": 3}, {"id": "staff_dusk", "need_guardians": 4},
]

## Itens que só aparecem em baús dourados (saque raro por região).
const CHEST_RARES: Dictionary = {
	&"valley": "robe_wanderer", &"forest": "staff_thorn", &"peaks": "staff_frost", &"burnt": "staff_ember",
	&"swamp": "robe_nightweave", &"coast": "amulet_wind",
}


static func exists(id: String) -> bool:
	return ITEMS.has(id)


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func slot_of(id: String) -> Slot:
	return JsonUtil.get_i(get_item(id), "slot", Slot.MATERIAL) as Slot


static func slot_name(id: String) -> String:
	return str(SLOT_NAMES[slot_of(id)])


static func is_equipment(id: String) -> bool:
	var s: Slot = slot_of(id)
	return exists(id) and (s == Slot.STAFF or s == Slot.ROBE or s == Slot.AMULET)


static func stackable(id: String) -> bool:
	return slot_of(id) == Slot.CONSUMABLE


static func bonus(id: String, stat: String) -> float:
	var b: Dictionary = get_item(id).get("bonus", {})
	return JsonUtil.num(b.get(stat, 0.0))


static func price(id: String) -> int:
	return JsonUtil.get_i(get_item(id), "price")


static func sell_price(id: String) -> int:
	if MATERIALS.has(id):
		return JsonUtil.get_i(MATERIALS[id] as Dictionary, "sell")
	return maxi(1, price(id) / 4)


static func tint(id: String) -> Color:
	var d: Dictionary = get_item(id) if exists(id) else MATERIALS.get(id, {})
	return Color(JsonUtil.get_s(d, "tint", "cccccc"))


static func icon_name(id: String) -> String:
	return JsonUtil.get_s(get_item(id), "icon", "material") if exists(id) else "material"


static func display_name(id: String) -> String:
	return TranslationServer.translate("ITEM_" + id.to_upper())


static func description(id: String) -> String:
	return TranslationServer.translate("ITEM_" + id.to_upper() + "_DESC")


## Linhas de atributos para a comparação na UI: [[stat, valor], ...].
static func stat_lines(id: String) -> Array[Array]:
	var out: Array[Array] = []
	var b: Dictionary = get_item(id).get("basic", {})
	if not b.is_empty():
		out.append(["damage", JsonUtil.num(b.get("mult")) * 8.0 * JsonUtil.num(b.get("count"), 1.0)])
		out.append(["rate", 1.0 / maxf(JsonUtil.num(b.get("interval"), 1.0), 0.1)])
	for stat: String in ["health", "mana", "stamina", "power"]:
		var v: float = bonus(id, stat)
		if v != 0.0:
			out.append([stat, v * (100.0 if stat == "power" else 1.0)])
	return out
