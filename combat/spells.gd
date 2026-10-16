class_name Spells
extends RefCounted
## Execução dos feitiços (um método por tipo). Quem conjura é o SpellCaster;
## aqui ficam o efeito no mundo, o dano, os VFX e o som em camadas.

const ENEMY_MASK: int = 4
const PLAYER_MASK: int = 2

static var _db: Dictionary[StringName, SpellData] = {}


static func get_spell(id: StringName) -> SpellData:
	if _db.is_empty():
		for f: String in DirAccess.get_files_at("res://data/spells"):
			var path: String = "res://data/spells/" + f.trim_suffix(".remap")
			if path.ends_with(".tres"):
				var s: SpellData = load(path) as SpellData
				if s != null:
					_db[s.id] = s
	return _db.get(id)


static func all_ids() -> Array[StringName]:
	get_spell(&"")
	var out: Array[StringName] = []
	out.assign(_db.keys())
	return out


static func info_for(spell: SpellData, source: Node, amount: float) -> DamageInfo:
	var d: DamageInfo = DamageInfo.make(amount, spell.element, source, spell.id)
	d.knockback = spell.knockback
	d.stagger = spell.stagger
	return d


## Dano em área com queda pela distância e empurrão para fora do centro.
static func apply_area(ctx: Node3D, center: Vector3, radius: float, base: DamageInfo, mask: int) -> int:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, center)
	q.collision_mask = mask & ~1
	q.collide_with_areas = true
	var hits: Array[Dictionary] = ctx.get_world_3d().direct_space_state.intersect_shape(q, 32)
	var done: Dictionary[int, bool] = {}
	for h: Dictionary in hits:
		var target: Node = DamageInfo.find_damageable(h["collider"] as Object)
		if target == null or done.has(target.get_instance_id()) or target == base.source:
			continue
		done[target.get_instance_id()] = true
		var tpos: Vector3 = (target as Node3D).global_position if target is Node3D else center
		var dist: float = Vector3(tpos.x - center.x, 0.0, tpos.z - center.z).length()
		var falloff: float = lerpf(1.0, 0.55, clampf(dist / radius, 0.0, 1.0))
		var d: DamageInfo = DamageInfo.make(base.amount * falloff, base.element, base.source, base.spell_id)
		d.knockback = base.knockback
		d.stagger = base.stagger
		d.hit_position = tpos + Vector3.UP
		var away: Vector3 = Vector3(tpos.x - center.x, 0.0, tpos.z - center.z)
		d.direction = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		target.call(&"take_damage", d)
	Events.spell_hit_world.emit(base.spell_id, base.element, center, null)
	return done.size()


# --- Tipos de feitiço ------------------------------------------------------------

static func projectile(caster: SpellCaster, spell: SpellData, charge: float, dir: Vector3) -> void:
	var pool: ProjectilePool = ProjectilePool.get_for(caster)
	if pool == null:
		return
	var amount: float = lerpf(spell.damage, maxf(spell.charge_damage, spell.damage), charge)
	var info: DamageInfo = info_for(spell, caster.player, amount)
	info.stagger = lerpf(spell.stagger, 1.0, charge)
	info.knockback = spell.knockback * (1.0 + charge * 2.0)
	var p: Projectile = pool.take()
	p.mask = Projectile.MASK_FROM_PLAYER
	p.max_distance = spell.range_m
	p.impact_scale = 1.0 + charge * 1.2
	p.world_tags = spell.world_tags
	p.exclude = [caster.player.get_rid()]
	p.launch(caster.cast_origin(), dir, spell.speed * (1.0 + charge * 0.4), info, spell.color, 1.0 + charge * 1.3)
	Audio.play(&"cast_heavy" if charge > 0.5 else &"cast_bolt", caster.cast_origin())


static func area(caster: SpellCaster, spell: SpellData) -> void:
	var center: Vector3 = caster.player.global_position
	var info: DamageInfo = info_for(spell, caster.player, spell.damage)
	var n: int = apply_area(caster.player, center + Vector3.UP, spell.radius, info, ENEMY_MASK)
	var vfx: Vfx = Vfx.get_for(caster)
	if vfx != null:
		vfx.shockwave(center, spell.radius, spell.color, 0.5)
		vfx.shockwave(center, spell.radius * 0.6, Color("e8b44c"), 0.35)
		vfx.impact(center + Vector3.UP * 0.5, spell.color, 1.6, 48)
	Audio.play(&"impact_heavy", center)
	Audio.play(&"charge", center, -4.0)
	if n > 0 and caster.player.cam_rig != null:
		caster.player.cam_rig.shake(0.5, 0.3)


static func chain(caster: SpellCaster, spell: SpellData, first_target: Node3D) -> void:
	var points: PackedVector3Array = [caster.cast_origin()]
	var hit_ids: Dictionary[int, bool] = {}
	var current: Node3D = first_target
	var amount: float = spell.damage
	for i: int in spell.count:
		if current == null:
			break
		hit_ids[current.get_instance_id()] = true
		var p: Vector3 = current.global_position + Vector3.UP * 1.1
		points.append(p)
		var info: DamageInfo = info_for(spell, caster.player, amount)
		info.hit_position = p
		info.direction = (p - points[points.size() - 2]).normalized()
		current.call(&"take_damage", info)
		amount *= 0.8
		current = _nearest_enemy(caster.player, p, spell.radius, hit_ids)
	if points.size() == 1:
		# Sem alvo: o raio vai até o fim do alcance e pode revelar runas no mundo.
		var end: Vector3 = caster.aim_point(spell.range_m)
		points.append(end)
		Events.spell_hit_world.emit(spell.id, spell.element, end, null)
	var vfx: Vfx = Vfx.get_for(caster)
	if vfx != null:
		vfx.lightning(points, spell.color)
		for k: int in range(1, points.size()):
			vfx.impact(points[k], spell.color, 0.8, 16)
	Audio.play(&"lightning", caster.cast_origin())


