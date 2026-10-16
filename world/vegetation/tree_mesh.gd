class_name TreeMesh
extends RefCounted
## Árvores geradas por código: tronco e galhos (tubos que afinam, ramificação
## recursiva estilo L-system) e copa em cards de folhas com alfa.
## Cada espécie gera 3 níveis: LOD0 (perto), LOD1 (simplificado) e impostor
## (dois cards cruzados com a silhueta pintada).

enum Species { OAK, GIANT, PINE, DEAD }

const BARK_COLORS: Array[Color] = [Color("4a3a2c"), Color("3b2e26"), Color("3a3028"), Color("2b2526")]
const LEAF_COLORS: Array[Color] = [Color("5e7f36"), Color("3f6230"), Color("2f4a34"), Color("000000")]

static var _cache: Dictionary[String, Resource] = {}


## Retorna {"lod0": ArrayMesh, "lod1": ArrayMesh, "impostor": ArrayMesh, "height": float, "trunk_radius": float}.
static func build(species: Species, variant: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9000 + int(species) * 100 + variant
	var p: Dictionary = _params(species, rng)
	var lod0: ArrayMesh = _build_lod(species, p, rng.seed, 1.0)
	var lod1: ArrayMesh = _build_lod(species, p, rng.seed, 0.45)
	return {"lod0": lod0, "lod1": lod1, "impostor": _impostor(species, p),
		"height": JsonUtil.get_f(p, "height"), "trunk_radius": JsonUtil.get_f(p, "radius")}


static func _params(species: Species, rng: RandomNumberGenerator) -> Dictionary:
	match species:
		Species.OAK:
			return {"height": rng.randf_range(7.0, 10.0), "radius": rng.randf_range(0.28, 0.4), "branches": 6,
				"depth": 2, "spread": 0.75, "leaf_size": 2.6, "leaf_count": 9, "trunk_frac": 0.45, "gnarl": 0.35}
		Species.GIANT:
			return {"height": rng.randf_range(20.0, 27.0), "radius": rng.randf_range(0.9, 1.25), "branches": 7,
				"depth": 2, "spread": 0.6, "leaf_size": 5.0, "leaf_count": 10, "trunk_frac": 0.6, "gnarl": 0.25}
		Species.PINE:
			return {"height": rng.randf_range(10.0, 15.0), "radius": rng.randf_range(0.25, 0.35), "branches": 0,
				"depth": 0, "spread": 0.0, "leaf_size": 1.0, "leaf_count": 0, "trunk_frac": 1.0, "gnarl": 0.05}
		_:
			return {"height": rng.randf_range(6.0, 9.0), "radius": rng.randf_range(0.22, 0.32), "branches": 5,
				"depth": 2, "spread": 0.9, "leaf_size": 0.0, "leaf_count": 0, "trunk_frac": 0.5, "gnarl": 0.6}


static func _build_lod(species: Species, p: Dictionary, seed_value: int, detail: float) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var bark: SurfaceTool = SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves: SurfaceTool = SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = maxi(4, roundi(9 * detail))
	var segs: int = maxi(3, roundi(8 * detail))
	var height: float = JsonUtil.get_f(p, "height")
	var radius: float = JsonUtil.get_f(p, "radius")
	var trunk_len: float = height * JsonUtil.get_f(p, "trunk_frac")
	var tips: Array[Transform3D] = []
	var trunk_dir: Vector3 = Vector3(rng.randf_range(-0.08, 0.08), 1.0, rng.randf_range(-0.08, 0.08)).normalized()
	var top: Vector3 = _branch(bark, Vector3.ZERO, trunk_dir, trunk_len, radius, radius * 0.55, sides, segs,
		JsonUtil.get_f(p, "gnarl"), rng, species == Species.GIANT)
	if species == Species.PINE:
		_pine_layers(leaves, top, height, rng, detail)
	else:
		_recurse(bark, top, trunk_dir, height - trunk_len, radius * 0.55, JsonUtil.get_i(p, "branches"),
			JsonUtil.get_i(p, "depth"), JsonUtil.get_f(p, "spread"), JsonUtil.get_f(p, "gnarl"), sides, segs, rng, tips, detail)
		if JsonUtil.get_i(p, "leaf_count") > 0:
			var leaf_size: float = JsonUtil.get_f(p, "leaf_size")
			for t: Transform3D in tips:
				var n_cards: int = maxi(1, roundi(3 * detail))
				for c: int in n_cards:
					var off: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.8), rng.randf_range(-1, 1)) * leaf_size * 0.45
					_leaf_card(leaves, t.origin + off, leaf_size * rng.randf_range(0.8, 1.25), rng.randf() * TAU, rng)
	var mesh: ArrayMesh = ArrayMesh.new()
	bark.generate_normals()
	bark.commit(mesh)
	if species != Species.DEAD:
		leaves.commit(mesh)
		mesh.surface_set_material(1, leaf_material(species))
	mesh.surface_set_material(0, bark_material(species))
	return mesh


## Tubo que afina com leve torção; retorna a ponta.
static func _branch(st: SurfaceTool, start: Vector3, dir: Vector3, length: float, r0: float, r1: float,
		sides: int, segs: int, gnarl: float, rng: RandomNumberGenerator, roots: bool = false) -> Vector3:
	var base: int = _vertex_count(st)
	var side: Vector3 = dir.cross(Vector3.FORWARD if absf(dir.y) > 0.9 else Vector3.UP).normalized()
	var up: Vector3 = side.cross(dir).normalized()
	var pos: Vector3 = start
	var bend: Vector3 = Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)) * gnarl * 0.15
	var pts: Array[Vector3] = []
	for s: int in segs + 1:
		var t: float = float(s) / segs
		pts.append(pos)
		var d: Vector3 = (dir + bend * t * 2.0).normalized()
		pos += d * (length / segs)
	for s: int in segs + 1:
		var t: float = float(s) / segs
		var r: float = lerpf(r0, r1, pow(t, 0.8))
		if roots and t < 0.15:
			r *= 1.0 + (0.15 - t) * 9.0
		for k: int in sides + 1:
			var a: float = TAU * k / sides
			var flare: float = 1.0 + (0.25 * sin(a * 3.0 + t * 4.0) if roots and t < 0.2 else 0.0)
			var off: Vector3 = (side * cos(a) + up * sin(a)) * r * flare
			st.set_uv(Vector2(float(k) / sides * 2.0, t * length * 0.5))
			st.set_color(Color(1, 1, 1))
			st.add_vertex(pts[s] + off)
	for s: int in segs:
		for k: int in sides:
			var i0: int = base + s * (sides + 1) + k
			var i1: int = i0 + sides + 1
			st.add_index(i0)
			st.add_index(i0 + 1)
			st.add_index(i1)
			st.add_index(i0 + 1)
			st.add_index(i1 + 1)
			st.add_index(i1)
	st.set_meta(&"vcount", base + (segs + 1) * (sides + 1))
	return pos


static func _vertex_count(st: SurfaceTool) -> int:
	# SurfaceTool não expõe a contagem; _branch guarda na metadata.
	var n: int = st.get_meta(&"vcount", 0)
	return n


static func _recurse(st: SurfaceTool, start: Vector3, parent_dir: Vector3, length: float, radius: float, count: int,
		depth: int, spread: float, gnarl: float, sides: int, segs: int, rng: RandomNumberGenerator,
		tips: Array[Transform3D], detail: float) -> void:
	if depth <= 0 or count <= 0:
		tips.append(Transform3D(Basis(), start))
		return
	var n: int = maxi(2, roundi(count * (0.6 + 0.4 * detail)))
	for i: int in n:
		var a: float = TAU * i / n + rng.randf_range(-0.4, 0.4)
		var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var d: Vector3 = (parent_dir * (1.0 - spread * 0.6) + out * spread).normalized()
		var l: float = length * rng.randf_range(0.55, 0.85)
		var origin: Vector3 = start - parent_dir * rng.randf_range(0.0, length * 0.25)
		var tip: Vector3 = _branch(st, origin, d, l, radius, radius * 0.45, maxi(3, sides - 2), maxi(2, segs - 3), gnarl, rng)
		_recurse(st, tip, d, l * 0.7, radius * 0.45, count - 2, depth - 1, spread, gnarl, sides, segs, rng, tips, detail)


static func _leaf_card(st: SurfaceTool, center: Vector3, size: float, rot: float, rng: RandomNumberGenerator) -> void:
	# Dois quads cruzados + um horizontal: volume aparente de copa.
	for k: int in 3:
		var a: float = rot + k * PI / 3.0
		var right: Vector3 = Vector3(cos(a), 0.0, sin(a)) * size * 0.5
		var up: Vector3 = Vector3.UP * size * 0.5
		if k == 2:
			up = Vector3(-sin(a), 0.0, cos(a)) * size * 0.5
		var nrm: Vector3 = (center - Vector3(0, center.y * 0.6, 0)).normalized()
		var tint: Color = Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.25))
		var corners: Array[Vector3] = [center - right - up, center + right - up, center + right + up, center - right + up]
		var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nrm)
			st.set_color(tint)
			st.set_uv(uvs[idx])
			st.add_vertex(corners[idx])


static func _pine_layers(st: SurfaceTool, top: Vector3, height: float, rng: RandomNumberGenerator, detail: float) -> void:
	var layers: int = maxi(6, roundi(14 * detail))
	for i: int in layers:
		var t: float = float(i) / layers
		var y: float = height * lerpf(0.18, 0.98, t)
		var r: float = lerpf(3.4, 0.6, t) * (height / 12.0)
		var cards: int = maxi(5, roundi(10 * detail))
		for c: int in cards:
			var a: float = TAU * c / cards + rng.randf() * 0.5 + i
			var dir: Vector3 = Vector3(cos(a), -0.35, sin(a))
			var center: Vector3 = Vector3(top.x * t, y, top.z * t) + dir * r * 0.5
			var right: Vector3 = Vector3(-sin(a), 0.0, cos(a)) * r * 0.75
			var along: Vector3 = dir * r * 0.7
			var nrm: Vector3 = (dir + Vector3.UP * 1.5).normalized()
			var corners: Array[Vector3] = [center - along - right, center - along + right, center + along + right, center + along - right]
			var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(nrm)
				st.set_color(Color(1, 1, 1).darkened(t * 0.1 + rng.randf() * 0.15))
				st.set_uv(uvs[idx])
				st.add_vertex(corners[idx])


static func _impostor(species: Species, p: Dictionary) -> ArrayMesh:
	var h: float = JsonUtil.get_f(p, "height")
	var w: float = h * (0.45 if species == Species.PINE else 0.85)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 2:
		var a: float = k * PI * 0.5
		var right: Vector3 = Vector3(cos(a), 0.0, sin(a)) * w * 0.5
		var corners: Array[Vector3] = [-right, right, right + Vector3.UP * h, -right + Vector3.UP * h]
		var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[idx])
			st.add_vertex(corners[idx])
	var m: ArrayMesh = st.commit()
	m.surface_set_material(0, impostor_material(species))
	return m


# --- Materiais e texturas -------------------------------------------------------

static func bark_material(species: Species) -> StandardMaterial3D:
	var key: String = "bark_%d" % species
	if not _cache.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = BARK_COLORS[species]
		var n: FastNoiseLite = FastNoiseLite.new()
		n.seed = 400 + species
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.05
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		var tex: NoiseTexture2D = NoiseTexture2D.new()
		tex.width = 128
		tex.height = 512
		tex.seamless = true
		tex.noise = n
		var grad: Gradient = Gradient.new()
		grad.set_color(0, Color(0.55, 0.5, 0.45))
		grad.set_color(1, Color(1.15, 1.1, 1.0))
		tex.color_ramp = grad
		m.albedo_texture = tex
		var ntex: NoiseTexture2D = tex.duplicate() as NoiseTexture2D
		ntex.as_normal_map = true
		ntex.bump_strength = 10.0
		ntex.color_ramp = null
		m.normal_enabled = true
		m.normal_texture = ntex
		m.roughness = 0.9
		_cache[key] = m
	return _cache[key] as StandardMaterial3D


