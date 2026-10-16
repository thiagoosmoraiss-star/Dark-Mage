extends SceneTree
## Captura de tela de uma cena (golden visual e revisão). Precisa de renderização
## (não use --headless).
## Uso: godot --path . -s res://tools/capture.gd -- --scene=res://levels/x.tscn
##      --out=res://tests/golden/m0/x.png [--frames=60] [--overlay]

var _frames_left: int = 60
var _out: String = ""


func _initialize() -> void:
	var scene_path: String = _arg("--scene", "res://levels/test_scene.tscn")
	_out = _arg("--out", "res://build/captures/capture.png")
	_frames_left = _arg("--frames", "60").to_int()
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("capture: cena não encontrada: %s" % scene_path)
		quit(1)
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_frames_left -= 1
	if _frames_left > 0:
		return false
	var img: Image = root.get_texture().get_image()
	var abs_path: String = ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err: Error = img.save_png(abs_path)
	print("capture: %s (%dx%d) %s | GPU %s via %s" % [
		_out, img.get_width(), img.get_height(), error_string(err),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name()])
	quit(0 if err == OK else 1)
	return true


static func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback
