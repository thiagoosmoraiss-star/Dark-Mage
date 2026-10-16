class_name Enemy
extends CharacterBody3D
## Inimigo com máquina de estados: patrulha, suspeita, perseguição, ataque com
## telegrafia (pose + brilho + marcador no chão), recuperação, recuo, retorno,
## atordoamento e morte. Percepção por visão (cone + linha de visão) e som.

signal died(enemy: Enemy)
signal state_changed(old_state: int, new_state: int)

enum State { IDLE, PATROL, SUSPICIOUS, CHASE, ATTACK_WINDUP, ATTACK_RECOVER, REPOSITION, RETURN, STAGGER, DEAD }

const STATE_NAMES: Array[String] = ["idle", "patrol", "suspicious", "chase", "windup", "recover", "reposition",
	"return", "stagger", "dead"]
const LEASH: float = 45.0
const PATROL_RADIUS: float = 10.0
const GRAVITY: float = 22.0

@export var data: EnemyData
@export var elite: bool = false

var state: State = State.IDLE
var health: float = 60.0
var max_health: float = 60.0
var damage_mult: float = 1.0
var home: Vector3
var target: Node3D
var last_seen: Vector3
var status: StatusEffects = StatusEffects.new()
var cooldowns: Cooldowns = Cooldowns.new()
var model: EnemyModel
var agent: NavigationAgent3D

var _state_time: float = 0.0
var _perceive_timer: float = 0.0
var _patrol_goal: Vector3
var _has_token: bool = false
var _marker: Decal
var _knock: Vector3 = Vector3.ZERO
var _lost_time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _strafe_dir: float = 1.0


func _ready() -> void:
	add_to_group(&"enemy")
	collision_layer = 4
	collision_mask = 1 | 4
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.4 * data.model_scale
	cap.height = 1.7 * data.model_scale
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = cap
	col.position.y = cap.height * 0.5
	add_child(col)
	model = _make_model()
	model.name = "Model"
	add_child(model)
	model.setup(data)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 1.0
	agent.target_desired_distance = 1.2
	agent.radius = cap.radius
	agent.height = cap.height
	add_child(agent)
	_rng.seed = get_instance_id()
	home = global_position
	_patrol_goal = home
	var night: float = 0.0
	var atmo: Node = get_tree().get_first_node_in_group(&"atmosphere")
	if atmo != null:
		night = JsonUtil.num(atmo.call(&"night_factor"), 0.0)
	var mult: float = (1.8 if elite else 1.0) * (1.0 + 0.3 * night)
	max_health = data.health * mult
	health = max_health
	damage_mult = (1.5 if elite else 1.0) * (1.0 + 0.25 * night)
	if elite:
		model.scale = Vector3.ONE * 1.2
	status.applied.connect(_on_status_applied)
	status.expired.connect(_on_status_expired)
	Events.spell_cast.connect(_on_noise)


func is_alive() -> bool:
	return state != State.DEAD


## Subclasses trocam o visual (criaturas procedurais).
func _make_model() -> EnemyModel:
	return EnemyModel.new()


## Gravidade aplicada a cada passo (voadores e criaturas aquáticas desligam).
func _uses_gravity() -> bool:
	return true


## Multiplicador de dano recebido conforme o ponto atingido (ponto fraco).
func _hit_multiplier(_info: DamageInfo) -> float:
	return 1.0


func set_state(s: State) -> void:
	if s == state:
		return
	var old: State = state
	if old == State.ATTACK_WINDUP and _marker != null:
		_marker.visible = false
	state = s
	_state_time = 0.0
	if s != State.ATTACK_WINDUP and s != State.ATTACK_RECOVER and _has_token:
		_release_token()
	state_changed.emit(old, s)


# --- Laço principal ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_state_time += delta
		if _state_time > 3.5:
			visible = false
			set_physics_process(false)
		return
	_state_time += delta
	cooldowns.tick(delta)
	var dot: float = status.tick(delta)
	if dot > 0.0:
		_apply_raw_damage(dot, false)
	_perceive_timer -= delta
	if _perceive_timer <= 0.0:
		_perceive_timer = 0.2
		_perceive()
	var move: Vector3 = Vector3.ZERO
	var speed_mult: float = status.speed_multiplier()
	if status.can_act():
		move = _think(delta)
	velocity.x = move.x * speed_mult + _knock.x
	velocity.z = move.z * speed_mult + _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, 18.0 * delta)
	if _uses_gravity():
		velocity.y = -1.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_animate(move)


