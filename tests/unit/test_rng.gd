extends GdUnitTestSuite
## RNG com seed: mesmo seed e mesmo fluxo geram a mesma sequência; fluxos diferem.


func _sequence(rng: RandomNumberGenerator, n: int) -> Array:
	var out: Array = []
	for i: int in n:
		out.append(rng.randi())
	return out


func test_same_seed_same_sequence() -> void:
	var a: RandomNumberGenerator = Rng.make_rng(1234, "world")
	var b: RandomNumberGenerator = Rng.make_rng(1234, "world")
	assert_array(_sequence(a, 64)).is_equal(_sequence(b, 64))


func test_streams_are_independent() -> void:
	var a: RandomNumberGenerator = Rng.make_rng(1234, "world")
	var b: RandomNumberGenerator = Rng.make_rng(1234, "loot")
	assert_array(_sequence(a, 16)).is_not_equal(_sequence(b, 16))


func test_different_seed_differs() -> void:
	var a: RandomNumberGenerator = Rng.make_rng(1, "world")
	var b: RandomNumberGenerator = Rng.make_rng(2, "world")
	assert_array(_sequence(a, 16)).is_not_equal(_sequence(b, 16))


## Valores de referência do FNV-1a 32 bits: se mudarem, a geração do mundo mudou.
func test_known_hash_values() -> void:
	assert_int(StableHash.fnv1a_string("")).is_equal(0x811C9DC5)
	assert_int(StableHash.fnv1a_string("a")).is_equal(0xE40C292C)
	assert_int(StableHash.fnv1a_string("foobar")).is_equal(0xBF9CF968)


func test_autoload_stream_is_reseedable() -> void:
	var old_seed: int = Rng.world_seed
	Rng.reseed(77)
	var first: int = Rng.stream("test").randi()
	Rng.reseed(77)
	assert_int(Rng.stream("test").randi()).is_equal(first)
	Rng.reseed(old_seed)


func test_float_hash_quantizes_noise() -> void:
	var a: PackedFloat32Array = [1.0, 2.5, -3.25]
	var b: PackedFloat32Array = [1.0000001, 2.5000002, -3.2500001]
	var c: PackedFloat32Array = [1.0, 2.5, -3.26]
	assert_int(StableHash.fnv1a_floats(a)).is_equal(StableHash.fnv1a_floats(b))
	assert_int(StableHash.fnv1a_floats(a)).is_not_equal(StableHash.fnv1a_floats(c))
