extends GdUnitTestSuite
## M8: santuários (4 arquétipos), Guardiões (2 fases + mecânica) e chefe final
## (3 fases), com god mode no jogador. Confirma morte do chefe, purificação e
## feitiço concedido.

var _root: Node3D
var _player: Player


func before_test() -> void:
	GameState.reset()
	HitStop.reset()
	_root = Node3D.new()
	add_child(_root)
	_root.add_child(Vfx.new())
	_root.add_child(ProjectilePool.new())
	_root.add_child(CombatDirector.new())


func after_test() -> void:
	HitStop.reset()
	GameState.reset()
	_root.queue_free()
	await get_tree().process_frame


func _spawn_player(at: Vector3) -> Player:
	_player = Player.new()
	_player.with_camera = false
	_player.use_scripted_input = true
	_player.god_mode = true
	_root.add_child(_player)
	_player.teleport(at)
	return _player


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


# --- Santuários --------------------------------------------------------------------

func test_brazier_shrine_solved_by_arcane_lance() -> void:
	var s: Shrine = Shrine.build(_root, Vector3(0, 400, 0), "shrine_test_a", &"valley", Shrine.Archetype.BRAZIERS)
	var p: Player = _spawn_player(s.spawn_point().origin)
	var done: Array[bool] = [false]
	s.completed.connect(func(_id: String) -> void: done[0] = true)
	await _frames(3)
	# Lança errada (pulso) não acende; a Lança Arcana acende.
	for b: Node3D in s._targets:
		Events.spell_hit_world.emit(&"umbral_pulse", 0, b.global_position, b)
	assert_bool(done[0]).is_false()
	for b: Node3D in s._targets:
		Events.spell_hit_world.emit(&"arcane_lance", 0, b.global_position + Vector3.UP, b)
	assert_bool(done[0]).is_true()
	var hp_before: float = p.stats.max_health
	s.claim_reward(p)
	assert_bool(GameState.has_flag("shrine_done:shrine_test_a")).is_true()
	assert_float(p.stats.max_health + p.stats.max_mana).is_equal(hp_before + 100.0 + 10.0)


func test_rune_shrine_needs_chain_then_shot() -> void:
	var s: Shrine = Shrine.build(_root, Vector3(300, 400, 0), "shrine_test_r", &"coast", Shrine.Archetype.RUNES)
	_spawn_player(s.spawn_point().origin)
	var done: Array[bool] = [false]
	s.completed.connect(func(_id: String) -> void: done[0] = true)
	await _frames(3)
	for b: Node3D in s._targets:
		Events.spell_hit_world.emit(&"arcane_lance", 0, b.global_position, b)  # ainda ocultas
	assert_bool(done[0]).is_false()
	for b: Node3D in s._targets:
		Events.spell_hit_world.emit(&"ether_chain", 3, b.global_position + Vector3(2, 0, 0), null)
	for b: Node3D in s._targets:
		Events.spell_hit_world.emit(&"basic", 0, b.global_position, b)
	assert_bool(done[0]).is_true()


func test_chasm_fall_returns_to_start() -> void:
	var s: Shrine = Shrine.build(_root, Vector3(600, 400, 0), "shrine_test_c", &"forest", Shrine.Archetype.CHASM)
	var p: Player = _spawn_player(s.spawn_point().origin)
	await _frames(5)
	p.teleport(s.global_position + Vector3(12, -4, 16))  # no meio do abismo
	var ok: bool = false
	for i: int in 180:
		await get_tree().physics_frame
		if p.global_position.distance_to(s.spawn_point().origin) < 1.5:
			ok = true
			break
	assert_bool(ok).is_true()


func test_trial_shrine_completes_after_two_waves() -> void:
	var s: Shrine = Shrine.build(_root, Vector3(900, 400, 0), "shrine_test_t", &"valley", Shrine.Archetype.TRIAL)
	var p: Player = _spawn_player(s.spawn_point().origin)
	var done: Array[bool] = [false]
	s.completed.connect(func(_id: String) -> void: done[0] = true)
	s.on_enter(p)
	var panels: Node = get_tree().get_first_node_in_group(&"world_panels")
	assert_object(panels).is_null()
	for wave: int in 2:
		await _frames(3)
		for e: Enemy in s._wave_enemies.duplicate():
			if e.is_alive():
				e.take_damage(DamageInfo.make(9999.0, DamageInfo.Element.ARCANE, p))
		await _frames(3)
	assert_bool(done[0]).is_true()


# --- Chefes --------------------------------------------------------------------------

func _fight(lair: Lair, p: Player) -> Dictionary:
	var b: Boss = lair.boss
	var phases: Dictionary = {0: true}
	b.phase_changed.connect(func(ph: int) -> void: phases[ph] = true)
	var broke: Array[int] = [0]
	var guards: Array[int] = [0]
	var t: int = 0
	while b.is_alive() and t < 6000:
		await get_tree().physics_frame
		t += 1
		if b.guarded:
			guards[0] += 1
			# Usa o feitiço certo para quebrar a mecânica.
			var needed: StringName = b.breaker_for(b.current_mechanic())
			if needed == &"frost_shackles":
				b.apply_status(StatusEffects.Kind.FROZEN, 3.0, 1.0)
			else:
				var info: DamageInfo = DamageInfo.make(30.0, DamageInfo.Element.ARCANE, p, needed)
				info.stagger = 1.0
				info.hit_position = b.global_position + Vector3.UP
				b.take_damage(info)
			if not b.guarded:
				broke[0] += 1
		elif t % 12 == 0:
			var hit: DamageInfo = DamageInfo.make(20.0, DamageInfo.Element.ARCANE, p, &"basic")
			hit.hit_position = b.global_position + Vector3.UP
			b.take_damage(hit)
	return {"phases": phases, "broke": broke[0], "frames": t, "alive": b.is_alive()}


func _test_guardian(region: StringName, expected_reward: StringName) -> void:
	var lair: Lair = Lair.build(_root, Vector3(0, 400, 600), "lair_" + String(region), region)
	var p: Player = _spawn_player(lair._arena_center + Vector3(0, 0.5, 8))
	await _frames(30)
	assert_object(lair.boss).is_not_null()
	var r: Dictionary = await _fight(lair, p)
	print("%s: fases %s, mecânica quebrada %d vezes, %d frames" % [region, (r["phases"] as Dictionary).keys(), r["broke"], r["frames"]])
	assert_bool(r["alive"] as bool).override_failure_message("o chefe não morreu").is_false()
	assert_int(r["broke"] as int).override_failure_message("a mecânica nunca foi quebrada").is_greater_equal(1)
	assert_int((r["phases"] as Dictionary).size()).is_equal(lair.boss.boss.phase_thresholds.size() + 1)
	assert_bool(GameState.has_flag("guardian:" + String(region))).is_true()
	assert_float(GameState.corruption(region)).is_equal(0.0)
	assert_bool(p.caster.unlocked.has(expected_reward)).is_true()


func test_guardian_forest() -> void:
	await _test_guardian(&"forest", &"umbral_step")


func test_guardian_peaks() -> void:
	await _test_guardian(&"peaks", &"frost_shackles")


func test_guardian_burnt() -> void:
	await _test_guardian(&"burnt", &"astral_fall")


func test_guardian_swamp() -> void:
	await _test_guardian(&"swamp", &"beacon_wrath")


func test_final_boss_three_phases() -> void:
	var data: BossData = load("res://data/bosses/fear.tres") as BossData
	var ground: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(120, 2, 120)
	cs.shape = box
	cs.position.y = -1.0
	ground.add_child(cs)
	_root.add_child(ground)
	var b: Boss = Boss.new()
	b.boss = data
	_root.add_child(b)
	b.global_position = Vector3(0, 0.2, -6)
	b.arena_center = Vector3.ZERO
	b.arena_radius = 22.0
	var p: Player = _spawn_player(Vector3(0, 0.3, 6))
	var phases: Dictionary = {0: true}
	var mechanics: Dictionary = {}
	b.phase_changed.connect(func(ph: int) -> void: phases[ph] = true)
	var t: int = 0
	while b.is_alive() and t < 20000:
		await get_tree().physics_frame
		t += 1
		if b.guarded:
			var mech: BossData.Mechanic = b.current_mechanic()
			mechanics[mech] = true
			var info: DamageInfo = DamageInfo.make(30.0, DamageInfo.Element.ARCANE, p, b.breaker_for(mech))
			info.stagger = 1.0
			b.take_damage(info)
		elif t % 12 == 0:
			b.take_damage(DamageInfo.make(22.0, DamageInfo.Element.ARCANE, p, &"basic"))
	print("chefe final: fases %s, mecânicas %s, %d frames" % [phases.keys(), mechanics.keys(), t])
	assert_bool(b.is_alive()).is_false()
	assert_int(phases.size()).is_equal(3)
	assert_int(mechanics.size()).is_equal(3)
