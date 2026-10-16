class_name WaterBody
extends MeshInstance3D
## Lago ou poça retangular com superfície própria (o mar fica no Ocean).
## O jogador consulta surface_at() para saber se está nadando.

@export var size: Vector2 = Vector2(20.0, 20.0)
@export var depth: float = 3.0


func _ready() -> void:
	add_to_group(&"water_body")
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = maxi(1, int(size.x / 2.0))
	plane.subdivide_depth = maxi(1, int(size.y / 2.0))
	mesh = plane
	var mat: ShaderMaterial = Ocean.make_material()
	mat.set_shader_parameter(&"wave_scale", 0.15)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Altura da superfície em `pos`, ou -INF se fora do lago.
func surface_at(pos: Vector3) -> float:
	var local: Vector3 = global_transform.affine_inverse() * pos
	if absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.y * 0.5 and local.y > -depth - 2.0:
		return global_position.y
	return -INF
