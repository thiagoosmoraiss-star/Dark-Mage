class_name InteriorManager
extends Node3D
## Cenas internas (santuários e covis) construídas sob demanda numa "dimensão de
## bolso" (longe da ilha, acima do mar). Entrar/sair = fade + teleporte + troca
## do ambiente da câmera; sol e lua apagam enquanto o jogador está dentro.

signal entered(id: String)
signal exited(id: String)

const POCKET_ORIGIN: Vector3 = Vector3(6000.0, 400.0, 6000.0)
const POCKET_SPACING: float = 260.0

var world: IslandWorld
var current_id: String = ""
var _interiors: Dictionary[String, Node3D] = {}
var _return_point: Vector3
var _return_yaw: float = 0.0
var _env: Environment
var _fade: ColorRect
var _slots: int = 0
var _busy: bool = false


func _ready() -> void:
	add_to_group(&"interiors")
	_env = InteriorBuilder.interior_environment()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


## Verdadeiro durante o fade de entrada/saída (menus não abrem).
func is_busy() -> bool:
	return _busy


func is_inside() -> bool:
	return current_id != ""


func interior(id: String) -> Node3D:
	return _interiors.get(id)


## Cria (se preciso) e entra no interior `id`. `builder` monta o conteúdo e
## devolve o nó raiz, que precisa ter o método spawn_point().
func enter(id: String, builder: Callable, entrance: Node3D) -> void:
	if world.player == null or is_inside() or _busy:
		return
	_busy = true
	await _fade_to(1.0)
	if not _interiors.has(id):
		var origin: Vector3 = POCKET_ORIGIN + Vector3(_slots * POCKET_SPACING, 0, 0)
		_slots += 1
		var node: Node3D = builder.call(self, origin) as Node3D
		_interiors[id] = node
	var node2: Node3D = _interiors[id]
	_return_point = entrance.global_position + entrance.global_basis.z * 3.5 + Vector3.UP * 0.3
	_return_yaw = entrance.global_rotation.y
	current_id = id
	_set_outdoor(false)
	var spawn: Transform3D = node2.call(&"spawn_point")
	world.player.teleport(spawn.origin)
	world.player.rotation.y = spawn.basis.get_euler().y
	if world.player.cam_rig != null:
		world.player.cam_rig.yaw = world.player.rotation.y
		world.player.cam_rig.global_position = world.player.global_position + Vector3.UP * 1.5
	if node2.has_method(&"on_enter"):
		node2.call(&"on_enter", world.player)
	entered.emit(id)
	await get_tree().create_timer(0.25, true).timeout
	await _fade_to(0.0)
	_busy = false


func exit_interior() -> void:
	if not is_inside() or _busy:
		return
	_busy = true
	var id: String = current_id
	await _fade_to(1.0)
	current_id = ""
	_set_outdoor(true)
	world.player.teleport(_return_point)
	world.player.rotation.y = _return_yaw + PI
	world.player.respawn_point = _return_point
	if world.player.cam_rig != null:
		world.player.cam_rig.yaw = world.player.rotation.y
		world.player.cam_rig.global_position = world.player.global_position + Vector3.UP * 1.5
	exited.emit(id)
	await get_tree().create_timer(0.25, true).timeout
	await _fade_to(0.0)
	_busy = false


## Sai imediatamente, sem fade nem teleporte (carregar jogo, viagem, capturas).
func force_outdoor() -> void:
	if not is_inside():
		return
	var id: String = current_id
	current_id = ""
	_set_outdoor(true)
	exited.emit(id)


func _set_outdoor(on: bool) -> void:
	Audio.set_indoor(not on)
	var cam: Camera3D = world.player.cam_rig.camera if world.player.cam_rig != null else null
	if cam != null:
		cam.environment = null if on else _env
	if world.atmosphere != null:
		world.atmosphere.sun.visible = on and world.atmosphere.sun.light_energy > 0.001
		world.atmosphere.moon.visible = on and world.atmosphere.moon.light_energy > 0.001
		world.atmosphere.set_process(on)
	if world.ocean != null:
		world.ocean.visible = on
	# Dentro: o respawn é a entrada da sala (morrer reinicia a sala).
	if not on:
		world.player.respawn_point = (_interiors[current_id].call(&"spawn_point") as Transform3D).origin


func _fade_to(a: float) -> void:
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", a, 0.35)
	await tw.finished
