class_name InputDefaults
extends RefCounted
## Tabela única dos controles padrão (roteiro, seção 4.1). É usada por:
## - tools/setup_input_map.gd, que grava o InputMap em project.godot;
## - Settings, para "restaurar padrões" e aplicar remapeamentos salvos.
## Alt nunca é usado (conflita com o menu do sistema no Windows).
## Interagir = G (E é o Feitiço 2; ver DECISIONS.md).

const DEADZONE: float = 0.2

## Cada evento: ["key", Key], ["mouse", MouseButton], ["joy_button", JoyButton],
## ["joy_axis", JoyAxis, direção (-1.0 ou 1.0)].
const ACTIONS: Dictionary = {
	&"move_forward": [["key", KEY_W], ["joy_axis", JOY_AXIS_LEFT_Y, -1.0]],
	&"move_back": [["key", KEY_S], ["joy_axis", JOY_AXIS_LEFT_Y, 1.0]],
	&"move_left": [["key", KEY_A], ["joy_axis", JOY_AXIS_LEFT_X, -1.0]],
	&"move_right": [["key", KEY_D], ["joy_axis", JOY_AXIS_LEFT_X, 1.0]],
	&"camera_up": [["joy_axis", JOY_AXIS_RIGHT_Y, -1.0]],
	&"camera_down": [["joy_axis", JOY_AXIS_RIGHT_Y, 1.0]],
	&"camera_left": [["joy_axis", JOY_AXIS_RIGHT_X, -1.0]],
	&"camera_right": [["joy_axis", JOY_AXIS_RIGHT_X, 1.0]],
	&"jump": [["key", KEY_SPACE], ["joy_button", JOY_BUTTON_A]],
	&"sprint": [["key", KEY_SHIFT], ["joy_button", JOY_BUTTON_LEFT_STICK]],
	&"dodge": [["key", KEY_CTRL], ["key", KEY_C], ["joy_button", JOY_BUTTON_B]],
	&"attack": [["mouse", MOUSE_BUTTON_LEFT], ["joy_axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	&"aim": [["mouse", MOUSE_BUTTON_RIGHT], ["joy_axis", JOY_AXIS_TRIGGER_LEFT, 1.0]],
	&"spell_1": [["key", KEY_Q]],
	&"spell_2": [["key", KEY_E]],
	&"spell_3": [["key", KEY_R]],
	&"spell_4": [["key", KEY_F]],
	&"spell_modifier": [["joy_button", JOY_BUTTON_LEFT_SHOULDER]],
	&"spell_wheel": [["joy_button", JOY_BUTTON_RIGHT_SHOULDER]],
	&"interact": [["key", KEY_G], ["joy_button", JOY_BUTTON_X]],
	&"lock_on": [["mouse", MOUSE_BUTTON_MIDDLE], ["key", KEY_TAB], ["joy_button", JOY_BUTTON_RIGHT_STICK]],
	&"pad_spell_1": [["joy_button", JOY_BUTTON_A]],
	&"pad_spell_2": [["joy_button", JOY_BUTTON_B]],
	&"pad_spell_3": [["joy_button", JOY_BUTTON_X]],
	&"pad_spell_4": [["joy_button", JOY_BUTTON_Y]],
	&"quick_potion": [["key", KEY_H], ["joy_button", JOY_BUTTON_DPAD_DOWN]],
	&"quick_mana": [["key", KEY_J], ["joy_button", JOY_BUTTON_DPAD_RIGHT]],
	&"inventory": [["key", KEY_I], ["joy_button", JOY_BUTTON_BACK]],
	&"journal": [["key", KEY_L], ["joy_button", JOY_BUTTON_DPAD_LEFT]],
	&"ui_move_item": [["key", KEY_X], ["joy_button", JOY_BUTTON_Y]],
	&"ui_tab_prev": [["key", KEY_Q], ["joy_button", JOY_BUTTON_LEFT_SHOULDER]],
	&"ui_tab_next": [["key", KEY_E], ["joy_button", JOY_BUTTON_RIGHT_SHOULDER]],
	&"map": [["key", KEY_M], ["joy_button", JOY_BUTTON_DPAD_UP]],
	&"pause": [["key", KEY_ESCAPE], ["joy_button", JOY_BUTTON_START]],
	&"debug_overlay": [["key", KEY_F3]],
}


static func make_event(spec: Array) -> InputEvent:
	var ev: InputEvent = _make_event_raw(spec)
	if ev != null:
		ev.device = -1  # qualquer dispositivo, como os eventos criados no editor
	return ev


static func _make_event_raw(spec: Array) -> InputEvent:
	var kind: String = spec[0]
	match kind:
		"key":
			var k: InputEventKey = InputEventKey.new()
			k.physical_keycode = spec[1] as Key
			return k
		"mouse":
			var m: InputEventMouseButton = InputEventMouseButton.new()
			m.button_index = spec[1] as MouseButton
			return m
		"joy_button":
			var b: InputEventJoypadButton = InputEventJoypadButton.new()
			b.button_index = spec[1] as JoyButton
			return b
		"joy_axis":
			var a: InputEventJoypadMotion = InputEventJoypadMotion.new()
			a.axis = spec[1] as JoyAxis
			a.axis_value = spec[2] as float
			return a
	push_error("InputDefaults: tipo de evento desconhecido '%s'" % kind)
	return null


static func events_for(action: StringName) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	var specs: Array = ACTIONS.get(action, [])
	for spec: Array in specs:
		var ev: InputEvent = make_event(spec)
		if ev != null:
			out.append(ev)
	return out


## Recria todas as ações no InputMap em tempo de execução com os padrões.
static func apply_to_input_map() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, DEADZONE)
		for ev: InputEvent in events_for(action):
			InputMap.action_add_event(action, ev)


# --- Remapeamento: conversão evento ↔ spec e rótulos -------------------------

## Ações que o jogador pode remapear (na ordem da tela de opções).
const REMAPPABLE: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"sprint", &"dodge", &"attack", &"aim",
	&"spell_1", &"spell_2", &"spell_3", &"spell_4", &"interact", &"lock_on", &"quick_potion", &"quick_mana",
	&"inventory", &"journal", &"map", &"pause",
	&"pad_spell_1", &"pad_spell_2", &"pad_spell_3", &"pad_spell_4",
]

