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
var panels: WorldPanels
var ambience: RegionAmbience
var interiors: InteriorManager
var citadel: Citadel
var _autosave_timer: float = 0.0
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
	panels = WorldPanels.new()
	panels.name = "WorldPanels"
	panels.add_to_group(&"world_panels")
	add_child(panels)
	panels.rest_requested.connect(_on_rest)
	panels.travel_requested.connect(_on_travel)
	if terrain != null:
		interiors = InteriorManager.new()
		interiors.name = "Interiors"
		interiors.world = self
		add_child(interiors)
		ambience = RegionAmbience.new()
		ambience.name = "RegionAmbience"
		ambience.atmosphere = atmosphere
		ambience.terrain = terrain
		add_child(ambience)
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
	player.apply_progression()
	GameState.leveled_up.connect(func(_lv: int) -> void:
		player.apply_progression()
		game_hud.show_banner(tr("LEVEL_UP"), tr("LEVEL_UP_DESC") % GameState.level, 3.0))
	Events.enemy_killed.connect(func(e: Node) -> void:
		var en: Enemy = e as Enemy
		if en != null and not en is Boss:
			GameState.add_xp(en.data.xp * (2 if en.elite else 1))
			GameState.add_souls(en.data.souls * (2 if en.elite else 1)))
	map_screen = MapScreen.new()
	map_screen.name = "MapScreen"
	map_screen.fog = fog
	map_screen.player = player
	add_child(map_screen)
	fog.reveal(player.global_position, 90.0)


func _build_structures() -> void:
	var story_i: int = 0
	for poi: Dictionary in WorldPois.all():
		var p2: Vector2 = WorldPois.pos2(poi)
		var pos: Vector3 = Vector3(p2.x, terrain.height_at(Vector3(p2.x, 0, p2.y)), p2.y)
		var id: StringName = poi["id"]
		var region: StringName = poi["region"]
		var rng: RandomNumberGenerator = Rng.make_rng(Rng.WORLD_SEED, "poi_" + String(id))
		match poi["kind"] as StringName:
			&"ruin":
				structures[id] = RuinBuilder.build_ruin(self, pos, StableHash.fnv1a_string(String(id)), terrain,
					GameState.corruption(region))
			&"beacon":
				var tower: StaticBody3D = RuinBuilder.build_beacon_tower(self, pos - Vector3.UP * 0.5, StableHash.fnv1a_string(String(id)) % 97)
				structures[id] = tower
				var beacon: Beacon = Beacon.new()
				beacon.poi_id = String(id)
				beacon.region = region
				beacon.name = "Beacon"
				tower.add_child(beacon)
				beacon.position = Vector3(0, JsonUtil.num(tower.get_meta(&"top_y")), 0)
			&"bonfire":
				var bf: Bonfire = Bonfire.new()
				bf.poi_id = String(id)
				bf.name = "Bonfire_" + String(id)
				add_child(bf)
				bf.global_position = pos
				structures[id] = bf
			&"chest":
				var ch: Chest = Chest.new()
				ch.poi_id = String(id)
				ch.region = region
				ch.gold = rng.randf() < 0.15
				add_child(ch)
				ch.global_position = pos
				ch.rotation.y = rng.randf() * TAU
				structures[id] = ch
			&"shrine", &"lair":
				var ent: InteriorEntrance = InteriorEntrance.new()
				ent.kind = InteriorEntrance.Kind.SHRINE if poi["kind"] == &"shrine" else InteriorEntrance.Kind.LAIR
				ent.poi_id = String(id)
				ent.region = region
				ent.archetype = WorldPois.by_kind(&"shrine").find(poi) % 4
				add_child(ent)
				ent.global_position = pos - Vector3.UP * 0.1
				ent.rotation.y = rng.randf() * TAU
				structures[id] = ent
			&"citadel":
				citadel = Citadel.new()
				citadel.name = "Citadel"
				citadel.terrain = terrain
				add_child(citadel)
				structures[id] = citadel
			&"viewpoint", &"story":
				var lp: LorePoint = LorePoint.new()
				lp.poi_id = String(id)
				lp.kind = LorePoint.Kind.VIEWPOINT if poi["kind"] == &"viewpoint" else LorePoint.Kind.STORY
				lp.story_index = story_i
				if lp.kind == LorePoint.Kind.STORY:
					story_i += 1
				add_child(lp)
				lp.global_position = pos
				lp.rotation.y = rng.randf() * TAU
				structures[id] = lp


