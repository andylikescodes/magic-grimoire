class_name SaveManager extends Node

## ── Save/Load System ──
const SAVE_DIR = "user://saves/"
const SAVE_EXT = ".json"

var current_save_name: String = ""

## ── Save Game ──

func save_game(save_name: String, grimoire: GrimoireData, summoner: SummonerData,
			   story_progress: Dictionary = {}) -> bool:

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var save_data = {
		"save_name": save_name,
		"timestamp": Time.get_datetime_string_from_system(),
		"summoner": summoner.to_dict(),
		"grimoire": grimoire.to_dict(),
		"story_progress": story_progress,
		"version": "0.1.0",
	}

	var path = SAVE_DIR + save_name + SAVE_EXT
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	current_save_name = save_name
	return true


func load_game(save_name: String, card_lookup: Callable) -> Dictionary:
	"""Returns save data dict, or empty dict on failure."""
	var path = SAVE_DIR + save_name + SAVE_EXT
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return {}

	current_save_name = save_name
	return json.get_data()


func list_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return saves

	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return saves

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(SAVE_EXT):
			saves.append({
				"name": file_name.trim_suffix(SAVE_EXT),
				"path": SAVE_DIR + file_name,
			})
		file_name = dir.get_next()
	dir.list_dir_end()

	return saves


func delete_save(save_name: String) -> bool:
	var path = SAVE_DIR + save_name + SAVE_EXT
	if FileAccess.file_exists(path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			dir.remove(path)
			return true
	return false
