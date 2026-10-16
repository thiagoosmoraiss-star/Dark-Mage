class_name Shrine
extends Node3D
## Santuário (2–5 min): sala instanciada com um desafio e um altar de recompensa
## (Sigilo de Vida ou de Mana). Arquétipos: braseiros (Lança Arcana acende),
## provação (ondas de inimigos), abismo (plataformas: pulo, planador, blink) e
## runas ocultas (Corrente Etérea revela, disparo ativa).

signal completed(id: String)

enum Archetype { BRAZIERS, TRIAL, CHASM, RUNES }

const W: int = 6
const D: int = 8

var poi_id: String
var region: StringName
var archetype: Archetype
var done: bool = false
var _spawn: Transform3D
var _seal: Node3D
var _targets: Array[Node3D] = []
var _lit: Dictionary[int, bool] = {}
var _revealed: Dictionary[int, bool] = {}
var _wave: int = 0
var _wave_enemies: Array[Enemy] = []
var _altar: Interactable


static func build(parent: Node3D, origin: Vector3, id: String, reg: StringName, arch: int) -> Shrine:
	var s: Shrine = Shrine.new()
	s.name = "Shrine_" + id
	s.poi_id = id
	s.region = reg
	s.archetype = arch as Archetype
	parent.add_child(s)
	s.global_position = origin
	s._build()
	return s


func spawn_point() -> Transform3D:
	return _spawn


func _build() -> void:
	done = GameState.has_flag("shrine_done:" + poi_id)
	var depth: int = D + (2 if archetype == Archetype.CHASM else 0)
	var gaps: Array[Vector2i] = []
	if archetype == Archetype.CHASM:
		for j: int in range(2, depth - 2):
			for i: int in W:
				gaps.append(Vector2i(i, j))
	InteriorBuilder.room(self, global_position, W, depth, 2, [["s", W / 2]], gaps, true, StableHash.fnv1a_string(poi_id))
	var tile: float = InteriorBuilder.TILE
	_spawn = Transform3D(Basis(Vector3.UP, 0.0), global_position + Vector3(W * tile * 0.5, 0.3, depth * tile - 3.0))
	# Portal de saída ao lado da entrada.
	var exit: InteriorEntrance = InteriorEntrance.new()
	exit.kind = InteriorEntrance.Kind.EXIT
	add_child(exit)
	exit.global_position = global_position + Vector3(W * tile * 0.5 + 4.5, 0.0, depth * tile - 2.5)
	# Altar no fundo (norte).
	_altar = ShrineAltar.new()
	(_altar as ShrineAltar).shrine = self
	add_child(_altar)
	_altar.global_position = global_position + Vector3(W * tile * 0.5, 0.0, 3.5)
	if archetype != Archetype.CHASM:
		_seal = _make_seal(global_position + Vector3(W * tile * 0.5, 0.0, 7.5))
	match archetype:
		Archetype.BRAZIERS:
			_build_braziers()
		Archetype.TRIAL:
			pass
		Archetype.CHASM:
			_build_chasm(depth)
		Archetype.RUNES:
			_build_runes()
	if done:
		_open_seal(false)
	Events.spell_hit_world.connect(_on_spell_hit_world)


func on_enter(_player: Player) -> void:
	var panels: WorldPanels = get_tree().get_first_node_in_group(&"world_panels") as WorldPanels
	if panels != null and not done:
		panels.show_text(tr("SHRINE_TITLE_%d" % archetype), tr("SHRINE_HINT_%d" % archetype))
	if archetype == Archetype.TRIAL and not done and _wave == 0:
		_spawn_wave()


# --- Selo (barreira de energia) --------------------------------------------------

func _make_seal(pos: Vector3) -> Node3D:
	var root: StaticBody3D = StaticBody3D.new()
	add_child(root)
	root.global_position = pos
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(W * InteriorBuilder.TILE, 7.5)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = q
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.42, 0.18, 0.84, 0.35)
	m.emission_enabled = true
	m.emission = Color("6b2fd6")
	mi.material_override = m
	mi.position.y = 3.75
	root.add_child(mi)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = Vector3(W * InteriorBuilder.TILE, 8.0, 0.6)
	cs.shape = b
	cs.position.y = 4.0
	root.add_child(cs)
	return root


func _open_seal(announce: bool) -> void:
	if _seal != null and is_instance_valid(_seal):
		_seal.queue_free()
		_seal = null
	if announce:
		Audio.play(&"beacon", _altar.global_position, -4.0)
		var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
		if hud != null:
			hud.show_banner(tr("SHRINE_SOLVED"), "")


