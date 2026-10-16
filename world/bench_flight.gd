class_name BenchFlight
extends Node
## Benchmark fixo (roteiro, seção 10): voo de câmera de 60 s por três regiões
## (Vale -> Floresta -> Picos), com hora do dia fixa. Grava JSON em
## user://bench/ com FPS médio, P95/P99 do tempo de frame, draw calls,
## primitivas e memória. Uso: godot --path . -- --bench [--preset=high]

## Duração do voo (60 s por padrão; --bench-seconds=N para perfis rápidos).
var duration: float = 60.0
const WARMUP: float = 3.0
## Pontos de controle do voo: [posição, alvo].
const PATH: Array[Array] = [
	[Vector3(0, 40, 300), Vector3(0, 30, 120)],
	[Vector3(40, 22, 120), Vector3(60, 18, -60)],
	[Vector3(60, 30, 420), Vector3(40, 20, 620)],
	[Vector3(20, 24, 620), Vector3(-40, 30, 760)],
	[Vector3(-80, 90, -200), Vector3(-80, 150, -600)],
	[Vector3(-120, 140, -480), Vector3(-60, 180, -700)],
]

var camera: Camera3D
var _t: float = -WARMUP
var _stats: FrameStats = FrameStats.new(8000)
var _draw_calls: PackedFloat32Array = []
var _primitives: PackedFloat32Array = []
var _vram_start: float = 0.0
var _objects_start: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	duration = _arg("--bench-seconds", "60").to_float()
	var preset: String = _arg("--preset", "")
	if preset != "":
		Settings.set_preset(StringName(preset))
	_apply_profile_flags()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	camera = Camera3D.new()
	camera.name = "BenchCamera"
	camera.far = 4000.0
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	camera.current = true
	var terrain: Node = get_tree().get_first_node_in_group(&"island_terrain")
	if terrain != null:
		(terrain.get(&"terrain") as Node).call(&"set_camera", camera)
	var atmo: Node = get_tree().get_first_node_in_group(&"atmosphere")
	if atmo != null:
		atmo.set(&"running", false)
		atmo.set(&"hours", 10.0)
		atmo.call(&"apply_now")
	_place(0.0)


## Flags de perfil para isolar custos (só desenvolvimento).
func _apply_profile_flags() -> void:
	var vp: Viewport = get_viewport()
	if Game.has_arg("--no-fsr"):
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if Game.has_arg("--fsr1"):
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	var atmo: Node = get_tree().get_first_node_in_group(&"atmosphere")
	var env: Environment = atmo.get(&"environment") if atmo != null else null
	if env != null:
		if Game.has_arg("--no-glow"):
			env.glow_enabled = false
		if Game.has_arg("--no-fog"):
			env.fog_enabled = false
			env.volumetric_fog_enabled = false
		if Game.has_arg("--no-sky"):
			env.background_mode = Environment.BG_COLOR
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var terrain: Node3D = get_tree().get_first_node_in_group(&"island_terrain") as Node3D
	if terrain != null and Game.has_arg("--no-terrain"):
		terrain.visible = false


func _process(delta: float) -> void:
	_t += delta
	_place(clampf(_t / duration, 0.0, 1.0))
	if _t < 0.0:
		return
	if _vram_start == 0.0:
		_vram_start = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
		_objects_start = Performance.get_monitor(Performance.OBJECT_COUNT)
	_stats.push(delta * 1000.0)
	_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if _t >= duration:
		_finish()


func _place(u: float) -> void:
	var seg: float = u * (PATH.size() - 1)
	var i: int = mini(floori(seg), PATH.size() - 2)
	var f: float = smoothstep(0.0, 1.0, seg - i)
	var a: Array = PATH[i]
	var b: Array = PATH[i + 1]
	var pos: Vector3 = (a[0] as Vector3).lerp(b[0] as Vector3, f)
	var target: Vector3 = (a[1] as Vector3).lerp(b[1] as Vector3, f)
	camera.global_position = pos
	camera.look_at(target)


func _finish() -> void:
	set_process(false)
	var avg_ms: float = _stats.average()
	var report: Dictionary = {
		"date": Time.get_datetime_string_from_system(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"preset": String(Settings.current_preset()),
		"resolution": "%dx%d" % [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"frames": _stats.count(),
		"fps_avg": 1000.0 / maxf(avg_ms, 0.001),
		"frame_ms_avg": avg_ms,
		"frame_ms_p95": _stats.percentile(95.0),
		"frame_ms_p99": _stats.percentile(99.0),
		"draw_calls_avg": _mean(_draw_calls),
		"draw_calls_max": _max(_draw_calls),
		"primitives_avg": _mean(_primitives),
		"vram_mb_start": _vram_start / 1048576.0,
		"vram_mb_end": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"objects_start": _objects_start,
		"objects_end": Performance.get_monitor(Performance.OBJECT_COUNT),
	}
	DirAccess.make_dir_recursive_absolute("user://bench")
	var path: String = "user://bench/bench_%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("BENCH ", JSON.stringify(report))
	print("BENCH arquivo: ", ProjectSettings.globalize_path(path))
	get_tree().quit(0)


static func _mean(a: PackedFloat32Array) -> float:
	var t: float = 0.0
	for v: float in a:
		t += v
	return t / maxf(a.size(), 1)


static func _max(a: PackedFloat32Array) -> float:
	var m: float = 0.0
	for v: float in a:
		m = maxf(m, v)
	return m


static func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback
