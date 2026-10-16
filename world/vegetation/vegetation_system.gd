class_name VegetationSystem
extends Node3D
## Árvores e rochas da ilha. A distribuição é determinística (seed do mundo) e
## segue regras de bioma: região, altura, inclinação e clareiras ao redor dos
## pontos de interesse. Renderização por células de MultiMesh com 3 níveis
## (LOD0, LOD1, impostor) e fade por dither nas visibility ranges.
## A colisão (troncos e rochas grandes) só existe perto do jogador.

const L = preload("res://world/island/island_layout.gd")
const CELL: float = 64.0
const IMPOSTOR_CELL: float = 256.0
const VARIANTS: int = 3
const ROCK_VARIANTS: int = 6
const COLLISION_RADIUS: float = 90.0

## Faixas de visibilidade (m).
const LOD0_END: float = 95.0
const LOD1_END: float = 340.0
const IMPOSTOR_END: float = 1700.0
const ROCK_LOD1_END: float = 650.0

enum Kind { OAK, GIANT, PINE, DEAD, ROCK }

class Instance:
	var kind: int
	var variant: int
	var xform: Transform3D
	var radius: float  # raio de colisão (0 = sem colisão)
	var height: float

var terrain: IslandTerrain
var instances: Array[Instance] = []
## Clareiras: Vector3(x, raio, z).
var clearings: Array[Vector3] = []

var _tree_meshes: Dictionary = {}  # "kind_variant" -> TreeMesh.build()
var _rock_meshes: Array[Dictionary] = []
var _cells: Dictionary[Vector2i, Array] = {}  # célula -> índices de instances
var _collision_cells: Dictionary[Vector2i, Node3D] = {}
var _region_map: Image
var _built: bool = false
var _preset: Dictionary = GraphicsPresets.get_preset(GraphicsPresets.HIGH)
## [MultiMeshInstance3D, nível (0 = LOD0, 1 = LOD1, 2 = impostor, 3 = rocha perto, 4 = rocha longe)]
var _lod_nodes: Array[Array] = []


func _ready() -> void:
	add_to_group(&"vegetation")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if terrain == null:
		terrain = get_tree().get_first_node_in_group(&"island_terrain") as IslandTerrain
	clearings.append(Vector3(L.CITADEL_CENTER.x, L.CITADEL_RADIUS + 10.0, L.CITADEL_CENTER.y))
	clearings.append(Vector3(IslandWorld.SPAWN.x, 14.0, IslandWorld.SPAWN.y))
	for poi: Dictionary in WorldPois.all():
		var r: float = JsonUtil.get_f(poi, "radius")
		if r > 0.0:
			clearings.append(Vector3(JsonUtil.get_f(poi, "x"), r, JsonUtil.get_f(poi, "z")))
	_preset = GraphicsPresets.get_preset(Settings.current_preset())
	Events.graphics_preset_changed.connect(_on_preset)
	if terrain != null:
		generate()
		build_render()


func _on_preset(p: String) -> void:
	_preset = GraphicsPresets.get_preset(StringName(p))
	for entry: Array in _lod_nodes:
		_apply_range(entry[0] as MultiMeshInstance3D, entry[1] as int)


func add_clearing(pos: Vector3, radius: float) -> void:
	clearings.append(Vector3(pos.x, radius, pos.z))


# --- Distribuição -----------------------------------------------------------------

