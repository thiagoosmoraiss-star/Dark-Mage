extends Node
## Configurações do jogador, salvas em user://settings.cfg (ConfigFile, só dados).

const PATH: String = "user://settings.cfg"
const VERSION: int = 1

const DEFAULTS: Dictionary = {
	"graphics": {
		"preset": "",  # vazio = detectar na primeira execução
		"vsync": true,
		"max_fps": 0,
		"window_mode": "fullscreen",  # windowed | borderless | fullscreen
		"fov": 75.0,
	},
	"audio": {
		"master": 1.0, "music": 0.8, "sfx": 1.0, "ambient": 0.8, "ui": 0.8, "voice": 1.0,
	},
	"controls": {
		"mouse_sensitivity": 0.25,
		"invert_y": false,
		"gamepad_sensitivity": 1.0,
	},
	"general": {
		"language": "pt_BR",
	},
	"accessibility": {
		"colorblind_mode": "none",  # none | protanopia | deuteranopia | tritanopia
		"subtitles": true,
		"subtitle_size": 1.0,
		"ui_scale": 1.0,
		"camera_shake": 1.0,
		"reduce_flashes": false,
		"colorblind_markers": false,
		"damage_numbers": true,
		"aim_assist": false,
		"hud_hide_out_of_combat": false,
	},
}

var _cfg: ConfigFile = ConfigFile.new()
## Caminho alternativo, usado pelos testes para não tocar o arquivo real.
var path: String = PATH
var _cb_layer: CanvasLayer
var _cb_rect: ColorRect


func _ready() -> void:
	load_settings()
	InputDefaults.apply_to_input_map()
	_apply_input_remaps()
	if str(get_value("graphics", "preset")) == "":
		var guess: StringName = GraphicsPresets.guess_from_adapter(RenderingServer.get_video_adapter_name())
		set_value("graphics", "preset", String(guess))
	apply_graphics()
	apply_language()
	apply_accessibility()


func load_settings() -> void:
	_cfg = ConfigFile.new()
	var err: Error = _cfg.load(path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Settings: arquivo inválido (%s), usando padrões." % error_string(err))
		_cfg = ConfigFile.new()
	_cfg.set_value("meta", "version", VERSION)


func save_settings() -> Error:
	return _cfg.save(path)


func get_value(section: String, key: String) -> Variant:
	var fallback: Variant = (DEFAULTS.get(section, {}) as Dictionary).get(key)
	return _cfg.get_value(section, key, fallback)


func set_value(section: String, key: String, value: Variant) -> void:
	_cfg.set_value(section, key, value)
	Events.settings_changed.emit(section)


func current_preset() -> StringName:
	return StringName(str(get_value("graphics", "preset")))


func set_preset(preset: StringName) -> void:
	set_value("graphics", "preset", String(preset))
	apply_graphics()
	Events.graphics_preset_changed.emit(String(preset))


## Aplica o preset ao viewport principal e às sombras globais. O ambiente
## (SSAO, SSR, névoa...) é aplicado pelo mundo ao ouvir graphics_preset_changed.
func apply_graphics() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Dictionary = GraphicsPresets.get_preset(current_preset())
	var vp: Viewport = get_viewport()
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.use_taa = p["taa"]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	# FSR1 (espacial) nos presets baixos: o FSR2 custa ~30 ms numa GPU integrada (D33).
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if p["fsr"] else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = p["render_scale"]
	var atlas: int = p["shadow_atlas"]
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	var vsync: bool = get_value("graphics", "vsync")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = roundi(SaveCodec.num(get_value("graphics", "max_fps"), 0.0))


func apply_window_mode() -> void:
	# Capturas, benchmark e testes passam --windowed/--resolution: não mexe na janela.
	var args: PackedStringArray = OS.get_cmdline_args()
	if DisplayServer.get_name() == "headless" or args.has("--windowed") or args.has("--resolution") or Game.has_arg("--bench"):
		return
	# Rodando uma ferramenta (-s capture.gd, GdUnit): a janela é da ferramenta.
	if Engine.get_main_loop() != null and Engine.get_main_loop().get_script() != null:
		return
	match str(get_value("graphics", "window_mode")):
		"windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func apply_language() -> void:
	TranslationServer.set_locale(str(get_value("general", "language")))


## Filtro de daltonismo (correção por daltonização) num CanvasLayer acima de tudo.
func apply_accessibility() -> void:
	var mode: String = str(get_value("accessibility", "colorblind_mode"))
	var idx: int = ["none", "protanopia", "deuteranopia", "tritanopia"].find(mode)
	if idx <= 0:
		if _cb_layer != null:
			_cb_layer.visible = false
		return
	if _cb_layer == null:
		_cb_layer = CanvasLayer.new()
		_cb_layer.layer = 120
		add_child(_cb_layer)
		_cb_rect = ColorRect.new()
		_cb_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_cb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = load("res://shaders/colorblind.gdshader") as Shader
		_cb_rect.material = m
		_cb_layer.add_child(_cb_rect)
	_cb_layer.visible = true
	(_cb_rect.material as ShaderMaterial).set_shader_parameter(&"mode", idx)


# --- Remapeamento -------------------------------------------------------------

## Substitui os eventos de uma ação. `specs` usa o formato de InputDefaults.
func remap_action(action: StringName, specs: Array) -> void:
	_cfg.set_value("input", String(action), specs)
	_apply_remap(action, specs)
	Events.input_remapped.emit(action)


## Troca o evento de teclado/mouse (ou de gamepad) de `action` por `spec`. Se outra
## ação remapeável já usava esse evento, ela recebe o evento antigo (troca).
func rebind(action: StringName, spec: Array) -> void:
	var pad: bool = InputDefaults.is_pad_spec(spec)
	var old: Array = []
	var specs: Array = []
	for s: Variant in InputDefaults.current_specs(action):
		var sa: Array = s
		if InputDefaults.is_pad_spec(sa) == pad and old.is_empty():
			old = sa
		else:
			specs.append(sa)
	specs.insert(0, spec)
	# Contextos: os feitiços do gamepad (LB + botão) só conflitam entre si.
	var modifier_ctx: bool = String(action).begins_with("pad_spell")
	for other: StringName in InputDefaults.REMAPPABLE:
		if other == action or String(other).begins_with("pad_spell") != modifier_ctx:
			continue
		var os: Array = InputDefaults.current_specs(other)
		var hit: int = -1
		for i: int in os.size():
			if os[i] == spec:
				hit = i
		if hit >= 0:
			if old.is_empty():
				os.remove_at(hit)
			else:
				os[hit] = old
			remap_action(other, os)
	remap_action(action, specs)


func reset_controls() -> void:
	if _cfg.has_section("input"):
		_cfg.erase_section("input")
	InputDefaults.apply_to_input_map()


func _apply_input_remaps() -> void:
	if not _cfg.has_section("input"):
		return
	for key: String in _cfg.get_section_keys("input"):
		var action: StringName = StringName(key)
		if not InputDefaults.ACTIONS.has(action):
			continue  # ação removida em versão nova: ignora
		var specs: Variant = _cfg.get_value("input", key)
		if specs is Array:
			_apply_remap(action, specs as Array)


func _apply_remap(action: StringName, specs: Array) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for spec: Variant in specs:
		if spec is Array and (spec as Array).size() >= 2:
			var ev: InputEvent = InputDefaults.make_event(spec as Array)
			if ev != null:
				InputMap.action_add_event(action, ev)