func _think(_delta: float) -> Vector3:
	match state:
		State.IDLE:
			if _state_time > _rng.randf_range(2.0, 4.0):
				_patrol_goal = home + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(3.0, PATROL_RADIUS)
				set_state(State.PATROL)
		State.PATROL:
			if _flat_dist(_patrol_goal) < 1.2 or _state_time > 10.0:
				set_state(State.IDLE)
			else:
				return _steer_to(_patrol_goal, data.walk_speed)
		State.SUSPICIOUS:
			if _flat_dist(last_seen) > 1.5 and _state_time < 5.0:
				return _steer_to(last_seen, data.walk_speed * 1.3)
			if _state_time > 6.0:
				set_state(State.RETURN)
		State.CHASE:
			return _chase()
		State.REPOSITION:
			return _reposition()
		State.ATTACK_WINDUP:
			_face(target.global_position if target != null else last_seen)
			var k: float = clampf(_state_time / data.windup, 0.0, 1.0)
			model.set_eye_intensity(1.0 + k * 3.0)
			if _state_time >= data.windup:
				_strike()
				set_state(State.ATTACK_RECOVER)
		State.ATTACK_RECOVER:
			model.set_eye_intensity(1.0)
			if _state_time >= 0.6:
				_release_token()
				set_state(State.CHASE)
		State.RETURN:
			if _flat_dist(home) < 2.0:
				health = minf(max_health, health + max_health * 0.5)
				set_state(State.IDLE)
			else:
				return _steer_to(home, data.run_speed * 0.7)
		State.STAGGER:
			if _state_time > 0.55:
				set_state(State.CHASE if target != null else State.IDLE)
	return Vector3.ZERO


func _chase() -> Vector3:
	if target == null:
		set_state(State.SUSPICIOUS)
		return Vector3.ZERO
	if home.distance_to(global_position) > LEASH or _lost_time > 6.0:
		target = null
		set_state(State.RETURN)
		return Vector3.ZERO
	var d: float = _flat_dist(target.global_position)
	var can_see: bool = _has_los(target)
	var in_range: bool = d <= data.attack_range and can_see
	if in_range and cooldowns.ready(&"attack"):
		var director: CombatDirector = CombatDirector.get_for(self)
		if director == null or director.request_token(self):
			_has_token = true
			_begin_windup()
			return Vector3.ZERO
		set_state(State.REPOSITION)
		return Vector3.ZERO
	# Arqueiros: mantêm distância e recuam se o jogador chegar perto.
	if data.attack_kind != EnemyData.AttackKind.MELEE and d < data.preferred_range * 0.55:
		var away: Vector3 = (global_position - target.global_position)
		away.y = 0.0
		_face(target.global_position)
		return away.normalized() * data.run_speed * 0.8
	if data.attack_kind != EnemyData.AttackKind.MELEE and d <= data.preferred_range and can_see:
		_face(target.global_position)
		return Vector3.ZERO
	return _steer_to(target.global_position, data.run_speed)


## Sem vez de atacar: rodeia o jogador a uma distância segura.
func _reposition() -> Vector3:
	if target == null or _state_time > 2.5:
		set_state(State.CHASE)
		return Vector3.ZERO
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var d: float = to.length()
	_face(target.global_position)
	var tangent: Vector3 = Vector3.UP.cross(to.normalized()) * _strafe_dir
	var radial: Vector3 = to.normalized() * (d - maxf(data.attack_range + 2.5, data.preferred_range))
	return (tangent * 2.0 + radial * 0.8).limit_length(data.walk_speed * 1.4)


func _begin_windup() -> void:
	set_state(State.ATTACK_WINDUP)
	_has_token = true
	model.play_once(data.anim_attack, 0.1, 0.9 / maxf(data.windup + 0.3, 0.1))
	if data.attack_kind == EnemyData.AttackKind.MELEE:
		var vfx: Vfx = Vfx.get_for(self)
		if vfx != null:
			var fwd: Vector3 = -global_basis.z
			_marker = vfx.ground_marker(global_position + fwd * data.attack_range * 0.6, data.attack_range * 0.75,
				Color(0.85, 0.2, 0.5, 0.85), data.windup)
	Audio.play(&"blade_swing" if data.attack_kind == EnemyData.AttackKind.MELEE else &"bow_shot", global_position, -6.0)