func generate() -> void:
	instances.clear()
	_cells.clear()
	var data: Terrain3DData = terrain.terrain.data
	var path: String = IslandTerrain.REGION_MAP_PATH
	_region_map = (load(path) as Texture2D).get_image() if ResourceLoader.exists(path) else null
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = StableHash.derive_seed(Rng.WORLD_SEED, "vegetation")
	var grove: FastNoiseLite = FastNoiseLite.new()
	grove.seed = rng.seed & 0xFFFF
	grove.frequency = 0.012
	var step: float = 5.0
	var occupied: Dictionary[Vector2i, bool] = {}
	var n: int = int(L.WORLD_SIZE / step)
	for gz: int in n:
		for gx: int in n:
			var x: float = -L.HALF + (gx + rng.randf()) * step
			var z: float = -L.HALF + (gz + rng.randf()) * step
			var roll: float = rng.randf()
			var roll2: float = rng.randf()
			var p: Vector3 = Vector3(x, 0.0, z)
			var h: float = data.get_height(p)
			if is_nan(h) or h < -0.6:
				continue
			if _in_clearing(x, z):
				continue
			var region: int = _region_at(x, z)
			var nrm: Vector3 = data.get_normal(p)
			var g: float = grove.get_noise_2d(x, z) * 0.5 + 0.5
			var pick: Array = _choose(region, h, nrm.y, g, roll, roll2)
			if pick.is_empty():
				continue
			var kind: int = pick[0]
			var spacing: float = pick[1]
			var key: Vector2i = Vector2i(floori(x / spacing), floori(z / spacing))
			if occupied.has(key) or occupied.has(key + Vector2i(1, 0)) or occupied.has(key + Vector2i(0, 1)):
				continue
			occupied[key] = true
			_add(kind, p, h, nrm, rng)


func _choose(region: int, h: float, ny: float, grove: float, roll: float, roll2: float) -> Array:
	# Rochas: em todo lugar, mais nas encostas, nos picos e nas terras calcinadas.
	var rock_p: float = 0.004 + (1.0 - ny) * 0.08
	if region == L.Region.PEAKS or region == L.Region.BURNT:
		rock_p += 0.02
	if roll2 < rock_p:
		return [Kind.ROCK, 6.0]
	if ny < 0.8 or h < 0.8 and region != L.Region.SWAMP:
		return []
	match region:
		L.Region.VALLEY:
			if roll < 0.06 * smoothstep(0.55, 0.8, grove):
				return [Kind.OAK, 9.0]
		L.Region.FOREST:
			if roll < 0.12:
				return [Kind.GIANT, 15.0]
			if roll < 0.2 + 0.1 * grove:
				return [Kind.OAK, 8.0]
		L.Region.PEAKS:
			if h < 150.0 and roll < 0.16 * smoothstep(150.0, 90.0, h) + 0.02:
				return [Kind.PINE, 7.0]
		L.Region.BURNT:
			if roll < 0.025:
				return [Kind.DEAD, 12.0]
		L.Region.SWAMP:
			if roll < 0.07:
				return [Kind.DEAD, 9.0]
		L.Region.COAST:
			if roll < 0.01 and h > 2.5:
				return [Kind.OAK, 12.0]
	return []


func _add(kind: int, p: Vector3, h: float, nrm: Vector3, rng: RandomNumberGenerator) -> void:
	var inst: Instance = Instance.new()
	inst.kind = kind
	inst.variant = rng.randi_range(0, (ROCK_VARIANTS if kind == Kind.ROCK else VARIANTS) - 1)
	var s: float = rng.randf_range(0.8, 1.2)
	var b: Basis = Basis(Vector3.UP, rng.randf() * TAU)
	if kind == Kind.ROCK:
		s = minf(rng.randf_range(0.6, 1.4) * (1.0 + (1.0 - nrm.y) * 0.8), 2.4)
		b = Basis(Quaternion(Vector3.UP, nrm)) * b
		b = b.scaled(Vector3(s, s * rng.randf_range(0.7, 1.1), s))
		inst.radius = 1.0 * s if s > 0.9 else 0.0
		inst.height = 1.4 * s
		p.y = h - 0.25 * s
	else:
		if kind == Kind.DEAD:
			b = Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.12)) * b
		b = b.scaled(Vector3(s, s, s))
		var tm: Dictionary = _tree_mesh(kind, inst.variant)
		inst.radius = JsonUtil.get_f(tm, "trunk_radius") * s
		inst.height = JsonUtil.get_f(tm, "height") * s
		p.y = h - 0.15
	inst.xform = Transform3D(b, p)
	instances.append(inst)
	var cell: Vector2i = Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	if not _cells.has(cell):
		_cells[cell] = []
	_cells[cell].append(instances.size() - 1)


