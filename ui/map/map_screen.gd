class_name MapScreen
extends CanvasLayer
## Tela de mapa (M / D-pad ↑): pergaminho com névoa de guerra, ícones dos locais
## descobertos (com estado: farol aceso, baú aberto, santuário concluído...),
## posição do jogador, marcadores próprios e viagem rápida pelas fogueiras.
## Cursor pelo mouse ou pelo analógico esquerdo; A/clique viaja; X/Y marca.

const L = preload("res://world/island/island_layout.gd")
const MAP_TEXTURE: String = "res://world/island/data/preview.png"
const GOLD: Color = Color("e8b44c")
const CURSOR_SPEED: float = 620.0
const PICK_RADIUS: float = 20.0
const MAX_MARKERS: int = 12

## kind → [cor, forma]
const ICONS: Dictionary = {
	&"beacon": [Color("e8b44c"), "triangle"], &"bonfire": [Color("ff8a3c"), "flame"],
	&"chest": [Color("c9a26b"), "square"], &"shrine": [Color("b67cff"), "diamond"],
	&"lair": [Color("e05a6b"), "skull"], &"viewpoint": [Color("9be0d0"), "eye"],
	&"story": [Color("d8cfc0"), "dot"], &"citadel": [Color("6b2fd6"), "star"],
	&"merchant": [Color("ffd27a"), "coin"],
}

var fog: FogOfWar
var player: Node3D
var world: IslandWorld

var _root: Control
var _map: TextureRect
var _fog_tex: ImageTexture
var _overlay: Control
var _info: Label
var _cursor: Vector2 = Vector2.ZERO
var _hover: Dictionary = {}
var _pois: Array[Dictionary] = []


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
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
	_map.offset_right = -420
	_map.offset_top = 60
	_map.offset_bottom = -60
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# Painel lateral: título, legenda e informação do local sob o cursor.
	var side: PanelContainer = PanelContainer.new()
	side.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -390
	side.offset_right = -40
	side.offset_top = 60
	side.offset_bottom = -60
	_root.add_child(side)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	side.add_child(v)
	v.add_child(UiStyle.title_label(tr("MAP_TITLE"), 30))
	_info = UiStyle.body_label("", 18)
	_info.custom_minimum_size = Vector2(320, 120)
	v.add_child(_info)
	v.add_child(MenuKit.separator())
	for kind: StringName in [&"bonfire", &"beacon", &"shrine", &"lair", &"chest", &"viewpoint", &"story", &"merchant"]:
		var row: HBoxContainer = HBoxContainer.new()
		var sw: Control = Control.new()
		sw.custom_minimum_size = Vector2(26, 24)
		var k: StringName = kind
		sw.draw.connect(func() -> void: _draw_icon(sw, Vector2(13, 12), k, true, 1.0))
		row.add_child(sw)
		var l: Label = Label.new()
		l.text = tr("MAP_KIND_" + String(kind).to_upper())
		l.add_theme_font_size_override(&"font_size", 17)
		row.add_child(l)
		v.add_child(row)
	v.add_child(MenuKit.separator())
	var help: Label = UiStyle.body_label(tr("MAP_HELP"), 16)
	help.add_theme_color_override(&"font_color", UiStyle.TEXT_DIM)
	v.add_child(help)


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	_root.visible = not _root.visible
	get_tree().paused = _root.visible
	if _root.visible:
		_refresh_fog()
		_collect_pois()
		if player != null:
			_cursor = world_to_map(player.global_position)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Audio.play(&"ui_open")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Audio.play(&"ui_close")


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		var ui: GameUi = get_tree().get_first_node_in_group(&"game_ui") as GameUi
		var panels: WorldPanels = get_tree().get_first_node_in_group(&"world_panels") as WorldPanels
		if event.is_action_pressed(&"map") and (ui == null or not ui.is_open()) and (panels == null or not panels.is_open()):
			toggle()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"map") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		toggle()
	elif event is InputEventMouseMotion:
		_cursor = (event as InputEventMouseMotion).position
		return
	elif event.is_action_pressed(&"ui_accept") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		_activate()
	elif event.is_action_pressed(&"ui_move_item") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT):
		toggle_marker_at(_cursor)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _root.visible:
		return
	var stick: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if stick.length_squared() > 0.0:
		_cursor += stick * CURSOR_SPEED * delta
		var r: Rect2 = _map_rect()
		_cursor = _cursor.clamp(r.position, r.end)
	_hover = _pick(_cursor)
	_info.text = _describe(_hover)
	_overlay.queue_redraw()


func _refresh_fog() -> void:
	if fog == null:
		return
	if _fog_tex == null:
		_fog_tex = ImageTexture.create_from_image(fog.image())
	else:
		_fog_tex.update(fog.image())
	(_map.material as ShaderMaterial).set_shader_parameter(&"fog_mask", _fog_tex)


