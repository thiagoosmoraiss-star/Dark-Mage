class_name Player
extends CharacterBody3D
## O Mago Sombrio: movimento, travessia (escalada, planador, natação, esquiva) e
## recursos. Visual e animação ficam em PlayerModel; câmera em CameraRig.
## Toda a lógica roda em _physics_process (60 Hz fixo) para ser determinística.

signal state_changed(old_state: int, new_state: int)
signal landed(fall_speed: float)
signal respawned
## Emitido ao fim de cada passo de física (testes contam frames por aqui).
signal stepped(frame: int)

enum State { GROUND, AIR, CLIMB, GLIDE, SWIM, DODGE, DEAD }

const STATE_NAMES: Array[String] = ["ground", "air", "climb", "glide", "swim", "dodge", "dead"]
const CAPSULE_RADIUS: float = 0.35
const CAPSULE_HEIGHT: float = 1.7
## Ações cujo "acabou de apertar" é derivado no modo de input roteirizado.
const TRACKED_ACTIONS: Array[StringName] = [&"jump", &"dodge", &"sprint", &"attack", &"aim", &"lock_on",
	&"spell_1", &"spell_2", &"spell_3", &"spell_4", &"interact"]

@export var tuning: PlayerTuning = PlayerTuning.new()
## Desliga a leitura de input (cutscenes, menus).
@export var input_enabled: bool = true
## Cria câmera própria (desligado em testes sem câmera).
@export var with_camera: bool = true

## Input roteirizado (testes e demonstrações): ação -> pressionada. Quando
## `use_scripted_input` é verdadeiro, o Input real é ignorado.
var use_scripted_input: bool = false
var scripted_input: Dictionary[StringName, bool] = {}
var physics_frames: int = 0
var stats: PlayerStats = PlayerStats.new()
var caster: SpellCaster
## Égide Violeta: dano absorvido restante e duração.
var barrier_hp: float = 0.0
var barrier_time: float = 0.0
## Modo deus de depuração (testes de chefe, capturas): não recebe dano.
var god_mode: bool = false
## Ponto de renascimento (fogueira ativa; no M6, o início).
var respawn_point: Vector3 = Vector3.ZERO
var state: State = State.AIR
var cam_rig: CameraRig
var model: PlayerModel
## Direção de movimento desejada no mundo (0..1 de intensidade).
var move_input: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3.FORWARD
var sprinting: bool = false
var raining: bool = false
## Velocidade horizontal atual (para animação).
var ground_speed: float = 0.0
var last_safe_position: Vector3 = Vector3.ZERO

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _dodge_time: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _climb_normal: Vector3 = Vector3.ZERO
var _climb_ledge_time: float = 0.0
var _safe_timer: float = 0.0
var _drown_time: float = 0.0
var _iframes: float = 0.0
var _air_time: float = 0.0
var _last_fall_speed: float = 0.0
var _prev_pressed: Dictionary[StringName, bool] = {}
var _dodge_started_ms: int = -100000
var _barrier_mesh: MeshInstance3D
var _step_accum: float = 0.0
var _dead_time: float = 0.0
var _combat_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	floor_max_angle = deg_to_rad(tuning.floor_max_angle_deg)
	floor_snap_length = 0.6
	floor_stop_on_slope = true
	floor_constant_speed = true
	safe_margin = 0.02
	collision_layer = 2
	collision_mask = 1 | 4
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = CAPSULE_RADIUS
	shape.height = CAPSULE_HEIGHT
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shape
	col.position.y = CAPSULE_HEIGHT * 0.5
	add_child(col)
	model = PlayerModel.new()
	model.name = "Model"
	add_child(model)
	if with_camera:
		cam_rig = CameraRig.new()
		cam_rig.name = "CameraRig"
		add_child(cam_rig)
		cam_rig.set_target(self)
		cam_rig.yaw = global_rotation.y
	caster = SpellCaster.new()
	caster.name = "SpellCaster"
	add_child(caster)
	var interactor: Interactor = Interactor.new()
	interactor.name = "Interactor"
	add_child(interactor)
	_build_barrier()
	facing = -global_basis.z
	last_safe_position = global_position
	respawn_point = global_position
	if with_camera and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	stats.tick(delta)
	_iframes = maxf(_iframes - delta, 0.0)
	_tick_barrier(delta)
	_combat_timer = maxf(_combat_timer - delta, 0.0)
	if stats.in_combat and _combat_timer <= 0.0:
		stats.in_combat = false
		Events.combat_state_changed.emit(false)
	_read_input()
	match state:
		State.GROUND:
			_ground(delta)
		State.AIR:
			_air(delta)
		State.CLIMB:
			_climb(delta)
		State.GLIDE:
			_glide(delta)
		State.SWIM:
			_swim(delta)
		State.DODGE:
			_dodge(delta)
		State.DEAD:
			velocity = Vector3(0.0, velocity.y - tuning.gravity * delta, 0.0)
			move_and_slide()
			_dead_time += delta
			if _dead_time > 3.0:
				_respawn()
	_track_safe_position(delta)
	var h: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	ground_speed = h.length()
	_footsteps(delta)
	if model != null:
		model.update_pose(self, delta)
	if use_scripted_input:
		for a: StringName in TRACKED_ACTIONS:
			_prev_pressed[a] = pressed(a)
	physics_frames += 1
	stepped.emit(physics_frames)


