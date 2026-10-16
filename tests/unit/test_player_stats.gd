extends GdUnitTestSuite


func test_stamina_drain_exhaust_and_recover() -> void:
	var s: PlayerStats = PlayerStats.new()
	assert_bool(s.use_stamina(60.0)).is_true()
	assert_bool(s.use_stamina(60.0)).is_true()
	assert_float(s.stamina).is_equal(0.0)
	assert_bool(s.exhausted).is_true()
	assert_bool(s.use_stamina(1.0)).is_false()
	for i: int in 60:  # 1 s: ainda no atraso + começo da regeneração
		s.tick(1.0 / 60.0)
	assert_bool(s.exhausted).is_true()
	for i: int in 120:
		s.tick(1.0 / 60.0)
	assert_bool(s.exhausted).is_false()
	assert_float(s.stamina).is_greater(30.0)


func test_damage_heal_and_death() -> void:
	var s: PlayerStats = PlayerStats.new()
	var died: Array[bool] = [false]
	s.died.connect(func() -> void: died[0] = true)
	s.damage(30.0)
	assert_float(s.health).is_equal(70.0)
	s.invulnerable = true
	s.damage(50.0)
	assert_float(s.health).is_equal(70.0)
	s.invulnerable = false
	s.heal(100.0)
	assert_float(s.health).is_equal(100.0)
	s.damage(200.0)
	assert_bool(died[0]).is_true()


func test_mana_regen_faster_out_of_combat() -> void:
	var a: PlayerStats = PlayerStats.new()
	var b: PlayerStats = PlayerStats.new()
	a.use_mana(50.0)
	b.use_mana(50.0)
	b.in_combat = true
	for i: int in 60:
		a.tick(1.0 / 60.0)
		b.tick(1.0 / 60.0)
	assert_float(a.mana).is_greater(b.mana)


func test_serialization_round_trip() -> void:
	var s: PlayerStats = PlayerStats.new()
	s.max_health = 140.0
	s.set_health(90.0)
	var t: PlayerStats = PlayerStats.new()
	t.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())) as Dictionary)
	assert_float(t.max_health).is_equal(140.0)
	assert_float(t.health).is_equal(90.0)
