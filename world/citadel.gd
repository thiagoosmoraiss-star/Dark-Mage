class_name Citadel
extends Node3D
## Cidadela do Medo (platô no centro-norte): ruínas em anel, um trono e uma
## cúpula de névoa que só se abre com os 4 Guardiões vencidos. Dentro, o chefe
## final (3 fases). A vitória purifica a ilha inteira e mostra o epílogo.

const L = preload("res://world/island/island_layout.gd")
const ARENA_RADIUS: float = 24.0
const GUARDIANS: Array[StringName] = [&"forest", &"peaks", &"burnt", &"swamp"]

var terrain: IslandTerrain
var boss: Boss
var dome: StaticBody3D
var cleared: bool = false
var _center: Vector3
var _started: bool = false


func _ready() -> void:
	add_to_group(&"citadel")
	var c2: Vector2 = L.CITADEL_CENTER
	_center = Vector3(c2.x, terrain.height_at(Vector3(c2.x, 0, c2.y)) if terrain != null else L.CITADEL_TOP, c2.y)
	cleared = GameState.has_flag("final:fear")
	_build_ruins()
	_build_dome()
	_update_dome()
	GameState.changed.connect(func(_k: StringName) -> void: _update_dome())


static func guardians_defeated() -> int:
	var n: int = 0
	for r: StringName in GUARDIANS:
		if GameState.has_flag("guardian:" + String(r)):
			n += 1
	return n


func _build_ruins() -> void:
	var mat: ShaderMaterial = RuinBuilder.stone_material(0.2, 0.8)
	var body: StaticBody3D = StaticBody3D.new()
	body.add_to_group(&"structure")
	add_child(body)
	body.global_position = _center
	var rng: RandomNumberGenerator = Rng.make_rng(Rng.WORLD_SEED, "citadel")
	# Anel de torres partidas e muralhas.
	for i: int in 12:
		var a: float = TAU * i / 12.0
		var p: Vector3 = Vector3(cos(a), 0.0, sin(a)) * (ARENA_RADIUS + 6.0)
		var h: int = rng.randi_range(3, 9) if i % 3 != 0 else rng.randi_range(10, 16)
		for k: int in h:
			var b: MeshInstance3D = MeshInstance3D.new()
			b.mesh = StoneMesh.block(Vector3(3.0, 1.6, 3.0), k % 5, 0.6, 4)
			b.material_override = mat
			b.position = p + Vector3(rng.randf_range(-0.15, 0.15), 0.8 + k * 1.6, rng.randf_range(-0.15, 0.15))
			b.rotation.y = -a
			body.add_child(b)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(3.0, h * 1.6, 3.0)
		cs.shape = box
		cs.position = p + Vector3.UP * h * 0.8
		cs.rotation.y = -a
		body.add_child(cs)
	# Trono no norte da arena.
	var throne_pos: Vector3 = Vector3(0, 0, -ARENA_RADIUS + 3.0)
	for k: int in 3:
		var step: MeshInstance3D = MeshInstance3D.new()
		step.mesh = StoneMesh.block(Vector3(8.0 - k * 2.0, 0.6, 4.0 - k), 9 + k, 0.4, 5)
		step.material_override = mat
		step.position = throne_pos + Vector3(0, 0.3 + k * 0.6, 0)
		body.add_child(step)
	var back: MeshInstance3D = MeshInstance3D.new()
	back.mesh = StoneMesh.block(Vector3(3.0, 7.0, 1.0), 12, 0.5, 6)
	back.material_override = mat
	back.position = throne_pos + Vector3(0, 5.0, -1.2)
	body.add_child(back)
	var crystal: MeshInstance3D = MeshInstance3D.new()
	crystal.mesh = MageLook.crystal_mesh(0.8, 3.0, 7)
	crystal.material_override = MageLook.crystal_material()
	crystal.position = throne_pos + Vector3(0, 10.0, -1.2)
	body.add_child(crystal)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("b67cff")
	light.light_energy = 4.0
	light.omni_range = 30.0
	light.position = crystal.position
	body.add_child(light)