# --- Input --------------------------------------------------------------------

func _read_input() -> void:
	if not input_enabled:
		move_input = Vector3.ZERO
		sprinting = false
		return
	var v: Vector2 = input_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var b: Basis = cam_rig.flat_basis() if cam_rig != null else Basis.IDENTITY
	move_input = b * Vector3(v.x, 0.0, v.y)
	if move_input.length() > 1.0:
		move_input = move_input.normalized()
	sprinting = pressed(&"sprint")
	if just_pressed(&"jump"):
		_jump_buffer = tuning.jump_buffer


func pressed(action: StringName) -> bool:
	if not input_enabled:
		return false
	if use_scripted_input:
		return scripted_input.get(action, false)
	return Input.is_action_pressed(action)


func just_pressed(action: StringName) -> bool:
	if use_scripted_input:
		return pressed(action) and not _prev_pressed.get(action, false)
	return input_enabled and Input.is_action_just_pressed(action)


func input_vector(neg_x: StringName, pos_x: StringName, neg_y: StringName, pos_y: StringName) -> Vector2:
	if not input_enabled:
		return Vector2.ZERO
	if use_scripted_input:
		var v: Vector2 = Vector2(float(pressed(pos_x)) - float(pressed(neg_x)), float(pressed(pos_y)) - float(pressed(neg_y)))
		return v.normalized() if v.length() > 1.0 else v
	return Input.get_vector(neg_x, pos_x, neg_y, pos_y)


func set_state(s: State) -> void:
	if s == state:
		return
	var old: State = state
	state = s
	state_changed.emit(old, s)


# --- Chão e ar -----------------------------------------------------------------

func _ground(delta: float) -> void:
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	var target_speed: float = tuning.run_speed * move_input.length()
	if move_input.length() < 0.55:
		target_speed = tuning.walk_speed * move_input.length() / 0.55
	if sprinting and move_input.length() > 0.2 and stats.can_use_stamina():
		target_speed = tuning.sprint_speed
		stats.use_stamina(tuning.sprint_stamina_per_s * delta)
	_horizontal(delta, target_speed, 1.0)
	velocity.y = -1.0  # mantém contato em descidas
	move_and_slide()
	_coyote = tuning.coyote_time
	if _jump_buffer > 0.0:
		_jump()
		return
	if just_pressed(&"dodge") and stats.can_use_stamina():
		_start_dodge()
		return
	if _in_water_depth() > tuning.swim_depth:
		set_state(State.SWIM)
		return
	if not is_on_floor():
		set_state(State.AIR)
		_air_time = 0.0
		return
	if _try_start_climb():
		return


