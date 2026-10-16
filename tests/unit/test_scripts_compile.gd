extends GdUnitTestSuite
## Todo script do projeto (fora de addons/) precisa compilar sem erros nem
## warnings tratados como erro. Pega scripts que nenhuma cena carrega no smoke.

const SKIP_DIRS: Array[String] = ["res://addons", "res://.godot", "res://build", "res://reports"]


func _collect(dir_path: String, out: PackedStringArray) -> void:
	if dir_path in SKIP_DIRS:
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub) if dir_path != "res://" else "res://" + sub, out)
	for file: String in dir.get_files():
		if file.get_extension() in ["gd", "gdshader"]:
			out.append(dir_path.path_join(file))


func test_all_scripts_and_shaders_load() -> void:
	var files: PackedStringArray = []
	_collect("res://", files)
	assert_int(files.size()).is_greater(10)
	for path: String in files:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		assert_object(res).override_failure_message("não carregou: %s" % path).is_not_null()
