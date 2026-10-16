extends SceneTree
## Pinta o mapa da ilha (1024²) em estilo de carta antiga: cores das regiões
## esmaecidas e misturadas pelos pesos, relevo sombreado com luz de noroeste,
## curvas de nível a cada 20 m, contorno da costa a tinta e ondas desenhadas no mar.
## Grava world/island/data/map_painted.png, usado pela tela de mapa.
## Uso: tools/run.sh res://tools/make_map.gd

const WORLD_SEED: int = 20261016
const N: int = 1024
const PAPER: Color = Color(0.86, 0.79, 0.64)
const INK: Color = Color(0.22, 0.15, 0.11)
const SEA: Color = Color(0.55, 0.6, 0.6)
const LAND: Array[int] = [IslandLayout.Region.VALLEY, IslandLayout.Region.FOREST, IslandLayout.Region.PEAKS,
	IslandLayout.Region.BURNT, IslandLayout.Region.SWAMP]


func _initialize() -> void:
	var t0: int = Time.get_ticks_msec()
	var gen: IslandGenerator = IslandGenerator.new(WORLD_SEED, 2048)
	gen.generate()
	var res: int = gen.resolution
	var step: int = res / N
	var palette: Array[Color] = []
	palette.resize(IslandLayout.Region.size())
	var tints: Dictionary = {
		IslandLayout.Region.SEA: SEA, IslandLayout.Region.COAST: Color("d9c894"),
		IslandLayout.Region.VALLEY: Color("c2b46a"), IslandLayout.Region.FOREST: Color("7d8f5a"),
		IslandLayout.Region.PEAKS: Color("b8b4ae"), IslandLayout.Region.BURNT: Color("a9735a"),
		IslandLayout.Region.SWAMP: Color("8d7c9a"), IslandLayout.Region.CITADEL: Color("9a8c80"),
	}
	for r: int in palette.size():
		palette[r] = (tints.get(r, PAPER) as Color).lerp(PAPER, 0.15)
	var img: Image = Image.create_empty(N, N, false, Image.FORMAT_RGB8)
	var light: Vector2 = Vector2(-1.0, -1.0).normalized()
	for z: int in N:
		for x: int in N:
			var i: int = (z * step) * res + x * step
			var h: float = gen.heights[i]
			var hx0: float = gen.heights[(z * step) * res + maxi(x * step - step, 0)]
			var hx1: float = gen.heights[(z * step) * res + mini(x * step + step, res - 1)]
			var hz0: float = gen.heights[maxi(z * step - step, 0) * res + x * step]
			var hz1: float = gen.heights[mini(z * step + step, res - 1) * res + x * step]
			var grad: Vector2 = Vector2(hx1 - hx0, hz1 - hz0)
			var c: Color
			if h < 0.0:
				# Mar: azul-papel que escurece com a profundidade e linhas de onda perto da costa.
				c = SEA.lerp(PAPER, 0.35).darkened(clampf(-h / 60.0, 0.0, 0.35))
				if h > -7.0 and fposmod(-h, 2.3) < 0.35:
					c = c.lightened(0.18)
			else:
				# Pesos das 5 regiões terrestres (VALLEY, FOREST, PEAKS, BURNT, SWAMP).
				var wp: Vector2 = gen.pixel_to_world(x * step, z * step)
				var w: PackedFloat32Array = gen.region_weights_at(wp.x, wp.y)
				c = Color(0, 0, 0)
				for k: int in 5:
					c += palette[LAND[k]] * w[k]
				var rid: int = gen.region_ids[i]
				if rid == IslandLayout.Region.COAST or rid == IslandLayout.Region.CITADEL:
					c = c.lerp(palette[rid], 0.7)
				var shade: float = clampf(1.0 + grad.dot(light) * 0.06, 0.6, 1.25)
				c = Color(c.r * shade, c.g * shade, c.b * shade)
				# Curvas de nível.
				if floori(h / 20.0) != floori(hx1 / 20.0) or floori(h / 20.0) != floori(hz1 / 20.0):
					c = c.lerp(INK, 0.22)
			# Linha da costa.
			if (h >= 0.0) != (hx1 >= 0.0) or (h >= 0.0) != (hz1 >= 0.0):
				c = c.lerp(INK, 0.8)
			img.set_pixel(x, z, c)
	_lava_mask(gen)
	var path: String = ProjectSettings.globalize_path("res://world/island/data/map_painted.png")
	print("map: %s %s em %.1f s" % [path, error_string(img.save_png(path)), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)


## Máscara de lava (512²): lagos internos (abaixo do mar e sem ligação com o oceano
## aberto) onde o peso das Terras Calcinadas passa de 0,4.
func _lava_mask(gen: IslandGenerator) -> void:
	const M: int = 512
	var res: int = gen.resolution
	var st: int = res / M
	var water: PackedByteArray = []
	water.resize(M * M)
	for z: int in M:
		for x: int in M:
			water[z * M + x] = 1 if gen.heights[(z * st) * res + x * st] < 0.0 else 0
	# Flood fill do oceano a partir das bordas.
	var ocean: PackedByteArray = []
	ocean.resize(M * M)
	var stack: PackedInt32Array = []
	for k: int in M:
		for idx: int in [k, (M - 1) * M + k, k * M, k * M + M - 1]:
			if water[idx] == 1 and ocean[idx] == 0:
				ocean[idx] = 1
				stack.append(idx)
	while not stack.is_empty():
		var idx2: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var cx: int = idx2 % M
		var cz: int = idx2 / M
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var nz: int = cz + d.y
			if nx < 0 or nz < 0 or nx >= M or nz >= M:
				continue
			var n: int = nz * M + nx
			if water[n] == 1 and ocean[n] == 0:
				ocean[n] = 1
				stack.append(n)
	var out: PackedByteArray = []
	out.resize(M * M)
	var lava_px: int = 0
	for z2: int in M:
		for x2: int in M:
			var i: int = z2 * M + x2
			if water[i] == 1 and ocean[i] == 0:
				var wp: Vector2 = gen.pixel_to_world(x2 * st, z2 * st)
				if gen.region_weights_at(wp.x, wp.y)[3] > 0.4:
					out[i] = 255
					lava_px += 1
	var img: Image = Image.create_from_data(M, M, false, Image.FORMAT_L8, out)
	var path: String = ProjectSettings.globalize_path("res://world/island/data/lava_mask.png")
	print("lava: %d px, %s" % [lava_px, error_string(img.save_png(path))])