const PAD_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓", JOY_BUTTON_DPAD_LEFT: "D-pad ←",
	JOY_BUTTON_DPAD_RIGHT: "D-pad →",
}


static func is_pad_spec(spec: Array) -> bool:
	return str(spec[0]).begins_with("joy")


## Spec (formato da tabela ACTIONS) de um evento; [] se não for remapeável.
static func spec_of(ev: InputEvent) -> Array:
	if ev is InputEventKey:
		var k: InputEventKey = ev
		var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return ["key", code]
	if ev is InputEventMouseButton:
		return ["mouse", (ev as InputEventMouseButton).button_index]
	if ev is InputEventJoypadButton:
		return ["joy_button", (ev as InputEventJoypadButton).button_index]
	if ev is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = ev
		return ["joy_axis", m.axis, 1.0 if m.axis_value > 0.0 else -1.0]
	return []


static func current_specs(action: StringName) -> Array:
	var out: Array = []
	if InputMap.has_action(action):
		for ev: InputEvent in InputMap.action_get_events(action):
			var s: Array = spec_of(ev)
			if not s.is_empty():
				out.append(s)
	return out


static func spec_label(spec: Array) -> String:
	if spec.is_empty():
		return "—"
	match str(spec[0]):
		"key":
			return OS.get_keycode_string(spec[1] as Key)
		"mouse":
			var names: Dictionary = {MOUSE_BUTTON_LEFT: "Mouse 1", MOUSE_BUTTON_RIGHT: "Mouse 2", MOUSE_BUTTON_MIDDLE: "Mouse 3",
				MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5"}
			return str(names.get(spec[1], "Mouse %d" % roundi(JsonUtil.num(spec[1]))))
		"joy_button":
			return str(PAD_NAMES.get(spec[1], "Botão %d" % roundi(JsonUtil.num(spec[1]))))
		"joy_axis":
			var axis: int = roundi(JsonUtil.num(spec[1]))
			var dir: float = JsonUtil.num(spec[2])
			match axis:
				JOY_AXIS_TRIGGER_LEFT:
					return "LT"
				JOY_AXIS_TRIGGER_RIGHT:
					return "RT"
				JOY_AXIS_LEFT_X:
					return "L ←" if dir < 0.0 else "L →"
				JOY_AXIS_LEFT_Y:
					return "L ↑" if dir < 0.0 else "L ↓"
				JOY_AXIS_RIGHT_X:
					return "R ←" if dir < 0.0 else "R →"
				JOY_AXIS_RIGHT_Y:
					return "R ↑" if dir < 0.0 else "R ↓"
	return "?"


## Rótulo do primeiro evento de teclado/mouse (pad=false) ou de gamepad (pad=true).
static func action_label(action: StringName, pad: bool) -> String:
	for s: Variant in current_specs(action):
		if is_pad_spec(s as Array) == pad:
			return spec_label(s as Array)
	# Feitiços no gamepad: LB + botão (ações pad_spell_N).
	if pad and String(action).begins_with("spell_") and InputMap.has_action(StringName("pad_" + String(action))):
		return "LB+" + action_label(StringName("pad_" + String(action)), true)
	return "—"
