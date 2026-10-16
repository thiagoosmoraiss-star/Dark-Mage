class_name NavBaker
extends NavigationRegion3D
## Malha de navegação assada em tempo de execução ao redor do jogador (célula de
## BAKE_SIZE m), em thread, a partir do Terrain3D e dos colisores estáticos
## próximos (troncos e rochas). Re-assa quando o jogador se afasta do centro.

const BAKE_SIZE: float = 140.0
const REBAKE_DISTANCE: float = 45.0

var terrain: IslandTerrain
var baking: bool = false
var bake_count: int = 0
var _center: Vector3 = Vector3(INF, 0, INF)


func _ready() -> void:
	add_to_group(&"nav_baker")
	var nm: NavigationMesh = NavigationMesh.new()
	nm.cell_size = 0.5
	nm.cell_height = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 42.0
	nm.region_min_size = 4.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	navigation_mesh = nm
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, 0.5)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, 0.25)


func _process(_delta: float) -> void:
	if baking or terrain == null:
		return
	var focus: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if focus == null:
		return
	var p: Vector3 = focus.global_position
	if Vector2(p.x - _center.x, p.z - _center.z).length() < REBAKE_DISTANCE:
		return
	bake_around(p)


func bake_around(p: Vector3) -> void:
	baking = true
	_center = p
	var half: float = BAKE_SIZE * 0.5
	var aabb: AABB = AABB(Vector3(p.x - half, p.y - 120.0, p.z - half), Vector3(BAKE_SIZE, 240.0, BAKE_SIZE))
	navigation_mesh.filter_baking_aabb = aabb
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	var mgr: InteriorManager = get_tree().get_first_node_in_group(&"interiors") as InteriorManager
	if mgr != null and mgr.is_inside():
		# Dentro de santuários/covis: a malha vem dos colisores da sala.
		var room: Node = mgr.interior(mgr.current_id)
		if room != null:
			NavigationServer3D.parse_source_geometry_data(navigation_mesh, src, room)
	else:
		var faces: PackedVector3Array = terrain.terrain.generate_nav_mesh_source_geometry(aabb, false)
		if not faces.is_empty():
			src.add_faces(faces, Transform3D.IDENTITY)
	# Colisores estáticos próximos (troncos, rochas, ruínas) viram obstáculos.
	var veg: Node = get_tree().get_first_node_in_group(&"vegetation")
	if veg != null:
		NavigationServer3D.parse_source_geometry_data(navigation_mesh, src, veg)
	for s: Node in get_tree().get_nodes_in_group(&"structure"):
		NavigationServer3D.parse_source_geometry_data(navigation_mesh, src, s)
	NavigationServer3D.bake_from_source_geometry_data_async(navigation_mesh, src, _on_baked)


func _on_baked() -> void:
	# O NavigationMesh foi atualizado na thread; reatribuir aplica no servidor.
	var nm: NavigationMesh = navigation_mesh
	navigation_mesh = nm
	baking = false
	bake_count += 1
