class_name SkillTreeStorageService
extends Node

const STATE_SCRIPT := preload("res://addons/skill_tree_editor/runtime/skill_tree_state.gd")

signal state_changed(tree_id: String, snapshot: Dictionary)

const ROOT_PATH := "user://skill_tree"
var _states: Dictionary = {}

func _key(tree_id: String, slot: String) -> String:
	return "%s::%s" % [slot, tree_id]

func _path(tree_id: String, slot: String) -> String:
	var safe_slot := slot.strip_edges().replace("/", "_").replace("\\", "_")
	var safe_tree := tree_id.strip_edges().replace("/", "_").replace("\\", "_")
	return "%s/%s/%s.json" % [ROOT_PATH, safe_slot if not safe_slot.is_empty() else "default", safe_tree if not safe_tree.is_empty() else "main"]

func get_state(tree_id: String, slot := "default") -> SkillTreeState:
	var key := _key(tree_id, slot)
	if _states.has(key):
		return _states[key]
	var state := SkillTreeState.new()
	state.tree_id = tree_id
	var path := _path(tree_id, slot)
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				state = SkillTreeState.from_dictionary(parsed, tree_id)
	_states[key] = state
	return state

func has_state(tree_id: String, slot := "default") -> bool:
	return FileAccess.file_exists(_path(tree_id, slot)) or _states.has(_key(tree_id, slot))

func save_state(state: SkillTreeState, slot := "default") -> bool:
	if not state:
		return false
	var path := _path(state.tree_id, slot)
	var directory := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	# Write a sibling temporary file then rename it, so a crash cannot leave a
	# partially written JSON file in place of the previous valid state.
	var temp_path := "%s.tmp" % path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(state.to_dictionary(), "\t"))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))
	if error != OK:
		return false
	_states[_key(state.tree_id, slot)] = state
	state_changed.emit(state.tree_id, state.to_dictionary())
	return true

func clear_state(tree_id: String, slot := "default") -> bool:
	_states.erase(_key(tree_id, slot))
	var path := _path(tree_id, slot)
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

func clear_all_states() -> void:
	_states.clear()
	var root_path := ProjectSettings.globalize_path(ROOT_PATH)
	if not DirAccess.dir_exists_absolute(root_path):
		return
	_clear_directory(root_path)

func _clear_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if not directory:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var entry_path := path.path_join(entry)
		if directory.current_is_dir():
			_clear_directory(entry_path)
			DirAccess.remove_absolute(entry_path)
		else:
			DirAccess.remove_absolute(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()

func export_state(tree_id: String, slot := "default") -> Dictionary:
	return get_state(tree_id, slot).to_dictionary()

func import_state(snapshot: Dictionary, slot := "default") -> bool:
	var state := SkillTreeState.from_dictionary(snapshot)
	return save_state(state, slot)
