class_name DetailMeshes
extends RefCounted
## Pequenos detalhes de chão gerados por código: flores, samambaias, arbustos e
## cogumelos bioluminescentes (roteiro 2.3). UV.y = altura relativa (vento).


## Flores: haste fina + corola de 5 pétalas (cards cruzados). Cor por vértice.
static func flower(seed_value: int, petal: Color) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: int in 3:
		var base: Vector3 = Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
		var h: float = rng.randf_range(0.22, 0.38)
		_stem(st, base, h, 0.008, Color("4f7a3a"))
		var top: Vector3 = base + Vector3(0, h, 0)
		for p: int in 5:
			var a: float = TAU * p / 5.0 + f
			var dir: Vector3 = Vector3(cos(a), 0.25, sin(a)).normalized()
			var side: Vector3 = Vector3(-sin(a), 0.0, cos(a)) * 0.025
			var tip: Vector3 = top + dir * 0.06
			_tri(st, top - side, top + side, tip, petal)
		_tri(st, top + Vector3(-0.012, 0.01, 0), top + Vector3(0.012, 0.01, 0), top + Vector3(0, 0.02, 0.012), Color("e8b44c"))
	return _commit(st)


## Samambaia: frondes arqueadas com folíolos.
static func fern(seed_value: int) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var green: Color = Color("3f6a2e")
	for f: int in 7:
		var a: float = TAU * f / 7.0 + rng.randf() * 0.4
		var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var length: float = rng.randf_range(0.5, 0.8)
		var prev: Vector3 = Vector3.ZERO
		for s: int in 8:
			var t: float = float(s + 1) / 8.0
			var p: Vector3 = dir * length * t + Vector3.UP * (sin(t * PI * 0.9) * 0.35)
			var w: float = 0.09 * sin(t * PI) + 0.01
			var shade: Color = green.lerp(Color("6f8f3a"), t * 0.5)
			_tri(st, prev, p, p + side * w + Vector3.DOWN * 0.03, shade)
			_tri(st, prev, p - side * w + Vector3.DOWN * 0.03, p, shade)
			prev = p
	return _commit(st)


## Arbusto: tufo de cards de folhas (usa a textura de folhagem das árvores).
static func bush(seed_value: int) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: int in 7:
		var center: Vector3 = Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.25, 0.6), rng.randf_range(-0.35, 0.35))
		var size: float = rng.randf_range(0.5, 0.8)
		for k: int in 2:
			var a: float = rng.randf() * PI + k * PI * 0.5
			var right: Vector3 = Vector3(cos(a), 0.0, sin(a)) * size * 0.5
			var up: Vector3 = Vector3.UP * size * 0.5
			var shade: Color = Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.25))
			var corners: Array[Vector3] = [center - right - up, center + right - up, center + right + up, center - right + up]
			var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal((corners[idx] - Vector3(0, -0.2, 0)).normalized())
				st.set_color(shade)
				st.set_uv(uvs[idx])
				st.add_vertex(corners[idx])
	var m: ArrayMesh = st.commit()
	m.surface_set_material(0, TreeMesh.leaf_material(TreeMesh.Species.OAK))
	return m


## Cogumelos: hastes + chapéus (perfil girado), com emissão no chapéu.
static func mushrooms(seed_value: int) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var caps: Array[Color] = [Color("b67cff"), Color("7fd6ff"), Color("8f6bff")]
	for m: int in rng.randi_range(3, 6):
		var cap: Color = caps[rng.randi_range(0, caps.size() - 1)]
		var base: Vector3 = Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
		var h: float = rng.randf_range(0.06, 0.2)
		var r: float = h * rng.randf_range(0.45, 0.8)
		_stem(st, base, h, r * 0.18, Color("d8d0c4"))
		var sides: int = 9
		var top: Vector3 = base + Vector3(0, h, 0)
		for k: int in sides:
			var a0: float = TAU * k / sides
			var a1: float = TAU * (k + 1) / sides
			var p0: Vector3 = top + Vector3(cos(a0) * r, -r * 0.25, sin(a0) * r)
			var p1: Vector3 = top + Vector3(cos(a1) * r, -r * 0.25, sin(a1) * r)
			_tri(st, top + Vector3(0, r * 0.45, 0), p1, p0, cap)
			_tri(st, top, p0, p1, cap.darkened(0.4))
	return _commit(st)


static func _stem(st: SurfaceTool, base: Vector3, h: float, r: float, c: Color) -> void:
	for k: int in 4:
		var a0: float = TAU * k / 4.0
		var a1: float = TAU * (k + 1) / 4.0
		var o0: Vector3 = Vector3(cos(a0), 0, sin(a0)) * r
		var o1: Vector3 = Vector3(cos(a1), 0, sin(a1)) * r
		_tri(st, base + o0, base + o1, base + o1 + Vector3(0, h, 0), c)
		_tri(st, base + o0, base + o1 + Vector3(0, h, 0), base + o0 + Vector3(0, h, 0), c)


## Triângulo com normal voltada para cima e UV.y = altura (0..1 em 0,5 m), usada pelo vento.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	for v: Vector3 in [a, b, c]:
		st.set_normal(-n if n.y < 0.0 else n)
		st.set_color(col)
		st.set_uv(Vector2(0.0, clampf(v.y / 0.5, 0.0, 1.0)))
		st.add_vertex(v)


static func _commit(st: SurfaceTool) -> ArrayMesh:
	return st.commit()
