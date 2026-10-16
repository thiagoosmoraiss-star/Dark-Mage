class_name Bonfire
extends Interactable
## Fogueira de Repouso: cura, salva, define o renascimento, ressuscita os
## inimigos e permite viagem rápida entre fogueiras descobertas.

var discovered: bool = false
var _flames: GPUParticles3D
var _embers: GPUParticles3D
var _light: OmniLight3D
var _t: float = 0.0


static func display_name(id: String) -> String:
	var key: String = "BONFIRE_" + id.to_upper()
	var t: String = TranslationServer.translate(key)
	if t != key:
		return t
	var poi: Dictionary = WorldPois.get_poi(StringName(id))
	var region: String = str(poi.get("region", ""))
	return "%s — %s" % [TranslationServer.translate("BONFIRE_GENERIC"), TranslationServer.translate("REGION_" + region.to_upper())]


func _ready() -> void:
	super._ready()
	prompt_key = "INTERACT_BONFIRE"
	_build()
	discovered = GameState.discovered_bonfires.has(poi_id)
	_set_lit(discovered)


func get_class_tag() -> String:
	return "bonfire"


func prompt_text() -> String:
	return tr("INTERACT_BONFIRE_REST") if discovered else tr("INTERACT_BONFIRE")


func interact(player: Player) -> void:
	if not discovered:
		discovered = true
		GameState.discover_bonfire(poi_id)
		_set_lit(true)
		Audio.play(&"fire", global_position)
	GameState.respawn_bonfire = poi_id
	player.respawn_point = global_position + global_basis.z * 1.8
	player.stats.set_health(player.stats.max_health)
	player.stats.set_mana(player.stats.max_mana)
	var world: IslandWorld = player.get_tree().get_first_node_in_group(&"world") as IslandWorld
	if world != null:
		world.on_bonfire_rest(self)


func _set_lit(on: bool) -> void:
	_flames.emitting = on
	_light.light_energy = 2.2 if on else 0.25
	_light.omni_range = 9.0 if on else 3.0


func _process(delta: float) -> void:
	_t += delta
	if _flames.emitting:
		_light.light_energy = 2.0 + sin(_t * 11.0) * 0.25 + sin(_t * 23.0) * 0.15


func _build() -> void:
	var rng: RandomNumberGenerator = Rng.make_rng(Rng.WORLD_SEED, "bonfire_" + poi_id)
	# Anel de pedras.
	for i: int in 9:
		var a: float = TAU * i / 9.0
		var rock: MeshInstance3D = MeshInstance3D.new()
		rock.mesh = RockMesh.build(300 + i % 4, Vector3(0.5, 0.32, 0.42), 2, 0.3)
		rock.material_override = Materials.rock(0.2)
		rock.position = Vector3(cos(a) * 0.85, 0.05, sin(a) * 0.85)
		rock.rotation.y = rng.randf() * TAU
		add_child(rock)
	# Toras cruzadas.
	var bark: Material = TreeMesh.bark_material(TreeMesh.Species.OAK)
	for i: int in 4:
		var log_mi: MeshInstance3D = MeshInstance3D.new()
		log_mi.mesh = _log_mesh(1.1, 0.09)
		log_mi.material_override = bark
		log_mi.rotation = Vector3(deg_to_rad(65.0), TAU * i / 4.0 + 0.3, 0.0)
		log_mi.position = Vector3(0, 0.1, 0)
		add_child(log_mi)
	_flames = _fire_particles(36, 0.9, Color(1.0, 0.62, 0.25), Vector3(0, 2.2, 0), 0.5)
	_embers = _fire_particles(16, 2.0, Color(1.0, 0.45, 0.15), Vector3(0, 1.3, 0), 0.08)
	_embers.emitting = true
	_light = OmniLight3D.new()
	_light.light_color = Color("ffb765")
	_light.position.y = 0.8
	_light.shadow_enabled = false
	add_child(_light)


func _fire_particles(amount: int, lifetime: float, color: Color, vel: Vector3, size: float) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.position.y = 0.25
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = vel.y * 0.5
	pm.initial_velocity_max = vel.y
	pm.gravity = Vector3(0, 0.6, 0)
	pm.color = color
	var c: Curve = Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0))
	var ct: CurveTexture = CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = Vfx.ADDITIVE
	m.set_shader_parameter(&"energy", 2.5)
	q.material = m
	p.draw_pass_1 = q
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	add_child(p)
	return p


static func _log_mesh(length: float, radius: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 8
	for r: int in 2:
		for s: int in sides + 1:
			var a: float = TAU * s / sides
			var n: Vector3 = Vector3(cos(a), 0.0, sin(a))
			st.set_normal(n)
			st.set_uv(Vector2(float(s) / sides, r))
			st.add_vertex(n * radius * (1.0 - r * 0.15) + Vector3.UP * (r * length - length * 0.5))
	for s: int in sides:
		st.add_index(s)
		st.add_index(s + 1)
		st.add_index(s + sides + 1)
		st.add_index(s + 1)
		st.add_index(s + sides + 2)
		st.add_index(s + sides + 1)
	return st.commit()
