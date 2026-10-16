class_name GameUi
extends CanvasLayer
## Camada de menus durante o jogo: pausa (Esc/Start), menu de jogo (I/Back e
## L/D-pad ←), opções, loja e atalhos de poção. Pausa a árvore enquanto há um
## menu aberto e devolve o mouse preso ao fechar.

var world: IslandWorld
var _stack: Array[Control] = []


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_ui")


func is_open() -> bool:
	return not _stack.is_empty()


func _blocked() -> bool:
	if world == null or world.player == null:
		return true
	if world.map_screen != null and world.map_screen.is_open():
		return true
	if world.panels != null and world.panels.is_open():
		return true
	return world.interiors != null and world.interiors.is_busy()


func _unhandled_input(event: InputEvent) -> void:
	if is_open():
		return
	if _blocked():
		return
	if event.is_action_pressed(&"pause"):
		open_pause()
	elif event.is_action_pressed(&"inventory"):
		open_game_menu(GameMenu.Tab.INVENTORY)
	elif event.is_action_pressed(&"journal"):
		open_game_menu(GameMenu.Tab.JOURNAL)
	elif event.is_action_pressed(&"quick_potion"):
		_quick("potion_health")
	elif event.is_action_pressed(&"quick_mana"):
		_quick("potion_mana")
	else:
		return
	get_viewport().set_input_as_handled()


func _quick(id: String) -> void:
	if world.player.state == Player.State.DEAD or not Inventory.quick_use(id, world.player):
		Audio.play(&"ui_error")


func _push(c: Control) -> void:
	if _stack.is_empty():
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Audio.play(&"ui_open")
	if not _stack.is_empty():
		_stack.back().visible = false
	_stack.append(c)
	add_child(c)


func _pop() -> void:
	if _stack.is_empty():
		return
	var top: Control = _stack.pop_back()
	top.queue_free()
	if _stack.is_empty():
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Audio.play(&"ui_close")
		if world != null and world.player != null:
			world.player.apply_progression()
	else:
		var under: Control = _stack.back()
		under.visible = true
		MenuKit.focus_first.call_deferred(under)


func close_all() -> void:
	while not _stack.is_empty():
		_pop()


func open_pause() -> void:
	var p: ListPanel = ListPanel.new()
	p.name = "PauseMenu"
	p.title = tr("PAUSE_TITLE")
	p.subtitle = tr("PAUSE_SUB") % [GameState.level, MenuKit.format_time(GameState.play_time_s)]
	p.add_button(tr("PAUSE_RESUME"), _pop)
	p.add_button(tr("TAB_INVENTORY"), func() -> void: open_game_menu(GameMenu.Tab.INVENTORY))
	p.add_button(tr("TAB_JOURNAL"), func() -> void: open_game_menu(GameMenu.Tab.JOURNAL))
	p.add_button(tr("PAUSE_MAP"), func() -> void:
		close_all()
		if world.map_screen != null:
			world.map_screen.toggle())
	p.add_button(tr("PAUSE_SAVE"), func() -> void:
		ListPanel.slot_picker(p, "save", func(slot: int) -> void:
			Game.current_slot = slot
			var err: Error = world.save_game(slot)
			Audio.play(&"ui_confirm" if err == OK else &"ui_error")
			MenuKit.focus_first(p)), not world.player.stats.in_combat)
	p.add_button(tr("PAUSE_LOAD"), func() -> void:
		ListPanel.slot_picker(p, "load", func(slot: int) -> void:
			get_tree().paused = false
			Game.continue_game(slot)))
	p.add_button(tr("UI_OPTIONS"), open_options)
	p.add_button(tr("PAUSE_MAIN_MENU"), func() -> void:
		ListPanel.confirm(p, tr("PAUSE_CONFIRM_MENU"), func() -> void: Game.goto_main_menu()))
	p.add_button(tr("UI_QUIT"), func() -> void:
		ListPanel.confirm(p, tr("PAUSE_CONFIRM_QUIT"), func() -> void: get_tree().quit()))
	p.back.connect(_pop)
	_push(p)


func open_game_menu(tab: GameMenu.Tab) -> void:
	var m: GameMenu = GameMenu.new()
	m.name = "GameMenu"
	m.player = world.player
	m.current = tab
	m.closed.connect(_pop)
	_push(m)


func open_options() -> void:
	var o: OptionsMenu = OptionsMenu.new()
	o.name = "OptionsMenu"
	o.closed.connect(_pop)
	_push(o)


func open_shop() -> void:
	if is_open():
		return
	var s: ShopMenu = ShopMenu.new()
	s.name = "ShopMenu"
	s.player = world.player
	s.closed.connect(_pop)
	_push(s)
