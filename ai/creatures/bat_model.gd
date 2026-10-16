class_name BatModel
extends CreatureModel
## Morcego Espectral: corpo escuro translúcido com borda violeta, orelhas e asas
## de membrana recortada que batem (mais rápido no mergulho).

var _wing_l: Node3D
var _wing_r: Node3D
var _body: Node3D


func build(data: EnemyData) -> void:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = preload("res://shaders/spectral.gdshader")
	var nt: NoiseTexture2D = NoiseTexture2D.new()
	nt.seamless = true
	nt.noise = FastNoiseLite.new()
	mat.set_shader_parameter(&"noise_tex", nt)
	flash_mats.append(mat)
	_body = Node3D.new()
	add_child(_body)
	var torso: MeshInstance3D = MeshInstance3D.new()
	torso.mesh = RockMesh.build(41, Vector3(0.42, 0.38, 0.62), 2, 0.12)
	torso.material_override = mat
	_body.add_child(torso)
	var head: MeshInstance3D = MeshInstance3D.new()
	head.mesh = RockMesh.build(42, Vector3(0.3, 0.28, 0.3), 2, 0.1)
	head.material_override = mat
	head.position = Vector3(0, 0.08, -0.36)
	_body.add_child(head)
	for side: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = MeshInstance3D.new()
		ear.mesh = MageLook.crystal_mesh(0.05, 0.22, 4)
		ear.material_override = mat
		ear.position = Vector3(side * 0.09, 0.24, -0.38)
		ear.rotation.z = -side * 0.35
		_body.add_child(ear)
		var eye: MeshInstance3D = make_eye(data.eye_color, 0.09)
		eye.position = Vector3(side * 0.07, 0.1, -0.5)
		_body.add_child(eye)
	_wing_l = _make_wing(mat, -1.0)
	_wing_r = _make_wing(mat, 1.0)
	scale = Vector3.ONE * data.model_scale


func _make_wing(mat: Material, side: float) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = Vector3(side * 0.16, 0.05, -0.05)
	_body.add_child(pivot)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Membrana: leque de "dedos" com borda recortada entre eles.
	var fingers: int = 4
	var root: Vector3 = Vector3.ZERO
	var prev_tip: Vector3 = Vector3(0, 0, 0.3)
	for f: int in fingers + 1:
		var t: float = float(f) / fingers
		var ang: float = lerpf(-0.2, 1.3, t)
		var length: float = lerpf(0.55, 1.05, sin(t * PI * 0.9))
		var tip: Vector3 = Vector3(side * cos(ang) * length, sin(t * PI) * 0.12, -sin(ang) * length * 0.55 + 0.25)
		if f > 0:
			var mid: Vector3 = (prev_tip + tip) * 0.5 * 0.72
			for tri: Array in [[root, prev_tip, mid], [root, mid, tip]]:
				for v: Vector3 in tri:
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(absf(v.x), v.z))
					st.add_vertex(v)
		prev_tip = tip
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	var wm: ShaderMaterial = (mat as ShaderMaterial).duplicate() as ShaderMaterial
	wm.render_priority = 1
	mi.material_override = wm
	flash_mats.append(wm)
	pivot.add_child(mi)
	return pivot


func animate(_delta: float) -> void:
	var speed: float = 14.0 if anim_state == &"dive" else (9.0 if anim_state == &"chase" else 6.5)
	var flap: float = sin(anim_time * speed) * 0.75
	_wing_l.rotation.z = flap
	_wing_r.rotation.z = -flap
	_body.position.y = sin(anim_time * speed + 1.2) * 0.06
	_body.rotation.x = -0.5 if anim_state == &"dive" else 0.0
