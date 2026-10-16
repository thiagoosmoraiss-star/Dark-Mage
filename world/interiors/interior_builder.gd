class_name InteriorBuilder
extends RefCounted
## Monta salas fechadas com as peças modulares do KayKit Dungeon (grade de 4 m):
## piso, paredes em dois andares, teto, portas, pilares, tochas com luz real e
## colisão. Usado por santuários e covis (cenas internas instanciadas).

const DIR: String = "res://assets/models/props/kaykit_dungeon/"
const TILE: float = 4.0

static var _scenes: Dictionary[String, PackedScene] = {}


static func piece(name: String) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load(DIR + name + ".glb") as PackedScene
	return _scenes[name].instantiate() as Node3D


## Sala w×d ladrilhos, `levels` andares de parede (4 m cada). `doors`: lista de
## [lado ("n","s","e","w"), índice do ladrilho]. `gaps`: ladrilhos sem piso
## (abismos). Retorna o corpo estático (colisão) com tudo dentro.
static func room(parent: Node3D, origin: Vector3, w: int, d: int, levels: int = 2, doors: Array = [],
		gaps: Array[Vector2i] = [], ceiling: bool = true, rng_seed: int = 1, skip_sides: Array[String] = []) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Room"
	body.collision_layer = 1
	parent.add_child(body)
	body.global_position = origin
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var floor_names: Array[String] = ["floor_tile_large", "floor_tile_large", "floor_tile_large", "floor_tile_large_rocks"]
	for j: int in d:
		for i: int in w:
			if gaps.has(Vector2i(i, j)):
				continue
			var f: Node3D = piece(floor_names[rng.randi_range(0, floor_names.size() - 1)])
			f.position = Vector3((i + 0.5) * TILE, 0.0, (j + 0.5) * TILE)
			f.rotation.y = PI * 0.5 * rng.randi_range(0, 3)
			body.add_child(f)
			_box(body, Vector3(TILE, 0.3, TILE), f.position - Vector3(0, 0.15, 0))
			if ceiling:
				var c: Node3D = piece("floor_tile_large")
				c.position = Vector3((i + 0.5) * TILE, levels * TILE + 0.1, (j + 0.5) * TILE)
				c.rotation.x = PI
				body.add_child(c)
	if ceiling:
		_box(body, Vector3(w * TILE, 0.4, d * TILE), Vector3(w * TILE * 0.5, levels * TILE + 0.3, d * TILE * 0.5))
	# Paredes (porta só no andar de baixo).
	for side: String in ["n", "s", "e", "w"]:
		if skip_sides.has(side):
			continue
		var count: int = w if side == "n" or side == "s" else d
		for k: int in count:
			for lv: int in levels:
				var is_door: bool = lv == 0 and doors.has([side, k])
				var name: String = "wall_doorway" if is_door else (["wall", "wall", "wall_cracked", "wall_arched"][rng.randi_range(0, 3)] if lv > 0 else ["wall", "wall", "wall_cracked"][rng.randi_range(0, 2)])
				var wall: Node3D = piece(name)
				var pos: Vector3
				var rot: float = 0.0
				match side:
					"n":
						pos = Vector3((k + 0.5) * TILE, lv * TILE, 0.0)
					"s":
						pos = Vector3((k + 0.5) * TILE, lv * TILE, d * TILE)
						rot = PI
					"w":
						pos = Vector3(0.0, lv * TILE, (k + 0.5) * TILE)
						rot = PI * 0.5
					"e":
						pos = Vector3(w * TILE, lv * TILE, (k + 0.5) * TILE)
						rot = -PI * 0.5
				wall.position = pos
				wall.rotation.y = rot
				body.add_child(wall)
				if not is_door:
					var size: Vector3 = Vector3(TILE, TILE, 1.0) if side == "n" or side == "s" else Vector3(1.0, TILE, TILE)
					_box(body, size, pos + Vector3(0, TILE * 0.5, 0))
				else:
					# Verga da porta (parte de cima continua sólida).
					var size2: Vector3 = Vector3(TILE, 1.0, 1.0) if side == "n" or side == "s" else Vector3(1.0, 1.0, TILE)
					_box(body, size2, pos + Vector3(0, TILE - 0.5, 0))
	# Pilares nos cantos internos e tochas nas paredes.
	for corner: Vector3 in [Vector3(1, 0, 1), Vector3(w * TILE - 1, 0, 1), Vector3(1, 0, d * TILE - 1), Vector3(w * TILE - 1, 0, d * TILE - 1)]:
		for lv: int in levels:
			var p: Node3D = piece("pillar")
			p.position = corner + Vector3.UP * lv * TILE
			body.add_child(p)
	var torch_every: int = 2
	for k: int in range(0, w, torch_every):
		add_torch(body, Vector3((k + 0.5) * TILE, 2.6, 0.55), 0.0)
		add_torch(body, Vector3((k + 0.5) * TILE, 2.6, d * TILE - 0.55), PI)
	for k: int in range(1, d, torch_every * 2):
		add_torch(body, Vector3(0.55, 2.6, (k + 0.5) * TILE), PI * 0.5)
		add_torch(body, Vector3(w * TILE - 0.55, 2.6, (k + 0.5) * TILE), -PI * 0.5)
	_set_world_layer(body)
	return body


## Peças de interior ficam na camada 1 (decals de telegrafia projetam nelas).
static func _set_world_layer(root: Node) -> void:
	for n: Node in root.find_children("*", "VisualInstance3D", true, false):
		(n as VisualInstance3D).layers = 1


static func add_torch(parent: Node3D, pos: Vector3, rot: float, color: Color = Color("ffb765")) -> OmniLight3D:
	var t: Node3D = piece("torch_mounted")
	t.position = pos
	t.rotation.y = rot
	parent.add_child(t)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.position = pos + Vector3(0, 0.6, 0) + Vector3(sin(rot), 0, cos(rot)) * 0.4
	parent.add_child(light)
	return light


static func _box(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)


## Ambiente de interior: fundo escuro, luz ambiente violeta fraca, glow e SSAO.
static func interior_environment() -> Environment:
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.015, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.26, 0.42)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.15
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_hdr_threshold = 1.0
	e.ssao_enabled = true
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_density = 0.012
	e.fog_light_color = Color(0.12, 0.08, 0.18)
	e.adjustment_enabled = true
	e.adjustment_color_correction = ColorGrading.lut_for(&"default")
	return e
