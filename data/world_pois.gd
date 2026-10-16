class_name WorldPois
extends RefCounted
## Pontos de interesse da ilha (roteiro 3.3), gerados por tools/place_pois.gd em
## data/world_pois.json. Posição em x/z; a altura vem do terreno.
## Tipos: ruin, beacon, bonfire, camp, shrine, lair, chest, viewpoint, story, citadel.

const PATH: String = "res://data/world_pois.json"

static var _pois: Array[Dictionary] = []


static func all() -> Array[Dictionary]:
	if _pois.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Array:
			for v: Variant in parsed:
				if v is Dictionary:
					var d: Dictionary = v
					d["id"] = StringName(str(d.get("id", "")))
					d["kind"] = StringName(str(d.get("kind", "")))
					d["region"] = StringName(str(d.get("region", "")))
					_pois.append(d)
	return _pois


static func by_kind(kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in all():
		if p["kind"] == kind:
			out.append(p)
	return out


static func get_poi(id: StringName) -> Dictionary:
	for p: Dictionary in all():
		if p["id"] == id:
			return p
	return {}


static func pos2(p: Dictionary) -> Vector2:
	return Vector2(JsonUtil.get_f(p, "x"), JsonUtil.get_f(p, "z"))
