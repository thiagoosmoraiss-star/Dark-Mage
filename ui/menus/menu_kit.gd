class_name MenuKit
extends RefCounted
## Peças comuns dos menus: botões com som, linhas de opção, barras de abas e
## ícones. Tudo é Control com foco, para mouse, teclado e gamepad.

const ICON_DIR: String = "res://assets/ui/icons/"

static var _icons: Dictionary[String, Texture2D] = {}


static func icon(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		var path: String = ICON_DIR + icon_name + ".svg"
		_icons[icon_name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[icon_name]


static func button(text: String, cb: Callable, min_h: float = 46.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		if cb.is_valid():
			cb.call())
	b.focus_entered.connect(func() -> void: Audio.play(&"ui_select"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b


## Linha "rótulo .......... controle".
static func row(label: String, control: Control) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 18)
	var l: Label = Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(320, 0)
	h.add_child(l)
	control.custom_minimum_size = Vector2(maxf(control.custom_minimum_size.x, 300.0), 40)
	h.add_child(control)
	return h


static func slider(value: float, min_v: float, max_v: float, step: float, cb: Callable) -> HSlider:
	var s: HSlider = HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(v: float) -> void: cb.call(v))
	s.mouse_entered.connect(func() -> void: s.grab_focus())
	return s


static func toggle(on: bool, cb: Callable) -> CheckButton:
	var c: CheckButton = CheckButton.new()
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(v: bool) -> void:
		Audio.play(&"ui_click")
		cb.call(v))
	c.mouse_entered.connect(func() -> void: c.grab_focus())
	return c


## Lista de escolhas: [[valor, texto], ...].
static func choice(options: Array, current: Variant, cb: Callable) -> OptionButton:
	var o: OptionButton = OptionButton.new()
	o.focus_mode = Control.FOCUS_ALL
	for i: int in options.size():
		var opt: Array = options[i]
		o.add_item(str(opt[1]), i)
		if opt[0] == current:
			o.select(i)
	o.item_selected.connect(func(i: int) -> void:
		Audio.play(&"ui_click")
		cb.call((options[i] as Array)[0]))
	o.mouse_entered.connect(func() -> void: o.grab_focus())
	return o


static func separator() -> HSeparator:
	var s: HSeparator = HSeparator.new()
	s.add_theme_constant_override(&"separation", 10)
	return s


## Painel centralizado e escurecimento atrás.
static func backdrop(parent: Control, alpha: float = 0.6) -> ColorRect:
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, alpha)
	parent.add_child(dim)
	return dim


## Primeiro Control focável (em profundidade) dentro de `root`.
static func first_focusable(root: Node) -> Control:
	for c: Node in root.get_children():
		var ctl: Control = c as Control
		var vis: bool = ctl.is_visible_in_tree() if ctl != null and ctl.is_inside_tree() else (ctl != null and ctl.visible)
		if ctl != null and vis and ctl.focus_mode == Control.FOCUS_ALL and not (ctl is BaseButton and (ctl as BaseButton).disabled):
			return ctl
		var deeper: Control = first_focusable(c)
		if deeper != null:
			return deeper
	return null


static func focus_first(root: Node) -> void:
	var c: Control = first_focusable(root)
	if c != null:
		c.grab_focus()


## Todos os Controls focáveis e visíveis (usado nos testes de navegação).
static func focusables(root: Node, out: Array[Control] = []) -> Array[Control]:
	for c: Node in root.get_children():
		var ctl: Control = c as Control
		if ctl != null and ctl.is_visible_in_tree() and ctl.focus_mode == Control.FOCUS_ALL:
			out.append(ctl)
		focusables(c, out)
	return out


## Aplica a escala de UI (acessibilidade) a um Control de tela cheia.
static func apply_ui_scale(root: Control) -> void:
	var k: float = clampf(JsonUtil.num(Settings.get_value("accessibility", "ui_scale"), 1.0), 0.75, 1.5)
	var vs: Vector2 = root.get_viewport_rect().size
	# Âncoras no canto: com escala, o tamanho é definido à mão (vs / k).
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.scale = Vector2(k, k)
	root.position = Vector2.ZERO
	root.size = vs / k


static func format_time(seconds: float) -> String:
	var s: int = roundi(seconds)
	return "%d:%02d" % [s / 3600, (s / 60) % 60]