## Locais visíveis: na área revelada ou com flag (visitados).
func _collect_pois() -> void:
	_pois.clear()
	for poi: Dictionary in WorldPois.all():
		var kind: StringName = poi["kind"]
		if not ICONS.has(kind):
			continue
		var p2: Vector2 = WorldPois.pos2(poi)
		var pos: Vector3 = Vector3(p2.x, 0, p2.y)
		var id: String = String(poi["id"] as StringName)
		var done: bool = _is_done(kind, id)
		if kind == &"citadel" or done or (fog != null and fog.is_revealed(pos)):
			_pois.append({"id": id, "kind": kind, "pos": pos, "done": done, "region": poi["region"]})
	if world != null and world.merchant != null and fog != null and fog.is_revealed(world.merchant.global_position):
		_pois.append({"id": "merchant", "kind": &"merchant", "pos": world.merchant.global_position, "done": false, "region": &"valley"})


static func _is_done(kind: StringName, id: String) -> bool:
	match kind:
		&"bonfire":
			return GameState.discovered_bonfires.has(id)
		&"shrine":
			return GameState.has_flag("shrine_done:" + id)
		&"lair":
			var poi: Dictionary = WorldPois.get_poi(StringName(id))
			return GameState.has_flag("guardian:" + String(poi.get("region", &"") as StringName))
		&"citadel":
			return GameState.has_flag("final:fear")
	return GameState.has_flag("%s:%s" % [kind, id])


