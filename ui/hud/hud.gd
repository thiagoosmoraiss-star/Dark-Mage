class_name Hud
extends Control
## HUD mínima (roteiro 6): vida e mana, slots de feitiço com recarga, carga,
## ultimate, mira, alvo travado e barras de vida de inimigos feridos.
## Tudo desenhado em _draw (preto translúcido, filetes dourados).

const GOLD: Color = Color("e8b44c")
const GOLD_DIM: Color = Color(0.91, 0.71, 0.3, 0.45)
const BG: Color = Color(0.043, 0.035, 0.063, 0.62)
const HEALTH: Color = Color("b8323f")
const MANA: Color = Color("6b2fd6")
const MANA_GLOW: Color = Color("b67cff")
const KEY_LABELS: Array[String] = ["Q", "E", "R", "F"]

var player: Player
var _alpha: float = 1.0
var _shown_health: float = 1.0
var _lag_health: float = 1.0
var _shown_mana: float = 1.0
var _message: String = ""
var _message_t: float = 0.0
var _font: Font
var _hurt_flash: float = 0.0
var _prompt: String = ""
var _banner_title: String = ""
var _banner_sub: String = ""
var _banner_t: float = 0.0
var _loot_lines: PackedStringArray = []
var _loot_t: float = 0.0
var _title_font: Font
var _boss: Boss
var _subtitle: String = ""
var _subtitle_t: float = 0.0
var _boss_shown: float = 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(&"hud")
	_font = UiStyle.body_font()
	_title_font = UiStyle.title_font()
	Events.region_entered.connect(func(region: StringName) -> void:
		show_banner(tr("REGION_" + String(region).to_upper()), ""))
	Events.perfect_dodge.connect(func() -> void: _show_message("ESQUIVA PERFEITA", 1.2))
	Events.player_damaged.connect(func(_i: RefCounted) -> void: _hurt_flash = 1.0)


func bind(p: Player) -> void:
	player = p
	var inter: Interactor = p.get_node_or_null(^"Interactor") as Interactor
	if inter != null:
		inter.focus_changed.connect(func(t: Interactable) -> void:
			_prompt = "" if t == null else t.prompt_text())
	p.caster.cast_failed.connect(func(reason: StringName) -> void:
		_show_message(tr("HUD_NO_MANA") if reason == &"mana" else tr("HUD_COOLDOWN"), 0.8))


## Faixa grande no centro-alto (região, farol aceso, chefe).
func show_banner(title: String, subtitle: String, seconds: float = 3.5) -> void:
	_banner_title = title
	_banner_sub = subtitle
	_banner_t = seconds


func set_boss(b: Boss) -> void:
	_boss = b
	if b != null:
		_boss_shown = 1.0


## Legendas (falas breves dos chefes), com tamanho ajustável na acessibilidade.
func show_subtitle(text: String, seconds: float) -> void:
	if Settings.get_value("accessibility", "subtitles") == false:
		return
	_subtitle = text
	_subtitle_t = seconds


func show_loot(loot: Dictionary) -> void:
	_loot_lines = []
	if JsonUtil.get_i(loot, "souls") > 0:
		_loot_lines.append("+%d %s" % [JsonUtil.get_i(loot, "souls"), tr("ITEM_SOULS")])
	if JsonUtil.get_i(loot, "crystals") > 0:
		_loot_lines.append("+%d %s" % [JsonUtil.get_i(loot, "crystals"), tr("ITEM_CRYSTALS")])
	var mat: String = JsonUtil.get_s(loot, "material")
	if mat != "":
		_loot_lines.append("+%d %s" % [JsonUtil.get_i(loot, "material_count"), tr("MAT_" + mat.to_upper())])
	_loot_t = 4.0


func _show_message(text: String, seconds: float) -> void:
	_message = text
	_message_t = seconds


