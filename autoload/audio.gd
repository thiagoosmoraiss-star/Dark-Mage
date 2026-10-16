extends Node
## Áudio: barramentos (Master, Music, SFX, Ambient, UI, Voice), pool de vozes 3D
## e 2D com limite de simultaneidade, e volumes vindos das configurações.

const BUSES: Array[StringName] = [&"Music", &"SFX", &"Ambient", &"UI", &"Voice"]
const SETTINGS_KEYS: Dictionary = {
	&"Master": "master", &"Music": "music", &"SFX": "sfx", &"Ambient": "ambient", &"UI": "ui", &"Voice": "voice",
}
const VOICES_3D: int = 28
const VOICES_2D: int = 8

var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _next_3d: int = 0
var _next_2d: int = 0
var _cache: Dictionary[String, AudioStream] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i: int in VOICES_3D:
		var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p.max_distance = 80.0
		p.unit_size = 6.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 1.0
		add_child(p)
		_players_3d.append(p)
	for i: int in VOICES_2D:
		var p2: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p2)
		_players_2d.append(p2)
	apply_volumes()
	Events.settings_changed.connect(func(section: String) -> void:
		if section == "audio":
			apply_volumes())


func _ensure_buses() -> void:
	for b: StringName in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, &"Master")
	# Reverb para cavernas e interiores (ligado por áreas de reverb).
	if AudioServer.get_bus_index(&"Reverb") == -1:
		AudioServer.add_bus()
		var r: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(r, &"Reverb")
		AudioServer.set_bus_send(r, &"SFX")
		var fx: AudioEffectReverb = AudioEffectReverb.new()
		fx.room_size = 0.8
		fx.wet = 0.35
		AudioServer.add_bus_effect(r, fx)


func apply_volumes() -> void:
	for bus: StringName in SETTINGS_KEYS:
		var idx: int = AudioServer.get_bus_index(bus)
		if idx < 0:
			continue
		var lin: float = JsonUtil.num(Settings.get_value("audio", SETTINGS_KEYS[bus] as String), 1.0)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))
		AudioServer.set_bus_mute(idx, lin <= 0.001)


func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(SoundBank.BASE + path) as AudioStream
	return _cache[path]


## Toca um som lógico do SoundBank. Com `pos` finito toca em 3D.
func play(id: StringName, pos: Vector3 = Vector3.INF, volume_offset_db: float = 0.0) -> void:
	if not SoundBank.SOUNDS.has(id):
		push_warning("Audio: som desconhecido %s" % id)
		return
	var def: Dictionary = SoundBank.SOUNDS[id]
	var files: Array = def["files"]
	var stream: AudioStream = _stream(files[_rng.randi_range(0, files.size() - 1)] as String)
	if stream == null:
		return
	var pitch_var: float = JsonUtil.get_f(def, "pitch", 0.0)
	var pitch: float = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	var db: float = JsonUtil.get_f(def, "db", 0.0) + volume_offset_db
	var bus: StringName = def.get("bus", &"SFX")
	if pos.is_finite():
		var p: AudioStreamPlayer3D = _players_3d[_next_3d]
		_next_3d = (_next_3d + 1) % _players_3d.size()
		p.stop()
		p.stream = stream
		p.bus = bus
		p.volume_db = db
		p.pitch_scale = pitch
		p.global_position = pos
		p.play()
	else:
		var p2: AudioStreamPlayer = _players_2d[_next_2d]
		_next_2d = (_next_2d + 1) % _players_2d.size()
		p2.stop()
		p2.stream = stream
		p2.bus = bus
		p2.volume_db = db
		p2.pitch_scale = pitch
		p2.play()
