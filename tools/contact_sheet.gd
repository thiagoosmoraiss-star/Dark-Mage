extends SceneTree
## Junta várias capturas numa folha de contato (para revisão visual rápida).
## Uso: godot --headless --path . -s res://tools/contact_sheet.gd -- --dir=res://tests/golden/m1
##      [--out=res://build/sheets/m1.png] [--cols=2] [--width=640]


func _initialize() -> void:
	var dir_path: String = _arg("--dir", "res://tests/golden/m1")
	var out: String = _arg("--out", "res://build/sheets/%s.png" % dir_path.get_file())
	var cols: int = _arg("--cols", "2").to_int()
	var cell_w: int = _arg("--width", "640").to_int()
	var files: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("contact_sheet: pasta não encontrada %s" % dir_path)
		quit(1)
		return
	for f: String in dir.get_files():
		if f.get_extension() == "png":
			files.append(f)
	files.sort()
	if files.is_empty():
		quit(1)
		return
	var first: Image = Image.load_from_file(ProjectSettings.globalize_path(dir_path.path_join(files[0])))
	var cell_h: int = roundi(float(first.get_height()) * cell_w / first.get_width())
	var rows: int = ceili(float(files.size()) / cols)
	var sheet: Image = Image.create_empty(cols * cell_w, rows * cell_h, false, Image.FORMAT_RGB8)
	for i: int in files.size():
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(dir_path.path_join(files[i])))
		img.convert(Image.FORMAT_RGB8)
		img.resize(cell_w, cell_h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(0, 0, cell_w, cell_h), Vector2i((i % cols) * cell_w, (i / cols) * cell_h))
	var abs_out: String = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())
	sheet.save_png(abs_out)
	print("contact_sheet: %s (%d imagens)" % [abs_out, files.size()])
	quit(0)


static func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback
