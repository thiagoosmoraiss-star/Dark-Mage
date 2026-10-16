class_name IslandTerrain
extends Node3D
## Monta o Terrain3D da ilha: carrega os dados gerados (world/island/data),
## as texturas PBR e configura material, LOD e colisão.
## A colisão vem dos mesmos dados de altura que o visual (roteiro 8.3).

const DATA_DIR: String = "res://world/island/data"
const TEXTURE_DIR: String = "res://assets/textures/terrain"
const REGION_MAP_PATH: String = "res://world/island/data/region_map.png"

## FULL_GAME constrói a colisão de toda a ilha (usado nos testes); DYNAMIC_GAME
## só ao redor da câmera/jogador.
@export var full_collision: bool = false
@export var collision_radius: int = 160

var terrain: Terrain3D
var _region_map: Image


func _ready() -> void:
	add_to_group(&"island_terrain")
	terrain = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.vertex_spacing = 1.0
	terrain.mesh_lods = 7
	terrain.mesh_size = 48
	terrain.data_directory = DATA_DIR
	add_child(terrain, true)
	# Material, colisão e assets só existem depois de o Terrain3D entrar na
	# árvore; assets atribuídos antes são descartados na inicialização.
	_configure_material(terrain.material)
	terrain.collision.mode = (Terrain3DCollision.FULL_GAME if full_collision else Terrain3DCollision.DYNAMIC_GAME)
	terrain.collision.radius = collision_radius
	terrain.cast_shadows = RenderingServer.SHADOW_CASTING_SETTING_ON
	terrain.assets = build_assets()
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(REGION_MAP_PATH)) if FileAccess.file_exists(REGION_MAP_PATH) else null
	_region_map = img


static func build_assets() -> Terrain3DAssets:
	var assets: Terrain3DAssets = Terrain3DAssets.new()
	for i: int in IslandLayout.MATERIALS.size():
		var mat_name: String = IslandLayout.MATERIALS[i]
		var ta: Terrain3DTextureAsset = Terrain3DTextureAsset.new()
		ta.name = mat_name
		ta.albedo_texture = load(TEXTURE_DIR.path_join(mat_name + "_albedo_height.png")) as Texture2D
		ta.normal_texture = load(TEXTURE_DIR.path_join(mat_name + "_normal_rough.png")) as Texture2D
		ta.uv_scale = IslandLayout.UV_SCALES[i]
		ta.detiling_rotation = 0.12
		ta.detiling_shift = 0.25
		ta.normal_depth = 1.0
		ta.ao_strength = 0.6
		ta.roughness = 0.25  # menos brilho especular granulado
		assets.set_texture(i, ta)
	return assets


static func _configure_material(m: Terrain3DMaterial) -> void:
	m.world_background = Terrain3DMaterial.NONE
	m.auto_shader = false
	m.dual_scaling = true
	m.texture_filtering = Terrain3DMaterial.LINEAR
	# Variação de macro escala para quebrar a repetição de longe.
	m.set_shader_param(&"enable_macro_variation", true)
	m.set_shader_param(&"macro_variation1", Color(0.92, 0.9, 0.84))
	m.set_shader_param(&"macro_variation2", Color(0.86, 0.88, 0.92))
	m.set_shader_param(&"macro_variation_slope", 0.333)
	m.set_shader_param(&"noise1_scale", 0.04)
	m.set_shader_param(&"noise2_scale", 0.076)
	m.set_shader_param(&"blend_sharpness", 0.87)
	# Projeção nas encostas íngremes (evita textura esticada nos penhascos).
	m.set_shader_param(&"enable_projection", true)
	m.set_shader_param(&"projection_threshold", 0.8)
	m.set_shader_param(&"dual_scale_texture", IslandLayout.Mat.ROCK)
	m.set_shader_param(&"dual_scale_reduction", 0.3)
	m.set_shader_param(&"tri_scale_reduction", 0.3)
	m.set_shader_param(&"dual_scale_far", 170.0)
	m.set_shader_param(&"dual_scale_near", 100.0)


func height_at(pos: Vector3) -> float:
	return terrain.data.get_height(pos)


## Região no ponto (IslandLayout.Region), lida do mapa de regiões gerado.
func region_at(pos: Vector3) -> int:
	if _region_map == null:
		return IslandLayout.Region.VALLEY
	var n: int = _region_map.get_width()
	var px: int = clampi(floori((pos.x + IslandLayout.HALF) / IslandLayout.WORLD_SIZE * n), 0, n - 1)
	var pz: int = clampi(floori((pos.z + IslandLayout.HALF) / IslandLayout.WORLD_SIZE * n), 0, n - 1)
	return roundi(_region_map.get_pixel(px, pz).r * 255.0)
