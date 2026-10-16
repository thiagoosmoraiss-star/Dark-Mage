class_name MapScreen
extends CanvasLayer
## Tela de mapa (tecla M): pergaminho com névoa de guerra, posição e direção do
## jogador e marcadores. Pausa o jogo enquanto aberta.

const L = preload("res://world/island/island_layout.gd")
const MAP_TEXTURE: String = "res://world/island/data/preview.png"
const GOLD: Color = Color("e8b44c")

var fog: FogOfWar
var player: Node3D
## Marcadores: [{pos: Vector3, kind: String, label: String}]
var markers: Array[Dictionary] = []

var _root: Control
var _map: TextureRect
var _fog_tex: ImageTexture
var _overlay: Control


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.043, 0.035, 0.063, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_map = TextureRect.new()
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.offset_left = 80
	_map.offset_right = -80
	_map.offset_top = 60
	_map.offset_bottom = -60
	if FileAccess.file_exists(MAP_TEXTURE):
		_map.texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(MAP_TEXTURE)))
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = preload("res://shaders/ui_map.gdshader")
	var nt: NoiseTexture2D = NoiseTexture2D.new()
	nt.seamless = true
	nt.noise = FastNoiseLite.new()
	mat.set_shader_parameter(&"paper_noise", nt)
	_map.material = mat
	_root.add_child(_map)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_root.add_child(_overlay)


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	_root.visible = not _root.visible
	get_tree().paused = _root.visible
	if _root.visible:
		_refresh_fog()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"map") or (_root.visible and event.is_action_pressed(&"pause")):
		toggle()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _root.visible:
		_overlay.queue_redraw()


func _refresh_fog() -> void:
	if fog == null:
		return
	if _fog_tex == null:
		_fog_tex = ImageTexture.create_from_image(fog.image())
	else:
		_fog_tex.update(fog.image())
	(_map.material as ShaderMaterial).set_shader_parameter(&"fog_mask", _fog_tex)


## Converte posição do mundo para a tela do mapa.
func world_to_map(pos: Vector3) -> Vector2:
	var rect: Rect2 = _map_rect()
	var u: float = (pos.x + L.HALF) / L.WORLD_SIZE
	var v: float = (pos.z + L.HALF) / L.WORLD_SIZE
	return rect.position + Vector2(u, v) * rect.size


func _map_rect() -> Rect2:
	var r: Rect2 = _map.get_global_rect()
	var s: float = minf(r.size.x, r.size.y)
	return Rect2(r.position + (r.size - Vector2(s, s)) * 0.5, Vector2(s, s))


func _draw_overlay() -> void:
	for m: Dictionary in markers:
		var mp: Vector3 = m.get("pos", Vector3.ZERO)
		if fog != null and not fog.is_revealed(mp) and not m.get("always", false):
			continue
		var sp: Vector2 = world_to_map(mp)
		_overlay.draw_circle(sp, 6.0, Color(0.1, 0.07, 0.12))
		_overlay.draw_circle(sp, 4.0, GOLD)
	if player != null:
		var p: Vector2 = world_to_map(player.global_position)
		var f: Vector3 = -player.global_basis.z
		var dir: Vector2 = Vector2(f.x, f.z).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var pts: PackedVector2Array = [p + dir * 18.0, p - dir * 10.0 + side * 11.0, p - dir * 4.0, p - dir * 10.0 - side * 11.0]
		_overlay.draw_colored_polygon(pts, Color("b67cff"))
		_overlay.draw_polyline(pts + PackedVector2Array([pts[0]]), GOLD, 1.5)