func _process(delta: float) -> void:
	if player == null:
		return
	var s: PlayerStats = player.stats
	_shown_health = lerpf(_shown_health, s.health / s.max_health, 1.0 - exp(-16.0 * delta))
	_lag_health = move_toward(_lag_health, _shown_health, delta * (0.35 if _lag_health > _shown_health else 4.0))
	_shown_mana = lerpf(_shown_mana, s.mana / s.max_mana, 1.0 - exp(-16.0 * delta))
	var hide_ooc: bool = Settings.get_value("accessibility", "hud_hide_out_of_combat") == true
	var want: float = 1.0
	if hide_ooc and not s.in_combat and s.health >= s.max_health * 0.999 and s.mana >= s.max_mana * 0.999:
		want = 0.0
	_alpha = move_toward(_alpha, want, delta * 2.0)
	_message_t = maxf(_message_t - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta * 2.5, 0.0)
	_banner_t = maxf(_banner_t - delta, 0.0)
	_loot_t = maxf(_loot_t - delta, 0.0)
	_subtitle_t = maxf(_subtitle_t - delta, 0.0)
	if _boss != null and is_instance_valid(_boss):
		_boss_shown = lerpf(_boss_shown, _boss.health / _boss.max_health, 1.0 - exp(-10.0 * delta))
	elif _boss != null:
		_boss = null
	var ui_scale: float = JsonUtil.num(Settings.get_value("accessibility", "ui_scale"), 1.0)
	scale = Vector2(ui_scale, ui_scale)
	size = get_viewport_rect().size / ui_scale
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var vs: Vector2 = size
	_draw_vitals(Vector2(28, vs.y - 92))
	_draw_slots(Vector2(vs.x - 28 - 4 * 64, vs.y - 92))
	_draw_crosshair(vs * 0.5)
	_draw_lock_and_enemies()
	if _message_t > 0.0:
		var a: float = clampf(_message_t * 2.0, 0.0, 1.0)
		var w: float = _font.get_string_size(_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(_font, Vector2(vs.x * 0.5 - w * 0.5, vs.y * 0.3), _message, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
			Color(GOLD, a))
	_draw_world_ui(vs)
	if _hurt_flash > 0.0 and Settings.get_value("accessibility", "reduce_flashes") != true:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.6, 0.05, 0.1, 0.12 * _hurt_flash), false, 24.0)


func _draw_world_ui(vs: Vector2) -> void:
	# Prompt de interação.
	if _prompt != "":
		var text: String = "[G]  " + _prompt
		var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var r: Rect2 = Rect2(Vector2(vs.x * 0.5 - w * 0.5 - 16, vs.y * 0.7), Vector2(w + 32, 38))
		draw_rect(r, Color(BG, 0.75))
		draw_rect(r, GOLD_DIM, false, 1.0)
		draw_string(_font, r.position + Vector2(16, 26), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.95, 0.9, 0.82))
	# Faixa (região, farol).
	if _banner_t > 0.0:
		var a: float = clampf(_banner_t, 0.0, 1.0) * clampf((3.5 - _banner_t) * 2.0 + 0.2, 0.0, 1.0)
		var tw: float = _title_font.get_string_size(_banner_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		var y: float = vs.y * 0.2
		draw_string(_title_font, Vector2(vs.x * 0.5 - tw * 0.5, y), _banner_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(GOLD, a))
		draw_line(Vector2(vs.x * 0.5 - tw * 0.6, y + 12), Vector2(vs.x * 0.5 + tw * 0.6, y + 12), Color(GOLD_DIM, a), 1.0)
		if _banner_sub != "":
			var sw: float = _font.get_string_size(_banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(_font, Vector2(vs.x * 0.5 - sw * 0.5, y + 42), _banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.93, 0.9, 0.84, a))
	# Barra do chefe.
	if _boss != null and is_instance_valid(_boss) and _boss.is_alive():
		var bw: float = minf(vs.x * 0.55, 760.0)
		var br: Rect2 = Rect2(Vector2(vs.x * 0.5 - bw * 0.5, vs.y - 70), Vector2(bw, 12))
		var name_text: String = tr(_boss.boss.name_key)
		var nw: float = _title_font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(_title_font, Vector2(vs.x * 0.5 - nw * 0.5, br.position.y - 10), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, GOLD)
		draw_rect(br.grow(2.0), Color(BG, 0.85))
		draw_rect(Rect2(br.position, Vector2(bw * _boss_shown, 12)), HEALTH if not _boss.guarded else Color("6b9bd6"))
		if _boss.vulnerable_time > 0.0:
			draw_rect(br, Color(GOLD, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02)), false, 2.0)
		for t: float in _boss.boss.phase_thresholds:
			var x: float = br.position.x + bw * t
			draw_line(Vector2(x, br.position.y - 3), Vector2(x, br.end.y + 3), GOLD, 2.0)
		draw_rect(br, GOLD_DIM, false, 1.0)
	# Legenda.
	if _subtitle_t > 0.0:
		var size_k: float = JsonUtil.num(Settings.get_value("accessibility", "subtitle_size"), 1.0)
		var fs: int = roundi(22 * size_k)
		var sw2: float = _font.get_string_size(_subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sr: Rect2 = Rect2(Vector2(vs.x * 0.5 - sw2 * 0.5 - 14, vs.y - 150), Vector2(sw2 + 28, fs + 16))
		var sa: float = clampf(_subtitle_t * 2.0, 0.0, 1.0)
		draw_rect(sr, Color(0, 0, 0, 0.55 * sa))
		draw_string(_font, sr.position + Vector2(14, fs + 4), _subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.92, 0.85, sa))
	# Saque recebido.
	if _loot_t > 0.0:
		var a2: float = clampf(_loot_t, 0.0, 1.0)
		for i: int in _loot_lines.size():
			draw_string(_font, Vector2(vs.x - 300, vs.y * 0.45 + i * 28), _loot_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(GOLD, a2))
	# Almas (canto superior direito, discreto).
	var souls: String = "%d  %s" % [GameState.souls, tr("ITEM_SOULS")]
	draw_string(_font, Vector2(vs.x - 28 - _font.get_string_size(souls, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, 40), souls,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.8, 0.95, 0.75 * _alpha))


