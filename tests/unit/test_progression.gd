extends GdUnitTestSuite
## M9: inventário (pilhas, mover, equipar, bônus, validação), mercador, diário,
## pontos de atributo e remapeamento com troca de conflitos.


func before_test() -> void:
	GameState.reset()
	Inventory.reset()


func after_test() -> void:
	GameState.reset()
	Inventory.reset()
	Settings.reset_controls()


func test_start_inventory() -> void:
	assert_str(Inventory.equipped["staff"]).is_equal("staff_apprentice")
	assert_int(Inventory.count("potion_health")).is_equal(3)
	assert_int(Inventory.count("potion_mana")).is_equal(2)


func test_stacks_and_capacity() -> void:
	assert_int(Inventory.add("potion_health", 10)).is_equal(10)
	assert_int(Inventory.count("potion_health")).is_equal(13)
	# 9 por pilha: 13 poções ocupam 2 casas.
	var stacks: int = 0
	for i: int in Inventory.SIZE:
		if Inventory.id_at(i) == "potion_health":
			stacks += 1
	assert_int(stacks).is_equal(2)
	# Equipamento não empilha; a bolsa enche.
	var free: int = Inventory.free_slots()
	assert_int(Inventory.add("robe_wanderer", 100)).is_equal(free)
	assert_int(Inventory.free_slots()).is_equal(0)
	assert_int(Inventory.add("amulet_moon")).is_equal(0)
	assert_int(Inventory.add("nao_existe")).is_equal(0)


func test_move_swaps_and_merges() -> void:
	Inventory.add("staff_thorn")
	var staff_i: int = _find("staff_thorn")
	Inventory.move(staff_i, 30)
	assert_str(Inventory.id_at(30)).is_equal("staff_thorn")
	assert_str(Inventory.id_at(staff_i)).is_equal("")
	# Duas pilhas da mesma poção se juntam.
	Inventory.slots[20] = {"id": "potion_mana", "count": 4}
	Inventory.move(20, _find("potion_mana"))
	assert_int(Inventory.count("potion_mana")).is_equal(6)


func test_equip_swaps_and_bonus() -> void:
	Inventory.add("robe_warden")
	Inventory.add("amulet_heart")
	assert_bool(Inventory.equip_from(_find("robe_warden"))).is_true()
	assert_bool(Inventory.equip_from(_find("amulet_heart"))).is_true()
	assert_float(Inventory.bonus("health")).is_equal(45.0)
	# Trocar de cajado devolve o antigo para a mesma casa.
	Inventory.add("staff_ember")
	var i: int = _find("staff_ember")
	Inventory.equip_from(i)
	assert_str(Inventory.equipped["staff"]).is_equal("staff_ember")
	assert_str(Inventory.id_at(i)).is_equal("staff_apprentice")
	assert_int(JsonUtil.get_i(Inventory.basic_attack(), "element")).is_equal(DamageInfo.Element.FIRE)
	# O cajado nunca fica vazio; o manto pode sair.
	assert_bool(Inventory.unequip("staff")).is_false()
	assert_bool(Inventory.unequip("robe")).is_true()
	assert_float(Inventory.bonus("health")).is_equal(20.0)
	# Poção não se equipa.
	assert_bool(Inventory.equip_from(_find("potion_health"))).is_false()


func test_inventory_round_trip_and_garbage() -> void:
	Inventory.add("staff_storm")
	Inventory.equip_from(_find("staff_storm"))
	var d: Dictionary = JSON.parse_string(JSON.stringify(Inventory.to_dict()))
	Inventory.reset()
	Inventory.from_dict(d)
	assert_str(Inventory.equipped["staff"]).is_equal("staff_storm")
	assert_int(Inventory.count("staff_apprentice")).is_equal(1)
	Inventory.from_dict({"slots": [{"id": "hack", "count": 99}, {"id": "potion_health", "count": 999}, 5],
		"equipped": {"staff": "robe_warden", "robe": "staff_dusk"}})
	assert_str(Inventory.id_at(0)).is_equal("")
	assert_int(Inventory.count_at(1)).is_equal(ItemDb.STACK_MAX)
	assert_str(Inventory.equipped["staff"]).is_equal("staff_apprentice")
	assert_str(Inventory.equipped["robe"]).is_equal("")