func _strike() -> void:
	cooldowns.start(&"attack", data.attack_cooldown * _rng.randf_range(0.85, 1.2))
	var amount: float = data.damage * damage_mult
	var info: DamageInfo = DamageInfo.make(amount, DamageInfo.Element.PHYSICAL, self, data.id)
	info.knockback = 4.0
	info.stagger = 0.6
	if data.attack_kind == EnemyData.AttackKind.MELEE:
		var fwd: Vector3 = -global_basis.z
		var center: Vector3 = global_position + fwd * data.attack_range * 0.6 + Vector3.UP
		info.direction = fwd
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = data.attack_range * 0.75
		var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis.IDENTITY, center)
		q.collision_mask = 2
		for h: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 4):
			var t: Node = DamageInfo.find_damageable(h["collider"] as Object)
			if t != null:
				info.hit_position = center
				t.call(&"take_damage", info)
				Audio.play(&"hit_flesh", center)
	else:
		var pool: ProjectilePool = ProjectilePool.get_for(self)
		if pool != null and target != null:
			var from: Vector3 = global_position + Vector3.UP * 1.3 - global_basis.z * 0.5
			var aim: Vector3 = target.global_position + Vector3.UP * 1.0
			# Mira com leve antecipação do movimento do jogador.
			var lead: Vector3 = (target as CharacterBody3D).velocity * (from.distance_to(aim) / data.projectile_speed) * 0.6 if target is CharacterBody3D else Vector3.ZERO
			var p: Projectile = pool.take()
			p.mask = Projectile.MASK_FROM_ENEMY
			p.max_distance = 60.0
			p.impact_scale = 0.7
			p.exclude = [get_rid()]
			p.launch(from, (aim + lead) - from, data.projectile_speed, info, Color("ff7a5a"), 0.8)


# --- Percepção -------------------------------------------------------------------

func _perceive() -> void:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or not player.call(&"is_alive"):
		if target != null:
			target = null
			set_state(State.RETURN)
		return
	var to: Vector3 = player.global_position - global_position
	var d: float = to.length()
	var seen: bool = false
	if d <= data.sight_range:
		var fwd: Vector3 = -global_basis.z
		var cos_half: float = cos(deg_to_rad(data.sight_fov_deg * 0.5))
		var in_cone: bool = fwd.dot(Vector3(to.x, 0.0, to.z).normalized()) >= cos_half or d < 4.0
		seen = (in_cone or target != null) and _has_los(player)
	if seen:
		last_seen = player.global_position
		_lost_time = 0.0
		if target == null:
			target = player
			player.call(&"notify_combat")
			if state != State.STAGGER and state != State.ATTACK_WINDUP:
				set_state(State.CHASE)
	elif target != null:
		_lost_time += 0.2
		if _lost_time > 1.0 and state == State.CHASE:
			target = null
			set_state(State.SUSPICIOUS)


func _on_noise(_spell_id: StringName) -> void:
	if state == State.DEAD or target != null:
		return
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null and player.global_position.distance_to(global_position) <= data.hearing_range:
		last_seen = player.global_position
		if state == State.IDLE or state == State.PATROL:
			set_state(State.SUSPICIOUS)


func _has_los(t: Node3D) -> bool:
	var from: Vector3 = global_position + Vector3.UP * 1.4
	var to: Vector3 = t.global_position + Vector3.UP * 1.2
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# --- Movimento ---------------------------------------------------------------------

func _steer_to(goal: Vector3, speed: float) -> Vector3:
	var next: Vector3 = goal
	if agent != null and NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		agent.target_position = goal
		var path: PackedVector3Array = agent.get_current_navigation_path()
		# Só segue a malha se houver rota de verdade; senão vai direto (com desvio).
		if path.size() > 1 and not agent.is_navigation_finished():
			var candidate: Vector3 = agent.get_next_path_position()
			if Vector2(candidate.x - global_position.x, candidate.z - global_position.z).length() > 0.2:
				next = candidate
	var dir: Vector3 = next - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return Vector3.ZERO
	dir = dir.normalized()
	# Desvio simples de obstáculos à frente (quando não há malha de navegação).
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6,
		global_position + Vector3.UP * 0.6 + dir * 1.6, 1 | 4, [get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		dir = (dir + Vector3.UP.cross(dir) * _strafe_dir).normalized()
	_face(global_position + dir)
	return dir * speed


func _face(p: Vector3) -> void:
	var to: Vector3 = p - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	var want: float = atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, want, 0.25)


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _animate(move: Vector3) -> void:
	if state == State.ATTACK_WINDUP or state == State.ATTACK_RECOVER or state == State.STAGGER:
		return
	var sp: float = Vector2(move.x, move.z).length()
	if sp > data.walk_speed * 1.2:
		model.play(data.anim_run)
	elif sp > 0.1:
		model.play(data.anim_walk)
	else:
		model.play(&"Idle_Combat" if target != null else data.anim_idle)


