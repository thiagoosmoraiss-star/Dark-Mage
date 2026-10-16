class_name ShrineAltar
extends Interactable
## Altar no fundo do santuário: velas, cristal flutuante e o Sigilo.

var shrine: Shrine
var _crystal: MeshInstance3D
var _t: float = 0.0


func _ready() -> void:
	super._ready()
	prompt_key = "INTERACT_ALTAR"
	var base: Node3D = (load("res://assets/models/props/kaykit_halloween/shrine_candles.gltf") as PackedScene).instantiate()
	base.scale = Vector3.ONE * 1.4
	add_child(base)
	_crystal = MeshInstance3D.new()
	_crystal.mesh = MageLook.crystal_mesh(0.22, 0.75, 6)
	var m: StandardMaterial3D = MageLook.crystal_material().duplicate() as StandardMaterial3D
	m.emission = Color("e8b44c")
	m.albedo_color = Color("e8b44c")
	_crystal.material_override = m
	_crystal.position.y = 3.2
	add_child(_crystal)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("ffd27a")
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.position.y = 3.2
	add_child(light)


func can_interact(_player: Player) -> bool:
	return shrine != null and not shrine.done


func interact(player: Player) -> void:
	shrine.claim_reward(player)
	_crystal.visible = false


func _process(delta: float) -> void:
	_t += delta
	_crystal.rotation.y += delta
	_crystal.position.y = 3.2 + sin(_t * 1.5) * 0.15