static func _nearest_enemy(ctx: Node, from: Vector3, radius: float, skip: Dictionary[int, bool]) -> Node3D:
	var best: Node3D = null
	var best_d: float = radius
	for e: Node in ctx.get_tree().get_nodes_in_group(&"enemy"):
		var en: Node3D = e as Node3D
		if en == null or skip.has(en.get_instance_id()) or not en.call(&"is_alive"):
			continue
		var d: float = en.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = en
	return best


static func barrier(caster: SpellCaster, spell: SpellData) -> void:
	caster.player.barrier_hp = float(spell.count)
	caster.player.barrier_time = spell.duration
	Audio.play(&"barrier", caster.player.global_position)
	var vfx: Vfx = Vfx.get_for(caster)
	if vfx != null:
		vfx.shockwave(caster.player.global_position, spell.radius * 1.5, spell.color, 0.4)


static func meteor(caster: SpellCaster, spell: SpellData) -> void:
	var target: Vector3 = caster.ground_aim_point(spell.range_m)
	var vfx: Vfx = Vfx.get_for(caster)
	if vfx != null:
		vfx.ground_marker(target, spell.radius, Color(1.0, 0.6, 0.3, 0.9), spell.duration)
	Audio.play(&"charge", target)
	var tree: SceneTree = caster.get_tree()
	await tree.create_timer(spell.duration * 0.6, false).timeout
	# Astro em queda: projétil vindo do alto com explosão em área.
	var pool: ProjectilePool = ProjectilePool.get_for(caster)
	if pool == null:
		return
	var info: DamageInfo = info_for(spell, caster.player, spell.damage)
	var p: Projectile = pool.take()
	p.mask = 1
	p.splash_radius = spell.radius
	p.impact_scale = 2.5
	p.max_distance = 80.0
	p.world_tags = spell.world_tags
	var start: Vector3 = target + Vector3(6.0, 34.0, 4.0)
	p.launch(start, target - start, 70.0, info, spell.color, 3.0)
	Audio.play(&"fire", start)
	await tree.create_timer(0.45, false).timeout
	Audio.play(&"boom", target)
	if caster.player.cam_rig != null:
		caster.player.cam_rig.shake(0.8, 0.4)


static func blink(caster: SpellCaster, spell: SpellData) -> void:
	var pl: Player = caster.player
	var dir: Vector3 = pl.move_input.normalized() if pl.move_input.length() > 0.1 else pl.facing
	var from: Vector3 = pl.global_position + Vector3.UP * 0.9
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * spell.range_m, 1)
	var hit: Dictionary = pl.get_world_3d().direct_space_state.intersect_ray(q)
	var dest: Vector3 = (hit["position"] as Vector3) - dir * 0.6 if not hit.is_empty() else from + dir * spell.range_m
	dest.y -= 0.9
	var vfx: Vfx = Vfx.get_for(caster)
	if vfx != null:
		vfx.impact(pl.global_position + Vector3.UP, spell.color, 1.2, 36)
	pl.global_position = dest
	pl.reset_physics_interpolation()
	pl.grant_iframes(0.25)
	if vfx != null:
		vfx.impact(dest + Vector3.UP, spell.color, 1.2, 36)
	Audio.play(&"blink", dest)


static func control(caster: SpellCaster, spell: SpellData) -> void:
	var center: Vector3 = caster.ground_aim_point(spell.range_m)
	var info: DamageInfo = info_for(spell, caster.player, spell.damage)
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = spell.radius
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, center + Vector3.UP)
	q.collision_mask = ENEMY_MASK
	for h: Dictionary in caster.player.get_world_3d().direct_space_state.intersect_shape(q, 24):
		var t: Node = DamageInfo.find_damageable(h["collider"] as Object)
		if t != null and t.has_method(&"apply_status"):
			t.call(&"take_damage", info)
			t.call(&"apply_status", StatusEffects.Kind.FROZEN, spell.duration, 1.0)
	Events.spell_hit_world.emit(spell.id, spell.element, center, null)
	var vfx: Vfx = Vfx.get_for(caster)
	if vfx != null:
		vfx.shockwave(center, spell.radius, spell.color, 0.6)
		vfx.impact(center + Vector3.UP * 0.3, spell.color, 1.3, 40)
	Audio.play(&"frost", center)


static func ultimate(caster: SpellCaster, spell: SpellData) -> void:
	var center: Vector3 = caster.player.global_position
	var info: DamageInfo = info_for(spell, caster.player, spell.damage)
	apply_area(caster.player, center + Vector3.UP, spell.radius, info, ENEMY_MASK)
	var vfx: Vfx = Vfx.get_for(caster)
	if vfx != null:
		vfx.shockwave(center, spell.radius, Color("e8b44c"), 0.9)
		vfx.shockwave(center, spell.radius * 0.7, Color("b67cff"), 0.7)
		vfx.impact(center + Vector3.UP, Color("e8b44c"), 2.5, 64)
		vfx.flash(center + Vector3.UP * 2.0, Color("ffd27a"), 12.0, 0.6)
	Audio.play(&"boom", center)
	Audio.play(&"beacon", center)
	HitStop.hit(caster.get_tree(), 90, 0.05)
	if caster.player.cam_rig != null:
		caster.player.cam_rig.shake(1.0, 0.6)
