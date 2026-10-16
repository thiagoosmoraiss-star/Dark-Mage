class_name Boss
extends Enemy
## Guardião do Medo / chefe final. Fases por limiar de vida (mudança visual e
## ataques novos), ataques telegrafados e uma mecânica que pede um feitiço.
## Sem o feitiço a luta continua possível: a mecânica abre sozinha às vezes.

signal phase_changed(phase: int)
signal defeated(boss: Boss)

var boss: BossData
var phase: int = 0
## Mecânica ativa: o chefe está protegido até ser quebrado.
var guarded: bool = false
var vulnerable_time: float = 0.0
var arena_center: Vector3
var arena_radius: float = 16.0
var minions: Array[Enemy] = []

var _attack_index: int = 0
var _attack: StringName = &""
var _guard_timer: float = 8.0
var _aura: GPUParticles3D
var _guard_fx: MeshInstance3D
var _strike_point: Vector3
var _markers: Array[Decal] = []


func _make_model() -> EnemyModel:
	match boss.body:
		&"golem":
			return GolemModel.new()
		&"serpent":
			return SerpentModel.new()
	return EnemyModel.new()


func _uses_gravity() -> bool:
	return boss.body != &"serpent"


func _ready() -> void:
	# Converte BossData em EnemyData para reaproveitar a base (modelo, percepção, dano).
	var d: EnemyData = EnemyData.new()
	d.id = boss.id
	d.name_key = boss.name_key
	d.model_path = boss.model_path
	d.weapon_path = boss.weapon_path
	d.tint = boss.tint
	d.eye_color = boss.eye_color
	d.model_scale = boss.model_scale
	d.health = boss.health
	d.damage = boss.damage
	d.walk_speed = boss.move_speed * 0.6
	d.run_speed = boss.move_speed
	d.sight_range = 60.0
	d.hearing_range = 60.0
	d.attack_range = 7.0
	d.attack_cooldown = 1.2
	d.windup = 1.0
	d.knockback_resist = 1.0
	d.poise = 99.0
	d.anim_attack = &"2H_Melee_Attack_Chop"
	d.anim_run = &"Running_A"
	d.anim_walk = &"Walking_D_Skeletons" if boss.body == &"skeleton" else &"Walking_A"
	data = d
	super._ready()
	add_to_group(&"boss")
	max_health = boss.health
	health = max_health
	damage_mult = 1.0
	_build_aura()
	if boss.body == &"serpent":
		(model as SerpentModel).emerge = 1.0
		model.play(&"rise")


func _build_aura() -> void:
	_aura = GPUParticles3D.new()
	_aura.amount = 60
	_aura.lifetime = 1.6
	_aura.local_coords = false
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.5 * boss.model_scale * 0.5
	pm.direction = Vector3.UP
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.4, 0)
	pm.color = boss.eye_color
	_aura.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = Vfx.ADDITIVE
	q.material = m
	_aura.draw_pass_1 = q
	_aura.position.y = 1.5 * boss.model_scale * 0.5
	add_child(_aura)
	_guard_fx = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 1.4 * boss.model_scale * 0.5 + 0.8
	sm.height = sm.radius * 2.0
	_guard_fx.mesh = sm
	var gm: ShaderMaterial = ShaderMaterial.new()
	gm.shader = preload("res://shaders/barrier.gdshader")
	gm.set_shader_parameter(&"color", _guard_color())
	_guard_fx.material_override = gm
	_guard_fx.position.y = sm.radius * 0.8
	_guard_fx.visible = false
	add_child(_guard_fx)


func _guard_color() -> Color:
	match boss.mechanic:
		BossData.Mechanic.SHIELD:
			return Color("7fd66b")
		BossData.Mechanic.ARMOR:
			return Color("9fe3ff")
		BossData.Mechanic.OVERHEAT:
			return Color("ff8a3c")
		BossData.Mechanic.SUBMERGE:
			return Color("3fb6a8")
	return Color("b67cff")


func current_mechanic() -> BossData.Mechanic:
	if boss.mechanic != BossData.Mechanic.ALL:
		return boss.mechanic
	return [BossData.Mechanic.SHIELD, BossData.Mechanic.ARMOR, BossData.Mechanic.SUBMERGE][mini(phase, 2)]


