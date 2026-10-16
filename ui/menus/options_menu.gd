class_name OptionsMenu
extends TabbedScreen
## Opções (roteiro 6): gráficos, áudio, controles com remapeamento e
## acessibilidade. Tudo é gravado em user://settings.cfg ao fechar.

var _listen_action: StringName = &""
var _listen_pad: bool = false
var _listen_button: Button


func _init() -> void:
	title = tr("UI_OPTIONS")
	hint = tr("UI_HINT_OPTIONS")
	tabs = [
		[tr("OPT_TAB_GRAPHICS"), _graphics_tab],
		[tr("OPT_TAB_AUDIO"), _audio_tab],
		[tr("OPT_TAB_CONTROLS"), _controls_tab],
		[tr("OPT_TAB_ACCESS"), _access_tab],
	]
	closed.connect(func() -> void: Settings.save_settings())


func _page() -> ScrollContainer:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "Rows"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 10)
	sc.add_child(v)
	return sc


func _rows(sc: ScrollContainer) -> VBoxContainer:
	return sc.get_node(^"Rows") as VBoxContainer


func _on(section: String, key: String) -> bool:
	var v: bool = Settings.get_value(section, key) == true
	return v


func _off(section: String, key: String) -> bool:
	var v: bool = Settings.get_value(section, key) == false
	return v


func _setter(section: String, key: String) -> Callable:
	return func(v: Variant) -> void: Settings.set_value(section, key, v)


# --- Gráficos -------------------------------------------------------------------

func _graphics_tab() -> Control:
	var sc: ScrollContainer = _page()
	var r: VBoxContainer = _rows(sc)
	var presets: Array = []
	for p: StringName in GraphicsPresets.ORDER:
		presets.append([String(p), tr("PRESET_" + String(p).to_upper())])
	r.add_child(MenuKit.row(tr("OPT_PRESET"), MenuKit.choice(presets, String(Settings.current_preset()),
		func(v: Variant) -> void: Settings.set_preset(StringName(str(v))))))
	r.add_child(MenuKit.row(tr("OPT_WINDOW"), MenuKit.choice(
		[["windowed", tr("OPT_WINDOWED")], ["borderless", tr("OPT_BORDERLESS")], ["fullscreen", tr("OPT_FULLSCREEN")]],
		str(Settings.get_value("graphics", "window_mode")), func(v: Variant) -> void:
			Settings.set_value("graphics", "window_mode", v)
			Settings.apply_window_mode())))
	r.add_child(MenuKit.row(tr("OPT_VSYNC"), MenuKit.toggle(_on("graphics", "vsync"),
		func(v: bool) -> void:
			Settings.set_value("graphics", "vsync", v)
			Settings.apply_graphics())))
	var fps_now: int = roundi(JsonUtil.num(Settings.get_value("graphics", "max_fps")))
	r.add_child(MenuKit.row(tr("OPT_MAX_FPS"), MenuKit.choice(
		[[0, tr("OPT_UNLIMITED")], [30, "30"], [60, "60"], [90, "90"], [120, "120"], [144, "144"]], fps_now,
		func(v: Variant) -> void:
			Settings.set_value("graphics", "max_fps", v)
			Settings.apply_graphics())))
	var fov: float = JsonUtil.num(Settings.get_value("graphics", "fov"), 75.0)
	r.add_child(_slider_row(tr("OPT_FOV"), fov, 60.0, 100.0, 1.0, "%d°", func(v: float) -> void:
		Settings.set_value("graphics", "fov", v)))
	return sc


func _slider_row(label: String, value: float, min_v: float, max_v: float, step: float, fmt: String, cb: Callable) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 12)
	var val: Label = Label.new()
	val.custom_minimum_size = Vector2(70, 0)
	val.text = fmt % value if fmt.contains("%d") == false else fmt % roundi(value)
	var s: HSlider = MenuKit.slider(value, min_v, max_v, step, func(v: float) -> void:
		val.text = fmt % v if fmt.contains("%d") == false else fmt % roundi(v)
		cb.call(v))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(300, 40)
	h.add_child(s)
	h.add_child(val)
	h.custom_minimum_size = Vector2(390, 0)
	return MenuKit.row(label, h)


# --- Áudio ----------------------------------------------------------------------

func _audio_tab() -> Control:
	var sc: ScrollContainer = _page()
	var r: VBoxContainer = _rows(sc)
	for key: String in ["master", "music", "sfx", "ambient", "ui", "voice"]:
		var k: String = key
		var v: float = JsonUtil.num(Settings.get_value("audio", key), 1.0)
		r.add_child(_slider_row(tr("OPT_VOL_" + key.to_upper()), v * 100.0, 0.0, 100.0, 5.0, "%d%%", func(x: float) -> void:
			Settings.set_value("audio", k, x / 100.0)
			Audio.play(&"ui_select")))
	return sc


# --- Controles -------------------------------------------------------------------

