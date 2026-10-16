extends GdUnitTestSuite
## M9: toda tela de menu abre com foco e todo controle focável é alcançável
## pelas setas (navegação de gamepad/teclado); abas trocam por ui_tab_*; ações
## básicas (usar poção, equipar, gastar ponto, comprar) funcionam pela UI;
## cajados mudam o ataque básico; LB + face vira feitiço.

var _root: Node
var _player: Player


func before_test() -> void:
	GameState.reset()
	Inventory.reset()
	HitStop.reset()
	_root = Node3D.new()
	add_child(_root)
	_root.add_child(Vfx.new())
	_root.add_child(ProjectilePool.new())
	_player = Player.new()
	_player.with_camera = false
	_player.use_scripted_input = true
	_root.add_child(_player)
	_player.teleport(Vector3(0, 500, 0))


func after_test() -> void:
	get_tree().paused = false
	for a: StringName in [&"spell_modifier", &"pad_spell_2", &"jump"]:
		Input.action_release(a)
	_root.queue_free()
	GameState.reset()
	Inventory.reset()
	await get_tree().process_frame


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


## Busca em largura pelos vizinhos de foco nas 4 direções (o que o D-pad faz).
func _reachable(start: Control) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[Control] = [start]
	while not queue.is_empty():
		var c: Control = queue.pop_front()
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var n: Control = c.find_valid_focus_neighbor(side)
			if n != null and not seen.has(n):
				seen[n] = true
				queue.append(n)
		var nx: Control = c.find_next_valid_focus()
		if nx != null and not seen.has(nx):
			# Tab (próximo) também conta: é como o teclado navega.
			seen[nx] = true
			queue.append(nx)
	return seen


func _assert_navigable(screen: Control, label: String) -> void:
	await _frames(3)
	var focused: Control = screen.get_viewport().gui_get_focus_owner()
	assert_object(focused).override_failure_message("%s: nada com foco ao abrir" % label).is_not_null()
	if focused == null:
		return
	var all: Array[Control] = MenuKit.focusables(screen)
	var seen: Dictionary = _reachable(focused)
	print("%s: %d focáveis, %d alcançados a partir de %s" % [label, all.size(), seen.size(), focused.name])
	assert_int(all.size()).override_failure_message("%s: nenhum controle focável" % label).is_greater(0)
	var missing: Array[String] = []
	for c: Control in all:
		if not seen.has(c) and not (c is BaseButton and (c as BaseButton).disabled):
			missing.append(str(c.name))
	assert_array(missing).override_failure_message("%s: inalcançáveis pelas setas: %s" % [label, missing]).is_empty()
	# As setas mudam mesmo o foco (simula o D-pad/teclado).
	if all.size() > 1:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = &"ui_down"
		ev.pressed = true
		Input.parse_input_event(ev)
		await _frames(2)
		var ev2: InputEventAction = InputEventAction.new()
		ev2.action = &"ui_down"
		ev2.pressed = false
		Input.parse_input_event(ev2)


func test_options_all_tabs_navigable() -> void:
	var o: OptionsMenu = OptionsMenu.new()
	add_child(o)
	for t: int in o.tabs.size():
		o.set_tab(t)
		await _assert_navigable(o, "Opções/aba %d" % t)
	o.queue_free()
	await _frames(1)


func test_game_menu_all_tabs_navigable() -> void:
	GameState.add_xp(500)
	var m: GameMenu = GameMenu.new()
	m.player = _player
	add_child(m)
	for t: int in m.tabs.size():
		m.set_tab(t)
		await _assert_navigable(m, "Grimório/aba %d" % t)
	# Tabs por ação.
	m.set_tab(0)
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_tab_next"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	assert_int(m.current).is_equal(1)
	m.queue_free()
	await _frames(1)


func test_shop_and_pause_and_slots_navigable() -> void:
	GameState.add_souls(1000)
	var s: ShopMenu = ShopMenu.new()
	s.player = _player
	add_child(s)
	for t: int in s.tabs.size():
		s.set_tab(t)
		await _assert_navigable(s, "Loja/aba %d" % t)
	s.queue_free()
	var p: ListPanel = ListPanel.new()
	p.title = "Pausa"
	for i: int in 5:
		p.add_button("B%d" % i, func() -> void: pass)
	add_child(p)
	await _assert_navigable(p, "Pausa")
	var picker: ListPanel = ListPanel.slot_picker(p, "save", func(_s: int) -> void: pass)
	await _assert_navigable(picker, "Slots")
	p.queue_free()
	await _frames(1)


func test_main_menu_navigable() -> void:
	var mm: MainMenu = MainMenu.new()
	add_child(mm)
	await _assert_navigable(mm, "Menu inicial")
	mm.queue_free()
	await _frames(1)


func test_ui_actions_use_equip_spend() -> void:
	var m: GameMenu = GameMenu.new()
	m.player = _player
	add_child(m)
	await _frames(2)
	_player.stats.damage(60.0)
	var hp: float = _player.stats.health
	var pot: int = -1
	for i: int in Inventory.SIZE:
		if Inventory.id_at(i) == "potion_health":
			pot = i
	(m.find_child("Slot_%d" % pot, true, false) as ItemSlot).pressed.emit()
	assert_float(_player.stats.health).is_greater(hp)
	assert_int(Inventory.count("potion_health")).is_equal(2)
	Inventory.add("robe_warden")
	m.refresh()
	await _frames(1)
	var robe: int = -1
	for i: int in Inventory.SIZE:
		if Inventory.id_at(i) == "robe_warden":
			robe = i
	(m.find_child("Slot_%d" % robe, true, false) as ItemSlot).pressed.emit()
	await _frames(1)
	assert_str(Inventory.equipped["robe"]).is_equal("robe_warden")
	assert_float(_player.stats.max_health).is_equal(125.0)
	GameState.add_xp(GameState.xp_to_next(1))
	m.set_tab(GameMenu.Tab.CHARACTER)
	await _frames(1)
	(m.find_child("Add_health", true, false) as Button).pressed.emit()
	await _frames(1)
	assert_int(GameState.attributes["health"]).is_equal(1)
	assert_float(_player.stats.max_health).is_equal(135.0)
	m.queue_free()
	await _frames(1)


func test_staff_changes_basic_attack() -> void:
	var pool: ProjectilePool = ProjectilePool.get_for(_player)
	await _frames(2)
	var before: int = _active(pool)
	_player.caster.basic_attack()
	assert_int(_active(pool) - before).is_equal(1)
	Inventory.add("staff_thorn")
	for i: int in Inventory.SIZE:
		if Inventory.id_at(i) == "staff_thorn":
			Inventory.equip_from(i)
	_player.caster._basic_cd = 0.0
	var b2: int = _active(pool)
	_player.caster.basic_attack()
	assert_int(_active(pool) - b2).is_equal(3)


func _active(pool: ProjectilePool) -> int:
	var n: int = 0
	for c: Node in pool.get_children():
		if c is Projectile and (c as Projectile).active:
			n += 1
	return n


func test_gamepad_modifier_turns_face_buttons_into_spells() -> void:
	_player.use_scripted_input = false
	_player.input_enabled = true
	Input.action_press(&"pad_spell_2")
	Input.action_press(&"jump")
	assert_bool(_player.pressed(&"spell_2")).is_false()
	assert_bool(_player.pressed(&"jump")).is_true()
	Input.action_press(&"spell_modifier")
	assert_bool(_player.pressed(&"spell_2")).is_true()
	assert_bool(_player.pressed(&"jump")).is_false()
