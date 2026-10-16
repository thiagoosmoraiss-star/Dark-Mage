class_name Atmosphere
extends Node3D
## Céu, sol, lua, névoa, pós-processamento e ciclo de dia e noite.
## Constrói o próprio WorldEnvironment e as luzes; basta instanciar na cena.
## Os presets gráficos (SSAO, SSIL, SSR, névoa volumétrica, sombras) são
## aplicados aqui ao ouvir Events.graphics_preset_changed.

const SKY_SHADER: Shader = preload("res://shaders/sky.gdshader")
const MOON_COLOR: Color = Color("9d92ff")
const VIOLET_FOG: Color = Color("4a2a7a")

## Hora do dia (0..24).
@export_range(0.0, 24.0, 0.01) var hours: float = 9.0
## Duração de um dia completo em minutos reais.
@export var cycle_minutes: float = 24.0
@export var running: bool = true
## Clima: 0 = limpo, 1 = encoberto. Controlado pelo sistema de clima.
@export_range(0.0, 1.0) var cloud_coverage: float = 0.42
## Multiplicador de névoa do clima (1 = normal).
@export var weather_fog: float = 1.0
## Corrupção da área atual (0..1): névoa violeta, céu dessaturado.
@export_range(0.0, 1.0) var corruption: float = 0.0

var environment: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_material: ShaderMaterial
var world_environment: WorldEnvironment

var _preset: Dictionary = GraphicsPresets.get_preset(GraphicsPresets.HIGH)
var _sky_accum: float = 999.0
var _cloud_time: float = 0.0
var _last_hour_emitted: int = -1
var _grading: StringName = &""
const GRADING_FADE: float = 2.0
var _lut: ImageTexture3D
var _blend_from: StringName = &"default"
var _blend_t: float = 1.0
var _blend_step: float = 0.0


func _ready() -> void:
	add_to_group(&"atmosphere")
	_build()
	Events.graphics_preset_changed.connect(_on_preset_changed)
	_on_preset_changed(String(Settings.current_preset()))
	set_grading(&"default")
	apply_now()


func _process(delta: float) -> void:
	_update_grading_blend(delta)
	if running:
		hours = fposmod(hours + delta * 24.0 / (cycle_minutes * 60.0), 24.0)
	_cloud_time += delta
	_update_lights_and_fog()
	_sky_accum += delta
	var interval: float = _preset["sky_radiance_update_s"]
	if _sky_accum >= interval:
		_sky_accum = 0.0
		_update_sky()
	var h: int = floori(hours)
	if h != _last_hour_emitted:
		_last_hour_emitted = h
		Events.time_of_day_changed.emit(hours)


## Atualiza tudo imediatamente (útil após mudar a hora por script).
func apply_now() -> void:
	_update_lights_and_fog()
	_update_sky()


func set_hours(value: float) -> void:
	hours = fposmod(value, 24.0)
	apply_now()


func is_night() -> bool:
	return DayNightPalette.sun_direction(hours).y < -0.05


## Fator noturno contínuo (0 = dia pleno, 1 = noite plena), para jogabilidade.
func night_factor() -> float:
	return smoothstep(0.1, -0.15, DayNightPalette.sun_direction(hours).y)


## Troca a graduação com crossfade de ~2 s entre as LUTs (sem salto ao cruzar regiões).
func set_grading(preset: StringName) -> void:
	if preset == _grading:
		return
	var from: StringName = _grading
	_grading = preset
	if from == &"" or _lut == null:
		_lut = ColorGrading.lut_for(preset)
		environment.adjustment_color_correction = _lut
		return
	_blend_from = from if _blend_t >= 1.0 else _blend_from
	_blend_t = 0.0


func _update_grading_blend(delta: float) -> void:
	if _blend_t >= 1.0 or _lut == null:
		return
	_blend_t = minf(_blend_t + delta / GRADING_FADE, 1.0)
	_blend_step -= delta
	if _blend_step > 0.0 and _blend_t < 1.0:
		return
	_blend_step = 0.12
	ColorGrading.blend_into(_lut, _blend_from, _grading, _blend_t)


# --- Construção -------------------------------------------------------------

func _build() -> void:
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 7
	noise.frequency = 0.008
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = noise
	sky_material.set_shader_parameter(&"cloud_noise", tex)

	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.15
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.set_glow_level(1, 0.0)
	environment.set_glow_level(2, 0.6)
	environment.set_glow_level(3, 1.0)
	environment.set_glow_level(4, 0.6)
	environment.set_glow_level(5, 0.3)
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_sun_scatter = 0.35
	environment.fog_aerial_perspective = 0.35
	environment.fog_sky_affect = 0.12
	environment.fog_height = 2.0
	environment.fog_height_density = 0.012
	environment.volumetric_fog_density = 0.008
	environment.volumetric_fog_anisotropy = 0.55
	environment.volumetric_fog_length = 96.0
	environment.volumetric_fog_ambient_inject = 0.4
	environment.volumetric_fog_sky_affect = 0.0
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 1.6
	environment.ssao_power = 1.5
	environment.ssil_radius = 4.0
	environment.ssr_max_steps = 48
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08

	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.light_angular_distance = 0.6
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.directional_shadow_pancake_size = 30.0
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = MOON_COLOR
	moon.light_angular_distance = 0.4
	moon.shadow_bias = 0.05
	moon.shadow_normal_bias = 1.5
	moon.directional_shadow_blend_splits = true
	add_child(moon)


