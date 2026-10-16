class_name GameMenu
extends TabbedScreen
## Menu de jogo (I / Back; L / D-pad ←): inventário em grade com equipamento e
## comparação, personagem (atributos), feitiços (slots) e diário de missões.

enum Tab { INVENTORY, CHARACTER, SPELLS, JOURNAL }

const COLS: int = 9
const STATS: Array[String] = ["health", "mana", "stamina", "power"]

var player: Player
var _detail: VBoxContainer
var _picked: int = -1
var _spell_slot: int = 0


func _init() -> void:
	title = tr("UI_GAME_MENU")
	hint = tr("UI_HINT_INVENTORY")
	tabs = [
		[tr("TAB_INVENTORY"), _inventory_tab],
		[tr("TAB_CHARACTER"), _character_tab],
		[tr("TAB_SPELLS"), _spells_tab],
		[tr("TAB_JOURNAL"), _journal_tab],
	]


# --- Inventário -------------------------------------------------------------------

func _inventory_tab() -> Control:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 28)
	# Coluna de equipamento.
	var eq: VBoxContainer = VBoxContainer.new()
	eq.add_theme_constant_override(&"separation", 10)
	eq.add_child(UiStyle.title_label(tr("INV_EQUIPPED"), 22))
	for slot: String in ItemDb.EQUIP_SLOTS:
		var row: HBoxContainer = HBoxContainer.new()
		var s: ItemSlot = ItemSlot.new()
		s.name = "Equip_" + slot
		s.equip_slot = slot
		s.set_item(Inventory.equipped[slot], 1 if Inventory.equipped[slot] != "" else 0)
		var sl: String = slot
		s.pressed.connect(func() -> void:
			if Inventory.unequip(sl):
				Audio.play(&"ui_confirm")
				_apply()
			else:
				Audio.play(&"ui_error"))
		s.focus_entered.connect(func() -> void: _show_detail(Inventory.equipped[sl]))
		row.add_child(s)
		var l: Label = Label.new()
		l.text = tr("SLOT_" + slot.to_upper())
		l.add_theme_color_override(&"font_color", UiStyle.TEXT_DIM)
		row.add_child(l)
		eq.add_child(row)
	eq.add_child(MenuKit.separator())
	eq.add_child(_currency_line("souls", GameState.souls))
	eq.add_child(_currency_line("crystal", GameState.crystals))
	h.add_child(eq)
	# Grade.
	var gv: VBoxContainer = VBoxContainer.new()
	gv.add_child(UiStyle.title_label(tr("INV_BAG"), 22))
	var grid: GridContainer = GridContainer.new()
	grid.name = "Grid"
	grid.columns = COLS
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	for i: int in Inventory.SIZE:
		var s2: ItemSlot = ItemSlot.new()
		s2.name = "Slot_%d" % i
		s2.index = i
		s2.set_item(Inventory.id_at(i), Inventory.count_at(i))
		s2.picked = i == _picked
		var idx: int = i
		s2.pressed.connect(func() -> void: _on_slot_pressed(idx))
		s2.focus_entered.connect(func() -> void: _show_detail(Inventory.id_at(idx)))
		s2.dropped_on.connect(func(from: int, to: int) -> void:
			Inventory.move(from, to)
			Audio.play(&"ui_click")
			refresh())
		s2.gui_input.connect(func(ev: InputEvent) -> void: _slot_input(idx, ev))
		grid.add_child(s2)
	gv.add_child(grid)
	# Materiais (somente leitura; vendidos ao mercador).
	var mats: HBoxContainer = HBoxContainer.new()
	mats.add_theme_constant_override(&"separation", 14)
	for mid: String in ItemDb.MATERIALS:
		var n: int = GameState.materials[mid] if GameState.materials.has(mid) else 0
		if n <= 0:
			continue
		var tr_: TextureRect = TextureRect.new()
		tr_.texture = MenuKit.icon("material")
		tr_.modulate = ItemDb.tint(mid)
		tr_.custom_minimum_size = Vector2(26, 26)
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.tooltip_text = tr("MAT_" + mid.to_upper())
		mats.add_child(tr_)
		var l2: Label = Label.new()
		l2.text = "%s ×%d" % [tr("MAT_" + mid.to_upper()), n]
		mats.add_child(l2)
	if mats.get_child_count() > 0:
		gv.add_child(MenuKit.separator())
		gv.add_child(mats)
	else:
		mats.free()
	h.add_child(gv)
	# Detalhes + comparação.
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(360, 0)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override(&"separation", 8)
	h.add_child(_detail)
	return h


func _currency_line(icon_name: String, n: int) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	var t: TextureRect = TextureRect.new()
	t.texture = MenuKit.icon(icon_name)
	t.modulate = UiStyle.VIOLET if icon_name == "crystal" else UiStyle.GOLD
	t.custom_minimum_size = Vector2(26, 26)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h.add_child(t)
	var l: Label = Label.new()
	l.text = "%d  %s" % [n, tr("CURRENCY_" + icon_name.to_upper())]
	h.add_child(l)
	return h


