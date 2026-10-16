extends GdUnitTestSuite
## Gerador da ilha: determinismo por seed e composição autoral.

const L = preload("res://world/island/island_layout.gd")


func test_same_seed_same_hash() -> void:
	var a: IslandGenerator = IslandGenerator.new(20261016, 96)
	a.generate()
	var b: IslandGenerator = IslandGenerator.new(20261016, 96)
	b.generate()
	assert_int(a.height_hash()).is_equal(b.height_hash())
	assert_array(Array(a.region_ids)).is_equal(Array(b.region_ids))


func test_different_seed_differs() -> void:
	var a: IslandGenerator = IslandGenerator.new(1, 64)
	a.generate()
	var b: IslandGenerator = IslandGenerator.new(2, 64)
	b.generate()
	assert_int(a.height_hash()).is_not_equal(b.height_hash())


func test_composition() -> void:
	var g: IslandGenerator = IslandGenerator.new(20261016, 64)
	# Cidadela num platô alto e plano.
	var c: Vector2 = L.CITADEL_CENTER
	assert_float(g.height_at(c.x, c.y)).is_between(100.0, 115.0)
	assert_float(absf(g.height_at(c.x + 30.0, c.y) - g.height_at(c.x - 30.0, c.y))).is_less(4.0)
	# Mar aberto nos cantos do mundo.
	assert_float(g.height_at(-1000.0, -1000.0)).is_less(-10.0)
	assert_float(g.height_at(1000.0, 1000.0)).is_less(-10.0)
	# Vale no centro: terra firme, sem montanhas.
	assert_float(g.height_at(0.0, 100.0)).is_between(3.0, 50.0)
	# Pântano baixo, perto do nível do mar.
	var s: Vector2 = L.REGION_CENTERS[L.Region.SWAMP]
	assert_float(g.height_at(s.x, s.y)).is_between(-3.0, 4.0)
	# Vulcão alto e com cratera.
	var v: Vector2 = L.VOLCANO_CENTER
	var rim: float = g.height_at(v.x + L.CRATER_RADIUS, v.y)
	assert_float(rim).is_greater(120.0)
	assert_float(g.height_at(v.x, v.y)).is_less(rim)


func test_peaks_highest_and_swamp_low() -> void:
	var g: IslandGenerator = IslandGenerator.new(20261016, 128)
	g.generate()
	var max_by_region: Dictionary = {}
	var swamp: PackedFloat32Array = []
	for i: int in g.heights.size():
		var r: int = g.region_ids[i]
		max_by_region[r] = maxf(JsonUtil.num(max_by_region.get(r, -999.0)), g.heights[i])
		if r == L.Region.SWAMP:
			swamp.append(g.heights[i])
	swamp.sort()
	var swamp_median: float = swamp[swamp.size() / 2]
	assert_float(JsonUtil.num(max_by_region[L.Region.PEAKS])).is_greater(170.0)
	for r: int in max_by_region:
		if r != L.Region.PEAKS:
			assert_float(JsonUtil.num(max_by_region[r])).is_less(JsonUtil.num(max_by_region[L.Region.PEAKS]))
	# Pântano: miolo perto do nível do mar.
	assert_float(swamp_median).is_less(6.0)


func test_control_encoding_matches_terrain3d() -> void:
	var g: IslandGenerator = IslandGenerator.new(20261016, 32)
	g.generate()
	var img: Image = g.control_image(func(b: int, o: int, bl: int) -> int:
		return Terrain3DUtil.enc_base(b) | Terrain3DUtil.enc_overlay(o) | Terrain3DUtil.enc_blend(bl))
	var px: float = img.get_pixel(16, 16).r
	var bits: int = Terrain3DUtil.as_uint(px)
	assert_int(Terrain3DUtil.get_base(bits)).is_between(0, 7)
	assert_int(Terrain3DUtil.get_overlay(bits)).is_between(0, 7)
