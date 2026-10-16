extends SceneTree
## Teste de vazamento (seção 16): carrega a ilha, o jogador anda em círculos,
## pula, esquiva e conjura os 4 feitiços sem parar por N segundos; mede objetos,
## nós, órfãos e memória estática a cada 30 s. Reprova se, depois do aquecimento
## (60 s), os nós crescerem mais de 3% ou a memória estática mais de 10%.
## Uso: tools/run.sh res://tools/soak.gd -- --seconds=600

const WARMUP: float = 60.0
const SAMPLE: float = 30.0

var _world: Node
var _player: Node
var _t: float = 0.0
var _next_sample: float = 0.0
var _seconds: float = 600.0
var _samples: Array[Dictionary] = []
var _casts: int = 0
var _cast_t: float = 0.0
var _slot: int = 0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seconds="):
			_seconds = a.substr(10).to_float()
	_world = (load("res://levels/island/island.tscn") as PackedScene).instantiate()
	root.add_child(_world)


func _process(delta: float) -> bool:
	_t += delta
	if _player == null:
		_player = _world.get(&"player")
		if _player == null:
			return false
		_player.set(&"use_scripted_input", true)
		_player.set(&"god_mode", true)
	_drive(delta)
	if _t >= _next_sample:
		_next_sample += SAMPLE
		_samples.append({
			"t": roundi(_t), "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "casts": _casts,
		})
		print("soak ", JSON.stringify(_samples.back()))
	if _t >= _seconds:
		_finish()
		return true
	return false


## Anda em círculo, pula e esquiva de vez em quando, conjura a cada 0,6 s.
func _drive(delta: float) -> void:
	var input: Dictionary = _player.get(&"scripted_input")
	var phase: int = int(_t / 3.0) % 4
	input[&"move_forward"] = true
	input[&"move_left"] = phase == 1
	input[&"move_right"] = phase == 3
	input[&"jump"] = fmod(_t, 7.0) < 0.1
	input[&"dodge"] = fmod(_t, 11.0) < 0.1
	input[&"attack"] = fmod(_t, 2.0) < 0.5
	_cast_t -= delta
	for i: int in 4:
		input[StringName("spell_%d" % (i + 1))] = false
	if _cast_t <= 0.0:
		_cast_t = 0.6
		var caster: Node = _player.get(&"caster")
		var stats: Object = _player.get(&"stats")
		stats.call(&"set_mana", 9999.0)
		(caster.get(&"cooldowns") as RefCounted).call(&"reset")
		if caster.call(&"cast_slot", _slot):
			_casts += 1
		_slot = (_slot + 1) % 4
	_player.set(&"scripted_input", input)


func _finish() -> void:
	var base: Dictionary = {}
	for s: Dictionary in _samples:
		if JsonUtil.num(s["t"]) >= WARMUP:
			base = s
			break
	var last: Dictionary = _samples.back()
	var ok: bool = not base.is_empty()
	var node_growth: float = 0.0
	var mem_growth: float = 0.0
	if ok:
		node_growth = (JsonUtil.num(last["nodes"]) - JsonUtil.num(base["nodes"])) / maxf(JsonUtil.num(base["nodes"]), 1.0)
		mem_growth = (JsonUtil.num(last["static_mb"]) - JsonUtil.num(base["static_mb"])) / maxf(JsonUtil.num(base["static_mb"]), 1.0)
		ok = node_growth <= 0.03 and mem_growth <= 0.10 and JsonUtil.num(last["orphans"]) <= JsonUtil.num(base["orphans"]) + 5
	print("soak RESULTADO: %s — %d s, %d conjurações, nós %+.1f%%, memória estática %+.1f%%" % [
		"APROVADO" if ok else "REPROVADO", roundi(_t), _casts, node_growth * 100.0, mem_growth * 100.0])
	quit(0 if ok else 1)
