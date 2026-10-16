class_name CreditsRoll
extends CanvasLayer
## Créditos rolando ao fim do jogo (CREDITS.md), com o título e "obrigado por jogar".
## Qualquer tecla de confirmar/voltar acelera; termina sozinho e emite `finished`.

signal finished

const SPEED: float = 42.0

var _scroll: Control
var _label: Label
var _y: float = 0.0
var _fast: bool = false


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiStyle.theme()
	add_child(root)
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.015, 0.03, 0.92)
	root.add_child(bg)
	_scroll = Control.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.clip_contents = true
	root.add_child(_scroll)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 18)
	v.custom_minimum_size = Vector2(900, 0)
	_scroll.add_child(v)
	var t: Label = UiStyle.title_label("DARK MAGE", 64)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub: Label = UiStyle.title_label(tr("MENU_SUBTITLE"), 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var text: String = FileAccess.get_file_as_string("res://CREDITS.md") if FileAccess.file_exists("res://CREDITS.md") else ""
	_label = UiStyle.body_label(text.replace("#", "").replace("**", "").replace("`", ""), 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(900, 0)
	v.add_child(_label)
	var thanks: Label = UiStyle.title_label(tr("CREDITS_THANKS"), 34)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(thanks)
	_y = get_viewport().get_visible_rect().size.y
	_layout.call_deferred(v)


func _layout(v: VBoxContainer) -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	v.position = Vector2((vs.x - v.size.x) * 0.5, _y)


func _process(delta: float) -> void:
	var v: Control = _scroll.get_child(0) as Control
	_y -= delta * SPEED * (6.0 if _fast else 1.0)
	v.position.y = _y
	if _y + v.size.y < -40.0:
		finished.emit()
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		_fast = true
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"ui_accept") or event.is_action_released(&"ui_cancel") or event.is_action_released(&"pause"):
		_fast = false
