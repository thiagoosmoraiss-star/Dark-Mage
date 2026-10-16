class_name WorldPanels
extends CanvasLayer
## Painéis do mundo: texto de lore (altares, diários) e menu da fogueira
## (descansar, viagem rápida). Pausam o jogo; navegáveis por mouse/teclado/gamepad.

signal rest_requested(bonfire_id: String, hours: float)
signal travel_requested(bonfire_id: String)

var _root: Control
var _panel: PanelContainer
var _box: VBoxContainer
var _open: bool = false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
	_root.visible = false
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	_root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(620, 0)
	_root.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 14)
	_panel.add_child(_box)


func is_open() -> bool:
	return _open


func _clear() -> void:
	for c: Node in _box.get_children():
		c.queue_free()


func _show() -> void:
	_open = true
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.play(&"ui_open")
	_center.call_deferred()


func _center() -> void:
	_panel.reset_size()
	_panel.position = (_root.size - _panel.size) * 0.5
	for c: Node in _box.get_children():
		if c is Button:
			(c as Button).grab_focus()
			break


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Audio.play(&"ui_close")


func _unhandled_input(event: InputEvent) -> void:
	if _open and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"interact")):
		close()
		get_viewport().set_input_as_handled()


func show_text(title: String, body: String) -> void:
	_clear()
	_box.add_child(UiStyle.title_label(title, 30))
	var sep: HSeparator = HSeparator.new()
	_box.add_child(sep)
	var b: Label = UiStyle.body_label(body, 21)
	b.custom_minimum_size = Vector2(580, 0)
	_box.add_child(b)
	_add_button(tr("UI_CLOSE"), close)
	_show()


func show_rest(bonfire_id: String, bonfire_name: String) -> void:
	_clear()
	_box.add_child(UiStyle.title_label(bonfire_name, 30))
	_box.add_child(UiStyle.body_label(tr("BONFIRE_RESTED"), 19))
	_add_button(tr("BONFIRE_WAIT_MORNING"), func() -> void:
		rest_requested.emit(bonfire_id, 6.0)
		close())
	_add_button(tr("BONFIRE_WAIT_NIGHT"), func() -> void:
		rest_requested.emit(bonfire_id, 20.0)
		close())
	var others: Array[String] = []
	for id: String in GameState.discovered_bonfires:
		if id != bonfire_id:
			others.append(id)
	if not others.is_empty():
		_box.add_child(UiStyle.title_label(tr("BONFIRE_TRAVEL"), 22))
		for id: String in others:
			var target: String = id
			_add_button(Bonfire.display_name(target), func() -> void:
				travel_requested.emit(target)
				close())
	_add_button(tr("UI_CLOSE"), close)
	_show()


func _add_button(text: String, cb: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		cb.call())
	btn.focus_entered.connect(func() -> void: Audio.play(&"ui_select"))
	_box.add_child(btn)
