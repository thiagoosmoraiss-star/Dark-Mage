extends SceneTree
## Empacota texturas PBR (ambientCG) no formato do Terrain3D:
##   <nome>_albedo_height.png = cor (RGB) + deslocamento (A)
##   <nome>_normal_rough.png  = normal OpenGL (RGB) + rugosidade (A)
## Uso: godot --headless --path . -s res://tools/pack_terrain_textures.gd -- --src=<pasta com zips extraídos>
## A pasta de origem tem uma subpasta por material (ex.: Grass004/Grass004_1K-JPG_Color.jpg).

const OUT_DIR: String = "res://assets/textures/terrain"
const SIZE: int = 1024


func _initialize() -> void:
	var src: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			src = a.substr(6)
	var dir: DirAccess = DirAccess.open(src)
	if dir == null:
		push_error("pack: pasta de origem inválida: %s" % src)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ok: int = 0
	for mat: String in dir.get_directories():
		var base: String = src.path_join(mat).path_join(mat + "_1K-JPG_")
		var color: Image = Image.load_from_file(base + "Color.jpg")
		var disp: Image = Image.load_from_file(base + "Displacement.jpg")
		var normal: Image = Image.load_from_file(base + "NormalGL.jpg")
		var rough: Image = Image.load_from_file(base + "Roughness.jpg")
		if color == null or disp == null or normal == null or rough == null:
			push_error("pack: arquivos faltando em %s" % mat)
			continue
		for img: Image in [color, disp, normal, rough]:
			if img.get_width() != SIZE:
				img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		var albedo_h: Image = Terrain3DUtil.pack_image(color, disp, false, false, false, 0)
		var normal_r: Image = Terrain3DUtil.pack_image(normal, rough, false, false, false, 0)
		var name_lc: String = mat.to_lower()
		albedo_h.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join(name_lc + "_albedo_height.png")))
		normal_r.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join(name_lc + "_normal_rough.png")))
		ok += 1
		print("pack: %s" % mat)
	print("pack: %d materiais empacotados em %s" % [ok, OUT_DIR])
	quit(0 if ok > 0 else 1)
