class_name SoundBank
extends RefCounted
## Sons lógicos -> arquivos (um é sorteado a cada toque) e barramento.
## Magia em camadas = vários ids tocados juntos (ver SpellCaster/Projectile).

const BASE: String = "res://assets/audio/sfx/"

const SOUNDS: Dictionary = {
	# Magia
	&"cast_bolt": {"bus": &"SFX", "files": ["sci-fi-sounds/laserSmall_000.ogg", "sci-fi-sounds/laserSmall_001.ogg", "sci-fi-sounds/laserSmall_002.ogg"], "db": -8.0, "pitch": 0.12},
	&"cast_heavy": {"bus": &"SFX", "files": ["sci-fi-sounds/laserLarge_000.ogg", "sci-fi-sounds/laserLarge_001.ogg", "sci-fi-sounds/laserLarge_002.ogg"], "db": -6.0, "pitch": 0.08},
	&"charge": {"bus": &"SFX", "files": ["sci-fi-sounds/forceField_000.ogg", "sci-fi-sounds/forceField_001.ogg"], "db": -10.0, "pitch": 0.05},
	&"impact_arcane": {"bus": &"SFX", "files": ["impact-sounds/impactGlass_light_000.ogg", "impact-sounds/impactGlass_light_001.ogg", "impact-sounds/impactGlass_light_002.ogg", "impact-sounds/impactGlass_light_003.ogg"], "db": -6.0, "pitch": 0.15},
	&"impact_heavy": {"bus": &"SFX", "files": ["sci-fi-sounds/explosionCrunch_000.ogg", "sci-fi-sounds/explosionCrunch_001.ogg", "sci-fi-sounds/explosionCrunch_002.ogg"], "db": -4.0, "pitch": 0.1},
	&"boom": {"bus": &"SFX", "files": ["sci-fi-sounds/lowFrequency_explosion_000.ogg", "sci-fi-sounds/lowFrequency_explosion_001.ogg"], "db": -2.0, "pitch": 0.05},
	&"lightning": {"bus": &"SFX", "files": ["sci-fi-sounds/computerNoise_000.ogg", "sci-fi-sounds/computerNoise_001.ogg", "sci-fi-sounds/computerNoise_002.ogg"], "db": -6.0, "pitch": 0.2},
	&"barrier": {"bus": &"SFX", "files": ["sci-fi-sounds/forceField_002.ogg", "sci-fi-sounds/forceField_003.ogg", "sci-fi-sounds/forceField_004.ogg"], "db": -5.0, "pitch": 0.05},
	&"blink": {"bus": &"SFX", "files": ["sci-fi-sounds/laserSmall_003.ogg", "sci-fi-sounds/forceField_001.ogg"], "db": -8.0, "pitch": 0.1},
	&"fire": {"bus": &"SFX", "files": ["sci-fi-sounds/thrusterFire_000.ogg", "sci-fi-sounds/thrusterFire_001.ogg"], "db": -8.0, "pitch": 0.1},
	&"frost": {"bus": &"SFX", "files": ["impact-sounds/impactGlass_medium_000.ogg", "impact-sounds/impactGlass_medium_001.ogg", "impact-sounds/impactGlass_medium_002.ogg"], "db": -5.0, "pitch": 0.1},
	# Combate físico
	&"hit_flesh": {"bus": &"SFX", "files": ["impact-sounds/impactPunch_medium_000.ogg", "impact-sounds/impactPunch_medium_001.ogg", "impact-sounds/impactPunch_medium_002.ogg"], "db": -5.0, "pitch": 0.1},
	&"hit_bone": {"bus": &"SFX", "files": ["impact-sounds/impactMining_000.ogg", "impact-sounds/impactMining_001.ogg", "impact-sounds/impactMining_002.ogg"], "db": -6.0, "pitch": 0.12},
	&"hit_heavy": {"bus": &"SFX", "files": ["impact-sounds/impactPunch_heavy_000.ogg", "impact-sounds/impactPunch_heavy_001.ogg"], "db": -3.0, "pitch": 0.08},
	&"blade_swing": {"bus": &"SFX", "files": ["rpg-audio/knifeSlice.ogg", "rpg-audio/knifeSlice2.ogg", "rpg-audio/drawKnife1.ogg"], "db": -8.0, "pitch": 0.1},
	&"bow_shot": {"bus": &"SFX", "files": ["rpg-audio/drawKnife2.ogg", "rpg-audio/drawKnife3.ogg"], "db": -8.0, "pitch": 0.1},
	&"player_hurt": {"bus": &"SFX", "files": ["impact-sounds/impactSoft_heavy_000.ogg", "impact-sounds/impactSoft_heavy_001.ogg", "impact-sounds/impactSoft_heavy_002.ogg"], "db": -3.0, "pitch": 0.05},
	&"dodge": {"bus": &"SFX", "files": ["rpg-audio/cloth1.ogg", "rpg-audio/cloth2.ogg", "rpg-audio/cloth3.ogg", "rpg-audio/cloth4.ogg"], "db": -6.0, "pitch": 0.1},
	&"perfect_dodge": {"bus": &"SFX", "files": ["impact-sounds/impactBell_heavy_000.ogg", "impact-sounds/impactBell_heavy_001.ogg"], "db": -6.0, "pitch": 0.0},
	&"enemy_death": {"bus": &"SFX", "files": ["impact-sounds/impactPlate_light_000.ogg", "impact-sounds/impactPlate_light_001.ogg", "impact-sounds/impactPlate_light_002.ogg"], "db": -4.0, "pitch": 0.1},
	# Passos
	&"step_grass": {"bus": &"SFX", "files": ["impact-sounds/footstep_grass_000.ogg", "impact-sounds/footstep_grass_001.ogg", "impact-sounds/footstep_grass_002.ogg", "impact-sounds/footstep_grass_003.ogg", "impact-sounds/footstep_grass_004.ogg"], "db": -14.0, "pitch": 0.1},
	&"step_stone": {"bus": &"SFX", "files": ["impact-sounds/footstep_concrete_000.ogg", "impact-sounds/footstep_concrete_001.ogg", "impact-sounds/footstep_concrete_002.ogg", "impact-sounds/footstep_concrete_003.ogg", "impact-sounds/footstep_concrete_004.ogg"], "db": -14.0, "pitch": 0.1},
	&"step_snow": {"bus": &"SFX", "files": ["impact-sounds/footstep_snow_000.ogg", "impact-sounds/footstep_snow_001.ogg", "impact-sounds/footstep_snow_002.ogg", "impact-sounds/footstep_snow_003.ogg", "impact-sounds/footstep_snow_004.ogg"], "db": -12.0, "pitch": 0.1},
	&"step_wood": {"bus": &"SFX", "files": ["impact-sounds/footstep_wood_000.ogg", "impact-sounds/footstep_wood_001.ogg", "impact-sounds/footstep_wood_002.ogg"], "db": -12.0, "pitch": 0.1},
	# Mundo e UI
	&"chest_open": {"bus": &"SFX", "files": ["rpg-audio/metalLatch.ogg", "rpg-audio/creak1.ogg"], "db": -4.0, "pitch": 0.05},
	&"coins": {"bus": &"SFX", "files": ["rpg-audio/handleCoins.ogg", "rpg-audio/handleCoins2.ogg"], "db": -6.0, "pitch": 0.05},
	&"beacon": {"bus": &"SFX", "files": ["impact-sounds/impactBell_heavy_002.ogg", "impact-sounds/impactBell_heavy_003.ogg"], "db": -2.0, "pitch": 0.0},
	&"ui_select": {"bus": &"UI", "files": ["interface-sounds/select_001.ogg", "interface-sounds/select_002.ogg"], "db": -8.0, "pitch": 0.03},
	&"ui_click": {"bus": &"UI", "files": ["interface-sounds/click_001.ogg", "interface-sounds/click_002.ogg"], "db": -8.0, "pitch": 0.03},
	&"ui_confirm": {"bus": &"UI", "files": ["interface-sounds/confirmation_001.ogg", "interface-sounds/confirmation_002.ogg"], "db": -6.0, "pitch": 0.0},
	&"ui_back": {"bus": &"UI", "files": ["interface-sounds/back_001.ogg", "interface-sounds/back_002.ogg"], "db": -8.0, "pitch": 0.0},
	&"ui_error": {"bus": &"UI", "files": ["interface-sounds/error_001.ogg", "interface-sounds/error_002.ogg"], "db": -8.0, "pitch": 0.0},
	&"ui_open": {"bus": &"UI", "files": ["interface-sounds/open_001.ogg", "interface-sounds/open_002.ogg", "rpg-audio/bookOpen.ogg"], "db": -8.0, "pitch": 0.0},
	&"ui_close": {"bus": &"UI", "files": ["interface-sounds/close_001.ogg", "interface-sounds/close_002.ogg", "rpg-audio/bookClose.ogg"], "db": -8.0, "pitch": 0.0},
}