## Composição dos acampamentos por região (roteiro 4.4).
const CAMP_LAYOUTS: Dictionary = {
	&"valley": [["mist_crawler", 0, 0], ["mist_crawler", 3, 2], ["mist_crawler", -3, 1.5], ["bone_archer", 10, -6], ["bone_archer", -11, -5]],
	&"forest": [["mist_crawler", 0, 0], ["mist_crawler", 3, 2], ["spectral_bat", 0, -4], ["spectral_bat", 4, -2], ["bone_archer", -10, -6]],
	&"peaks": [["stone_golem", 0, 0], ["bone_archer", 12, -6], ["spectral_bat", -6, 4]],
	&"burnt": [["stone_golem", 0, 0], ["mist_crawler", 5, 3], ["mist_crawler", -5, 2], ["bone_archer", 12, -8]],
	&"swamp": [["swamp_witch", 0, -6], ["mist_crawler", 2, 2], ["mist_crawler", -3, 2], ["spectral_bat", 0, 5], ["lake_serpent", 0, 0]],
	&"coast": [["mist_crawler", 0, 0], ["mist_crawler", 3, 1], ["bone_archer", -9, -5], ["lake_serpent", 0, 0]],
}


## Acampamentos: composição por região; serpentes vão para a água mais próxima.
func _spawn_camps() -> void:
	for poi: Dictionary in WorldPois.by_kind(&"camp"):
		var c: Vector2 = WorldPois.pos2(poi)
		var rng: RandomNumberGenerator = Rng.make_rng(Rng.WORLD_SEED, "camp_" + String(poi["id"] as StringName))
		var layout: Array = CAMP_LAYOUTS.get(poi["region"], CAMP_LAYOUTS[&"valley"])
		for entry: Array in layout:
			var data: EnemyData = load("res://data/enemies/%s.tres" % str(entry[0])) as EnemyData
			var p: Vector2 = c + Vector2(JsonUtil.num(entry[1]), JsonUtil.num(entry[2])) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			if data.behavior == &"serpent":
				var water: Vector2 = _find_water_near(c, 60.0)
				if water == Vector2.INF:
					continue
				var s: Enemy = spawn_enemy(data, Vector3(water.x, 0.0, water.y), false)
				s.global_position.y = -0.6
				s.home = s.global_position
				continue
			spawn_enemy(data, Vector3(p.x, 0.0, p.y), rng.randf() < 0.12)


func _find_water_near(c: Vector2, radius: float) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = INF
	var step: float = 6.0
	var n: int = int(radius / step)
	for j: int in range(-n, n + 1):
		for i: int in range(-n, n + 1):
			var p: Vector2 = c + Vector2(i, j) * step
			if terrain.height_at(Vector3(p.x, 0, p.y)) < -1.8:
				var d: float = p.distance_to(c)
				if d < best_d:
					best_d = d
					best = p
	return best


static func enemy_class(behavior: StringName) -> Enemy:
	match behavior:
		&"bat":
			return BatEnemy.new()
		&"golem":
			return GolemEnemy.new()
		&"witch":
			return WitchEnemy.new()
		&"serpent":
			return SerpentEnemy.new()
	return Enemy.new()


## Cria um inimigo filho de `parent` (interiores usam isto direto).
static func spawn_into(parent: Node3D, data: EnemyData, pos: Vector3, elite: bool = false) -> Enemy:
	var e: Enemy = enemy_class(data.behavior)
	e.data = data
	e.elite = elite
	parent.add_child(e)
	e.global_position = pos
	e.home = pos
	return e


func spawn_enemy(data: EnemyData, pos: Vector3, elite: bool = false) -> Enemy:
	var e: Enemy = enemy_class(data.behavior)
	e.data = data
	e.elite = elite
	add_child(e)
	var y: float = terrain.height_at(pos) if terrain != null else pos.y
	e.global_position = Vector3(pos.x, y + 0.1, pos.z)
	e.home = e.global_position
	enemies.append(e)
	return e


