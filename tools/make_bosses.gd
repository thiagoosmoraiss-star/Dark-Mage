extends SceneTree
## Gera data/bosses/*.tres (BossData): os 4 Guardiões do Medo e o chefe final.
## Uso: tools/run.sh res://tools/make_bosses.gd

const SK: String = "res://assets/models/characters/kaykit_skeletons/"
const WP: String = "res://assets/models/props/kaykit_skeleton_weapons/"
const M := BossData.Mechanic

var table: Array[Dictionary] = [
	{"id": &"guardian_forest", "name_key": "BOSS_FOREST", "title_key": "BOSS_FOREST_TITLE", "region": &"forest",
		"body": &"skeleton", "model_path": SK + "Skeleton_Warrior.glb", "weapon_path": WP + "Skeleton_Axe.gltf",
		"tint": Color(0.45, 0.55, 0.35), "eye_color": Color("7fd66b"), "model_scale": 2.8, "health": 1100.0,
		"damage": 26.0, "move_speed": 3.4, "mechanic": M.SHIELD, "breaker_spell": &"umbral_pulse",
		"summon_id": &"mist_crawler", "reward_spell": &"umbral_step",
		"phase_attacks": [["slam", "sweep", "volley"], ["slam", "summon", "wave", "dash"]],
		"intro_key": "BOSS_FOREST_INTRO", "phase2_key": "BOSS_FOREST_P2", "defeat_key": "BOSS_FOREST_DEFEAT"},
	{"id": &"guardian_peaks", "name_key": "BOSS_PEAKS", "title_key": "BOSS_PEAKS_TITLE", "region": &"peaks",
		"body": &"golem", "tint": Color(0.62, 0.78, 0.92), "eye_color": Color("9fe3ff"), "model_scale": 1.8,
		"health": 1400.0, "damage": 30.0, "move_speed": 2.4, "mechanic": M.ARMOR, "breaker_spell": &"arcane_lance",
		"summon_id": &"spectral_bat", "reward_spell": &"frost_shackles",
		"phase_attacks": [["slam", "volley", "sweep"], ["slam", "wave", "nova", "summon"]],
		"intro_key": "BOSS_PEAKS_INTRO", "phase2_key": "BOSS_PEAKS_P2", "defeat_key": "BOSS_PEAKS_DEFEAT"},
	{"id": &"guardian_burnt", "name_key": "BOSS_BURNT", "title_key": "BOSS_BURNT_TITLE", "region": &"burnt",
		"body": &"golem", "tint": Color(0.32, 0.24, 0.22), "eye_color": Color("ff8a3c"), "model_scale": 2.0,
		"health": 1600.0, "damage": 34.0, "move_speed": 2.6, "mechanic": M.OVERHEAT, "breaker_spell": &"frost_shackles",
		"summon_id": &"mist_crawler", "reward_spell": &"astral_fall",
		"phase_attacks": [["slam", "sweep", "dash"], ["nova", "slam", "volley", "wave"]],
		"intro_key": "BOSS_BURNT_INTRO", "phase2_key": "BOSS_BURNT_P2", "defeat_key": "BOSS_BURNT_DEFEAT"},
	{"id": &"guardian_swamp", "name_key": "BOSS_SWAMP", "title_key": "BOSS_SWAMP_TITLE", "region": &"swamp",
		"body": &"serpent", "tint": Color(0.4, 0.3, 0.5), "eye_color": Color("b67cff"), "model_scale": 1.7,
		"health": 1500.0, "damage": 28.0, "move_speed": 0.0, "mechanic": M.SUBMERGE, "breaker_spell": &"ether_chain",
		"summon_id": &"mist_crawler", "reward_spell": &"beacon_wrath",
		"phase_attacks": [["volley", "wave"], ["volley", "summon", "nova", "wave"]],
		"intro_key": "BOSS_SWAMP_INTRO", "phase2_key": "BOSS_SWAMP_P2", "defeat_key": "BOSS_SWAMP_DEFEAT"},
	{"id": &"fear", "name_key": "BOSS_FEAR", "title_key": "BOSS_FEAR_TITLE", "region": &"citadel",
		"body": &"skeleton", "model_path": SK + "Skeleton_Mage.glb", "weapon_path": WP + "Skeleton_Staff.gltf",
		"tint": Color(0.18, 0.12, 0.26), "eye_color": Color("e8b44c"), "model_scale": 3.4, "health": 3000.0,
		"damage": 32.0, "move_speed": 3.8, "mechanic": M.ALL, "phase_thresholds": PackedFloat32Array([0.66, 0.33]),
		"summon_id": &"mist_crawler", "reward_spell": &"",
		"phase_attacks": [["slam", "volley", "sweep"], ["wave", "summon", "dash", "volley"], ["nova", "wave", "volley", "dash", "slam"]],
		"intro_key": "BOSS_FEAR_INTRO", "phase2_key": "BOSS_FEAR_P2", "defeat_key": "BOSS_FEAR_DEFEAT"},
]


func _initialize() -> void:
	var dir: String = "res://data/bosses"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for row: Dictionary in table:
		var b: BossData = BossData.new()
		for key: String in row:
			b.set(key, row[key])
		var err: Error = ResourceSaver.save(b, dir.path_join(String(b.id) + ".tres"))
		print("boss %s: %s" % [b.id, error_string(err)])
	quit(0)
