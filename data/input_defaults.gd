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
	&"inventory": [["key", KEY_I], ["joy_button", JOY_BUTTON_BACK]],
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
