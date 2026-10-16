class_name MageLook
extends RefCounted
## Adapta o modelo KayKit Mage à direção de arte: manto preto com detalhes
## dourados, cajado próprio com cristal violeta que emite luz, capa longa e
## olhos com brilho violeta (roteiro 2.4).

const VIOLET: Color = Color("6b2fd6")
const VIOLET_GLOW: Color = Color("b67cff")
const GOLD: Color = Color("e8b44c")
const ROBE_BLACK: Color = Color("17121f")

const BONE_RIGHT_HAND: Array[String] = ["handslot.r", "hand.r", "Hand.R", "wrist.r"]
const BONE_CHEST: Array[String] = ["chest", "Chest", "spine.001", "spine"]
const BONE_HEAD: Array[String] = ["head", "Head"]
## Itens que o pacote KayKit pendura no esqueleto e que não usamos.
const HIDE_MESHES: Array[String] = ["Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff"]

## Atlas KayKit: grade 8×4 de faixas de gradiente (128×256 px cada).
## Faixa (coluna, linha) -> [cor do topo, cor da base] na paleta do jogo.
const SWATCH_REMAP: Dictionary = {
	Vector2i(0, 1): [Color("3b2b5e"), Color("0b0910")],  # manto (lilás -> preto-violeta)
	Vector2i(1, 1): [Color("3b2b5e"), Color("0b0910")],
	Vector2i(7, 1): [Color("2a1f45"), Color("0b0910")],  # azul-marinho -> violeta escuro
	Vector2i(0, 3): [Color("f2cf72"), Color("a5701f")],  # amarelos -> dourado antigo
	Vector2i(2, 3): [Color("f2cf72"), Color("9c6a1c")],
	Vector2i(1, 3): [Color("d9a442"), Color("6e3f12")],
	Vector2i(0, 0): [Color("d8d0cc"), Color("a8a0aa")],  # pele -> pálida acinzentada
	Vector2i(7, 2): [Color("d8d0cc"), Color("a8a0aa")],
	Vector2i(6, 3): [Color("d8d0cc"), Color("9c90a0")],
	Vector2i(7, 3): [Color("d8d0cc"), Color("9c90a0")],
	Vector2i(5, 0): [Color("f2cf72"), Color("8a5a18")],  # laranja (faixa do chapéu) -> dourado
	Vector2i(4, 3): [Color("8a2433"), Color("3a0d18")],  # vermelho (cinto) -> bordô
	Vector2i(2, 1): [Color("5b2a9e"), Color("1e0f38")],  # magenta (forro da capa) -> violeta
	Vector2i(1, 2): [Color("5b2a9e"), Color("1e0f38")],
	Vector2i(6, 0): [Color("5a4034"), Color("1f1612")],  # couro -> couro escuro
}


static func find_bone(skel: Skeleton3D, names: Array[String]) -> int:
	if skel == null:
		return -1
	for n: String in names:
		var i: int = skel.find_bone(n)
		if i >= 0:
			return i
	return -1


## Recolore o atlas do personagem (ver MageLook.remap_color) e esconde acessórios.
static func apply(root: Node3D, _skel: Skeleton3D) -> void:
	var done: Dictionary = {}
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		for h: String in HIDE_MESHES:
			if mi.name == h:
				mi.visible = false
		if not mi.visible or mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var mat: BaseMaterial3D = mi.get_active_material(s) as BaseMaterial3D
			if mat == null:
				continue
			var key: int = mat.get_instance_id()
			if not done.has(key):
				done[key] = _recolored(mat)
			mi.set_surface_override_material(s, done[key] as Material)


static func _recolored(src: BaseMaterial3D) -> StandardMaterial3D:
	var m: StandardMaterial3D = src.duplicate() as StandardMaterial3D
	if m == null:
		m = StandardMaterial3D.new()
	var tex: Texture2D = src.albedo_texture
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			remap_atlas(img)
			img.generate_mipmaps()
			m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.82
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


## Repinta as faixas do atlas mantendo a modulação original (o filete claro de
## cada faixa vira um realce proporcional na nova cor).
static func remap_atlas(img: Image) -> void:
	var cw: int = img.get_width() / 8
	var ch: int = img.get_height() / 4
	for cell: Vector2i in SWATCH_REMAP:
		var pair: Array = SWATCH_REMAP[cell]
		var top: Color = pair[0]
		var bottom: Color = pair[1]
		var x0: int = cell.x * cw
		var y0: int = cell.y * ch
		for y: int in ch:
			var t: float = float(y) / (ch - 1)
			var target: Color = top.lerp(bottom, t)
			var ref: Color = img.get_pixel(x0 + 4, y0 + y)
			var ref_v: float = maxf(ref.v, 0.02)
			for x: int in cw:
				var c: Color = img.get_pixel(x0 + x, y0 + y)
				var k: float = clampf(c.v / ref_v, 0.6, 1.6)
				img.set_pixel(x0 + x, y0 + y, Color(target.r * k, target.g * k, target.b * k, c.a))


# --- Cajado --------------------------------------------------------------------

## Cajado próprio (haste, garras douradas e cristal com luz real) preso ao
## osso da mão direita. No KayKit o eixo +Z do handslot aponta para cima.
static func attach_staff(skel: Skeleton3D) -> OmniLight3D:
	var bone: int = find_bone(skel, BONE_RIGHT_HAND)
	if bone < 0:
		return null
	var att: BoneAttachment3D = BoneAttachment3D.new()
	att.name = "StaffSlot"
	att.bone_idx = bone
	skel.add_child(att)
	var staff: Node3D = build_staff()
	staff.scale = Vector3.ONE * 1.5  # o rig do KayKit tem escala própria
	att.add_child(staff)
	return staff.get_node(^"CrystalLight") as OmniLight3D


## Alinha o cajado com a vertical do mundo (levemente inclinado para a frente)
## na pose atual da mão. Chamado depois de a animação de idle ser aplicada; a
## partir daí o cajado acompanha a mão.
static func align_staff(staff: Node3D, character_forward: Vector3) -> void:
	var parent: Node3D = staff.get_parent() as Node3D
	if parent == null:
		return
	var want_world: Vector3 = (Vector3.UP + character_forward.normalized() * 0.18).normalized()
	var local_up: Vector3 = (parent.global_basis.inverse() * want_world).normalized()
	var s: Vector3 = staff.scale
	staff.basis = Basis(Quaternion(Vector3.UP, local_up)).scaled(s)


static func build_staff() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Staff"
	# Haste de madeira escura, levemente torta e com nós.
	var shaft: MeshInstance3D = MeshInstance3D.new()
	shaft.name = "Shaft"
	shaft.mesh = _lathe_shaft(1.55, 0.028, 18, 10)
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color("2a1d17")
	wood.roughness = 0.75
	wood.albedo_texture = Materials.detail_noise()
	wood.uv1_scale = Vector3(1.0, 6.0, 1.0)
	shaft.material_override = wood
	shaft.position.y = -0.55
	root.add_child(shaft)
	# Garras douradas que seguram o cristal.
	var gold: StandardMaterial3D = StandardMaterial3D.new()
	gold.albedo_color = GOLD
	gold.metallic = 0.85
	gold.roughness = 0.32
	for i: int in 3:
		var claw: MeshInstance3D = MeshInstance3D.new()
		claw.mesh = _claw_mesh(0.2, 0.012)
		claw.material_override = gold
		claw.position.y = 0.98
		claw.rotation.y = TAU * i / 3.0
		root.add_child(claw)
	# Cristal facetado emissivo.
	var crystal: MeshInstance3D = MeshInstance3D.new()
	crystal.name = "Crystal"
	crystal.mesh = crystal_mesh(0.075, 0.24, 6)
	crystal.material_override = crystal_material()
	crystal.position.y = 1.11
	root.add_child(crystal)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "CrystalLight"
	light.light_color = VIOLET_GLOW
	light.light_energy = 1.1
	light.omni_range = 5.5
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.position.y = 1.11
	root.add_child(light)
	root.rotation_degrees = Vector3(0, 0, 0)
	return root


static func crystal_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = VIOLET.lightened(0.15)
	m.emission_enabled = true
	m.emission = VIOLET_GLOW
	m.emission_energy_multiplier = 3.2
	m.roughness = 0.08
	m.metallic = 0.2
	m.rim_enabled = true
	m.rim = 1.0
	m.rim_tint = 0.2
	return m


## Bipirâmide alongada facetada (cristal arcano).
static func crystal_mesh(radius: float, height: float, sides: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Vector3 = Vector3(0, height * 0.62, 0)
	var bottom: Vector3 = Vector3(0, -height * 0.38, 0)
	for i: int in sides:
		var a0: float = TAU * i / sides
		var a1: float = TAU * (i + 1) / sides
		var r0: float = radius * (0.85 + 0.15 * sin(i * 2.3))
		var r1: float = radius * (0.85 + 0.15 * sin((i + 1) * 2.3))
		var p0: Vector3 = Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
		var p1: Vector3 = Vector3(cos(a1) * r1, 0.0, sin(a1) * r1)
		for tri: Array in [[top, p1, p0], [bottom, p0, p1]]:
			var n: Vector3 = ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3)).normalized()
			for v: Vector3 in tri:
				st.set_normal(-n)
				st.add_vertex(v)
	return st.commit()


static func _lathe_shaft(length: float, radius: float, rings: int, sides: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = 5
	n.frequency = 2.0
	for r: int in rings + 1:
		var t: float = float(r) / rings
		var y: float = t * length
		var knot: float = 1.0 + 0.35 * maxf(0.0, sin(t * 19.0)) * (1.0 - t)
		var rad: float = radius * lerpf(1.1, 0.8, t) * knot
		var off: Vector3 = Vector3(n.get_noise_1d(t * 3.0) * 0.03, 0.0, n.get_noise_1d(t * 3.0 + 50.0) * 0.03)
		for s: int in sides + 1:
			var a: float = TAU * s / sides
			var nrm: Vector3 = Vector3(cos(a), 0.0, sin(a))
			st.set_normal(nrm)
			st.set_uv(Vector2(float(s) / sides, t))
			st.add_vertex(off + nrm * rad + Vector3.UP * y)
	for r: int in rings:
		for s: int in sides:
			var i0: int = r * (sides + 1) + s
			var i1: int = i0 + sides + 1
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i0 + 1)
			st.add_index(i0 + 1)
			st.add_index(i1)
			st.add_index(i1 + 1)
	return st.commit()


## Garra curva (tubo afinando) que sobe e se curva para dentro.
static func _claw_mesh(height: float, radius: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 8
	var sides: int = 6
	var pts: Array[Vector3] = []
	for i: int in segs + 1:
		var t: float = float(i) / segs
		pts.append(Vector3(0.045 + sin(t * PI) * 0.05 - t * t * 0.06, t * height, 0.0))
	for i: int in segs + 1:
		var t: float = float(i) / segs
		var rad: float = radius * (1.0 - t * 0.85)
		for s: int in sides + 1:
			var a: float = TAU * s / sides
			var nrm: Vector3 = Vector3(cos(a), 0.0, sin(a))
			st.set_normal(nrm)
			st.add_vertex(pts[i] + nrm * rad)
	for i: int in segs:
		for s: int in sides:
			var i0: int = i * (sides + 1) + s
			var i1: int = i0 + sides + 1
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i0 + 1)
			st.add_index(i0 + 1)
			st.add_index(i1)
			st.add_index(i1 + 1)
	return st.commit()


# --- Capa e olhos ------------------------------------------------------------------

## A capa é a do próprio modelo (recolorida); devolvemos o nó para o balanço.
static func attach_cape(skel: Skeleton3D) -> MeshInstance3D:
	return skel.find_child("Mage_Cape", true, false) as MeshInstance3D


## Olhos com brilho violeta sob a sombra do chapéu. A posição vem da caixa
## da malha da cabeça (pose de ligação) convertida para o espaço do osso.
static func attach_eyes(skel: Skeleton3D) -> void:
	var bone: int = find_bone(skel, BONE_HEAD)
	var head_mesh: MeshInstance3D = skel.find_child("Mage_Head", true, false) as MeshInstance3D
	if bone < 0 or head_mesh == null or head_mesh.mesh == null:
		return
	var att: BoneAttachment3D = BoneAttachment3D.new()
	att.name = "EyeSlot"
	att.bone_idx = bone
	skel.add_child(att)
	var aabb: AABB = head_mesh.mesh.get_aabb()
	var rest_inv: Transform3D = skel.get_bone_global_rest(bone).affine_inverse()
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	tex.width = 32
	tex.height = 32
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = tex
	mat.albedo_color = Color(VIOLET_GLOW.r * 1.6, VIOLET_GLOW.g * 1.6, VIOLET_GLOW.b * 1.6, 0.75)
	var w: float = aabb.size.x
	for side: float in [-1.0, 1.0]:
		var eye_model: Vector3 = Vector3(aabb.get_center().x + side * w * 0.16, aabb.position.y + aabb.size.y * 0.42,
			aabb.end.z + 0.005)
		var q: MeshInstance3D = MeshInstance3D.new()
		q.name = "EyeGlow"
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(w * 0.075, w * 0.075)
		q.mesh = quad
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = rest_inv * eye_model
		att.add_child(q)
