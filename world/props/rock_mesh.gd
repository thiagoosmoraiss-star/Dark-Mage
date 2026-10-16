class_name RockMesh
extends RefCounted
## Rochas esculpidas por código: icosfera subdividida, deformada por ruído 3D
## (fBm + ridged), achatada na base e com normais suaves. A cor de vértice
## guarda a cavidade (AO aproximado) usada pelo shader de rocha.

const PHI: float = 1.618033988749895


static func build(seed_value: int, size: Vector3 = Vector3(2.0, 1.4, 2.0), subdivisions: int = 3,
		roughness: float = 0.35) -> ArrayMesh:
	var verts: PackedVector3Array = []
	var faces: Array[Vector3i] = []
	_icosahedron(verts, faces)
	for i: int in subdivisions:
		faces = _subdivide(verts, faces)

	var n_base: FastNoiseLite = FastNoiseLite.new()
	n_base.seed = seed_value
	n_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_base.frequency = 0.9
	n_base.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_base.fractal_octaves = 4
	var n_ridge: FastNoiseLite = FastNoiseLite.new()
	n_ridge.seed = seed_value * 31 + 7
	n_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_ridge.frequency = 1.6
	n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n_ridge.fractal_octaves = 3

	# Cortes planos aleatórios dão aspecto de rocha fraturada.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var planes: Array[Plane] = []
	for i: int in 4:
		var nrm: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1.0), rng.randf_range(-1, 1)).normalized()
		planes.append(Plane(nrm, rng.randf_range(0.72, 0.92)))

	var colors: PackedColorArray = []
	colors.resize(verts.size())
	for i: int in verts.size():
		var d: Vector3 = verts[i]
		var disp: float = n_base.get_noise_3dv(d * 1.3) * roughness + n_ridge.get_noise_3dv(d * 2.0) * roughness * 0.45
		var p: Vector3 = d * (1.0 + disp)
		for pl: Plane in planes:
			var dist: float = pl.distance_to(p)
			if dist > 0.0:
				p -= pl.normal * dist * 0.85
		p = Vector3(p.x * size.x, p.y * size.y, p.z * size.z) * 0.5
		if p.y < -size.y * 0.22:  # base achatada para assentar no chão
			p.y = lerpf(p.y, -size.y * 0.22, 0.85)
		verts[i] = p
		var cav: float = clampf(0.55 + disp * 1.6, 0.0, 1.0)
		colors[i] = Color(cav, cav, cav)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in verts.size():
		st.set_color(colors[i])
		st.set_uv(Vector2(verts[i].x, verts[i].z))
		st.add_vertex(verts[i])
	for f: Vector3i in faces:
		st.add_index(f.x)
		st.add_index(f.z)
		st.add_index(f.y)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _icosahedron(verts: PackedVector3Array, faces: Array[Vector3i]) -> void:
	var raw: Array[Vector3] = [
		Vector3(-1, PHI, 0), Vector3(1, PHI, 0), Vector3(-1, -PHI, 0), Vector3(1, -PHI, 0),
		Vector3(0, -1, PHI), Vector3(0, 1, PHI), Vector3(0, -1, -PHI), Vector3(0, 1, -PHI),
		Vector3(PHI, 0, -1), Vector3(PHI, 0, 1), Vector3(-PHI, 0, -1), Vector3(-PHI, 0, 1),
	]
	for v: Vector3 in raw:
		verts.append(v.normalized())
	var idx: Array[Vector3i] = [
		Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
		Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
		Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
		Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1),
	]
	faces.append_array(idx)


static func _subdivide(verts: PackedVector3Array, faces: Array[Vector3i]) -> Array[Vector3i]:
	var cache: Dictionary[int, int] = {}
	var out: Array[Vector3i] = []
	for f: Vector3i in faces:
		var a: int = _midpoint(verts, cache, f.x, f.y)
		var b: int = _midpoint(verts, cache, f.y, f.z)
		var c: int = _midpoint(verts, cache, f.z, f.x)
		out.append(Vector3i(f.x, a, c))
		out.append(Vector3i(f.y, b, a))
		out.append(Vector3i(f.z, c, b))
		out.append(Vector3i(a, b, c))
	return out


static func _midpoint(verts: PackedVector3Array, cache: Dictionary[int, int], i: int, j: int) -> int:
	var key: int = mini(i, j) * 1000003 + maxi(i, j)
	if cache.has(key):
		return cache[key]
	verts.append(((verts[i] + verts[j]) * 0.5).normalized())
	cache[key] = verts.size() - 1
	return verts.size() - 1
