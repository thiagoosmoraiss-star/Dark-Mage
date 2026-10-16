extends Node
## Geradores aleatórios determinísticos, um fluxo por sistema (mundo, loot...).
## Efeitos visuais podem usar randf() comum; tudo que afeta o mundo ou o save
## precisa passar por aqui.

## Seed oficial da ilha. Documentada em DESIGN.md e DECISIONS.md.
const WORLD_SEED: int = 20261016

var world_seed: int = WORLD_SEED
var _streams: Dictionary[String, RandomNumberGenerator] = {}


func _ready() -> void:
	var override: String = _cmdline_value("--seed")
	if override.is_valid_int():
		world_seed = override.to_int()


## Retorna o gerador do sistema `stream`, criando-o na primeira chamada.
func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		_streams[stream_name] = make_rng(world_seed, stream_name)
	return _streams[stream_name]


## Recria todos os fluxos com uma seed nova (usado por testes e por "novo jogo").
func reseed(new_seed: int) -> void:
	world_seed = new_seed
	_streams.clear()


static func make_rng(seed_value: int, stream_name: String) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = StableHash.derive_seed(seed_value, stream_name)
	rng.state = rng.seed  # garante o mesmo ponto de partida em qualquer versão
	return rng


static func _cmdline_value(key: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			return arg.substr(key.length() + 1)
	return ""