# --- Braseiros -------------------------------------------------------------------

func _build_braziers() -> void:
	var tile: float = InteriorBuilder.TILE
	var spots: Array[Vector3] = [Vector3(1.5, 0, 3.0), Vector3(W - 1.5, 0, 3.0), Vector3(1.5, 0, 5.5), Vector3(W - 1.5, 0, 5.5)]
	for i: int in spots.size():
		var b: StaticBody3D = StaticBody3D.new()
		b.name = "Brazier_%d" % i
		add_child(b)
		b.global_position = global_position + spots[i] * tile
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = StoneMesh.drum(0.55, 1.1, 3 + i, 10)
		mi.material_override = RuinBuilder.stone_material(0.2)
		mi.position.y = 0.55
		b.add_child(mi)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var cyl: CylinderShape3D = CylinderShape3D.new()
		cyl.radius = 0.6
		cyl.height = 1.3
		cs.shape = cyl
		cs.position.y = 0.65
		b.add_child(cs)
		var flame: GPUParticles3D = _flame(Color(0.75, 0.5, 1.0))
		flame.position.y = 1.2
		flame.emitting = done
		b.add_child(flame)
		b.set_meta(&"flame", flame)
		_targets.append(b)


func _flame(color: Color) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.8
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, 0.5, 0)
	pm.color = color
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = Vfx.ADDITIVE
	q.material = m
	p.draw_pass_1 = q
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.visible = false
	p.add_child(light)
	return p


## Lógica dos braseiros e das runas: chamada por qualquer feitiço que acerta o mundo.
func _on_spell_hit_world(spell_id: StringName, _element: int, pos: Vector3, collider: Node) -> void:
	if done:
		return
	for i: int in _targets.size():
		var t: Node3D = _targets[i]
		var hit_it: bool = collider == t or t.global_position.distance_to(pos) < 1.6
		match archetype:
			Archetype.BRAZIERS:
				if hit_it and spell_id == &"arcane_lance" and not _lit.has(i):
					register_brazier(i)
			Archetype.RUNES:
				if spell_id == &"ether_chain" and t.global_position.distance_to(pos) < 6.0 and not _revealed.has(i):
					_reveal_rune(i)
				elif hit_it and _revealed.has(i) and not _lit.has(i):
					_activate_rune(i)


func register_brazier(i: int) -> void:
	_lit[i] = true
	var flame: GPUParticles3D = _targets[i].get_meta(&"flame") as GPUParticles3D
	flame.emitting = true
	(flame.get_child(0) as OmniLight3D).visible = true
	Audio.play(&"fire", _targets[i].global_position)
	if _lit.size() == _targets.size():
		_complete()


# --- Provação ----------------------------------------------------------------------

func _spawn_wave() -> void:
	_wave += 1
	var layout: Array = IslandWorld.CAMP_LAYOUTS.get(region, IslandWorld.CAMP_LAYOUTS[&"valley"])
	_wave_enemies.clear()
	var tile: float = InteriorBuilder.TILE
	var k: int = 0
	for entry: Array in layout:
		var data: EnemyData = load("res://data/enemies/%s.tres" % str(entry[0])) as EnemyData
		if data.behavior == &"serpent" or data.behavior == &"golem" and _wave == 1:
			continue
		var p: Vector3 = global_position + Vector3((1.5 + (k % 4) * 1.0) * tile, 0.2, (2.5 + float(k) / 4.0) * tile)
		var e: Enemy = IslandWorld.spawn_into(self, data, p, _wave == 2 and k == 0)
		e.died.connect(_on_wave_enemy_died)
		_wave_enemies.append(e)
		k += 1


func _on_wave_enemy_died(_e: Enemy) -> void:
	for e: Enemy in _wave_enemies:
		if e.is_alive():
			return
	if _wave < 2:
		_spawn_wave.call_deferred()
	else:
		_complete()


# --- Abismo --------------------------------------------------------------------------