# --- Dano --------------------------------------------------------------------------

func take_damage(info: DamageInfo) -> bool:
	if state == State.DEAD:
		return false
	var amount: float = info.amount * status.damage_taken_multiplier() * _hit_multiplier(info)
	if amount > info.amount * 1.5:
		info.is_critical = true
	_apply_raw_damage(amount, info.is_critical)
	if info.status_kind >= 0 and state != State.DEAD:
		apply_status(info.status_kind as StatusEffects.Kind, info.status_time, info.status_power)
	Events.damage_dealt.emit(self, info)
	model.flash()
	var vfx: Vfx = Vfx.get_for(self)
	if vfx != null:
		vfx.damage_number(global_position + Vector3.UP * 2.0 * data.model_scale, amount, info.is_critical)
	Audio.play(&"hit_bone", global_position + Vector3.UP)
	if info.knockback > 0.0:
		_knock = info.direction * info.knockback * (1.0 - data.knockback_resist)
		_knock.y = 0.0
	if info.source is Player and info.spell_id != &"basic":
		HitStop.hit(get_tree(), 55, 0.06)
	elif info.source is Player and info.stagger >= 0.7:
		HitStop.hit(get_tree(), 40, 0.1)
	if target == null and info.source is Node3D and (info.source as Node).is_in_group(&"player"):
		target = info.source as Node3D
		last_seen = target.global_position
	if health > 0.0 and info.stagger >= data.poise and state != State.STAGGER:
		set_state(State.STAGGER)
		model.play_once(&"Hit_A", 0.05)
	elif health > 0.0 and state != State.ATTACK_WINDUP and state != State.STAGGER:
		set_state(State.CHASE)
	return true


func _apply_raw_damage(amount: float, _crit: bool) -> void:
	health -= amount
	if health <= 0.0:
		_die()


func apply_status(kind: StatusEffects.Kind, duration: float, power: float) -> void:
	status.apply(kind, duration, power)


func _on_status_applied(kind: StatusEffects.Kind) -> void:
	if kind == StatusEffects.Kind.FROZEN:
		model.set_frozen(true)


func _on_status_expired(kind: StatusEffects.Kind) -> void:
	if kind == StatusEffects.Kind.FROZEN:
		model.set_frozen(false)


func _die() -> void:
	health = 0.0
	set_state(State.DEAD)
	_release_token()
	collision_layer = 0
	collision_mask = 1
	model.set_frozen(false)
	model.play_once(&"Death_A", 0.1)
	Audio.play(&"enemy_death", global_position + Vector3.UP)
	var vfx: Vfx = Vfx.get_for(self)
	if vfx != null:
		vfx.impact(global_position + Vector3.UP, Color("6b2fd6"), 1.4, 40)
	Events.enemy_killed.emit(self)
	died.emit(self)


func _release_token() -> void:
	if not _has_token:
		return
	_has_token = false
	var director: CombatDirector = CombatDirector.get_for(self)
	if director != null:
		director.release_token(self)


## Longe do jogador: para de processar e some (sem perder o estado).
var dormant: bool = false


func set_dormant(on: bool) -> void:
	if on == dormant or state == State.DEAD:
		return
	dormant = on
	set_physics_process(not on)
	model.visible = not on
	model.set_process(not on)
	if model.anim != null:
		model.anim.active = not on
	if on and target != null:
		target = null
		_release_token()
		set_state(State.RETURN)


## Ressuscita no lugar de origem (descanso nas fogueiras).
func revive() -> void:
	health = max_health
	collision_layer = 4
	collision_mask = 1 | 4
	global_position = home
	visible = true
	dormant = false
	model.visible = true
	model.set_process(true)
	target = null
	status.active.clear()
	set_physics_process(true)
	state = State.IDLE
	_state_time = 0.0
	model.play(data.anim_idle)
