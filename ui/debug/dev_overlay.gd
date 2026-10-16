extends CanvasLayer
## Overlay de desenvolvedor (F3). Só existe em build de debug ou com `--dev`.

const REFRESH_S: float = 0.25

var _stats: FrameStats = FrameStats.new(240)
var _label: Label
var _panel: PanelContainer
var _accum: float = 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Game.dev_mode:
		set_process(false)
		set_process_unhandled_input(false)
		return
	_build_ui()
	_panel.visible = Game.has_arg("--overlay")


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.043, 0.035, 0.063, 0.78)  # #0B0910 translúcido
	box.border_color = Color(0.91, 0.706, 0.298, 0.9)  # #E8B44C
	box.set_border_width_all(1)
	box.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", box)
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	_label.add_theme_font_size_override("font_size", 13)
	_panel.add_child(_label)
	add_child(_panel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		_panel.visible = not _panel.visible
		Events.dev_overlay_toggled.emit(_panel.visible)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_stats.push(delta * 1000.0)
	_accum += delta
	if _accum < REFRESH_S or not _panel.visible:
		return
	_accum = 0.0
	_label.text = _compose_text()


func _compose_text() -> String:
	var lines: PackedStringArray = []
	lines.append("FPS %d   frame %.2f ms   P95 %.2f   P99 %.2f" % [
		Engine.get_frames_per_second(), _stats.average(), _stats.percentile(95.0), _stats.percentile(99.0)])
	lines.append("draw calls %d   primitivas %d   objetos %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	lines.append("VRAM %.1f MB   RAM estática %.1f MB   nós %d   recursos %d" % [
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	lines.append("GPU %s (%s)   preset %s" % [
		RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name(),
		Settings.current_preset()])
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		var p: Vector3 = cam.global_position
		lines.append("câmera %.1f, %.1f, %.1f   célula %s   região -" % [
			p.x, p.y, p.z, Vector2i(floori(p.x / 128.0), floori(p.z / 128.0))])
	return "\n".join(lines)
