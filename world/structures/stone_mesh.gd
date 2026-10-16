class_name StoneMesh
extends RefCounted
## Blocos de pedra esculpidos por código: caixa subdividida com chanfro
## arredondado, deformada por ruído e com lascas nas quinas. A cor de vértice
## guarda a cavidade (mesmo shader das rochas).

static var _cache: Dictionary[String, ArrayMesh] = {}


## Bloco de tamanho `size`. `wear` (0..1) = quanto as quinas estão gastas.
static func block(size: Vector3, seed_value: int, wear: float = 0.5, subdiv: int = 6) -> ArrayMesh:
	var key: String = "%s_%d_%.2f_%d" % [size, seed_value, wear, subdiv]
	if _cache.has(key):
		return _cache[key]
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 1.4
	n.fractal_octaves = 3
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: Vector3 = size * 0.5
	var bevel: float = minf(minf(size.x, size.y), size.z) * (0.12 + 0.18 * wear)
	# Seis faces de uma grade; cada vértice é projetado num "cubo arredondado".
	var faces: Array[Array] = [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	var base_index: int = 0
	for f: Array in faces:
		var normal: Vector3 = f[0]
		var u_axis: Vector3 = f[1]
		var v_axis: Vector3 = f[2]
		for j: int in subdiv + 1:
			for i: int in subdiv + 1:
				var u: float = float(i) / subdiv * 2.0 - 1.0
				var v: float = float(j) / subdiv * 2.0 - 1.0
				var p: Vector3 = normal + u_axis * v + v_axis * u
				p = Vector3(p.x * half.x, p.y * half.y, p.z * half.z)
				# Arredonda as quinas: aproxima do "núcleo" e empurra na direção da normal suave.
				var core: Vector3 = Vector3(clampf(p.x, -half.x + bevel, half.x - bevel),
					clampf(p.y, -half.y + bevel, half.y - bevel), clampf(p.z, -half.z + bevel, half.z - bevel))
				var dir: Vector3 = (p - core)
				if dir.length() > 0.0001:
					p = core + dir.normalized() * bevel
				var disp: float = n.get_noise_3dv(p * 1.3) * 0.05 * (0.6 + wear)
				var chip: float = maxf(0.0, n.get_noise_3dv(p * 3.1 + Vector3(9, 3, 1)) - 0.35) * 0.25 * wear
				var nrm_dir: Vector3 = (p - Vector3.ZERO).normalized()
				p += nrm_dir * (disp - chip)
				var cav: float = clampf(0.65 + disp * 4.0 - chip * 3.0, 0.2, 1.0)
				st.set_color(Color(cav, cav, cav))
				st.set_uv(Vector2(u, v))
				st.add_vertex(p)
		for j: int in subdiv:
			for i: int in subdiv:
				var a: int = base_index + j * (subdiv + 1) + i
				var b: int = a + 1
				var c: int = a + subdiv + 1
				var d: int = c + 1
				st.add_index(a)
				st.add_index(c)
				st.add_index(b)
				st.add_index(b)
				st.add_index(c)
				st.add_index(d)
		base_index += (subdiv + 1) * (subdiv + 1)
	st.generate_normals()
	st.generate_tangents()
	var mesh: ArrayMesh = st.commit()
	_cache[key] = mesh
	return mesh


## Tambor de coluna (perfil girado com caneluras e desgaste).
static func drum(radius: float, height: float, seed_value: int, flutes: int = 12) -> ArrayMesh:
	var key: String = "drum_%.2f_%.2f_%d" % [radius, height, seed_value]
	if _cache.has(key):
		return _cache[key]
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 2.0
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = flutes * 3
	var rings: int = 6
	for r: int in rings + 1:
		var t: float = float(r) / rings
		for s: int in sides + 1:
			var a: float = TAU * s / sides
			var flute: float = 1.0 - 0.06 * pow(absf(sin(a * flutes * 0.5)), 0.5)
			var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var wear_n: float = n.get_noise_3dv(dir * 2.0 + Vector3(0, t * 3.0, 0))
			var rad: float = radius * flute * (1.0 + wear_n * 0.05)
			var y: float = (t - 0.5) * height
			var p: Vector3 = dir * rad + Vector3.UP * y
			var cav: float = clampf(0.7 + wear_n * 0.6 + (flute - 0.97) * 4.0, 0.25, 1.0)
			st.set_color(Color(cav, cav, cav))
			st.set_uv(Vector2(float(s) / sides, t))
			st.add_vertex(p)
	for r: int in rings:
		for s: int in sides:
			var i0: int = r * (sides + 1) + s
			var i1: int = i0 + sides + 1
			st.add_index(i0)
			st.add_index(i0 + 1)
			st.add_index(i1)
			st.add_index(i0 + 1)
			st.add_index(i1 + 1)
			st.add_index(i1)
	# Tampas (o topo quebrado fica a cargo de quem empilha).
	var top_c: int = (rings + 1) * (sides + 1)
	for cap: float in [-0.5, 0.5]:
		st.set_color(Color(0.8, 0.8, 0.8))
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(Vector3(0, cap * height, 0))
	for s: int in sides:
		var lo0: int = s
		var lo1: int = s + 1
		var hi0: int = rings * (sides + 1) + s
		var hi1: int = hi0 + 1
		st.add_index(top_c)
		st.add_index(lo1)
		st.add_index(lo0)
		st.add_index(top_c + 1)
		st.add_index(hi0)
		st.add_index(hi1)
	st.generate_normals()
	st.generate_tangents()
	var mesh: ArrayMesh = st.commit()
	_cache[key] = mesh
	return mesh
