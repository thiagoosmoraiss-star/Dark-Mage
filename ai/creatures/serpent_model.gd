class_name SerpentModel
extends CreatureModel
## Serpente do Lago: pescoço segmentado (escamas por shader de rocha tingido),
## cabeça com mandíbula e olhos verdes. Ondula; ergue-se ao emergir.

const SEGMENTS: int = 11

var segs: Array[Node3D] = []
var head: Node3D
var jaw: Node3D
var emerge: float = 0.0  # 0 submersa .. 1 erguida


func build(data: EnemyData) -> void:
	var scales: ShaderMaterial = Materials.rock(0.0, 0.0).duplicate() as ShaderMaterial
	scales.set_shader_parameter(&"stone_light", Color("3f6a64"))
	scales.set_shader_parameter(&"stone_dark", Color("16262a"))
	scales.set_shader_parameter(&"detail_scale", 3.5)
	for i: int in SEGMENTS:
		var t: float = float(i) / (SEGMENTS - 1)
		var r: float = lerpf(0.75, 0.42, t)
		var seg: Node3D = Node3D.new()
		add_child(seg)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = RockMesh.build(80 + i % 3, Vector3(r * 2.0, r * 1.7, r * 2.2), 2, 0.08)
		mi.material_override = scales
		seg.add_child(mi)
		# Barbatana dorsal violeta.
		var fin: MeshInstance3D = MeshInstance3D.new()
		fin.mesh = MageLook.crystal_mesh(0.08, r * 1.3, 3)
		fin.material_override = MageLook.crystal_material()
		fin.position = Vector3(0, r * 0.85, 0)
		fin.rotation.x = -0.4
		seg.add_child(fin)
		segs.append(seg)
	head = Node3D.new()
	add_child(head)
	var skull: MeshInstance3D = MeshInstance3D.new()
	skull.mesh = RockMesh.build(90, Vector3(0.9, 0.6, 1.3), 2, 0.12)
	skull.material_override = scales
	head.add_child(skull)
	jaw = Node3D.new()
	jaw.position = Vector3(0, -0.15, -0.2)
	head.add_child(jaw)
	var jaw_mi: MeshInstance3D = MeshInstance3D.new()
	jaw_mi.mesh = RockMesh.build(91, Vector3(0.7, 0.25, 1.0), 2, 0.1)
	jaw_mi.material_override = scales
	jaw_mi.position = Vector3(0, 0, -0.35)
	jaw.add_child(jaw_mi)
	for side: float in [-1.0, 1.0]:
		var eye: MeshInstance3D = make_eye(data.eye_color, 0.16)
		eye.position = Vector3(side * 0.28, 0.12, -0.45)
		head.add_child(eye)
	var flash_mat: StandardMaterial3D = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1, 1, 1, 0)
	flash_mats.append(flash_mat)
	scale = Vector3.ONE * data.model_scale


func _process(delta: float) -> void:
	super._process(delta)
	var want: float = 0.0 if anim_state == &"submerged" else 1.0
	emerge = move_toward(emerge, want, delta * 0.9)


func animate(_delta: float) -> void:
	var t: float = anim_time
	var height: float = lerpf(-3.5, 4.2, emerge)
	var prev: Vector3 = Vector3(0, -2.5, 1.6)
	for i: int in SEGMENTS:
		var u: float = float(i) / (SEGMENTS - 1)
		var y: float = lerpf(-2.5, height, smoothstep(0.0, 1.0, u))
		var sway: float = sin(t * 2.0 - u * 4.0) * 0.5 * (1.0 - u * 0.4)
		var p: Vector3 = Vector3(sway, y, lerpf(1.6, -0.4, u))
		segs[i].position = p
		var dir: Vector3 = (p - prev).normalized() if i > 0 else Vector3.UP
		if dir.length() > 0.01:
			segs[i].basis = Basis(Quaternion(Vector3.UP, dir))
		prev = p
	head.position = prev + Vector3(0, 0.35, -0.5)
	head.rotation.x = -0.2 + (0.35 if anim_state == &"windup" else 0.0)
	jaw.rotation.x = 0.55 if anim_state == &"windup" or anim_state == &"spit" else 0.05 + sin(t * 1.5) * 0.04