func breaker_for(mech: BossData.Mechanic) -> StringName:
	match mech:
		BossData.Mechanic.SHIELD:
			return &"umbral_pulse"
		BossData.Mechanic.ARMOR:
			return &"arcane_lance"
		BossData.Mechanic.OVERHEAT:
			return &"frost_shackles"
		BossData.Mechanic.SUBMERGE:
			return &"ether_chain"
	return &""


# --- Laço ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD:
		return
	vulnerable_time = maxf(vulnerable_time - delta, 0.0)
	if boss.mechanic != BossData.Mechanic.NONE and target != null:
		_guard_timer -= delta
		if not guarded and _guard_timer <= 0.0 and vulnerable_time <= 0.0:
			_set_guard(true)
		elif guarded and _guard_timer <= -14.0:
			# Janela automática: mesmo sem o feitiço certo a luta não trava.
			_break_guard(false)
	# Mantém o chefe dentro da arena.
	var flat: Vector3 = global_position - arena_center
	flat.y = 0.0
	if flat.length() > arena_radius:
		global_position -= flat.normalized() * (flat.length() - arena_radius)


func _set_guard(on: bool) -> void:
	guarded = on
	_guard_fx.visible = on
	if on:
		_guard_timer = 0.0
		Audio.play(&"barrier", global_position)
		if current_mechanic() == BossData.Mechanic.SUBMERGE and boss.body == &"serpent":
			model.play(&"submerged")


func _break_guard(by_spell: bool) -> void:
	_set_guard(false)
	_guard_timer = 10.0
	vulnerable_time = 5.0 if by_spell else 3.0
	model.play_once(&"Hit_B" if boss.body == &"skeleton" else &"idle")
	if boss.body == &"serpent":
		model.play(&"rise")
	set_state(State.STAGGER)
	var vfx: Vfx = Vfx.get_for(self)
	if vfx != null:
		vfx.shockwave(global_position, 6.0, _guard_color(), 0.5)
		vfx.impact(global_position + Vector3.UP * 2.0, _guard_color(), 2.0, 48)
	Audio.play(&"impact_heavy", global_position)
	HitStop.hit(get_tree(), 80, 0.05)


func _think(delta: float) -> Vector3:
	if target == null:
		var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
		if player != null and player.global_position.distance_to(arena_center) < arena_radius + 4.0:
			target = player
			set_state(State.CHASE)
		return Vector3.ZERO
	match state:
		State.CHASE:
			var d: float = _flat_dist(target.global_position)
			if cooldowns.ready(&"attack"):
				_choose_attack()
				return Vector3.ZERO
			if d > 6.0 and boss.body != &"serpent":
				return _steer_to(target.global_position, data.run_speed)
			_face(target.global_position)
		State.ATTACK_WINDUP:
			if _attack != &"dash":
				_face(target.global_position)
			var k: float = clampf(_state_time / _windup_time(), 0.0, 1.0)
			model.set_eye_intensity(1.0 + k * 3.0)
			if _state_time >= _windup_time():
				_execute_attack()
				set_state(State.ATTACK_RECOVER)
		State.ATTACK_RECOVER:
			model.set_eye_intensity(1.0)
			if _attack == &"dash" and _state_time < 0.5:
				var dir: Vector3 = (_strike_point - global_position)
				dir.y = 0.0
				return dir.normalized() * 22.0 if dir.length() > 1.0 else Vector3.ZERO
			if _state_time >= 0.9:
				set_state(State.CHASE)
		State.STAGGER:
			if _state_time > 1.2:
				set_state(State.CHASE)
		_:
			set_state(State.CHASE)
	return Vector3.ZERO


func _windup_time() -> float:
	match _attack:
		&"nova":
			return 2.2
		&"summon":
			return 1.0
		&"volley":
			return 0.8
		&"dash":
			return 1.1
	return 1.0 if phase == 0 else 0.8


