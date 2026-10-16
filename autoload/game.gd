extends Node
## Estado global do jogo: pausa, modo de desenvolvedor e argumentos de linha de comando.

## Verdadeiro em build de debug ou com o argumento `--dev` (após `--`).
var dev_mode: bool = false
var paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dev_mode = OS.is_debug_build() or has_arg("--dev")


func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	Events.game_paused.emit(value)


static func has_arg(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)
