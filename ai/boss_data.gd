class_name BossData
extends Resource
## Guardião (ou chefe final): fases, ataques por fase e a mecânica que exige um feitiço.

enum Mechanic { NONE, SHIELD, ARMOR, OVERHEAT, SUBMERGE, ALL }

@export var id: StringName = &""
@export var name_key: String = ""
@export var title_key: String = ""
@export var region: StringName = &"valley"
## Visual: "skeleton" (KayKit), "golem", "serpent".
@export var body: StringName = &"skeleton"
@export var model_path: String = ""
@export var weapon_path: String = ""
@export var tint: Color = Color(0.6, 0.55, 0.7)
@export var eye_color: Color = Color("b67cff")
@export var model_scale: float = 2.6
@export var health: float = 1200.0
@export var damage: float = 28.0
@export var move_speed: float = 3.2
## Limiares de vida em que a fase muda (ex.: [0.5] = 2 fases; [0.66, 0.33] = 3 fases).
@export var phase_thresholds: PackedFloat32Array = [0.5]
## Ataques por fase: lista de listas de ids (slam, sweep, volley, wave, summon, dash, nova).
@export var phase_attacks: Array = [["slam", "sweep", "volley"], ["slam", "wave", "summon", "nova"]]
@export var mechanic: Mechanic = Mechanic.NONE
## Feitiço que quebra a mecânica (pulso, lança carregada, gelo, corrente).
@export var breaker_spell: StringName = &""
@export var summon_id: StringName = &"mist_crawler"
## Feitiço concedido ao vencer.
@export var reward_spell: StringName = &""
@export var intro_key: String = ""
@export var phase2_key: String = ""
@export var defeat_key: String = ""
