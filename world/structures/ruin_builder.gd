class_name RuinBuilder
extends RefCounted
## Monta ruínas e torres a partir de blocos esculpidos (StoneMesh), assentadas
## no terreno, com colisão simples (caixas/cilindros) para escalada e navegação.

const L = preload("res://world/island/island_layout.gd")


static func stone_material(moss: float = 0.55, corruption: float = 0.0) -> ShaderMaterial:
	var m: ShaderMaterial = Materials.rock(moss, corruption).duplicate() as ShaderMaterial
	m.set_shader_parameter(&"stone_light", Color("c9bfa8"))
	m.set_shader_parameter(&"stone_dark", Color("5a544f"))
	m.set_shader_parameter(&"detail_scale", 0.6)
	return m


## Ruína do vale: colunata em semicírculo, muro partido, arco e blocos caídos.
static func build_ruin(parent: Node3D, center: Vector3, seed_value: int, terrain: IslandTerrain, corruption: float = 0.0) -> Node3D:
	var root: StaticBody3D = StaticBody3D.new()
	root.name = "Ruin_%d" % seed_value
	root.collision_layer = 1
	root.add_to_group(&"structure")
	parent.add_child(root)
	root.global_position = center
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var mat: ShaderMaterial = stone_material(0.6, corruption)
	# Colunata.
	var cols: int = 7
	for i: int in cols:
		var a: float = PI * (0.1 + 0.8 * float(i) / (cols - 1))
		var p: Vector3 = Vector3(cos(a) * 9.0, 0.0, -sin(a) * 9.0)
		var drums: int = rng.randi_range(1, 5)
		if i == 3:
			drums = 6
		_column(root, p, drums, rng, mat, terrain)
	# Muro partido ao fundo.
	var wall_len: int = 7
	for i: int in wall_len:
		var h: int = maxi(1, 4 - absi(i - 2) + rng.randi_range(-1, 1))
		for k: int in h:
			var size: Vector3 = Vector3(1.4, 0.75, 0.9) * rng.randf_range(0.92, 1.08)
			var lp: Vector3 = Vector3(-6.0 + i * 1.45 + rng.randf_range(-0.05, 0.05), 0.0, -12.5)
			_block(root, lp, size, k * 0.76 + 0.38, rng.randf_range(-0.04, 0.04), rng.randi(), mat, terrain)
	# Arco de entrada.
	_arch(root, Vector3(0.0, 0.0, 4.5), rng, mat, terrain)
	# Blocos caídos e espalhados.
	for i: int in 9:
		var p: Vector3 = Vector3(rng.randf_range(-11, 11), 0.0, rng.randf_range(-12, 6))
		var size: Vector3 = Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(0.5, 0.9), rng.randf_range(0.7, 1.2))
		_block(root, p, size, size.y * 0.3, rng.randf_range(-0.5, 0.5), rng.randi(), mat, terrain, true)
	return root


static func _ground(root: Node3D, local: Vector3, terrain: IslandTerrain) -> float:
	var world: Vector3 = root.global_position + root.global_basis * local
	return (terrain.height_at(world) if terrain != null else root.global_position.y) - root.global_position.y


static func _block(root: StaticBody3D, local: Vector3, size: Vector3, lift: float, tilt: float, seed_value: int,
		mat: Material, terrain: IslandTerrain, fallen: bool = false) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = StoneMesh.block(size, seed_value % 6, 0.6, 5)
	mi.material_override = mat
	var y: float = _ground(root, local, terrain) + lift
	mi.position = Vector3(local.x, y, local.z)
	mi.rotation = Vector3(tilt * 0.5 if fallen else 0.0, tilt, tilt * 0.3 if fallen else 0.0)
	root.add_child(mi)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size * 0.96
	cs.shape = box
	cs.transform = mi.transform
	root.add_child(cs)


static func _column(root: StaticBody3D, local: Vector3, drums: int, rng: RandomNumberGenerator, mat: Material, terrain: IslandTerrain) -> void:
	var base_y: float = _ground(root, local, terrain)
	# Base quadrada.
	var base: MeshInstance3D = MeshInstance3D.new()
	base.mesh = StoneMesh.block(Vector3(1.5, 0.45, 1.5), 3, 0.5, 5)
	base.material_override = mat
	base.position = Vector3(local.x, base_y + 0.15, local.z)
	root.add_child(base)
	var drum_h: float = 1.1
	for k: int in drums:
		var d: MeshInstance3D = MeshInstance3D.new()
		d.mesh = StoneMesh.drum(0.5, drum_h, rng.randi_range(0, 3))
		d.material_override = mat
		d.position = Vector3(local.x + rng.randf_range(-0.04, 0.04), base_y + 0.4 + drum_h * (k + 0.5), local.z)
		d.rotation.y = rng.randf() * TAU
		root.add_child(d)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = 0.4 + drum_h * drums
	cs.shape = cyl
	cs.position = Vector3(local.x, base_y + cyl.height * 0.5, local.z)
	root.add_child(cs)
	if drums >= 5:
		var cap: MeshInstance3D = MeshInstance3D.new()
		cap.mesh = StoneMesh.block(Vector3(1.4, 0.4, 1.4), 2, 0.4, 5)
		cap.material_override = mat
		cap.position = Vector3(local.x, base_y + 0.4 + drum_h * drums + 0.2, local.z)
		root.add_child(cap)


