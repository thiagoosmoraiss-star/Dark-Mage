extends GdUnitTestSuite
## Lógica pura de combate: status, recargas, dados de feitiço, hit-stop.


func test_status_freeze_slow_and_expire() -> void:
	var s: StatusEffects = StatusEffects.new()
	s.apply(StatusEffects.Kind.FROZEN, 1.0)
	assert_float(s.speed_multiplier()).is_equal(0.0)
	assert_bool(s.can_act()).is_false()
	assert_float(s.damage_taken_multiplier()).is_greater(1.0)
	s.tick(1.1)
	assert_bool(s.has(StatusEffects.Kind.FROZEN)).is_false()
	s.apply(StatusEffects.Kind.SLOWED, 2.0, 0.4)
	assert_float(s.speed_multiplier()).is_equal_approx(0.6, 0.001)


func test_status_burning_deals_damage_over_time() -> void:
	var s: StatusEffects = StatusEffects.new()
	s.apply(StatusEffects.Kind.BURNING, 2.0, 5.0)
	var total: float = 0.0
	for i: int in 120:
		total += s.tick(1.0 / 60.0)
	assert_float(total).is_equal_approx(10.0, 0.2)


func test_status_resistance() -> void:
	var s: StatusEffects = StatusEffects.new()
	s.resist[StatusEffects.Kind.FROZEN] = 1.0
	s.apply(StatusEffects.Kind.FROZEN, 3.0)
	assert_bool(s.has(StatusEffects.Kind.FROZEN)).is_false()


func test_cooldowns() -> void:
	var c: Cooldowns = Cooldowns.new()
	c.start(&"x", 2.0)
	assert_bool(c.ready(&"x")).is_false()
	assert_float(c.fraction(&"x")).is_equal(1.0)
	c.tick(1.0)
	assert_float(c.fraction(&"x")).is_equal_approx(0.5, 0.001)
	c.rate = 2.0
	c.tick(0.6)
	assert_bool(c.ready(&"x")).is_true()


func test_all_eight_spells_load_and_cover_roles() -> void:
	var ids: Array[StringName] = Spells.all_ids()
	assert_int(ids.size()).is_equal(8)
	var kinds: Dictionary = {}
	for id: StringName in ids:
		var s: SpellData = Spells.get_spell(id)
		assert_object(s).is_not_null()
		kinds[s.kind] = true
		assert_str(tr(s.name_key)).is_not_equal(s.name_key)
	assert_int(kinds.size()).is_equal(8)
	# Pelo menos 2 feitiços interagem com o mundo (roteiro 4.3).
	var world: int = 0
	for id: StringName in ids:
		if not Spells.get_spell(id).world_tags.is_empty():
			world += 1
	assert_int(world).is_greater_equal(2)


func test_hit_stop_restores_time_scale() -> void:
	HitStop.hit(get_tree(), 50, 0.05)
	assert_float(Engine.time_scale).is_equal(0.05)
	await await_millis(150)
	assert_float(Engine.time_scale).is_equal(1.0)
	HitStop.reset()
