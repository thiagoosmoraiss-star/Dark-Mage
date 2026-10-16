extends SceneTree
## Capturas para o golden visual e a autocrítica. Precisa de renderização (sem --headless).
##
## Uma captura:
##   godot --path . -s res://tools/capture.gd -- --scene=res://levels/x.tscn --out=res://build/x.png
## Várias poses (JSON com lista de {name, scene, hour, cam, target, fov?, coverage?, corruption?, frames?}):
##   godot --path . -s res://tools/capture.gd -- --shots=res://tests/golden/m1/shots.json --outdir=res://tests/golden/m1
## Opções: --overlay (mostra o overlay F3), --frames=N (padrão 90), --preset=low|medium|high|ultra (padrão high).

var _shots: Array = []
var _index: int = -1
var _frames_left: int = 0
var _default_frames: int = 90
var _outdir: String = ""
var _scene_path: String = ""
var _scene: Node = null
var _camera: Camera3D = null
var _failed: bool = false


func _initialize() -> void:
	_default_frames = _arg("--frames", "90").to_int()
	var shots_path: String = _arg("--shots", "")
	if shots_path != "":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(shots_path))
		if not (parsed is Array):
			push_error("capture: JSON de poses inválido: %s" % shots_path)
			quit(1)
			return
		_shots = parsed
		_outdir = _arg("--outdir", shots_path.get_base_dir())
	else:
		_shots = [{"name": _arg("--out", "res://build/captures/capture.png").get_file().get_basename(),
			"scene": _arg("--scene", "res://levels/test_scene.tscn")}]
		_outdir = _arg("--out", "res://build/captures/capture.png").get_base_dir()
	_next_shot()


func _next_shot() -> void:
	_index += 1
	if _index >= _shots.size():
		quit(1 if _failed else 0)
		return
	var shot: Dictionary = _shots[_index]
	var scene_path: String = JsonUtil.get_s(shot, "scene", _scene_path if _scene_path != "" else "res://levels/test_scene.tscn")
	if scene_path != _scene_path:
		if _scene != null:
			_scene.queue_free()
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			push_error("capture: cena não encontrada: %s" % scene_path)
			quit(1)
			return
		_scene = packed.instantiate()
		root.add_child(_scene)
		_scene_path = scene_path
		_camera = null
	_frames_left = JsonUtil.get_i(shot, "frames", _default_frames)
	_setup_shot.call_deferred(shot)


