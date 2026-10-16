class_name IslandGenerator
extends RefCounted
## Gera a Ilha do Medo de forma determinística a partir de uma seed.
## Saída: mapas de altura (RF), controle (RF com bits do Terrain3D), cor (RGBA8,
## alfa = modificador de rugosidade) e regiões (L8). A mesma seed e resolução
## sempre produzem os mesmos dados (ver test_island_generator.gd).

const L = preload("res://world/island/island_layout.gd")

var seed_value: int
var resolution: int
var spacing: float

var _n_base: FastNoiseLite
var _n_detail: FastNoiseLite
var _n_ridge: FastNoiseLite
var _n_warp: FastNoiseLite
var _n_coast: FastNoiseLite
var _n_region: FastNoiseLite
var _n_mat: FastNoiseLite

## Resultados.
var heights: PackedFloat32Array
## Passadas de suavização após o ruído.
var smooth_passes: int = 2
var region_ids: PackedByteArray
var region_weights: Array[PackedFloat32Array] = []


func _init(world_seed: int, res: int = 2048) -> void:
	seed_value = world_seed
	resolution = res
	spacing = L.WORLD_SIZE / res
	var base_seed: int = StableHash.derive_seed(world_seed, "island")
	_n_base = _noise(base_seed + 1, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0035, 5, FastNoiseLite.FRACTAL_FBM)
	_n_detail = _noise(base_seed + 2, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 4, FastNoiseLite.FRACTAL_FBM)
	_n_ridge = _noise(base_seed + 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0028, 5, FastNoiseLite.FRACTAL_RIDGED)
	_n_warp = _noise(base_seed + 4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0015, 3, FastNoiseLite.FRACTAL_FBM)
	_n_coast = _noise(base_seed + 5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.004, 4, FastNoiseLite.FRACTAL_FBM)
	_n_region = _noise(base_seed + 6, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.003, 3, FastNoiseLite.FRACTAL_FBM)
	_n_mat = _noise(base_seed + 7, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.018, 4, FastNoiseLite.FRACTAL_FBM)


static func _noise(s: int, type: FastNoiseLite.NoiseType, freq: float, octaves: int,
		fractal: FastNoiseLite.FractalType) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = s
	n.noise_type = type
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_type = fractal
	return n


func pixel_to_world(px: int, pz: int) -> Vector2:
	return Vector2(px * spacing - L.HALF, pz * spacing - L.HALF)


# --- Altura -------------------------------------------------------------------

## Pesos das regiões terrestres no ponto (soma 1). Ordem: VALLEY, FOREST, PEAKS, BURNT, SWAMP.
func region_weights_at(x: float, z: float) -> PackedFloat32Array:
	var w: PackedFloat32Array = []
	w.resize(5)
	var total: float = 0.0
	var wx: float = x + _n_region.get_noise_2d(x, z) * 140.0
	var wz: float = z + _n_region.get_noise_2d(z + 500.0, x - 300.0) * 140.0
	var i: int = 0
	for r: int in [L.Region.VALLEY, L.Region.FOREST, L.Region.PEAKS, L.Region.BURNT, L.Region.SWAMP]:
		var c: Vector2 = L.REGION_CENTERS[r]
		var d2: float = (wx - c.x) * (wx - c.x) + (wz - c.y) * (wz - c.y)
		var sigma: float = L.REGION_SIGMA * (1.15 if r == L.Region.VALLEY else 1.0)
		var v: float = exp(-d2 / (2.0 * sigma * sigma))
		w[i] = v
		total += v
		i += 1
	for k: int in 5:
		w[k] = w[k] / maxf(total, 1e-6)
	return w


## Máscara de terra (1 = interior, 0 = mar aberto) e fator de falésia (0..1).
func land_mask(x: float, z: float) -> Vector2:
	var r: float = sqrt(x * x + z * z) / L.ISLAND_RADIUS
	var coast_n: float = _n_coast.get_noise_2d(x, z)
	var warp: float = _n_warp.get_noise_2d(x, z)
	var r_eff: float = r * (1.0 + coast_n * 0.2 + warp * 0.24)
	var cliff: float = smoothstep(0.05, 0.35, _n_warp.get_noise_2d(x * 1.7 + 900.0, z * 1.7))
	var width: float = lerpf(0.16, 0.05, cliff)
	return Vector2(smoothstep(1.0, 1.0 - width, r_eff), cliff)


