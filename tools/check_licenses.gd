extends SceneTree
## Falha se algum arquivo em res://assets/ não estiver citado em ASSETS_LICENSES.md
## (roteiro, seção 9). Cada asset é citado pelo caminho relativo a assets/.
## Uso: godot --headless --path . -s res://tools/check_licenses.gd

const IGNORED_EXT: Array[String] = ["import", "uid", "gdignore", "md"]


func _initialize() -> void:
	var registry: String = FileAccess.get_file_as_string("res://ASSETS_LICENSES.md")
	if registry.is_empty():
		push_error("check_licenses: ASSETS_LICENSES.md ausente ou vazio.")
		quit(1)
		return
	var files: PackedStringArray = []
	_collect("res://assets", files)
	var missing: PackedStringArray = []
	for f: String in files:
		var rel: String = f.trim_prefix("res://assets/")
		if not registry.contains(rel):
			missing.append(rel)
	if missing.is_empty():
		print("check_licenses: APROVADO (%d arquivos de asset registrados)." % files.size())
		quit(0)
	else:
		for m: String in missing:
			printerr("check_licenses: sem licença registrada: assets/%s" % m)
		quit(1)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.get_extension() in IGNORED_EXT:
			continue
		out.append(dir_path.path_join(file))
