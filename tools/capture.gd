extends SceneTree
## Capturas para o golden visual e a autocrítica. Precisa de renderização (sem --headless).
##
## Uma captura:
##   godot --path . -s res://tools/capture.gd -- --scene=res://levels/x.tscn --out=res://build/x.png
## Várias poses (JSON com lista de {name, scene, hour, cam, target, fov?, coverage?, corruption?, frames?}):
##   godot --path . -s res://tools/capture.gd -- --shots=res://tests/golden/m1/shots.json --outdir=res://tests/golden/m1
## Opções: --overlay (mostra o overlay F3), --frames=N (padrão 90), --preset=low|medium|high|ultra (padrão high).

var _shots: Array = []
var _index: int = -1
var _frames_left: int = 0
var _default_frames: int = 90
var _outdir: String = ""
var _scene_path: String = ""
var _scene: Node = null
var _camera: Camera3D = null
var _failed: bool = false


func _initialize() -> void:
	_default_frames = _arg("--frames", "90").to_int()
	var shots_path: String = _arg("--shots", "")
	if shots_path != "":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(shots_path))
		if not (parsed is Array):
			push_error("capture: JSON de poses inválido: %s" % shots_path)
			quit(1)
			return
		_shots = parsed
		_outdir = _arg("--outdir", shots_path.get_base_dir())
	else:
		_shots = [{"name": _arg("--out", "res://build/captures/capture.png").get_file().get_basename(),
			"scene": _arg("--scene", "res://levels/test_scene.tscn")}]
		_outdir = _arg("--out", "res://build/captures/capture.png").get_base_dir()
	_next_shot()


func _next_shot() -> void:
	_index += 1
	if _index >= _shots.size():
		quit(1 if _failed else 0)
		return
	var shot: Dictionary = _shots[_index]
	var scene_path: String = JsonUtil.get_s(shot, "scene", _scene_path if _scene_path != "" else "res://levels/test_scene.tscn")
	if scene_path != _scene_path:
		if _scene != null:
			_scene.queue_free()
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			push_error("capture: cena não encontrada: %s" % scene_path)
			quit(1)
			return
		_scene = packed.instantiate()
		root.add_child(_scene)
		_scene_path = scene_path
		_camera = null
	_frames_left = JsonUtil.get_i(shot, "frames", _default_frames)
	_setup_shot.call_deferred(shot)


func _setup_shot(shot: Dictionary) -> void:
	# Preset fixo nas capturas (padrão: high) para o golden não depender da máquina.
	var settings: Node = root.get_node_or_null(^"Settings")
	if settings != null and str(settings.call(&"current_preset")) != _arg("--preset", "high"):
		settings.call(&"set_preset", StringName(_arg("--preset", "high")))
	# Acesso dinâmico: este script compila antes dos autoloads, então não pode
	# depender estaticamente de classes que os usam (como Atmosphere).
	var atmo: Node = root.get_tree().get_first_node_in_group(&"atmosphere")
	if atmo != null:
		atmo.set(&"running", false)
		if shot.has("hour"):
			atmo.set(&"hours", JsonUtil.get_f(shot, "hour"))
		if shot.has("coverage"):
			atmo.set(&"cloud_coverage", JsonUtil.get_f(shot, "coverage"))
		atmo.set(&"corruption", JsonUtil.get_f(shot, "corruption", 0.0))
		atmo.call(&"apply_now")
	if shot.has("cam"):
		if _camera == null:
			_camera = Camera3D.new()
			_scene.add_child(_camera)
		_camera.global_position = JsonUtil.vec3(shot["cam"])
		_camera.fov = JsonUtil.get_f(shot, "fov", 70.0)
		_camera.far = 4000.0
		_camera.look_at(JsonUtil.vec3(shot.get("target")))
		_camera.current = true


func _process(_delta: float) -> bool:
	if _index >= _shots.size() or _index < 0:
		return false
	_frames_left -= 1
	if _frames_left > 0:
		return false
	var shot: Dictionary = _shots[_index]
	var img: Image = root.get_texture().get_image()
	var out: String = _outdir.path_join("%s.png" % str(shot.get("name", "shot_%d" % _index)))
	var abs_path: String = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err: Error = img.save_png(abs_path)
	if err != OK:
		_failed = true
	print("capture: %s (%dx%d) %s | GPU %s via %s" % [out, img.get_width(), img.get_height(), error_string(err),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name()])
	_next_shot()
	return false


static func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback
