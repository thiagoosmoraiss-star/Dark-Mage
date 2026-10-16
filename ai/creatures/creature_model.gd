class_name CreatureModel
extends EnemyModel
## Base dos visuais procedurais (morcego, golem, serpente): mesma interface do
## EnemyModel, mas a animação é feita por código num "estado" lógico.

var anim_state: StringName = &"idle"
var anim_time: float = 0.0
var eye_mats: Array[StandardMaterial3D] = []
var flash_mats: Array[Material] = []
var _flash_t2: float = 0.0
var _frozen: bool = false
var _eye_k: float = 1.0


func setup(data: EnemyData) -> void:
	build(data)
	CharacterLayers.apply(self)


## Subclasses constroem a malha aqui.
func build(_data: EnemyData) -> void:
	pass


func play(name_: StringName, _blend: float = 0.15, _speed: float = 1.0) -> void:
	if anim_state != name_:
		anim_state = name_
		anim_time = 0.0


func play_once(name_: StringName, blend: float = 0.1, speed: float = 1.0) -> void:
	play(name_, blend, speed)
	anim_time = 0.0


func flash() -> void:
	_flash_t2 = 0.12


func set_eye_intensity(k: float) -> void:
	_eye_k = k
	for m: StandardMaterial3D in eye_mats:
		m.emission_energy_multiplier = 3.0 * k


func set_frozen(on: bool) -> void:
	_frozen = on


func make_eye(color: Color, size: float) -> MeshInstance3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _dot_texture()
	eye_mats.append(m)
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static var _dot: GradientTexture2D


static func _dot_texture() -> GradientTexture2D:
	if _dot == null:
		_dot = GradientTexture2D.new()
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot.gradient = g
	return _dot


func _process(delta: float) -> void:
	if not _frozen:
		anim_time += delta
	_flash_t2 = maxf(_flash_t2 - delta, 0.0)
	var f: float = _flash_t2 / 0.12
	for m: Material in flash_mats:
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter(&"flash", f)
		elif m is StandardMaterial3D:
			(m as StandardMaterial3D).emission_energy_multiplier = f * 2.0
	animate(delta if not _frozen else 0.0)


## Subclasses animam aqui conforme anim_state/anim_time.
func animate(_delta: float) -> void:
	pass
