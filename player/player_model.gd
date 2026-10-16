class_name PlayerModel
extends Node3D
## Visual do Mago Sombrio: modelo KayKit (CC0) recolorido para a paleta do jogo,
## cajado com cristal que emite luz, capa com movimento secundário, olhos violeta
## e AnimationTree (máquina de estados + BlendSpace1D de locomoção).

const MODEL_SCENE: String = "res://assets/models/characters/kaykit_mage/Mage.glb"

## Nome lógico -> nomes candidatos no arquivo (o primeiro que existir é usado).
const ANIMS: Dictionary = {
	&"idle": ["Idle", "Idle_A"],
	&"idle_alt": ["Unarmed_Idle", "Idle_B", "Idle"],
	&"walk": ["Walking_A", "Walking_B", "Walk"],
	&"run": ["Running_A", "Running_B", "Run"],
	&"sprint": ["Running_B", "Running_A"],
	&"jump_start": ["Jump_Start", "Jump"],
	&"fall": ["Jump_Idle", "Jump_Idle"],
	&"land": ["Jump_Land"],
	&"climb": ["Climb", "Lie_StandUp", "Interact"],
	&"glide": ["Jump_Idle"],
	&"swim": ["Unarmed_Idle", "Idle"],
	&"dodge": ["Dodge_Forward", "Roll"],
	&"dodge_back": ["Dodge_Backward", "Dodge_Forward"],
	&"cast_quick": ["Spellcast_Shoot", "Spellcast_Quick"],
	&"cast_charged": ["Spellcast_Long"],
	&"cast_area": ["Spellcast_Raise", "Spellcast_Summon"],
	&"attack": ["Spellcast_Shoot", "1H_Melee_Attack_Stab"],
	&"hit": ["Hit_A", "Hit_B"],
	&"death": ["Death_A", "Death_B"],
	&"interact": ["Interact", "PickUp"],
}

var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var skeleton: Skeleton3D
var staff_light: OmniLight3D
var cape: MeshInstance3D

var _resolved: Dictionary = {}
var _playback: AnimationNodeStateMachinePlayback
var _lean: float = 0.0
var _cape_swing: Vector2 = Vector2.ZERO
var _prev_velocity: Vector3 = Vector3.ZERO
var _oneshot_lock: float = 0.0
var _visual: Node3D


func _ready() -> void:
	var packed: PackedScene = load(MODEL_SCENE) as PackedScene
	if packed == null:
		push_error("PlayerModel: modelo não encontrado")
		return
	_visual = packed.instantiate() as Node3D
	_visual.name = "Mage"
	_visual.rotation.y = PI  # o modelo olha para +Z; o jogador anda para -Z
	add_child(_visual)
	anim_player = _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = _visual.find_child("*", true, false) as Skeleton3D
	for n: Node in _visual.find_children("*", "Skeleton3D", true, false):
		skeleton = n as Skeleton3D
		break
	MageLook.apply(_visual, skeleton)
	staff_light = MageLook.attach_staff(skeleton)
	cape = MageLook.attach_cape(skeleton)
	MageLook.attach_eyes(skeleton)
	CharacterLayers.apply(_visual)
	_resolve_animations()
	_build_tree()
	_align_staff_after_pose.call_deferred()


func _align_staff_after_pose() -> void:
	if staff_light == null:
		return
	for i: int in 3:
		await get_tree().process_frame
	if is_instance_valid(staff_light):
		MageLook.align_staff(staff_light.get_parent() as Node3D, -global_basis.z)


func _resolve_animations() -> void:
	if anim_player == null:
		return
	for key: StringName in ANIMS:
		for candidate: String in ANIMS[key]:
			if anim_player.has_animation(candidate):
				_resolved[key] = StringName(candidate)
				break
	for loop_key: StringName in [&"idle", &"idle_alt", &"walk", &"run", &"sprint", &"fall", &"glide", &"swim", &"climb"]:
		if _resolved.has(loop_key):
			var an: StringName = _resolved[loop_key]
			anim_player.get_animation(an).loop_mode = Animation.LOOP_LINEAR


func anim_name(key: StringName) -> StringName:
	return _resolved.get(key, &"")


