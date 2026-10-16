class_name ListPanel
extends Control
## Painel central com título e uma coluna de botões (menu de pausa, escolha de
## slot, confirmação). Esc/B volta (sinal `back`).

signal back

var title: String = ""
var subtitle: String = ""
var width: float = 520.0
var _box: VBoxContainer
var _panel: PanelContainer


func _ready() -> void:
	theme = UiStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuKit.backdrop(self, 0.55)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 10)
	_panel.add_child(_box)
	if title != "":
		var t: Label = UiStyle.title_label(title, 32)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(t)
	if subtitle != "":
		var s: Label = UiStyle.body_label(subtitle, 19)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(s)
	if title != "" or subtitle != "":
		_box.add_child(MenuKit.separator())
	MenuKit.apply_ui_scale(self)
	_build()
	MenuKit.focus_first.call_deferred(_box)


## Sobrescrito pelas subclasses ou preenchido com add_button() antes do _ready.
func _build() -> void:
	for b: Array in _pending:
		_add(b[0] as String, b[1] as Callable, b[2] as bool)


var _pending: Array[Array] = []


func add_button(text: String, cb: Callable, enabled: bool = true) -> void:
	if _box == null:
		_pending.append([text, cb, enabled])
	else:
		_add(text, cb, enabled)


func _add(text: String, cb: Callable, enabled: bool) -> Button:
	var b: Button = MenuKit.button(text, cb)
	b.disabled = not enabled
	_box.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		Audio.play(&"ui_back")
		back.emit()
		get_viewport().set_input_as_handled()


static func confirm(parent: Node, question: String, on_yes: Callable) -> ListPanel:
	var p: ListPanel = ListPanel.new()
	p.title = question
	p.width = 460.0
	p.add_button(TranslationServer.translate("UI_YES"), func() -> void:
		p.queue_free()
		on_yes.call())
	p.add_button(TranslationServer.translate("UI_NO"), func() -> void:
		p.queue_free()
		MenuKit.focus_first(parent))
	p.back.connect(func() -> void:
		p.queue_free()
		MenuKit.focus_first(parent))
	parent.add_child(p)
	return p


## Escolha de slot de save. mode: "save", "load" ou "new".
static func slot_picker(parent: Node, mode: String, on_pick: Callable) -> ListPanel:
	var p: ListPanel = ListPanel.new()
	p.title = TranslationServer.translate("SLOTS_" + mode.to_upper())
	p.width = 620.0
	for s: int in SaveSystem.SLOT_COUNT:
		var info: Dictionary = SaveSystem.slot_info(s)
		var slot: int = s
		var text: String
		if info.is_empty():
			text = TranslationServer.translate("SLOT_EMPTY") % (s + 1)
		elif info.has("corrupt"):
			text = TranslationServer.translate("SLOT_CORRUPT") % (s + 1)
		else:
			var dt: Dictionary = Time.get_datetime_dict_from_unix_time(JsonUtil.get_i(info, "saved_at_unix") + _tz_offset())
			text = TranslationServer.translate("SLOT_INFO") % [s + 1, JsonUtil.get_i(info, "level", 1),
				MenuKit.format_time(JsonUtil.get_f(info, "play_time_s")),
				"%02d/%02d/%04d %02d:%02d" % [dt["day"], dt["month"], dt["year"], dt["hour"], dt["minute"]]]
		var enabled: bool = mode != "load" or (not info.is_empty() and not info.has("corrupt"))
		p.add_button(text, func() -> void:
			if mode != "load" and not info.is_empty():
				ListPanel.confirm(p, TranslationServer.translate("SLOT_OVERWRITE"), func() -> void:
					p.queue_free()
					on_pick.call(slot))
			else:
				p.queue_free()
				on_pick.call(slot), enabled)
	p.add_button(TranslationServer.translate("UI_BACK"), func() -> void:
		p.queue_free()
		MenuKit.focus_first(parent))
	p.back.connect(func() -> void:
		p.queue_free()
		MenuKit.focus_first(parent))
	parent.add_child(p)
	return p


static func _tz_offset() -> int:
	return JsonUtil.get_i(Time.get_time_zone_from_system(), "bias") * 60
