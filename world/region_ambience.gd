class_name RegionAmbience
extends Node3D
## Identidade de cada região ao redor do jogador: corrupção (névoa violeta,
## céu dessaturado, LUT), partículas de clima, frio nos picos e anúncio da região.

const L = preload("res://world/island/island_layout.gd")
const COLD_HEIGHT: float = 125.0
const COLD_GRACE: float = 18.0

var atmosphere: Atmosphere
var terrain: IslandTerrain
var current_region: StringName = &""
## 0..1: quanto o jogador está congelando (HUD mostra a geada nas bordas).
var cold: float = 0.0

var _timer: float = 0.0
var _corruption_target: float = 0.0
var _snow: GPUParticles3D
var _ash: GPUParticles3D
var _wisps: GPUParticles3D
var _fireflies: GPUParticles3D
var _cold_time: float = 0.0


func _ready() -> void:
	add_to_group(&"region_ambience")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_snow = _weather(900, Color(0.95, 0.97, 1.0, 0.9), Vector3(0.6, -3.2, 0.2), 0.07, 6.0)
	_ash = _weather(500, Color(0.35, 0.3, 0.3, 0.8), Vector3(0.4, -0.8, 0.2), 0.06, 9.0)
	_wisps = _weather(60, Color(0.7, 0.45, 1.0, 1.0), Vector3(0.0, 0.25, 0.0), 0.16, 7.0, true)
	_fireflies = _weather(80, Color(1.0, 0.85, 0.4, 1.0), Vector3(0.0, 0.15, 0.0), 0.08, 6.0, true)
	_build_fog_volumes()


func _weather(amount: int, color: Color, vel: Vector3, size: float, life: float, glow: bool = false) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 10, 28)
	pm.direction = vel.normalized() if vel.length() > 0.0 else Vector3.UP
	pm.spread = 25.0 if not glow else 180.0
	pm.initial_velocity_min = vel.length() * 0.6
	pm.initial_velocity_max = vel.length() * 1.2
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6 if glow else 0.3
	pm.color = color
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = Vfx.ADDITIVE if glow else preload("res://shaders/vfx_soft.gdshader")
	m.set_shader_parameter(&"energy", 2.5 if glow else 1.0)
	q.material = m
	p.draw_pass_1 = q
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	p.emitting = false
	add_child(p)
	return p


## Névoa volumétrica violeta e espessa no Pântano (só aparece no Médio ou acima).
func _build_fog_volumes() -> void:
	var swamp: Vector2 = L.REGION_CENTERS[L.Region.SWAMP]
	var fv: FogVolume = FogVolume.new()
	fv.size = Vector3(460, 26, 520)
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	var fm: FogMaterial = FogMaterial.new()
	fm.density = 0.05
	fm.albedo = Color(0.45, 0.3, 0.6)
	fm.emission = Color(0.08, 0.02, 0.14)
	fm.height_falloff = 0.12
	fv.material = fm
	fv.position = Vector3(swamp.x, 4.0, swamp.y)
	add_child(fv)


func _process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var cam: Camera3D = get_viewport().get_camera_3d()
	var focus: Vector3 = player.global_position if player != null else (cam.global_position if cam != null else Vector3.ZERO)
	_timer -= delta
	if _timer <= 0.0 and terrain != null:
		_timer = 0.5
		var id: int = terrain.region_at(focus)
		var region: StringName = L.REGION_NAMES.get(id, &"valley")
		if region != current_region and region != &"sea":
			current_region = region
			Events.region_entered.emit(region)
		_corruption_target = GameState.corruption(current_region)
		if atmosphere != null:
			var grading: StringName = &"corrupted" if _corruption_target > 0.5 else (
				&"purified" if GameState.purification.get(String(current_region), 0.0) > 0.9 else &"default")
			atmosphere.set_grading(grading)
	if atmosphere != null:
		atmosphere.corruption = move_toward(atmosphere.corruption, _corruption_target, delta * 0.3)
	_update_weather(focus, cam)
	_update_cold(player, delta)


func _update_weather(focus: Vector3, cam: Camera3D) -> void:
	var at: Vector3 = cam.global_position if cam != null else focus
	for p: GPUParticles3D in [_snow, _ash, _wisps, _fireflies]:
		p.global_position = at + Vector3.UP * (6.0 if p == _snow or p == _ash else 0.0)
	var night: float = atmosphere.night_factor() if atmosphere != null else 0.0
	_snow.emitting = current_region == &"peaks" and focus.y > COLD_HEIGHT - 30.0
	_ash.emitting = current_region == &"burnt"
	_wisps.emitting = current_region == &"swamp" or (current_region == &"forest" and night > 0.5)
	_fireflies.emitting = (current_region == &"valley" or current_region == &"coast") and night > 0.6


## Frio nos picos: depois de um tempo exposto, a stamina recupera devagar e a
## vida cai aos poucos. Perto de uma fogueira acesa (ou com proteção) não congela.
func _update_cold(player: Node3D, delta: float) -> void:
	var p: Player = player as Player
	if p == null:
		return
	var exposed: bool = current_region == &"peaks" and p.global_position.y > COLD_HEIGHT \
		and not GameState.has_flag("ward:frost") and not _near_fire(p.global_position)
	if exposed:
		_cold_time += delta
	else:
		_cold_time = maxf(_cold_time - delta * 3.0, 0.0)
	cold = clampf((_cold_time - COLD_GRACE * 0.5) / COLD_GRACE, 0.0, 1.0)
	p.stats.stamina_regen = 28.0 * (1.0 - 0.6 * cold)
	if cold >= 1.0 and p.is_alive():
		p.stats.set_health(p.stats.health - 1.5 * delta)


func _near_fire(pos: Vector3) -> bool:
	for b: Node in get_tree().get_nodes_in_group(&"interactable"):
		var bf: Bonfire = b as Bonfire
		if bf != null and bf.discovered and bf.global_position.distance_to(pos) < 8.0:
			return true
	return false
