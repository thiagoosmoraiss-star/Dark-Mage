class_name Beacon
extends Interactable
## Farol Arcano no topo da torre: ao ser aceso revela a região no mapa, purifica
## parte da corrupção e vira um marco dourado visível de longe (feixe de luz).

const REVEAL_RADIUS: float = 420.0

@export var region: StringName = &"valley"

var lit: bool = false
var _crystal: MeshInstance3D
var _crystal_mat: StandardMaterial3D
var _light: OmniLight3D
var _beam: MeshInstance3D
var _t: float = 0.0


func _ready() -> void:
	super._ready()
	prompt_key = "INTERACT_BEACON"
	interact_range = 3.4
	_build()
	_apply(GameState.has_flag(flag_key()), false)


func get_class_tag() -> String:
	return "beacon"


func can_interact(_player: Player) -> bool:
	return not lit


func interact(player: Player) -> void:
	if lit:
		return
	_apply(true, true)
	GameState.set_flag(flag_key())
	GameState.purify(region, 0.35)
	var world: IslandWorld = player.get_tree().get_first_node_in_group(&"world") as IslandWorld
	if world != null:
		world.fog.reveal(global_position, REVEAL_RADIUS)
	Audio.play(&"beacon", global_position)
	Audio.play(&"boom", global_position, -8.0)
	var vfx: Vfx = Vfx.get_for(self)
	if vfx != null:
		vfx.shockwave(global_position, 14.0, Color("e8b44c"), 1.0)
		vfx.impact(global_position + Vector3.UP * 1.5, Color("e8b44c"), 2.5, 64)
	var hud: Hud = player.get_tree().get_first_node_in_group(&"hud") as Hud
	if hud != null:
		hud.show_banner(tr("BEACON_LIT"), tr("REGION_" + String(region).to_upper()))


func _apply(on: bool, animate: bool) -> void:
	lit = on
	var col: Color = Color("ffd27a") if on else Color("6b2fd6")
	_crystal_mat.albedo_color = col
	_crystal_mat.emission = col
	_crystal_mat.emission_energy_multiplier = 6.0 if on else 1.2
	_light.light_color = col
	_beam.visible = on
	if animate:
		_light.light_energy = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(_light, "light_energy", 6.0, 1.5)
	else:
		_light.light_energy = 6.0 if on else 0.6
	_light.omni_range = 45.0 if on else 6.0


func _process(delta: float) -> void:
	_t += delta
	_crystal.rotation.y += delta * (0.6 if lit else 0.15)
	_crystal.position.y = 2.1 + sin(_t * 1.3) * 0.12


func _build() -> void:
	var gold: StandardMaterial3D = StandardMaterial3D.new()
	gold.albedo_color = Color("c99a3f")
	gold.metallic = 0.85
	gold.roughness = 0.35
	var brazier: MeshInstance3D = MeshInstance3D.new()
	brazier.mesh = StoneMesh.drum(1.1, 0.5, 8, 16)
	brazier.material_override = gold
	brazier.position.y = 0.25
	add_child(brazier)
	for i: int in 4:
		var a: float = TAU * i / 4.0
		var claw: MeshInstance3D = MeshInstance3D.new()
		claw.mesh = StoneMesh.block(Vector3(0.18, 1.6, 0.18), 1, 0.2, 3)
		claw.material_override = gold
		claw.position = Vector3(cos(a) * 0.95, 1.2, sin(a) * 0.95)
		claw.rotation = Vector3(sin(a) * 0.35, 0.0, -cos(a) * 0.35)
		add_child(claw)
	_crystal = MeshInstance3D.new()
	_crystal.mesh = MageLook.crystal_mesh(0.5, 1.6, 7)
	_crystal_mat = MageLook.crystal_material().duplicate() as StandardMaterial3D
	_crystal.material_override = _crystal_mat
	_crystal.position.y = 2.1
	add_child(_crystal)
	_light = OmniLight3D.new()
	_light.position.y = 2.4
	_light.shadow_enabled = false
	add_child(_light)
	# Feixe vertical (dois quads cruzados aditivos com gradiente).
	_beam = MeshInstance3D.new()
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 2:
		var r: Vector3 = Vector3(cos(k * PI * 0.5), 0.0, sin(k * PI * 0.5)) * 0.9
		var h: float = 90.0
		var pts: Array[Vector3] = [-r, r, r + Vector3.UP * h, -r + Vector3.UP * h]
		var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(1.0, 0.85, 0.5, 1.0 - (pts[idx].y / h)))
			st.set_uv(uvs[idx])
			st.add_vertex(pts[idx])
	_beam.mesh = st.commit()
	var bm: ShaderMaterial = ShaderMaterial.new()
	bm.shader = Vfx.ADDITIVE
	bm.set_shader_parameter(&"radial", false)
	bm.set_shader_parameter(&"energy", 1.4)
	_beam.material_override = bm
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = 2.0
	add_child(_beam)