func _choose_attack() -> void:
	var list: Array = boss.phase_attacks[mini(phase, boss.phase_attacks.size() - 1)]
	_attack = StringName(str(list[_attack_index % list.size()]))
	_attack_index += 1
	if _attack == &"summon" and _alive_minions() >= 3:
		_attack = &"slam"
	_strike_point = target.global_position
	set_state(State.ATTACK_WINDUP)
	var vfx: Vfx = Vfx.get_for(self)
	_markers.clear()
	match _attack:
		&"slam":
			model.play_once(&"2H_Melee_Attack_Chop", 0.1, 0.7)
			if vfx != null:
				_markers.append(vfx.ground_marker(_strike_point, 4.5, Color(0.95, 0.3, 0.3, 0.9), _windup_time()))
		&"sweep":
			model.play_once(&"2H_Melee_Attack_Spin", 0.1, 0.8)
			if vfx != null:
				_markers.append(vfx.ground_marker(global_position, 7.0, Color(0.95, 0.5, 0.25, 0.9), _windup_time()))
		&"nova":
			model.play_once(&"Spellcast_Summon", 0.1, 0.6)
			if vfx != null:
				_markers.append(vfx.ground_marker(global_position, 13.0, Color(0.7, 0.2, 1.0, 0.9), _windup_time()))
		&"dash":
			model.play_once(&"Taunt", 0.1, 1.0)
			if vfx != null:
				for i: int in 4:
					var p: Vector3 = global_position.lerp(_strike_point, float(i + 1) / 4.0)
					_markers.append(vfx.ground_marker(p, 2.2, Color(0.95, 0.35, 0.35, 0.9), _windup_time()))
		_:
			model.play_once(&"Spellcast_Shoot", 0.1, 0.8)
	Audio.play(&"charge", global_position, -2.0)


func _execute_attack() -> void:
	cooldowns.start(&"attack", (1.6 if phase == 0 else 1.1) * _rng.randf_range(0.9, 1.2))
	var info: DamageInfo = DamageInfo.make(boss.damage, DamageInfo.Element.PHYSICAL, self, boss.id)
	info.knockback = 8.0
	info.stagger = 0.8
	var vfx: Vfx = Vfx.get_for(self)
	match _attack:
		&"slam":
			Spells.apply_area(self, _strike_point + Vector3.UP, 4.5, info, 2)
			if vfx != null:
				vfx.shockwave(_strike_point, 5.0, Color("c9bfa8"), 0.4)
				vfx.impact(_strike_point + Vector3.UP * 0.3, Color("ff7a5a"), 2.0, 40)
			Audio.play(&"boom", _strike_point, -4.0)
		&"sweep":
			Spells.apply_area(self, global_position + Vector3.UP, 7.0, info, 2)
			if vfx != null:
				vfx.shockwave(global_position, 7.5, Color("ffb765"), 0.35)
			Audio.play(&"blade_swing", global_position)
		&"nova":
			info.amount *= 1.6
			Spells.apply_area(self, global_position + Vector3.UP, 13.0, info, 2)
			if vfx != null:
				vfx.shockwave(global_position, 13.0, boss.eye_color, 0.8)
				vfx.flash(global_position + Vector3.UP * 3.0, boss.eye_color, 10.0, 0.5)
			Audio.play(&"boom", global_position)
		&"wave":
			# Onda que se expande: quem estiver no chão dentro do anel leva dano.
			if vfx != null:
				vfx.shockwave(global_position, arena_radius, boss.eye_color, 1.2)
			_wave_hits(info)
		&"volley":
			_volley(info, 5 if phase == 0 else 9)
		&"summon":
			_summon()
		&"dash":
			pass
	if _attack == &"dash":
		cooldowns.start(&"dash_hit", 0.0)


func _wave_hits(info: DamageInfo) -> void:
	var t0: float = Time.get_ticks_msec() / 1000.0
	var player: Player = target as Player
	while is_inside_tree() and Time.get_ticks_msec() / 1000.0 - t0 < 1.2:
		await get_tree().physics_frame
		if player == null or not is_instance_valid(player):
			return
		var r: float = (Time.get_ticks_msec() / 1000.0 - t0) / 1.2 * arena_radius
		var d: float = Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
		if absf(d - r) < 1.2 and player.is_on_floor():
			player.take_damage(info)
			return


func _volley(info: DamageInfo, n: int) -> void:
	var pool: ProjectilePool = ProjectilePool.get_for(self)
	if pool == null or target == null:
		return
	var from: Vector3 = global_position + Vector3.UP * 1.8 * boss.model_scale * 0.5
	var to: Vector3 = target.global_position + Vector3.UP
	var base_dir: Vector3 = (to - from).normalized()
	for i: int in n:
		var spread: float = (float(i) - (n - 1) * 0.5) * 0.12
		var dir: Vector3 = base_dir.rotated(Vector3.UP, spread)
		var p: Projectile = pool.take()
		p.mask = Projectile.MASK_FROM_ENEMY
		p.exclude = [get_rid()]
		var pi: DamageInfo = DamageInfo.make(info.amount * 0.45, DamageInfo.Element.ARCANE, self, boss.id)
		p.launch(from, dir, 22.0, pi, boss.eye_color, 1.2)
	Audio.play(&"cast_heavy", from)


