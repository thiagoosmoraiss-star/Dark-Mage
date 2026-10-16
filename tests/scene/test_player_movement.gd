extends GdUnitTestSuite
## Controlador do jogador com input simulado (roteiro M3): determinismo,
## não atravessa o chão, pulo e aterrissagem.


func _make_world() -> Node3D:
	var world: Node3D = Node3D.new()
	var ground: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200, 2, 200)
	shape.shape = box
	shape.position.y = -1.0
	ground.add_child(shape)
	world.add_child(ground)
	# Rampa de 25° à frente.
	var ramp: StaticBody3D = StaticBody3D.new()
	var rs: CollisionShape3D = CollisionShape3D.new()
	var rb: BoxShape3D = BoxShape3D.new()
	rb.size = Vector3(6, 1, 20)
	rs.shape = rb
	ramp.add_child(rs)
	ramp.position = Vector3(10, 1.5, -15)
	ramp.rotation.x = deg_to_rad(25.0)
	world.add_child(ramp)
	add_child(world)
	return world


## Cria o jogador com input roteirizado e roda exatamente `frames` passos dele.
func _run(frames: int, actions: Array[StringName]) -> Player:
	var world: Node3D = _make_world()
	var p: Player = Player.new()
	p.with_camera = false
	p.use_scripted_input = true
	for a: StringName in actions:
		p.scripted_input[a] = true
	world.add_child(p)
	p.global_position = Vector3(0, 0.1, 0)
	while p.physics_frames < frames:
		await p.stepped
	p.set_physics_process(false)
	return p


func test_walk_forward_is_deterministic() -> void:
	var p1: Player = await _run(120, [&"move_forward"])
	var pos1: Vector3 = p1.global_position
	p1.get_parent().queue_free()
	await get_tree().physics_frame
	var p2: Player = await _run(120, [&"move_forward"])
	var pos2: Vector3 = p2.global_position
	p2.get_parent().queue_free()
	print("posição após 2 s andando: %s / %s" % [pos1, pos2])
	assert_float(pos1.distance_to(pos2)).is_less(0.001)
	# ~2 s a 5,6 m/s menos a aceleração; para -Z.
	assert_float(pos1.z).is_between(-11.5, -9.0)
	assert_float(absf(pos1.x)).is_less(0.01)
	assert_float(pos1.y).is_between(-0.05, 0.1)


func test_does_not_fall_through_ground() -> void:
	var p: Player = await _run(240, [])
	assert_float(p.global_position.y).is_between(-0.05, 0.15)
	assert_int(p.state).is_equal(Player.State.GROUND)
	p.get_parent().queue_free()


func test_jump_and_land() -> void:
	var world: Node3D = _make_world()
	var p: Player = Player.new()
	p.with_camera = false
	world.add_child(p)
	p.use_scripted_input = true
	while p.physics_frames < 10:
		await p.stepped
	p.scripted_input[&"jump"] = true
	await p.stepped
	p.scripted_input[&"jump"] = false
	var max_y: float = 0.0
	var landed: Array[bool] = [false]
	p.landed.connect(func(_s: float) -> void: landed[0] = true)
	for i: int in 90:
		await p.stepped
		max_y = maxf(max_y, p.global_position.y)
	assert_float(max_y).is_between(0.8, 1.4)  # v²/2g = 6.8²/44 ≈ 1.05 m
	assert_bool(landed[0]).is_true()
	assert_int(p.state).is_equal(Player.State.GROUND)
	world.queue_free()


func test_sprint_uses_stamina() -> void:
	var p: Player = await _run(60, [&"move_forward", &"sprint"])
	assert_float(p.stats.stamina).is_less(90.0)
	assert_float(p.ground_speed).is_greater(7.0)
	p.get_parent().queue_free()
