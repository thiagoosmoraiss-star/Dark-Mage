class_name FrameStats
extends RefCounted
## Janela deslizante de tempos de frame (ms) com média e percentis.
## Sem alocação por frame: o buffer é fixo e o ordenado é reaproveitado.

var _samples: PackedFloat32Array
var _sorted: PackedFloat32Array
var _count: int = 0
var _head: int = 0


func _init(capacity: int = 240) -> void:
	_samples.resize(maxi(capacity, 1))
	_sorted.resize(maxi(capacity, 1))


func push(ms: float) -> void:
	_samples[_head] = ms
	_head = (_head + 1) % _samples.size()
	_count = mini(_count + 1, _samples.size())


func count() -> int:
	return _count


func average() -> float:
	if _count == 0:
		return 0.0
	var total: float = 0.0
	for i: int in _count:
		total += _samples[i]
	return total / _count


## Percentil pelo método "nearest rank" (p em 0..100).
func percentile(p: float) -> float:
	if _count == 0:
		return 0.0
	_sorted.resize(_count)
	for i: int in _count:
		_sorted[i] = _samples[i]
	_sorted.sort()
	var rank: int = clampi(ceili(p / 100.0 * _count), 1, _count)
	return _sorted[rank - 1]
