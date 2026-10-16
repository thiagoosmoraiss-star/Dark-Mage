extends Node
## Música adaptativa e ambiente (roteiro 5). Música: exploração de dia/noite, trilha
## sombria (regiões corrompidas e interiores), combate e chefe, com crossfade entre
## dois players. Ambiente: camadas em loop no barramento Ambient cujos volumes seguem
## a região, a hora, a corrupção, a proximidade do mar e os interiores; fogo 3D na
## fogueira acesa mais próxima.

const MUSIC: Dictionary[StringName, String] = {
	&"explore_day": "res://assets/audio/music/explore_day.mp3",
	&"explore_night": "res://assets/audio/music/explore_night.mp3",
	&"dark": "res://assets/audio/music/dark.ogg",
	&"combat": "res://assets/audio/music/combat.mp3",
	&"boss": "res://assets/audio/music/boss.mp3",
}
const MUSIC_DB: Dictionary[StringName, float] = {
	&"explore_day": -6.0, &"explore_night": -7.0, &"dark": -4.0, &"combat": -8.0, &"boss": -6.0,
}
const LAYERS: Array[StringName] = [&"wind_soft", &"forest_day", &"wind_peaks", &"waves", &"swamp", &"burnt", &"cave",
	&"corruption", &"crickets"]
const COMBAT_HOLD: float = 5.0
const BOSS_RANGE: float = 70.0

## Força uma faixa (menu, epílogo); vazio = automático. &"none" = silêncio.
var forced: StringName = &""
var current: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _layers: Dictionary[StringName, AudioStreamPlayer] = {}
var _layer_targets: Dictionary[StringName, float] = {}
var _fire: AudioStreamPlayer3D
var _timer: float = 0.0
var _combat_hold: float = 0.0
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	for id: StringName in LAYERS:
		var lp: AudioStreamPlayer = AudioStreamPlayer.new()
		lp.bus = &"Ambient"
		lp.volume_db = -80.0
		lp.stream = _load_loop("res://assets/audio/ambience/%s.mp3" % String(id))
		add_child(lp)
		_layers[id] = lp
		_layer_targets[id] = 0.0
	_fire = AudioStreamPlayer3D.new()
	_fire.bus = &"Ambient"
	_fire.stream = _load_loop("res://assets/audio/ambience/fire.mp3")
	_fire.unit_size = 3.0
	_fire.max_distance = 26.0
	_fire.volume_db = -4.0
	add_child(_fire)


func _load_loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path) as AudioStream
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s


func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless" and not Game.has_arg("--audio-test"):
		return
	_timer -= delta
	_combat_hold = maxf(_combat_hold - delta, 0.0)
	if _timer <= 0.0:
		_timer = 0.5
		var want: StringName = pick_track()
		if want != current:
			play_track(want)
		_update_layer_targets()
	for id: StringName in LAYERS:
		var p: AudioStreamPlayer = _layers[id]
		if p.stream == null:
			continue
		var cur: float = db_to_linear(p.volume_db)
		var lin: float = move_toward(cur, _layer_targets[id], delta * 0.35)
		p.volume_db = linear_to_db(maxf(lin, 0.0001))
		if lin > 0.001 and not p.playing:
			p.play(randf() * 10.0)
		elif lin <= 0.001 and p.playing:
			p.stop()


## Escolhe a faixa pelo estado do jogo (ver a ordem de prioridade abaixo).
func pick_track() -> StringName:
	if forced != &"":
		return &"" if forced == &"none" else forced
	var world: IslandWorld = get_tree().get_first_node_in_group(&"world") as IslandWorld if is_inside_tree() else null
	if world == null or world.player == null:
		return &""
	var p: Player = world.player
	# 1. Chefe vivo por perto.
	for b: Node in get_tree().get_nodes_in_group(&"boss"):
		var boss: Boss = b as Boss
		if boss != null and boss.is_alive() and boss.global_position.distance_to(p.global_position) < BOSS_RANGE:
			return &"boss"
	# 2. Combate (com folga para não alternar a cada golpe).
	if p.stats.in_combat:
		_combat_hold = COMBAT_HOLD
	if _combat_hold > 0.0:
		return &"combat"
	# 3. Interiores e regiões corrompidas.
	if world.interiors != null and world.interiors.is_inside():
		return &"dark"
	var region: StringName = world.ambience.current_region if world.ambience != null else &"valley"
	if GameState.corruption(region) > 0.45:
		return &"dark"
	# 4. Exploração conforme a hora.
	if world.atmosphere != null and world.atmosphere.is_night():
		return &"explore_night"
	return &"explore_day"