func _build_dome() -> void:
	dome = StaticBody3D.new()
	add_child(dome)
	dome.global_position = _center
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = ARENA_RADIUS + 10.0
	sm.height = sm.radius * 2.0
	sm.radial_segments = 48
	sm.rings = 24
	mi.mesh = sm
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = preload("res://shaders/barrier.gdshader")
	m.set_shader_parameter(&"color", Color("6b2fd6"))
	m.set_shader_parameter(&"strength", 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.add_child(mi)
	# Colisão em anel (cilindros) que impede a entrada.
	for i: int in 24:
		var a: float = TAU * i / 24.0
		var cs: CollisionShape3D = CollisionShape3D.new()
		var cyl: CylinderShape3D = CylinderShape3D.new()
		cyl.radius = 4.6
		cyl.height = 60.0
		cs.shape = cyl
		cs.position = Vector3(cos(a), 0.0, sin(a)) * (ARENA_RADIUS + 10.0) + Vector3.UP * 20.0
		dome.add_child(cs)


func _update_dome() -> void:
	if dome == null:
		return
	var open: bool = guardians_defeated() >= GUARDIANS.size() or cleared
	dome.visible = not open
	dome.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	for c: Node in dome.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = open


func _process(_delta: float) -> void:
	if cleared or _started:
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null or guardians_defeated() < GUARDIANS.size():
		return
	if Vector2(player.global_position.x - _center.x, player.global_position.z - _center.z).length() < ARENA_RADIUS:
		start_final_battle()


func start_final_battle() -> void:
	_started = true
	var data: BossData = load("res://data/bosses/fear.tres") as BossData
	boss = Boss.new()
	boss.boss = data
	add_child(boss)
	boss.global_position = _center + Vector3(0, 1.0, -ARENA_RADIUS + 6.0)
	boss.home = boss.global_position
	boss.arena_center = _center
	boss.arena_radius = ARENA_RADIUS - 2.0
	boss.defeated.connect(_on_victory)
	var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
	if hud != null:
		hud.show_banner(tr(data.name_key), tr(data.title_key), 5.0)
		hud.set_boss(boss)
		hud.show_subtitle(tr(data.intro_key), 6.0)
	Audio.play(&"boom", _center)


func _on_victory(_b: Boss) -> void:
	cleared = true
	GameState.set_flag("final:fear")
	for r: StringName in GameState.BASE_CORRUPTION.keys():
		GameState.purify(r, 1.0)
	GameState.add_xp(1000)
	var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
	if hud != null:
		hud.set_boss(null)
		hud.show_subtitle(tr(boss.boss.defeat_key), 6.0)
	_update_dome()
	_epilogue.call_deferred()


## Epílogo visual: o dia nasce dourado sobre a ilha purificada e o texto final aparece.
func _epilogue() -> void:
	await get_tree().create_timer(4.0).timeout
	var atmo: Atmosphere = get_tree().get_first_node_in_group(&"atmosphere") as Atmosphere
	if atmo != null:
		var tw: Tween = create_tween()
		tw.tween_method(atmo.set_hours, atmo.hours, atmo.hours + fposmod(7.0 - atmo.hours, 24.0), 6.0)
		atmo.corruption = 0.0
		atmo.set_grading(&"purified")
	await get_tree().create_timer(6.5).timeout
	var panels: WorldPanels = get_tree().get_first_node_in_group(&"world_panels") as WorldPanels
	if panels != null:
		panels.show_text(tr("EPILOGUE_TITLE"), tr("EPILOGUE_BODY"))
	var world: IslandWorld = get_tree().get_first_node_in_group(&"world") as IslandWorld
	if world != null:
		world.save_game(Game.current_slot)
