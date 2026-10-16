class_name ShopMenu
extends TabbedScreen
## Loja do Mercador Misterioso: comprar (estoque por progresso) e vender itens da
## bolsa e materiais de região, em fragmentos de alma.

var player: Player


func _init() -> void:
	title = tr("SHOP_TITLE")
	hint = tr("UI_HINT_SHOP")
	tabs = [[tr("SHOP_BUY"), _buy_tab], [tr("SHOP_SELL"), _sell_tab]]


func _header(v: VBoxContainer) -> void:
	var l: Label = Label.new()
	l.text = tr("SHOP_SOULS") % GameState.souls
	l.add_theme_color_override(&"font_color", UiStyle.GOLD)
	v.add_child(l)
	v.add_child(UiStyle.body_label(tr("SHOP_GREETING"), 18))


func _list() -> Array:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 6)
	sc.add_child(v)
	return [sc, v]


func _row(id: String, label: String, enabled: bool, cb: Callable) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 14)
	var t: TextureRect = TextureRect.new()
	t.texture = MenuKit.icon(ItemDb.icon_name(id))
	t.modulate = ItemDb.tint(id)
	t.custom_minimum_size = Vector2(40, 40)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h.add_child(t)
	var b: Button = MenuKit.button(label, cb, 44)
	b.name = "Item_" + id
	b.custom_minimum_size = Vector2(420, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	h.add_child(b)
	var d: Label = UiStyle.body_label(ItemDb.description(id) if ItemDb.exists(id) else "", 16)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.add_theme_color_override(&"font_color", UiStyle.TEXT_DIM)
	h.add_child(d)
	return h


func _buy_tab() -> Control:
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override(&"separation", 10)
	_header(outer)
	var lv: Array = _list()
	outer.add_child(lv[0] as Control)
	var v: VBoxContainer = lv[1]
	for id: String in Merchant.stock():
		var owned: bool = ItemDb.is_equipment(id) and Inventory.owns(id)
		var p: int = ItemDb.price(id)
		var label: String = "%s — %d" % [ItemDb.display_name(id), p] + ("  (%s)" % tr("SHOP_OWNED") if owned else "")
		var item: String = id
		v.add_child(_row(id, label, GameState.souls >= p and not owned, func() -> void:
			if Merchant.buy(item):
				Audio.play(&"coins")
			else:
				Audio.play(&"ui_error")
			refresh()))
	_ensure_focus_target(v)
	return outer


func _sell_tab() -> Control:
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override(&"separation", 10)
	_header(outer)
	var lv: Array = _list()
	outer.add_child(lv[0] as Control)
	var v: VBoxContainer = lv[1]
	for i: int in Inventory.SIZE:
		var id: String = Inventory.id_at(i)
		if id == "":
			continue
		var idx: int = i
		var label: String = "%s ×%d — +%d" % [ItemDb.display_name(id), Inventory.count_at(i), ItemDb.sell_price(id)]
		v.add_child(_row(id, label, true, func() -> void:
			Merchant.sell_slot(idx)
			Audio.play(&"coins")
			refresh()))
	for mid: String in ItemDb.MATERIALS:
		var n: int = GameState.materials[mid] if GameState.materials.has(mid) else 0
		if n <= 0:
			continue
		var m: String = mid
		var row: HBoxContainer = _row(mid, "%s ×%d — +%d" % [tr("MAT_" + mid.to_upper()), n, ItemDb.sell_price(mid)], true, func() -> void:
			Merchant.sell_material(m, 1)
			Audio.play(&"coins")
			refresh())
		(row.get_child(0) as TextureRect).texture = MenuKit.icon("material")
		v.add_child(row)
	_ensure_focus_target(v)
	return outer


## Lista vazia ou toda desabilitada: um botão "voltar" garante foco para o gamepad.
func _ensure_focus_target(v: VBoxContainer) -> void:
	if MenuKit.first_focusable(v) == null:
		v.add_child(UiStyle.body_label(tr("SHOP_EMPTY"), 18))
		v.add_child(MenuKit.button(tr("UI_BACK"), func() -> void: closed.emit()))
