extends GdUnitTestSuite
## Vegetação (M4): distribuição determinística, tudo assentado no terreno,
## nada na água por engano, clareiras respeitadas, grama por regras.

const L = preload("res://world/island/island_layout.gd")

var _island: IslandTerrain
var _cam: Camera3D
var _veg: VegetationSystem


func before() -> void:
	_cam = Camera3D.new()
	add_child(_cam)
	_island = IslandTerrain.new()
	add_child(_island)
	_island.terrain.set_camera(_cam)
	_veg = VegetationSystem.new()
	_veg.terrain = _island
	add_child(_veg)
	await get_tree().process_frame


func after() -> void:
	_veg.queue_free()
	_island.queue_free()
	_cam.queue_free()


func test_counts_per_kind() -> void:
	var c: Dictionary = _veg.count_by_kind()
	print("vegetação: ", c, " total ", _veg.instances.size())
	assert_int(JsonUtil.get_i(c, VegetationSystem.Kind.GIANT)).is_greater(150)
	assert_int(JsonUtil.get_i(c, VegetationSystem.Kind.OAK)).is_greater(150)
	assert_int(JsonUtil.get_i(c, VegetationSystem.Kind.PINE)).is_greater(150)
	assert_int(JsonUtil.get_i(c, VegetationSystem.Kind.DEAD)).is_greater(50)
	assert_int(JsonUtil.get_i(c, VegetationSystem.Kind.ROCK)).is_greater(300)


func test_everything_sits_on_terrain() -> void:
	var data: Terrain3DData = _island.terrain.data
	for inst: VegetationSystem.Instance in _veg.instances:
		var p: Vector3 = inst.xform.origin
		var h: float = data.get_height(p)
		# Nada flutua; o afundamento é proporcional ao tamanho (base enterrada).
		assert_float(p.y).override_failure_message("flutuando em %s" % p).is_less_equal(h + 0.01)
		assert_float(h - p.y).override_failure_message("enterrado demais em %s" % p).is_less_equal(maxf(0.3, inst.height * 0.3))


func test_no_trees_in_water_and_clearings_respected() -> void:
	for inst: VegetationSystem.Instance in _veg.instances:
		var p: Vector3 = inst.xform.origin
		if inst.kind != VegetationSystem.Kind.ROCK and inst.kind != VegetationSystem.Kind.DEAD:
			assert_float(p.y).override_failure_message("árvore na água em %s" % p).is_greater(0.4)
		assert_float(Vector2(p.x, p.z).distance_to(L.CITADEL_CENTER)).is_greater(L.CITADEL_RADIUS)


func test_distribution_is_deterministic() -> void:
	var first: Array[Transform3D] = []
	for i: int in mini(50, _veg.instances.size()):
		first.append(_veg.instances[i].xform)
	var n: int = _veg.instances.size()
	_veg.generate()
	assert_int(_veg.instances.size()).is_equal(n)
	for i: int in first.size():
		assert_bool(_veg.instances[i].xform.is_equal_approx(first[i])).is_true()


func test_grass_chunk_follows_rules() -> void:
	var grass: GrassField = GrassField.new()
	grass.terrain = _island
	add_child(grass)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var key: Vector2i = Vector2i(floori(IslandWorld.SPAWN.x / GrassField.CHUNK), floori(IslandWorld.SPAWN.y / GrassField.CHUNK))
	var count: int = grass.fill_chunk(mm, key)
	assert_int(count).is_greater(80)
	var again: int = grass.fill_chunk(mm, key)
	assert_int(again).is_equal(count)
	# Mar aberto: nenhuma grama.
	assert_int(grass.fill_chunk(mm, Vector2i(-80, -80))).is_equal(0)
	grass.queue_free()
