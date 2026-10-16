class_name MainMenu
extends Control
## Menu inicial: arte da ilha ao entardecer (captura do próprio jogo) com zoom
## lento, título e as opções Continuar, Novo jogo, Carregar, Opções, Créditos, Sair.

const BG_PATH: String = "res://assets/ui/menu_bg.png"

var _bg: TextureRect
var _menu: VBoxContainer
var _t: float = 0.0
var _sub: Control


func _ready() -> void:
	theme = UiStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Settings.apply_window_mode()
	var base: ColorRect = ColorRect.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.03, 0.025, 0.045)
	add_child(base)
	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(BG_PATH):
		_bg.texture = load(BG_PATH) as Texture2D
	add_child(_bg)
	var shade: TextureRect = TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.02, 0.015, 0.035, 0.92))
	grad.set_color(1, Color(0.02, 0.015, 0.035, 0.0))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.75, 0)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(shade)
	_add_embers()
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 110
	col.offset_right = 640
	col.offset_top = 150
	col.add_theme_constant_override(&"separation", 12)
	add_child(col)
	var title: Label = UiStyle.title_label("DARK MAGE", 76)
	col.add_child(title)
	var sub: Label = UiStyle.title_label(tr("MENU_SUBTITLE"), 28)
	sub.add_theme_color_override(&"font_color", UiStyle.TEXT)
	col.add_child(sub)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	col.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 10)
	_menu.custom_minimum_size = Vector2(380, 0)
	col.add_child(_menu)
	var latest: int = SaveSystem.latest_slot()
	if latest >= 0:
		_menu.add_child(MenuKit.button(tr("MENU_CONTINUE"), func() -> void: Game.continue_game(latest)))
	_menu.add_child(MenuKit.button(tr("MENU_NEW"), func() -> void:
		ListPanel.slot_picker(self, "new", func(slot: int) -> void: Game.start_new_game(slot))))
	var load_b: Button = MenuKit.button(tr("MENU_LOAD"), func() -> void:
		ListPanel.slot_picker(self, "load", func(slot: int) -> void: Game.continue_game(slot)))
	load_b.disabled = latest < 0
	_menu.add_child(load_b)
	_menu.add_child(MenuKit.button(tr("UI_OPTIONS"), _open_options))
	_menu.add_child(MenuKit.button(tr("MENU_CREDITS"), _open_credits))
	_menu.add_child(MenuKit.button(tr("UI_QUIT"), func() -> void: get_tree().quit()))
	var ver: Label = Label.new()
	ver.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -160
	ver.offset_top = -44
	ver.add_theme_color_override(&"font_color", UiStyle.TEXT_DIM)
	add_child(ver)
	MenuKit.apply_ui_scale(self)
	MenuKit.focus_first.call_deferred(_menu)


func _process(delta: float) -> void:
	_t += delta
	# Zoom lento ("Ken Burns") sobre a arte de fundo.
	var k: float = 1.04 + 0.03 * sin(_t * 0.05)
	_bg.pivot_offset = _bg.size * 0.5
	_bg.scale = Vector2(k, k)
	_bg.position.x = -12.0 * sin(_t * 0.04)


func _add_embers() -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.amount = 60
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1100, 20)
	p.position = Vector2(960, 1120)
	p.direction = Vector2(0.15, -1)
	p.spread = 15.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.71, 0.49, 1.0, 0.0))
	g.add_point(0.2, Color(0.71, 0.49, 1.0, 0.7))
	g.set_color(1, Color(0.91, 0.71, 0.3, 0.0))
	p.color_ramp = g
	add_child(p)


func _unhandled_input(event: InputEvent) -> void:
	if _sub != null and event.is_action_pressed(&"ui_cancel"):
		_close_sub()
		get_viewport().set_input_as_handled()


func _open_options() -> void:
	var o: OptionsMenu = OptionsMenu.new()
	o.closed.connect(_close_sub)
	_sub = o
	add_child(o)


func _open_credits() -> void:
	var p: ListPanel = ListPanel.new()
	p.title = tr("MENU_CREDITS")
	p.width = 760.0
	p.back.connect(_close_sub)
	_sub = p
	var text: String = FileAccess.get_file_as_string("res://CREDITS.md") if FileAccess.file_exists("res://CREDITS.md") else ""
	add_child(p)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 460)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lbl: Label = UiStyle.body_label(text.replace("#", "").replace("**", "").replace("`", ""), 17)
	lbl.custom_minimum_size = Vector2(690, 0)
	sc.add_child(lbl)
	p._box.add_child(sc)
	var close: Button = MenuKit.button(tr("UI_BACK"), _close_sub)
	p._box.add_child(close)
	close.grab_focus.call_deferred()


func _close_sub() -> void:
	if _sub != null:
		_sub.queue_free()
		_sub = null
		Settings.save_settings()
	MenuKit.focus_first.call_deferred(_menu)
