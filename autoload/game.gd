extends Node
## Estado global do jogo: pausa, modo de desenvolvedor, argumentos de linha de
## comando e o fluxo menu inicial → carregamento → ilha (novo jogo ou save).

const ISLAND_SCENE: String = "res://levels/island/island.tscn"
const MENU_SCENE: String = "res://levels/main_menu.tscn"

## Verdadeiro em build de debug ou com o argumento `--dev` (após `--`).
var dev_mode: bool = false
var paused: bool = false
## Slot em uso (autosave, fogueiras e epílogo gravam aqui).
var current_slot: int = 0
## Save lido pelo menu e ainda não aplicado ao jogador/mundo (a ilha aplica no _ready).
var pending_save: Dictionary = {}
## Novo jogo: a ilha mostra a introdução.
var new_game: bool = false
## Último dispositivo usado (para mostrar rótulos de teclado ou de gamepad).
var using_gamepad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dev_mode = OS.is_debug_build() or has_arg("--dev")


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_gamepad = false


func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	Events.game_paused.emit(value)


static func has_arg(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)


func start_new_game(slot: int) -> void:
	GameState.reset()
	Inventory.reset()
	current_slot = slot
	pending_save = {}
	new_game = true
	Events.game_started.emit(slot)
	goto(ISLAND_SCENE)


## Lê o slot e prepara GameState/Inventory antes de montar a ilha (baús abertos,
## faróis acesos e chefes vencidos já nascem no estado certo). false se inválido.
func continue_game(slot: int) -> bool:
	var data: Dictionary = SaveSystem.load_slot(slot)
	if data.is_empty():
		return false
	var progress: Variant = data.get("progress", {})
	GameState.from_dict(progress as Dictionary if progress is Dictionary else {})
	var inv: Variant = data.get("inventory", {})
	Inventory.from_dict(inv as Dictionary if inv is Dictionary else {})
	current_slot = slot
	pending_save = data
	new_game = false
	goto(ISLAND_SCENE)
	return true


func goto_main_menu() -> void:
	get_tree().paused = false
	goto(MENU_SCENE)


## Troca de cena passando pela tela de carregamento (carga em segundo plano).
func goto(path: String) -> void:
	var ls: LoadingScreen = LoadingScreen.new()
	ls.target = path
	get_tree().paused = false
	get_tree().change_scene_to_node(ls)
