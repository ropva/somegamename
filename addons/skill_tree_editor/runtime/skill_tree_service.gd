## The addon's only public runtime entry point. Internal persistence and
## progression services are owned here so a copied addon needs one autoload.
class_name SkillTreeService
extends Node

const PLAYER_DATA_SCRIPT := preload("res://addons/skill_tree_editor/runtime/skill_tree_player_data.gd")
const STORAGE_SERVICE_SCRIPT := preload("res://addons/skill_tree_editor/runtime/skill_tree_storage.gd")
const PROGRESSION_SERVICE_SCRIPT := preload("res://addons/skill_tree_editor/runtime/skill_progression_service.gd")

signal configured(tree_id: String, slot: String)
signal currency_changed(currency_key: String, amount: int)
signal skill_purchased(skill_id: String, new_level: int)
signal skill_toggled(skill_id: String)
signal skill_state_changed(skill_id: String)
signal skill_purchase_failed(skill_id: String, reason: String)
signal state_changed(tree_id: String, snapshot: Dictionary)
signal progression_reset(summary: Dictionary)

var player_data = PLAYER_DATA_SCRIPT.new()
var progression: SkillProgressionService
var _storage: SkillTreeStorageService
var _tree_data: SkillTreeData
var _save_slot := "default"
var _runtime_translations: Array[Translation] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# These services deliberately are not autoloads. Keeping them as children
	# makes the public singleton the sole runtime dependency of game scripts.
	_storage = STORAGE_SERVICE_SCRIPT.new()
	_storage.name = "StorageService"
	add_child(_storage)
	_storage.state_changed.connect(_on_storage_state_changed)
	progression = PROGRESSION_SERVICE_SCRIPT.new()
	progression.name = "ProgressionService"
	progression.set_storage(_storage)
	add_child(progression)
	progression.currency_changed.connect(_on_currency_changed)
	progression.skill_purchased.connect(func(skill_id, level): skill_purchased.emit(skill_id, level))
	progression.skill_toggled.connect(func(skill_id): skill_toggled.emit(skill_id))
	progression.skill_state_changed.connect(func(skill_id): skill_state_changed.emit(skill_id))
	progression.skill_purchase_failed.connect(func(skill_id, reason): skill_purchase_failed.emit(skill_id, reason))
	player_data.bind(progression)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_skilltree_data"):
		if reset_debug():
			get_viewport().set_input_as_handled()

func configure(tree_data: SkillTreeData, save_slot := "default") -> SkillProgressionService:
	if not tree_data or not progression:
		return null
	tree_data.ensure_default_currency()
	_tree_data = tree_data
	_save_slot = save_slot
	_register_runtime_translations(tree_data)
	progression.configure(tree_data, save_slot)
	configured.emit(tree_data.tree_id, save_slot)
	return progression

func _exit_tree() -> void:
	_clear_runtime_translations()

func _register_runtime_translations(tree_data: SkillTreeData) -> void:
	_clear_runtime_translations()
	if not tree_data:
		return
	var translations: Dictionary = {}
	for locale_data in tree_data.get_locales():
		var locale_key := str(locale_data.get("key", ""))
		var translation := Translation.new()
		translation.locale = locale_key
		translations[locale_key] = translation
	var has_messages := false
	for currency in tree_data.currencies:
		if not currency:
			continue
		var currency_key := str(currency.get("key"))
		if currency_key.is_empty():
			continue
		for locale_key in translations:
			var full_name := str((currency.get("translations") as Dictionary).get(locale_key, currency_key))
			var short_name := str((currency.get("short_translations") as Dictionary).get(locale_key, full_name))
			translations[locale_key].add_message("CURRENCY_%s" % currency_key.to_upper(), full_name)
			translations[locale_key].add_message("CURRENCY_%s_SHORT" % currency_key.to_upper(), short_name)
		has_messages = true
	for stat in tree_data.player_stats:
		if not stat:
			continue
		var title_key := str(stat.get("title_key"))
		var stat_translations: Dictionary = stat.get("translations")
		for locale_key in translations:
			var fallback := title_key if not title_key.is_empty() else str(stat.get("key"))
			if locale_key == "ru" and not str(stat.get("title_ru")).is_empty():
				fallback = str(stat.get("title_ru"))
			elif locale_key == "en" and not str(stat.get("title_en")).is_empty():
				fallback = str(stat.get("title_en"))
			if not title_key.is_empty():
				translations[locale_key].add_message(title_key, str(stat_translations.get(locale_key, fallback)))
			_register_collection_messages(translations, stat)
			has_messages = true
	for skill in tree_data.skills:
		if not skill:
			continue
		var title_key := skill.get_title_key()
		for locale_key in translations:
			var fallback := skill.get_title_fallback()
			var localized := str((skill.title_translations as Dictionary).get(locale_key, fallback))
			translations[locale_key].add_message(title_key, localized)
		has_messages = true
	for skill in tree_data.skills:
		if not skill:
			continue
		for effect in skill.effects:
			if effect and effect.operation == SkillEffectData.Operation.ADD_UNIQUE and not effect.target_key.strip_edges().is_empty():
				var stat := tree_data.get_player_stat(effect.target_property)
				if stat:
					_register_dictionary_key(translations, stat, effect.target_key, effect.unique_key_translations)
					has_messages = true
	if not has_messages:
		return
	for translation in translations.values():
		TranslationServer.add_translation(translation)
		_runtime_translations.append(translation)

