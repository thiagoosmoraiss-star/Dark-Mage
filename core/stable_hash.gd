class_name StableHash
extends RefCounted
## Hashes estáveis entre plataformas e versões do Godot (FNV-1a 32 bits).
## Usados para derivar seeds e para comparar dados gerados (ex.: heightmap).

const FNV_OFFSET: int = 0x811C9DC5
const FNV_PRIME: int = 0x01000193
const MASK32: int = 0xFFFFFFFF


static func fnv1a_bytes(data: PackedByteArray, seed_value: int = FNV_OFFSET) -> int:
	var h: int = seed_value & MASK32
	for b: int in data:
		h = ((h ^ b) * FNV_PRIME) & MASK32
	return h


static func fnv1a_string(text: String, seed_value: int = FNV_OFFSET) -> int:
	return fnv1a_bytes(text.to_utf8_buffer(), seed_value)


## Hash de um array de floats (por exemplo, amostras de altura). Quantiza em
## milímetros para ignorar ruído de ponto flutuante abaixo da tolerância.
static func fnv1a_floats(values: PackedFloat32Array, seed_value: int = FNV_OFFSET) -> int:
	var h: int = seed_value & MASK32
	for v: float in values:
		var q: int = roundi(v * 1000.0)
		for shift: int in [0, 8, 16, 24]:
			h = ((h ^ ((q >> shift) & 0xFF)) * FNV_PRIME) & MASK32
	return h


## Combina a seed do mundo com o nome de um sistema, gerando a seed daquele fluxo.
static func derive_seed(world_seed: int, stream: String) -> int:
	var base: int = fnv1a_string(str(world_seed))
	return fnv1a_string(stream, base)
