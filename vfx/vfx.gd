class_name Vfx
extends Node3D
## Efeitos visuais com pool (nada de instantiate/queue_free por golpe).
## Uma instância por mundo, no grupo "vfx". Use Vfx.get_for(node).

const ADDITIVE: Shader = preload("res://shaders/vfx_additive.gdshader")
const SHOCKWAVE: Shader = preload("res://shaders/shockwave.gdshader")
const POOL_IMPACT: int = 24
const POOL_RING: int = 10
const POOL_BOLT: int = 8
const POOL_NUMBER: int = 24
const POOL_LIGHT: int = 6
const POOL_MARKER: int = 8

var _impacts: Array[GPUParticles3D] = []
var _rings: Array[MeshInstance3D] = []
var _bolts: Array[MeshInstance3D] = []
var _numbers: Array[Label3D] = []
var _lights: Array[OmniLight3D] = []
var _markers: Array[Decal] = []
var _i_impact: int = 0
var _i_ring: int = 0
var _i_bolt: int = 0
var _i_number: int = 0
var _i_light: int = 0
var _i_marker: int = 0
## Animações em andamento: [nó, tipo, tempo, duração, dados]
var _anims: Array[Array] = []


static func get_for(n: Node) -> Vfx:
	return n.get_tree().get_first_node_in_group(&"vfx") as Vfx


func _ready() -> void:
	add_to_group(&"vfx")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var spark_mat: ShaderMaterial = ShaderMaterial.new()
	spark_mat.shader = ADDITIVE
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	quad.material = spark_mat
	for i: int in POOL_IMPACT:
		var p: GPUParticles3D = GPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = 28
		p.lifetime = 0.55
		p.explosiveness = 0.95
		p.local_coords = false
		p.process_material = _impact_process()
		p.draw_pass_1 = quad
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
		p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
		add_child(p)
		_impacts.append(p)
	var noise: NoiseTexture2D = NoiseTexture2D.new()
	noise.seamless = true
	noise.noise = FastNoiseLite.new()
	for i: int in POOL_RING:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(2, 2)
		q.orientation = PlaneMesh.FACE_Y
		mi.mesh = q
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = SHOCKWAVE
		m.set_shader_parameter(&"noise_tex", noise)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_rings.append(mi)
	for i: int in POOL_BOLT:
		var b: MeshInstance3D = MeshInstance3D.new()
		b.mesh = ImmediateMesh.new()
		var bm: ShaderMaterial = ShaderMaterial.new()
		bm.shader = ADDITIVE
		bm.set_shader_parameter(&"radial", false)
		bm.set_shader_parameter(&"energy", 5.0)
		b.material_override = bm
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.visible = false
		add_child(b)
		_bolts.append(b)
	for i: int in POOL_NUMBER:
		var l: Label3D = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0012
		l.font_size = 30
		l.outline_size = 8
		l.outline_modulate = Color(0.04, 0.03, 0.06, 0.9)
		l.visible = false
		add_child(l)
		_numbers.append(l)
	for i: int in POOL_LIGHT:
		var o: OmniLight3D = OmniLight3D.new()
		o.omni_range = 7.0
		o.shadow_enabled = false
		o.visible = false
		add_child(o)
		_lights.append(o)
	var ring_tex: ImageTexture = _ring_texture(false)
	var ring_emit: ImageTexture = _ring_texture(true)
	for i: int in POOL_MARKER:
		var d: Decal = Decal.new()
		d.texture_albedo = ring_tex
		d.texture_emission = ring_emit
		# Só projeta no terreno e nas estruturas (camada 1), nunca em personagens.
		d.cull_mask = 1
		d.emission_energy = 2.5
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		d.visible = false
		add_child(d)
		_markers.append(d)


static func _impact_process() -> ParticleProcessMaterial:
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var curve: CurveTexture = CurveTexture.new()
	var c: Curve = Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	pm.scale_curve = curve
	return pm