func _register_collection_messages(translations: Dictionary, stat: Resource) -> void:
	var stat_key := str(stat.get("key")).to_upper()
	var values: Variant = stat.call("get_base_value")
	var collection: Dictionary = stat.get("collection_translations")
	if values is Array:
		for index in values.size():
			var key := "TR_%s_%d" % [stat_key, index]
			_register_message(translations, key, str(index), collection.get(str(index), {}))
	elif values is Dictionary:
		for entry_key in values:
			_register_dictionary_key(translations, stat, str(entry_key), collection.get(str(entry_key), {}))

func _register_dictionary_key(translations: Dictionary, stat: Resource, entry_key: String, values: Dictionary) -> void:
	var key := "%s_%s" % [str(stat.get("key")).to_upper(), entry_key.to_upper()]
	_register_message(translations, key, entry_key, values)

func _register_message(translations: Dictionary, key: String, fallback: String, values: Dictionary) -> void:
	for locale_key in translations:
		translations[locale_key].add_message(key, str(values.get(locale_key, fallback)))

func _clear_runtime_translations() -> void:
	for translation in _runtime_translations:
		TranslationServer.remove_translation(translation)
	_runtime_translations.clear()

func get_tree_data() -> SkillTreeData:
	return _tree_data

func get_save_slot() -> String:
	return _save_slot

func get_level(skill_id: String) -> int:
	return progression.get_level(skill_id) if progression else 0

func get_skill_state(skill_id: String) -> String:
	return progression.get_skill_state(skill_id) if progression else SkillProgressionService.STATE_HIDDEN

func is_visible(skill_id: String) -> bool:
	return progression.is_visible(skill_id) if progression else false

func prerequisites_met(skill_id: String) -> bool:
	return progression.prerequisites_met(skill_id) if progression else false

func get_missing_prerequisites(skill_id: String) -> Array[Dictionary]:
	return progression.get_missing_prerequisites(skill_id) if progression else []

func purchase_skill(skill_id: String) -> bool:
	return progression.purchase_skill(skill_id) if progression else false

func has_toggle_effects(skill_id: String) -> bool:
	return progression.has_toggle_effects(skill_id) if progression else false

func toggle_skill(skill_id: String) -> bool:
	return progression.toggle_skill(skill_id) if progression else false

func is_toggle_skill_active(skill_id: String) -> bool:
	return progression.is_toggle_skill_active(skill_id) if progression else false

func set_toggle_skill_active(skill_id: String, active: bool) -> bool:
	return progression.set_toggle_skill_active(skill_id, active) if progression else false

func reset_progression_with_refund() -> Dictionary:
	var summary := progression.reset_progression_with_refund() if progression else {}
	if not summary.is_empty():
		progression_reset.emit(summary)
	return summary

func get_progression_reset_preview() -> Dictionary:
	return progression.get_progression_reset_preview() if progression else {}

func reset_debug() -> bool:
	return progression.reset_debug() if progression else false

func get_currency(currency_key: String) -> int:
	return progression.get_currency(currency_key) if progression else 0

func set_currency(currency_key: String, amount: int) -> bool:
	return progression.set_currency(currency_key, amount) if progression else false

func add_currency(currency_key: String, amount: int) -> bool:
	return progression.add_currency(currency_key, amount) if progression else false

func can_afford(currency_key: String, amount: int) -> bool:
	return progression.can_afford(currency_key, amount) if progression else false

func spend_currency(currency_key: String, amount: int) -> bool:
	return progression.spend_currency(currency_key, amount) if progression else false

func _on_currency_changed(currency_key: String, amount: int) -> void:
	currency_changed.emit(currency_key, amount)

func get_value(key: String, fallback: Variant = null) -> Variant:
	return player_data.get_value(key, fallback)

func set_value(key: String, value: Variant) -> bool:
	return player_data.set_value(key, value)

func export_state() -> Dictionary:
	return progression.export_state() if progression else {}

func import_state(snapshot: Dictionary) -> bool:
	return progression.import_state(snapshot) if progression else false

func clear_current_state() -> bool:
	return clear_state(_tree_data.tree_id, _save_slot) if _tree_data else false

func clear_state(tree_id: String, slot := "default") -> bool:
	if not _storage:
		return false
	var cleared := _storage.clear_state(tree_id, slot)
	if cleared and _tree_data and tree_id == _tree_data.tree_id and slot == _save_slot:
		progression.configure(_tree_data, _save_slot)
	return cleared

func clear_all_states() -> void:
	if _storage:
		_storage.clear_all_states()
	if _tree_data and progression:
		progression.configure(_tree_data, _save_slot)

func _on_storage_state_changed(tree_id: String, snapshot: Dictionary) -> void:
	state_changed.emit(tree_id, snapshot)
