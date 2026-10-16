extends GdUnitTestSuite
## Ciclo de dia e noite: paleta contínua, sol e lua coerentes com o horário.


func test_sun_is_up_at_noon_and_down_at_midnight() -> void:
	assert_float(DayNightPalette.sun_direction(12.0).y).is_greater(0.8)
	assert_float(DayNightPalette.sun_direction(0.0).y).is_less(-0.8)
	assert_float(absf(DayNightPalette.sun_direction(6.0).y)).is_less(0.01)
	assert_float(absf(DayNightPalette.sun_direction(18.0).y)).is_less(0.01)


func test_sun_rises_east_sets_west() -> void:
	assert_float(DayNightPalette.sun_direction(6.0).x).is_greater(0.9)
	assert_float(DayNightPalette.sun_direction(18.0).x).is_less(-0.9)


func test_moon_is_up_at_night() -> void:
	assert_float(DayNightPalette.moon_direction(0.5).y).is_greater(0.5)


func test_palette_is_continuous_and_cyclic() -> void:
	var prev: Dictionary = DayNightPalette.sample(0.0)
	var h: float = 0.05
	while h <= 24.0:
		var cur: Dictionary = DayNightPalette.sample(h)
		var dz: float = (cur["zenith"] as Color).srgb_to_linear().get_luminance() - (prev["zenith"] as Color).srgb_to_linear().get_luminance()
		assert_float(absf(dz)).override_failure_message("salto de cor às %.2fh" % h).is_less(0.05)
		assert_float(absf(JsonUtil.num(cur["sun_energy"]) - JsonUtil.num(prev["sun_energy"]))).is_less(0.12)
		prev = cur
		h += 0.05
	var a: Dictionary = DayNightPalette.sample(0.0)
	var b: Dictionary = DayNightPalette.sample(24.0)
	assert_bool((a["zenith"] as Color).is_equal_approx(b["zenith"] as Color)).is_true()


func test_day_is_brighter_than_night() -> void:
	assert_float(JsonUtil.num(DayNightPalette.sample(12.0)["sun_energy"])).is_greater(1.0)
	assert_float(JsonUtil.num(DayNightPalette.sample(0.0)["sun_energy"])).is_equal(0.0)
	assert_float(JsonUtil.num(DayNightPalette.sample(0.0)["stars"])).is_greater(0.9)


func test_atmosphere_node_updates_lights() -> void:
	var atmo: Atmosphere = auto_free(Atmosphere.new()) as Atmosphere
	add_child(atmo)
	atmo.running = false
	atmo.set_hours(12.0)
	assert_bool(atmo.sun.visible).is_true()
	assert_float(atmo.sun.light_energy).is_greater(1.0)
	assert_bool(atmo.is_night()).is_false()
	assert_float(-atmo.sun.global_basis.z.y).is_less(-0.8)  # luz aponta para baixo
	atmo.set_hours(0.5)
	assert_bool(atmo.is_night()).is_true()
	assert_float(atmo.night_factor()).is_equal(1.0)
	assert_bool(atmo.sun.visible).is_false()
	assert_bool(atmo.moon.visible).is_true()
	assert_bool(atmo.moon.shadow_enabled).is_true()


func test_time_advances_with_cycle() -> void:
	var atmo: Atmosphere = auto_free(Atmosphere.new()) as Atmosphere
	add_child(atmo)
	atmo.hours = 10.0
	atmo.cycle_minutes = 24.0
	atmo._process(60.0)  # 1 minuto real = 1 hora de jogo
	assert_float(atmo.hours).is_equal_approx(11.0, 0.001)


func test_color_grading_neutral_is_identity() -> void:
	var c: Color = Color(0.3, 0.6, 0.2)
	assert_bool(ColorGrading.grade(c, ColorGrading.NEUTRAL).is_equal_approx(c)).is_true()
	var lut: ImageTexture3D = ColorGrading.lut_for(&"corrupted")
	assert_int(lut.get_depth()).is_equal(ColorGrading.SIZE)
