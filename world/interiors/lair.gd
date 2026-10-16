class_name Lair
extends Node3D
## Covil do Guardião: corredor com inimigos da região e a arena do chefe. Vencer
## o Guardião purifica a região, concede um feitiço e abre o portal de saída.

const ARENA_W: int = 9
const ARENA_D: int = 9

var poi_id: String
var region: StringName
var boss: Boss
var cleared: bool = false
var _spawn: Transform3D
var _arena_center: Vector3
var _intro_done: bool = false


static func boss_for(reg: StringName) -> BossData:
	return load("res://data/bosses/guardian_%s.tres" % String(reg)) as BossData


static func build(parent: Node3D, origin: Vector3, id: String, reg: StringName) -> Lair:
	var l: Lair = Lair.new()
	l.name = "Lair_" + id
	l.poi_id = id
	l.region = reg
	parent.add_child(l)
	l.global_position = origin
	l._build()
	return l


func spawn_point() -> Transform3D:
	return _spawn


func _build() -> void:
	cleared = GameState.has_flag("guardian:" + String(region))
	var tile: float = InteriorBuilder.TILE
	var seed_value: int = StableHash.fnv1a_string(poi_id)
	# Corredor 4×6 (entrada ao sul, porta ao norte para a arena).
	var corridor_origin: Vector3 = global_position + Vector3((ARENA_W - 4) * 0.5 * tile, 0, ARENA_D * tile)
	InteriorBuilder.room(self, corridor_origin, 4, 6, 2, [["s", 2], ["n", 2]], [], true, seed_value)
	_spawn = Transform3D(Basis.IDENTITY, corridor_origin + Vector3(2.0 * tile, 0.3, 6 * tile - 3.0))
	var exit_back: InteriorEntrance = InteriorEntrance.new()
	exit_back.kind = InteriorEntrance.Kind.EXIT
	add_child(exit_back)
	exit_back.global_position = corridor_origin + Vector3(2.0 * tile + 4.0, 0.0, 6 * tile - 2.5)
	# Arena 9×9 com pé-direito triplo, sem parede sul (o corredor fecha o lado).
	var gaps: Array[Vector2i] = []
	if region == &"swamp":
		for j: int in range(3, 6):
			for i: int in range(3, 6):
				gaps.append(Vector2i(i, j))
	InteriorBuilder.room(self, global_position, ARENA_W, ARENA_D, 3, [], gaps, true, seed_value + 1, ["s"])
	_arena_center = global_position + Vector3(ARENA_W * 0.5 * tile, 0.0, ARENA_D * 0.5 * tile)
	if region == &"swamp":
		_build_pool()
	_build_arena_lights()
	# Inimigos do corredor.
	if not cleared:
		var layout: Array = IslandWorld.CAMP_LAYOUTS.get(region, IslandWorld.CAMP_LAYOUTS[&"valley"])
		var k: int = 0
		for entry: Array in layout:
			var data: EnemyData = load("res://data/enemies/%s.tres" % str(entry[0])) as EnemyData
			if data.behavior == &"serpent" or data.behavior == &"golem" or k >= 3:
				continue
			var p: Vector3 = corridor_origin + Vector3((1.0 + k) * tile, 0.2, 2.0 * tile)
			IslandWorld.spawn_into(self, data, p)
			k += 1
	if not cleared:
		_spawn_boss()
	else:
		_open_exit()


## Quatro braseiros com cristais na cor do Guardião iluminam a arena.
func _build_arena_lights() -> void:
	var data: BossData = boss_for(region)
	var col: Color = data.eye_color if data != null else Color("b67cff")
	for i: int in 4:
		var a: float = TAU * (i + 0.5) / 4.0
		var p: Vector3 = _arena_center + Vector3(cos(a), 0.0, sin(a)) * 11.0
		var base: MeshInstance3D = MeshInstance3D.new()
		base.mesh = StoneMesh.drum(0.9, 1.4, 20 + i, 12)
		base.material_override = RuinBuilder.stone_material(0.1, 0.5)
		add_child(base)
		base.global_position = p + Vector3.UP * 0.7
		var c: MeshInstance3D = MeshInstance3D.new()
		c.mesh = MageLook.crystal_mesh(0.35, 1.2, 6)
		var cm: StandardMaterial3D = MageLook.crystal_material().duplicate() as StandardMaterial3D
		cm.emission = col
		cm.albedo_color = col
		c.material_override = cm
		add_child(c)
		c.global_position = p + Vector3.UP * 2.2
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = col
		l.light_energy = 2.2
		l.omni_range = 17.0
		l.shadow_enabled = false
		add_child(l)
		l.global_position = p + Vector3.UP * 3.0


func _build_pool() -> void:
	var tile: float = InteriorBuilder.TILE
	var body: StaticBody3D = StaticBody3D.new()
	add_child(body)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = Vector3(3 * tile, 1.0, 3 * tile)
	cs.shape = b
	body.add_child(cs)
	body.global_position = _arena_center + Vector3(0, -3.5, 0)
	var water: WaterBody = WaterBody.new()
	water.size = Vector2(3 * tile, 3 * tile)
	water.depth = 3.0
	add_child(water)
	water.global_position = _arena_center + Vector3(0, -0.6, 0)
	var mat: ShaderMaterial = water.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"corruption", 1.0)


func _spawn_boss() -> void:
	var data: BossData = boss_for(region)
	if data == null:
		return
	boss = Boss.new()
	boss.boss = data
	add_child(boss)
	var y: float = -0.8 if data.body == &"serpent" else 0.2
	boss.global_position = _arena_center + Vector3(0, y, -2.0 if data.body != &"serpent" else 0.0)
	boss.home = boss.global_position
	boss.arena_center = _arena_center
	boss.arena_radius = ARENA_W * InteriorBuilder.TILE * 0.5 - 3.0
	boss.look_at(_arena_center + Vector3(0, y, 20.0), Vector3.UP)
	boss.defeated.connect(_on_boss_defeated)


func _process(_delta: float) -> void:
	if _intro_done or boss == null or cleared:
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.global_position.distance_to(_arena_center) < ARENA_W * InteriorBuilder.TILE * 0.5:
		_intro_done = true
		var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
		if hud != null:
			hud.show_banner(tr(boss.boss.name_key), tr(boss.boss.title_key), 4.0)
			hud.set_boss(boss)
			hud.show_subtitle(tr(boss.boss.intro_key), 5.0)
		Audio.play(&"boom", _arena_center, -6.0)


func _on_boss_defeated(_b: Boss) -> void:
	cleared = true
	GameState.set_flag("guardian:" + String(region))
	GameState.purify(region, 1.0)
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null and boss.boss.reward_spell != &"":
		player.caster.unlock(boss.boss.reward_spell)
		var sp: SpellData = Spells.get_spell(boss.boss.reward_spell)
		var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
		if hud != null:
			hud.set_boss(null)
			hud.show_subtitle(tr(boss.boss.defeat_key), 5.0)
			hud.show_banner(tr("GUARDIAN_DEFEATED"), tr("SPELL_LEARNED") % tr(sp.name_key) if sp != null else "", 5.0)
	GameState.add_xp(300)
	GameState.add_souls(400)
	Audio.play(&"beacon", _arena_center)
	_open_exit()


func _open_exit() -> void:
	var exit: InteriorEntrance = InteriorEntrance.new()
	exit.kind = InteriorEntrance.Kind.EXIT
	add_child(exit)
	exit.global_position = _arena_center + Vector3(0, 0, 6.0)