func _on_slot_pressed(i: int) -> void:
	if _picked >= 0:
		Inventory.move(_picked, i)
		_picked = -1
		Audio.play(&"ui_click")
		refresh()
		return
	var id: String = Inventory.id_at(i)
	if id == "":
		return
	if ItemDb.is_equipment(id):
		Inventory.equip_from(i)
		Audio.play(&"ui_confirm")
		_apply()
	elif ItemDb.slot_of(id) == ItemDb.Slot.CONSUMABLE:
		if not Inventory.use_at(i, player):
			Audio.play(&"ui_error")
		refresh()


## "Mover" (X no teclado, Y no gamepad): pega o item; confirmar em outra casa solta.
func _slot_input(i: int, ev: InputEvent) -> void:
	if ev.is_action_pressed(&"ui_move_item"):
		_picked = -1 if _picked == i else (i if Inventory.id_at(i) != "" else -1)
		Audio.play(&"ui_select")
		get_viewport().set_input_as_handled()
		refresh()


func _apply() -> void:
	if player != null:
		player.apply_progression()
	refresh()


func _show_detail(id: String) -> void:
	if _detail == null:
		return
	for c: Node in _detail.get_children():
		c.queue_free()
	if id == "":
		return
	_detail.add_child(UiStyle.title_label(ItemDb.display_name(id), 24))
	var kind: Label = Label.new()
	kind.text = tr("SLOT_" + ItemDb.slot_name(id).to_upper())
	kind.add_theme_color_override(&"font_color", ItemSlot.RARITY_COLORS[clampi(JsonUtil.get_i(ItemDb.get_item(id), "rarity"), 0, 2)])
	_detail.add_child(kind)
	_detail.add_child(UiStyle.body_label(ItemDb.description(id), 18))
	# Comparação com o equipado no mesmo espaço.
	var other: String = ""
	if ItemDb.is_equipment(id):
		var slot: String = ItemDb.slot_name(id)
		other = Inventory.equipped[slot] if Inventory.equipped[slot] != id else ""
	var mine: Dictionary = _lines_dict(id)
	var theirs: Dictionary = _lines_dict(other)
	var keys: Array = mine.keys()
	for k: Variant in theirs.keys():
		if not keys.has(k):
			keys.append(k)
	if not keys.is_empty():
		_detail.add_child(MenuKit.separator())
	for k: Variant in keys:
		var a: float = JsonUtil.num(mine.get(k, 0.0))
		var b: float = JsonUtil.num(theirs.get(k, 0.0))
		var l: Label = Label.new()
		var delta: String = ""
		if other != "" and absf(a - b) > 0.01:
			delta = "  (%s%.0f)" % ["+" if a > b else "", a - b] if str(k) != "rate" else "  (%s%.1f)" % ["+" if a > b else "", a - b]
			l.add_theme_color_override(&"font_color", Color("8fd18a") if a > b else Color("e07a6b"))
		l.text = ("%s: %.0f" if str(k) != "rate" else "%s: %.1f/s") % [tr("STAT_" + str(k).to_upper()), a] + delta
		_detail.add_child(l)
	if other != "":
		var cmp: Label = Label.new()
		cmp.text = tr("INV_COMPARED") % ItemDb.display_name(other)
		cmp.add_theme_color_override(&"font_color", UiStyle.TEXT_DIM)
		cmp.add_theme_font_size_override(&"font_size", 16)
		_detail.add_child(cmp)


func _lines_dict(id: String) -> Dictionary:
	var d: Dictionary = {}
	if id == "":
		return d
	for line: Array in ItemDb.stat_lines(id):
		d[line[0]] = line[1]
	return d


# --- Personagem ---------------------------------------------------------------------

