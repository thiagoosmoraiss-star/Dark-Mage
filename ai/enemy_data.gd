class_name EnemyData
extends Resource
## Dados de um tipo de inimigo (roteiro 4.4). Variantes de elite multiplicam vida e dano.

enum AttackKind { MELEE, RANGED, CASTER }

@export var id: StringName = &""
## Comportamento (classe): basic, witch, bat, golem, serpent.
@export var behavior: StringName = &"basic"
@export var name_key: String = ""
@export var model_path: String = ""
@export var weapon_path: String = ""
@export var weapon_bone: String = "handslot.r"
@export var tint: Color = Color(0.85, 0.82, 0.9)
@export var eye_color: Color = Color("b67cff")
@export var model_scale: float = 1.0
@export var health: float = 60.0
@export var damage: float = 12.0
@export var walk_speed: float = 1.6
@export var run_speed: float = 4.6
@export var sight_range: float = 22.0
@export var sight_fov_deg: float = 120.0
@export var hearing_range: float = 14.0
@export var attack_kind: AttackKind = AttackKind.MELEE
@export var attack_range: float = 2.0
## Distância preferida (arqueiros mantêm distância).
@export var preferred_range: float = 1.6
@export var attack_cooldown: float = 1.8
## Telegrafia: tempo de preparação antes do golpe.
@export var windup: float = 0.55
@export var projectile_speed: float = 28.0
@export var knockback_resist: float = 0.0
@export var poise: float = 0.6
@export var xp: int = 10
@export var souls: int = 5
@export var anim_attack: StringName = &"1H_Melee_Attack_Chop"
@export var anim_idle: StringName = &"Idle"
@export var anim_walk: StringName = &"Walking_A"
@export var anim_run: StringName = &"Running_A"
