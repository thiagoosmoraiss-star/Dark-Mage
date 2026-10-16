extends GdUnitTestSuite
## Terreno da ilha (M2): colisão = visual, dados = gerador, regiões coerentes.

const L = preload("res://world/island/island_layout.gd")

var _island: IslandTerrain
var _cam: Camera3D


func before() -> void:
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.position = Vector3(0, 200, 0)
	_cam.current = true
	_island = IslandTerrain.new()
	_island.full_collision = true
	add_child(_island)
	_island.terrain.set_camera(_cam)
	for i: int in 5:
		await get_tree().physics_frame


func after() -> void:
	_island.queue_free()
	_cam.queue_free()


func test_data_loaded() -> void:
	assert_int(_island.terrain.data.get_region_count()).is_greater_equal(4)
	var r: Vector2 = _island.terrain.data.get_height_range()
	assert_float(r.x).is_less(-10.0)
	assert_float(r.y).is_greater(150.0)


## Roteiro M2: colisão × altura do Terrain3D em 10 mil pontos, diferença ≤ 0,05 m.
## Critério estrito nos vértices da grade (onde a colisão e a malha visual são
## definidas). Entre vértices, a malha do Terrain3D usa diagonais alternadas e a
## colisão uma diagonal fixa; ali medimos a distância entre as superfícies
## (diferença vertical × normal.y) e exigimos P99 ≤ 0,05 m e < 0,5% acima disso
## (ver DECISIONS D27).
func test_collision_matches_visual_height() -> void:
	var space: PhysicsDirectSpaceState3D = _island.get_world_3d().direct_space_state
	var data: Terrain3DData = _island.terrain.data
	var rng: RandomNumberGenerator = Rng.make_rng(Rng.WORLD_SEED, "test_collision")
	var worst_vertex: float = 0.0
	var between: PackedFloat32Array = []
	var misses: int = 0
	for i: int in 20000:
		var on_vertex: bool = i < 10000
		var x: float = float(rng.randi_range(-900, 900)) if on_vertex else rng.randf_range(-900.0, 900.0)
		var z: float = float(rng.randi_range(-900, 900)) if on_vertex else rng.randf_range(-900.0, 900.0)
		var p: Vector3 = Vector3(x, 0, z)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 600, z), Vector3(x, -200, z)))
		if hit.is_empty():
			misses += 1
			continue
		var dy: float = absf((hit["position"] as Vector3).y - data.get_height(p))
		if on_vertex:
			worst_vertex = maxf(worst_vertex, dy)
		else:
			between.append(dy * absf(data.get_normal(p).y))
	between.sort()
	var n: int = between.size()
	var p99: float = between[n * 99 / 100]
	var over: float = float(n - between.bsearch(0.05)) / n
	print("colisão × visual: vértices máx %.4f m (10k); entre vértices P99 %.4f m, máx %.4f m, %.2f%% > 5 cm" % [
		worst_vertex, p99, between[n - 1], over * 100.0])
	assert_int(misses).is_equal(0)
	assert_float(worst_vertex).is_less_equal(0.05)
	assert_float(p99).is_less_equal(0.05)
	assert_float(over).is_less(0.005)


## Os dados gravados correspondem ao gerador (mesma seed) nos vértices.
func test_saved_data_matches_generator() -> void:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://world/island/data/meta.json"))
	assert_bool(meta is Dictionary).is_true()
	var m: Dictionary = meta
	assert_int(JsonUtil.get_i(m, "seed")).is_equal(Rng.WORLD_SEED)
	var g: IslandGenerator = IslandGenerator.new(Rng.WORLD_SEED, JsonUtil.get_i(m, "resolution"))
	var rng: RandomNumberGenerator = Rng.make_rng(Rng.WORLD_SEED, "test_data")
	var worst: float = 0.0
	for i: int in 300:
		var x: float = float(rng.randi_range(-900, 900))
		var z: float = float(rng.randi_range(-900, 900))
		worst = maxf(worst, absf(g.final_height_at(x, z) - _island.terrain.data.get_height(Vector3(x, 0, z))))
	assert_float(worst).is_less_equal(0.05)


func test_region_lookup() -> void:
	assert_int(_island.region_at(Vector3(L.CITADEL_CENTER.x, 0, L.CITADEL_CENTER.y))).is_equal(L.Region.CITADEL)
	assert_int(_island.region_at(Vector3(-1000, 0, -1000))).is_equal(L.Region.SEA)
	var s: Vector2 = L.REGION_CENTERS[L.Region.SWAMP]
	assert_int(_island.region_at(Vector3(s.x, 0, s.y))).is_equal(L.Region.SWAMP)