func _air(delta: float) -> void:
	_coyote = maxf(_coyote - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_air_time += delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		_jump()
		return
	# Abrir o planador: pular no ar enquanto cai, com distância do chão.
	if _jump_buffer > 0.0 and velocity.y < 0.5 and _air_time > 0.15 and stats.can_use_stamina() \
			and _height_above_ground(3.0) > 2.5:
		_jump_buffer = 0.0
		set_state(State.GLIDE)
		return
	_horizontal(delta, tuning.run_speed * move_input.length() * (1.3 if sprinting else 1.0), tuning.air_control)
	velocity.y = maxf(velocity.y - tuning.gravity * delta, -tuning.max_fall_speed)
	_last_fall_speed = -velocity.y
	move_and_slide()
	if _in_water_depth() > tuning.swim_depth:
		velocity.y *= 0.3
		set_state(State.SWIM)
		return
	if is_on_floor():
		landed.emit(_last_fall_speed)
		set_state(State.GROUND)
		return
	_try_start_climb()


func _jump() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	velocity.y = tuning.jump_velocity
	_air_time = 0.0
	set_state(State.AIR)
	if model != null:
		model.on_jump()


func _horizontal(delta: float, target_speed: float, control: float) -> void:
	var h: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var want: Vector3 = move_input.normalized() * target_speed if move_input.length() > 0.01 else Vector3.ZERO
	var rate: float = (tuning.acceleration if want.length() > h.length() else tuning.deceleration) * control
	h = h.move_toward(want, rate * delta)
	velocity.x = h.x
	velocity.z = h.z
	if move_input.length() > 0.05:
		facing = facing.slerp(move_input.normalized(), clampf(tuning.turn_speed * delta, 0.0, 1.0)).normalized()
		rotation.y = atan2(-facing.x, -facing.z)


# --- Escalada ------------------------------------------------------------------

## Raio para a frente na altura do peito; retorna a normal da parede ou zero.
func _wall_probe(height: float, dist: float = 0.8) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3.UP * height
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + facing * dist, 1)
	return space.intersect_ray(q)


func _try_start_climb() -> bool:
	if move_input.length() < 0.3 or not stats.can_use_stamina():
		return false
	if move_input.normalized().dot(facing) < 0.7:
		return false
	var hit: Dictionary = _wall_probe(1.0, CAPSULE_RADIUS + 0.35)
	if hit.is_empty():
		return false
	var n: Vector3 = hit["normal"]
	var angle: float = rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))
	if angle < tuning.climb_min_angle_deg:
		return false
	_climb_normal = n
	set_state(State.CLIMB)
	velocity = Vector3.ZERO
	return true


