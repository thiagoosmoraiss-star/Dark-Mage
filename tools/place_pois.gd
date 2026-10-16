extends SceneTree
## Distribui os pontos de interesse da ilha (roteiro 3.3) e grava data/world_pois.json.
## Determinístico (seed do mundo). Uso: QUIT_AFTER=100000 bash tools/run.sh res://tools/place_pois.gd
##
## Regras: faróis no ponto mais alto da região; covis perto do centro das regiões
## corrompidas; fogueiras, santuários, acampamentos, baús, mirantes e histórias em
## terreno pouco inclinado, acima da água, longe uns dos outros e fora da Cidadela.

const L = preload("res://world/island/island_layout.gd")
const WORLD_SEED: int = 20261016
const OUT: String = "res://data/world_pois.json"

## Âncoras autorais (fatia vertical do M6) — mantidas como estão.
const FIXED: Array[Dictionary] = [
	{"id": "ruin_awakening", "kind": "ruin", "x": -35.0, "z": 95.0, "radius": 16.0, "region": "valley"},
	{"id": "beacon_valley", "kind": "beacon", "x": 70.0, "z": 20.0, "radius": 9.0, "region": "valley"},
	{"id": "bonfire_valley", "kind": "bonfire", "x": 18.0, "z": 165.0, "radius": 4.0, "region": "valley"},
	{"id": "camp_valley_north", "kind": "camp", "x": -30.0, "z": 60.0, "radius": 0.0, "region": "valley"},
	{"id": "citadel", "kind": "citadel", "x": 0.0, "z": -360.0, "radius": 95.0, "region": "citadel"},
]

## [tipo, região, quantidade, raio da clareira, distância mínima, inclinação máx.]
const PLAN: Array[Array] = [
	["beacon", "forest", 1, 9.0, 120.0, 0.45], ["beacon", "peaks", 1, 9.0, 120.0, 0.5], ["beacon", "burnt", 1, 9.0, 120.0, 0.45],
	["lair", "forest", 1, 22.0, 150.0, 0.18], ["lair", "peaks", 1, 22.0, 150.0, 0.2], ["lair", "burnt", 1, 22.0, 150.0, 0.2],
	["lair", "swamp", 1, 22.0, 150.0, 0.18],
	["bonfire", "valley", 1, 4.0, 90.0, 0.12], ["bonfire", "forest", 1, 4.0, 90.0, 0.12], ["bonfire", "peaks", 1, 4.0, 90.0, 0.15],
	["bonfire", "burnt", 1, 4.0, 90.0, 0.15], ["bonfire", "swamp", 1, 4.0, 90.0, 0.12], ["bonfire", "coast", 2, 4.0, 90.0, 0.15],
	["shrine", "valley", 2, 8.0, 70.0, 0.15], ["shrine", "forest", 2, 8.0, 70.0, 0.15], ["shrine", "peaks", 2, 8.0, 70.0, 0.2],
	["shrine", "burnt", 2, 8.0, 70.0, 0.18], ["shrine", "swamp", 2, 8.0, 70.0, 0.15], ["shrine", "coast", 2, 8.0, 70.0, 0.18],
	["camp", "valley", 1, 0.0, 70.0, 0.25], ["camp", "forest", 3, 0.0, 70.0, 0.25], ["camp", "peaks", 2, 0.0, 70.0, 0.3],
	["camp", "burnt", 3, 0.0, 70.0, 0.3], ["camp", "swamp", 3, 0.0, 70.0, 0.25], ["camp", "coast", 2, 0.0, 70.0, 0.25],
	["chest", "valley", 5, 2.0, 35.0, 0.22], ["chest", "forest", 6, 2.0, 35.0, 0.22], ["chest", "peaks", 5, 2.0, 35.0, 0.22],
	["chest", "burnt", 5, 2.0, 35.0, 0.22], ["chest", "swamp", 5, 2.0, 35.0, 0.22], ["chest", "coast", 4, 2.0, 35.0, 0.22],
	["viewpoint", "peaks", 2, 3.0, 120.0, 0.6], ["viewpoint", "burnt", 1, 3.0, 120.0, 0.6], ["viewpoint", "coast", 2, 3.0, 120.0, 0.6],
	["story", "valley", 1, 3.0, 60.0, 0.3], ["story", "forest", 1, 3.0, 60.0, 0.3], ["story", "swamp", 1, 3.0, 60.0, 0.3],
	["story", "burnt", 1, 3.0, 60.0, 0.3], ["story", "peaks", 1, 3.0, 60.0, 0.3],
]

var _gen: IslandGenerator
var _placed: Array[Dictionary] = []
## Grade de alcance a partir do início (8 m): só aceita POIs conectados.
var _reach: PackedByteArray
const REACH_STEP: float = 8.0
var _reach_n: int = 0