func height_at(x: float, z: float) -> float:
	var w: PackedFloat32Array = region_weights_at(x, z)
	var base: float = _n_base.get_noise_2d(x, z)
	var detail: float = _n_detail.get_noise_2d(x, z)
	var ridge: float = _n_ridge.get_noise_2d(x, z) * 0.5 + 0.5

	var h_valley: float = 20.0 + base * 16.0 + detail * 3.0
	var h_forest: float = 30.0 + base * 24.0 + detail * 5.0
	var north: float = smoothstep(-300.0, -820.0, z)
	var h_peaks: float = 55.0 + pow(ridge, 1.6) * 230.0 * (0.55 + 0.45 * north) + base * 25.0 + detail * 6.0
	var h_burnt: float = 26.0 + pow(ridge, 1.3) * 55.0 + detail * 5.0
	var dv: float = Vector2(x, z).distance_to(L.VOLCANO_CENTER)
	h_burnt += L.VOLCANO_HEIGHT * pow(maxf(0.0, 1.0 - dv / L.VOLCANO_RADIUS), 1.7)
	if dv < L.CRATER_RADIUS:
		h_burnt -= 46.0 * pow(1.0 - dv / L.CRATER_RADIUS, 1.5)
	var h_swamp: float = -0.4 + base * 2.4 + detail * 0.9

	var h: float = (w[0] * h_valley + w[1] * h_forest + w[2] * h_peaks + w[3] * h_burnt + w[4] * h_swamp)
	# O pântano domina o próprio miolo: baixo, com poças abaixo do nível do mar.
	h = lerpf(h, h_swamp, smoothstep(0.3, 0.7, w[4]))

	# Cidadela: platô de bordas íngremes.
	var dc: float = Vector2(x, z).distance_to(L.CITADEL_CENTER)
	var plateau: float = smoothstep(L.CITADEL_RADIUS + L.CITADEL_SKIRT, L.CITADEL_RADIUS, dc + detail * 10.0)
	h = lerpf(h, L.CITADEL_TOP + detail * 1.5, plateau)

	# Costa: praia suave ou falésia, e fundo do mar.
	var lm: Vector2 = land_mask(x, z)
	var beach_h: float = lerpf(1.2 + detail * 0.8, h, smoothstep(0.0, 0.55, lm.x))
	var shaped: float = lerpf(beach_h, h, lm.y * 0.8)
	var sea_floor: float = -26.0 + base * 6.0
	return lerpf(sea_floor, shaped, smoothstep(0.0, 0.18, lm.x))


## Altura final num vértice da grade de 1 m, já com a suavização aplicada
## (duas passadas 1-2-1 = kernel 1-4-6-4-1 em cada eixo).
func final_height_at(x: float, z: float) -> float:
	if spacing > 1.5 or smooth_passes != 2:
		return height_at(x, z)
	var k: Array[float] = [1.0, 4.0, 6.0, 4.0, 1.0]
	var total: float = 0.0
	for j: int in 5:
		for i: int in 5:
			total += k[i] * k[j] * height_at(x + (i - 2) * spacing, z + (j - 2) * spacing)
	return total / 256.0


# --- Geração completa -----------------------------------------------------------

func generate() -> void:
	var n: int = resolution
	heights = PackedFloat32Array()
	heights.resize(n * n)
	region_ids = PackedByteArray()
	region_ids.resize(n * n)
	for pz: int in n:
		for px: int in n:
			var p: Vector2 = pixel_to_world(px, pz)
			var hgt: float = height_at(p.x, p.y)
			heights[pz * n + px] = hgt
			region_ids[pz * n + px] = _classify(p.x, p.y, hgt)
	# Só faz sentido na resolução de 1 m (em grades grossas apagaria o relevo).
	if spacing <= 1.5:
		for i: int in smooth_passes:
			_smooth()


