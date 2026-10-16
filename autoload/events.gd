extends Node
## Barramento global de sinais. Sistemas emitem e escutam aqui para não
## guardarem referências diretas entre si.

@warning_ignore_start("unused_signal")

# Ciclo de jogo
signal game_started(slot: int)
signal game_paused(paused: bool)
signal game_saved(slot: int)
signal game_loaded(slot: int)

# Configurações
signal settings_changed(section: String)
signal graphics_preset_changed(preset: String)
signal input_remapped(action: StringName)

# Mundo
signal time_of_day_changed(hours: float)
signal region_entered(region_id: StringName)
signal region_purified(region_id: StringName)

# Combate
signal damage_dealt(target: Node, info: RefCounted)
signal player_damaged(info: RefCounted)
signal enemy_killed(enemy: Node)
signal spell_cast(spell_id: StringName)
## Um feitiço acertou o mundo (objetos reativos: braseiros, espinhos, água, runas).
signal spell_hit_world(spell_id: StringName, element: int, pos: Vector3, collider: Node)
signal perfect_dodge
signal combat_state_changed(in_combat: bool)
signal lock_on_changed(target: Node)

# Debug
signal dev_overlay_toggled(visible: bool)

@warning_ignore_restore("unused_signal")
