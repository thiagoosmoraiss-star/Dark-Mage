class_name HitStop
extends RefCounted
## Pausa curta de impacto (40–80 ms) e câmera lenta (esquiva perfeita), usando
## Engine.time_scale com temporizador em tempo real. Pedidos sobrepostos ficam
## com o mais forte; nunca deixa o jogo preso em câmera lenta.

static var _until_ms: int = 0
static var _scale: float = 1.0
static var _timer_running: bool = false


static func hit(tree: SceneTree, duration_ms: int = 60, time_scale: float = 0.05) -> void:
	_request(tree, duration_ms, time_scale)


static func slow_motion(tree: SceneTree, duration_ms: int = 450, time_scale: float = 0.35) -> void:
	_request(tree, duration_ms, time_scale)


static func _request(tree: SceneTree, duration_ms: int, time_scale: float) -> void:
	if tree == null or tree.paused:
		return
	var now: int = Time.get_ticks_msec()
	var until: int = now + duration_ms
	if now < _until_ms and time_scale > _scale:
		return  # já há um efeito mais forte em andamento
	_until_ms = maxi(_until_ms, until)
	_scale = time_scale
	Engine.time_scale = time_scale
	if not _timer_running:
		_timer_running = true
		_wait(tree)


static func _wait(tree: SceneTree) -> void:
	while Time.get_ticks_msec() < _until_ms:
		await tree.create_timer(0.016, true, false, true).timeout
	Engine.time_scale = 1.0
	_scale = 1.0
	_timer_running = false


static func reset() -> void:
	_until_ms = 0
	_scale = 1.0
	Engine.time_scale = 1.0
