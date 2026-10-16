extends Node3D
## Cena de testes de atmosfera (M1): chão ondulado, rochas e o ciclo de dia.
## Tudo gerado por código a partir de uma seed fixa.

const GROUND_SHADER: Shader = preload("res://shaders/sandbox_ground.gdshader")
const SIZE: float = 240.0
const STEP: float = 2.0

var _noise: FastNoiseLite


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = 4242
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_build_ground()
	_build_rocks()
	if get_viewport().get_camera_3d() == null:
		var cam: Camera3D = Camera3D.new()
		cam.position = Vector3(0, 8, 30)
		cam.fov = 70.0
		add_child(cam)
		cam.look_at(Vector3(0, 3, 0))


func height_at(x: float, z: float) -> float:
	var h: float = _noise.get_noise_2d(x, z) * 6.0
	var ridge: float = smoothstep(40.0, 110.0, -z) * 18.0 * (0.6 + 0.4 * _noise.get_noise_2d(x * 2.0, 5.0))
	return h + ridge


func _build_ground() -> void:
	var n: int = int(SIZE / STEP) + 1
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in n:
		for i: int in n:
			var x: float = -SIZE * 0.5 + i * STEP
			var z: float = -SIZE * 0.5 + j * STEP
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, height_at(x, z), z))
	for j: int in n - 1:
		for i: int in n - 1:
			var a: int = j * n + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + n)
	st.generate_normals()
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter(&"detail_noise", Materials.detail_noise())
	mat.set_shader_parameter(&"detail_normal", Materials.detail_normal())
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


func _build_rocks() -> void:
	var rng: RandomNumberGenerator = Rng.make_rng(4242, "sandbox_rocks")
	var specs: Array[Array] = [
		[Vector3(-6, 0, -4), Vector3(5, 3.2, 4.2)], [Vector3(7, 0, -9), Vector3(8, 6, 7)],
		[Vector3(2, 0, 4), Vector3(1.6, 1.0, 1.4)], [Vector3(-14, 0, -18), Vector3(10, 9, 9)],
		[Vector3(18, 0, -30), Vector3(14, 12, 11)], [Vector3(-3, 0, 8), Vector3(1.0, 0.7, 1.1)],
	]
	var k: int = 0
	for s: Array in specs:
		var pos: Vector3 = s[0]
		var size: Vector3 = s[1]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = RockMesh.build(100 + k, size, 3, 0.32)
		mi.material_override = Materials.rock(0.5)
		pos.y = height_at(pos.x, pos.z)
		mi.position = pos
		mi.rotation.y = rng.randf() * TAU
		add_child(mi)
		k += 1
