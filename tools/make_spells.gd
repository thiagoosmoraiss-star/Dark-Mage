extends SceneTree
## Gera data/spells/*.tres (SpellData) a partir da tabela abaixo.
## Uso: tools/run.sh res://tools/make_spells.gd
## Os 8 feitiços cobrem as funções do roteiro 4.3.

const E := DamageInfo.Element
const K := SpellData.Kind

const TABLE: Array[Dictionary] = [
	{"id": &"arcane_lance", "kind": K.PROJECTILE, "element": E.ARCANE, "mana_cost": 12.0, "cooldown": 0.8,
		"damage": 18.0, "charge_damage": 64.0, "charge_time": 1.2, "speed": 46.0, "range_m": 60.0, "radius": 0.0,
		"knockback": 3.0, "stagger": 0.5, "color": Color("b67cff"), "world_tags": ["ignite"],
		"cast_anim": &"cast_charged", "cast_lock": 0.3},
	{"id": &"umbral_pulse", "kind": K.AREA, "element": E.ARCANE, "mana_cost": 20.0, "cooldown": 6.0,
		"damage": 22.0, "radius": 5.5, "knockback": 10.0, "stagger": 1.0, "color": Color("6b2fd6"),
		"world_tags": ["shatter"], "cast_anim": &"cast_area", "cast_lock": 0.45},
	{"id": &"ether_chain", "kind": K.CHAIN, "element": E.LIGHTNING, "mana_cost": 18.0, "cooldown": 4.0,
		"damage": 20.0, "range_m": 18.0, "radius": 9.0, "count": 4, "stagger": 0.6, "color": Color("9fd8ff"),
		"world_tags": ["reveal"], "cast_anim": &"cast_quick", "cast_lock": 0.35},
	{"id": &"violet_aegis", "kind": K.BARRIER, "element": E.ARCANE, "mana_cost": 25.0, "cooldown": 12.0,
		"damage": 0.0, "duration": 4.5, "count": 60, "radius": 1.6, "color": Color("e8b44c"),
		"cast_anim": &"cast_area", "cast_lock": 0.3},
	{"id": &"astral_fall", "kind": K.METEOR, "element": E.FIRE, "mana_cost": 35.0, "cooldown": 10.0,
		"damage": 75.0, "radius": 4.8, "range_m": 32.0, "duration": 1.1, "knockback": 12.0, "stagger": 1.0,
		"color": Color("ffb765"), "world_tags": ["ignite", "shatter"], "cast_anim": &"cast_area", "cast_lock": 0.5},
	{"id": &"umbral_step", "kind": K.BLINK, "element": E.ARCANE, "mana_cost": 10.0, "cooldown": 2.5,
		"damage": 0.0, "range_m": 9.0, "color": Color("b67cff"), "cast_anim": &"dodge", "cast_lock": 0.15},
	{"id": &"frost_shackles", "kind": K.CONTROL, "element": E.FROST, "mana_cost": 20.0, "cooldown": 8.0,
		"damage": 12.0, "radius": 4.0, "range_m": 14.0, "duration": 3.0, "stagger": 0.4, "color": Color("9fe3ff"),
		"world_tags": ["freeze_water"], "cast_anim": &"cast_quick", "cast_lock": 0.35},
	{"id": &"beacon_wrath", "kind": K.ULTIMATE, "element": E.ARCANE, "mana_cost": 0.0, "cooldown": 1.0,
		"damage": 160.0, "radius": 12.0, "count": 300, "knockback": 16.0, "stagger": 1.0, "color": Color("e8b44c"),
		"world_tags": ["ignite", "shatter", "reveal"], "cast_anim": &"cast_area", "cast_lock": 0.8},
]


func _initialize() -> void:
	var dir: String = "res://data/spells"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for row: Dictionary in TABLE:
		var s: SpellData = SpellData.new()
		for key: String in row:
			var v: Variant = row[key]
			if key == "world_tags":
				s.world_tags = PackedStringArray(v as Array)
			else:
				s.set(key, v)
		var id_str: String = String(s.id)
		s.name_key = "SPELL_%s" % id_str.to_upper()
		s.desc_key = "SPELL_%s_DESC" % id_str.to_upper()
		var err: Error = ResourceSaver.save(s, dir.path_join(id_str + ".tres"))
		print("spell %s: %s" % [id_str, error_string(err)])
	quit(0)
