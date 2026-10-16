class_name Projectile
extends Node3D
## Projétil reutilizável (pool). Move-se por raycast entre a posição anterior e
## a nova, então nunca atravessa alvos finos em alta velocidade.

signal finished(p: Projectile)

const MASK_FROM_PLAYER: int = 1 | 4
const MASK_FROM_ENEMY: int = 1 | 2

var active: bool = false
var velocity: Vector3 = Vector3.ZERO
var damage: DamageInfo
var max_distance: float = 60.0
var gravity: float = 0.0
var mask: int = MASK_FROM_PLAYER
var color: Color = Color("b67cff")
var impact_scale: float = 1.0
## Ao acertar: dano em área (raio > 0).
var splash_radius: float = 0.0
var world_tags: PackedStringArray = []
var exclude: Array[RID] = []

var _travelled: float = 0.0
var _core: MeshInstance3D
var _trail: GPUParticles3D
var _core_mat: StandardMaterial3D


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_core = MeshInstance3D.new()
	_core.mesh = MageLook.crystal_mesh(0.07, 0.42, 5)
	_core.rotation_degrees = Vector3(-90, 0, 0)
	_core_mat = StandardMaterial3D.new()
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_mat.emission_enabled = true
	_core_mat.emission_energy_multiplier = 4.0
	_core.material_override = _core_mat
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	_trail = GPUParticles3D.new()
	_trail.amount = 40
	_trail.lifetime = 0.35
	_trail.local_coords = false
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3.ZERO
	var c: Curve = Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var ct: CurveTexture = CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	_trail.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	var qm: ShaderMaterial = ShaderMaterial.new()
	qm.shader = Vfx.ADDITIVE
	q.material = qm
	_trail.draw_pass_1 = q
	_trail.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	add_child(_trail)
	visible = false
	set_physics_process(false)


func launch(from: Vector3, dir: Vector3, speed: float, info: DamageInfo, tint: Color, size: float = 1.0) -> void:
	global_position = from
	velocity = dir.normalized() * speed
	damage = info
	color = tint
	_travelled = 0.0
	active = true
	visible = true
	scale = Vector3.ONE * size
	_core_mat.albedo_color = tint
	_core_mat.emission = tint
	(_trail.process_material as ParticleProcessMaterial).color = tint
	_trail.restart()
	_trail.emitting = true
	look_at(from + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.FORWARD)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not active:
		return
	velocity.y -= gravity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	q.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_on_hit(hit)
		return
	global_position = to
	if velocity.length_squared() > 0.01:
		look_at(to + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.FORWARD)
	_travelled += velocity.length() * delta
	if _travelled >= max_distance:
		_finish(false)


func _on_hit(hit: Dictionary) -> void:
	var pos: Vector3 = hit["position"]
	var collider: Object = hit["collider"]
	global_position = pos
	damage.hit_position = pos
	damage.direction = velocity.normalized()
	var target: Node = DamageInfo.find_damageable(collider)
	if splash_radius > 0.0:
		Spells.apply_area(self, pos, splash_radius, damage, mask)
	elif target != null:
		target.call(&"take_damage", damage)
	else:
		Events.spell_hit_world.emit(damage.spell_id, damage.element, pos, collider as Node)
	var vfx: Vfx = Vfx.get_for(self)
	if vfx != null:
		vfx.impact(pos, color, impact_scale)
		if splash_radius > 0.0:
			vfx.shockwave(pos, splash_radius, color)
	Audio.play(&"impact_heavy" if impact_scale > 1.4 else &"impact_arcane", pos)
	_finish(true)


func _finish(_hit: bool) -> void:
	active = false
	set_physics_process(false)
	_trail.emitting = false
	visible = false
	damage = null
	finished.emit(self)