func _setup_shot(shot: Dictionary) -> void:
	# Preset fixo nas capturas (padrão: high) para o golden não depender da máquina.
	var settings: Node = root.get_node_or_null(^"Settings")
	if settings != null and str(settings.call(&"current_preset")) != _arg("--preset", "high"):
		settings.call(&"set_preset", StringName(_arg("--preset", "high")))
	# Acesso dinâmico: este script compila antes dos autoloads, então não pode
	# depender estaticamente de classes que os usam (como Atmosphere).
	var atmo: Node = root.get_tree().get_first_node_in_group(&"atmosphere")
	if atmo != null:
		atmo.set(&"running", false)
		if shot.has("hour"):
			atmo.set(&"hours", JsonUtil.get_f(shot, "hour"))
		if shot.has("coverage"):
			atmo.set(&"cloud_coverage", JsonUtil.get_f(shot, "coverage"))
		atmo.set(&"corruption", JsonUtil.get_f(shot, "corruption", 0.0))
		atmo.call(&"apply_now")
	var player: Node3D = root.get_tree().get_first_node_in_group(&"player") as Node3D
	var interiors_node: Node = root.get_tree().get_first_node_in_group(&"interiors")
	if interiors_node != null and shot.has("player"):
		interiors_node.call(&"force_outdoor")
	if player != null and shot.has("player"):
		var pp: Vector3 = JsonUtil.vec3(shot["player"])
		var terrain_node: Node = root.get_tree().get_first_node_in_group(&"island_terrain")
		if terrain_node != null:
			pp.y = JsonUtil.num(terrain_node.call(&"height_at", pp), pp.y) + 0.05
		player.call(&"teleport", pp)
		player.set(&"god_mode", true)
		player.rotation.y = deg_to_rad(JsonUtil.get_f(shot, "player_yaw", 0.0))
		var rig: Node3D = player.get_node_or_null(^"CameraRig") as Node3D
		if rig != null:
			rig.set_process(true)
			rig.set(&"yaw", player.rotation.y + deg_to_rad(JsonUtil.get_f(shot, "cam_yaw", 0.0)))
			rig.set(&"pitch", deg_to_rad(JsonUtil.get_f(shot, "cam_pitch", -12.0)))
			rig.global_position = pp + Vector3.UP * 1.55
	if shot.has("map"):
		var world_node: Node = root.get_tree().get_first_node_in_group(&"world")
		var ms: Node = world_node.get(&"map_screen") if world_node != null else null
		if ms != null:
			var fog: RefCounted = world_node.get(&"fog")
			for p: Variant in shot.get("reveal", []):
				fog.call(&"reveal", JsonUtil.vec3(p), 160.0)
			if not ms.call(&"is_open"):
				ms.call(&"toggle")
	# Estado de jogo para as capturas de UI (itens, almas, flags, XP).
	var gs: Node = root.get_node_or_null(^"/root/GameState")
	var inv: Node = root.get_node_or_null(^"/root/Inventory")
	if shot.has("souls") and gs != null:
		gs.call(&"add_souls", JsonUtil.get_i(shot, "souls"))
	if shot.has("xp") and gs != null:
		gs.call(&"add_xp", JsonUtil.get_i(shot, "xp"))
	if shot.has("flags") and gs != null:
		for f: Variant in (shot["flags"] as Array):
			gs.call(&"set_flag", str(f))
	if shot.has("give") and inv != null:
		for g: Variant in (shot["give"] as Array):
			inv.call(&"add", str((g as Array)[0]), roundi(JsonUtil.num((g as Array)[1])))
	if shot.has("equip") and inv != null:
		for e: Variant in (shot["equip"] as Array):
			for i: int in 36:
				if str(inv.call(&"id_at", i)) == str(e):
					inv.call(&"equip_from", i)
					break
	if shot.get("hide_hud", false) == true:
		var wn2: Node = root.get_tree().get_first_node_in_group(&"world")
		var hud_layer: CanvasLayer = wn2.get(&"hud") as CanvasLayer if wn2 != null else null
		if hud_layer != null:
			hud_layer.visible = false
	if shot.has("enter") and player != null:
		var wn: Node = root.get_tree().get_first_node_in_group(&"world")
		var structs: Dictionary = wn.get(&"structures")
		var ent: Node = structs.get(StringName(str(shot["enter"])))
		if ent != null:
			ent.call(&"interact", player)
			# O painel de dica pausa o jogo: fecha para a captura seguir.
			await root.get_tree().create_timer(1.0).timeout
			var panels: Node = root.get_tree().get_first_node_in_group(&"world_panels")
			if panels != null:
				panels.call(&"close")
	if shot.has("move") and player != null:
		# Desloca o jogador depois de entrar num interior (relativo ao ponto atual).
		await root.get_tree().create_timer(1.2).timeout
		var mv: Vector3 = player.global_position + JsonUtil.vec3(shot["move"])
		player.call(&"teleport", mv)
		player.rotation.y = deg_to_rad(JsonUtil.get_f(shot, "player_yaw", 0.0))
	if shot.has("ui"):
		await root.get_tree().create_timer(0.6).timeout
		var ui: Node = root.get_tree().get_first_node_in_group(&"game_ui")
		var which: String = str(shot["ui"])
		if ui != null:
			ui.call(&"close_all")
			match which:
				"pause":
					ui.call(&"open_pause")
				"options":
					ui.call(&"open_options")
				"shop":
					ui.call(&"open_shop")
				_:
					ui.call(&"open_game_menu", ["inventory", "character", "spells", "journal"].find(which))
		if shot.has("tab"):
			await root.get_tree().process_frame
			var top: Node = ui.get_child(ui.get_child_count() - 1)
			top.call(&"set_tab", JsonUtil.get_i(shot, "tab"))
		if shot.has("focus"):
			await root.get_tree().process_frame
			var fc: Control = root.find_child(str(shot["focus"]), true, false) as Control
			if fc != null:
				fc.grab_focus()
	if shot.has("cast") and player != null:
		var caster: Node = player.get_node_or_null(^"SpellCaster")
		if caster != null:
			var spell: Resource = (load("res://data/spells/%s.tres" % str(shot["cast"])) as Resource)
			var cds: RefCounted = caster.get(&"cooldowns")
			cds.call(&"reset")
			caster.call(&"cast_spell", spell, JsonUtil.get_f(shot, "charge", 0.0))
	if not shot.has("cam") and not shot.has("cam_rel") and player != null:
		# Sem câmera definida: volta para a câmera do jogador.
		var rig_cam: Node = player.get_node_or_null(^"CameraRig/SpringArm/Camera3D")
		if rig_cam != null:
			(rig_cam as Camera3D).current = true
			var tn: Node = root.get_tree().get_first_node_in_group(&"island_terrain")
			if tn != null:
				(tn.get(&"terrain") as Node).call(&"set_camera", rig_cam)
	if shot.has("cam_rel") and player != null:
		var base: Vector3 = player.global_position
		shot["cam"] = _arr(base + player.global_basis * JsonUtil.vec3(shot["cam_rel"]))
		shot["target"] = _arr(base + player.global_basis * JsonUtil.vec3(shot.get("target_rel", [0.0, 1.2, 0.0])))
	if shot.has("cam"):
		# Câmera própria da captura (a da cena pode estar presa a um SpringArm).
		if _camera == null or not is_instance_valid(_camera):
			_camera = Camera3D.new()
			_camera.name = "CaptureCamera"
			_scene.add_child(_camera)
		var terrain_node: Node = root.get_tree().get_first_node_in_group(&"island_terrain")
		if terrain_node != null:
			var t3d: Node = terrain_node.get(&"terrain")
			if t3d != null:
				t3d.call(&"set_camera", _camera)
		_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_camera.global_position = JsonUtil.vec3(shot["cam"])
		_camera.fov = JsonUtil.get_f(shot, "fov", 70.0)
		_camera.far = 4000.0
		_camera.look_at(JsonUtil.vec3(shot.get("target")))
		_camera.current = true


func _process(_delta: float) -> bool:
	if _index >= _shots.size() or _index < 0:
		return false
	_frames_left -= 1
	if _frames_left > 0:
		return false
	var shot: Dictionary = _shots[_index]
	var img: Image = root.get_texture().get_image()
	var out: String = _outdir.path_join("%s.png" % str(shot.get("name", "shot_%d" % _index)))
	var abs_path: String = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err: Error = img.save_png(abs_path)
	if err != OK:
		_failed = true
	print("capture: %s (%dx%d) %s | GPU %s via %s" % [out, img.get_width(), img.get_height(), error_string(err),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name()])
	_next_shot()
	return false


static func _arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback
