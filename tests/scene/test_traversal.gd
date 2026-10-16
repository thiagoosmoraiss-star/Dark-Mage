extends GdUnitTestSuite
## Travessia avançada (M5): percurso com input roteirizado que escala uma parede,
## plana sobre um vale e nada até um marcador. Também testa esquiva e afogamento.


func _box(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	b.position = pos
	parent.add_child(b)
	return b


## Percurso: chão (z 0..-10) -> parede de 8 m (z = -12) -> platô (z -12..-30, y 8)
## -> vale (y 0) -> lago (z -60..-100, superfície y 1) -> marcador em z = -85.
func _course() -> Node3D:
	var w: Node3D = Node3D.new()
	add_child(w)
	_box(w, Vector3(40, 2, 24), Vector3(0, -1, 0))           # chão inicial
	_box(w, Vector3(40, 8, 18), Vector3(0, 4, -21))          # platô alto (parede na face z = -12)
	_box(w, Vector3(40, 2, 120), Vector3(0, -3, -90))        # fundo do vale/lago (y -2)
	var lake: WaterBody = WaterBody.new()
	lake.size = Vector2(40, 60)
	lake.position = Vector3(0, 1.0, -85)
	w.add_child(lake)
	return w


func _player(w: Node3D) -> Player:
	var p: Player = Player.new()
	p.with_camera = false
	p.use_scripted_input = true
	w.add_child(p)
	p.global_position = Vector3(0, 0.05, -6)
	return p


func _steps(p: Player, n: int) -> void:
	for i: int in n:
		await p.stepped


func test_climb_glide_swim_course() -> void:
	var w: Node3D = _course()
	var p: Player = _player(w)
	var seen: Dictionary = {}
	p.state_changed.connect(func(_o: int, s: int) -> void: seen[s] = true)
	# 1) Anda até a parede e escala.
	p.scripted_input[&"move_forward"] = true
	var t: int = 0
	while p.global_position.y < 8.0 and t < 600:
		await p.stepped
		t += 1
	assert_bool(seen.has(Player.State.CLIMB)).override_failure_message("não escalou").is_true()
	# 2) Sobe por cima da borda e anda até a beirada do platô.
	t = 0
	while p.global_position.z > -29.5 and t < 400:
		await p.stepped
		t += 1
	assert_float(p.global_position.y).is_greater(7.5)
	# 3) Pula da beirada e abre o planador.
	p.scripted_input[&"jump"] = true
	await _steps(p, 2)
	p.scripted_input[&"jump"] = false
	await _steps(p, 20)
	p.scripted_input[&"jump"] = true
	await _steps(p, 2)
	p.scripted_input[&"jump"] = false
	assert_int(p.state).is_equal(Player.State.GLIDE)
	# 4) Plana até o lago e nada até o marcador.
	t = 0
	while p.global_position.z > -85.0 and t < 1500:
		await p.stepped
		t += 1
	assert_bool(seen.has(Player.State.GLIDE)).is_true()
	assert_bool(seen.has(Player.State.SWIM)).override_failure_message("não nadou").is_true()
	assert_float(p.global_position.z).is_less_equal(-85.0)
	print("percurso: chegou ao marcador em z=%.1f; estados vistos %s; stamina %.0f" % [p.global_position.z, seen.keys(), p.stats.stamina])
	w.queue_free()


func test_dodge_gives_iframes_and_costs_stamina() -> void:
	var w: Node3D = _course()
	var p: Player = _player(w)
	await _steps(p, 5)
	p.scripted_input[&"dodge"] = true
	await _steps(p, 2)
	p.scripted_input[&"dodge"] = false
	assert_bool(p.has_iframes()).is_true()
	assert_float(p.stats.stamina).is_less(100.0)
	var hp: float = p.stats.health
	var hit: DamageInfo = DamageInfo.make(20.0, DamageInfo.Element.PHYSICAL, null)
	assert_bool(p.take_damage(hit)).is_false()
	assert_float(p.stats.health).is_equal(hp)
	await _steps(p, 40)
	assert_bool(p.has_iframes()).is_false()
	w.queue_free()


func test_exhausted_swimmer_respawns_on_shore() -> void:
	var w: Node3D = _course()
	var p: Player = _player(w)
	await _steps(p, 40)  # registra posição segura no chão
	var safe: Vector3 = p.last_safe_position
	p.teleport(Vector3(0, 0.0, -85))
	await _steps(p, 10)
	assert_int(p.state).is_equal(Player.State.SWIM)
	p.stats.use_stamina(1000.0)
	var respawned: Array[bool] = [false]
	p.respawned.connect(func() -> void: respawned[0] = true)
	await _steps(p, 150)
	assert_bool(respawned[0]).is_true()
	assert_float(p.global_position.distance_to(safe)).is_less(1.5)
	assert_float(p.stats.health).is_less(100.0)
	w.queue_free()


func test_fog_of_war_reveal_and_save() -> void:
	var f: FogOfWar = FogOfWar.new()
	assert_bool(f.is_revealed(Vector3(0, 0, 0))).is_false()
	f.reveal(Vector3(0, 0, 0), 80.0)
	assert_bool(f.is_revealed(Vector3(10, 0, 10))).is_true()
	assert_bool(f.is_revealed(Vector3(500, 0, 500))).is_false()
	var g: FogOfWar = FogOfWar.new()
	assert_bool(g.from_save(f.to_save())).is_true()
	assert_bool(g.is_revealed(Vector3(10, 0, 10))).is_true()
	assert_bool(g.from_save("lixo")).is_false()