func _climb(delta: float) -> void:
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	var hit: Dictionary = _wall_probe(1.0, CAPSULE_RADIUS + 0.6)
	if hit.is_empty():
		# Sem parede no peito: chegou à borda? Sobe por cima.
		_climb_over_ledge()
		return
	_climb_normal = (hit["normal"] as Vector3)
	var angle: float = rad_to_deg(acos(clampf(_climb_normal.y, -1.0, 1.0)))
	if angle < tuning.climb_min_angle_deg - 8.0:
		_climb_over_ledge()
		return
	facing = -Vector3(_climb_normal.x, 0.0, _climb_normal.z).normalized()
	rotation.y = atan2(-facing.x, -facing.z)
	# Eixos do plano da parede.
	var right: Vector3 = Vector3.UP.cross(_climb_normal).normalized()
	var up: Vector3 = _climb_normal.cross(right).normalized()
	var raw: Vector2 = input_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	var fast: bool = sprinting and raw.length() > 0.1
	var speed: float = tuning.climb_sprint_speed if fast else tuning.climb_speed
	var cost: float = tuning.climb_stamina_per_s * (2.2 if fast else 1.0) * (1.0 if raw.length() > 0.1 else 0.25)
	if not stats.use_stamina(cost * delta):
		set_state(State.AIR)
		velocity = _climb_normal * 1.5
		return
	var move: Vector3 = (right * raw.x + up * raw.y) * speed
	if raining:
		move += Vector3.DOWN * tuning.rain_slip
	# Salto na parede: impulso para cima.
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		if stats.use_stamina(tuning.climb_jump_stamina):
			move += up * 7.0
	# Gruda na parede.
	var hit_pos: Vector3 = hit["position"]
	var desired_dist: float = CAPSULE_RADIUS + 0.05
	var to_wall: Vector3 = (hit_pos - (global_position + Vector3.UP)).project(_climb_normal)
	move += -_climb_normal * (to_wall.length() - desired_dist) * -8.0 if to_wall.dot(_climb_normal) > 0.0 else -_climb_normal * 2.0
	velocity = move
	move_and_slide()
	if just_pressed(&"dodge"):
		set_state(State.AIR)
		velocity = _climb_normal * 3.0
		return
	if is_on_floor() and raw.y < -0.1:
		set_state(State.GROUND)


func _climb_over_ledge() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var top_probe: Vector3 = global_position + facing * 0.9 + Vector3.UP * 2.6
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top_probe, top_probe + Vector3.DOWN * 3.0, 1)
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.6:
		global_position = (hit["position"] as Vector3) + Vector3.UP * 0.05
		velocity = Vector3.ZERO
		set_state(State.GROUND)
		if model != null:
			model.on_ledge_climb()
	else:
		set_state(State.AIR)


# --- Planador --------------------------------------------------------------------

func _glide(delta: float) -> void:
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0 or not stats.use_stamina(tuning.glide_stamina_per_s * delta):
		_jump_buffer = 0.0
		set_state(State.AIR)
		return
	var want_dir: Vector3 = move_input.normalized() if move_input.length() > 0.1 else facing
	facing = facing.slerp(want_dir, clampf(2.5 * delta, 0.0, 1.0)).normalized()
	rotation.y = atan2(-facing.x, -facing.z)
	var h: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(facing * tuning.glide_speed, 12.0 * delta)
	velocity = Vector3(h.x, move_toward(velocity.y, -tuning.glide_fall_speed, 30.0 * delta), h.z)
	move_and_slide()
	if is_on_floor():
		set_state(State.GROUND)
	elif _in_water_depth() > 0.2:
		set_state(State.SWIM)
	elif is_on_wall():
		_try_start_climb()


# --- Natação ------------------------------------------------------------------------

func _swim(delta: float) -> void:
	var depth: float = _in_water_depth()
	if depth < tuning.swim_depth - 0.25 and is_on_floor():
		set_state(State.GROUND)
		return
	if stats.exhausted:
		_drown(delta)
		return
	_drown_time = 0.0
	var fast: bool = sprinting and move_input.length() > 0.2
	var cost: float = (tuning.swim_sprint_stamina_per_s if fast else tuning.swim_stamina_per_s) * (1.0 if move_input.length() > 0.1 else 0.4)
	stats.use_stamina(cost * delta)
	_horizontal(delta, (tuning.swim_sprint_speed if fast else tuning.swim_speed) * move_input.length(), 0.6)
	# Flutua com o peito na superfície.
	var target_y: float = _water_level() - tuning.swim_depth
	velocity.y = clampf((target_y - global_position.y) * 4.0, -3.0, 3.0)
	move_and_slide()
	if is_on_wall() and move_input.length() > 0.3:
		_try_start_climb()


