class_name Chest
extends Interactable
## Baú (KayKit Dungeon, CC0): a tampa abre girando na dobradiça e entrega o
## saque da região. Fica aberto para sempre (flag no GameState).

const MODEL: String = "res://assets/models/props/kaykit_dungeon/chest.glb"
const MODEL_GOLD: String = "res://assets/models/props/kaykit_dungeon/chest_gold.glb"
const REGION_MATERIAL: Dictionary = {
	&"valley": "golden_herb", &"forest": "glowcap", &"peaks": "frost_shard", &"burnt": "ember_stone",
	&"swamp": "violet_resin", &"coast": "sea_pearl",
}

@export var gold: bool = false
@export var region: StringName = &"valley"

var opened: bool = false
var _lid: Node3D


func _ready() -> void:
	super._ready()
	prompt_key = "INTERACT_CHEST"
	var packed: PackedScene = load(MODEL_GOLD if gold else MODEL) as PackedScene
	var m: Node3D = packed.instantiate() as Node3D
	m.scale = Vector3.ONE * 0.75
	add_child(m)
	_lid = m.find_child("*lid", true, false) as Node3D
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.25, 0.7, 0.9)
	cs.shape = box
	cs.position.y = 0.3
	body.add_child(cs)
	add_child(body)
	opened = GameState.has_flag(flag_key())
	if opened and _lid != null:
		_lid.rotation.x = -1.7


func get_class_tag() -> String:
	return "chest"


func can_interact(_player: Player) -> bool:
	return not opened


func interact(player: Player) -> void:
	if opened:
		return
	opened = true
	GameState.set_flag(flag_key())
	Audio.play(&"chest_open", global_position)
	if _lid != null:
		var tw: Tween = create_tween()
		tw.tween_property(_lid, "rotation:x", -1.7, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var loot: Dictionary = roll_loot(poi_id, region, gold)
	GameState.add_souls(JsonUtil.get_i(loot, "souls"))
	GameState.add_crystals(JsonUtil.get_i(loot, "crystals"))
	var mat: String = JsonUtil.get_s(loot, "material")
	if mat != "":
		GameState.add_material(mat, JsonUtil.get_i(loot, "material_count"))
	var vfx: Vfx = Vfx.get_for(self)
	if vfx != null:
		vfx.impact(global_position + Vector3.UP * 0.8, Color("e8b44c"), 1.0, 30)
	Audio.play(&"coins", global_position)
	var hud: Hud = player.get_tree().get_first_node_in_group(&"hud") as Hud
	if hud != null:
		hud.show_loot(loot)


## Saque determinístico por baú (mesma seed -> mesmo conteúdo).
static func roll_loot(id: String, reg: StringName, is_gold: bool) -> Dictionary:
	var rng: RandomNumberGenerator = Rng.make_rng(Rng.WORLD_SEED, "chest_" + id)
	var out: Dictionary = {
		"souls": rng.randi_range(60, 120) if is_gold else rng.randi_range(15, 45),
		"crystals": rng.randi_range(2, 4) if is_gold else rng.randi_range(0, 2),
		"material": REGION_MATERIAL.get(reg, "golden_herb"),
		"material_count": rng.randi_range(1, 3),
	}
	return out
