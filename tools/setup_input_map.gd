extends SceneTree
## Grava o InputMap padrão (data/input_defaults.gd) em project.godot.
## Uso: godot --headless --path . -s res://tools/setup_input_map.gd

func _initialize() -> void:
	for action: StringName in InputDefaults.ACTIONS:
		var events: Array[InputEvent] = InputDefaults.events_for(action)
		ProjectSettings.set_setting("input/%s" % action, {
			"deadzone": InputDefaults.DEADZONE,
			"events": events,
		})
	var err: Error = ProjectSettings.save()
	if err != OK:
		push_error("Falha ao salvar project.godot: %s" % error_string(err))
		quit(1)
		return
	print("InputMap gravado: %d ações." % InputDefaults.ACTIONS.size())
	quit(0)