func play_track(id: StringName, fade: float = -1.0) -> void:
	current = id
	if fade < 0.0:
		fade = 1.2 if id == &"combat" or id == &"boss" else 3.0
	var old: AudioStreamPlayer = _players[_active]
	_active = 1 - _active
	var nu: AudioStreamPlayer = _players[_active]
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(old, "volume_db", -80.0, fade)
	if id != &"" and MUSIC.has(id):
		nu.stream = _load_loop(MUSIC[id])
		nu.volume_db = -60.0
		nu.play()
		_tween.tween_property(nu, "volume_db", MUSIC_DB[id], fade)
	else:
		nu.stop()
	_tween.chain().tween_callback(func() -> void:
		if old.volume_db <= -79.0:
			old.stop())


## Volumes-alvo das camadas de ambiente.
func _update_layer_targets() -> void:
	for id: StringName in LAYERS:
		_layer_targets[id] = 0.0
	var world: IslandWorld = get_tree().get_first_node_in_group(&"world") as IslandWorld
	if world == null or world.player == null:
		_fire.stop()
		return
	var p: Player = world.player
	if world.interiors != null and world.interiors.is_inside():
		_layer_targets[&"cave"] = 0.8
		_fire.stop()
		return
	var night: bool = world.atmosphere != null and world.atmosphere.is_night()
	var region: StringName = world.ambience.current_region if world.ambience != null else &"valley"
	match region:
		&"forest":
			_layer_targets[&"forest_day" if not night else &"crickets"] = 0.8
			_layer_targets[&"wind_soft"] = 0.25
		&"peaks", &"citadel":
			_layer_targets[&"wind_peaks"] = 0.85
		&"burnt":
			_layer_targets[&"burnt"] = 0.8
		&"swamp":
			_layer_targets[&"swamp"] = 0.8
			if night:
				_layer_targets[&"crickets"] = 0.35
		&"coast", &"sea":
			_layer_targets[&"waves"] = 0.9
			_layer_targets[&"wind_soft"] = 0.4
		_:
			_layer_targets[&"wind_soft"] = 0.6
			if night:
				_layer_targets[&"crickets"] = 0.6
			else:
				_layer_targets[&"forest_day"] = 0.3
	# Perto do nível do mar, as ondas aparecem em qualquer região.
	if p.global_position.y < 9.0:
		_layer_targets[&"waves"] = maxf(_layer_targets[&"waves"], 0.6 * (1.0 - clampf(p.global_position.y / 9.0, 0.0, 1.0)))
	_layer_targets[&"corruption"] = GameState.corruption(region) * 0.7
	_update_fire(p)


func _update_fire(p: Player) -> void:
	var best: Node3D = null
	var best_d: float = 26.0
	for n: Node in get_tree().get_nodes_in_group(&"interactable"):
		var bf: Bonfire = n as Bonfire
		if bf != null and bf.discovered:
			var d: float = bf.global_position.distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = bf
	if best == null:
		if _fire.playing:
			_fire.stop()
		return
	_fire.global_position = best.global_position + Vector3.UP * 0.5
	if not _fire.playing and _fire.stream != null:
		_fire.play()


## Para tudo (troca de cena para o menu).
func stop_all() -> void:
	play_track(&"", 0.8)
	for id: StringName in LAYERS:
		_layer_targets[id] = 0.0
	_fire.stop()
