class_name Ocean
extends MeshInstance3D
## Mar ao redor da ilha. Malha polar centrada na câmera (anéis mais densos perto
## dela), reposicionada a cada frame em passos fixos; as ondas são calculadas em
## coordenadas de mundo, então não "andam" com a malha.

const WATER_SHADER: Shader = preload("res://shaders/water.gdshader")
const WATER_SIMPLE_SHADER: Shader = preload("res://shaders/water_simple.gdshader")
const SNAP: float = 8.0

@export var sea_level: float = 0.0
@export var radius: float = 9000.0
@export var rings: int = 140
@export var segments: int = 160


func _ready() -> void:
	add_to_group(&"ocean")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mesh = build_polar_mesh(radius, rings, segments)
	material_override = make_material()
	_apply_lava_mask(material_override as ShaderMaterial)
	Events.graphics_preset_changed.connect(_on_preset)
	_on_preset(String(Settings.current_preset()))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 64.0
	position.y = sea_level


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var p: Vector3 = cam.global_position
	global_position = Vector3(snappedf(p.x, SNAP), sea_level, snappedf(p.z, SNAP))


## Baixo: shader simples (sem refração nem cor por profundidade).
func _on_preset(p: String) -> void:
	var q: int = JsonUtil.get_i(GraphicsPresets.get_preset(StringName(p)), "water_quality", 1)
	(material_override as ShaderMaterial).shader = WATER_SHADER if q >= 1 else WATER_SIMPLE_SHADER


## Máscara de lava (tools/make_map.gd): lagos internos das Terras Calcinadas,
## borrada para a borda ser suave. Só o mar global usa.
static func _apply_lava_mask(m: ShaderMaterial) -> void:
	const PATH: String = "res://world/island/data/lava_mask.png"
	if not ResourceLoader.exists(PATH):
		return
	var mask: Image = (load(PATH) as Texture2D).get_image()
	if mask.is_compressed():
		mask.decompress()
	mask.resize(256, 256, Image.INTERPOLATE_BILINEAR)
	mask.resize(512, 512, Image.INTERPOLATE_BILINEAR)
	m.set_shader_parameter(&"lava_mask", ImageTexture.create_from_image(mask))
	m.set_shader_parameter(&"lava_world_size", IslandLayout.WORLD_SIZE)


static func make_material() -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = WATER_SHADER
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = 31
	n.frequency = 0.02
	n.fractal_octaves = 4
	var nt: NoiseTexture2D = NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 4.0
	nt.generate_mipmaps = true
	nt.noise = n
	m.set_shader_parameter(&"normal_noise", nt)
	var fnoise: FastNoiseLite = FastNoiseLite.new()
	fnoise.seed = 77
	fnoise.noise_type = FastNoiseLite.TYPE_CELLULAR
	fnoise.frequency = 0.04
	fnoise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var ft: NoiseTexture2D = NoiseTexture2D.new()
	ft.width = 256
	ft.height = 256
	ft.seamless = true
	ft.generate_mipmaps = true
	ft.noise = fnoise
	m.set_shader_parameter(&"foam_noise", ft)
	return m


## Disco com anéis em progressão geométrica: ~1 m perto do centro, dezenas de
## metros no horizonte.
static func build_polar_mesh(max_radius: float, ring_count: int, segment_count: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.add_vertex(Vector3.ZERO)
	var first: float = 1.5
	var growth: float = pow(max_radius / first, 1.0 / float(ring_count - 1))
	for r: int in ring_count:
		var rad: float = first * pow(growth, r)
		for s: int in segment_count:
			var a: float = TAU * s / segment_count
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(cos(a) * rad, 0.0, sin(a) * rad))
	for s: int in segment_count:
		st.add_index(0)
		st.add_index(1 + (s + 1) % segment_count)
		st.add_index(1 + s)
	for r: int in ring_count - 1:
		var a0: int = 1 + r * segment_count
		var a1: int = 1 + (r + 1) * segment_count
		for s: int in segment_count:
			var s1: int = (s + 1) % segment_count
			st.add_index(a0 + s)
			st.add_index(a0 + s1)
			st.add_index(a1 + s)
			st.add_index(a0 + s1)
			st.add_index(a1 + s1)
			st.add_index(a1 + s)
	return st.commit()
