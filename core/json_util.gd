class_name JsonUtil
extends RefCounted
## Leitura tipada de valores vindos de JSON ou Dictionary sem tipo.


static func num(v: Variant, fallback: float = 0.0) -> float:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			return f
		TYPE_INT:
			var i: int = v
			return float(i)
	return fallback


static func get_f(d: Dictionary, key: Variant, fallback: float = 0.0) -> float:
	return num(d.get(key), fallback)


static func get_i(d: Dictionary, key: Variant, fallback: int = 0) -> int:
	return roundi(num(d.get(key), float(fallback)))


static func get_s(d: Dictionary, key: Variant, fallback: String = "") -> String:
	var v: Variant = d.get(key)
	return v if v is String else fallback


static func vec3(v: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if v is Array:
		var a: Array = v
		if a.size() >= 3:
			return Vector3(num(a[0]), num(a[1]), num(a[2]))
	elif v is Vector3:
		return v
	return fallback
