class_name ItemSlot
extends Button
## Casa da grade do inventário (ou do equipamento). Desenha ícone tingido, raridade
## e quantidade; arrastar e soltar com o mouse; com teclado/gamepad, "mover" pega o
## item e confirmar em outra casa solta.

signal dropped_on(from_index: int, to_index: int)

const RARITY_COLORS: Array[Color] = [Color(0.7, 0.66, 0.62, 0.5), Color("6b9bd6"), Color("e8b44c")]

var index: int = -1
var item_id: String = ""
var count: int = 0
var equip_slot: String = ""
var picked: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(72, 72)
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func() -> void: grab_focus())
	focus_entered.connect(func() -> void: Audio.play(&"ui_select"))


func set_item(id: String, n: int) -> void:
	item_id = id
	count = n
	tooltip_text = ItemDb.display_name(id) if id != "" else ""
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(r.grow(-3), Color(0.06, 0.05, 0.08, 0.85))
	if item_id != "":
		var rar: int = JsonUtil.get_i(ItemDb.get_item(item_id), "rarity")
		draw_rect(r.grow(-3), RARITY_COLORS[clampi(rar, 0, 2)], false, 2.0)
		var tex: Texture2D = MenuKit.icon(ItemDb.icon_name(item_id))
		if tex != null:
			draw_texture_rect(tex, r.grow(-12), false, ItemDb.tint(item_id))
		if count > 1:
			draw_string(UiStyle.body_font(), Vector2(size.x - 22, size.y - 9), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiStyle.TEXT)
	elif equip_slot != "":
		var t2: Texture2D = MenuKit.icon(equip_slot)
		if t2 != null:
			draw_texture_rect(t2, r.grow(-16), false, Color(1, 1, 1, 0.12))
	if has_focus():
		draw_rect(r.grow(-1), UiStyle.GOLD, false, 2.0)
	if picked:
		draw_rect(r.grow(-6), Color(UiStyle.VIOLET, 0.35))


func _get_drag_data(_at: Vector2) -> Variant:
	if item_id == "" or index < 0:
		return null
	var prev: TextureRect = TextureRect.new()
	prev.texture = MenuKit.icon(ItemDb.icon_name(item_id))
	prev.modulate = ItemDb.tint(item_id)
	prev.custom_minimum_size = Vector2(56, 56)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	set_drag_preview(prev)
	return {"from": index}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return index >= 0 and data is Dictionary and (data as Dictionary).has("from")


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped_on.emit(JsonUtil.get_i(data as Dictionary, "from"), index)
