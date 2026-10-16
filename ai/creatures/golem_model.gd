class_name GolemModel
extends CreatureModel
## Golem de Pedra Corrompida: rochas esculpidas articuladas (tronco, cabeça,
## braços, pernas), musgo escurecido e um cristal violeta pulsante nas costas
## (ponto fraco). Animação procedural de passo pesado e golpe de duas mãos.

var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var weak_point: MeshInstance3D


func build(data: EnemyData) -> void:
	var rock: ShaderMaterial = Materials.rock(0.35, 0.7).duplicate() as ShaderMaterial
	rock.set_shader_parameter(&"stone_light", data.tint if data.tint != Color(0.85, 0.82, 0.9) else Color("8d857f"))
	torso = _part(Vector3(0, 1.7, 0), RockMesh.build(61, Vector3(1.9, 1.6, 1.3), 3, 0.28), rock)
	head = _part(Vector3(0, 0.95, -0.25), RockMesh.build(62, Vector3(0.75, 0.6, 0.7), 2, 0.25), rock, torso)
	arm_l = _limb(torso, Vector3(-1.15, 0.45, 0), rock, 63)
	arm_r = _limb(torso, Vector3(1.15, 0.45, 0), rock, 64)
	leg_l = _part(Vector3(-0.5, 0.75, 0), RockMesh.build(65, Vector3(0.7, 1.1, 0.75), 2, 0.25), rock)
	leg_r = _part(Vector3(0.5, 0.75, 0), RockMesh.build(66, Vector3(0.7, 1.1, 0.75), 2, 0.25), rock)
	(leg_l.get_child(0) as Node3D).position.y = -0.5
	(leg_r.get_child(0) as Node3D).position.y = -0.5
	for side: float in [-1.0, 1.0]:
		var eye: MeshInstance3D = make_eye(data.eye_color, 0.16)
		eye.position = Vector3(side * 0.16, 0.05, -0.33)
		head.add_child(eye)
	# Ponto fraco: cristal nas costas.
	weak_point = MeshInstance3D.new()
	weak_point.mesh = MageLook.crystal_mesh(0.22, 0.7, 6)
	var cm: StandardMaterial3D = MageLook.crystal_material().duplicate() as StandardMaterial3D
	cm.emission_energy_multiplier = 4.0
	weak_point.material_override = cm
	eye_mats.append(cm)
	weak_point.position = Vector3(0, 0.3, 0.62)
	weak_point.rotation.x = 0.6
	torso.add_child(weak_point)
	var flash_mat: StandardMaterial3D = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1, 1, 1, 0)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1, 1, 1)
	flash_mats.append(flash_mat)
	for mi: Node in find_children("*", "MeshInstance3D", true, false):
		var mo: Material = (mi as MeshInstance3D).material_override
		var is_eye: bool = mo is StandardMaterial3D and eye_mats.has(mo as StandardMaterial3D)
		if mi != weak_point and not is_eye:
			(mi as MeshInstance3D).material_overlay = flash_mat
	scale = Vector3.ONE * data.model_scale


func _part(pos: Vector3, mesh: Mesh, mat: Material, parent: Node3D = null) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = pos
	(parent if parent != null else self).add_child(pivot)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	pivot.add_child(mi)
	return pivot


func _limb(parent: Node3D, pos: Vector3, mat: Material, seed_value: int) -> Node3D:
	var shoulder: Node3D = _part(pos, RockMesh.build(seed_value, Vector3(0.75, 0.75, 0.75), 2, 0.25), mat, parent)
	var fore: Node3D = _part(Vector3(0, -0.9, 0), RockMesh.build(seed_value + 10, Vector3(0.65, 1.1, 0.65), 2, 0.25), mat, shoulder)
	_part(Vector3(0, -0.75, 0), RockMesh.build(seed_value + 20, Vector3(0.85, 0.6, 0.85), 2, 0.25), mat, fore)
	return shoulder


func animate(_delta: float) -> void:
	var t: float = anim_time
	match anim_state:
		&"walk", &"chase":
			var sp: float = 3.2 if anim_state == &"chase" else 2.2
			leg_l.rotation.x = sin(t * sp) * 0.45
			leg_r.rotation.x = -sin(t * sp) * 0.45
			arm_l.rotation.x = -sin(t * sp) * 0.35
			arm_r.rotation.x = sin(t * sp) * 0.35
			torso.position.y = 1.7 + absf(sin(t * sp)) * 0.08
			torso.rotation.z = sin(t * sp) * 0.05
		&"windup":
			var k: float = clampf(t / 1.1, 0.0, 1.0)
			arm_l.rotation.x = lerpf(0.0, -2.6, k)
			arm_r.rotation.x = lerpf(0.0, -2.6, k)
			torso.rotation.x = lerpf(0.0, 0.25, k)
		&"slam":
			var k2: float = clampf(t / 0.18, 0.0, 1.0)
			arm_l.rotation.x = lerpf(-2.6, 0.9, k2)
			arm_r.rotation.x = lerpf(-2.6, 0.9, k2)
			torso.rotation.x = lerpf(0.25, -0.35, k2)
		_:
			leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, 0.1)
			leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, 0.1)
			arm_l.rotation.x = lerpf(arm_l.rotation.x, 0.0, 0.1) + sin(t * 0.8) * 0.02
			arm_r.rotation.x = lerpf(arm_r.rotation.x, 0.0, 0.1) - sin(t * 0.8) * 0.02
			torso.rotation.x = lerpf(torso.rotation.x, 0.0, 0.1)
			torso.position.y = 1.7 + sin(t * 1.2) * 0.03
	weak_point.scale = Vector3.ONE * (1.0 + sin(t * 4.0) * 0.08)
