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
	if has_arg("--export-smoke"):
		_export_smoke.call_deferred()


## Aceite do M11 no executável exportado: menu → novo jogo (espaço 3) → salvar →
## menu → continuar → confere o estado. Grava user://export_smoke.txt e fecha.
func _export_smoke() -> void:
	var log_lines: PackedStringArray = []
	var ok: bool = true
	SaveSystem.delete_slot(2)
	await get_tree().create_timer(2.0).timeout
	var menu_ok: bool = get_tree().current_scene is MainMenu
	log_lines.append("menu: %s" % menu_ok)
	ok = ok and menu_ok
	start_new_game(2)
	var world: IslandWorld = await _wait_world()
	log_lines.append("ilha (novo jogo): %s" % (world != null))
	if world == null:
		_finish_smoke(false, log_lines)
		return
	GameState.add_souls(777)
	Inventory.add("staff_ember")
	var err: Error = world.save_game(2)
	log_lines.append("save: %s" % error_string(err))
	ok = ok and err == OK
	goto_main_menu()
	await get_tree().create_timer(4.0).timeout
	log_lines.append("voltou ao menu: %s" % (get_tree().current_scene is MainMenu))
	GameState.reset()
	Inventory.reset()
	ok = ok and continue_game(2)
	world = await _wait_world()
	var restored: bool = world != null and GameState.souls == 777 and Inventory.count("staff_ember") == 1
	log_lines.append("carregar e conferir: %s" % restored)
	SaveSystem.delete_slot(2)
	_finish_smoke(ok and restored, log_lines)


func _wait_world() -> IslandWorld:
	for i: int in 600:
		await get_tree().create_timer(0.1).timeout
		var w: IslandWorld = get_tree().current_scene as IslandWorld
		if w != null and w.player != null:
			await get_tree().create_timer(1.0).timeout
			return w
	return null


func _finish_smoke(ok: bool, lines: PackedStringArray) -> void:
	lines.append("RESULTADO: %s" % ("APROVADO" if ok else "REPROVADO"))
	var f: FileAccess = FileAccess.open("user://export_smoke.txt", FileAccess.WRITE)
	f.store_string("
".join(lines))
	f.close()
	print("
".join(lines))
	get_tree().quit(0 if ok else 1)


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
	Music.forced = &""
	Music.stop_all()
	var ls: LoadingScreen = LoadingScreen.new()
	ls.target = path
	get_tree().paused = false
	get_tree().change_scene_to_node(ls)
