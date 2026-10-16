class_name GrassField
extends Node3D
## Grama em chunks de MultiMesh ao redor da câmera. Cada chunk é gerado de forma
## determinística (seed pela coordenada) a partir do terreno: altura, normal,
## material do mapa de controle e cor. Chunks fora do alcance voltam ao pool.

const GRASS_SHADER: Shader = preload("res://shaders/grass.gdshader")
const CHUNK: float = 12.0
const L = preload("res://world/island/island_layout.gd")

## Densidade de tufos por m² no preset Alto (multiplicada pelo preset).
@export var base_density: float = 5.0
@export var radius: float = 46.0
@export var chunks_per_frame: int = 3

## Peso da grama por material do terreno (índices de IslandLayout.Mat).
const MAT_DENSITY: Array[float] = [1.0, 0.75, 0.3, 0.0, 0.05, 0.0, 0.35, 0.0]
const MAT_TINT: Array[Color] = [
	Color(0.86, 0.9, 0.55), Color(0.62, 0.78, 0.42), Color(0.6, 0.62, 0.38), Color(0.6, 0.6, 0.5),
	Color(0.9, 0.85, 0.6), Color(0.8, 0.85, 0.9), Color(0.45, 0.3, 0.55), Color(0.5, 0.35, 0.3),
]

var terrain: IslandTerrain
var _material: ShaderMaterial
var _mesh: ArrayMesh
var _active: Dictionary[Vector2i, MultiMeshInstance3D] = {}
var _pool: Array[MultiMeshInstance3D] = []
var _density_scale: float = 0.8


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_mesh = GrassMesh.build()
	_material = ShaderMaterial.new()
	_material.shader = GRASS_SHADER
	var n: FastNoiseLite = FastNoiseLite.new()
	n.frequency = 0.03
	var nt: NoiseTexture2D = NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.noise = n
	_material.set_shader_parameter(&"wind_noise", nt)
	_material.set_shader_parameter(&"fade_start", radius - 14.0)
	_material.set_shader_parameter(&"fade_end", radius - 2.0)
	Events.graphics_preset_changed.connect(_on_preset)
	_on_preset(String(Settings.current_preset()))
	if terrain == null:
		terrain = get_tree().get_first_node_in_group(&"island_terrain") as IslandTerrain


func _on_preset(p: String) -> void:
	_density_scale = JsonUtil.get_f(GraphicsPresets.get_preset(StringName(p)), "vegetation_density", 0.8)
	for key: Vector2i in _active.keys():
		_release(key)


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or terrain == null:
		return
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	RenderingServer.global_shader_parameter_set(&"player_position",
		player.global_position if player != null else Vector3(0, -1000, 0))
	var c: Vector3 = cam.global_position
	var r: float = radius
	var cmin: Vector2i = Vector2i(floori((c.x - r) / CHUNK), floori((c.z - r) / CHUNK))
	var cmax: Vector2i = Vector2i(floori((c.x + r) / CHUNK), floori((c.z + r) / CHUNK))
	# Libera os que saíram do alcance.
	for key: Vector2i in _active.keys():
		if _chunk_dist(key, c) > r + CHUNK:
			_release(key)
	# Cria os mais próximos primeiro, respeitando o orçamento por frame.
	var wanted: Array[Vector2i] = []
	for z: int in range(cmin.y, cmax.y + 1):
		for x: int in range(cmin.x, cmax.x + 1):
			var k: Vector2i = Vector2i(x, z)
			if not _active.has(k) and _chunk_dist(k, c) <= r:
				wanted.append(k)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _chunk_dist(a, c) < _chunk_dist(b, c))
	for i: int in mini(chunks_per_frame, wanted.size()):
		_build(wanted[i])


func _chunk_dist(k: Vector2i, c: Vector3) -> float:
	var center: Vector2 = Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK)
	return center.distance_to(Vector2(c.x, c.z))


func _release(key: Vector2i) -> void:
	var mmi: MultiMeshInstance3D = _active[key]
	_active.erase(key)
	mmi.visible = false
	_pool.append(mmi)


func _build(key: Vector2i) -> void:
	var mmi: MultiMeshInstance3D
	if _pool.is_empty():
		mmi = MultiMeshInstance3D.new()
		mmi.material_override = _material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _mesh
		mmi.multimesh = mm
		add_child(mmi)
	else:
		mmi = _pool.pop_back()
	mmi.visible = true
	_active[key] = mmi
	fill_chunk(mmi.multimesh, key)


## Preenche o MultiMesh do chunk (público para testes).
func fill_chunk(mm: MultiMesh, key: Vector2i) -> int:
	var data: Terrain3DData = terrain.terrain.data
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = StableHash.derive_seed(Rng.WORLD_SEED, "grass_%d_%d" % [key.x, key.y])
	var attempts: int = roundi(CHUNK * CHUNK * base_density * _density_scale)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i: int in attempts:
		var p: Vector3 = Vector3((key.x + rng.randf()) * CHUNK, 0.0, (key.y + rng.randf()) * CHUNK)
		var keep: float = rng.randf()
		var h: float = data.get_height(p)
		if is_nan(h) or h < L.SEA_LEVEL + 0.6:
			continue
		var nrm: Vector3 = data.get_normal(p)
		if nrm.y < 0.82:
			continue
		var base_id: int = data.get_control_base_id(p)
		var over_id: int = data.get_control_overlay_id(p)
		var blend: float = data.get_control_blend(p)
		var dens: float = lerpf(MAT_DENSITY[base_id % 8], MAT_DENSITY[over_id % 8], blend)
		if keep > dens:
			continue
		p.y = h - 0.03
		var s: float = rng.randf_range(0.75, 1.3) * lerpf(0.7, 1.0, dens)
		var b: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.25), s))
		# Inclina levemente com o terreno.
		b = Basis(Quaternion(Vector3.UP, nrm.slerp(Vector3.UP, 0.5))) * b
		xforms.append(Transform3D(b, p))
		var tint: Color = MAT_TINT[base_id % 8].lerp(MAT_TINT[over_id % 8], blend)
		var cmap: Color = data.get_color(p)
		var v: float = rng.randf_range(0.85, 1.1)
		# Mistura de touceiras verdes e douradas (campos do Vale).
		var gold: float = rng.randf() * 0.5
		tint = tint.lerp(Color(1.0, 0.86, 0.5), gold * float(base_id == 0))
		colors.append(Color(tint.r * cmap.r * v, tint.g * cmap.g * v, tint.b * cmap.b * v))
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_custom_data(i, colors[i])
	return xforms.size()


func active_chunk_count() -> int:
	return _active.size()
