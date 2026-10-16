class_name UiStyle
extends RefCounted
## Estilo visual da UI (roteiro 6): preto translúcido, filetes dourados, títulos
## serifados e corpo sem serifa. Fontes OFL em assets/fonts (fallback: padrão).

const GOLD: Color = Color("e8b44c")
const GOLD_DIM: Color = Color(0.91, 0.71, 0.3, 0.45)
const BG: Color = Color(0.043, 0.035, 0.063, 0.88)
const BG_SOFT: Color = Color(0.043, 0.035, 0.063, 0.62)
const TEXT: Color = Color(0.93, 0.9, 0.84)
const TEXT_DIM: Color = Color(0.7, 0.66, 0.62)
const VIOLET: Color = Color("b67cff")

const TITLE_FONT_PATH: String = "res://assets/fonts/Cinzel-Variable.ttf"
const BODY_FONT_PATH: String = "res://assets/fonts/AlegreyaSans-Regular.ttf"

static var _theme: Theme


static func title_font() -> Font:
	return load(TITLE_FONT_PATH) as Font if ResourceLoader.exists(TITLE_FONT_PATH) else ThemeDB.fallback_font


static func body_font() -> Font:
	return load(BODY_FONT_PATH) as Font if ResourceLoader.exists(BODY_FONT_PATH) else ThemeDB.fallback_font


static func panel_box(alpha: float = 0.88) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = Color(BG.r, BG.g, BG.b, alpha)
	b.border_color = GOLD_DIM
	b.set_border_width_all(1)
	b.set_content_margin_all(18)
	b.corner_detail = 1
	b.shadow_color = Color(0, 0, 0, 0.45)
	b.shadow_size = 8
	return b


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = body_font()
	t.default_font_size = 20
	t.set_color(&"font_color", &"Label", TEXT)
	t.set_stylebox(&"panel", &"PanelContainer", panel_box())
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.06, 0.1, 0.85)
	normal.border_color = GOLD_DIM
	normal.set_border_width_all(1)
	normal.set_content_margin_all(10)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.1, 0.22, 0.95)
	hover.border_color = GOLD
	var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.25, 0.15, 0.35, 0.95)
	var focus: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	focus.set_border_width_all(2)
	for st: Array in [[&"normal", normal], [&"hover", hover], [&"pressed", pressed], [&"focus", focus], [&"disabled", normal]]:
		t.set_stylebox(st[0] as StringName, &"Button", st[1] as StyleBox)
	t.set_color(&"font_color", &"Button", TEXT)
	t.set_color(&"font_hover_color", &"Button", GOLD)
	t.set_color(&"font_focus_color", &"Button", GOLD)
	t.set_color(&"font_disabled_color", &"Button", TEXT_DIM)
	_theme = t
	return t


static func title_label(text: String, size: int = 30) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override(&"font", title_font())
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", GOLD)
	return l


static func body_label(text: String, size: int = 20) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override(&"font_size", size)
	return l