func _in_clearing(x: float, z: float) -> bool:
	for c: Vector3 in clearings:
		if Vector2(x - c.x, z - c.z).length() < c.y:
			return true
	return false


func _region_at(x: float, z: float) -> int:
	if _region_map == null:
		return L.Region.VALLEY
	var n: int = _region_map.get_width()
	var px: int = clampi(floori((x + L.HALF) / L.WORLD_SIZE * n), 0, n - 1)
	var pz: int = clampi(floori((z + L.HALF) / L.WORLD_SIZE * n), 0, n - 1)
	return roundi(_region_map.get_pixel(px, pz).r * 255.0)


# --- Malhas -------------------------------------------------------------------------

func _tree_mesh(kind: int, variant: int) -> Dictionary:
	var key: String = "%d_%d" % [kind, variant]
	if not _tree_meshes.has(key):
		_tree_meshes[key] = TreeMesh.build(kind as TreeMesh.Species, variant)
	return _tree_meshes[key]


func _rock_mesh(variant: int) -> Dictionary:
	while _rock_meshes.size() <= variant:
		var v: int = _rock_meshes.size()
		var size: Vector3 = Vector3(2.2, 1.5, 1.9) if v % 2 == 0 else Vector3(1.8, 1.9, 1.6)
		var lod0: ArrayMesh = RockMesh.build(700 + v, size, 3, 0.34)
		var lod1: ArrayMesh = RockMesh.build(700 + v, size, 2, 0.34)
		_rock_meshes.append({"lod0": lod0, "lod1": lod1})
	return _rock_meshes[variant]


# --- Renderização -------------------------------------------------------------------

func build_render() -> void:
	for child: Node in get_children():
		child.queue_free()
	# Agrupa por célula/tipo/variante.
	var groups: Dictionary = {}       # "cx_cz_kind_var" -> Array[Transform3D]
	var imp_groups: Dictionary = {}   # "ix_iz_kind" -> Array[Transform3D]
	var corrupt_tint: Dictionary = {}
	for i: int in instances.size():
		var inst: Instance = instances[i]
		var c: Vector2i = Vector2i(floori(inst.xform.origin.x / CELL), floori(inst.xform.origin.z / CELL))
		var gk: String = "%d_%d_%d_%d" % [c.x, c.y, inst.kind, inst.variant]
		if not groups.has(gk):
			groups[gk] = []
		(groups[gk] as Array).append(inst.xform)
		if inst.kind != Kind.ROCK:
			var ic: Vector2i = Vector2i(floori(inst.xform.origin.x / IMPOSTOR_CELL), floori(inst.xform.origin.z / IMPOSTOR_CELL))
			var ik: String = "%d_%d_%d" % [ic.x, ic.y, inst.kind]
			if not imp_groups.has(ik):
				imp_groups[ik] = []
			(imp_groups[ik] as Array).append(inst.xform)
	for gk: String in groups:
		var parts: PackedStringArray = gk.split("_")
		var kind: int = parts[2].to_int()
		var variant: int = parts[3].to_int()
		var xforms: Array = groups[gk]
		if kind == Kind.ROCK:
			var rm: Dictionary = _rock_mesh(variant)
			var rock_mat: Material = Materials.rock(0.5 if _region_for_xforms(xforms) != L.Region.BURNT else 0.1,
				0.6 if _region_for_xforms(xforms) == L.Region.SWAMP else 0.0)
			_add_mmi(rm["lod0"] as Mesh, xforms, 3, rock_mat)
			_add_mmi(rm["lod1"] as Mesh, xforms, 4, rock_mat)
		else:
			var tm: Dictionary = _tree_mesh(kind, variant)
			_add_mmi(tm["lod0"] as Mesh, xforms, 0, null)
			_add_mmi(tm["lod1"] as Mesh, xforms, 1, null)
	for ik: String in imp_groups:
		var kind: int = ik.split("_")[2].to_int()
		var tm: Dictionary = _tree_mesh(kind, 0)
		_add_mmi(tm["impostor"] as Mesh, imp_groups[ik] as Array, 2, null)
	_built = true


