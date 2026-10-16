class_name TabbedScreen
extends Control
## Tela de abas em tela cheia (opções, inventário/personagem/feitiços/diário).
## Q/E ou LB/RB trocam de aba; Esc/B fecham. Cada aba é montada sob demanda por
## um Callable que devolve o Control do conteúdo.

signal closed

var title: String = ""
## [[texto, Callable que devolve Control], ...]
var tabs: Array[Array] = []
var current: int = 0
var hint: String = ""

var _tab_bar: HBoxContainer
var _content: MarginContainer
var _panel: PanelContainer
var _hint_label: Label


func _ready() -> void:
	theme = UiStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuKit.backdrop(self, 0.72)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 70
	_panel.offset_right = -70
	_panel.offset_top = 50
	_panel.offset_bottom = -50
	add_child(_panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 12)
	_panel.add_child(v)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 24)
	v.add_child(head)
	head.add_child(UiStyle.title_label(title, 34))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override(&"separation", 6)
	head.add_child(_tab_bar)
	for i: int in tabs.size():
		var idx: int = i
		var b: Button = Button.new()
		b.text = str(tabs[i][0])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE  # abas trocam por Q/E ou LB/RB, ou clique
		b.custom_minimum_size = Vector2(150, 42)
		b.pressed.connect(func() -> void:
			Audio.play(&"ui_click")
			set_tab(idx))
		_tab_bar.add_child(b)
	v.add_child(MenuKit.separator())
	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_content)
	_hint_label = Label.new()
	_hint_label.add_theme_color_override(&"font_color", UiStyle.TEXT_DIM)
	_hint_label.add_theme_font_size_override(&"font_size", 17)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint_label)
	MenuKit.apply_ui_scale(self)
	set_tab(current)


func set_tab(i: int) -> void:
	current = wrapi(i, 0, tabs.size())
	for k: int in _tab_bar.get_child_count():
		(_tab_bar.get_child(k) as Button).button_pressed = k == current
	refresh()


## Remonta a aba atual (depois de equipar, comprar, etc.), tentando manter o foco.
func refresh() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_path: String = str(_content.get_path_to(focused)) if focused != null and _content.is_ancestor_of(focused) else ""
	for c: Node in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	var builder: Callable = tabs[current][1]
	var page: Control = builder.call() as Control
	_content.add_child(page)
	_hint_label.text = hint + "    " + tr("UI_HINT_TABS")
	_restore_focus.call_deferred(focus_path)


func _restore_focus(path: String) -> void:
	if path != "" and _content.has_node(path):
		var c: Control = _content.get_node(path) as Control
		if c != null and c.is_visible_in_tree() and c.focus_mode == Control.FOCUS_ALL:
			c.grab_focus()
			return
	MenuKit.focus_first(_content)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_tab_next"):
		Audio.play(&"ui_select")
		set_tab(current + 1)
	elif event.is_action_pressed(&"ui_tab_prev"):
		Audio.play(&"ui_select")
		set_tab(current - 1)
	elif event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		Audio.play(&"ui_back")
		closed.emit()
	else:
		return
	get_viewport().set_input_as_handled()