# --- Atualização --------------------------------------------------------------

func _update_lights_and_fog() -> void:
	var p: Dictionary = DayNightPalette.sample(hours)
	var sun_dir: Vector3 = DayNightPalette.sun_direction(hours)
	var moon_dir: Vector3 = DayNightPalette.moon_direction(hours)

	var sun_vis: float = smoothstep(-0.04, 0.1, sun_dir.y)
	var moon_vis: float = smoothstep(-0.02, 0.12, moon_dir.y)
	sun.light_energy = JsonUtil.num(p["sun_energy"]) * sun_vis
	sun.light_color = p["sun"]
	sun.visible = sun.light_energy > 0.001
	_aim(sun, sun_dir)
	moon.light_energy = JsonUtil.num(p["moon_energy"]) * moon_vis
	moon.visible = moon.light_energy > 0.001
	_aim(moon, moon_dir)
	# Só uma luz direcional projeta sombra por vez (custo).
	moon.shadow_enabled = sun.light_energy < 0.05

	var fog: Color = p["fog"]
	fog = fog.lerp(VIOLET_FOG, corruption * 0.75)
	environment.fog_light_color = fog
	environment.fog_density = JsonUtil.num(p["fog_density"]) * weather_fog * (1.0 + corruption * 1.5)
	environment.volumetric_fog_albedo = fog.lerp(Color(0.85, 0.82, 0.9), 0.4)
	environment.volumetric_fog_emission = VIOLET_FOG * 0.05 * corruption
	environment.volumetric_fog_density = (0.006 + 0.02 * corruption) * weather_fog
	environment.ambient_light_energy = p["ambient"]
	environment.tonemap_exposure = p["exposure"]
	environment.adjustment_saturation = JsonUtil.num(p["saturation"]) * (1.0 - corruption * 0.3)


func _update_sky() -> void:
	var p: Dictionary = DayNightPalette.sample(hours)
	var sun_dir: Vector3 = DayNightPalette.sun_direction(hours)
	var moon_dir: Vector3 = DayNightPalette.moon_direction(hours)
	sky_material.set_shader_parameter(&"sun_dir", sun_dir)
	sky_material.set_shader_parameter(&"moon_dir", moon_dir)
	sky_material.set_shader_parameter(&"zenith_color", p["zenith"])
	sky_material.set_shader_parameter(&"horizon_color", p["horizon"])
	sky_material.set_shader_parameter(&"sun_color", p["sun"])
	sky_material.set_shader_parameter(&"moon_color", MOON_COLOR)
	sky_material.set_shader_parameter(&"cloud_lit_color", p["cloud_lit"])
	sky_material.set_shader_parameter(&"cloud_shadow_color", p["cloud_shadow"])
	sky_material.set_shader_parameter(&"star_intensity", p["stars"])
	sky_material.set_shader_parameter(&"cloud_coverage", cloud_coverage)
	sky_material.set_shader_parameter(&"cloud_time", _cloud_time)
	sky_material.set_shader_parameter(&"corruption", corruption)
	var fog: Color = p["fog"]
	sky_material.set_shader_parameter(&"ground_color", fog.darkened(0.6))


## Aponta a luz para que ela venha da direção `to_light`.
static func _aim(light: DirectionalLight3D, to_light: Vector3) -> void:
	var fwd: Vector3 = -to_light
	var up: Vector3 = Vector3.UP if absf(fwd.y) < 0.99 else Vector3.FORWARD
	light.basis = Basis.looking_at(fwd, up)


func _on_preset_changed(preset_name: String) -> void:
	_preset = GraphicsPresets.get_preset(StringName(preset_name))
	var splits: int = _preset["shadow_splits"]
	sun.directional_shadow_mode = (DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if splits >= 4
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	sun.directional_shadow_max_distance = _preset["shadow_distance"]
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = _preset["shadow_distance"] * 0.6
	environment.ssao_enabled = _preset["ssao"]
	environment.ssil_enabled = _preset["ssil"]
	environment.ssr_enabled = _preset["ssr"]
	environment.volumetric_fog_enabled = _preset["volumetric_fog"]
	# Glow: no Baixo só os níveis mais largos (mais baratos).
	var low_q: bool = JsonUtil.get_i(_preset, "volumetric_quality") == 0
	environment.set_glow_level(1, 0.0)
	environment.set_glow_level(2, 0.0 if low_q else 0.6)
	environment.set_glow_level(4, 0.6)
	var q: int = _preset["volumetric_quality"]
	var vol_sizes: Array[int] = [32, 64, 96, 128]
	var vol_depths: Array[int] = [32, 48, 64, 96]
	RenderingServer.environment_set_volumetric_fog_volume_size(vol_sizes[q], vol_depths[q])
	var soft: Array[RenderingServer.ShadowQuality] = [
		RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH]
	RenderingServer.directional_soft_shadow_filter_set_quality(soft[q])
	RenderingServer.positional_soft_shadow_filter_set_quality(soft[q])
	(environment.sky as Sky).radiance_size = Sky.RADIANCE_SIZE_128 if q == 0 else Sky.RADIANCE_SIZE_256
	_sky_accum = 999.0