func _summon() -> void:
	var data_m: EnemyData = load("res://data/enemies/%s.tres" % String(boss.summon_id)) as EnemyData
	if data_m == null:
		return
	for i: int in 2:
		var a: float = _rng.randf() * TAU
		var p: Vector3 = arena_center + Vector3(cos(a), 0.0, sin(a)) * arena_radius * 0.6
		var e: Enemy = IslandWorld.spawn_into(get_parent() as Node3D, data_m, p + Vector3.UP * 0.3)
		minions.append(e)
		var vfx: Vfx = Vfx.get_for(self)
		if vfx != null:
			vfx.impact(p + Vector3.UP, boss.eye_color, 1.2, 30)


func _alive_minions() -> int:
	var n: int = 0
	for m: Enemy in minions:
		if is_instance_valid(m) and m.is_alive():
			n += 1
	return n


# --- Dano e fases -----------------------------------------------------------------------

func _hit_multiplier(info: DamageInfo) -> float:
	if guarded:
		return 0.0
	return 2.0 if vulnerable_time > 0.0 else 1.0


func take_damage(info: DamageInfo) -> bool:
	if state == State.DEAD:
		return false
	if guarded:
		var needed: StringName = breaker_for(current_mechanic())
		var charged: bool = info.spell_id != &"arcane_lance" or info.stagger >= 0.85
		if info.spell_id == needed and charged:
			_break_guard(true)
		else:
			var vfx: Vfx = Vfx.get_for(self)
			if vfx != null:
				vfx.impact(info.hit_position, _guard_color(), 0.6, 10)
			Audio.play(&"barrier", global_position, -10.0)
		return false
	# Golpes comuns não atordoam o chefe (poise alto).
	var ok: bool = super.take_damage(info)
	_check_phase()
	return ok


func apply_status(kind: StatusEffects.Kind, duration: float, power: float) -> void:
	if kind == StatusEffects.Kind.FROZEN and guarded and current_mechanic() == BossData.Mechanic.OVERHEAT:
		_break_guard(true)
		return
	# Chefes ficam congelados por menos tempo.
	super.apply_status(kind, duration * 0.4, power)


func _check_phase() -> void:
	var ratio: float = health / max_health
	var next: int = 0
	for t: float in boss.phase_thresholds:
		if ratio <= t:
			next += 1
	if next > phase:
		phase = next
		phase_changed.emit(phase)
		_guard_timer = 2.0
		if boss.mechanic == BossData.Mechanic.ALL:
			# Cada fase do chefe final abre com a sua mecânica característica.
			vulnerable_time = 0.0
			_guard_timer = 0.6
		var vfx: Vfx = Vfx.get_for(self)
		if vfx != null:
			vfx.shockwave(global_position, 10.0, boss.eye_color, 0.8)
		# Mudança visual: aura mais intensa e escala maior.
		(_aura.process_material as ParticleProcessMaterial).color = boss.eye_color.lightened(0.2 * phase)
		_aura.amount = 60 + 50 * phase
		model.scale *= 1.08
		model.set_eye_intensity(2.0)
		var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
		if hud != null and boss.phase2_key != "":
			hud.show_banner(tr(boss.name_key), tr(boss.phase2_key), 3.0)
		Audio.play(&"boom", global_position, -2.0)


func _die() -> void:
	super._die()
	_guard_fx.visible = false
	_aura.emitting = false
	for m: Enemy in minions:
		if is_instance_valid(m) and m.is_alive():
			m._die()
	defeated.emit(self)


func _animate(move: Vector3) -> void:
	if boss.body == &"skeleton":
		super._animate(move)
	elif boss.body == &"golem":
		if state != State.ATTACK_WINDUP and state != State.ATTACK_RECOVER:
			model.play(&"chase" if move.length() > 1.0 else &"idle")
		elif state == State.ATTACK_WINDUP:
			model.play(&"windup")
		else:
			model.play(&"slam")