func _drown(delta: float) -> void:
	_drown_time += delta
	velocity = Vector3(0.0, -0.6, 0.0)
	move_and_slide()
	if _drown_time > 1.6:
		_drown_time = 0.0
		stats.damage(stats.max_health * 0.1)
		stats.set_stamina(stats.max_stamina * 0.5)
		stats.exhausted = false
		teleport(last_safe_position)
		respawned.emit()


# --- Esquiva --------------------------------------------------------------------------

func _start_dodge() -> void:
	if not stats.use_stamina(tuning.dodge_stamina):
		return
	_dodge_dir = move_input.normalized() if move_input.length() > 0.1 else -facing
	_dodge_time = tuning.dodge_time
	_iframes = tuning.dodge_iframes
	_dodge_started_ms = Time.get_ticks_msec()
	Audio.play(&"dodge", global_position)
	set_state(State.DODGE)
	if model != null:
		model.on_dodge(_dodge_dir.dot(facing) < -0.3)


func _dodge(delta: float) -> void:
	_dodge_time -= delta
	var speed: float = tuning.dodge_distance / tuning.dodge_time
	velocity = Vector3(_dodge_dir.x * speed, -2.0, _dodge_dir.z * speed)
	move_and_slide()
	if _dodge_time <= 0.0:
		set_state(State.GROUND if is_on_floor() else State.AIR)


func is_dodging() -> bool:
	return state == State.DODGE


func has_iframes() -> bool:
	return _iframes > 0.0


func grant_iframes(seconds: float) -> void:
	_iframes = maxf(_iframes, seconds)


func is_alive() -> bool:
	return state != State.DEAD


# --- Dano --------------------------------------------------------------------------

## Recebe um golpe. Retorna se causou dano.
func take_damage(info: DamageInfo) -> bool:
	if state == State.DEAD or god_mode:
		return false
	_enter_combat()
	if _iframes > 0.0:
		var since: float = (Time.get_ticks_msec() - _dodge_started_ms) / 1000.0
		if info.dodgeable and since <= tuning.perfect_dodge_window + tuning.dodge_iframes:
			_perfect_dodge()
		return false
	if barrier_hp > 0.0:
		var absorbed: float = minf(barrier_hp, info.amount)
		barrier_hp -= absorbed
		info.amount -= absorbed
		if _barrier_mesh != null:
			(_barrier_mesh.material_override as ShaderMaterial).set_shader_parameter(&"hit_flash", 1.0)
		Audio.play(&"barrier", global_position, -6.0)
		if info.amount <= 0.0:
			return false
	stats.damage(info.amount)
	Events.player_damaged.emit(info)
	Audio.play(&"player_hurt", global_position)
	if cam_rig != null:
		cam_rig.shake(clampf(info.amount / 30.0, 0.2, 0.8), 0.25)
	var vfx: Vfx = Vfx.get_for(self)
	if vfx != null:
		vfx.impact(global_position + Vector3.UP * 1.1, Color("d0443a"), 0.8, 16)
	if info.knockback > 0.0 and state == State.GROUND:
		velocity += info.direction * info.knockback
	if model != null and info.stagger >= 0.5:
		model.play_oneshot(&"hit", 0.3)
	if stats.health <= 0.0:
		_die()
	return true


func _perfect_dodge() -> void:
	_dodge_started_ms = -100000  # no máximo um por esquiva
	stats.set_mana(stats.mana + 15.0)
	HitStop.slow_motion(get_tree(), 450, 0.35)
	Audio.play(&"perfect_dodge", global_position)
	var vfx: Vfx = Vfx.get_for(self)
	if vfx != null:
		vfx.shockwave(global_position, 3.0, Color("e8b44c"), 0.4)
	Events.perfect_dodge.emit()


func _enter_combat() -> void:
	if not stats.in_combat:
		Events.combat_state_changed.emit(true)
	stats.in_combat = true
	_combat_timer = 6.0


## Inimigos chamam ao perceber o jogador (entra em combate: HUD, música).
func notify_combat() -> void:
	_enter_combat()


