extends GdUnitTestSuite
## Combate (M6): ataques e feitiços acertam, IA telegrafa e ataca, esquiva
## perfeita, limite de atacantes e teste de vazamento com 200 conjurações.

var _arena: Node3D
var _perfect_fired: bool = false


func before_test() -> void:
	_arena = Node3D.new()
	add_child(_arena)
	var ground: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200, 2, 200)
	cs.shape = box
	cs.position.y = -1.0
	ground.add_child(cs)
	_arena.add_child(ground)
	_arena.add_child(Vfx.new())
	_arena.add_child(ProjectilePool.new())
	_arena.add_child(CombatDirector.new())
	HitStop.reset()


func after_test() -> void:
	HitStop.reset()
	_arena.queue_free()
	await get_tree().process_frame


func _player() -> Player:
	var p: Player = Player.new()
	p.with_camera = false
	p.use_scripted_input = true
	_arena.add_child(p)
	p.global_position = Vector3(0, 0.05, 0)
	return p


func _enemy(id: String, pos: Vector3) -> Enemy:
	var e: Enemy = Enemy.new()
	e.data = load("res://data/enemies/%s.tres" % id) as EnemyData
	_arena.add_child(e)
	e.global_position = pos
	e.home = pos
	return e


func _steps(p: Player, n: int) -> void:
	for i: int in n:
		await p.stepped


func test_basic_attack_combo_hits_enemy() -> void:
	var p: Player = _player()
	var e: Enemy = _enemy("mist_crawler", Vector3(0, 0.05, -8))
	e.set_physics_process(false)  # alvo parado
	await _steps(p, 5)
	p.scripted_input[&"attack"] = true
	await _steps(p, 50)
	p.scripted_input[&"attack"] = false
	await _steps(p, 20)
	assert_float(e.health).is_less(e.max_health - 15.0)


func test_charged_lance_hits_harder_than_tap() -> void:
	var p: Player = _player()
	var a: Enemy = _enemy("mist_crawler", Vector3(0, 0.05, -8))
	a.set_physics_process(false)
	await _steps(p, 5)
	p.scripted_input[&"spell_1"] = true
	await _steps(p, 1)
	p.scripted_input[&"spell_1"] = false
	await _steps(p, 30)
	var tap_dmg: float = a.max_health - a.health
	a.health = a.max_health
	p.caster.cooldowns.reset()
	p.scripted_input[&"spell_1"] = true
	await _steps(p, 80)  # > 1,2 s: carga total
	p.scripted_input[&"spell_1"] = false
	await _steps(p, 30)
	var charged_dmg: float = a.max_health - a.health
	print("lança: toque %.1f, carregada %.1f" % [tap_dmg, charged_dmg])
	assert_float(tap_dmg).is_greater(10.0)
	assert_float(charged_dmg).is_greater(tap_dmg * 2.0)


func test_pulse_hits_and_pushes_all_nearby() -> void:
	var p: Player = _player()
	var es: Array[Enemy] = [_enemy("mist_crawler", Vector3(3, 0.05, 0)), _enemy("mist_crawler", Vector3(-3, 0.05, 1)),
		_enemy("mist_crawler", Vector3(0, 0.05, 3.5)), _enemy("mist_crawler", Vector3(0, 0.05, -20))]
	await _steps(p, 5)
	var before: Array[Vector3] = []
	for e: Enemy in es:
		before.append(e.global_position)
	p.scripted_input[&"spell_2"] = true
	await _steps(p, 2)
	p.scripted_input[&"spell_2"] = false
	await _steps(p, 15)
	for i: int in 3:
		assert_float(es[i].health).is_less(es[i].max_health)
		assert_float(es[i].global_position.distance_to(Vector3.ZERO)).is_greater(before[i].distance_to(Vector3.ZERO))
	assert_float(es[3].health).is_equal(es[3].max_health)


func test_chain_lightning_jumps_between_enemies() -> void:
	var p: Player = _player()
	var es: Array[Enemy] = [_enemy("mist_crawler", Vector3(0, 0.05, -6)), _enemy("mist_crawler", Vector3(4, 0.05, -9)),
		_enemy("mist_crawler", Vector3(8, 0.05, -11))]
	for e: Enemy in es:
		e.set_physics_process(false)
	await _steps(p, 5)
	p.scripted_input[&"spell_3"] = true
	await _steps(p, 2)
	p.scripted_input[&"spell_3"] = false
	await _steps(p, 5)
	for e: Enemy in es:
		assert_float(e.health).is_less(e.max_health)


func test_barrier_absorbs_damage() -> void:
	var p: Player = _player()
	await _steps(p, 5)
	p.scripted_input[&"spell_4"] = true
	await _steps(p, 2)
	p.scripted_input[&"spell_4"] = false
	await _steps(p, 2)
	assert_float(p.barrier_hp).is_greater(0.0)
	var hit: DamageInfo = DamageInfo.make(30.0, DamageInfo.Element.PHYSICAL, null)
	p.take_damage(hit)
	assert_float(p.stats.health).is_equal(p.stats.max_health)


