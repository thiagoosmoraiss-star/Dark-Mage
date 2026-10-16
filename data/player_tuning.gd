class_name PlayerTuning
extends Resource
## Constantes de movimento do jogador (ajustáveis no inspetor ou no modo debug).

@export_group("Chão")
@export var walk_speed: float = 2.4
@export var run_speed: float = 5.6
@export var sprint_speed: float = 8.6
@export var acceleration: float = 30.0
@export var deceleration: float = 38.0
@export var turn_speed: float = 12.0
@export var floor_max_angle_deg: float = 48.0
@export var sprint_stamina_per_s: float = 18.0

@export_group("Ar")
@export var jump_velocity: float = 6.8
@export var gravity: float = 22.0
@export var max_fall_speed: float = 45.0
@export var air_control: float = 0.35
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.12
@export var jump_stamina: float = 0.0

@export_group("Escalada")
@export var climb_speed: float = 1.9
@export var climb_sprint_speed: float = 3.6
@export var climb_stamina_per_s: float = 9.0
@export var climb_jump_stamina: float = 18.0
@export var climb_min_angle_deg: float = 52.0
@export var rain_slip: float = 0.35

@export_group("Planador")
@export var glide_fall_speed: float = 2.4
@export var glide_speed: float = 9.5
@export var glide_stamina_per_s: float = 6.5

@export_group("Natação")
@export var swim_speed: float = 2.6
@export var swim_sprint_speed: float = 4.6
@export var swim_stamina_per_s: float = 2.5
@export var swim_sprint_stamina_per_s: float = 16.0
@export var swim_depth: float = 1.15

@export_group("Esquiva")
@export var dodge_distance: float = 5.0
@export var dodge_time: float = 0.42
@export var dodge_iframes: float = 0.3
@export var dodge_stamina: float = 16.0
@export var perfect_dodge_window: float = 0.15
