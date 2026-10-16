class_name InteriorEntrance
extends Interactable
## Entrada de santuário (arco de pedra com véu violeta) ou de covil (portão
## sombrio entre rochas). Interagir leva para a cena interna.

enum Kind { SHRINE, LAIR, EXIT }

@export var kind: Kind = Kind.SHRINE
@export var region: StringName = &"valley"
@export var archetype: int = 0

var _veil_mat: StandardMaterial3D


func _ready() -> void:
	super._ready()
	interact_range = 3.2
	match kind:
		Kind.SHRINE:
			prompt_key = "INTERACT_SHRINE"
			_build_shrine_gate()
		Kind.LAIR:
			prompt_key = "INTERACT_LAIR"
			_build_lair_gate()
		Kind.EXIT:
			prompt_key = "INTERACT_EXIT"
			_build_exit_portal()


func get_class_tag() -> String:
	return ["shrine", "lair", "exit"][kind]


func interact_point() -> Vector3:
	return global_position + Vector3.UP * 1.0


func prompt_text() -> String:
	if kind == Kind.SHRINE and GameState.has_flag("shrine_done:" + poi_id):
		return tr("INTERACT_SHRINE_DONE")
	if kind == Kind.LAIR and GameState.has_flag("guardian:" + String(region)):
		return tr("INTERACT_LAIR_DONE")
	return tr(prompt_key)


func interact(_player: Player) -> void:
	var mgr: InteriorManager = get_tree().get_first_node_in_group(&"interiors") as InteriorManager
	if mgr == null:
		return
	match kind:
		Kind.SHRINE:
			Audio.play(&"ui_open", global_position)
			mgr.enter("shrine:" + poi_id, func(parent: Node3D, origin: Vector3) -> Node3D:
				return Shrine.build(parent, origin, poi_id, region, archetype), self)
		Kind.LAIR:
			Audio.play(&"beacon", global_position, -10.0)
			mgr.enter("lair:" + poi_id, func(parent: Node3D, origin: Vector3) -> Node3D:
				return Lair.build(parent, origin, poi_id, region), self)
		Kind.EXIT:
			mgr.exit_interior()


func _gate_material(color: Color) -> StandardMaterial3D:
	_veil_mat = StandardMaterial3D.new()
	_veil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_veil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_veil_mat.albedo_color = Color(color, 0.55)
	_veil_mat.emission_enabled = true
	_veil_mat.emission = color
	_veil_mat.emission_energy_multiplier = 2.0
	_veil_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _veil_mat


func _veil(size: Vector2, y: float, color: Color) -> void:
	var q: QuadMesh = QuadMesh.new()
	q.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _gate_material(color)
	mi.position = Vector3(0, y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.4
	light.omni_range = 7.0
	light.position = Vector3(0, y, 0.6)
	add_child(light)


func _build_shrine_gate() -> void:
	var mat: ShaderMaterial = RuinBuilder.stone_material(0.45, GameState.corruption(region))
	var body: StaticBody3D = StaticBody3D.new()
	add_child(body)
	for side: float in [-1.0, 1.0]:
		for k: int in 3:
			var b: MeshInstance3D = MeshInstance3D.new()
			b.mesh = StoneMesh.block(Vector3(1.0, 1.1, 1.0), k, 0.4, 5)
			b.material_override = mat
			b.position = Vector3(side * 1.6, 0.55 + k * 1.12, 0)
			add_child(b)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(1.0, 3.4, 1.0)
		cs.shape = box
		cs.position = Vector3(side * 1.6, 1.7, 0)
		body.add_child(cs)
	var lintel: MeshInstance3D = MeshInstance3D.new()
	lintel.mesh = StoneMesh.block(Vector3(4.4, 0.8, 1.2), 7, 0.4, 6)
	lintel.material_override = mat
	lintel.position = Vector3(0, 3.75, 0)
	add_child(lintel)
	var crystal: MeshInstance3D = MeshInstance3D.new()
	crystal.mesh = MageLook.crystal_mesh(0.18, 0.6, 6)
	crystal.material_override = MageLook.crystal_material()
	crystal.position = Vector3(0, 4.55, 0)
	add_child(crystal)
	_veil(Vector2(2.2, 3.2), 1.6, Color("b67cff"))


func _build_lair_gate() -> void:
	var mat: ShaderMaterial = Materials.rock(0.2, GameState.corruption(region))
	for i: int in 5:
		var a: float = PI * (float(i) / 4.0)
		var r: MeshInstance3D = MeshInstance3D.new()
		r.mesh = RockMesh.build(500 + i, Vector3(3.0, 3.5, 2.6), 3, 0.3)
		r.material_override = mat
		r.position = Vector3(-cos(a) * 4.2, sin(a) * 3.6 + 0.4, -0.8)
		add_child(r)
	var body: StaticBody3D = StaticBody3D.new()
	add_child(body)
	for side: float in [-1.0, 1.0]:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(2.6, 5.0, 2.6)
		cs.shape = box
		cs.position = Vector3(side * 4.0, 2.5, -0.8)
		body.add_child(cs)
	for side: float in [-1.0, 1.0]:
		var s: Node3D = (load("res://assets/models/props/kaykit_halloween/post_skull.gltf") as PackedScene).instantiate()
		s.position = Vector3(side * 2.6, 0, 1.4)
		add_child(s)
	_veil(Vector2(4.6, 4.2), 2.1, Color("6b2fd6"))


func _build_exit_portal() -> void:
	var gold: StandardMaterial3D = StandardMaterial3D.new()
	gold.albedo_color = Color("c99a3f")
	gold.metallic = 0.8
	gold.roughness = 0.35
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = StoneMesh.drum(1.3, 0.3, 11, 20)
	ring.material_override = gold
	ring.position.y = 0.15
	add_child(ring)
	_veil(Vector2(2.0, 3.0), 1.7, Color("e8b44c"))
