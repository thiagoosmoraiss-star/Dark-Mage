extends SceneTree
## Gera data/enemies/*.tres (EnemyData). Uso: tools/run.sh res://tools/make_enemies.gd

const SK: String = "res://assets/models/characters/kaykit_skeletons/"
const WP: String = "res://assets/models/props/kaykit_skeleton_weapons/"
const A := EnemyData.AttackKind

const TABLE: Array[Dictionary] = [
	{"id": &"mist_crawler", "name_key": "ENEMY_MIST_CRAWLER", "model_path": SK + "Skeleton_Minion.glb",
		"weapon_path": WP + "Skeleton_Blade.gltf", "tint": Color(0.62, 0.55, 0.72), "eye_color": Color("b67cff"),
		"health": 55.0, "damage": 11.0, "walk_speed": 1.7, "run_speed": 4.9, "sight_range": 20.0, "hearing_range": 14.0,
		"attack_kind": A.MELEE, "attack_range": 2.1, "preferred_range": 1.6, "attack_cooldown": 1.9, "windup": 0.6,
		"poise": 0.55, "xp": 12, "souls": 6, "anim_attack": &"1H_Melee_Attack_Chop", "anim_run": &"Running_A"},
	{"id": &"bone_archer", "name_key": "ENEMY_BONE_ARCHER", "model_path": SK + "Skeleton_Rogue.glb",
		"weapon_path": WP + "Skeleton_Crossbow.gltf", "tint": Color(0.78, 0.74, 0.7), "eye_color": Color("ff7a5a"),
		"health": 42.0, "damage": 13.0, "walk_speed": 1.5, "run_speed": 4.2, "sight_range": 30.0, "hearing_range": 16.0,
		"attack_kind": A.RANGED, "attack_range": 24.0, "preferred_range": 15.0, "attack_cooldown": 2.6, "windup": 0.9,
		"projectile_speed": 26.0, "poise": 0.45, "xp": 14, "souls": 8, "anim_attack": &"1H_Ranged_Shoot",
		"anim_run": &"Running_B"},
	{"id": &"swamp_witch", "name_key": "ENEMY_SWAMP_WITCH", "model_path": SK + "Skeleton_Mage.glb",
		"weapon_path": WP + "Skeleton_Staff.gltf", "tint": Color(0.55, 0.62, 0.5), "eye_color": Color("7fff9e"),
		"health": 70.0, "damage": 14.0, "walk_speed": 1.4, "run_speed": 3.6, "sight_range": 26.0, "hearing_range": 18.0,
		"attack_kind": A.CASTER, "attack_range": 20.0, "preferred_range": 13.0, "attack_cooldown": 3.2, "windup": 1.0,
		"projectile_speed": 18.0, "poise": 0.6, "xp": 22, "souls": 12, "anim_attack": &"Spellcast_Shoot",
		"anim_run": &"Running_A"},
]


func _initialize() -> void:
	var dir: String = "res://data/enemies"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for row: Dictionary in TABLE:
		var e: EnemyData = EnemyData.new()
		for key: String in row:
			e.set(key, row[key])
		var err: Error = ResourceSaver.save(e, dir.path_join(String(e.id) + ".tres"))
		print("enemy %s: %s" % [e.id, error_string(err)])
	quit(0)
