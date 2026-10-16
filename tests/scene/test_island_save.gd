extends GdUnitTestSuite
## M9: o save guarda e restaura tudo na ilha completa — posição, vida, hora,
## progresso, inventário, equipamento, feitiços, marcadores do mapa e névoa.

const TEST_DIR: String = "user://test_saves_island"

var _old_dir: String
var _world: IslandWorld


func before() -> void:
	_old_dir = SaveSystem.directory
	SaveSystem.directory = TEST_DIR
	GameState.reset()
	Inventory.reset()
	var ps: PackedScene = load("res://levels/island/island.tscn") as PackedScene
	_world = ps.instantiate() as IslandWorld
	add_child(_world)
	for i: int in 20:
		await get_tree().physics_frame


func after() -> void:
	SaveSystem.delete_slot(1)
	SaveSystem.directory = _old_dir
	_world.queue_free()
	GameState.reset()
	Inventory.reset()
	await get_tree().process_frame


func test_save_and_load_restores_everything() -> void:
	var p: Player = _world.player
	assert_object(p).is_not_null()
	assert_object(_world.merchant).is_not_null()
	assert_object(_world.game_ui).is_not_null()
	# Estado a salvar.
	p.teleport(Vector3(40.0, _world.terrain.height_at(Vector3(40, 0, 170)) + 0.5, 170.0))
	GameState.add_souls(321)
	GameState.set_flag("beacon:beacon_valley")
	GameState.add_xp(GameState.xp_to_next(1))
	GameState.spend_point("mana")
	Inventory.add("staff_frost")
	for i: int in Inventory.SIZE:
		if Inventory.id_at(i) == "staff_frost":
			Inventory.equip_from(i)
	Inventory.add("amulet_moon")
	p.apply_progression()
	p.caster.unlock(&"umbral_step")
	p.caster.equip(2, &"umbral_step")
	_world.map_markers.append(Vector2(-120.0, 55.0))
	_world.fog.reveal(Vector3(300, 0, -300), 50.0)
	_world.atmosphere.set_hours(20.5)
	var pos: Vector3 = p.global_position
	assert_int(_world.save_game(1)).is_equal(OK)
	# Bagunça tudo.
	GameState.reset()
	Inventory.reset()
	_world.map_markers.clear()
	p.caster.equip(2, &"ether_chain")
	p.teleport(Vector3(0, 80, 0))
	_world.atmosphere.set_hours(8.0)
	# Carrega.
	assert_bool(_world.load_game(1)).is_true()
	assert_float(p.global_position.distance_to(pos)).is_less(0.5)
	assert_int(GameState.souls).is_equal(321)
	assert_bool(GameState.has_flag("beacon:beacon_valley")).is_true()
	assert_int(GameState.level).is_equal(2)
	assert_int(GameState.attributes["mana"]).is_equal(1)
	assert_str(Inventory.equipped["staff"]).is_equal("staff_frost")
	assert_int(Inventory.count("amulet_moon")).is_equal(1)
	assert_int(Inventory.count("staff_apprentice")).is_equal(1)
	assert_float(p.stats.max_mana).is_equal(110.0)
	assert_str(String(p.caster.equipped[2])).is_equal("umbral_step")
	assert_bool(p.caster.unlocked.has(&"umbral_step")).is_true()
	assert_int(_world.map_markers.size()).is_equal(1)
	assert_float(_world.map_markers[0].x).is_equal(-120.0)
	assert_bool(_world.fog.is_revealed(Vector3(300, 0, -300))).is_true()
	assert_float(_world.atmosphere.hours).is_equal_approx(20.5, 0.01)