func test_frost_freezes_enemy() -> void:
	var p: Player = _player()
	var e: Enemy = _enemy("mist_crawler", Vector3(0, 0.05, -6))
	p.caster.unlock(&"frost_shackles")
	p.caster.equip(0, &"frost_shackles")
	await _steps(p, 5)
	p.scripted_input[&"spell_1"] = true
	await _steps(p, 2)
	p.scripted_input[&"spell_1"] = false
	await _steps(p, 3)
	assert_bool(e.status.has(StatusEffects.Kind.FROZEN)).is_true()
	assert_float(e.status.speed_multiplier()).is_equal(0.0)


func test_enemy_telegraphs_then_hits_player() -> void:
	var p: Player = _player()
	var e: Enemy = _enemy("mist_crawler", Vector3(0, 0.05, -10))
	e.rotation.y = 0.0  # olhando para +Z? (-Z é a frente do modelo): vira para o jogador
	e.look_at(Vector3(0, 0.05, 0), Vector3.UP)
	var states: Dictionary = {}
	e.state_changed.connect(func(_o: int, s: int) -> void: states[s] = true)
	var hp: float = p.stats.health
	await _steps(p, 360)
	assert_bool(states.has(Enemy.State.CHASE)).override_failure_message("não perseguiu").is_true()
	assert_bool(states.has(Enemy.State.ATTACK_WINDUP)).override_failure_message("não telegrafou").is_true()
	assert_float(p.stats.health).override_failure_message("não acertou").is_less(hp)


func test_perfect_dodge_avoids_damage() -> void:
	var p: Player = _player()
	_perfect_fired = false
	Events.perfect_dodge.connect(_on_perfect_dodge)
	await _steps(p, 12)  # no chão (no ar, a esquiva vira blink)
	assert_int(p.state).is_equal(Player.State.GROUND)
	p.scripted_input[&"dodge"] = true
	await _steps(p, 2)
	p.scripted_input[&"dodge"] = false
	var hit: DamageInfo = DamageInfo.make(25.0, DamageInfo.Element.PHYSICAL, null)
	assert_bool(p.take_damage(hit)).is_false()
	Events.perfect_dodge.disconnect(_on_perfect_dodge)
	assert_bool(_perfect_fired).is_true()
	assert_float(p.stats.health).is_equal(p.stats.max_health)
	HitStop.reset()


func _on_perfect_dodge() -> void:
	_perfect_fired = true


func test_max_two_simultaneous_attackers() -> void:
	var p: Player = _player()
	var es: Array[Enemy] = []
	for i: int in 5:
		var a: float = TAU * i / 5.0
		var e: Enemy = _enemy("mist_crawler", Vector3(cos(a) * 3.0, 0.05, sin(a) * 3.0))
		e.look_at(Vector3(0, 0.05, 0), Vector3.UP)
		es.append(e)
	p.stats.max_health = 100000.0
	p.stats.set_health(100000.0)
	var worst: int = 0
	for f: int in 480:
		await p.stepped
		var n: int = 0
		for e: Enemy in es:
			if e.state == Enemy.State.ATTACK_WINDUP or e.state == Enemy.State.ATTACK_RECOVER:
				n += 1
		worst = maxi(worst, n)
	print("máximo de atacantes simultâneos: %d" % worst)
	assert_int(worst).is_between(1, CombatDirector.MAX_ATTACKERS)


func test_200_casts_do_not_leak() -> void:
	var p: Player = _player()
	p.stats.max_mana = 1.0e9
	p.stats.set_mana(1.0e9)
	var e: Enemy = _enemy("mist_crawler", Vector3(0, 0.05, -10))
	e.set_physics_process(false)
	e.max_health = 1.0e9
	e.health = 1.0e9
	await _steps(p, 5)
	# Aquecimento: enche os pools e caches.
	for i: int in 20:
		p.caster.cooldowns.reset()
		p.caster.cast_spell(Spells.get_spell(&"arcane_lance"), 0.0)
		await _steps(p, 2)
	await _steps(p, 60)
	var objects_before: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	var resources_before: float = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var ids: Array[StringName] = [&"arcane_lance", &"umbral_pulse", &"ether_chain", &"violet_aegis"]
	for i: int in 200:
		p.caster.cooldowns.reset()
		p.caster.cast_spell(Spells.get_spell(ids[i % 4]), float(i % 3) * 0.5)
		await _steps(p, 2)
	await _steps(p, 90)
	var objects_after: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	var resources_after: float = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	print("vazamento: objetos %d -> %d, recursos %d -> %d" % [objects_before, objects_after, resources_before, resources_after])
	# Tolerância: até 20 objetos/recursos (formas de consulta transitórias, timers).
	assert_float(objects_after - objects_before).is_less_equal(20.0)
	assert_float(resources_after - resources_before).is_less_equal(20.0)
