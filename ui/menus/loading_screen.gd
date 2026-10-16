class_name LoadingScreen
extends Control
## Tela de carregamento: carrega a cena alvo em segundo plano com barra de
## progresso e uma dica de lore; troca de cena quando termina.

const TIPS: int = 8

var target: String = ""
var _bar: ProgressBar
var _progress: Array = []
var _done: bool = false


func _ready() -> void:
	theme = UiStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.025, 0.045)
	add_child(bg)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	v.offset_top = -190
	v.offset_left = -420
	v.offset_right = 420
	v.add_theme_constant_override(&"separation", 14)
	add_child(v)
	var tip: Label = UiStyle.body_label(tr("TIP_%d" % (randi() % TIPS + 1)), 20)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_color_override(&"font_color", UiStyle.TEXT_DIM)
	v.add_child(tip)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(840, 6)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = UiStyle.GOLD
	_bar.add_theme_stylebox_override(&"fill", fill)
	var bgs: StyleBoxFlat = StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.08)
	_bar.add_theme_stylebox_override(&"background", bgs)
	v.add_child(_bar)
	var t: Label = UiStyle.title_label(tr("UI_LOADING"), 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if ResourceLoader.load_threaded_request(target) != OK:
		push_error("LoadingScreen: não foi possível carregar " + target)


func _process(_delta: float) -> void:
	if _done:
		return
	var st: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(target, _progress)
	if not _progress.is_empty():
		_bar.value = JsonUtil.num(_progress[0]) * 100.0
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		_done = true
		var ps: PackedScene = ResourceLoader.load_threaded_get(target) as PackedScene
		get_tree().change_scene_to_packed.call_deferred(ps)
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_done = true
		push_error("LoadingScreen: falha ao carregar " + target)