static func _arch(root: StaticBody3D, local: Vector3, rng: RandomNumberGenerator, mat: Material, terrain: IslandTerrain) -> void:
	var span: float = 3.4
	for side: float in [-1.0, 1.0]:
		for k: int in 4:
			_block(root, local + Vector3(side * span * 0.5, 0, 0), Vector3(0.9, 0.8, 1.0), 0.4 + k * 0.82,
				rng.randf_range(-0.03, 0.03), rng.randi(), mat, terrain)
	# Aduelas do arco (uma falta: ruína).
	var segs: int = 7
	# Pilares: 4 blocos de 0,82 m a partir de 0,4 m -> topo em ~3,7 m; o arco nasce ali.
	var base_y: float = _ground(root, local, terrain) + 3.62 - sin(PI * 0.5 / segs) * span * 0.5
	for i: int in segs:
		if i == 5:
			continue
		var a: float = PI * (float(i) + 0.5) / segs
		var p: Vector3 = local + Vector3(-cos(a) * span * 0.5, 0.0, 0.0)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = StoneMesh.block(Vector3(0.8, 0.55, 1.0), i % 4, 0.5, 5)
		mi.material_override = mat
		mi.position = Vector3(p.x, base_y + sin(a) * span * 0.5, p.z)
		mi.rotation.z = a - PI * 0.5
		root.add_child(mi)


## Torre do Farol Arcano: anéis de blocos (MultiMesh) que afinam, janelas,
## plataforma no topo com braseiro e cristal. Colisão em cilindros empilhados.
static func build_beacon_tower(parent: Node3D, center: Vector3, seed_value: int, height: float = 24.0) -> StaticBody3D:
	var root: StaticBody3D = StaticBody3D.new()
	root.name = "BeaconTower_%d" % seed_value
	root.collision_layer = 1
	root.add_to_group(&"structure")
	parent.add_child(root)
	root.global_position = center
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var mat: ShaderMaterial = stone_material(0.45)
	var block_h: float = 0.8
	var rings: int = int(height / block_h)
	var xforms: Array[Transform3D] = []
	for r: int in rings:
		var t: float = float(r) / rings
		var radius: float = lerpf(3.6, 2.5, t)
		var count: int = 14
		for k: int in count:
			var a: float = TAU * (k + 0.5 * (r % 2)) / count
			# Janelas: faltam blocos em alguns anéis.
			if r % 7 == 4 and k % 7 == 0:
				continue
			var p: Vector3 = Vector3(cos(a) * radius, r * block_h + block_h * 0.5, sin(a) * radius)
			var b: Basis = Basis(Vector3.UP, -a + PI * 0.5).scaled(Vector3(radius * TAU / count / 1.5 * 1.02, 1.0, 1.0))
			b = b.rotated(Vector3.UP, rng.randf_range(-0.02, 0.02))
			xforms.append(Transform3D(b, p))
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = StoneMesh.block(Vector3(1.5, block_h * 0.98, 1.1), 1, 0.45, 4)
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	root.add_child(mmi)
	# Plataforma e ameias.
	var top_y: float = rings * block_h
	for k: int in 10:
		var a: float = TAU * k / 10.0
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = StoneMesh.block(Vector3(1.2, 0.9, 0.8), k % 4, 0.6, 4)
		mi.material_override = mat
		mi.position = Vector3(cos(a) * 2.9, top_y + 0.45, sin(a) * 2.9)
		mi.rotation.y = -a + PI * 0.5
		root.add_child(mi)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	floor_mi.mesh = StoneMesh.drum(3.1, 0.4, 5, 24)
	floor_mi.material_override = mat
	floor_mi.position = Vector3(0, top_y - 0.2, 0)
	root.add_child(floor_mi)
	# Colisão: tronco de cone aproximado por cilindros.
	for seg: int in 4:
		var t0: float = float(seg) / 4.0
		var cs: CollisionShape3D = CollisionShape3D.new()
		var cyl: CylinderShape3D = CylinderShape3D.new()
		cyl.radius = lerpf(3.9, 2.8, t0 + 0.125)
		cyl.height = height / 4.0
		cs.shape = cyl
		cs.position = Vector3(0, height * (t0 + 0.125), 0)
		root.add_child(cs)
	var top_cs: CollisionShape3D = CollisionShape3D.new()
	var top_cyl: CylinderShape3D = CylinderShape3D.new()
	top_cyl.radius = 3.2
	top_cyl.height = 0.4
	top_cs.shape = top_cyl
	top_cs.position = Vector3(0, top_y - 0.2, 0)
	root.add_child(top_cs)
	root.set_meta(&"top_y", top_y)
	return root