func _panel(r: Rect2) -> void:
	draw_rect(r, Color(BG, BG.a * _alpha))
	draw_rect(r, Color(GOLD_DIM, GOLD_DIM.a * _alpha), false, 1.0)


func _draw_vitals(origin: Vector2) -> void:
	var w: float = 260.0
	_panel(Rect2(origin - Vector2(10, 10), Vector2(w + 20, 64)))
	# Vida: barra vermelha com "rastro" claro do dano recente.
	var hr: Rect2 = Rect2(origin, Vector2(w, 14))
	draw_rect(hr, Color(0, 0, 0, 0.5 * _alpha))
	draw_rect(Rect2(hr.position, Vector2(w * _lag_health, 14)), Color(0.95, 0.85, 0.75, 0.55 * _alpha))
	draw_rect(Rect2(hr.position, Vector2(w * _shown_health, 14)), Color(HEALTH, _alpha))
	draw_rect(hr, Color(GOLD, 0.8 * _alpha), false, 1.0)
	# Mana.
	var mr: Rect2 = Rect2(origin + Vector2(0, 22), Vector2(w * 0.85, 9))
	draw_rect(mr, Color(0, 0, 0, 0.5 * _alpha))
	draw_rect(Rect2(mr.position, Vector2(mr.size.x * _shown_mana, 9)), Color(MANA, _alpha))
	draw_rect(Rect2(mr.position, Vector2(mr.size.x * _shown_mana, 3)), Color(MANA_GLOW, 0.8 * _alpha))
	draw_rect(mr, Color(GOLD_DIM, _alpha), false, 1.0)
	# Ultimate: losango que enche de dourado.
	var c: SpellCaster = player.caster
	var s: SpellData = Spells.get_spell(&"beacon_wrath")
	if c.unlocked.has(&"beacon_wrath") and s != null:
		var u: float = c.ultimate_charge / float(s.count)
		var center: Vector2 = origin + Vector2(w * 0.93, 27)
		var pts: PackedVector2Array = [center + Vector2(0, -11), center + Vector2(11, 0), center + Vector2(0, 11), center + Vector2(-11, 0)]
		draw_colored_polygon(pts, Color(0, 0, 0, 0.5 * _alpha))
		var inner: PackedVector2Array = []
		for p: Vector2 in pts:
			inner.append(center + (p - center) * u)
		draw_colored_polygon(inner, Color(GOLD, (0.6 + 0.4 * float(u >= 1.0)) * _alpha))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(GOLD, _alpha), 1.0)
	var hp_text: String = "%d / %d" % [roundi(player.stats.health), roundi(player.stats.max_health)]
	draw_string(_font, origin + Vector2(4, 48), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.86, 0.8, 0.7 * _alpha))


func _draw_slots(origin: Vector2) -> void:
	var c: SpellCaster = player.caster
	for i: int in 4:
		var r: Rect2 = Rect2(origin + Vector2(i * 64, 0), Vector2(54, 54))
		_panel(r)
		var s: SpellData = c.slot_spell(i)
		if s != null:
			var center: Vector2 = r.get_center()
			var can_pay: bool = player.stats.mana >= s.mana_cost
			var col: Color = s.color if can_pay else s.color.darkened(0.6)
			_draw_spell_icon(s, center, 15.0, Color(col, _alpha))
			var f: float = c.cooldowns.fraction(s.id)
			if f > 0.0:
				draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * f)), Color(0, 0, 0, 0.55 * _alpha))
				draw_arc(center, 22.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - f), 32, Color(GOLD, 0.8 * _alpha), 2.0, true)
		draw_string(_font, r.position + Vector2(4, 13), KEY_LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(GOLD, 0.9 * _alpha))
	# Carga.
	var ch: float = c.charge_ratio()
	if ch > 0.0:
		var bar: Rect2 = Rect2(size * 0.5 + Vector2(-60, 40), Vector2(120, 5))
		draw_rect(bar, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ch, 5)), MANA_GLOW if ch < 1.0 else GOLD)


