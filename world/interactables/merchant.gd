class_name Merchant
extends Interactable
## O Mercador Misterioso: um esqueleto encapuzado com lanterna, caixotes e barris,
## ao lado da fogueira do Vale. O estoque cresce com cada Guardião vencido.

const SK: String = "res://assets/models/characters/kaykit_skeletons/Skeleton_Rogue.glb"
const DUNGEON: String = "res://assets/models/props/kaykit_dungeon/"
const HALLOWEEN: String = "res://assets/models/props/kaykit_halloween/"


func _ready() -> void:
	super._ready()
	add_to_group(&"merchant")
	prompt_key = "INTERACT_MERCHANT"
	interact_range = 3.2
	_build()


func get_class_tag() -> String:
	return "merchant"


func interact(_player: Player) -> void:
	var ui: GameUi = get_tree().get_first_node_in_group(&"game_ui") as GameUi
	if ui != null:
		ui.open_shop()
	Audio.play(&"coins", global_position)


## Itens à venda agora (de acordo com os Guardiões vencidos).
static func stock() -> Array[String]:
	var g: int = Citadel.guardians_defeated()
	var out: Array[String] = []
	for e: Dictionary in ItemDb.MERCHANT_STOCK:
		if g >= JsonUtil.get_i(e, "need_guardians"):
			out.append(JsonUtil.get_s(e, "id"))
	return out


static func buy(id: String) -> bool:
	var p: int = ItemDb.price(id)
	if GameState.souls < p or not stock().has(id):
		return false
	if Inventory.add(id, 1) == 0:
		return false
	GameState.add_souls(-p)
	return true


## Vende 1 unidade da casa `i` do inventário.
static func sell_slot(i: int) -> bool:
	var id: String = Inventory.id_at(i)
	if id == "":
		return false
	Inventory.remove_at(i, 1)
	GameState.add_souls(ItemDb.sell_price(id))
	return true


static func sell_material(id: String, n: int = 1) -> bool:
	var have: int = GameState.materials[id] if GameState.materials.has(id) else 0
	if have < n:
		return false
	GameState.add_material(id, -n)
	GameState.add_souls(ItemDb.sell_price(id) * n)
	return true


func _build() -> void:
	var body: Node3D = _load(SK)
	if body != null:
		body.scale = Vector3.ONE * 1.05
		add_child(body)
		_tint(body, Color(0.16, 0.1, 0.22))
		var ap: AnimationPlayer = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap != null:
			for anim: String in ["Idle", "Idle_B", "Unarmed_Idle"]:
				if ap.has_animation(anim):
					ap.play(anim)
					break
	# Mercadorias atrás dele: barril, caixotes e uma vela; lanterna ao lado.
	for p: Array in [[DUNGEON + "barrel_large.glb", Vector3(1.2, 0, -1.1), 0.3, 0.55], [DUNGEON + "crates_stacked.glb", Vector3(-1.3, 0, -1.0), 0.8, 0.6],
			[HALLOWEEN + "lantern_standing.gltf", Vector3(0.95, 0, 0.45), 0.0, 0.8], [DUNGEON + "candle_lit.glb", Vector3(1.2, 0.72, -1.1), 0.0, 0.8]]:
		var prop: Node3D = _load(str(p[0]))
		if prop != null:
			add_child(prop)
			prop.position = p[1]
			prop.rotation.y = p[2]
			prop.scale = Vector3.ONE * JsonUtil.num(p[3], 1.0)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("ffb35c")
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.shadow_enabled = false
	light.position = Vector3(0.95, 1.3, 0.45)
	add_child(light)
	var col: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.0
	cs.shape = cap
	cs.position.y = 1.0
	col.add_child(cs)
	add_child(col)


func _load(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path) as PackedScene
	return ps.instantiate() as Node3D if ps != null else null


func _tint(n: Node, c: Color) -> void:
	var overlay: StandardMaterial3D = StandardMaterial3D.new()
	overlay.albedo_color = Color(c, 0.55)
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for m: Node in n.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = overlay
