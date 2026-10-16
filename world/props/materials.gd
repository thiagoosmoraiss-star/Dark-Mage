class_name Materials
extends RefCounted
## Materiais e texturas procedurais compartilhados (criados uma vez e reutilizados).

const ROCK_SHADER: Shader = preload("res://shaders/rock.gdshader")

static var _cache: Dictionary[StringName, Resource] = {}


static func detail_noise() -> NoiseTexture2D:
	if not _cache.has(&"detail_noise"):
		var n: FastNoiseLite = FastNoiseLite.new()
		n.seed = 1301
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.012
		n.fractal_octaves = 5
		var t: NoiseTexture2D = NoiseTexture2D.new()
		t.width = 512
		t.height = 512
		t.seamless = true
		t.generate_mipmaps = true
		t.noise = n
		_cache[&"detail_noise"] = t
	return _cache[&"detail_noise"] as NoiseTexture2D


static func detail_normal() -> NoiseTexture2D:
	if not _cache.has(&"detail_normal"):
		var n: FastNoiseLite = FastNoiseLite.new()
		n.seed = 977
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.03
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 3
		var t: NoiseTexture2D = NoiseTexture2D.new()
		t.width = 512
		t.height = 512
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 6.0
		t.generate_mipmaps = true
		t.noise = n
		_cache[&"detail_normal"] = t
	return _cache[&"detail_normal"] as NoiseTexture2D


static func rock(moss: float = 0.45, corruption: float = 0.0) -> ShaderMaterial:
	var key: StringName = StringName("rock_%.2f_%.2f" % [moss, corruption])
	if not _cache.has(key):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = ROCK_SHADER
		m.set_shader_parameter(&"detail_noise", detail_noise())
		m.set_shader_parameter(&"detail_normal", detail_normal())
		m.set_shader_parameter(&"moss_amount", moss)
		m.set_shader_parameter(&"corruption", corruption)
		_cache[key] = m
	return _cache[key] as ShaderMaterial
