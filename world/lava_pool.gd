class_name LavaPool
extends Node3D
## Lago de lava na cratera do vulcão (Terras Calcinadas): disco com shader de lava,
## luz alaranjada, fagulhas subindo e dano de queimadura em quem pisar.

const L = preload("res://world/island/island_layout.gd")
const DAMAGE_PER_S: float = 25.0

var terrain: IslandTerrain
var radius: float = L.CRATER_RADIUS * 0.75
var _area: Area3D
var _tick: float = 0.0


func _ready() -> void:
	var c: Vector2 = L.VOLCANO_CENTER
	var floor_y: float = terrain.height_at(Vector3(c.x, 0, c.y)) if terrain != null else 100.0
	global_position = Vector3(c.x, floor_y + 2.5, c.y)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.2
	cm.radial_segments = 48
	cm.rings = 1
	mi.mesh = cm
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = preload("res://shaders/lava.gdshader")
	var nt: NoiseTexture2D = NoiseTexture2D.new()
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	var fn: FastNoiseLite = FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 4
	nt.noise = fn
	m.set_shader_parameter(&"noise_tex", nt)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("ff6a2c")
	light.light_energy = 6.0
	light.omni_range = radius * 2.4
	light.shadow_enabled = false
	light.position.y = 6.0
	add_child(light)
	add_child(_embers())
	_area = Area3D.new()
	_area.collision_mask = 2  # jogador
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 4.0
	cs.shape = cyl
	_area.add_child(cs)
	add_child(_area)


func _embers() -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 5.0
	p.visibility_aabb = AABB(Vector3(-radius, -2, -radius), Vector3(radius * 2, 40, radius * 2))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0, 0.5, 0)
	pm.scale_min = 0.1
	pm.scale_max = 0.3
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1.0, 0.7, 0.2, 1.0))
	g.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var qm: StandardMaterial3D = StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = qm
	p.draw_pass_1 = q
	return p


func _physics_process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	for b: Node3D in _area.get_overlapping_bodies():
		var pl: Player = b as Player
		# Só queima quem está na altura da lava (não quem anda nas faixas de rocha acima).
		if pl != null and pl.global_position.y < global_position.y + 1.0:
			var info: DamageInfo = DamageInfo.make(DAMAGE_PER_S * 0.25, DamageInfo.Element.FIRE, self, &"lava")
			info.dodgeable = false
			info.hit_position = pl.global_position
			pl.take_damage(info)
