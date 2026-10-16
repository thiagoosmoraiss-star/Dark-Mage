class_name IslandWorld
extends Node3D
## Cena principal do mundo aberto: atmosfera, terreno, mar, jogador e HUD.
## O jogador nasce no Vale do Despertar, num ponto já validado do terreno.

const SPAWN: Vector2 = Vector2(30.0, 180.0)

@export var spawn_player: bool = true

var atmosphere: Atmosphere
var terrain: IslandTerrain
var ocean: Ocean
var player: Player
var hud: CanvasLayer
var vegetation: VegetationSystem
var grass: GrassField
var fog: FogOfWar = FogOfWar.new()
var map_screen: MapScreen
var _reveal_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"world")
	atmosphere = get_node_or_null(^"Atmosphere") as Atmosphere
	terrain = get_node_or_null(^"IslandTerrain") as IslandTerrain
	ocean = get_node_or_null(^"Ocean") as Ocean
	# Flags de perfil (só desenvolvimento): -- --no-veg --no-grass --no-water --no-shadows
	if ocean != null and Game.has_arg("--no-water"):
		ocean.visible = false
	if atmosphere != null and Game.has_arg("--no-shadows"):
		atmosphere.sun.shadow_enabled = false
	if terrain != null and not Game.has_arg("--no-veg"):
		vegetation = VegetationSystem.new()
		vegetation.name = "Vegetation"
		vegetation.terrain = terrain
		add_child(vegetation)
	if terrain != null and not Game.has_arg("--no-grass"):
		for which: int in [GrassField.Layer.GRASS, GrassField.Layer.FLOWERS, GrassField.Layer.FERNS,
				GrassField.Layer.BUSHES, GrassField.Layer.MUSHROOMS]:
			var layer_node: GrassField = GrassField.make_layer(which as GrassField.Layer)
			layer_node.terrain = terrain
			add_child(layer_node)
			if which == GrassField.Layer.GRASS:
				grass = layer_node
	if Game.has_arg("--bench"):
		var bench: BenchFlight = BenchFlight.new()
		bench.name = "BenchFlight"
		add_child(bench)
	elif spawn_player:
		_spawn_player()
	else:
		# Sem jogador (vistas e capturas): câmera livre no Vale olhando a Cidadela.
		var cam: Camera3D = Camera3D.new()
		cam.name = "ViewCamera"
		cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		cam.far = 4000.0
		add_child(cam)
		cam.global_position = Vector3(0, 90, 420)
		cam.look_at(Vector3(0, 60, -360))
		cam.current = true
		if terrain != null:
			terrain.terrain.set_camera(cam)


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	add_child(player)
	var y: float = terrain.height_at(Vector3(SPAWN.x, 0.0, SPAWN.y)) if terrain != null else 0.0
	player.teleport(Vector3(SPAWN.x, y + 0.3, SPAWN.y))
	player.rotation.y = PI * 0.15  # olhando para o norte, com a Cidadela no horizonte
	if player.cam_rig != null:
		player.cam_rig.yaw = player.rotation.y
		if terrain != null:
			terrain.terrain.set_camera(player.cam_rig.camera)
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var wheel: StaminaWheel = StaminaWheel.new()
	wheel.player = player
	hud.add_child(wheel)
	map_screen = MapScreen.new()
	map_screen.name = "MapScreen"
	map_screen.fog = fog
	map_screen.player = player
	add_child(map_screen)
	fog.reveal(player.global_position, 90.0)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_reveal_timer += delta
	if _reveal_timer >= 0.5:
		_reveal_timer = 0.0
		# Revela mais longe quando o jogador está no alto (mirantes).
		var h: float = player.global_position.y
		fog.reveal(player.global_position, clampf(70.0 + h * 0.6, 70.0, 220.0))


func _unhandled_input(event: InputEvent) -> void:
	if map_screen != null and map_screen.is_open():
		return
	if event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
