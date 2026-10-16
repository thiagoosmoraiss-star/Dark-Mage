class_name StaminaWheel
extends Control
## Roda de stamina ao lado do personagem (roteiro 4.2): só aparece em uso,
## fica vermelha quando exausto. Desenhada com draw_arc (sem textura).

const GOLD: Color = Color("e8b44c")
const EXHAUSTED: Color = Color("d0443a")
const BACK: Color = Color(0.043, 0.035, 0.063, 0.55)

var player: Player
var _alpha: float = 0.0
var _shown_ratio: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(64, 64)


func _process(delta: float) -> void:
	if player == null:
		return
	var ratio: float = player.stats.stamina_ratio()
	_shown_ratio = lerpf(_shown_ratio, ratio, 1.0 - exp(-14.0 * delta))
	var want: float = 1.0 if ratio < 0.999 or player.stats.exhausted else 0.0
	_alpha = move_toward(_alpha, want, delta * (4.0 if want > 0.0 else 1.5))
	visible = _alpha > 0.01
	var cam: Camera3D = get_viewport().get_camera_3d()
	# Só aparece com a câmera do jogador (em capturas/cutscenes some).
	if cam == null or player.cam_rig == null or cam != player.cam_rig.camera:
		visible = false
		return
	if visible:
		var anchor: Vector3 = player.global_position + player.global_basis.x * 0.7 + Vector3.UP * 1.5
		if not cam.is_position_behind(anchor):
			var ui_scale: float = JsonUtil.num(Settings.get_value("accessibility", "ui_scale"), 1.0)
			scale = Vector2(ui_scale, ui_scale)
			position = cam.unproject_position(anchor) - size * 0.5 * ui_scale
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = 22.0
	var col: Color = EXHAUSTED if player != null and player.stats.exhausted else GOLD
	draw_arc(c, r, 0.0, TAU, 48, Color(BACK, BACK.a * _alpha), 7.0, true)
	if _shown_ratio > 0.001:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * _shown_ratio, 48, Color(col, _alpha), 5.0, true)
	if player != null and player.stats.exhausted:
		draw_arc(c, r + 5.0, 0.0, TAU, 48, Color(EXHAUSTED, 0.35 * _alpha), 1.5, true)
