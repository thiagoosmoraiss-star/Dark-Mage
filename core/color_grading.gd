class_name ColorGrading
extends RefCounted
## Gera LUTs 3D (ImageTexture3D) para Environment.adjustment_color_correction.
## Usado para a graduação de cor por região e por estado (corrompida/purificada).

const SIZE: int = 17

## Parâmetros padrão: levemente quente nas luzes e frio/violeta nas sombras.
const NEUTRAL: Dictionary = {
	"lift": Color(0.0, 0.0, 0.0), "gain": Color(1.0, 1.0, 1.0), "gamma": 1.0,
	"saturation": 1.0, "shadow_tint": Color(0.0, 0.0, 0.0), "highlight_tint": Color(0.0, 0.0, 0.0),
}

const PRESETS: Dictionary = {
	&"default": {"lift": Color(0.012, 0.008, 0.02), "gain": Color(1.02, 1.0, 0.97), "gamma": 1.0,
		"saturation": 1.04, "shadow_tint": Color(0.02, 0.0, 0.05), "highlight_tint": Color(0.03, 0.015, -0.01)},
	&"corrupted": {"lift": Color(0.02, 0.0, 0.04), "gain": Color(0.95, 0.9, 1.04), "gamma": 1.05,
		"saturation": 0.72, "shadow_tint": Color(0.05, 0.0, 0.1), "highlight_tint": Color(0.02, -0.01, 0.05)},
	&"purified": {"lift": Color(0.005, 0.005, 0.0), "gain": Color(1.05, 1.02, 0.95), "gamma": 0.98,
		"saturation": 1.12, "shadow_tint": Color(0.0, 0.01, 0.02), "highlight_tint": Color(0.05, 0.03, -0.02)},
}


## Aplica a graduação a uma cor linear 0..1 (mesma fórmula usada para gerar a LUT).
static func grade(c: Color, p: Dictionary) -> Color:
	var lift: Color = p.get("lift", NEUTRAL["lift"])
	var gain: Color = p.get("gain", NEUTRAL["gain"])
	var gamma: float = p.get("gamma", 1.0)
	var sat: float = p.get("saturation", 1.0)
	var st: Color = p.get("shadow_tint", NEUTRAL["shadow_tint"])
	var ht: Color = p.get("highlight_tint", NEUTRAL["highlight_tint"])
	var v: Vector3 = Vector3(c.r, c.g, c.b)
	v = Vector3(v.x * gain.r, v.y * gain.g, v.z * gain.b) + Vector3(lift.r, lift.g, lift.b) * (Vector3.ONE - v)
	v = Vector3(pow(maxf(v.x, 0.0), gamma), pow(maxf(v.y, 0.0), gamma), pow(maxf(v.z, 0.0), gamma))
	var lum: float = v.dot(Vector3(0.2126, 0.7152, 0.0722))
	v = Vector3(lum, lum, lum).lerp(v, sat)
	var shadow_w: float = 1.0 - smoothstep(0.0, 0.5, lum)
	var high_w: float = smoothstep(0.5, 1.0, lum)
	v += Vector3(st.r, st.g, st.b) * shadow_w + Vector3(ht.r, ht.g, ht.b) * high_w
	return Color(clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0), clampf(v.z, 0.0, 1.0))


static func make_lut(p: Dictionary) -> ImageTexture3D:
	var tex: ImageTexture3D = ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, SIZE, SIZE, SIZE, false, lut_images(p))
	return tex


static func lut_images(p: Dictionary) -> Array[Image]:
	var images: Array[Image] = []
	for b: int in SIZE:
		var img: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
		for g: int in SIZE:
			for r: int in SIZE:
				var src: Color = Color(float(r) / (SIZE - 1), float(g) / (SIZE - 1), float(b) / (SIZE - 1))
				img.set_pixel(r, g, grade(src, p))
		images.append(img)
	return images


static var _data_cache: Dictionary[StringName, PackedByteArray] = {}


## Bytes RGB8 da LUT (todas as fatias em sequência), em cache por preset.
static func lut_data(preset: StringName) -> PackedByteArray:
	if not _data_cache.has(preset):
		var out: PackedByteArray = []
		var params: Dictionary = PRESETS.get(preset, PRESETS[&"default"])
		for img: Image in lut_images(params):
			out.append_array(img.get_data())
		_data_cache[preset] = out
	return _data_cache[preset]


## Atualiza `tex` com a mistura linear das LUTs `a` → `b` em `t` (0..1).
static func blend_data(a: StringName, b: StringName, t: float) -> PackedByteArray:
	var da: PackedByteArray = lut_data(a)
	var db: PackedByteArray = lut_data(b)
	var mixed: PackedByteArray = da.duplicate()
	for i: int in mixed.size():
		mixed[i] = roundi(lerpf(da[i], db[i], t))
	return mixed


static func blend_into(tex: ImageTexture3D, a: StringName, b: StringName, t: float) -> void:
	var mixed: PackedByteArray = blend_data(a, b, t)
	var slice: int = SIZE * SIZE * 3
	var images: Array[Image] = []
	for k: int in SIZE:
		images.append(Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, mixed.slice(k * slice, (k + 1) * slice)))
	tex.update(images)


static func lut_for(preset: StringName) -> ImageTexture3D:
	var p: Dictionary = PRESETS.get(preset, PRESETS[&"default"])
	return make_lut(p)
