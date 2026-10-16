class_name GolemEnemy
extends Enemy
## Golem: lento, ergue os braços (telegrafia longa + círculo no chão) e esmaga
## numa área com onda de choque. Fica exposto depois do golpe. O cristal nas
## costas recebe dano triplicado.

func _make_model() -> EnemyModel:
	return GolemModel.new()


func _hit_multiplier(info: DamageInfo) -> float:
	var gm: GolemModel = model as GolemModel
	if gm == null or gm.weak_point == null:
		return 1.0
	var near_crystal: bool = info.hit_position.distance_to(gm.weak_point.global_position) < 1.1
	var from_behind: bool = info.direction.dot(-global_basis.z) > 0.35
	return 3.0 if near_crystal or from_behind else 0.8


func _begin_windup() -> void:
	set_state(State.ATTACK_WINDUP)
	_has_token = true
	model.play_once(&"windup")
	var vfx: Vfx = Vfx.get_for(self)
	if vfx != null:
		var fwd: Vector3 = -global_basis.z
		_marker = vfx.ground_marker(global_position + fwd * 2.2 * data.model_scale, data.attack_range * 0.85,
			Color(0.95, 0.35, 0.25, 0.9), data.windup)
	Audio.play(&"charge", global_position, -2.0)


func _strike() -> void:
	model.play_once(&"slam")
	cooldowns.start(&"attack", data.attack_cooldown)
	var center: Vector3 = global_position - global_basis.z * 2.2 * data.model_scale
	var info: DamageInfo = DamageInfo.make(data.damage * damage_mult, DamageInfo.Element.PHYSICAL, self, data.id)
	info.knockback = 9.0
	info.stagger = 1.0
	Spells.apply_area(self, center + Vector3.UP, data.attack_range * 0.85, info, 2)
	var vfx: Vfx = Vfx.get_for(self)
	if vfx != null:
		vfx.shockwave(center, data.attack_range, Color("c9bfa8"), 0.5)
		vfx.impact(center + Vector3.UP * 0.3, Color("8d857f"), 2.0, 40)
	Audio.play(&"boom", center, -4.0)
	Audio.play(&"hit_heavy", center)
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.cam_rig != null and player.global_position.distance_to(center) < 18.0:
		player.cam_rig.shake(0.6, 0.35)


func _animate(move: Vector3) -> void:
	if state == State.ATTACK_WINDUP or state == State.ATTACK_RECOVER:
		return
	model.play(&"chase" if move.length() > data.walk_speed * 1.2 else (&"walk" if move.length() > 0.1 else &"idle"))
