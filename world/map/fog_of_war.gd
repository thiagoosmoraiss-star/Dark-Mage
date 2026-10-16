class_name FogOfWar
extends RefCounted
## Névoa de guerra do mapa: máscara 256² (8 m por texel) revelada ao explorar
## e pelos faróis. Serializa para o save (comprimida, base64).

const L = preload("res://world/island/island_layout.gd")
const SIZE: int = 256
const TEXEL: float = L.WORLD_SIZE / SIZE

var mask: PackedByteArray
var _dirty: bool = true
var _image: Image


func _init() -> void:
	mask = PackedByteArray()
	mask.resize(SIZE * SIZE)
	mask.fill(0)


## Revela um círculo (bordas suaves) ao redor de `pos`, em metros.
func reveal(pos: Vector3, radius: float) -> void:
	var cx: float = (pos.x + L.HALF) / TEXEL
	var cz: float = (pos.z + L.HALF) / TEXEL
	var r: float = radius / TEXEL
	var x0: int = maxi(0, floori(cx - r))
	var x1: int = mini(SIZE - 1, ceili(cx + r))
	var z0: int = maxi(0, floori(cz - r))
	var z1: int = mini(SIZE - 1, ceili(cz + r))
	for z: int in range(z0, z1 + 1):
		for x: int in range(x0, x1 + 1):
			var d: float = Vector2(x + 0.5 - cx, z + 0.5 - cz).length() / r
			if d >= 1.0:
				continue
			var v: int = roundi(clampf((1.0 - d) * 3.0, 0.0, 1.0) * 255.0)
			var i: int = z * SIZE + x
			if v > mask[i]:
				mask[i] = v
				_dirty = true


func is_revealed(pos: Vector3) -> bool:
	var x: int = clampi(floori((pos.x + L.HALF) / TEXEL), 0, SIZE - 1)
	var z: int = clampi(floori((pos.z + L.HALF) / TEXEL), 0, SIZE - 1)
	return mask[z * SIZE + x] > 127


## Fração da ilha revelada (0..1), só contando texels de terra (aproximação: todos).
func revealed_fraction() -> float:
	var n: int = 0
	for v: int in mask:
		if v > 127:
			n += 1
	return float(n) / mask.size()


func image() -> Image:
	if _dirty or _image == null:
		_image = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_L8, mask)
		_dirty = false
	return _image


func to_save() -> String:
	return Marshalls.raw_to_base64(mask.compress(FileAccess.COMPRESSION_ZSTD))


func from_save(text: String) -> bool:
	if text.is_empty():
		return false
	var raw: PackedByteArray = Marshalls.base64_to_raw(text)
	var data: PackedByteArray = raw.decompress(SIZE * SIZE, FileAccess.COMPRESSION_ZSTD)
	if data.size() != SIZE * SIZE:
		return false
	mask = data
	_dirty = true
	return true
