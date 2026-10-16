class_name BatEnemy
extends Enemy
## Morcego Espectral: voa em círculos acima do jogador e ataca em mergulho
## telegrafado (para no ar, guincha, olhos acendem, depois mergulha).

const HOVER: float = 4.5

var _dive_dir: Vector3
var _orbit: float = 0.0


func _make_model() -> EnemyModel:
	return BatModel.new()


func _uses_gravity() -> bool:
	return false


func _ready() -> void:
	super._ready()
	_orbit = _rng.randf() * TAU


func _ground_y(p: Vector3) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 80.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else p.y - HOVER


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD:
		velocity.y -= GRAVITY * delta
		return
	if state != State.ATTACK_WINDUP and state != State.ATTACK_RECOVER:
		var want: float = _ground_y(global_position) + HOVER + sin(_state_time * 2.0) * 0.4
		velocity.y = clampf((want - global_position.y) * 2.5, -6.0, 6.0)


func _think(delta: float) -> Vector3:
	if state == State.CHASE and target != null:
		model.play(&"chase")
		_orbit += delta * 1.1
		var center: Vector3 = target.global_position
		var goal: Vector3 = center + Vector3(cos(_orbit), 0.0, sin(_orbit)) * 6.0
		var d: float = _flat_dist(center)
		if d < 9.0 and cooldowns.ready(&"attack") and _has_los(target):
			var director: CombatDirector = CombatDirector.get_for(self)
			if director == null or director.request_token(self):
				_has_token = true
				set_state(State.ATTACK_WINDUP)
				Audio.play(&"charge", global_position, -4.0)
				return Vector3.ZERO
		return _steer_air(goal, data.run_speed)
	if state == State.ATTACK_WINDUP:
		velocity.y = 0.0
		if target != null:
			_face(target.global_position)
			_dive_dir = (target.global_position + Vector3.UP * 0.8 - global_position).normalized()
		model.set_eye_intensity(1.0 + _state_time / data.windup * 3.0)
		if _state_time >= data.windup:
			model.play(&"dive")
			set_state(State.ATTACK_RECOVER)
		return Vector3.ZERO
	if state == State.ATTACK_RECOVER:
		# Mergulho: avança na direção travada; acerta no caminho.
		if _state_time < 0.55:
			velocity.y = _dive_dir.y * data.run_speed * 3.0
			if target != null and global_position.distance_to(target.global_position + Vector3.UP) < 1.3 and cooldowns.ready(&"dive_hit"):
				cooldowns.start(&"dive_hit", 1.0)
				cooldowns.start(&"attack", data.attack_cooldown)
				var info: DamageInfo = DamageInfo.make(data.damage * damage_mult, DamageInfo.Element.ARCANE, self, data.id)
				info.direction = _dive_dir
				info.knockback = 3.0
				target.call(&"take_damage", info)
			return Vector3(_dive_dir.x, 0.0, _dive_dir.z) * data.run_speed * 3.0
		model.set_eye_intensity(1.0)
		cooldowns.start(&"attack", data.attack_cooldown)
		_release_token()
		set_state(State.CHASE)
		return Vector3.ZERO
	model.play(&"idle")
	return super._think(delta)


func _steer_air(goal: Vector3, speed: float) -> Vector3:
	var dir: Vector3 = goal - global_position
	dir.y = 0.0
	if dir.length() < 0.2:
		return Vector3.ZERO
	_face(global_position + dir)
	return dir.normalized() * speed


func _animate(_move: Vector3) -> void:
	pass