## Anel com runas. Para emissão, o RGB carrega a máscara (preto fora do anel).
static func _ring_texture(for_emission: bool) -> ImageTexture:
	var n: int = 128
	var img: Image = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y: int in n:
		for x: int in n:
			var d: float = Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var ring: float = clampf(1.0 - absf(d - 0.9) / 0.08, 0.0, 1.0)
			var fill: float = clampf(1.0 - d, 0.0, 1.0) * 0.25 * float(d < 1.0)
			var runes: float = float(absf(sin(atan2(y - n * 0.5, x - n * 0.5) * 12.0)) > 0.92 and d > 0.72 and d < 0.8) * 0.8
			var a: float = clampf(ring + fill + runes, 0.0, 1.0)
			img.set_pixel(x, y, Color(a, a, a, 1.0) if for_emission else Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# --- API ---------------------------------------------------------------------------

func impact(pos: Vector3, color: Color, scale_mult: float = 1.0, amount: int = 28) -> void:
	var p: GPUParticles3D = _impacts[_i_impact]
	_i_impact = (_i_impact + 1) % _impacts.size()
	p.global_position = pos
	p.amount = amount
	p.speed_scale = 1.0
	var pm: ParticleProcessMaterial = p.process_material as ParticleProcessMaterial
	pm.color = color
	pm.initial_velocity_max = 7.0 * scale_mult
	p.restart()
	p.emitting = true
	flash(pos, color, 2.5 * scale_mult, 0.12)


func shockwave(pos: Vector3, radius: float, color: Color, duration: float = 0.45) -> void:
	var mi: MeshInstance3D = _rings[_i_ring]
	_i_ring = (_i_ring + 1) % _rings.size()
	mi.global_position = pos + Vector3.UP * 0.12
	mi.scale = Vector3(radius, 1.0, radius)
	var m: ShaderMaterial = mi.material_override as ShaderMaterial
	m.set_shader_parameter(&"color", color)
	m.set_shader_parameter(&"progress", 0.0)
	mi.visible = true
	_track(mi, &"ring", duration, null)


## Raio quebrado entre pontos (corrente etérea).
func lightning(points: PackedVector3Array, color: Color, duration: float = 0.28) -> void:
	if points.size() < 2:
		return
	var b: MeshInstance3D = _bolts[_i_bolt]
	_i_bolt = (_i_bolt + 1) % _bolts.size()
	b.global_transform = Transform3D.IDENTITY
	_draw_bolt(b.mesh as ImmediateMesh, points, color)
	b.visible = true
	_track(b, &"bolt", duration, points)


func _draw_bolt(im: ImmediateMesh, points: PackedVector3Array, color: Color) -> void:
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var cam: Camera3D = get_viewport().get_camera_3d()
	var view: Vector3 = cam.global_position if cam != null else Vector3.UP * 100.0
	for s: int in points.size() - 1:
		var a: Vector3 = points[s]
		var bpt: Vector3 = points[s + 1]
		var segs: int = maxi(3, int(a.distance_to(bpt) / 1.2))
		var prev: Vector3 = a
		for k: int in segs:
			var t: float = float(k + 1) / segs
			var p: Vector3 = a.lerp(bpt, t)
			if k < segs - 1:
				p += Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))
			var dir: Vector3 = (p - prev).normalized()
			var side: Vector3 = dir.cross((view - prev).normalized()).normalized() * 0.09
			for v: Vector3 in [prev - side, prev + side, p + side, prev - side, p + side, p - side]:
				im.surface_set_color(color)
				im.surface_set_uv(Vector2(0.5, 0.5))
				im.surface_add_vertex(v)
			prev = p
	im.surface_end()


func damage_number(pos: Vector3, amount: float, crit: bool = false, color: Color = Color("f2efe6")) -> void:
	if Settings.get_value("accessibility", "damage_numbers") == false:
		return
	var l: Label3D = _numbers[_i_number]
	_i_number = (_i_number + 1) % _numbers.size()
	l.text = str(roundi(amount))
	l.modulate = Color("e8b44c") if crit else color
	l.font_size = 40 if crit else 30
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.3, randf_range(-0.3, 0.3))
	l.visible = true
	_track(l, &"number", 0.8, l.global_position)


func flash(pos: Vector3, color: Color, energy: float, duration: float) -> void:
	if Settings.get_value("accessibility", "reduce_flashes") == true:
		energy *= 0.35
	var o: OmniLight3D = _lights[_i_light]
	_i_light = (_i_light + 1) % _lights.size()
	o.global_position = pos + Vector3.UP * 0.3
	o.light_color = color
	o.light_energy = energy
	o.visible = true
	_track(o, &"light", duration, energy)


## Marcador no chão (indicador de área/telegrafia). Retorna o Decal para controle.
func ground_marker(pos: Vector3, radius: float, color: Color, duration: float) -> Decal:
	var d: Decal = _markers[_i_marker]
	_i_marker = (_i_marker + 1) % _markers.size()
	d.global_position = pos
	d.size = Vector3(radius * 2.0, 3.0, radius * 2.0)
	d.modulate = color
	d.visible = true
	_track(d, &"marker", duration, null)
	return d


func _track(node: Node3D, kind: StringName, duration: float, data: Variant) -> void:
	for a: Array in _anims:
		if a[0] == node:
			_anims.erase(a)
			break
	_anims.append([node, kind, 0.0, duration, data])


func _process(delta: float) -> void:
	for i: int in range(_anims.size() - 1, -1, -1):
		var a: Array = _anims[i]
		var node: Node3D = a[0]
		var t: float = (a[2] as float) + delta
		a[2] = t
		var dur: float = a[3]
		var u: float = clampf(t / dur, 0.0, 1.0)
		match a[1] as StringName:
			&"ring":
				((node as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(&"progress", u)
			&"number":
				var start: Vector3 = a[4]
				node.global_position = start + Vector3.UP * (u * 1.2)
				(node as Label3D).modulate.a = 1.0 - smoothstep(0.6, 1.0, u)
			&"light":
				(node as OmniLight3D).light_energy = (a[4] as float) * (1.0 - u)
			&"bolt":
				var bm: ShaderMaterial = (node as MeshInstance3D).material_override as ShaderMaterial
				bm.set_shader_parameter(&"energy", 5.0 * (1.0 - u))
				if fmod(t, 0.06) < delta:
					var c: Color = Color("9fd8ff")
					_draw_bolt((node as MeshInstance3D).mesh as ImmediateMesh, a[4] as PackedVector3Array, c)
			&"marker":
				var d: Decal = node as Decal
				d.emission_energy = 1.5 + 2.0 * u
		if u >= 1.0:
			node.visible = false
			_anims.remove_at(i)
