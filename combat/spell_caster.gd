class_name SpellCaster
extends Node
## Conjuração do jogador: ataque básico (combo de 3), feitiços nos slots Q/E/R/F,
## carga ao segurar, mira de ombro, lock-on e carga da ultimate pelo dano.

signal slots_changed
signal ultimate_changed(value: float, max_value: float)
signal lock_changed(target: Node3D)
signal cast_failed(reason: StringName)

const SLOT_ACTIONS: Array[StringName] = [&"spell_1", &"spell_2", &"spell_3", &"spell_4"]
const BASIC_DAMAGE: Array[float] = [8.0, 8.0, 16.0]
const BASIC_INTERVAL: float = 0.26
const COMBO_RESET: float = 0.85
const LOCK_RANGE: float = 28.0
const AUTO_AIM_RANGE: float = 24.0
const AUTO_AIM_COS: float = 0.82  # ~35°

var player: Player
var cooldowns: Cooldowns = Cooldowns.new()
var equipped: Array[StringName] = [&"arcane_lance", &"umbral_pulse", &"ether_chain", &"violet_aegis"]
## Os 4 feitiços iniciais; os outros 4 vêm dos Guardiões (blink, gelo, astro, ultimate).
var unlocked: Dictionary[StringName, bool] = {
	&"arcane_lance": true, &"umbral_pulse": true, &"ether_chain": true, &"violet_aegis": true,
}
var ultimate_charge: float = 0.0
var lock_target: Node3D = null
var aiming: bool = false
## Poder arcano (atributo): multiplica o dano.
var power: float = 1.0

var _combo: int = 0
var _combo_timer: float = 0.0
var _basic_cd: float = 0.0
var _cast_lock: float = 0.0
var _charging_slot: int = -1
var _charge_time: float = 0.0


func _ready() -> void:
	player = get_parent() as Player
	Events.damage_dealt.connect(_on_damage_dealt)


func _physics_process(delta: float) -> void:
	if player == null or player.state == Player.State.DEAD:
		return
	cooldowns.tick(delta)
	_basic_cd = maxf(_basic_cd - delta, 0.0)
	_cast_lock = maxf(_cast_lock - delta, 0.0)
	_combo_timer = maxf(_combo_timer - delta, 0.0)
	if _combo_timer <= 0.0:
		_combo = 0
	_validate_lock()
	aiming = player.pressed(&"aim")
	if player.cam_rig != null:
		player.cam_rig.aiming = aiming
		if lock_target != null and not aiming:
			_face_camera_to(lock_target.global_position, delta)
	if player.just_pressed(&"lock_on"):
		toggle_lock()
	var busy: bool = player.state == Player.State.CLIMB or player.state == Player.State.SWIM or player.state == Player.State.GLIDE
	if busy:
		_charging_slot = -1
		return
	# Ataque básico.
	if player.pressed(&"attack") and _basic_cd <= 0.0 and _cast_lock <= 0.0:
		basic_attack()
	# Feitiços: tocar = conjura; segurar = carrega (se o feitiço tiver carga).
	for i: int in SLOT_ACTIONS.size():
		var action: StringName = SLOT_ACTIONS[i]
		if player.just_pressed(action):
			var s: SpellData = slot_spell(i)
			if s != null and s.charge_time > 0.0 and _ready_to_cast(s, false):
				_charging_slot = i
				_charge_time = 0.0
				Audio.play(&"charge", player.global_position, -6.0)
			else:
				cast_slot(i)
		if _charging_slot == i:
			if player.pressed(action):
				_charge_time += delta
			else:
				var s2: SpellData = slot_spell(i)
				var charge: float = clampf(_charge_time / maxf(s2.charge_time, 0.01), 0.0, 1.0) if s2 != null else 0.0
				_charging_slot = -1
				cast_slot(i, charge)
	# Ultimate: os dois botões de feitiço 1 e 4 juntos.
	if player.pressed(&"spell_1") and player.pressed(&"spell_4") and ultimate_ready():
		cast_ultimate()
	# Blink no ar ou ao esquivar mirando.
	if player.just_pressed(&"dodge") and (player.state == Player.State.AIR or aiming) and unlocked.has(&"umbral_step"):
		cast_spell(Spells.get_spell(&"umbral_step"), 0.0)


func charge_ratio() -> float:
	if _charging_slot < 0:
		return 0.0
	var s: SpellData = slot_spell(_charging_slot)
	return clampf(_charge_time / maxf(s.charge_time, 0.01), 0.0, 1.0) if s != null else 0.0


func slot_spell(i: int) -> SpellData:
	if i < 0 or i >= equipped.size() or equipped[i] == &"":
		return null
	return Spells.get_spell(equipped[i])


func equip(slot: int, id: StringName) -> void:
	if unlocked.has(id) and slot >= 0 and slot < 4:
		equipped[slot] = id
		slots_changed.emit()


func unlock(id: StringName) -> void:
	unlocked[id] = true
	slots_changed.emit()


