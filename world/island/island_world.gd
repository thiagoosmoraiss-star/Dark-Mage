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
var vfx: Vfx
var projectiles: ProjectilePool
var director: CombatDirector
var nav: NavBaker
var game_hud: Hud
var enemies: Array[Enemy] = []
var structures: Dictionary[StringName, Node3D] = {}
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
	vfx = Vfx.new()
	vfx.name = "Vfx"
	add_child(vfx)
	projectiles = ProjectilePool.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	director = CombatDirector.new()
	director.name = "CombatDirector"
	add_child(director)
	if terrain != null:
		_build_structures()
		nav = NavBaker.new()
		nav.name = "Navigation"
		nav.terrain = terrain
		add_child(nav)
		if not Game.has_arg("--no-enemies") and not Game.has_arg("--bench"):
			_spawn_camps()
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
	game_hud = Hud.new()
	game_hud.name = "GameHud"
	hud.add_child(game_hud)
	game_hud.bind(player)
	map_screen = MapScreen.new()
	map_screen.name = "MapScreen"
	map_screen.fog = fog
	map_screen.player = player
	add_child(map_screen)
	fog.reveal(player.global_position, 90.0)


func _build_structures() -> void:
	for poi: Dictionary in WorldPois.POIS:
		var p2: Vector2 = WorldPois.pos2(poi)
		var pos: Vector3 = Vector3(p2.x, terrain.height_at(Vector3(p2.x, 0, p2.y)), p2.y)
		match poi["kind"] as StringName:
			&"ruin":
				structures[poi["id"]] = RuinBuilder.build_ruin(self, pos, StableHash.fnv1a_string(String(poi["id"] as StringName)), terrain)
			&"beacon":
				structures[poi["id"]] = RuinBuilder.build_beacon_tower(self, pos - Vector3.UP * 0.5, 7)


## Acampamentos: rastejantes em grupo perto do centro e arqueiros nas bordas.
func _spawn_camps() -> void:
	var crawler: EnemyData = load("res://data/enemies/mist_crawler.tres") as EnemyData
	var archer: EnemyData = load("res://data/enemies/bone_archer.tres") as EnemyData
	for poi: Dictionary in WorldPois.by_kind(&"camp"):
		var c: Vector2 = WorldPois.pos2(poi)
		var rng: RandomNumberGenerator = Rng.make_rng(Rng.WORLD_SEED, "camp_" + String(poi["id"] as StringName))
		var layout: Array[Array] = [[crawler, Vector2(0, 0)], [crawler, Vector2(3, 2)], [crawler, Vector2(-3, 1.5)],
			[archer, Vector2(10, -6)], [archer, Vector2(-11, -5)]]
		for entry: Array in layout:
			var off: Vector2 = entry[1]
			var p: Vector2 = c + off + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			spawn_enemy(entry[0] as EnemyData, Vector3(p.x, 0.0, p.y), rng.randf() < 0.12)


func spawn_enemy(data: EnemyData, pos: Vector3, elite: bool = false) -> Enemy:
	var e: Enemy = Enemy.new()
	e.data = data
	e.elite = elite
	add_child(e)
	var y: float = terrain.height_at(pos) if terrain != null else pos.y
	e.global_position = Vector3(pos.x, y + 0.1, pos.z)
	e.home = e.global_position
	enemies.append(e)
	return e


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
