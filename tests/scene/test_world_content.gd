extends GdUnitTestSuite
## Conteúdo do mundo (M7): POIs bem posicionados e alcançáveis, interativos
## (baú, farol, fogueira, mirante) e os 6 tipos de inimigo.

const L = preload("res://world/island/island_layout.gd")

var _island: IslandTerrain
var _cam: Camera3D


func before() -> void:
	_cam = Camera3D.new()
	add_child(_cam)
	_island = IslandTerrain.new()
	_island.full_collision = true
	add_child(_island)
	_island.terrain.set_camera(_cam)
	for i: int in 5:
		await get_tree().physics_frame


func after() -> void:
	_island.queue_free()
	_cam.queue_free()


func test_poi_counts_match_scope() -> void:
	var count: Dictionary = {}
	for p: Dictionary in WorldPois.all():
		count[p["kind"]] = JsonUtil.get_i(count, p["kind"]) + 1
	print("POIs: ", count)
	assert_int(JsonUtil.get_i(count, &"beacon")).is_equal(4)
	assert_int(JsonUtil.get_i(count, &"shrine")).is_equal(12)
	assert_int(JsonUtil.get_i(count, &"lair")).is_equal(4)
	assert_int(JsonUtil.get_i(count, &"bonfire")).is_greater_equal(6)
	var secrets: int = JsonUtil.get_i(count, &"chest") + JsonUtil.get_i(count, &"viewpoint") + JsonUtil.get_i(count, &"story")
	assert_int(secrets).is_greater_equal(38)
	# Todas as 6 regiões têm conteúdo.
	var regions: Dictionary = {}
	for p: Dictionary in WorldPois.all():
		regions[p["region"]] = true
	for r: StringName in [&"valley", &"forest", &"peaks", &"burnt", &"swamp", &"coast"]:
		assert_bool(regions.has(r)).override_failure_message("sem POI em %s" % r).is_true()


## Roteiro 3.3/11: nenhum POI dentro de rocha, flutuando ou submerso por engano.
func test_pois_sit_on_ground_and_above_water() -> void:
	var space: PhysicsDirectSpaceState3D = _island.get_world_3d().direct_space_state
	for p: Dictionary in WorldPois.all():
		var p2: Vector2 = WorldPois.pos2(p)
		var h: float = _island.height_at(Vector3(p2.x, 0, p2.y))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p2.x, 600, p2.y), Vector3(p2.x, -100, p2.y), 1))
		assert_bool(hit.is_empty()).override_failure_message("sem chão em %s" % p["id"]).is_false()
		var ground: float = (hit["position"] as Vector3).y
		assert_float(absf(ground - h)).override_failure_message("altura divergente em %s" % p["id"]).is_less(0.3)
		if p["kind"] != &"camp":
			assert_float(h).override_failure_message("submerso: %s (%.1f m)" % [p["id"], h]).is_greater(0.3)
		# Inclinação aceitável para estruturas (exceto mirantes/faróis, que ficam no alto).
		if p["kind"] in [&"bonfire", &"shrine", &"lair", &"chest"]:
			assert_float(_island.terrain.data.get_normal(Vector3(p2.x, 0, p2.y)).y).override_failure_message(
				"inclinado demais: %s" % p["id"]).is_greater(0.7)


## Alcançabilidade por grade: a partir do início, andando (inclinação < 45°) e
## nadando; POIs no alto exigem no máximo uma escalada de 30 m.
func test_all_pois_reachable_from_spawn() -> void:
	var step: float = 6.0
	var n: int = int(L.WORLD_SIZE / step)
	var heights: PackedFloat32Array = []
	heights.resize(n * n)
	for j: int in n:
		for i: int in n:
			heights[j * n + i] = _island.height_at(Vector3(-L.HALF + i * step, 0, -L.HALF + j * step))
	var start: Vector2i = Vector2i(int((IslandWorld.SPAWN.x + L.HALF) / step), int((IslandWorld.SPAWN.y + L.HALF) / step))
	var seen: PackedByteArray = []
	seen.resize(n * n)
	var queue: Array[Vector2i] = [start]
	seen[start.y * n + start.x] = 1
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		var hc: float = heights[c.y * n + c.x]
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n or seen[q.y * n + q.x] == 1:
				continue
			var hq: float = heights[q.y * n + q.x]
			if hq < -12.0:
				continue  # mar aberto: fora da ilha
			var swim: bool = hq < 0.0 and hc < 0.0
			if swim or absf(hq - hc) <= step:
				seen[q.y * n + q.x] = 1
				queue.append(q)
	var unreachable: PackedStringArray = []
	for p: Dictionary in WorldPois.all():
		var p2: Vector2 = WorldPois.pos2(p)
		var g: Vector2i = Vector2i(int((p2.x + L.HALF) / step), int((p2.y + L.HALF) / step))
		var ok: bool = false
		for dj: int in range(-6, 7):
			for di: int in range(-6, 7):
				var q: Vector2i = g + Vector2i(di, dj)
				if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
					continue
				if seen[q.y * n + q.x] == 1 and heights[g.y * n + g.x] - heights[q.y * n + q.x] <= 30.0:
					ok = true
		if not ok:
			unreachable.append(String(p["id"] as StringName))
	assert_array(Array(unreachable)).override_failure_message("inalcançáveis: %s" % unreachable).is_empty()


