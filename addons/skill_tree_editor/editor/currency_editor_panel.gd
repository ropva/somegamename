@tool
class_name SkillTreeCurrencyEditorPanel
extends AcceptDialog

const CURRENCY_SCRIPT := preload("res://addons/skill_tree_editor/scripts/skill_tree_currency_data.gd")

signal currencies_changed

@onready var currency_list: ItemList = %CurrencyList
@onready var key_edit: LineEdit = %KeyEdit
@onready var initial_amount: SpinBox = %InitialAmount
@onready var icon_picker: EditorResourcePicker = %IconPicker
@onready var translations_box: VBoxContainer = %TranslationsBox
@onready var create_button: Button = %CreateButton
@onready var update_button: Button = %UpdateButton
@onready var delete_button: Button = %DeleteButton
@onready var hint_label: Label = %HintLabel

var tree_data: SkillTreeData
var editor_language := "ru"
var selected_index := -1
var translation_edits: Dictionary = {}
var short_translation_edits: Dictionary = {}

func _ready() -> void:
	currency_list.item_selected.connect(_on_currency_selected)
	create_button.pressed.connect(_create_currency)
	update_button.pressed.connect(_update_currency)
	delete_button.pressed.connect(_delete_currency)

func configure(data: SkillTreeData, language: String) -> void:
	tree_data = data
	editor_language = language
	_refresh_list()
	_clear_form()
	_apply_language()

func _refresh_list(select_index := -1) -> void:
	currency_list.clear()
	if not tree_data:
		return
	for currency in tree_data.currencies:
		if not currency:
			continue
		var key := str(currency.get("key"))
		var locale := "en" if editor_language == "en" else "ru"
		var name := str((currency.get("translations") as Dictionary).get(locale, key))
		currency_list.add_item("%s — %s" % [name, key])
	if select_index >= 0 and select_index < currency_list.item_count:
		currency_list.select(select_index)
		_on_currency_selected(select_index)

func _clear_form() -> void:
	selected_index = -1
	key_edit.text = ""
	key_edit.editable = true
	initial_amount.value = 0
	icon_picker.edited_resource = null
	translation_edits.clear()
	short_translation_edits.clear()
	_rebuild_translation_inputs({}, {})
	update_button.disabled = true
	delete_button.disabled = true
	hint_label.text = ""

func _on_currency_selected(index: int) -> void:
	if not tree_data or index < 0 or index >= tree_data.currencies.size():
		return
	var currency := tree_data.currencies[index]
	if not currency:
		return
	selected_index = index
	key_edit.text = str(currency.get("key"))
	key_edit.editable = false
	initial_amount.value = int(currency.get("initial_amount"))
	icon_picker.edited_resource = currency.get("icon") as Resource
	_rebuild_translation_inputs(currency.get("translations") as Dictionary, currency.get("short_translations") as Dictionary)
	update_button.disabled = false
	delete_button.disabled = tree_data.currencies.size() <= 1
	hint_label.text = ""

func _rebuild_translation_inputs(values: Dictionary, short_values: Dictionary) -> void:
	for child in translations_box.get_children():
		child.queue_free()
	translation_edits.clear()
	short_translation_edits.clear()
	if not tree_data:
		return
	for locale_data in tree_data.get_locales():
		var locale_key := str(locale_data.get("key", ""))
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(locale_data.get("name", locale_key))
		label.custom_minimum_size.x = 76
		row.add_child(label)
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Name" if editor_language == "en" else "Название"
		name_edit.text = str(values.get(locale_key, ""))
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_edit)
		var short_edit := LineEdit.new()
		short_edit.placeholder_text = "Short" if editor_language == "en" else "Сокр."
		short_edit.text = str(short_values.get(locale_key, ""))
		short_edit.custom_minimum_size.x = 74
		row.add_child(short_edit)
		translation_edits[locale_key] = name_edit
		short_translation_edits[locale_key] = short_edit
		translations_box.add_child(row)

func _create_currency() -> void:
	if not tree_data:
		return
	var key := CURRENCY_SCRIPT.normalize_key(key_edit.text)
	if not CURRENCY_SCRIPT.is_valid_key(key) or tree_data.get_currency(key):
		hint_label.text = "Invalid or duplicate key" if editor_language == "en" else "Некорректный или повторяющийся ключ"
		return
	var currency: Resource = CURRENCY_SCRIPT.new()
	currency.set("key", key)
	_apply_form_to_currency(currency)
	tree_data.currencies.append(currency)
	currencies_changed.emit()
	_refresh_list(tree_data.currencies.size() - 1)

func _update_currency() -> void:
	if not tree_data or selected_index < 0 or selected_index >= tree_data.currencies.size():
		return
	var currency := tree_data.currencies[selected_index]
	if not currency:
		return
	_apply_form_to_currency(currency)
	currencies_changed.emit()
	_refresh_list(selected_index)

func _delete_currency() -> void:
	if not tree_data or selected_index < 0 or tree_data.currencies.size() <= 1:
		return
	var deleted := tree_data.currencies[selected_index]
	var deleted_key := str(deleted.get("key")) if deleted else ""
	tree_data.currencies.remove_at(selected_index)
	var fallback := tree_data.get_base_currency()
	var fallback_key := str(fallback.get("key")) if fallback else ""
	for skill in tree_data.skills:
		if skill and skill.currency_key == deleted_key:
			skill.currency_key = fallback_key
	currencies_changed.emit()
	_refresh_list(maxi(0, selected_index - 1))

func _apply_form_to_currency(currency: Resource) -> void:
	var names := {}
	var short_names := {}
	for locale_key in translation_edits:
		names[locale_key] = (translation_edits[locale_key] as LineEdit).text.strip_edges()
		short_names[locale_key] = (short_translation_edits[locale_key] as LineEdit).text.strip_edges()
	currency.set("translations", names)
	currency.set("short_translations", short_names)
	currency.set("icon", icon_picker.edited_resource as Texture2D)
	currency.set("initial_amount", maxi(0, int(initial_amount.value)))

func _apply_language() -> void:
	title = "Currencies" if editor_language == "en" else "Валюты"
	ok_button_text = "Back" if editor_language == "en" else "Назад"
	create_button.text = "Create" if editor_language == "en" else "Создать"
	update_button.text = "Update" if editor_language == "en" else "Изменить"
	delete_button.text = "Delete" if editor_language == "en" else "Удалить"
