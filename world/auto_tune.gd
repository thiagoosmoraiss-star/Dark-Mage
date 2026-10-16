class_name AutoTune
extends Node
## Microbenchmark da primeira execução: depois de 6 s na ilha, mede 3 s de jogo; se
## a média ficar abaixo de MIN_FPS, desce um preset (uma vez só) e avisa na HUD.
## O palpite inicial pelo nome da GPU continua em GraphicsPresets.guess_from_adapter.

const WAIT: float = 6.0
const MEASURE: float = 3.0
const MIN_FPS: float = 28.0

var _t: float = 0.0
var _frames: int = 0
var _time: float = 0.0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	var tool_run: bool = Engine.get_main_loop().get_script() != null
	if Settings.get_value("graphics", "auto_tuned") == true or DisplayServer.get_name() == "headless" or tool_run \
			or Game.has_arg("--bench") or Game.has_arg("--export-smoke") or args.has("--resolution"):
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	if _t < WAIT:
		return
	_frames += 1
	_time += delta
	if _time < MEASURE:
		return
	var fps: float = _frames / _time
	Settings.set_value("graphics", "auto_tuned", true)
	var order: Array[StringName] = GraphicsPresets.ORDER
	var idx: int = order.find(Settings.current_preset())
	if fps < MIN_FPS and idx > 0:
		Settings.set_preset(order[idx - 1])
		var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
		if hud != null:
			hud.show_banner(tr("AUTOTUNE_TITLE"), tr("AUTOTUNE_DESC") % tr("PRESET_" + String(order[idx - 1]).to_upper()), 5.0)
	Settings.save_settings()
	print("AutoTune: %.1f FPS no preset %s" % [fps, Settings.current_preset()])
	queue_free()