func _controls_tab() -> Control:
	var sc: ScrollContainer = _page()
	var r: VBoxContainer = _rows(sc)
	r.add_child(_slider_row(tr("OPT_MOUSE_SENS"), JsonUtil.num(Settings.get_value("controls", "mouse_sensitivity"), 0.25),
		0.05, 1.0, 0.01, "%.2f", func(v: float) -> void: Settings.set_value("controls", "mouse_sensitivity", v)))
	r.add_child(_slider_row(tr("OPT_PAD_SENS"), JsonUtil.num(Settings.get_value("controls", "gamepad_sensitivity"), 1.0),
		0.3, 2.5, 0.05, "%.2f", func(v: float) -> void: Settings.set_value("controls", "gamepad_sensitivity", v)))
	r.add_child(MenuKit.row(tr("OPT_INVERT_Y"), MenuKit.toggle(_on("controls", "invert_y"),
		_setter("controls", "invert_y"))))
	r.add_child(MenuKit.separator())
	var head: HBoxContainer = HBoxContainer.new()
	var hl: Label = UiStyle.title_label(tr("OPT_REMAP"), 22)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	for t: String in [tr("OPT_KEYBOARD"), tr("OPT_GAMEPAD")]:
		var l: Label = Label.new()
		l.text = t
		l.custom_minimum_size = Vector2(190, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override(&"font_color", UiStyle.GOLD)
		head.add_child(l)
	r.add_child(head)
	for action: StringName in InputDefaults.REMAPPABLE:
		if String(action).begins_with("pad_"):
			continue  # editados pela coluna gamepad das linhas de feitiço
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override(&"separation", 8)
		var l2: Label = Label.new()
		l2.text = tr("ACTION_" + String(action).to_upper())
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l2)
		for pad: bool in [false, true]:
			var b: Button = MenuKit.button(InputDefaults.action_label(action, pad), Callable(), 38)
			b.custom_minimum_size = Vector2(190, 38)
			b.name = "%s_%s" % [action, "pad" if pad else "kb"]
			# No gamepad, os feitiços são LB + botão: remapeia o botão (pad_spell_N).
			var a: StringName = StringName("pad_" + String(action)) if pad and String(action).begins_with("spell_") else action
			var p: bool = pad
			b.pressed.connect(func() -> void: _start_listen(a, p, b))
			h.add_child(b)
		r.add_child(h)
	r.add_child(MenuKit.button(tr("OPT_RESET_CONTROLS"), func() -> void:
		Settings.reset_controls()
		refresh()))
	return sc


func _start_listen(action: StringName, pad: bool, b: Button) -> void:
	_listen_action = action
	_listen_pad = pad
	_listen_button = b
	b.text = tr("OPT_PRESS_KEY")


func _input(event: InputEvent) -> void:
	if _listen_action == &"" or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_listen_action = &""
		refresh()
		return
	var spec: Array = InputDefaults.spec_of(event)
	if spec.is_empty() or InputDefaults.is_pad_spec(spec) != _listen_pad:
		return
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.6:
		return
	var action: StringName = _listen_action
	_listen_action = &""
	Settings.rebind(action, spec)
	Audio.play(&"ui_confirm")
	refresh()


# --- Acessibilidade ---------------------------------------------------------------

func _access_tab() -> Control:
	var sc: ScrollContainer = _page()
	var r: VBoxContainer = _rows(sc)
	r.add_child(MenuKit.row(tr("OPT_LANGUAGE"), MenuKit.choice([["pt_BR", "Português (Brasil)"], ["en", "English"]],
		str(Settings.get_value("general", "language")), func(v: Variant) -> void:
			Settings.set_value("general", "language", v)
			Settings.apply_language()
			title = tr("UI_OPTIONS")
			refresh())))
	r.add_child(MenuKit.row(tr("OPT_SUBTITLES"), MenuKit.toggle(_on("accessibility", "subtitles"),
		_setter("accessibility", "subtitles"))))
	r.add_child(_slider_row(tr("OPT_SUBTITLE_SIZE"), JsonUtil.num(Settings.get_value("accessibility", "subtitle_size"), 1.0),
		0.8, 1.8, 0.1, "%.1f×", func(v: float) -> void: Settings.set_value("accessibility", "subtitle_size", v)))
	r.add_child(_slider_row(tr("OPT_UI_SCALE"), JsonUtil.num(Settings.get_value("accessibility", "ui_scale"), 1.0),
		0.75, 1.5, 0.05, "%.2f×", func(v: float) -> void: Settings.set_value("accessibility", "ui_scale", v)))
	r.add_child(MenuKit.row(tr("OPT_COLORBLIND"), MenuKit.choice(
		[["none", tr("OPT_CB_NONE")], ["protanopia", tr("OPT_CB_PROTAN")], ["deuteranopia", tr("OPT_CB_DEUTAN")], ["tritanopia", tr("OPT_CB_TRITAN")]],
		str(Settings.get_value("accessibility", "colorblind_mode")), func(v: Variant) -> void:
			Settings.set_value("accessibility", "colorblind_mode", v)
			Settings.apply_accessibility())))
	r.add_child(MenuKit.row(tr("OPT_COLORBLIND_MARKERS"), MenuKit.toggle(_on("accessibility", "colorblind_markers"),
		_setter("accessibility", "colorblind_markers"))))
	r.add_child(_slider_row(tr("OPT_SHAKE"), JsonUtil.num(Settings.get_value("accessibility", "camera_shake"), 1.0) * 100.0,
		0.0, 100.0, 5.0, "%d%%", func(v: float) -> void: Settings.set_value("accessibility", "camera_shake", v / 100.0)))
	r.add_child(MenuKit.row(tr("OPT_FLASHES"), MenuKit.toggle(_on("accessibility", "reduce_flashes"),
		_setter("accessibility", "reduce_flashes"))))
	r.add_child(MenuKit.row(tr("OPT_DAMAGE_NUMBERS"), MenuKit.toggle(not _off("accessibility", "damage_numbers"),
		_setter("accessibility", "damage_numbers"))))
	r.add_child(MenuKit.row(tr("OPT_AIM_ASSIST"), MenuKit.toggle(_on("accessibility", "aim_assist"),
		_setter("accessibility", "aim_assist"))))
	r.add_child(MenuKit.row(tr("OPT_HUD_HIDE"), MenuKit.toggle(_on("accessibility", "hud_hide_out_of_combat"),
		_setter("accessibility", "hud_hide_out_of_combat"))))
	return sc
