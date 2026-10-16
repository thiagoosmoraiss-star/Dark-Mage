class_name WorldPois
extends RefCounted
## Pontos de interesse da ilha (roteiro 3.3). Posição em x/z; a altura vem do
## terreno. Usado para clareiras na vegetação, para o mapa e pelo M7/M8.
## Tipos: ruin, beacon, camp, bonfire, shrine, lair, chest, secret, citadel.

const POIS: Array[Dictionary] = [
	{"id": &"ruin_awakening", "kind": &"ruin", "x": -35.0, "z": 95.0, "radius": 16.0, "region": &"valley"},
	{"id": &"beacon_valley", "kind": &"beacon", "x": 70.0, "z": 20.0, "radius": 9.0, "region": &"valley"},
	{"id": &"bonfire_valley", "kind": &"bonfire", "x": 18.0, "z": 165.0, "radius": 4.0, "region": &"valley"},
	{"id": &"camp_valley_north", "kind": &"camp", "x": -30.0, "z": 60.0, "radius": 0.0, "region": &"valley"},
]


static func by_kind(kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in POIS:
		if p["kind"] == kind:
			out.append(p)
	return out


static func get_poi(id: StringName) -> Dictionary:
	for p: Dictionary in POIS:
		if p["id"] == id:
			return p
	return {}


static func pos2(p: Dictionary) -> Vector2:
	return Vector2(JsonUtil.get_f(p, "x"), JsonUtil.get_f(p, "z"))
