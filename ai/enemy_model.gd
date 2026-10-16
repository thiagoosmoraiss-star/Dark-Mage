class_name EnemyModel
extends Node3D
## Visual de um inimigo KayKit: recolor sombrio, olhos emissivos, arma no osso
## da mão, animações com crossfade e flash branco ao receber dano.

var anim: AnimationPlayer
var skeleton: Skeleton3D
var _flash: StandardMaterial3D
var _flash_t: float = 0.0
var _eyes: Array[MeshInstance3D] = []
var _eye_mat: StandardMaterial3D
var _current: StringName = &""
var _visual: Node3D


func setup(data: EnemyData) -> void:
	var packed: PackedScene = load(data.model_path) as PackedScene
	if packed == null:
		push_error("EnemyModel: modelo não encontrado %s" % data.model_path)
		return
	_visual = packed.instantiate() as Node3D
	_visual.rotation.y = PI
	_visual.scale = Vector3.ONE * data.model_scale
	add_child(_visual)
	anim = _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for n: Node in _visual.find_children("*", "Skeleton3D", true, false):
		skeleton = n as Skeleton3D
		break
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1, 1, 1, 0)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = data.eye_color
	_eye_mat.emission_enabled = true
	_eye_mat.emission = data.eye_color
	_eye_mat.emission_energy_multiplier = 3.0
	for node: Node in _visual.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		mi.material_overlay = _flash
		if mi.name.ends_with("Eyes"):
			mi.material_override = _eye_mat
			_eyes.append(mi)
		else:
			_tint(mi, data.tint)
	if data.weapon_path != "" and skeleton != null:
		var bone: int = skeleton.find_bone(data.weapon_bone)
		var wpacked: PackedScene = load(data.weapon_path) as PackedScene
		if bone >= 0 and wpacked != null:
			var att: BoneAttachment3D = BoneAttachment3D.new()
			att.bone_idx = bone
			skeleton.add_child(att)
			att.add_child(wpacked.instantiate())
	for a: StringName in [data.anim_idle, data.anim_walk, data.anim_run, &"Idle_Combat", &"Walking_Backwards",
			&"Running_Strafe_Left", &"Running_Strafe_Right"]:
		if anim != null and anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	CharacterLayers.apply(_visual)
	play(data.anim_idle)


## Materiais tingidos compartilhados entre inimigos do mesmo tipo (cache).
static var _tinted: Dictionary[String, Material] = {}


static func _tint(mi: MeshInstance3D, tint: Color) -> void:
	if mi.mesh == null:
		return
	for s: int in mi.mesh.get_surface_count():
		var src: BaseMaterial3D = mi.mesh.surface_get_material(s) as BaseMaterial3D
		if src == null:
			continue
		var key: String = "%d_%s" % [src.get_instance_id(), tint.to_html()]
		if not _tinted.has(key):
			var m: StandardMaterial3D = src.duplicate() as StandardMaterial3D
			if m == null:
				continue
			m.albedo_color = tint
			m.rim_enabled = true
			m.rim = 0.25
			_tinted[key] = m
		mi.set_surface_override_material(s, _tinted[key])


func play(name_: StringName, blend: float = 0.15, speed: float = 1.0) -> void:
	if anim == null or not anim.has_animation(name_):
		return
	if _current == name_ and anim.is_playing():
		anim.speed_scale = speed
		return
	_current = name_
	anim.play(name_, blend, speed)


func play_once(name_: StringName, blend: float = 0.1, speed: float = 1.0) -> void:
	if anim == null or not anim.has_animation(name_):
		return
	_current = name_
	anim.play(name_, blend, speed)
	anim.seek(0.0, true)


func flash() -> void:
	_flash_t = 0.12


## Brilho dos olhos (telegrafia): 1 = normal, >1 = preparando ataque.
func set_eye_intensity(k: float) -> void:
	_eye_mat.emission_energy_multiplier = 3.0 * k


func set_frozen(on: bool) -> void:
	if anim != null:
		anim.speed_scale = 0.0 if on else 1.0
	_flash.albedo_color = Color(0.6, 0.85, 1.0, 0.45) if on else Color(1, 1, 1, 0)


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.albedo_color = Color(1, 1, 1, clampf(_flash_t / 0.12, 0.0, 1.0) * 0.85)
