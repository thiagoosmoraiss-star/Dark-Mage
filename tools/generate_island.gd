extends SceneTree
## Gera a ilha com a seed oficial e grava os dados do Terrain3D em world/island/data.
## Uso: godot --headless --path . -s res://tools/generate_island.gd [-- --seed=N --res=2048]
## Grava também: region_map.png (512², id da região por pixel), preview.png (mapa
## sombreado para revisão) e meta.json (seed, resolução, hash da altura).

const DATA_DIR: String = "res://world/island/data"
const WORLD_SEED: int = 20261016  # igual a Rng.WORLD_SEED (este script não usa autoloads)


func _initialize() -> void:
	var seed_value: int = _arg("--seed", str(WORLD_SEED)).to_int()
	var res: int = _arg("--res", "2048").to_int()
	var t0: int = Time.get_ticks_msec()
	var gen: IslandGenerator = IslandGenerator.new(seed_value, res)
	gen.generate()
	print("island: alturas %d² em %.1f s (hash %08x)" % [res, (Time.get_ticks_msec() - t0) / 1000.0, gen.height_hash()])
	var t1: int = Time.get_ticks_msec()
	var control: Image = gen.control_image(_encode)
	print("island: controle em %.1f s" % ((Time.get_ticks_msec() - t1) / 1000.0))
	var t2: int = Time.get_ticks_msec()
	var color: Image = gen.color_image()
	print("island: cor em %.1f s" % ((Time.get_ticks_msec() - t2) / 1000.0))

	var abs_dir: String = ProjectSettings.globalize_path(DATA_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	for f: String in DirAccess.get_files_at(abs_dir):
		if f.begins_with("terrain3d") and f.ends_with(".res"):
			DirAccess.remove_absolute(abs_dir.path_join(f))

	_save_terrain.call_deferred(gen, control, color, seed_value, res, t0)


func _save_terrain(gen: IslandGenerator, control: Image, color: Image, seed_value: int, res: int, t0: int) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(DATA_DIR)
	var cam: Camera3D = Camera3D.new()
	root.add_child(cam)
	var terrain: Terrain3D = Terrain3D.new()
	terrain.vertex_spacing = _spacing(res)
	terrain.set_camera(cam)
	terrain.data_directory = DATA_DIR
	root.add_child(terrain)
	await process_frame
	terrain.data.import_images([gen.height_image(), control, color],
		Vector3(-IslandLayout.HALF, 0.0, -IslandLayout.HALF), 0.0, 1.0)
	terrain.data.save_directory(DATA_DIR)
	print("island: %d regiões do Terrain3D gravadas em %s" % [terrain.data.get_region_count(), DATA_DIR])

	var regions: Image = gen.region_image()
	regions.resize(512, 512, Image.INTERPOLATE_NEAREST)
	regions.save_png(abs_dir.path_join("region_map.png"))
	_preview(gen).save_png(abs_dir.path_join("preview.png"))
	var meta: Dictionary = {"seed": seed_value, "resolution": res, "height_hash": "%08x" % gen.height_hash(),
		"generator": "IslandGenerator v1"}
	var f: FileAccess = FileAccess.open(abs_dir.path_join("meta.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	terrain.queue_free()
	print("island: concluído em %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


static func _spacing(res: int) -> float:
	return IslandLayout.WORLD_SIZE / res


static func _encode(base: int, overlay: int, blend: int) -> int:
	return Terrain3DUtil.enc_base(base) | Terrain3DUtil.enc_overlay(overlay) | Terrain3DUtil.enc_blend(blend)


## Mapa sombreado colorido por altura/região para a revisão visual.
static func _preview(gen: IslandGenerator) -> Image:
	var n: int = 512
	var step: int = gen.resolution / n
	var img: Image = Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var palette: Dictionary = {
		IslandLayout.Region.SEA: Color("2e4a7a"), IslandLayout.Region.COAST: Color("d8c79a"),
		IslandLayout.Region.VALLEY: Color("b9a24a"), IslandLayout.Region.FOREST: Color("3f6a34"),
		IslandLayout.Region.PEAKS: Color("c9c9d6"), IslandLayout.Region.BURNT: Color("7a3a2a"),
		IslandLayout.Region.SWAMP: Color("5a3a7a"), IslandLayout.Region.CITADEL: Color("8a8070"),
	}
	var res: int = gen.resolution
	for z: int in n:
		for x: int in n:
			var i: int = (z * step) * res + x * step
			var h: float = gen.heights[i]
			var hx: float = gen.heights[mini(i + step, res * res - 1)]
			var shade: float = clampf(0.75 + (h - hx) * 0.08, 0.35, 1.25)
			var c: Color = palette.get(gen.region_ids[i], Color.MAGENTA)
			if h < 0.0:
				c = Color("2e4a7a").darkened(clampf(-h / 40.0, 0.0, 0.6))
				shade = 1.0
			img.set_pixel(x, z, Color(c.r * shade, c.g * shade, c.b * shade))
	return img


static func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback
