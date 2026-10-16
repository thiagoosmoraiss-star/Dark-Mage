class_name GrassMesh
extends RefCounted
## Tufo de grama: lâminas curvas e afinando, em leque. UV.y = altura relativa
## (usada pelo shader para vento e cor).


static func build(blades: int = 14, height: float = 0.42, width: float = 0.028, seed_value: int = 3) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 4
	for b: int in blades:
		var ang: float = rng.randf() * TAU
		var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var origin: Vector3 = dir * rng.randf_range(0.0, 0.22)
		var h: float = height * rng.randf_range(0.6, 1.15)
		var lean: float = rng.randf_range(0.15, 0.45)
		var w: float = width * rng.randf_range(0.8, 1.3)
		var base_index: int = b * (segs + 1) * 2
		for s: int in segs + 1:
			var t: float = float(s) / segs
			var center: Vector3 = origin + Vector3.UP * (h * t) + dir * (lean * h * t * t)
			var half: float = w * (1.0 - t * 0.92) * 0.5
			var nrm: Vector3 = (dir * -0.4 + Vector3.UP).normalized()
			st.set_normal(nrm)
			st.set_uv(Vector2(0.0, t))
			st.add_vertex(center - side * half)
			st.set_normal(nrm)
			st.set_uv(Vector2(1.0, t))
			st.add_vertex(center + side * half)
		for s: int in segs:
			var i0: int = base_index + s * 2
			st.add_index(i0)
			st.add_index(i0 + 2)
			st.add_index(i0 + 1)
			st.add_index(i0 + 1)
			st.add_index(i0 + 2)
			st.add_index(i0 + 3)
	return st.commit()