func _pick(at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = PICK_RADIUS
	for p: Dictionary in _pois:
		var d: float = world_to_map(p["pos"] as Vector3).distance_to(at)
		if d < best_d:
			best_d = d
			best = p
	return best


func _describe(p: Dictionary) -> String:
	if p.is_empty():
		return tr("MAP_HOVER_NONE")
	var kind: StringName = p["kind"]
	var name_text: String = Bonfire.display_name(str(p["id"])) if kind == &"bonfire" else tr("MAP_KIND_" + String(kind).to_upper())
	var region: String = tr("REGION_" + String(p["region"] as StringName).to_upper())
	var state: String = tr("MAP_STATE_DONE_" + String(kind).to_upper()) if p["done"] else tr("MAP_STATE_OPEN")
	var extra: String = ""
	if kind == &"bonfire" and p["done"]:
		extra = "\n\n" + (tr("MAP_TRAVEL_HINT") if can_travel() else tr("MAP_TRAVEL_BLOCKED"))
	return "%s\n%s\n%s%s" % [name_text, region, state, extra]


func can_travel() -> bool:
	if world == null or world.player == null:
		return false
	if world.player.stats.in_combat or world.player.state == Player.State.DEAD:
		return false
	return world.interiors == null or not world.interiors.is_inside()


func _activate() -> void:
	if _hover.is_empty() or _hover["kind"] != &"bonfire" or not _hover["done"]:
		Audio.play(&"ui_error")
		return
	if not can_travel():
		Audio.play(&"ui_error")
		return
	var id: String = _hover["id"]
	toggle()
	world._on_travel(id)
	Audio.play(&"ui_confirm")


## Coloca um marcador no ponto do mapa, ou remove o marcador que estiver ali.
func toggle_marker_at(screen_pos: Vector2) -> void:
	if world == null:
		return
	for i: int in world.map_markers.size():
		var m: Vector2 = world.map_markers[i]
		if world_to_map(Vector3(m.x, 0, m.y)).distance_to(screen_pos) < PICK_RADIUS:
			world.map_markers.remove_at(i)
			Audio.play(&"ui_back")
			return
	if world.map_markers.size() >= MAX_MARKERS or not _map_rect().has_point(screen_pos):
		Audio.play(&"ui_error")
		return
	var w: Vector3 = map_to_world(screen_pos)
	world.map_markers.append(Vector2(w.x, w.z))
	Audio.play(&"ui_confirm")


## Converte posição do mundo para a tela do mapa.
func world_to_map(pos: Vector3) -> Vector2:
	var rect: Rect2 = _map_rect()
	var u: float = (pos.x + L.HALF) / L.WORLD_SIZE
	var v: float = (pos.z + L.HALF) / L.WORLD_SIZE
	return rect.position + Vector2(u, v) * rect.size


func map_to_world(p: Vector2) -> Vector3:
	var rect: Rect2 = _map_rect()
	var uv: Vector2 = (p - rect.position) / rect.size
	return Vector3(uv.x * L.WORLD_SIZE - L.HALF, 0.0, uv.y * L.WORLD_SIZE - L.HALF)


func _map_rect() -> Rect2:
	var r: Rect2 = _map.get_global_rect()
	var s: float = minf(r.size.x, r.size.y)
	return Rect2(r.position + (r.size - Vector2(s, s)) * 0.5, Vector2(s, s))


func _draw_overlay() -> void:
	for p: Dictionary in _pois:
		var sp: Vector2 = world_to_map(p["pos"] as Vector3)
		_draw_icon(_overlay, sp, p["kind"] as StringName, p["done"] as bool, 1.35 if p == _hover else 1.0)
	if world != null:
		var tex: Texture2D = MenuKit.icon("marker")
		for m: Vector2 in world.map_markers:
			var mp: Vector2 = world_to_map(Vector3(m.x, 0, m.y))
			if tex != null:
				_overlay.draw_texture_rect(tex, Rect2(mp - Vector2(12, 26), Vector2(24, 26)), false, UiStyle.VIOLET)
	if player != null:
		var p: Vector2 = world_to_map(player.global_position)
		var f: Vector3 = -player.global_basis.z
		var dir: Vector2 = Vector2(f.x, f.z).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var pts: PackedVector2Array = [p + dir * 18.0, p - dir * 10.0 + side * 11.0, p - dir * 4.0, p - dir * 10.0 - side * 11.0]
		_overlay.draw_colored_polygon(pts, Color("b67cff"))
		_overlay.draw_polyline(pts + PackedVector2Array([pts[0]]), GOLD, 1.5)
	# Cursor.
	_overlay.draw_arc(_cursor, 14.0, 0.0, TAU, 24, GOLD, 2.0)
	_overlay.draw_line(_cursor - Vector2(20, 0), _cursor - Vector2(8, 0), GOLD, 2.0)
	_overlay.draw_line(_cursor + Vector2(8, 0), _cursor + Vector2(20, 0), GOLD, 2.0)
	_overlay.draw_line(_cursor - Vector2(0, 20), _cursor - Vector2(0, 8), GOLD, 2.0)
	_overlay.draw_line(_cursor + Vector2(0, 8), _cursor + Vector2(0, 20), GOLD, 2.0)


## Ícone desenhado por forma (legível em daltonismo) e cor; feito = cheio e brilhante.
func _draw_icon(c: CanvasItem, at: Vector2, kind: StringName, done: bool, k: float) -> void:
	var def: Array = ICONS.get(kind, [GOLD, "dot"])
	var col: Color = def[0]
	var fill: Color = col if done else Color(col, 0.35)
	var r: float = 7.0 * k
	var ink: Color = Color(0.08, 0.06, 0.1)
	match str(def[1]):
		"triangle":
			var t: PackedVector2Array = [at + Vector2(0, -r * 1.3), at + Vector2(r * 1.1, r * 0.9), at + Vector2(-r * 1.1, r * 0.9)]
			c.draw_colored_polygon(t, fill)
			c.draw_polyline(t + PackedVector2Array([t[0]]), ink, 1.5)
		"flame":
			c.draw_circle(at + Vector2(0, r * 0.3), r * 0.9, fill)
			c.draw_colored_polygon([at + Vector2(-r * 0.75, 0), at + Vector2(0, -r * 1.5), at + Vector2(r * 0.75, 0)], fill)
			c.draw_arc(at + Vector2(0, r * 0.3), r * 0.9, 0.0, TAU, 16, ink, 1.2)
		"square":
			c.draw_rect(Rect2(at - Vector2(r, r * 0.75), Vector2(r * 2, r * 1.5)), fill)
			c.draw_rect(Rect2(at - Vector2(r, r * 0.75), Vector2(r * 2, r * 1.5)), ink, false, 1.2)
		"diamond":
			var d: PackedVector2Array = [at + Vector2(0, -r * 1.2), at + Vector2(r, 0), at + Vector2(0, r * 1.2), at + Vector2(-r, 0)]
			c.draw_colored_polygon(d, fill)
			c.draw_polyline(d + PackedVector2Array([d[0]]), ink, 1.5)
		"skull":
			c.draw_circle(at, r * 1.1, fill)
			c.draw_circle(at + Vector2(-r * 0.4, -r * 0.1), r * 0.25, ink)
			c.draw_circle(at + Vector2(r * 0.4, -r * 0.1), r * 0.25, ink)
		"eye":
			c.draw_arc(at, r, 0.0, TAU, 18, fill, 2.5)
			c.draw_circle(at, r * 0.4, fill)
		"star":
			var pts: PackedVector2Array = []
			for i: int in 10:
				var a: float = -PI * 0.5 + TAU * i / 10.0
				pts.append(at + Vector2(cos(a), sin(a)) * (r * 1.8 if i % 2 == 0 else r * 0.8))
			c.draw_colored_polygon(pts, fill)
		"coin":
			c.draw_circle(at, r, fill)
			c.draw_arc(at, r * 0.6, 0.0, TAU, 16, ink, 1.5)
		_:
			c.draw_circle(at, r * 0.7, fill)
			c.draw_arc(at, r * 0.7, 0.0, TAU, 12, ink, 1.2)
	if done and kind != &"bonfire" and kind != &"citadel" and kind != &"merchant":
		c.draw_line(at + Vector2(r * 0.6, r * 0.9), at + Vector2(r * 1.0, r * 1.3), Color("8fd18a"), 2.0)
		c.draw_line(at + Vector2(r * 1.0, r * 1.3), at + Vector2(r * 1.8, r * 0.4), Color("8fd18a"), 2.0)