static func leaf_material(species: Species) -> StandardMaterial3D:
	var key: String = "leaf_%d" % species
	if not _cache.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_texture = leaf_texture(species)
		m.albedo_color = LEAF_COLORS[species].lightened(0.15)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.45
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.8
		m.backlight_enabled = true
		m.backlight = Color(0.35, 0.4, 0.2)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_cache[key] = m
	return _cache[key] as StandardMaterial3D


## Textura de folhagem: muitas folhas elípticas sobrepostas, com variação de tom.
static func leaf_texture(species: Species) -> ImageTexture:
	var key: String = "leaf_tex_%d" % species
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var size: int = 256
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77 + species
	var needles: bool = species == Species.PINE
	var count: int = 900 if needles else 150
	for i: int in count:
		var c: Vector2 = Vector2(rng.randf_range(0.12, 0.88), rng.randf_range(0.12, 0.88)) * size
		# Concentra no centro (forma de tufo arredondado).
		c = c.lerp(Vector2(size, size) * 0.5, rng.randf_range(0.0, 0.35))
		var ang: float = rng.randf() * TAU
		var len: float = rng.randf_range(10.0, 18.0) if not needles else rng.randf_range(14.0, 26.0)
		var wid: float = len * (0.42 if not needles else 0.16)
		var shade: float = rng.randf_range(0.65, 1.15)
		var col: Color = Color(shade, shade * rng.randf_range(0.95, 1.05), shade * 0.9, 1.0)
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var nrm: Vector2 = Vector2(-dir.y, dir.x)
		var r: int = ceili(len)
		for y: int in range(maxi(0, floori(c.y) - r), mini(size, floori(c.y) + r)):
			for x: int in range(maxi(0, floori(c.x) - r), mini(size, floori(c.x) + r)):
				var d: Vector2 = Vector2(x, y) - c
				var u: float = d.dot(dir) / (len * 0.5)
				var v: float = d.dot(nrm) / (wid * 0.5)
				if u * u + v * v <= 1.0:
					var vein: float = 1.0 - 0.18 * (1.0 - absf(v)) * float(absf(v) < 0.15)
					img.set_pixel(x, y, Color(col.r * vein * (0.9 + 0.1 * u), col.g * vein, col.b * vein, 1.0))
	img.generate_mipmaps()
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func impostor_material(species: Species) -> StandardMaterial3D:
	var key: String = "imp_%d" % species
	if _cache.has(key):
		return _cache[key] as StandardMaterial3D
	var size: int = 128
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bark: Color = BARK_COLORS[species]
	var leaf: Color = LEAF_COLORS[species] if species != Species.DEAD else bark
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = 31 + species
	n.frequency = 0.08
	for y: int in size:
		for x: int in size:
			var u: float = float(x) / size - 0.5
			var v: float = 1.0 - float(y) / size
			var trunk: bool = absf(u) < 0.035 * (1.2 - v)
			var canopy: float = 0.0
			match species:
				Species.PINE:
					canopy = float(absf(u) < (1.0 - v) * 0.5 and v > 0.18)
				Species.DEAD:
					canopy = float(v > 0.45 and absf(u) < 0.03 + 0.4 * (v - 0.45) and absf(sin(u * 40.0 + v * 9.0)) < 0.25)
				_:
					var cy: float = 0.68 if species == Species.OAK else 0.75
					canopy = float(Vector2(u * 1.25, (v - cy) * 1.7).length() + n.get_noise_2d(x, y) * 0.12 < 0.4)
			if canopy > 0.5:
				var shade: float = 0.75 + n.get_noise_2d(x * 2.0, y * 2.0) * 0.3 + v * 0.15
				img.set_pixel(x, y, Color(leaf.r * shade, leaf.g * shade, leaf.b * shade, 1.0))
			elif trunk:
				img.set_pixel(x, y, Color(bark, 1.0))
	img.generate_mipmaps()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cache[key] = m
	return m