## Filtro 1-2-1 separável. Suaviza as dobras de 1 m: a malha do Terrain3D
## (diagonais alternadas) e a colisão (diagonal fixa) só divergem entre vértices,
## e a divergência cresce com a curvatura (ver DECISIONS D27).
func _smooth() -> void:
	var n: int = resolution
	var tmp: PackedFloat32Array = heights.duplicate()
	for pz: int in n:
		var row: int = pz * n
		for px: int in range(1, n - 1):
			tmp[row + px] = (heights[row + px - 1] + 2.0 * heights[row + px] + heights[row + px + 1]) * 0.25
	for pz: int in range(1, n - 1):
		var row: int = pz * n
		for px: int in n:
			heights[row + px] = (tmp[row - n + px] + 2.0 * tmp[row + px] + tmp[row + n + px]) * 0.25


func _classify(x: float, z: float, hgt: float) -> int:
	if hgt < L.SEA_LEVEL - 1.5:
		return L.Region.SEA
	if Vector2(x, z).distance_to(L.CITADEL_CENTER) < L.CITADEL_RADIUS + L.CITADEL_SKIRT * 0.5:
		return L.Region.CITADEL
	if land_mask(x, z).x < 0.45 and hgt < 6.0:
		return L.Region.COAST
	var w: PackedFloat32Array = region_weights_at(x, z)
	var best: int = 0
	for k: int in 5:
		if w[k] > w[best]:
			best = k
	return [L.Region.VALLEY, L.Region.FOREST, L.Region.PEAKS, L.Region.BURNT, L.Region.SWAMP][best]


func height_image() -> Image:
	return Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, heights.to_byte_array())


func region_image() -> Image:
	return Image.create_from_data(resolution, resolution, false, Image.FORMAT_L8, region_ids)


## Inclinação (0 = plano, 1 = vertical) no pixel, por diferenças centrais.
func slope_at(px: int, pz: int) -> float:
	var n: int = resolution
	var x0: int = maxi(px - 1, 0)
	var x1: int = mini(px + 1, n - 1)
	var z0: int = maxi(pz - 1, 0)
	var z1: int = mini(pz + 1, n - 1)
	var dx: float = (heights[pz * n + x1] - heights[pz * n + x0]) / ((x1 - x0) * spacing)
	var dz: float = (heights[z1 * n + px] - heights[z0 * n + px]) / ((z1 - z0) * spacing)
	var normal_y: float = 1.0 / sqrt(1.0 + dx * dx + dz * dz)
	return 1.0 - normal_y


## Mapa de controle do Terrain3D: material base, sobreposto e mistura por pixel.
## `encoder` recebe (base, overlay, blend 0..255) e devolve o uint32 do Terrain3D.
func control_image(encoder: Callable) -> Image:
	var n: int = resolution
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * n * 4)
	var cache: Dictionary[int, int] = {}
	var w_mat: PackedFloat32Array = []
	w_mat.resize(8)
	for pz: int in n:
		for px: int in n:
			var i: int = pz * n + px
			var p: Vector2 = pixel_to_world(px, pz)
			_material_weights(p.x, p.y, heights[i], slope_at(px, pz), w_mat)
			var a: int = 0
			var b: int = 1
			if w_mat[b] > w_mat[a]:
				a = 1
				b = 0
			for k: int in range(2, 8):
				if w_mat[k] > w_mat[a]:
					b = a
					a = k
				elif w_mat[k] > w_mat[b]:
					b = k
			var blend: int = clampi(roundi(w_mat[b] / maxf(w_mat[a] + w_mat[b], 1e-5) * 2.0 * 255.0), 0, 255)
			var key: int = (a << 12) | (b << 8) | blend
			if not cache.has(key):
				cache[key] = encoder.call(a, b, blend)
			bytes.encode_u32(i * 4, cache[key])
	return Image.create_from_data(n, n, false, Image.FORMAT_RF, bytes)