var _activation_timer: float = 0.0
const ENEMY_ACTIVE_RADIUS: float = 110.0


## Só os inimigos perto do jogador processam IA e são desenhados.
func _activate_enemies(delta: float) -> void:
	_activation_timer -= delta
	if _activation_timer > 0.0:
		return
	_activation_timer = 0.5
	var p: Vector3 = player.global_position
	for e: Enemy in enemies:
		if is_instance_valid(e):
			e.set_dormant(e.home.distance_to(p) > ENEMY_ACTIVE_RADIUS and e.global_position.distance_to(p) > ENEMY_ACTIVE_RADIUS)


## Fogueira: abre o menu de descanso/viagem.
func on_bonfire_rest(bf: Bonfire) -> void:
	panels.show_rest(bf.poi_id, Bonfire.display_name(bf.poi_id))


func _on_rest(_bonfire_id: String, hours: float) -> void:
	if atmosphere != null:
		atmosphere.set_hours(hours)
	revive_enemies()
	save_game(0)


func _on_travel(bonfire_id: String) -> void:
	var target: Node3D = structures.get(StringName(bonfire_id)) as Node3D
	if target == null or player == null:
		return
	if interiors != null:
		interiors.force_outdoor()
	player.teleport(target.global_position + target.global_basis.z * 2.0 + Vector3.UP * 0.3)
	player.respawn_point = player.global_position
	GameState.respawn_bonfire = bonfire_id
	if player.cam_rig != null:
		player.cam_rig.global_position = player.global_position + Vector3.UP * 1.5


func revive_enemies() -> void:
	for e: Enemy in enemies:
		if is_instance_valid(e) and not e.is_alive():
			e.revive()


# --- Save -----------------------------------------------------------------------

func save_game(slot: int) -> Error:
	if player == null:
		return ERR_UNCONFIGURED
	var data: Dictionary = SaveCodec.new_save()
	data["world_seed"] = Rng.world_seed
	data["play_time_s"] = GameState.play_time_s
	var pl: Dictionary = data["player"]
	var p: Vector3 = player.global_position
	pl["position"] = [p.x, p.y, p.z]
	pl["health"] = player.stats.health
	pl["mana"] = player.stats.mana
	pl["stamina"] = player.stats.stamina
	pl["stats"] = player.stats.to_dict()
	pl["equipped"] = Array(player.caster.equipped).map(func(x: StringName) -> String: return String(x))
	pl["unlocked"] = player.caster.unlocked.keys().map(func(x: StringName) -> String: return String(x))
	var w: Dictionary = data["world"]
	w["time_of_day_h"] = atmosphere.hours if atmosphere != null else 9.0
	w["flags"] = GameState.flags.duplicate()
	w["fog"] = fog.to_save()
	data["progress"] = GameState.to_dict()
	return SaveSystem.save_slot(slot, data)


func load_game(slot: int) -> bool:
	var data: Dictionary = SaveSystem.load_slot(slot)
	if data.is_empty() or player == null:
		return false
	if interiors != null:
		interiors.force_outdoor()
	var progress: Variant = data.get("progress", {})
	if progress is Dictionary:
		GameState.from_dict(progress as Dictionary)
	var pl: Dictionary = data["player"]
	player.teleport(JsonUtil.vec3(pl["position"]))
	var st: Variant = pl.get("stats", {})
	if st is Dictionary:
		player.stats.from_dict(st as Dictionary)
	var w: Dictionary = data["world"]
	if atmosphere != null:
		atmosphere.set_hours(JsonUtil.get_f(w, "time_of_day_h", 9.0))
	fog.from_save(JsonUtil.get_s(w, "fog"))
	player.apply_progression()
	var eq: Variant = pl.get("equipped", [])
	if eq is Array and (eq as Array).size() == 4:
		for i: int in 4:
			player.caster.equipped[i] = StringName(str((eq as Array)[i]))
	var un: Variant = pl.get("unlocked", [])
	if un is Array:
		for v: Variant in (un as Array):
			player.caster.unlocked[StringName(str(v))] = true
	return true


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_activate_enemies(delta)
	_autosave_timer += delta
	if _autosave_timer > 300.0 and player.state == Player.State.GROUND and not player.stats.in_combat:
		_autosave_timer = 0.0
		save_game(0)
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
