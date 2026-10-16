class_name CameraRig
extends Node3D
## Câmera em terceira pessoa: segue o alvo com suavização, gira com mouse/gamepad,
## colide com o cenário (SpringArm3D), tem zoom e ombro ao mirar.

@export var target_path: NodePath
@export var height: float = 1.55
@export var distance: float = 4.6
@export var min_distance: float = 2.2
@export var max_distance: float = 9.0
@export var aim_distance: float = 2.1
@export var aim_shoulder: float = 0.75
@export var pitch_min_deg: float = -70.0
@export var pitch_max_deg: float = 55.0
@export var follow_sharpness: float = 14.0
@export var gamepad_speed_deg: float = 150.0

var yaw: float = 0.0
var pitch: float = deg_to_rad(-12.0)
var aiming: bool = false
var camera: Camera3D
var spring: SpringArm3D

var _target: Node3D
var _zoom: float
var _shoulder: float = 0.0
var _shake: float = 0.0
var _shake_time: float = 0.0
var _arm_len: float


func _ready() -> void:
	top_level = true
	# Move-se em _process (suavização própria): fora da interpolação de física.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_zoom = distance
	_arm_len = distance
	spring = SpringArm3D.new()
	spring.name = "SpringArm"
	spring.spring_length = distance
	spring.margin = 0.25
	spring.collision_mask = 1
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.25
	spring.shape = shape
	add_child(spring)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.far = 3000.0
	camera.near = 0.08
	camera.fov = JsonUtil.num(Settings.get_value("graphics", "fov"), 75.0)
	spring.add_child(camera)
	camera.current = true
	_target = get_node_or_null(target_path) as Node3D
	if _target != null:
		global_position = _target.global_position + Vector3.UP * height
		yaw = _target.global_rotation.y
	Events.settings_changed.connect(_on_settings_changed)


func set_target(t: Node3D) -> void:
	_target = t
	global_position = t.global_position + Vector3.UP * height


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		var sens: float = JsonUtil.num(Settings.get_value("controls", "mouse_sensitivity"), 0.25) * 0.01
		var inv: float = -1.0 if Settings.get_value("controls", "invert_y") == true else 1.0
		yaw -= motion.relative.x * sens
		pitch -= motion.relative.y * sens * inv
		pitch = clampf(pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(min_distance, _zoom - 0.5)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(max_distance, _zoom + 0.5)


func _process(delta: float) -> void:
	# Analógico direito.
	var look: Vector2 = Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	if look.length_squared() > 0.0:
		var gs: float = deg_to_rad(gamepad_speed_deg) * JsonUtil.num(Settings.get_value("controls", "gamepad_sensitivity"), 1.0)
		var inv: float = -1.0 if Settings.get_value("controls", "invert_y") == true else 1.0
		yaw -= look.x * gs * delta
		pitch = clampf(pitch - look.y * gs * delta * inv, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	if _target != null:
		var goal: Vector3 = _target.global_position + Vector3.UP * height
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_sharpness * delta))
	rotation = Vector3(pitch, yaw, 0.0)
	var want_len: float = aim_distance if aiming else _zoom
	_arm_len = lerpf(_arm_len, want_len, 1.0 - exp(-10.0 * delta))
	spring.spring_length = _arm_len
	_shoulder = lerpf(_shoulder, aim_shoulder if aiming else 0.0, 1.0 - exp(-10.0 * delta))
	spring.position = Vector3(_shoulder, 0.0, 0.0)
	_apply_shake(delta)


## Tremor proporcional (0..1), reduzido pela opção de acessibilidade.
func shake(amount: float, duration: float = 0.25) -> void:
	var scale_opt: float = JsonUtil.num(Settings.get_value("accessibility", "camera_shake"), 1.0)
	_shake = maxf(_shake, amount * scale_opt)
	_shake_time = maxf(_shake_time, duration)


func _apply_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	_shake_time -= delta
	var k: float = _shake * clampf(_shake_time / 0.25, 0.0, 1.0) * 0.15
	camera.h_offset = randf_range(-k, k)
	camera.v_offset = randf_range(-k, k)
	if _shake_time <= 0.0:
		_shake = 0.0


## Direção "para frente" no plano horizontal, para mover o jogador relativo à câmera.
func flat_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func _on_settings_changed(section: String) -> void:
	if section == "graphics":
		camera.fov = JsonUtil.num(Settings.get_value("graphics", "fov"), 75.0)
