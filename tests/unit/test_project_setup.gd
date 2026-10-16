extends GdUnitTestSuite
## Fundação (M0): InputMap, presets, física, addons e remapeamento.


func test_input_map_matches_defaults() -> void:
	for action: StringName in InputDefaults.ACTIONS:
		assert_bool(InputMap.has_action(action)).override_failure_message("falta a ação %s" % action).is_true()
		var specs: Array = InputDefaults.ACTIONS[action]
		assert_int(InputMap.action_get_events(action).size()).is_equal(specs.size())


func test_project_input_section_matches_defaults() -> void:
	for action: StringName in InputDefaults.ACTIONS:
		assert_bool(ProjectSettings.has_setting("input/%s" % action)) \
			.override_failure_message("project.godot sem input/%s; rode tools/setup_input_map.gd" % action) \
			.is_true()


func test_alt_is_never_bound() -> void:
	for action: StringName in InputDefaults.ACTIONS:
		for ev: InputEvent in InputDefaults.events_for(action):
			var key: InputEventKey = ev as InputEventKey
			if key != null:
				assert_int(key.physical_keycode).is_not_equal(KEY_ALT)


## Contextos separados: jogo e menus (ações ui_*) podem reutilizar teclas, porque
## os menus pausam o jogo (ex.: Q/E trocam abas e também são feitiços).
func test_no_duplicate_keyboard_bindings() -> void:
	for ui_ctx: bool in [false, true]:
		_check_duplicates(ui_ctx)


func _check_duplicates(ui_ctx: bool) -> void:
	var seen: Dictionary = {}
	for action: StringName in InputDefaults.ACTIONS:
		if String(action).begins_with("ui_") != ui_ctx:
			continue
		for ev: InputEvent in InputDefaults.events_for(action):
			var key: InputEventKey = ev as InputEventKey
			if key == null:
				continue
			assert_bool(seen.has(key.physical_keycode)).override_failure_message(
				"tecla %s repetida em %s" % [OS.get_keycode_string(key.physical_keycode), action]).is_false()
			seen[key.physical_keycode] = action


func test_presets_are_complete() -> void:
	var reference: Dictionary = GraphicsPresets.PRESETS[GraphicsPresets.HIGH]
	for preset: StringName in GraphicsPresets.ORDER:
		var p: Dictionary = GraphicsPresets.PRESETS[preset]
		assert_array(p.keys()).contains_exactly_in_any_order(reference.keys())


func test_preset_guess() -> void:
	assert_str(String(GraphicsPresets.guess_from_adapter("NVIDIA GeForce RTX 4050 Laptop GPU"))).is_equal("high")
	assert_str(String(GraphicsPresets.guess_from_adapter("Intel(R) Iris(R) Xe Graphics"))).is_equal("medium")
	assert_str(String(GraphicsPresets.guess_from_adapter("Intel(R) UHD Graphics"))).is_equal("low")


func test_physics_is_jolt_at_60hz() -> void:
	assert_str(str(ProjectSettings.get_setting("physics/3d/physics_engine"))).is_equal("Jolt Physics")
	assert_int(Engine.physics_ticks_per_second).is_equal(60)


func test_terrain3d_extension_loaded() -> void:
	assert_bool(ClassDB.class_exists(&"Terrain3D")).is_true()
	var t: Node = ClassDB.instantiate(&"Terrain3D") as Node
	assert_object(t).is_not_null()
	t.free()


func test_settings_remap_and_reset() -> void:
	Settings.remap_action(&"interact", [["key", KEY_H]])
	var evs: Array[InputEvent] = InputMap.action_get_events(&"interact")
	assert_int(evs.size()).is_equal(1)
	var key: InputEventKey = evs[0] as InputEventKey
	assert_int(key.physical_keycode).is_equal(KEY_H)
	Settings.reset_controls()
	assert_int(InputMap.action_get_events(&"interact").size()).is_equal(2)
