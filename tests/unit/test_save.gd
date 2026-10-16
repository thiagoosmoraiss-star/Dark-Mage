extends GdUnitTestSuite
## Save: ida e volta, migração das fixtures v0 e v1, arquivo corrompido e backup.

const TEST_DIR: String = "user://test_saves"

var _old_dir: String


func before_test() -> void:
	_old_dir = SaveSystem.directory
	SaveSystem.directory = TEST_DIR
	for slot: int in SaveSystem.SLOT_COUNT:
		SaveSystem.delete_slot(slot)


func after_test() -> void:
	for slot: int in SaveSystem.SLOT_COUNT:
		SaveSystem.delete_slot(slot)
	SaveSystem.directory = _old_dir


func _sample() -> Dictionary:
	var data: Dictionary = SaveCodec.new_save()
	data["world_seed"] = 99
	var player: Dictionary = data["player"]
	player["position"] = [10.5, 3.0, -7.25]
	player["health"] = 42.0
	var world: Dictionary = data["world"]
	world["time_of_day_h"] = 21.5
	world["flags"] = {"beacon_1": true}
	return data


func _health(data: Dictionary) -> float:
	var player: Dictionary = data["player"]
	return SaveCodec.num(player["health"], -1.0)


func test_round_trip() -> void:
	assert_int(SaveSystem.save_slot(0, _sample())).is_equal(OK)
	var loaded: Dictionary = SaveSystem.load_slot(0)
	assert_bool(loaded.is_empty()).is_false()
	var player: Dictionary = loaded["player"]
	var world: Dictionary = loaded["world"]
	var flags: Dictionary = world["flags"]
	assert_array(player["position"] as Array).is_equal([10.5, 3.0, -7.25])
	assert_float(_health(loaded)).is_equal(42.0)
	assert_float(SaveCodec.num(world["time_of_day_h"], -1.0)).is_equal(21.5)
	assert_bool(flags.get("beacon_1", false) == true).is_true()


func test_invalid_slot_rejected() -> void:
	assert_int(SaveSystem.save_slot(3, _sample())).is_equal(ERR_INVALID_PARAMETER)
	assert_bool(SaveSystem.load_slot(-1).is_empty()).is_true()


func test_invalid_data_rejected() -> void:
	var bad: Dictionary = _sample()
	var world: Dictionary = bad["world"]
	world["time_of_day_h"] = 30.0
	assert_int(SaveSystem.save_slot(0, bad)).is_equal(ERR_INVALID_DATA)


func test_corrupted_file_falls_back_to_backup() -> void:
	assert_int(SaveSystem.save_slot(1, _sample())).is_equal(OK)
	var second: Dictionary = _sample()
	var player: Dictionary = second["player"]
	player["health"] = 7.0
	assert_int(SaveSystem.save_slot(1, second)).is_equal(OK)
	assert_float(_health(SaveSystem.load_slot(1))).is_equal(7.0)
	var f: FileAccess = FileAccess.open(SaveSystem.slot_path(1), FileAccess.WRITE)
	f.store_string("{ isto nao e json")
	f.close()
	var loaded: Dictionary = SaveSystem.load_slot(1)
	assert_bool(loaded.is_empty()).is_false()
	assert_float(_health(loaded)).is_equal(42.0)


func test_garbage_never_crashes() -> void:
	var cases: Array[String] = [
		"", "null", "[]", "{}",
		"{\"magic\":\"dark-mage-save\",\"version\":999}",
		"{\"magic\":\"dark-mage-save\",\"version\":1,\"player\":5}",
		"{\"magic\":\"outro\",\"version\":1}",
	]
	for text: String in cases:
		assert_bool(SaveCodec.decode(text).is_empty()).override_failure_message(text).is_true()


func test_migrates_v0_fixture() -> void:
	var text: String = FileAccess.get_file_as_string("res://tests/fixtures/save_v0.json")
	var data: Dictionary = SaveCodec.decode(text)
	assert_bool(data.is_empty()).is_false()
	assert_int(roundi(SaveCodec.num(data["version"], -1.0))).is_equal(SaveCodec.VERSION)
	var player: Dictionary = data["player"]
	assert_float(_health(data)).is_equal(80.0)
	assert_bool(player.has("hp")).is_false()
	assert_bool(data.has("world")).is_true()


func test_migrates_v1_fixture_to_v2_keeping_progress() -> void:
	var text: String = FileAccess.get_file_as_string("res://tests/fixtures/save_v1.json")
	var data: Dictionary = SaveCodec.decode(text)
	assert_bool(data.is_empty()).is_false()
	assert_int(roundi(SaveCodec.num(data["version"], -1.0))).is_equal(2)
	assert_bool(data["inventory"] is Dictionary).is_true()
	assert_bool(data["map_markers"] is Array).is_true()
	# Nada do v1 se perde.
	var prog: Dictionary = data["progress"]
	assert_int(JsonUtil.get_i(prog, "souls")).is_equal(840)
	assert_int(JsonUtil.get_i(prog, "level")).is_equal(5)
	GameState.from_dict(prog)
	Inventory.from_dict(data["inventory"] as Dictionary)
	assert_bool(GameState.has_flag("guardian:forest")).is_true()
	assert_str(Inventory.equipped["staff"]).is_equal("staff_apprentice")
	assert_int(Inventory.count("potion_health")).is_equal(3)
	GameState.reset()
	Inventory.reset()


func test_v2_requires_inventory_and_markers() -> void:
	var data: Dictionary = SaveCodec.new_save()
	assert_bool(SaveCodec.validate(data)).is_true()
	data.erase("inventory")
	assert_bool(SaveCodec.validate(data)).is_false()


func test_slot_info_and_latest_slot() -> void:
	assert_int(SaveSystem.latest_slot()).is_equal(-1)
	var a: Dictionary = _sample()
	a["progress"] = {"level": 7}
	assert_int(SaveSystem.save_slot(2, a)).is_equal(OK)
	var info: Dictionary = SaveSystem.slot_info(2)
	assert_int(JsonUtil.get_i(info, "level")).is_equal(7)
	assert_int(SaveSystem.latest_slot()).is_equal(2)
	assert_bool(SaveSystem.slot_info(1).is_empty()).is_true()