func _build_chasm(depth: int) -> void:
	var tile: float = InteriorBuilder.TILE
	var mat: ShaderMaterial = RuinBuilder.stone_material(0.3)
	var rng: RandomNumberGenerator = Rng.make_rng(Rng.WORLD_SEED, "chasm_" + poi_id)
	var z: float = (depth - 2.2) * tile
	var x: float = W * tile * 0.5
	var y: float = 0.0
	var body: StaticBody3D = StaticBody3D.new()
	add_child(body)
	body.global_position = global_position
	while z > 2.4 * tile:
		z -= rng.randf_range(5.0, 7.5)
		x = clampf(x + rng.randf_range(-5.0, 5.0), 3.0, W * tile - 3.0)
		y = clampf(y + rng.randf_range(-0.5, 1.2), 0.0, 3.5)
		var size: Vector3 = Vector3(rng.randf_range(2.6, 3.6), 1.0, rng.randf_range(2.6, 3.6))
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = StoneMesh.block(size, rng.randi_range(0, 5), 0.5, 5)
		mi.material_override = mat
		mi.position = Vector3(x, y - 0.5, z)
		body.add_child(mi)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var b: BoxShape3D = BoxShape3D.new()
		b.size = size
		cs.shape = b
		cs.position = mi.position
		body.add_child(cs)
	# Queda no abismo: volta ao início.
	var kill: Area3D = Area3D.new()
	kill.collision_mask = 2
	var ks: CollisionShape3D = CollisionShape3D.new()
	var kb: BoxShape3D = BoxShape3D.new()
	kb.size = Vector3(W * tile, 4.0, depth * tile)
	ks.shape = kb
	kill.add_child(ks)
	add_child(kill)
	kill.global_position = global_position + Vector3(W * tile * 0.5, -14.0, depth * tile * 0.5)
	kill.body_entered.connect(func(b2: Node3D) -> void:
		if b2 is Player:
			(b2 as Player).teleport(_spawn.origin))


# --- Runas ---------------------------------------------------------------------------

func _build_runes() -> void:
	var tile: float = InteriorBuilder.TILE
	var spots: Array[Vector3] = [Vector3(1.2, 0, 4.0), Vector3(W * 0.5, 0, 5.8), Vector3(W - 1.2, 0, 3.4)]
	for i: int in spots.size():
		var b: StaticBody3D = StaticBody3D.new()
		add_child(b)
		b.global_position = global_position + spots[i] * tile
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = StoneMesh.block(Vector3(0.9, 2.6, 0.9), 2 + i, 0.5, 5)
		mi.material_override = RuinBuilder.stone_material(0.3)
		mi.position.y = 1.3
		b.add_child(mi)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(0.9, 2.6, 0.9)
		cs.shape = box
		cs.position.y = 1.3
		b.add_child(cs)
		var rune: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.6, 0.6)
		rune.mesh = q
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_texture = LorePoint._rune_texture()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color("9fd8ff")
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = 3.0
		m.albedo_color = Color(1, 1, 1, 0.0)
		rune.material_override = m
		rune.position = Vector3(0, 1.8, 0.47)
		b.add_child(rune)
		b.set_meta(&"rune", m)
		_targets.append(b)


func _reveal_rune(i: int) -> void:
	_revealed[i] = true
	var m: StandardMaterial3D = _targets[i].get_meta(&"rune") as StandardMaterial3D
	m.albedo_color = Color(1, 1, 1, 0.8)
	Audio.play(&"lightning", _targets[i].global_position, -6.0)


func _activate_rune(i: int) -> void:
	_lit[i] = true
	var m: StandardMaterial3D = _targets[i].get_meta(&"rune") as StandardMaterial3D
	m.emission = Color("e8b44c")
	m.emission_energy_multiplier = 5.0
	Audio.play(&"impact_arcane", _targets[i].global_position)
	if _lit.size() == _targets.size():
		_complete()


func _complete() -> void:
	if done:
		return
	_open_seal(true)
	completed.emit(poi_id)


## Recompensa entregue pelo altar.
func claim_reward(player: Player) -> void:
	if done:
		return
	done = true
	GameState.set_flag("shrine_done:" + poi_id)
	var idx: int = WorldPois.by_kind(&"shrine").map(func(p: Dictionary) -> String: return String(p["id"] as StringName)).find(poi_id)
	var life: bool = idx % 2 == 0
	if life:
		GameState.sigils_health += 1
	else:
		GameState.sigils_mana += 1
	player.apply_progression()
	player.stats.set_health(player.stats.max_health)
	player.stats.set_mana(player.stats.max_mana)
	var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
	if hud != null:
		hud.show_banner(tr("SIGIL_LIFE") if life else tr("SIGIL_MANA"), tr("SIGIL_DESC_LIFE") if life else tr("SIGIL_DESC_MANA"))
	Audio.play(&"beacon", player.global_position)