func _die() -> void:
	set_state(State.DEAD)
	_dead_time = 0.0
	if model != null:
		model.play_oneshot(&"death", 3.0)


func _respawn() -> void:
	stats.set_health(stats.max_health)
	stats.set_mana(stats.max_mana)
	stats.set_stamina(stats.max_stamina)
	stats.exhausted = false
	teleport(respawn_point)
	grant_iframes(2.0)
	respawned.emit()


# --- Égide e passos -------------------------------------------------------------------

func _build_barrier() -> void:
	_barrier_mesh = MeshInstance3D.new()
	_barrier_mesh.name = "Aegis"
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 1.15
	sm.height = 2.3
	sm.radial_segments = 32
	sm.rings = 16
	_barrier_mesh.mesh = sm
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = preload("res://shaders/barrier.gdshader")
	_barrier_mesh.material_override = mat
	_barrier_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_barrier_mesh.position.y = 1.0
	_barrier_mesh.visible = false
	add_child(_barrier_mesh)


func _tick_barrier(delta: float) -> void:
	if barrier_time > 0.0:
		barrier_time -= delta
		if barrier_time <= 0.0 or barrier_hp <= 0.0:
			barrier_time = 0.0
			barrier_hp = 0.0
	if _barrier_mesh == null:
		return
	_barrier_mesh.visible = barrier_hp > 0.0
	if _barrier_mesh.visible:
		var m: ShaderMaterial = _barrier_mesh.material_override as ShaderMaterial
		var flash: float = JsonUtil.num(m.get_shader_parameter(&"hit_flash"), 0.0)
		m.set_shader_parameter(&"hit_flash", maxf(flash - delta * 4.0, 0.0))
		m.set_shader_parameter(&"strength", clampf(barrier_time, 0.0, 1.0))


func _footsteps(delta: float) -> void:
	if state != State.GROUND or ground_speed < 1.0:
		_step_accum = 0.0
		return
	_step_accum += delta * ground_speed
	if _step_accum < 2.1:
		return
	_step_accum = 0.0
	var id: StringName = &"step_grass"
	var island: Node = get_tree().get_first_node_in_group(&"island_terrain")
	if island != null:
		var region: int = roundi(JsonUtil.num(island.call(&"region_at", global_position), 2.0))
		if region == IslandLayout.Region.PEAKS and global_position.y > 120.0:
			id = &"step_snow"
		elif region == IslandLayout.Region.CITADEL or region == IslandLayout.Region.BURNT:
			id = &"step_stone"
	Audio.play(id, global_position)



# --- Água e segurança ---------------------------------------------------------------

func _water_level() -> float:
	var best: float = -INF
	for w: Node in get_tree().get_nodes_in_group(&"water_body"):
		if w.has_method(&"surface_at"):
			var h: float = w.call(&"surface_at", global_position)
			best = maxf(best, h)
	var ocean: Node = get_tree().get_first_node_in_group(&"ocean")
	if ocean != null:
		best = maxf(best, JsonUtil.num(ocean.get(&"sea_level"), 0.0))
	return best


## Quanto os pés estão abaixo da superfície da água (negativo = fora d'água).
func _in_water_depth() -> float:
	var lvl: float = _water_level()
	if lvl == -INF:
		return -1.0
	return lvl - global_position.y


func _height_above_ground(max_check: float) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * max_check, 1)
	var hit: Dictionary = space.intersect_ray(q)
	return max_check + 1.0 if hit.is_empty() else global_position.y - (hit["position"] as Vector3).y


func _track_safe_position(delta: float) -> void:
	_safe_timer += delta
	if _safe_timer < 0.5:
		return
	_safe_timer = 0.0
	if state == State.GROUND and is_on_floor() and _in_water_depth() < 0.0:
		last_safe_position = global_position


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	set_state(State.AIR)