func _build_tree() -> void:
	if anim_player == null:
		return
	var sm: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	var loco: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 9.0
	loco.blend_mode = AnimationNodeBlendSpace1D.BLEND_MODE_INTERPOLATED
	_add_point(loco, &"idle", 0.0)
	_add_point(loco, &"walk", 2.4)
	_add_point(loco, &"run", 5.6)
	_add_point(loco, &"sprint", 8.6)
	sm.add_node(&"locomotion", loco)
	for key: StringName in [&"jump_start", &"fall", &"land", &"climb", &"glide", &"swim", &"dodge", &"dodge_back",
			&"cast_quick", &"cast_charged", &"cast_area", &"attack", &"hit", &"death", &"interact"]:
		if _resolved.has(key):
			var a: AnimationNodeAnimation = AnimationNodeAnimation.new()
			a.animation = _resolved[key]
			sm.add_node(key, a)
	# Transições livres entre todos os estados, com crossfade curto.
	var names: Array[StringName] = [&"locomotion"]
	for key: StringName in _resolved:
		if sm.has_node(key):
			names.append(key)
	for a_name: StringName in names:
		for b_name: StringName in names:
			if a_name != b_name:
				var t: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
				t.xfade_time = 0.18
				t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
				sm.add_transition(a_name, b_name, t)
	if sm.has_node(&"jump_start") and sm.has_node(&"fall"):
		var auto: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
		auto.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		auto.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		auto.xfade_time = 0.1
		sm.remove_transition(&"jump_start", &"fall")
		sm.add_transition(&"jump_start", &"fall", auto)
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.tree_root = sm
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_visual.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	anim_tree.active = true
	_playback = anim_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
	_playback.start(&"locomotion")


func _add_point(bs: AnimationNodeBlendSpace1D, key: StringName, pos: float) -> void:
	if not _resolved.has(key):
		return
	var a: AnimationNodeAnimation = AnimationNodeAnimation.new()
	a.animation = _resolved[key]
	bs.add_blend_point(a, pos, -1, key)


func travel(key: StringName) -> void:
	if _playback == null or (not _resolved.has(key) and key != &"locomotion"):
		return
	if _playback.get_current_node() != key:
		_playback.travel(key)


## Toca uma animação única (feitiço, dano...) e bloqueia a troca por `lock` segundos.
func play_oneshot(key: StringName, lock: float = 0.4) -> void:
	if _playback == null or not _resolved.has(key):
		return
	_playback.start(key, true)
	_oneshot_lock = lock


func on_jump() -> void:
	play_oneshot(&"jump_start", 0.15)


func on_dodge(backwards: bool) -> void:
	play_oneshot(&"dodge_back" if backwards else &"dodge", 0.35)


func on_ledge_climb() -> void:
	play_oneshot(&"land", 0.2)


func update_pose(p: Player, delta: float) -> void:
	if anim_tree == null:
		return
	_oneshot_lock = maxf(_oneshot_lock - delta, 0.0)
	anim_tree.set(&"parameters/locomotion/blend_position", p.ground_speed)
	if _oneshot_lock <= 0.0:
		match p.state:
			Player.State.GROUND:
				var cur: StringName = _playback.get_current_node()
				if cur == &"fall" and _resolved.has(&"land"):
					play_oneshot(&"land", 0.12)
				else:
					travel(&"locomotion")
			Player.State.AIR:
				if _playback.get_current_node() != &"jump_start":
					travel(&"fall")
			Player.State.CLIMB:
				travel(&"climb")
			Player.State.GLIDE:
				travel(&"glide")
			Player.State.SWIM:
				travel(&"swim")
			Player.State.DEAD:
				travel(&"death")
	# Inclinação nas curvas (lean) proporcional à aceleração lateral.
	var v: Vector3 = p.velocity
	var accel: Vector3 = (v - _prev_velocity) / maxf(delta, 1e-4)
	_prev_velocity = v
	var right: Vector3 = p.global_basis.x
	var lateral: float = clampf(accel.dot(right) * 0.012, -0.22, 0.22) if p.state == Player.State.GROUND else 0.0
	if p.state == Player.State.GLIDE:
		lateral = clampf(p.move_input.dot(right) * 0.35, -0.35, 0.35)
	_lean = lerpf(_lean, lateral, 1.0 - exp(-8.0 * delta))
	_visual.rotation.z = -_lean
	_visual.rotation.x = -0.35 if p.state == Player.State.GLIDE else lerpf(_visual.rotation.x, 0.0, 1.0 - exp(-8.0 * delta))
	_visual.position.y = -0.55 if p.state == Player.State.SWIM else lerpf(_visual.position.y, 0.0, 1.0 - exp(-10.0 * delta))
	# Capa: balanço secundário com a velocidade (mola amortecida).
	if cape != null:
		var local_v: Vector3 = p.global_basis.inverse() * v
		var target: Vector2 = Vector2(clampf(-local_v.z * 0.07, -0.2, 0.9), clampf(local_v.x * 0.05, -0.4, 0.4))
		if p.state == Player.State.AIR or p.state == Player.State.GLIDE:
			target.x += clampf(-v.y * 0.04, -0.3, 0.6)
		_cape_swing = _cape_swing.lerp(target, 1.0 - exp(-6.0 * delta))
		cape.rotation = Vector3(_cape_swing.x, 0.0, _cape_swing.y)