# --- Conjuração -----------------------------------------------------------------

## O cajado equipado define elemento, dano, velocidade, cor, número de projéteis,
## abertura do leque, cadência e efeito de status do ataque básico.
func basic_attack() -> void:
	var staff: Dictionary = Inventory.basic_attack()
	var count: int = maxi(1, JsonUtil.get_i(staff, "count", 1))
	var spread: float = deg_to_rad(JsonUtil.get_f(staff, "spread"))
	var element: DamageInfo.Element = JsonUtil.get_i(staff, "element") as DamageInfo.Element
	var col: Color = Color(JsonUtil.get_s(staff, "color", "b67cff"))
	var st: Variant = staff.get("status", [])
	var pool: ProjectilePool = ProjectilePool.get_for(self)
	var dir: Vector3 = aim_direction()
	for k: int in count:
		var info: DamageInfo = DamageInfo.make(BASIC_DAMAGE[_combo] * power * JsonUtil.get_f(staff, "mult", 1.0), element, player, &"basic")
		info.stagger = 0.25 if _combo < 2 else 0.7
		info.knockback = 1.0 if _combo < 2 else 4.0
		if st is Array and (st as Array).size() == 4 and randf() < JsonUtil.num((st as Array)[3]):
			info.status_kind = roundi(JsonUtil.num((st as Array)[0]))
			info.status_time = JsonUtil.num((st as Array)[1])
			info.status_power = JsonUtil.num((st as Array)[2])
		if pool == null:
			break
		var p: Projectile = pool.take()
		p.mask = Projectile.MASK_FROM_PLAYER
		p.max_distance = 40.0
		p.impact_scale = 0.8 if _combo < 2 else 1.3
		p.exclude = [player.get_rid()]
		var size: float = 0.7 if _combo < 2 else 1.1
		var off: float = (k - (count - 1) * 0.5) * spread
		p.launch(cast_origin(), dir.rotated(Vector3.UP, off), JsonUtil.get_f(staff, "speed", 52.0), info, col, size)
	Audio.play(&"cast_bolt", cast_origin(), 0.0 if _combo < 2 else 3.0)
	if player.model != null:
		player.model.play_oneshot(&"attack", 0.18)
	_face_aim()
	_combo = (_combo + 1) % 3
	_combo_timer = COMBO_RESET
	_basic_cd = (BASIC_INTERVAL if _combo != 0 else BASIC_INTERVAL * 1.8) * JsonUtil.get_f(staff, "interval", 1.0)
	Events.spell_cast.emit(&"basic")


func cast_slot(i: int, charge: float = 0.0) -> bool:
	var s: SpellData = slot_spell(i)
	if s == null:
		return false
	return cast_spell(s, charge)


func _ready_to_cast(s: SpellData, report: bool) -> bool:
	if _cast_lock > 0.0:
		return false
	if not cooldowns.ready(s.id):
		if report:
			cast_failed.emit(&"cooldown")
		return false
	if player.stats.mana < s.mana_cost:
		if report:
			cast_failed.emit(&"mana")
			Audio.play(&"ui_error")
		return false
	return true


func cast_spell(s: SpellData, charge: float) -> bool:
	if s == null or not _ready_to_cast(s, true):
		return false
	player.stats.use_mana(s.mana_cost)
	cooldowns.start(s.id, s.cooldown)
	_cast_lock = s.cast_lock
	player.stats.in_combat = true
	if player.model != null:
		player.model.play_oneshot(s.cast_anim, s.cast_lock)
	_face_aim()
	match s.kind:
		SpellData.Kind.PROJECTILE:
			Spells.projectile(self, s, charge, aim_direction())
		SpellData.Kind.AREA:
			Spells.area(self, s)
		SpellData.Kind.CHAIN:
			Spells.chain(self, s, _chain_first_target(s.range_m))
		SpellData.Kind.BARRIER:
			Spells.barrier(self, s)
		SpellData.Kind.METEOR:
			Spells.meteor(self, s)
		SpellData.Kind.BLINK:
			Spells.blink(self, s)
		SpellData.Kind.CONTROL:
			Spells.control(self, s)
		SpellData.Kind.ULTIMATE:
			Spells.ultimate(self, s)
	Events.spell_cast.emit(s.id)
	return true


func ultimate_ready() -> bool:
	var s: SpellData = Spells.get_spell(&"beacon_wrath")
	return unlocked.has(&"beacon_wrath") and s != null and ultimate_charge >= float(s.count)


func cast_ultimate() -> void:
	var s: SpellData = Spells.get_spell(&"beacon_wrath")
	if cast_spell(s, 0.0):
		ultimate_charge = 0.0
		ultimate_changed.emit(0.0, float(s.count))


func _on_damage_dealt(_target: Node, info: RefCounted) -> void:
	var d: DamageInfo = info as DamageInfo
	if d == null or d.source != player or d.spell_id == &"beacon_wrath":
		return
	var s: SpellData = Spells.get_spell(&"beacon_wrath")
	var max_v: float = float(s.count) if s != null else 300.0
	ultimate_charge = minf(ultimate_charge + d.amount, max_v)
	ultimate_changed.emit(ultimate_charge, max_v)