func test_merchant_stock_buy_and_sell() -> void:
	var base: Array[String] = Merchant.stock()
	assert_bool(base.has("staff_thorn")).is_true()
	assert_bool(base.has("staff_dusk")).is_false()
	for r: String in ["forest", "peaks", "burnt", "swamp"]:
		GameState.set_flag("guardian:" + r)
	assert_bool(Merchant.stock().has("staff_dusk")).is_true()
	assert_bool(Merchant.buy("staff_thorn")).is_false()  # sem almas
	GameState.add_souls(500)
	assert_bool(Merchant.buy("staff_thorn")).is_true()
	assert_int(GameState.souls).is_equal(80)
	assert_bool(Inventory.owns("staff_thorn")).is_true()
	assert_bool(Merchant.sell_slot(_find("staff_thorn"))).is_true()
	assert_int(GameState.souls).is_equal(80 + 105)
	GameState.add_material("sea_pearl", 3)
	assert_bool(Merchant.sell_material("sea_pearl", 2)).is_true()
	assert_int(GameState.souls).is_equal(185 + 28)
	assert_bool(Merchant.sell_material("sea_pearl", 5)).is_false()


func test_attribute_points() -> void:
	assert_bool(GameState.spend_point("power")).is_false()
	GameState.add_xp(GameState.xp_to_next(1))
	assert_int(GameState.level).is_equal(2)
	assert_bool(GameState.spend_point("power")).is_true()
	assert_int(GameState.attributes["power"]).is_equal(1)
	assert_bool(GameState.spend_point("power")).is_false()
	assert_bool(GameState.spend_point("sorte")).is_false()


func test_journal_follows_flags() -> void:
	var q: Dictionary = Journal.current_objective()
	assert_str(str(q["id"])).is_equal("awaken")
	GameState.set_flag("beacon:beacon_valley")
	assert_str(str(Journal.current_objective()["id"])).is_equal("beacons")
	for b: Dictionary in WorldPois.by_kind(&"beacon"):
		GameState.set_flag("beacon:" + String(b["id"] as StringName))
	var g: Dictionary = Journal.current_objective()
	assert_str(str(g["id"])).is_equal("guardians")
	assert_int(JsonUtil.get_i(g, "total")).is_equal(4)
	for r: String in ["forest", "peaks", "burnt", "swamp"]:
		GameState.set_flag("guardian:" + r)
	assert_str(str(Journal.current_objective()["id"])).is_equal("citadel")
	GameState.set_flag("final:fear")
	assert_bool(Journal.current_objective().is_empty()).is_true()
	var all: Array[Dictionary] = Journal.quests()
	assert_int(all.size()).is_equal(10)


func test_rebind_swaps_conflicts() -> void:
	Settings.rebind(&"jump", ["key", KEY_K])
	assert_str(InputDefaults.action_label(&"jump", false)).is_equal("K")
	# Q já é do feitiço 1: o pulo pega Q e o feitiço 1 recebe o antigo K.
	Settings.rebind(&"jump", ["key", KEY_Q])
	assert_str(InputDefaults.action_label(&"jump", false)).is_equal("Q")
	assert_str(InputDefaults.action_label(&"spell_1", false)).is_equal("K")
	# O gamepad do pulo continua A.
	assert_str(InputDefaults.action_label(&"jump", true)).is_equal("A")
	Settings.rebind(&"dodge", ["joy_button", JOY_BUTTON_Y])
	assert_str(InputDefaults.action_label(&"dodge", true)).is_equal("Y")
	# LB + botão é outro contexto: trocar o feitiço 1 do gamepad não mexe no pulo.
	assert_str(InputDefaults.action_label(&"spell_1", true)).is_equal("LB+A")
	Settings.rebind(&"pad_spell_1", ["joy_button", JOY_BUTTON_Y])
	assert_str(InputDefaults.action_label(&"spell_1", true)).is_equal("LB+Y")
	assert_str(InputDefaults.action_label(&"spell_4", true)).is_equal("LB+A")
	assert_str(InputDefaults.action_label(&"jump", true)).is_equal("A")
	Settings.reset_controls()
	assert_str(InputDefaults.action_label(&"jump", false)).is_equal("Space")


func _find(id: String) -> int:
	for i: int in Inventory.SIZE:
		if Inventory.id_at(i) == id:
			return i
	return -1