func _initialize() -> void:
	_gen = IslandGenerator.new(WORLD_SEED, 2048)
	_build_reach()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = StableHash.derive_seed(WORLD_SEED, "pois")
	for f: Dictionary in FIXED:
		_placed.append(f.duplicate())
	var counters: Dictionary = {}
	for row: Array in PLAN:
		var kind: String = row[0]
		var region: String = row[1]
		for i: int in roundi(JsonUtil.num(row[2])):
			var poi: Dictionary = _place(kind, region, JsonUtil.num(row[3]), JsonUtil.num(row[4]), JsonUtil.num(row[5]), rng)
			if poi.is_empty() and region == "coast":
				# A costa é uma faixa estreita; o que não couber vai para a borda do vale/floresta.
				poi = _place(kind, "valley" if i % 2 == 0 else "forest", JsonUtil.num(row[3]), JsonUtil.num(row[4]), JsonUtil.num(row[5]), rng)
			if poi.is_empty():
				printerr("pois: não coube %s em %s" % [kind, region])
				continue
			var n: int = JsonUtil.get_i(counters, kind + region) + 1
			counters[kind + region] = n
			poi["id"] = "%s_%s_%d" % [kind, region, n]
			_placed.append(poi)
	var f: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(_placed, "\t"))
	f.close()
	var by_kind: Dictionary = {}
	for p: Dictionary in _placed:
		by_kind[p["kind"]] = JsonUtil.get_i(by_kind, p["kind"]) + 1
	print("pois: %d gravados em %s %s" % [_placed.size(), OUT, by_kind])
	quit(0)


## Mesma regra do teste de alcance: anda (desnível <= passo) e nada no raso.
func _build_reach() -> void:
	var n: int = int(L.WORLD_SIZE / REACH_STEP)
	_reach_n = n
	var hs: PackedFloat32Array = []
	hs.resize(n * n)
	for j: int in n:
		for i: int in n:
			hs[j * n + i] = _gen.height_at(-L.HALF + i * REACH_STEP, -L.HALF + j * REACH_STEP)
	_reach = PackedByteArray()
	_reach.resize(n * n)
	var start: Vector2i = Vector2i(int((30.0 + L.HALF) / REACH_STEP), int((180.0 + L.HALF) / REACH_STEP))
	var queue: Array[Vector2i] = [start]
	_reach[start.y * n + start.x] = 1
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		var hc: float = hs[c.y * n + c.x]
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n or _reach[q.y * n + q.x] == 1:
				continue
			var hq: float = hs[q.y * n + q.x]
			if hq < -12.0:
				continue
			if (hq < 0.0 and hc < 0.0) or absf(hq - hc) <= REACH_STEP:
				_reach[q.y * n + q.x] = 1
				queue.append(q)


func _reachable(x: float, z: float) -> bool:
	var i: int = int((x + L.HALF) / REACH_STEP)
	var j: int = int((z + L.HALF) / REACH_STEP)
	for dj: int in range(-2, 3):
		for di: int in range(-2, 3):
			var a: int = clampi(i + di, 0, _reach_n - 1)
			var b: int = clampi(j + dj, 0, _reach_n - 1)
			if _reach[b * _reach_n + a] == 1:
				return true
	return false


func _region_name(x: float, z: float, h: float) -> String:
	var id: int = _gen._classify(x, z, h)
	return str(L.REGION_NAMES[id])


func _slope(x: float, z: float) -> float:
	var d: float = 3.0
	var dx: float = (_gen.height_at(x + d, z) - _gen.height_at(x - d, z)) / (2.0 * d)
	var dz: float = (_gen.height_at(x, z + d) - _gen.height_at(x, z - d)) / (2.0 * d)
	return 1.0 - 1.0 / sqrt(1.0 + dx * dx + dz * dz)


func _place(kind: String, region: String, radius: float, min_dist: float, max_slope: float, rng: RandomNumberGenerator) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -INF
	var tries: int = 900 if kind == "beacon" or kind == "lair" or kind == "viewpoint" else 500
	if region == "coast":
		tries *= 4
	for t: int in tries:
		var x: float = rng.randf_range(-900.0, 900.0)
		var z: float = rng.randf_range(-900.0, 900.0)
		var h: float = _gen.height_at(x, z)
		if h < (1.2 if region == "coast" else 1.8) or (region == "swamp" and h < 0.4):
			continue
		if _region_name(x, z, h) != region:
			continue
		if not _reachable(x, z):
			continue
		if Vector2(x, z).distance_to(L.CITADEL_CENTER) < L.CITADEL_RADIUS + 40.0:
			continue
		if _too_close(x, z, min_dist):
			continue
		var s: float = _slope(x, z)
		if s > max_slope:
			continue
		var score: float = rng.randf()
		match kind:
			"beacon", "viewpoint":
				score = h  # o mais alto da região
			"lair":
				var c: Vector2 = L.REGION_CENTERS.get(_region_id(region), Vector2.ZERO)
				score = -Vector2(x, z).distance_to(c) - s * 200.0
			"bonfire", "shrine":
				score = -s * 100.0 + rng.randf() * 10.0
		if score > best_score:
			best_score = score
			best = {"kind": kind, "region": region, "x": snappedf(x, 0.5), "z": snappedf(z, 0.5), "radius": radius}
	return best


func _region_id(name: String) -> int:
	for k: int in L.REGION_NAMES:
		if str(L.REGION_NAMES[k]) == name:
			return k
	return -1


func _too_close(x: float, z: float, min_dist: float) -> bool:
	for p: Dictionary in _placed:
		var d: float = Vector2(x - JsonUtil.get_f(p, "x"), z - JsonUtil.get_f(p, "z")).length()
		if d < maxf(min_dist * 0.5, JsonUtil.get_f(p, "radius") + 12.0) or (p["kind"] == "beacon" and d < 60.0):
			if d < min_dist or p["kind"] != "chest":
				return true
	return false
