extends Node
## Saves em user://saves/ (3 slots). Grava em arquivo temporário e renomeia,
## mantendo um .bak do último save válido. Save corrompido nunca derruba o jogo.

const SLOT_COUNT: int = 3

## Pasta alternativa, usada pelos testes.
var directory: String = "user://saves"


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [directory, slot]


func backup_path(slot: int) -> String:
	return slot_path(slot) + ".bak"


func save_slot(slot: int, data: Dictionary) -> Error:
	if slot < 0 or slot >= SLOT_COUNT:
		return ERR_INVALID_PARAMETER
	if not SaveCodec.validate(data):
		push_error("SaveSystem: recusado save inválido no slot %d." % slot)
		return ERR_INVALID_DATA
	var err: Error = DirAccess.make_dir_recursive_absolute(directory)
	if err != OK:
		return err
	data["saved_at_unix"] = int(Time.get_unix_time_from_system())
	var final_path: String = slot_path(slot)
	var tmp_path: String = final_path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(SaveCodec.encode(data))
	f.close()
	# O save atual (se válido) vira o backup antes de ser substituído.
	if FileAccess.file_exists(final_path) and not _read_valid(final_path).is_empty():
		DirAccess.copy_absolute(final_path, backup_path(slot))
	err = DirAccess.rename_absolute(tmp_path, final_path)
	if err == OK:
		Events.game_saved.emit(slot)
	return err


## Carrega o slot; se estiver corrompido, tenta o backup. {} se nada servir.
func load_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT:
		return {}
	var data: Dictionary = _read_valid(slot_path(slot))
	if data.is_empty():
		data = _read_valid(backup_path(slot))
		if not data.is_empty():
			push_warning("SaveSystem: slot %d corrompido, usando backup." % slot)
	if not data.is_empty():
		Events.game_loaded.emit(slot)
	return data


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(backup_path(slot))


func delete_slot(slot: int) -> void:
	for p: String in [slot_path(slot), backup_path(slot)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	return SaveCodec.decode(text)
