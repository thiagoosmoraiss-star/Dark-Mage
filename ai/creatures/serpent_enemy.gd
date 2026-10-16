class_name SerpentEnemy
extends Enemy
## Serpente do Lago: fica submersa e imune; emerge quando o jogador chega
## perto da água, cospe veneno (projéteis) e volta a mergulhar após algumas
## rajadas. Só pode ser ferida enquanto está erguida.

const EMERGE_RANGE: float = 18.0

var _spits: int = 0


func _make_model() -> EnemyModel:
	return SerpentModel.new()


func _uses_gravity() -> bool:
	return false


func _ready() -> void:
	super._ready()
	model.play(&"submerged")
	collision_layer = 0


func _sm() -> SerpentModel:
	return model as SerpentModel


func take_damage(info: DamageInfo) -> bool:
	if _sm() == null or _sm().emerge < 0.6:
		return false
	return super.take_damage(info)


func _think(_delta: float) -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var near: bool = player != null and player.global_position.distance_to(global_position) < EMERGE_RANGE
	match state:
		State.IDLE, State.PATROL, State.SUSPICIOUS, State.RETURN:
			if near:
				target = player
				model.play(&"rise")
				Audio.play(&"impact_heavy", global_position, -6.0)
				set_state(State.CHASE)
		State.CHASE:
			collision_layer = 4 if _sm().emerge > 0.6 else 0
			if not near and _state_time > 3.0:
				model.play(&"submerged")
				collision_layer = 0
				target = null
				set_state(State.IDLE)
			elif target != null:
				_face(target.global_position)
				if _sm().emerge > 0.9 and cooldowns.ready(&"attack"):
					set_state(State.ATTACK_WINDUP)
					model.play(&"windup")
		State.ATTACK_WINDUP:
			if target != null:
				_face(target.global_position)
			model.set_eye_intensity(1.0 + _state_time / data.windup * 3.0)
			if _state_time >= data.windup:
				_spit()
				set_state(State.ATTACK_RECOVER)
		State.ATTACK_RECOVER:
			model.set_eye_intensity(1.0)
			if _state_time > 0.8:
				_spits += 1
				if _spits >= 3:
					# Mergulha e reaparece um pouco depois.
					_spits = 0
					model.play(&"submerged")
					cooldowns.start(&"attack", 5.0)
				else:
					model.play(&"rise")
				set_state(State.CHASE)
		State.STAGGER:
			if _state_time > 0.5:
				set_state(State.CHASE)
	return Vector3.ZERO


func _spit() -> void:
	model.play(&"spit")
	cooldowns.start(&"attack", data.attack_cooldown)
	var pool: ProjectilePool = ProjectilePool.get_for(self)
	if pool == null or target == null:
		return
	var from: Vector3 = (model as SerpentModel).head.global_position
	var info: DamageInfo = DamageInfo.make(data.damage * damage_mult, DamageInfo.Element.PHYSICAL, self, data.id)
	info.knockback = 3.0
	var p: Projectile = pool.take()
	p.mask = Projectile.MASK_FROM_ENEMY
	p.gravity = 9.0
	p.max_distance = 50.0
	p.exclude = [get_rid()]
	var to: Vector3 = target.global_position + Vector3.UP
	var dir: Vector3 = (to - from)
	var flight: float = dir.length() / data.projectile_speed
	dir.y += 0.5 * p.gravity * flight * flight
	p.launch(from, dir, data.projectile_speed, info, Color("7fff9e"), 1.1)
	Audio.play(&"cast_bolt", from)


func _animate(_move: Vector3) -> void:
	pass
