class_name LorePoint
extends Interactable
## Mirantes (revelam o mapa ao redor e dão almas) e histórias ambientais
## (altares, túmulos, restos de aventureiros, com texto de lore).

enum Kind { VIEWPOINT, STORY }

const HALLOWEEN: String = "res://assets/models/props/kaykit_halloween/"
const DUNGEON: String = "res://assets/models/props/kaykit_dungeon/"
## Composições das histórias: [arquivo, posição, rotação Y].
const STORY_PROPS: Array[Array] = [
	[["shrine_candles.gltf", Vector3(0, 0, 0), 0.0], ["skull_candle.gltf", Vector3(0.9, 0, 0.4), 0.6], ["bone_A.gltf", Vector3(-0.7, 0, 0.5), 1.2]],
	[["coffin.gltf", Vector3(0, 0, 0), 0.3], ["gravestone.gltf", Vector3(0, 0, -1.4), 0.0], ["candle_triple.gltf", Vector3(1.0, 0, -1.1), 0.0]],
	[["ribcage.gltf", Vector3(0, 0, 0), 0.4], ["skull.gltf", Vector3(0.6, 0, 0.5), 2.0], ["sword_shield_broken.glb", Vector3(-0.8, 0, 0.2), 0.8]],
	[["grave_A.gltf", Vector3(0, 0, 0), 0.0], ["lantern_standing.gltf", Vector3(1.2, 0, 0.3), 0.0], ["gravemarker_A.gltf", Vector3(-1.1, 0, -0.4), 0.3]],
	[["plaque_candles.gltf", Vector3(0, 0, 0), 0.0], ["post_skull.gltf", Vector3(1.3, 0, 0.2), 0.0], ["bone_B.gltf", Vector3(-0.8, 0, 0.6), 0.9]],
]

@export var kind: Kind = Kind.STORY
@export var story_index: int = 0

var _rune_mat: StandardMaterial3D


func _ready() -> void:
	super._ready()
	if kind == Kind.VIEWPOINT:
		prompt_key = "INTERACT_VIEWPOINT"
		_build_viewpoint()
	else:
		prompt_key = "INTERACT_STORY"
		_build_story()
	if kind == Kind.VIEWPOINT and GameState.has_flag(flag_key()):
		_rune_mat.emission_energy_multiplier = 3.5


func get_class_tag() -> String:
	return "viewpoint" if kind == Kind.VIEWPOINT else "story"


func interact(player: Player) -> void:
	var panels: WorldPanels = player.get_tree().get_first_node_in_group(&"world_panels") as WorldPanels
	if kind == Kind.VIEWPOINT:
		var first: bool = not GameState.has_flag(flag_key())
		GameState.set_flag(flag_key())
		var world: IslandWorld = player.get_tree().get_first_node_in_group(&"world") as IslandWorld
		if world != null:
			world.fog.reveal(global_position, 480.0)
		_rune_mat.emission_energy_multiplier = 3.5
		if first:
			GameState.add_souls(25)
			Audio.play(&"beacon", global_position, -6.0)
		if panels != null:
			panels.show_text(tr("VIEWPOINT_TITLE"), tr("VIEWPOINT_BODY"))
	else:
		GameState.set_flag(flag_key())
		if panels != null:
			var n: int = story_index + 1
			panels.show_text(tr("STORY_%d_TITLE" % n), tr("STORY_%d_BODY" % n))


func _build_viewpoint() -> void:
	var stele: MeshInstance3D = MeshInstance3D.new()
	stele.mesh = StoneMesh.block(Vector3(0.9, 2.4, 0.5), 4, 0.5, 6)
	stele.material_override = RuinBuilder.stone_material(0.4)
	stele.position.y = 1.1
	add_child(stele)
	var rune: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	rune.mesh = q
	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_texture = _rune_texture()
	_rune_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Color("e8b44c")
	_rune_mat.emission_energy_multiplier = 0.8
	_rune_mat.emission_texture = _rune_mat.albedo_texture
	rune.material_override = _rune_mat
	rune.position = Vector3(0, 1.6, 0.27)
	add_child(rune)
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.9, 2.4, 0.5)
	cs.shape = box
	cs.position.y = 1.1
	body.add_child(cs)
	add_child(body)


static func _rune_texture() -> ImageTexture:
	var n: int = 64
	var img: Image = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: Vector2 = Vector2(n, n) * 0.5
	for y: int in n:
		for x: int in n:
			var p: Vector2 = Vector2(x, y) - c
			var d: float = p.length() / (n * 0.5)
			var ring: bool = absf(d - 0.8) < 0.07
			var cross: bool = (absf(p.x) < 2.5 and absf(p.y) < n * 0.38) or (absf(p.y + 6) < 2.0 and absf(p.x) < n * 0.22)
			var eye: bool = absf(Vector2(p.x, p.y * 1.8 + 8).length() - 9.0) < 2.0
			if ring or cross or eye:
				img.set_pixel(x, y, Color(1, 0.85, 0.5, 1))
	return ImageTexture.create_from_image(img)


func _build_story() -> void:
	var set_props: Array = STORY_PROPS[story_index % STORY_PROPS.size()]
	for entry: Array in set_props:
		var file: String = entry[0]
		var path: String = (DUNGEON if file.ends_with(".glb") else HALLOWEEN) + file
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			continue
		var n: Node3D = packed.instantiate() as Node3D
		n.position = entry[1]
		n.rotation.y = entry[2]
		add_child(n)