func test_chest_loot_is_deterministic() -> void:
	var a: Dictionary = Chest.roll_loot("chest_valley_1", &"valley", false)
	var b: Dictionary = Chest.roll_loot("chest_valley_1", &"valley", false)
	assert_dict(a).is_equal(b)
	var g: Dictionary = Chest.roll_loot("chest_valley_1", &"valley", true)
	assert_int(JsonUtil.get_i(g, "souls")).is_greater(JsonUtil.get_i(a, "souls"))


func test_game_state_progress_and_serialization() -> void:
	GameState.reset()
	GameState.add_xp(GameState.xp_to_next(1) + 5)
	assert_int(GameState.level).is_equal(2)
	assert_int(GameState.attribute_points).is_equal(1)
	GameState.set_flag("chest:x")
	GameState.add_souls(40)
	GameState.purify(&"swamp", 0.5)
	assert_float(GameState.corruption(&"swamp")).is_equal_approx(0.5, 0.001)
	var d: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset()
	GameState.from_dict(d)
	assert_bool(GameState.has_flag("chest:x")).is_true()
	assert_int(GameState.souls).is_equal(40)
	assert_int(GameState.level).is_equal(2)
	assert_float(GameState.corruption(&"swamp")).is_equal_approx(0.5, 0.001)
	GameState.reset()


func test_all_six_enemy_types_spawn_and_take_damage() -> void:
	var ids: Array[String] = ["mist_crawler", "bone_archer", "swamp_witch", "spectral_bat", "stone_golem", "lake_serpent"]
	for id: String in ids:
		var data: EnemyData = load("res://data/enemies/%s.tres" % id) as EnemyData
		var e: Enemy = IslandWorld.enemy_class(data.behavior)
		e.data = data
		add_child(e)
		e.global_position = Vector3(0, _island.height_at(Vector3.ZERO) + 0.2, 0)
		await get_tree().physics_frame
		if data.behavior == &"serpent":
			(e.model as SerpentModel).emerge = 1.0
		var hp: float = e.health
		var info: DamageInfo = DamageInfo.make(10.0, DamageInfo.Element.ARCANE, null)
		info.hit_position = e.global_position
		e.take_damage(info)
		assert_float(e.health).override_failure_message("%s não recebeu dano" % id).is_less(hp)
		e.queue_free()
		await get_tree().process_frame


func test_golem_weak_point_and_submerged_serpent() -> void:
	var g: GolemEnemy = GolemEnemy.new()
	g.data = load("res://data/enemies/stone_golem.tres") as EnemyData
	add_child(g)
	await get_tree().physics_frame
	var front: DamageInfo = DamageInfo.make(10.0, DamageInfo.Element.ARCANE, null)
	front.hit_position = g.global_position + Vector3(0, 2, -3)
	front.direction = Vector3(0, 0, 1)  # vindo da frente
	var back: DamageInfo = DamageInfo.make(10.0, DamageInfo.Element.ARCANE, null)
	back.hit_position = (g.model as GolemModel).weak_point.global_position
	back.direction = -g.global_basis.z
	assert_float(g._hit_multiplier(back)).is_greater(g._hit_multiplier(front) * 2.0)
	g.queue_free()
	var s: SerpentEnemy = SerpentEnemy.new()
	s.data = load("res://data/enemies/lake_serpent.tres") as EnemyData
	add_child(s)
	await get_tree().physics_frame
	var hp: float = s.health
	s.take_damage(DamageInfo.make(50.0, DamageInfo.Element.ARCANE, null))
	assert_float(s.health).is_equal(hp)  # submersa: imune
	s.queue_free()
