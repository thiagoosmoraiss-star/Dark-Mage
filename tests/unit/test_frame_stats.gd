extends GdUnitTestSuite


func test_average_and_percentiles() -> void:
	var s: FrameStats = FrameStats.new(100)
	for i: int in range(1, 101):
		s.push(float(i))
	assert_float(s.average()).is_equal_approx(50.5, 0.0001)
	assert_float(s.percentile(95.0)).is_equal(95.0)
	assert_float(s.percentile(99.0)).is_equal(99.0)
	assert_float(s.percentile(100.0)).is_equal(100.0)


func test_window_slides() -> void:
	var s: FrameStats = FrameStats.new(4)
	for v: float in [100.0, 100.0, 1.0, 1.0, 1.0, 1.0]:
		s.push(v)
	assert_int(s.count()).is_equal(4)
	assert_float(s.average()).is_equal(1.0)


func test_empty_is_zero() -> void:
	var s: FrameStats = FrameStats.new(8)
	assert_float(s.average()).is_equal(0.0)
	assert_float(s.percentile(99.0)).is_equal(0.0)