func _region_for_xforms(xforms: Array) -> int:
	var t: Transform3D = xforms[0]
	return _region_at(t.origin.x, t.origin.z)


func _add_mmi(mesh: Mesh, xforms: Array, level: int, mat: Material) -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i] as Transform3D)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if mat != null:
		mmi.material_override = mat
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	_lod_nodes.append([mmi, level])
	_apply_range(mmi, level)


## Faixas de visibilidade e sombra por nível, conforme o preset.
func _apply_range(mmi: MultiMeshInstance3D, level: int) -> void:
	var lod0: float = JsonUtil.get_f(_preset, "veg_lod0_end", LOD0_END)
	var lod1: float = JsonUtil.get_f(_preset, "veg_lod1_end", LOD1_END)
	var imp: float = JsonUtil.get_f(_preset, "veg_impostor_end", IMPOSTOR_END)
	var rock_far: float = JsonUtil.get_f(_preset, "rock_far_end", ROCK_LOD1_END)
	var ranges: Array[Vector2] = [Vector2(0.0, lod0), Vector2(lod0 - 10.0, lod1), Vector2(lod1 - 25.0, imp),
		Vector2(0.0, 110.0), Vector2(100.0, rock_far)]
	var r: Vector2 = ranges[level]
	mmi.visibility_range_begin = r.x
	mmi.visibility_range_begin_margin = 10.0 if r.x > 0.0 else 0.0
	mmi.visibility_range_end = r.y
	mmi.visibility_range_end_margin = 12.0
	var shadows: bool = level == 0 or level == 3 or (level == 1 and _preset.get("tree_shadows_lod1", true) == true) or level == 4
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Colisão perto do jogador ---------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if not _built:
		return
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var p: Vector3 = player.global_position
	var center: Vector2i = Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	var reach: int = ceili(COLLISION_RADIUS / CELL)
	for key: Vector2i in _collision_cells.keys():
		if absi(key.x - center.x) > reach + 1 or absi(key.y - center.y) > reach + 1:
			_collision_cells[key].queue_free()
			_collision_cells.erase(key)
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var key: Vector2i = center + Vector2i(dx, dz)
			if not _collision_cells.has(key):
				_collision_cells[key] = _build_collision(key)


func _build_collision(key: Vector2i) -> Node3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	if not _cells.has(key):
		return body
	for idx: int in _cells[key]:
		var inst: Instance = instances[idx]
		if inst.radius <= 0.0:
			continue
		var shape: CollisionShape3D = CollisionShape3D.new()
		if inst.kind == Kind.ROCK:
			var sph: SphereShape3D = SphereShape3D.new()
			sph.radius = inst.radius
			shape.shape = sph
			shape.position = inst.xform.origin + Vector3.UP * inst.radius * 0.45
		else:
			var cap: CapsuleShape3D = CapsuleShape3D.new()
			cap.radius = maxf(inst.radius, 0.2)
			cap.height = maxf(inst.height * 0.5, cap.radius * 2.0 + 0.1)
			shape.shape = cap
			shape.position = inst.xform.origin + Vector3.UP * cap.height * 0.5
		body.add_child(shape)
	return body


func count_by_kind() -> Dictionary:
	var out: Dictionary = {}
	for inst: Instance in instances:
		out[inst.kind] = JsonUtil.get_i(out, inst.kind) + 1
	return out
