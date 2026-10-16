class_name DayNightPalette
extends RefCounted
## Paleta do ciclo de dia e noite (direção de arte, seção 2). Chaves por hora;
## valores interpolados linearmente e de forma cíclica (23h → 0h).
## Dourado/âmbar no dia e no pôr do sol; azul-crepúsculo e violeta à noite.

const KEYS: Array[Dictionary] = [
	{"h": 0.0, "zenith": Color("0a0d22"), "horizon": Color("2a2546"), "sun": Color("ff8a4a"), "sun_energy": 0.0,
		"moon_energy": 0.32, "ambient": 0.55, "fog": Color("1b1830"), "stars": 1.0, "cloud_lit": Color("3b3a5c"),
		"cloud_shadow": Color("121020"), "fog_density": 0.00054, "exposure": 1.25, "saturation": 0.9},
	{"h": 4.8, "zenith": Color("141a3c"), "horizon": Color("3d3158"), "sun": Color("ff8a4a"), "sun_energy": 0.0,
		"moon_energy": 0.28, "ambient": 0.55, "fog": Color("2a2440"), "stars": 0.8, "cloud_lit": Color("4a4466"),
		"cloud_shadow": Color("181528"), "fog_density": 0.00063, "exposure": 1.2, "saturation": 0.9},
	{"h": 6.0, "zenith": Color("3a4c80"), "horizon": Color("ffab6b"), "sun": Color("ff9550"), "sun_energy": 0.55,
		"moon_energy": 0.05, "ambient": 0.6, "fog": Color("b88a7a"), "stars": 0.15, "cloud_lit": Color("ffc08a"),
		"cloud_shadow": Color("5a4a66"), "fog_density": 0.00068, "exposure": 1.05, "saturation": 1.08},
	{"h": 8.0, "zenith": Color("2f62b0"), "horizon": Color("e6d3b5"), "sun": Color("ffe1b3"), "sun_energy": 1.35,
		"moon_energy": 0.0, "ambient": 0.75, "fog": Color("bdb8c2"), "stars": 0.0, "cloud_lit": Color("fff5ea"),
		"cloud_shadow": Color("8a8aa0"), "fog_density": 0.00040, "exposure": 1.0, "saturation": 1.05},
	{"h": 12.5, "zenith": Color("2456a8"), "horizon": Color("c9d5e2"), "sun": Color("fff3e0"), "sun_energy": 1.75,
		"moon_energy": 0.0, "ambient": 0.8, "fog": Color("b4bfcf"), "stars": 0.0, "cloud_lit": Color("ffffff"),
		"cloud_shadow": Color("9a9cb0"), "fog_density": 0.00032, "exposure": 0.95, "saturation": 1.0},
	{"h": 16.0, "zenith": Color("2c5ca8"), "horizon": Color("e8cfa6"), "sun": Color("ffdcab"), "sun_energy": 1.45,
		"moon_energy": 0.0, "ambient": 0.75, "fog": Color("c4b8b0"), "stars": 0.0, "cloud_lit": Color("fff0dc"),
		"cloud_shadow": Color("8c8698"), "fog_density": 0.00036, "exposure": 1.0, "saturation": 1.05},
	{"h": 18.0, "zenith": Color("38386e"), "horizon": Color("ff8f4f"), "sun": Color("ff7a3c"), "sun_energy": 0.65,
		"moon_energy": 0.0, "ambient": 0.6, "fog": Color("b0705e"), "stars": 0.05, "cloud_lit": Color("ffa070"),
		"cloud_shadow": Color("5a3f5e"), "fog_density": 0.00059, "exposure": 1.05, "saturation": 1.12},
	{"h": 19.2, "zenith": Color("1c1c46"), "horizon": Color("6e3a66"), "sun": Color("ff6a3c"), "sun_energy": 0.0,
		"moon_energy": 0.18, "ambient": 0.55, "fog": Color("3e2a4c"), "stars": 0.5, "cloud_lit": Color("6a4a78"),
		"cloud_shadow": Color("201830"), "fog_density": 0.00063, "exposure": 1.2, "saturation": 0.95},
	{"h": 21.0, "zenith": Color("0d1028"), "horizon": Color("2e284c"), "sun": Color("ff8a4a"), "sun_energy": 0.0,
		"moon_energy": 0.3, "ambient": 0.55, "fog": Color("1e1a34"), "stars": 0.95, "cloud_lit": Color("403e62"),
		"cloud_shadow": Color("141224"), "fog_density": 0.00054, "exposure": 1.25, "saturation": 0.9},
]


## Retorna os valores interpolados para a hora (0..24).
static func sample(hours: float) -> Dictionary:
	var h: float = fposmod(hours, 24.0)
	var n: int = KEYS.size()
	var i: int = n - 1
	for k: int in n:
		if JsonUtil.get_f(KEYS[k], "h") <= h:
			i = k
	var a: Dictionary = KEYS[i]
	var b: Dictionary = KEYS[(i + 1) % n]
	var ha: float = a["h"]
	var hb: float = b["h"]
	if hb <= ha:
		hb += 24.0
	var hh: float = h if h >= ha else h + 24.0
	var t: float = clampf((hh - ha) / maxf(hb - ha, 0.0001), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)  # suaviza as transições entre chaves
	var out: Dictionary = {}
	for key: String in a:
		if key == "h":
			continue
		var va: Variant = a[key]
		var vb: Variant = b[key]
		if va is Color:
			out[key] = (va as Color).lerp(vb as Color, t)
		else:
			out[key] = lerpf(va as float, vb as float, t)
	return out


## Direção PARA o sol. Nasce a leste (+X) às 6h, põe-se a oeste às 18h,
## inclinado para o sul (+Z) para que as sombras nunca fiquem totalmente verticais.
static func sun_direction(hours: float) -> Vector3:
	var a: float = (fposmod(hours, 24.0) - 6.0) / 12.0 * PI
	var tilt: float = deg_to_rad(28.0)
	return Vector3(cos(a), sin(a) * cos(tilt), sin(a) * sin(tilt)).normalized()


## A lua segue o caminho oposto, levemente deslocada para não ficar exatamente
## na antípoda do sol.
static func moon_direction(hours: float) -> Vector3:
	var a: float = (fposmod(hours, 24.0) - 18.5) / 12.0 * PI
	var tilt: float = deg_to_rad(-20.0)
	return Vector3(cos(a), sin(a) * cos(tilt), sin(a) * sin(tilt)).normalized()