## Ícones próprios desenhados (um símbolo por tipo de feitiço).
func _draw_spell_icon(s: SpellData, c: Vector2, r: float, col: Color) -> void:
	match s.kind:
		SpellData.Kind.PROJECTILE:
			draw_colored_polygon([c + Vector2(0, -r), c + Vector2(r * 0.4, 0), c + Vector2(0, r), c + Vector2(-r * 0.4, 0)], col)
		SpellData.Kind.AREA:
			draw_arc(c, r * 0.9, 0.0, TAU, 32, col, 3.0, true)
			draw_arc(c, r * 0.45, 0.0, TAU, 24, col, 2.0, true)
		SpellData.Kind.CHAIN:
			draw_polyline([c + Vector2(-r * 0.6, -r), c + Vector2(r * 0.2, -r * 0.1), c + Vector2(-r * 0.2, r * 0.1), c + Vector2(r * 0.6, r)], col, 3.0, true)
		SpellData.Kind.BARRIER:
			draw_arc(c, r * 0.85, PI, TAU, 24, col, 3.0, true)
			draw_line(c + Vector2(-r * 0.85, 0), c + Vector2(r * 0.85, 0), col, 2.0, true)
		SpellData.Kind.METEOR:
			draw_circle(c + Vector2(r * 0.3, r * 0.3), r * 0.45, col)
			draw_line(c + Vector2(r * 0.1, r * 0.1), c + Vector2(-r * 0.8, -r * 0.8), col, 3.0, true)
		SpellData.Kind.BLINK:
			draw_arc(c + Vector2(-r * 0.4, 0), r * 0.4, 0.0, TAU, 16, col, 2.0, true)
			draw_circle(c + Vector2(r * 0.5, 0), r * 0.3, col)
		SpellData.Kind.CONTROL:
			for k: int in 3:
				var a: float = k * PI / 3.0
				draw_line(c - Vector2(cos(a), sin(a)) * r, c + Vector2(cos(a), sin(a)) * r, col, 2.5, true)
		_:
			draw_colored_polygon([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)], col)


func _draw_crosshair(c: Vector2) -> void:
	if not player.caster.aiming:
		return
	var col: Color = Color(GOLD, 0.9)
	draw_arc(c, 9.0, 0.0, TAU, 24, col, 1.5, true)
	draw_circle(c, 1.8, col)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + d * 13.0, c + d * 19.0, col, 1.5, true)


func _draw_lock_and_enemies() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var lock: Node3D = player.caster.lock_target
	for e: Node in get_tree().get_nodes_in_group(&"enemy"):
		var en: Enemy = e as Enemy
		if en == null or not en.is_alive() or not en.visible:
			continue
		var damaged: bool = en.health < en.max_health
		var top: Vector3 = en.global_position + Vector3.UP * 2.3 * en.data.model_scale
		if (not damaged and en != lock) or cam.is_position_behind(top):
			continue
		if en.global_position.distance_to(cam.global_position) > 40.0:
			continue
		var sp: Vector2 = cam.unproject_position(top) / scale
		var w: float = 54.0
		var r: Rect2 = Rect2(sp - Vector2(w * 0.5, 0), Vector2(w, 5))
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(r.position, Vector2(w * en.health / en.max_health, 5)), HEALTH.lightened(0.1) if not en.elite else GOLD)
		if en == lock:
			var mid: Vector3 = en.global_position + Vector3.UP * 1.1 * en.data.model_scale
			var lp: Vector2 = cam.unproject_position(mid) / scale
			var k: float = 10.0 + sin(Time.get_ticks_msec() * 0.006) * 2.0
			var pts: PackedVector2Array = [lp + Vector2(0, -k), lp + Vector2(k, 0), lp + Vector2(0, k), lp + Vector2(-k, 0), lp + Vector2(0, -k)]
			draw_polyline(pts, GOLD, 2.0, true)