func _material_weights(x: float, z: float, hgt: float, slope: float, out: PackedFloat32Array) -> void:
	for k: int in 8:
		out[k] = 0.0
	var w: PackedFloat32Array = region_weights_at(x, z)
	var m: float = _n_mat.get_noise_2d(x, z) * 0.5 + 0.5
	var m2: float = _n_mat.get_noise_2d(z * 1.9 + 77.0, x * 1.9) * 0.5 + 0.5
	# Vale: campos de grama com manchas de musgo.
	out[L.Mat.GRASS] += w[0] * (0.6 + 0.4 * m)
	out[L.Mat.MOSS] += w[0] * (0.25 + 0.5 * m2) * 0.7
	# Floresta: chão musgoso e terra.
	out[L.Mat.MOSS] += w[1] * (0.5 + 0.5 * m)
	out[L.Mat.DIRT] += w[1] * (0.3 + 0.6 * m2)
	# Picos: grama rala embaixo, neve no alto.
	var snow: float = smoothstep(115.0, 160.0, hgt + (m - 0.5) * 30.0)
	out[L.Mat.GRASS] += w[2] * (1.0 - snow) * 0.6
	out[L.Mat.ROCK] += w[2] * (1.0 - snow) * 0.35
	out[L.Mat.SNOW] += snow * (0.6 + 0.4 * w[2]) * 1.4
	# Terras calcinadas: rocha vulcânica e terra queimada.
	out[L.Mat.VOLCANIC] += w[3] * (0.55 + 0.45 * m)
	out[L.Mat.DIRT] += w[3] * (0.2 + 0.3 * m2)
	# Pântano: solo corrompido e musgo.
	out[L.Mat.CORRUPT] += w[4] * (0.5 + 0.5 * m2)
	out[L.Mat.MOSS] += w[4] * (0.3 + 0.4 * m) * 0.8
	# Cidadela: rocha e terra.
	var dc: float = Vector2(x, z).distance_to(L.CITADEL_CENTER)
	var cit: float = smoothstep(L.CITADEL_RADIUS + L.CITADEL_SKIRT, L.CITADEL_RADIUS, dc)
	out[L.Mat.DIRT] += cit * (0.6 + 0.6 * m)
	out[L.Mat.ROCK] += cit * 0.4
	# Encostas íngremes viram rocha (vulcânica no leste).
	var steep: float = smoothstep(0.22, 0.4, slope + (m2 - 0.5) * 0.08)
	var rock_kind: int = L.Mat.VOLCANIC if w[3] > 0.5 else L.Mat.ROCK
	out[rock_kind] += steep * 3.0
	# Areia na costa.
	var beach: float = smoothstep(4.5, 1.5, hgt + (m - 0.5) * 2.0) * (1.0 - w[4] * 0.7)
	out[L.Mat.SAND] += beach * 2.5
	# Fundo do mar: areia e rocha.
	if hgt < -1.0:
		out[L.Mat.SAND] += 2.0
		out[L.Mat.ROCK] += m2


## Mapa de cor (tinta multiplicativa, branco = neutro; rugosidade no alfa, 0.5 = neutro).
func color_image() -> Image:
	var n: int = resolution
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * n * 4)
	for pz: int in n:
		for px: int in n:
			var i: int = pz * n + px
			var p: Vector2 = pixel_to_world(px, pz)
			var w: PackedFloat32Array = region_weights_at(p.x, p.y)
			var macro: float = _n_base.get_noise_2d(p.x * 3.1 + 200.0, p.y * 3.1) * 0.5 + 0.5
			# Vale dourado, floresta mais escura, pântano dessaturado e violeta.
			var tint: Color = Color(1, 1, 1)
			tint = tint.lerp(Color(1.0, 0.9, 0.62), w[0] * (0.35 + 0.5 * macro))
			tint = tint.lerp(Color(0.78, 0.86, 0.74), w[1] * 0.6)
			tint = tint.lerp(Color(0.9, 0.93, 1.0), w[2] * 0.4)
			tint = tint.lerp(Color(0.9, 0.78, 0.74), w[3] * 0.6)
			tint = tint.lerp(Color(0.72, 0.62, 0.86), w[4] * 0.75)
			var v: float = 0.84 + macro * 0.16
			bytes[i * 4 + 0] = clampi(roundi(tint.r * v * 255.0), 0, 255)
			bytes[i * 4 + 1] = clampi(roundi(tint.g * v * 255.0), 0, 255)
			bytes[i * 4 + 2] = clampi(roundi(tint.b * v * 255.0), 0, 255)
			var wet: float = w[4] * 0.35 + smoothstep(3.0, 0.5, heights[i]) * 0.25
			bytes[i * 4 + 3] = clampi(roundi((0.5 - wet) * 255.0), 0, 255)
	return Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, bytes)


## Hash estável dos dados de altura (testes de determinismo).
func height_hash() -> int:
	return StableHash.fnv1a_floats(heights)
