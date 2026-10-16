class_name SpellData
extends Resource
## Dados de um feitiço (roteiro 4.3). Os arquivos ficam em data/spells/*.tres.

enum Kind { PROJECTILE, AREA, CHAIN, BARRIER, METEOR, BLINK, CONTROL, ULTIMATE }

@export var id: StringName = &""
## Chave de tradução do nome e da descrição.
@export var name_key: String = ""
@export var desc_key: String = ""
@export var kind: Kind = Kind.PROJECTILE
@export var element: DamageInfo.Element = DamageInfo.Element.ARCANE
@export var mana_cost: float = 10.0
@export var cooldown: float = 1.0
@export var damage: float = 10.0
## Para feitiços carregáveis: dano máximo e tempo até carga total.
@export var charge_damage: float = 0.0
@export var charge_time: float = 0.0
@export var radius: float = 0.0
@export var range_m: float = 30.0
@export var speed: float = 40.0
@export var duration: float = 0.0
@export var knockback: float = 0.0
@export var stagger: float = 0.3
## Número de saltos (raio em cadeia) ou cargas do escudo.
@export var count: int = 0
@export var color: Color = Color("b67cff")
## Etiquetas de interação com o mundo (ex.: "ignite", "freeze_water", "reveal").
@export var world_tags: PackedStringArray = []
## Animação de conjuração (nome lógico do PlayerModel).
@export var cast_anim: StringName = &"cast_quick"
@export var cast_lock: float = 0.35
