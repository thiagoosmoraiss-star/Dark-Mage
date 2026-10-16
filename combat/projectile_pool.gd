class_name ProjectilePool
extends Node3D
## Pool de projéteis do mundo (grupo "projectile_pool").

const SIZE: int = 48

var _free: Array[Projectile] = []
var _all: Array[Projectile] = []


static func get_for(n: Node) -> ProjectilePool:
	return n.get_tree().get_first_node_in_group(&"projectile_pool") as ProjectilePool


func _ready() -> void:
	add_to_group(&"projectile_pool")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for i: int in SIZE:
		var p: Projectile = Projectile.new()
		p.finished.connect(_on_finished)
		add_child(p)
		_all.append(p)
		_free.append(p)


## Retorna um projétil livre (ou recicla o mais antigo em uso).
func take() -> Projectile:
	if _free.is_empty():
		var oldest: Projectile = _all[0]
		_all.erase(oldest)
		_all.append(oldest)
		oldest._finish(false)
	var p: Projectile = _free.pop_back()
	_all.erase(p)
	_all.append(p)
	p.gravity = 0.0
	p.splash_radius = 0.0
	p.impact_scale = 1.0
	p.max_distance = 60.0
	p.exclude.clear()
	return p


func _on_finished(p: Projectile) -> void:
	if not _free.has(p):
		_free.append(p)


func active_count() -> int:
	return SIZE - _free.size()