func _character_tab() -> Control:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 12)
	v.add_child(UiStyle.title_label(tr("CHAR_LEVEL") % GameState.level, 28))
	var need: int = GameState.xp_to_next(GameState.level)
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = need
	bar.value = GameState.xp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(420, 14)
	v.add_child(bar)
	var xl: Label = Label.new()
	xl.text = tr("CHAR_XP") % [GameState.xp, need]
	v.add_child(xl)
	var pts: Label = Label.new()
	pts.text = tr("CHAR_POINTS") % GameState.attribute_points
	pts.add_theme_color_override(&"font_color", UiStyle.GOLD if GameState.attribute_points > 0 else UiStyle.TEXT_DIM)
	v.add_child(pts)
	v.add_child(MenuKit.separator())
	for stat: String in STATS:
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override(&"separation", 16)
		var l: Label = Label.new()
		l.text = "%s  %d" % [tr("ATTR_" + stat.to_upper()), GameState.attributes[stat]]
		l.custom_minimum_size = Vector2(300, 0)
		h.add_child(l)
		var st: String = stat
		var b: Button = MenuKit.button("+", func() -> void:
			if GameState.spend_point(st):
				Audio.play(&"ui_confirm")
				_apply(), 40)
		b.name = "Add_" + stat
		b.custom_minimum_size = Vector2(56, 40)
		b.disabled = GameState.attribute_points <= 0
		h.add_child(b)
		var d: Label = Label.new()
		d.text = tr("ATTR_" + stat.to_upper() + "_DESC")
		d.add_theme_color_override(&"font_color", UiStyle.TEXT_DIM)
		h.add_child(d)
		v.add_child(h)
	v.add_child(MenuKit.separator())
	if player != null:
		var s: PlayerStats = player.stats
		for line: String in [
			tr("STAT_HEALTH") + ": %.0f / %.0f" % [s.health, s.max_health],
			tr("STAT_MANA") + ": %.0f / %.0f" % [s.mana, s.max_mana],
			tr("STAT_STAMINA") + ": %.0f" % s.max_stamina,
			tr("STAT_POWER") + ": ×%.2f" % player.caster.power,
			tr("CHAR_SIGILS") % [GameState.sigils_health, GameState.sigils_mana],
			tr("CHAR_TIME") % MenuKit.format_time(GameState.play_time_s),
		]:
			var l3: Label = Label.new()
			l3.text = line
			v.add_child(l3)
	# Sem nenhum botão ativo a aba ainda precisa de um alvo de foco.
	if GameState.attribute_points <= 0:
		var spacer: Button = MenuKit.button(tr("UI_BACK"), func() -> void: closed.emit())
		v.add_child(spacer)
	return v


# --- Feitiços --------------------------------------------------------------------------

func _spells_tab() -> Control:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 12)
	if player == null:
		return v
	v.add_child(UiStyle.body_label(tr("SPELLS_HELP"), 18))
	var slots: HBoxContainer = HBoxContainer.new()
	slots.add_theme_constant_override(&"separation", 10)
	var keys: Array[String] = []
	for a: StringName in SpellCaster.SLOT_ACTIONS:
		keys.append(InputDefaults.action_label(a, false))
	for i: int in 4:
		var s: SpellData = player.caster.slot_spell(i)
		var idx: int = i
		var b: Button = MenuKit.button("%s  ·  %s" % [keys[i], tr(s.name_key) if s != null else "—"], func() -> void:
			_spell_slot = idx
			refresh())
		b.name = "SpellSlot_%d" % i
		b.toggle_mode = true
		b.button_pressed = i == _spell_slot
		b.custom_minimum_size = Vector2(240, 50)
		slots.add_child(b)
	v.add_child(slots)
	v.add_child(MenuKit.separator())
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 10)
	for id: StringName in Spells.all_ids():
		var sp: SpellData = Spells.get_spell(id)
		if sp == null or id == &"beacon_wrath":
			continue  # a ultimate não ocupa slot (Q+F juntos)
		var known: bool = player.caster.unlocked.has(id)
		var sid: StringName = id
		var b2: Button = MenuKit.button(tr(sp.name_key) if known else "???", func() -> void:
			player.caster.equip(_spell_slot, sid)
			Audio.play(&"ui_confirm")
			refresh(), 50)
		b2.name = "Spell_" + String(id)
		b2.disabled = not known
		b2.custom_minimum_size = Vector2(300, 50)
		b2.tooltip_text = tr(sp.desc_key) if known else tr("SPELL_LOCKED")
		grid.add_child(b2)
		var d: Label = UiStyle.body_label(tr(sp.desc_key) if known else tr("SPELL_LOCKED"), 16)
		d.custom_minimum_size = Vector2(520, 0)
		d.add_theme_color_override(&"font_color", UiStyle.TEXT_DIM)
		grid.add_child(d)
	v.add_child(grid)
	if player.caster.unlocked.has(&"beacon_wrath"):
		v.add_child(UiStyle.body_label(tr("SPELLS_ULTIMATE_HELP"), 17))
	return v


# --- Diário ------------------------------------------------------------------------------

func _journal_tab() -> Control:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 8)
	sc.add_child(v)
	for main: bool in [true, false]:
		v.add_child(UiStyle.title_label(tr("JOURNAL_MAIN") if main else tr("JOURNAL_OPTIONAL"), 24))
		for q: Dictionary in Journal.quests():
			if q["main"] != main:
				continue
			var b: Button = Button.new()
			b.focus_mode = Control.FOCUS_ALL
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(0, 64)
			var locked: bool = q["locked"]
			var mark: String = "✔ " if q["done"] else ("◇ " if locked else "◆ ")
			b.text = "%s%s   %d/%d\n    %s" % [mark, q["title"], q["progress"], q["total"], tr("QUEST_LOCKED") if locked else q["desc"]]
			if q["done"]:
				b.add_theme_color_override(&"font_color", UiStyle.TEXT_DIM)
			b.mouse_entered.connect(func() -> void: b.grab_focus())
			v.add_child(b)
		v.add_child(MenuKit.separator())
	return sc