# --- Mira e alvo -------------------------------------------------------------------

func cast_origin() -> Vector3:
	if player.model != null and player.model.staff_light != null and is_instance_valid(player.model.staff_light):
		return player.model.staff_light.global_position
	return player.global_position + Vector3.UP * 1.4 + player.facing * 0.4


## Ponto mirado: centro da tela (mira) ou à frente.
func aim_point(max_range: float) -> Vector3:
	var cam: Camera3D = player.cam_rig.camera if player.cam_rig != null else null
	if cam == null:
		return cast_origin() + player.facing * max_range
	var from: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_basis.z
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * (max_range + 10.0), 1 | 4, [player.get_rid()])
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else from + dir * max_range


## Ponto no chão para feitiços de área mirados (meteoro, gelo).
func ground_aim_point(max_range: float) -> Vector3:
	var p: Vector3
	if lock_target != null:
		p = lock_target.global_position
	elif aiming:
		p = aim_point(max_range)
	else:
		var auto: Node3D = _auto_target(max_range)
		p = auto.global_position if auto != null else player.global_position + player.facing * minf(8.0, max_range)
	var flat: Vector3 = p - player.global_position
	flat.y = 0.0
	if flat.length() > max_range:
		p = player.global_position + flat.normalized() * max_range
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 60.0, 1)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func aim_direction() -> Vector3:
	var origin: Vector3 = cast_origin()
	if aiming:
		return (aim_point(60.0) - origin).normalized()
	if lock_target != null:
		return (lock_target.global_position + Vector3.UP * 1.0 - origin).normalized()
	var auto: Node3D = _auto_target(AUTO_AIM_RANGE)
	if auto != null:
		return (auto.global_position + Vector3.UP * 1.0 - origin).normalized()
	var cam_fwd: Vector3 = -player.cam_rig.camera.global_basis.z if player.cam_rig != null else player.facing
	cam_fwd.y = clampf(cam_fwd.y, -0.25, 0.35)
	return cam_fwd.normalized()


func _auto_target(range_m: float) -> Node3D:
	var fwd: Vector3 = player.facing
	if player.cam_rig != null:
		fwd = -player.cam_rig.camera.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
	var best: Node3D = null
	var best_score: float = -1.0
	for e: Node in get_tree().get_nodes_in_group(&"enemy"):
		var en: Node3D = e as Node3D
		if en == null or not en.call(&"is_alive"):
			continue
		var to: Vector3 = en.global_position - player.global_position
		var d: float = to.length()
		if d > range_m * 1.3:
			continue
		var c: float = fwd.dot(Vector3(to.x, 0.0, to.z).normalized())
		# Assistência de mira (acessibilidade): cone de ~55° e alcance 30% maior.
		var assist: bool = Settings.get_value("accessibility", "aim_assist") == true
		if c < (0.57 if assist else AUTO_AIM_COS) or (assist == false and d > range_m):
			continue
		var score: float = c * 2.0 - d / range_m
		if score > best_score:
			best_score = score
			best = en
	return best


func _chain_first_target(range_m: float) -> Node3D:
	if lock_target != null and lock_target.global_position.distance_to(player.global_position) <= range_m:
		return lock_target
	return _auto_target(range_m)


func toggle_lock() -> void:
	if lock_target != null:
		set_lock(null)
		return
	var cand: Node3D = _auto_target(LOCK_RANGE)
	if cand == null:
		# Sem nada à frente: o mais próximo no alcance.
		var best_d: float = LOCK_RANGE
		for e: Node in get_tree().get_nodes_in_group(&"enemy"):
			var en: Node3D = e as Node3D
			if en != null and en.call(&"is_alive"):
				var d: float = en.global_position.distance_to(player.global_position)
				if d < best_d:
					best_d = d
					cand = en
	set_lock(cand)


func set_lock(t: Node3D) -> void:
	lock_target = t
	lock_changed.emit(t)
	Events.lock_on_changed.emit(t)


func _validate_lock() -> void:
	if lock_target == null:
		return
	if not is_instance_valid(lock_target) or not lock_target.call(&"is_alive") \
			or lock_target.global_position.distance_to(player.global_position) > LOCK_RANGE * 1.3:
		set_lock(null)


func _face_aim() -> void:
	var d: Vector3 = aim_direction()
	d.y = 0.0
	if d.length() > 0.1:
		player.facing = d.normalized()
		player.rotation.y = atan2(-player.facing.x, -player.facing.z)


func _face_camera_to(target: Vector3, delta: float) -> void:
	var to: Vector3 = target - player.cam_rig.global_position
	var want_yaw: float = atan2(-to.x, -to.z)
	player.cam_rig.yaw = lerp_angle(player.cam_rig.yaw, want_yaw, 1.0 - exp(-6.0 * delta))
