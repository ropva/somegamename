@tool
extends Control

const TREE_SCRIPT = preload("res://addons/skill_tree_editor/scripts/skill_tree_data.gd")
const SKILL_SCRIPT = preload("res://addons/skill_tree_editor/scripts/skill_data.gd")
const GRID_SIZE := 96.0
const CARD_SIZE := Vector2(384.0, 384.0)
const REQUIREMENT_SCRIPT = preload("res://addons/skill_tree_editor/scripts/skill_requirement_data.gd")
const EFFECT_SCRIPT = preload("res://addons/skill_tree_editor/scripts/skill_effect_data.gd")
const STAT_SCRIPT = preload("res://addons/skill_tree_editor/scripts/skill_tree_stat_data.gd")
const CURRENCY_SCRIPT = preload("res://addons/skill_tree_editor/scripts/skill_tree_currency_data.gd")
const CURRENCY_EDITOR_SCENE = preload("res://addons/skill_tree_editor/editor/currency_editor_panel.tscn")
const VALIDATOR = preload("res://addons/skill_tree_editor/scripts/skill_tree_validator.gd")

var plugin: EditorPlugin
var graph: GraphEdit
var status_label: Label
var search_edit: LineEdit
var tree_name_edit: LineEdit
var zoom_label: Label
var language_option: OptionButton
var language := "ru"
var origin_element: GraphElement
var center_request_id := 0
var current_tree: SkillTreeData
var current_path := ""
var selected_skill_id := ""
var node_by_id: Dictionary = {}
var expanded_sections: Dictionary = {}
var open_dialog: EditorFileDialog
var save_dialog: EditorFileDialog
var context_menu: PopupMenu
var clear_dialog: ConfirmationDialog
var category_dialog: AcceptDialog
var category_edit: LineEdit
var category_list: ItemList
var category_rename_edit: LineEdit
var category_dialog_root: VBoxContainer
var stats_dialog: AcceptDialog
var stats_list: ItemList
var stat_key_edit: LineEdit
var stat_translations_container: VBoxContainer
var stat_translation_edits: Dictionary = {}
var stat_type_option: OptionButton
var stat_array_element_type_option: OptionButton
var stat_base_value: SpinBox
var stat_bool_value: CheckButton
var stats_hint_label: Label
var stat_array_base_value: LineEdit
var stat_array_base_row: HBoxContainer
var stat_array_entries: VBoxContainer
var stat_array_draft: Array[Dictionary] = []
var stat_dictionary_row: VBoxContainer
var stat_dictionary_entries: VBoxContainer
var stat_dictionary_draft: Array[Dictionary] = []
var edit_stat_button: Button
var locales_dialog: AcceptDialog
var locales_list: ItemList
var locale_key_edit: LineEdit
var locale_name_edit: LineEdit
var colors_dialog: AcceptDialog
var currency_dialog
var settings_dialog: AcceptDialog
var general_dialog: AcceptDialog
var refund_percent_label: Label
var refund_percent_spin: SpinBox
var state_colors_panel: VBoxContainer
var state_colors_toggle: Button
var state_color_buttons: Dictionary = {}
var context_position := Vector2.ZERO
var context_skill_id := ""
var clipboard_skill: SkillData
var undo_redo: EditorUndoRedoManager
var is_rebuilding := false
var is_opening := false
var is_saving := false
var dirty := false
var status_message_time_left := 0.0

func _ready() -> void:
	if not is_node_ready():
		return
	undo_redo = plugin.get_undo_redo() if plugin else null
	_build_ui()
	# The addon is intentionally data-free. Game projects create/open their own
	# SkillTreeData resource through Save As.
	new_tree(false)

func _process(_delta: float) -> void:
	if status_message_time_left > 0.0:
		status_message_time_left -= _delta
		if status_message_time_left <= 0.0 and status_label:
			status_label.text = ""
			status_label.visible = false
	if not graph or is_rebuilding:
		return
	for skill_id in node_by_id:
		var node: GraphNode = node_by_id[skill_id]
		var skill := current_tree.get_skill(skill_id) if current_tree else null
		if skill and node.position_offset != skill.editor_position:
			skill.editor_position = node.position_offset
			dirty = true

func _show_status(message: String) -> void:
	if not status_label:
		return
	status_label.text = message
	status_label.visible = not message.is_empty()
	status_message_time_left = 10.0

func _build_ui() -> void:
	var settings = plugin.get_editor_interface().get_editor_settings() if plugin else null
	language = str(settings.get_setting("skill_tree_editor/language")) if settings and settings.has_setting("skill_tree_editor/language") else _default_language()
	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var toolbar_margin := MarginContainer.new()
	toolbar_margin.name = "ToolbarMargin"
	toolbar_margin.add_theme_constant_override("margin_left", 8)
	toolbar_margin.add_theme_constant_override("margin_top", 6)
	toolbar_margin.add_theme_constant_override("margin_right", 8)
	toolbar_margin.add_theme_constant_override("margin_bottom", 6)
	root.add_child(toolbar_margin)
	var toolbar := HBoxContainer.new()
	toolbar.name = "Toolbar"
	toolbar.add_theme_constant_override("separation", 6)
	toolbar_margin.add_child(toolbar)
	tree_name_edit = LineEdit.new()
	tree_name_edit.name = "TreeName"
	tree_name_edit.placeholder_text = "Название дерева"
	tree_name_edit.custom_minimum_size.x = 132
	tree_name_edit.tooltip_text = "Название дерева"
	tree_name_edit.text_submitted.connect(_on_tree_name_submitted)
	tree_name_edit.focus_exited.connect(func(): _on_tree_name_submitted(tree_name_edit.text))
	toolbar.add_child(tree_name_edit)
	_add_toolbar_button(toolbar, "New", "Новое дерево")
	_add_toolbar_button(toolbar, "Open", "Открыть дерево")
	_add_toolbar_button(toolbar, "Save", "Сохранить", "Save")
	_add_toolbar_button(toolbar, "Save As", "Сохранить как", "SaveAs")
	_add_toolbar_button(toolbar, "Clear", "Очистить", "Clear")
	_add_toolbar_separator(toolbar)
	_add_toolbar_button(toolbar, "Undo", "Отменить", "Undo")
	_add_toolbar_button(toolbar, "Redo", "Вернуть", "Redo")
	_add_toolbar_separator(toolbar)
	_add_toolbar_button(toolbar, "Frame All", "Выделить все", "SelectAll")
	_add_toolbar_button(toolbar, "Center Origin", "Центр", "CenterView")
	_add_toolbar_separator(toolbar)
	_add_toolbar_button(toolbar, "Settings", "Настройки", "Tools")
	_add_toolbar_separator(toolbar)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Поиск навыка..."
	search_edit.custom_minimum_size.x = 140
	search_edit.text_changed.connect(_on_search_changed)
	toolbar.add_child(search_edit)
	var toolbar_spacer := Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)
	language_option = OptionButton.new()
	language_option.name = "Language"
	language_option.add_item("Русский")
	language_option.add_item("English")
	language_option.select(1 if language == "en" else 0)
	language_option.item_selected.connect(_set_language)
	toolbar.add_child(language_option)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.visible = false
	status_label.modulate = Color(0.85, 0.78, 0.45)

	var help := Label.new()
	help.text = "ПКМ по полю — создать навык. ПКМ по узлу — действия. Перетяните порт узла на другой порт, чтобы создать связь."
	help.modulate = Color(0.65, 0.68, 0.75)
	root.add_child(help)
	root.add_child(status_label)

	graph = GraphEdit.new()
	graph.name = "SkillGraph"
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.show_grid = true
	graph.snapping_enabled = true
	graph.snapping_distance = int(GRID_SIZE)
	graph.minimap_enabled = true
	graph.minimap_size = Vector2i(180, 120)
	var graph_panel := StyleBoxFlat.new()
	graph_panel.bg_color = Color("111521")
	graph_panel.border_width_left = 1
	graph_panel.border_width_top = 1
	graph_panel.border_width_right = 1
	graph_panel.border_width_bottom = 1
	graph_panel.border_color = Color("303a58")
	graph_panel.corner_radius_top_left = 6
	graph_panel.corner_radius_top_right = 6
	graph_panel.corner_radius_bottom_left = 6
	graph_panel.corner_radius_bottom_right = 6
	graph.add_theme_stylebox_override("panel", graph_panel)
	graph.add_theme_color_override("grid_minor", Color("202842"))
	graph.add_theme_color_override("grid_major", Color("39456d"))
	graph.gui_input.connect(_on_graph_gui_input)
	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)
	graph.delete_nodes_request.connect(_on_delete_nodes_request)
	graph.node_selected.connect(_on_node_selected)
	root.add_child(graph)
	_create_origin_element()
	_apply_language()

	context_menu = PopupMenu.new()
	context_menu.add_item("Создать навык", 1)
	context_menu.add_item("Вставить навык", 2)
	context_menu.add_separator()
	context_menu.add_item("Копировать", 3)
	context_menu.add_item("Дублировать", 4)
	context_menu.add_item("Удалить", 5)
	context_menu.add_item("Переместить в центр", 6)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(context_menu)
	category_dialog = AcceptDialog.new()
	category_dialog.title = "Категории"
	category_dialog.ok_button_text = "Закрыть"
	category_dialog_root = VBoxContainer.new()
	category_dialog_root.custom_minimum_size = Vector2(360, 260)
	category_dialog.add_child(category_dialog_root)
	category_list = ItemList.new()
	category_list.select_mode = ItemList.SELECT_SINGLE
	category_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_dialog_root.add_child(category_list)
	category_edit = LineEdit.new()
	category_edit.placeholder_text = "Новая категория"
	category_dialog_root.add_child(category_edit)
	var category_actions := HBoxContainer.new()
	category_dialog_root.add_child(category_actions)
	var add_category_button := Button.new()
	add_category_button.text = "Создать"
	add_category_button.pressed.connect(func(): _create_category(category_edit.text))
	category_actions.add_child(add_category_button)
	category_rename_edit = LineEdit.new()
	category_rename_edit.placeholder_text = "Новое название"
	category_rename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_actions.add_child(category_rename_edit)
	var rename_category_button := Button.new()
	rename_category_button.text = "Переименовать"
	rename_category_button.pressed.connect(func(): _rename_selected_category(category_rename_edit.text))
	category_actions.add_child(rename_category_button)
	var delete_category_button := Button.new()
	delete_category_button.text = "Удалить"
	delete_category_button.pressed.connect(_delete_selected_category)
	category_actions.add_child(delete_category_button)
	category_dialog.confirmed.connect(func(): category_dialog.hide())
	add_child(category_dialog)

	stats_dialog = AcceptDialog.new()
	stats_dialog.title = "Характеристики"
	stats_dialog.ok_button_text = "Закрыть"
	# Keep the editor dialog bounded when the list is empty; otherwise Godot may
	# let the expanding ItemList claim the whole editor viewport.
	stats_dialog.min_size = Vector2i(520, 420)
	var stats_root := VBoxContainer.new()
	stats_root.custom_minimum_size = Vector2(430, 280)
	stats_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stats_dialog.add_child(stats_root)
	stats_list = ItemList.new()
	stats_list.custom_minimum_size = Vector2(0, 120)
	stats_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_list.item_selected.connect(_on_stat_selected)
	stats_root.add_child(stats_list)
	stats_hint_label = Label.new()
	stats_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_hint_label.add_theme_color_override("font_color", Color("f6ca68"))
	stats_hint_label.visible = false
	stats_root.add_child(stats_hint_label)
	var stat_name_row := HBoxContainer.new()
	stats_root.add_child(stat_name_row)
	stat_key_edit = LineEdit.new()
	stat_key_edit.placeholder_text = "Название: damage"
	stat_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_name_row.add_child(stat_key_edit)
	stat_translations_container = VBoxContainer.new()
	stat_translations_container.add_theme_constant_override("separation", 4)
	stats_root.add_child(stat_translations_container)
	var stat_row := HBoxContainer.new()
	stats_root.add_child(stat_row)
	stat_type_option = OptionButton.new()
	stat_type_option.add_item("Int")
	stat_type_option.add_item("Float")
	stat_type_option.add_item("Array")
	stat_type_option.add_item("Dictionary")
	stat_type_option.add_item("Bool")
	stat_type_option.select(1)
	stat_type_option.item_selected.connect(_on_stat_type_selected)
	stat_row.add_child(stat_type_option)
	var stat_element_label := Label.new()
	stat_element_label.text = "Элементы"
	stat_element_label.visible = false
	stat_row.add_child(stat_element_label)
	stat_array_element_type_option = OptionButton.new()
	stat_array_element_type_option.add_item("Int", SkillTreeStatData.ValueType.INT)
	stat_array_element_type_option.add_item("Float", SkillTreeStatData.ValueType.FLOAT)
	stat_array_element_type_option.add_item("Bool", SkillTreeStatData.ValueType.BOOL)
	stat_array_element_type_option.select(1)
	stat_array_element_type_option.item_selected.connect(func(_index):
		_rebuild_array_draft()
		_rebuild_dictionary_draft())
	stat_array_element_type_option.visible = false
	stat_array_element_type_option.tooltip_text = "Тип каждого элемента Array"
	stat_row.add_child(stat_array_element_type_option)
	stat_array_element_type_option.set_meta("type_label", stat_element_label)
	stat_base_value = SpinBox.new()
	stat_base_value.min_value = -999999999
	stat_base_value.max_value = 999999999
	stat_base_value.step = 0.01
	stat_base_value.value = 0.0
	stat_base_value.custom_minimum_size.x = 90
	stat_row.add_child(stat_base_value)
	stat_bool_value = CheckButton.new()
	stat_bool_value.text = "True"
	stat_bool_value.visible = false
	stat_row.add_child(stat_bool_value)
	stat_array_base_row = HBoxContainer.new()
	stat_array_base_row.visible = false
	stats_root.add_child(stat_array_base_row)
	var stat_array_label := Label.new()
	stat_array_label.text = "Значения"
	stat_array_label.custom_minimum_size.x = 74
	stat_array_base_row.add_child(stat_array_label)
	var array_open_bracket := Label.new()
	array_open_bracket.text = "["
	stat_array_base_row.add_child(array_open_bracket)
	stat_array_base_value = LineEdit.new()
	stat_array_base_value.placeholder_text = "1, 2, 3"
	stat_array_base_value.tooltip_text = "Значения через запятую"
	stat_array_base_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_array_base_row.add_child(stat_array_base_value)
	var array_close_bracket := Label.new()
	array_close_bracket.text = "]"
	stat_array_base_row.add_child(array_close_bracket)
	# Kept only for loading legacy resources; arrays are edited as individual rows below.
	stat_array_base_row.visible = false
	stat_array_entries = VBoxContainer.new()
	stat_array_entries.visible = false
	stat_array_entries.add_theme_constant_override("separation", 4)
	stats_root.add_child(stat_array_entries)
	var add_array_item := Button.new()
	add_array_item.text = "+ Индекс"
	add_array_item.pressed.connect(_add_array_draft_entry)
	stat_array_entries.add_child(add_array_item)
	stat_dictionary_row = VBoxContainer.new()
	stat_dictionary_row.visible = false
	stats_root.add_child(stat_dictionary_row)
	var dictionary_label := Label.new()
	dictionary_label.text = "Ключи словаря"
	stat_dictionary_row.add_child(dictionary_label)
	stat_dictionary_entries = VBoxContainer.new()
	stat_dictionary_entries.add_theme_constant_override("separation", 4)
	stat_dictionary_row.add_child(stat_dictionary_entries)
	var add_dictionary_key := Button.new()
	add_dictionary_key.text = "+ Ключ"
	add_dictionary_key.pressed.connect(_add_dictionary_draft_entry)
	stat_dictionary_row.add_child(add_dictionary_key)
	var add_stat_button := Button.new()
	add_stat_button.text = "Создать"
	add_stat_button.pressed.connect(_create_player_stat)
	stat_row.add_child(add_stat_button)
	edit_stat_button = Button.new()
	edit_stat_button.text = "Изменить"
	edit_stat_button.disabled = true
	edit_stat_button.pressed.connect(_update_selected_player_stat)
	stat_row.add_child(edit_stat_button)
	var remove_stat_button := Button.new()
	remove_stat_button.text = "Удалить"
	remove_stat_button.pressed.connect(_delete_selected_player_stat)
	stat_row.add_child(remove_stat_button)
	stats_dialog.confirmed.connect(func(): stats_dialog.hide())
	add_child(stats_dialog)

	locales_dialog = AcceptDialog.new()
	locales_dialog.title = "Языки"
	locales_dialog.ok_button_text = "Закрыть"
	var locales_root := VBoxContainer.new()
	locales_root.custom_minimum_size = Vector2(360, 250)
	locales_dialog.add_child(locales_root)
	locales_list = ItemList.new()
	locales_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	locales_list.item_selected.connect(_on_locale_selected)
	locales_root.add_child(locales_list)
	var locale_key_row := HBoxContainer.new()
	locales_root.add_child(locale_key_row)
	var locale_key_label := Label.new()
	locale_key_label.text = "Ключ"
	locale_key_label.custom_minimum_size.x = 72
	locale_key_row.add_child(locale_key_label)
	locale_key_edit = LineEdit.new()
	locale_key_edit.placeholder_text = "en"
	locale_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	locale_key_row.add_child(locale_key_edit)
	var locale_name_row := HBoxContainer.new()
	locales_root.add_child(locale_name_row)
	var locale_name_label := Label.new()
	locale_name_label.text = "Название"
	locale_name_label.custom_minimum_size.x = 72
	locale_name_row.add_child(locale_name_label)
	locale_name_edit = LineEdit.new()
	locale_name_edit.placeholder_text = "English"
	locale_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	locale_name_row.add_child(locale_name_edit)
	var locale_actions := HBoxContainer.new()
	locales_root.add_child(locale_actions)
	var add_locale_button := Button.new()
	add_locale_button.text = "Добавить"
	add_locale_button.pressed.connect(_add_locale)
	locale_actions.add_child(add_locale_button)
	var remove_locale_button := Button.new()
	remove_locale_button.text = "Удалить"
	remove_locale_button.pressed.connect(_remove_selected_locale)
	locale_actions.add_child(remove_locale_button)
	locales_dialog.confirmed.connect(func(): locales_dialog.hide())
	add_child(locales_dialog)

	colors_dialog = AcceptDialog.new()
	colors_dialog.title = "Цвета"
	colors_dialog.ok_button_text = "Закрыть"
	var colors_root := VBoxContainer.new()
	colors_root.custom_minimum_size = Vector2(360, 250)
	colors_dialog.add_child(colors_root)
	state_colors_toggle = Button.new()
	state_colors_toggle.toggle_mode = true
	state_colors_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	state_colors_toggle.text = "Состояния навыка  ▾"
	colors_root.add_child(state_colors_toggle)
	state_colors_panel = VBoxContainer.new()
	state_colors_panel.add_theme_constant_override("separation", 6)
	colors_root.add_child(state_colors_panel)
	state_colors_toggle.button_pressed = true
	state_colors_toggle.toggled.connect(func(opened: bool):
		state_colors_panel.visible = opened
		state_colors_toggle.text = _translated("Состояния навыка  ▾" if opened else "Состояния навыка  ▸")
	)
	colors_dialog.confirmed.connect(func(): colors_dialog.hide())
	add_child(colors_dialog)
	# Section dialogs return to the settings menu instead of ending the workflow.
	category_dialog.confirmed.connect(_return_to_settings.bind(category_dialog))
	stats_dialog.confirmed.connect(_return_to_settings.bind(stats_dialog))
	locales_dialog.confirmed.connect(_return_to_settings.bind(locales_dialog))
	colors_dialog.confirmed.connect(_return_to_settings.bind(colors_dialog))

	currency_dialog = CURRENCY_EDITOR_SCENE.instantiate()
	currency_dialog.currencies_changed.connect(_on_currencies_changed)
	currency_dialog.confirmed.connect(_return_to_settings.bind(currency_dialog))
	add_child(currency_dialog)
	settings_dialog = AcceptDialog.new()
	settings_dialog.title = "Настройки"
	settings_dialog.ok_button_text = "Закрыть"
	var settings_root := VBoxContainer.new()
	settings_root.custom_minimum_size = Vector2(360, 220)
	settings_dialog.add_child(settings_root)
	for entry in [["Общее", "General"], ["Категории", "Categories"], ["Характеристики", "Stats"], ["Валюты", "Currencies"], ["Языки", "Locales"], ["Цвета", "Colors"]]:
		var action_button := Button.new()
		action_button.text = entry[0]
		action_button.pressed.connect(func(): settings_dialog.hide(); _on_toolbar_pressed(entry[1]))
		settings_root.add_child(action_button)
	add_child(settings_dialog)
	general_dialog = AcceptDialog.new()
	general_dialog.title = "Общее"
	general_dialog.ok_button_text = "Назад"
	var general_root := VBoxContainer.new()
	general_root.custom_minimum_size = Vector2(360, 100)
	general_dialog.add_child(general_root)
	refund_percent_label = Label.new()
	refund_percent_label.text = "Процент возврата при сбросе"
	general_root.add_child(refund_percent_label)
	refund_percent_spin = SpinBox.new()
	refund_percent_spin.min_value = 0.0
	refund_percent_spin.max_value = 100.0
	refund_percent_spin.step = 1.0
	refund_percent_spin.suffix = "%"
	refund_percent_spin.value_changed.connect(_on_refund_percent_changed)
	general_root.add_child(refund_percent_spin)
	general_dialog.confirmed.connect(_return_to_settings.bind(general_dialog))
	add_child(general_dialog)

	clear_dialog = ConfirmationDialog.new()
	clear_dialog.name = "ClearConfirmation"
	clear_dialog.title = "Очистить дерево навыков?"
	clear_dialog.dialog_text = "Все навыки и связи будут удалены из текущего дерева. Это действие можно отменить через Undo."
	clear_dialog.ok_button_text = "Очистить"
	clear_dialog.cancel_button_text = "Отмена"
	clear_dialog.confirmed.connect(clear_all_nodes)
	add_child(clear_dialog)
	_apply_language()

func _default_language() -> String:
	var locale := OS.get_locale_language().to_lower()
	return "ru" if locale == "ru" else "en"

func _set_language(index: int) -> void:
	language = "en" if index == 1 else "ru"
	if plugin:
		plugin.get_editor_interface().get_editor_settings().set_setting("skill_tree_editor/language", language)
	_apply_language()

func _translated(value: String) -> String:
	var values := {
		"Новый": "New", "Открыть": "Open", "Сохранить": "Save", "Сохранить как": "Save As", "Отменить": "Undo", "Повторить": "Redo", "Вернуть": "Redo", "Выделить все": "Select all", "Центр": "Center", "Новое дерево": "New tree", "Открыть дерево": "Open tree", "Категории": "Categories", "Характеристики": "Stats", "Языки": "Languages", "Цвета": "Colors", "Очистить": "Clear",
		"Русский": "Русский", "English": "English", "Название дерева": "Tree name", "Валюты": "Currencies", "Валюта": "Currency", "Стоимость": "Cost", "Базовая цена": "Base cost", "Стартовое количество": "Start amount",
		"Новый навык": "New skill", "Уровень 0 /": "Level 0 /", "  Цена": "  Cost", " SP": " SP",
		"ПКМ по полю — создать навык. ПКМ по узлу — действия. Перетяните порт узла на другой порт, чтобы создать связь.": "Right-click the canvas to create a skill. Right-click a node for actions. Drag a port to another port to create a connection.",
		"Поиск навыка...": "Search skills...", "Уменьшить (колесо вниз)": "Zoom out (wheel down)",
		"Увеличить (колесо вверх)": "Zoom in (wheel up)", "Закрыть": "Close",
		"Создать": "Create", "Изменить": "Edit", "Переименовать": "Rename", "Удалить": "Delete", "Новая категория": "New category",
		"Новое название": "New name", "Очистить дерево навыков?": "Clear skill tree?",
		"Настройки": "Settings", "Общее": "General", "Назад": "Back", "Процент возврата при сбросе": "Refund percentage",
		"Отмена": "Cancel", "Название навыка": "Skill name", "Описание...": "Description...",
		"Параметры  ▸": "Parameters  ▸", "Параметры  ▾": "Parameters  ▾", "Категория": "Category", "Иконка": "Icon",
		"Cost growth": "Cost growth", "Цены вручную": "Manual costs", "необязательно: 2, 3, 5": "optional: 2, 3, 5",
		"Виден сразу": "Visible immediately", "Эффекты": "Effects", "+ Создать эффект": "+ Create effect",
		"Требует": "Requires", "Ключ значения": "Value key", "Текст RU": "Russian text", "Текст EN": "English text", "Характеристика": "Player stat", "Название: damage": "Name: damage", "Значения": "Values", "Элементы": "Elements", "Ключи словаря": "Dictionary keys", "Ключ": "Key", "Новый ключ": "New key",
		"Массив": "Array", "Словарь": "Dictionary", "Прибавить": "Add", "Вычесть": "Subtract", "Умножить": "Multiply",
		"Разделить": "Divide", "Установить": "Set", "Добавить уникальное": "Add unique",
		"Effect value": "Effect value", "Effect growth": "Effect growth", "Ограничить минимумом и максимумом": "Clamp to minimum and maximum",
		"Минимум": "Minimum", "Максимум": "Maximum", "Центр дерева: (0, 0)": "Tree origin: (0, 0)",
		"Состояния навыка  ▾": "Skill states  ▾", "Состояния навыка  ▸": "Skill states  ▸", "Хватает валюты": "Enough currency", "Не хватает валюты": "Not enough currency", "Доступен": "Available", "Недоступен": "Unavailable", "Максимальный уровень": "Maximum level", "Следующее значение": "Next value"
	}
	if language == "en":
		return str(values.get(value, value))
	for key in values:
		if str(values[key]) == value:
			return key
	return value

func _apply_language() -> void:
	for control in find_children("*", "Control", true, false):
		if control is Button or control is Label or control is CheckButton or control is OptionButton:
			control.text = _translated(control.text)
			if language == "en":
				control.text = control.text.replace("Эффекты", "Effects").replace("Параметры", "Parameters")
			else:
				control.text = control.text.replace("Effects", "Эффекты").replace("Parameters", "Параметры")
		if control is LineEdit:
			control.placeholder_text = _translated(control.placeholder_text)
		control.tooltip_text = _translated(control.tooltip_text)
		if control is OptionButton:
			if control.has_meta("skill_category_option"):
				for i in mini(control.item_count, current_tree.categories.size() if current_tree else 0):
					control.set_item_text(i, _category_display_name(current_tree.categories[i]))
			else:
				for i in control.item_count:
					control.set_item_text(i, _translated(control.get_item_text(i)))
	for skill_id in node_by_id:
		var graph_node: GraphNode = node_by_id[skill_id]
		var title_box := graph_node.get_titlebar_hbox().get_node_or_null("TitleTranslations") as VBoxContainer
		if title_box:
			for title_edit in title_box.get_children():
				if title_edit is LineEdit:
					var locale_key := str(title_edit.get_meta("title_locale", "en"))
					title_edit.placeholder_text = _title_placeholder(locale_key)
		var description := graph_node.get_node_or_null("DescriptionEdit") as TextEdit
		if description:
			description.placeholder_text = "Description..." if language == "en" else "Описание..."
	if context_menu:
		for i in context_menu.item_count:
			context_menu.set_item_text(i, _translated(context_menu.get_item_text(i)))
	if category_dialog:
		category_dialog.title = _translated("Категории")
		category_dialog.ok_button_text = _translated("Назад")
	if stats_dialog:
		stats_dialog.title = _translated("Характеристики")
		stats_dialog.ok_button_text = _translated("Назад")
	if locales_dialog:
		locales_dialog.title = _translated("Языки")
		locales_dialog.ok_button_text = _translated("Назад")
	if colors_dialog:
		colors_dialog.title = _translated("Цвета")
		colors_dialog.ok_button_text = _translated("Назад")
	if currency_dialog and currency_dialog.visible:
		currency_dialog.configure(current_tree, language)
	if clear_dialog:
		clear_dialog.title = _translated("Очистить дерево навыков?")
		clear_dialog.ok_button_text = _translated("Очистить")
		clear_dialog.cancel_button_text = _translated("Отмена")
	if refund_percent_label:
		refund_percent_label.text = _translated("Процент возврата при сбросе")

func _get_undo_history() -> UndoRedo:
	if not undo_redo:
		return null
	# Snapshot actions use this Control as their operation object, so ask the
	# manager for the history of the currently edited plugin scene.
	var history_id := undo_redo.get_object_history_id(self)
	return undo_redo.get_history_undo_redo(history_id)

func _on_toolbar_pressed(action: String) -> void:
	match action:
		"New": new_tree()
		"Open": _open_tree_dialog()
		"Save": save_tree()
		"Save As": _save_tree_dialog()
		"Clear":
			if current_tree and not current_tree.skills.is_empty():
				clear_dialog.popup_centered(Vector2i(460, 180))
		"Undo":
			var history := _get_undo_history()
			if history and history.has_undo(): history.undo()
		"Redo":
			var history := _get_undo_history()
			if history and history.has_redo(): history.redo()
		"Validate": validate_tree()
		"Frame All": frame_all()
		"Center Origin": center_origin()
		"Categories":
			_open_category_dialog()
		"Stats":
			_open_stats_dialog()
		"Currencies":
			_open_currency_dialog()
		"Locales":
			_open_locales_dialog()
		"Colors":
			_open_colors_dialog()
		"Settings":
			settings_dialog.popup_centered(Vector2i(400, 420))
		"General":
			if current_tree:
				refund_percent_spin.value = current_tree.refund_percent
			general_dialog.popup_centered(Vector2i(400, 180))

func _return_to_settings(dialog: AcceptDialog) -> void:
	dialog.hide()
	settings_dialog.popup_centered(Vector2i(400, 420))

func _on_refund_percent_changed(value: float) -> void:
	if not current_tree or is_equal_approx(current_tree.refund_percent, value):
		return
	var before := _clone_tree(current_tree)
	current_tree.refund_percent = value
	_commit_snapshot(before, _clone_tree(current_tree), "Изменить процент возврата")

func _on_tree_name_submitted(value: String) -> void:
	if not current_tree:
		return
	var clean_value := value.strip_edges()
	if clean_value.is_empty():
		clean_value = "main"
	tree_name_edit.text = clean_value
	if current_tree.tree_id != clean_value:
		current_tree.tree_id = clean_value
		dirty = true

func _change_zoom(delta: float) -> void:
	if not graph:
		return
	graph.zoom = clampf(graph.zoom + delta, 0.25, 2.0)
	_update_zoom_label()

func _update_zoom_label() -> void:
	if zoom_label and graph:
		zoom_label.text = "%d%%" % roundi(graph.zoom * 100.0)

func _create_origin_element() -> void:
	origin_element = GraphElement.new()
	origin_element.name = "OriginElement"
	origin_element.position_offset = Vector2(-5.0, -5.0)
	origin_element.custom_minimum_size = Vector2(10.0, 10.0)
	origin_element.size = Vector2(10.0, 10.0)
	origin_element.draggable = false
	origin_element.resizable = false
	origin_element.selectable = false
	origin_element.mouse_filter = Control.MOUSE_FILTER_IGNORE
	origin_element.z_index = 1000
	origin_element.tooltip_text = "Центр дерева: (0, 0)"
	var dot := ColorRect.new()
	dot.name = "Dot"
	dot.color = Color(0.35, 0.75, 1.0, 0.95)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	origin_element.add_child(dot)
	graph.add_child(origin_element)

func center_origin() -> void:
	if not graph:
		return
	center_request_id += 1
	call_deferred("_center_origin_after_layout", center_request_id)

func _center_origin_after_layout(request_id: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for _pass in range(3):
		if request_id != center_request_id or not graph or not is_instance_valid(origin_element):
			return
		var viewport_center: Vector2 = graph.get_global_rect().get_center()
		var origin_center: Vector2 = origin_element.get_global_rect().get_center()
		var error: Vector2 = origin_center - viewport_center
		if error.length() <= 0.5:
			return
		graph.scroll_offset += error
		await get_tree().process_frame
		await get_tree().process_frame

func new_tree(record_undo := true) -> void:
	var before := _clone_tree(current_tree) if current_tree else null
	var tree := TREE_SCRIPT.new()
	tree.tree_id = "main"
	tree.categories = ["SKILL_CATEGORY_MAIN"]
	tree.ensure_default_currency()
	current_tree = tree
	var first_skill := SKILL_SCRIPT.new()
	first_skill.skill_id = "skill"
	first_skill.ensure_title_translations(tree.get_locales())
	first_skill.category = tree.categories[0]
	first_skill.currency_key = str(tree.get_base_currency().get("key"))
	first_skill.editor_position = -CARD_SIZE * 0.5
	tree.skills.append(first_skill)
	current_path = ""
	selected_skill_id = ""
	dirty = true
	if graph:
		graph.zoom = 1.0
		_update_zoom_label()
	_redraw_graph()
	call_deferred("center_origin")
	_show_status("Новое дерево: ПКМ по полю, чтобы создать навык")
	if record_undo and before and undo_redo:
		_commit_snapshot(before, _clone_tree(current_tree), "Создать новое дерево")

func _add_toolbar_separator(toolbar: HBoxContainer) -> void:
	var separator := VSeparator.new()
	separator.custom_minimum_size.y = 26
	toolbar.add_child(separator)

func _add_toolbar_button(toolbar: HBoxContainer, action: String, label: String, icon_name := "") -> void:
	var button := Button.new()
	button.name = action.replace(" ", "_")
	button.text = label
	button.tooltip_text = label
	button.custom_minimum_size.y = 30
	if not icon_name.is_empty() and plugin:
		var editor_base := plugin.get_editor_interface().get_base_control()
		var icon := editor_base.get_theme_icon(icon_name, "EditorIcons") if editor_base.has_theme_icon(icon_name, "EditorIcons") else null
		if icon:
			button.icon = icon
			button.text = ""
			button.custom_minimum_size.x = 34
	button.pressed.connect(_on_toolbar_pressed.bind(action))
	toolbar.add_child(button)

func clear_all_nodes() -> void:
	if not current_tree or current_tree.skills.is_empty():
		return
	var before := _clone_tree(current_tree)
	current_tree.skills.clear()
	current_tree.skills = []
	selected_skill_id = ""
	expanded_sections.clear()
	_commit_snapshot(before, _clone_tree(current_tree), "Очистить дерево навыков")
	_redraw_graph()
	_show_status("Дерево очищено. Отменить: Undo")

func _on_graph_gui_input(event: InputEvent) -> void:
	if context_menu and context_menu.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_zoom(0.1)
			graph.accept_event()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_zoom(-0.1)
			graph.accept_event()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_show_context_menu(false, graph.get_local_mouse_position())
		graph.accept_event()

func _on_node_gui_input(event: InputEvent, skill_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		selected_skill_id = skill_id
		var node: GraphNode = node_by_id.get(skill_id)
		if node:
			node.selected = true
		_show_context_menu(true, node.get_local_mouse_position() if node else Vector2.ZERO)
		get_viewport().set_input_as_handled()

func _show_context_menu(on_node: bool, local_position: Vector2) -> void:
	if not graph or not context_menu:
		return
	if not on_node:
		context_position = graph.get_scroll_offset() + local_position / maxf(graph.zoom, 0.01)
	context_menu.set_item_disabled(context_menu.get_item_index(1), on_node)
	context_menu.set_item_disabled(context_menu.get_item_index(2), clipboard_skill == null)
	context_menu.set_item_disabled(context_menu.get_item_index(3), not on_node)
	context_menu.set_item_disabled(context_menu.get_item_index(4), not on_node)
	context_menu.set_item_disabled(context_menu.get_item_index(5), not on_node)
	context_menu.set_item_disabled(context_menu.get_item_index(6), not on_node)
	context_menu.position = Vector2i(get_viewport().get_mouse_position())
	context_menu.popup()

func _input(event: InputEvent) -> void:
	if not graph or not is_visible_in_tree() or (context_menu and context_menu.visible):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var mouse_position := get_viewport().get_mouse_position()
		if not graph.get_global_rect().has_point(mouse_position):
			return
		for skill_id in node_by_id:
			var node: GraphNode = node_by_id[skill_id]
			if node.get_global_rect().has_point(mouse_position):
				selected_skill_id = skill_id
				node.selected = true
				context_skill_id = skill_id
				_show_context_menu(true, Vector2.ZERO)
				get_viewport().set_input_as_handled()
				return
		_show_context_menu(false, graph.get_local_mouse_position())
		get_viewport().set_input_as_handled()

func _snap_graph_position(value: Vector2) -> Vector2:
	return Vector2(roundf(value.x / GRID_SIZE) * GRID_SIZE, roundf(value.y / GRID_SIZE) * GRID_SIZE)

func move_selected_to_center() -> void:
	var skill := current_tree.get_skill(selected_skill_id) if current_tree else null
	if not skill or not graph:
		return
	var before := _clone_tree(current_tree)
	skill.editor_position = _snap_graph_position(-CARD_SIZE * 0.5)
	_commit_snapshot(before, _clone_tree(current_tree), "Переместить навык в центр")
	_redraw_graph()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		1: add_skill_at(context_position)
		2: paste_skill_at(context_position)
		3: copy_skill()
		4: duplicate_skill()
		5: delete_skill(selected_skill_id)
		6: move_selected_to_center()

func add_skill_at(position: Vector2) -> void:
	if not current_tree:
		new_tree(false)
	var before := _clone_tree(current_tree)
	var skill := SKILL_SCRIPT.new()
	_ensure_categories()
	current_tree.ensure_default_currency()
	skill.skill_id = _next_skill_id()
	skill.ensure_title_translations(current_tree.get_locales())
	skill.category = current_tree.categories[0]
	skill.currency_key = str(current_tree.get_base_currency().get("key"))
	skill.editor_position = _snap_graph_position(position - CARD_SIZE * 0.5)
	current_tree.skills.append(skill)
	selected_skill_id = skill.skill_id
	_commit_snapshot(before, _clone_tree(current_tree), "Создать навык")
	_redraw_graph()

func paste_skill_at(position: Vector2) -> void:
	if not clipboard_skill:
		return
	var before := _clone_tree(current_tree)
	var copy := _clone_skill(clipboard_skill)
	copy.skill_id = _next_skill_id(copy.skill_id + "_copy")
	copy.title += " (копия)"
	copy.editor_position = position
	current_tree.skills.append(copy)
	selected_skill_id = copy.skill_id
	_commit_snapshot(before, _clone_tree(current_tree), "Вставить навык")
	_redraw_graph()

func _next_skill_id(prefix := "skill") -> String:
	var index := 1
	var candidate := prefix
	while current_tree and current_tree.get_skill(candidate):
		index += 1
		candidate = "%s_%d" % [prefix, index]
	return candidate

func _on_node_selected(node: Node) -> void:
	selected_skill_id = node.name
	for skill_id in node_by_id:
		node_by_id[skill_id].selected = skill_id == selected_skill_id

func _on_connection_request(from_node: StringName, _from_port: int, to_node: StringName, _to_port: int) -> void:
	var parent_id := str(from_node)
	var child_id := str(to_node)
	if not current_tree or parent_id == child_id:
		return
	var child := current_tree.get_skill(child_id)
	if not child or current_tree.get_skill(parent_id) == null or _has_ancestor(parent_id, child_id):
		_show_status("Связь отклонена: она создаёт цикл")
		return
	for requirement in child.requirements:
		if requirement and requirement.parent_skill_id == parent_id:
			return
	if undo_redo:
		undo_redo.create_action("Создать связь")
		undo_redo.add_do_method(self, "_add_connection", parent_id, child_id, 1)
		undo_redo.add_undo_method(self, "_remove_connection", parent_id, child_id)
		undo_redo.commit_action()
	else:
		_add_connection(parent_id, child_id, 1)

func _add_connection(parent_id: String, child_id: String, required_level: int) -> void:
	var child := current_tree.get_skill(child_id) if current_tree else null
	if not child:
		return
	for requirement in child.requirements:
		if requirement and requirement.parent_skill_id == parent_id:
			return
	var requirement := REQUIREMENT_SCRIPT.new()
	requirement.parent_skill_id = parent_id
	requirement.required_level = required_level
	child.requirements.append(requirement)
	expanded_sections[child_id + ":requirements"] = true
	if graph and node_by_id.has(parent_id) and node_by_id.has(child_id):
		graph.connect_node(parent_id, 0, child_id, 0)
	dirty = true
	_redraw_graph()

func _has_ancestor(skill_id: String, target_id: String) -> bool:
	var skill := current_tree.get_skill(skill_id)
	if not skill:
		return false
	for requirement in skill.requirements:
		if requirement and (requirement.parent_skill_id == target_id or _has_ancestor(requirement.parent_skill_id, target_id)):
			return true
	return false

func _on_disconnection_request(from_node: StringName, _from_port: int, to_node: StringName, _to_port: int) -> void:
	var parent_id := str(from_node)
	var child_id := str(to_node)
	var child := current_tree.get_skill(child_id) if current_tree else null
	if not child:
		return
	var required_level := 1
	for requirement in child.requirements:
		if requirement and requirement.parent_skill_id == parent_id:
			required_level = requirement.required_level
			break
	if undo_redo:
		undo_redo.create_action("Удалить связь")
		undo_redo.add_do_method(self, "_remove_connection", parent_id, child_id)
		undo_redo.add_undo_method(self, "_add_connection", parent_id, child_id, required_level)
		undo_redo.commit_action()
	else:
		_remove_connection(parent_id, child_id)

func _remove_connection(parent_id: String, child_id: String) -> void:
	var child := current_tree.get_skill(child_id) if current_tree else null
	if not child:
		return
	child.requirements = child.requirements.filter(func(req): return req == null or req.parent_skill_id != parent_id)
	if graph:
		if graph.is_node_connected(parent_id, 0, child_id, 0):
			graph.disconnect_node(parent_id, 0, child_id, 0)
	dirty = true
	_redraw_graph()

func _on_delete_nodes_request() -> void:
	if graph:
		var selected: Array = graph.get_selected_nodes()
		if not selected.is_empty():
			for node_id in selected:
				delete_skill(str(node_id))
			return
	delete_skill(selected_skill_id)

func delete_skill(skill_id: String) -> void:
	if not current_tree or skill_id.is_empty():
		return
	var before := _clone_tree(current_tree)
	for skill in current_tree.skills:
		if skill:
			skill.requirements = skill.requirements.filter(func(req): return req == null or req.parent_skill_id != skill_id)
	current_tree.skills = current_tree.skills.filter(func(skill): return skill != null and skill.skill_id != skill_id)
	expanded_sections.erase(skill_id + ":parameters")
	expanded_sections.erase(skill_id + ":requirements")
	expanded_sections.erase(skill_id + ":effects")
	selected_skill_id = ""
	_commit_snapshot(before, _clone_tree(current_tree), "Удалить навык")
	_redraw_graph()

func copy_skill() -> void:
	var skill := current_tree.get_skill(selected_skill_id) if current_tree else null
	if skill:
		clipboard_skill = _clone_skill(skill)
		_show_status("Скопирован навык: %s" % _editor_skill_title(skill))

func duplicate_skill() -> void:
	if current_tree and not selected_skill_id.is_empty():
		copy_skill()
		paste_skill_at(current_tree.get_skill(selected_skill_id).editor_position + Vector2(48, 48))

func validate_tree() -> bool:
	if not current_tree:
		_show_status("Нет открытого дерева")
		return false
	var errors := VALIDATOR.validate(current_tree)
	if errors.is_empty():
		_show_status("✓ Корректно: %d навыков" % current_tree.skills.size())
		return true
	_show_status("✗ " + " | ".join(errors))
	return false

func save_tree(path_override: String = "") -> bool:
	if not current_tree:
		return false
	if is_saving:
		return false
	_commit_pending_edits()
	if not validate_tree():
		return false
	var target_path := path_override if not path_override.is_empty() else current_path
	if target_path.is_empty():
		_save_tree_dialog()
		return false

	is_saving = true
	var snapshot := _clone_tree(current_tree)
	var existing_uid := ResourceSaver.get_resource_id_for_path(target_path, false)
	# ResourceSaver can write the file while the old loaded resource remains the
	# cache owner. Taking over the path makes Save and Save As replace that
	# resource in the same editor session too.
	snapshot.take_over_path(target_path)
	var flags := ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	var error := ResourceSaver.save(snapshot, target_path, flags)
	if error != OK:
		current_tree.take_over_path(target_path)
		is_saving = false
		push_error("SkillTree save failed: %s (%s)" % [target_path, error_string(error)])
		_show_status("Ошибка сохранения %s: %s" % [target_path, error_string(error)])
		return false
	if existing_uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(target_path, existing_uid)
	var verification = ResourceLoader.load(target_path, "SkillTreeData", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not verification is SkillTreeData or _tree_fingerprint(verification) != _tree_fingerprint(snapshot):
		current_tree.take_over_path(target_path)
		is_saving = false
		push_error("SkillTree save verification failed: %s" % target_path)
		_show_status("Ошибка проверки сохранения: данные в %s не совпадают" % target_path)
		return false
	var refreshed = ResourceLoader.load(target_path, "SkillTreeData", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	current_tree = refreshed if refreshed is SkillTreeData else snapshot
	current_path = target_path
	dirty = false
	is_saving = false
	_redraw_graph()
	if plugin:
		var filesystem := plugin.get_editor_interface().get_resource_filesystem()
		if filesystem.has_method("update_file"):
			filesystem.update_file(target_path)
		else:
			filesystem.scan()
	_show_status("✓ Сохранено одним файлом: %s" % target_path)
	return true

func _commit_pending_edits() -> void:
	if not graph:
		return
	for edit in find_children("*", "LineEdit", true, false):
		if edit.has_meta("skill_commit_target"):
			var target: Resource = edit.get_meta("skill_commit_target")
			var property_name := str(edit.get_meta("skill_commit_property", ""))
			var skill_id := str(edit.get_meta("skill_commit_skill_id", ""))
			if edit.get_meta("skill_commit_mode", "line") == "costs":
				_on_costs_commit(edit, target as SkillData)
			else:
				_on_line_commit(edit, target, property_name, skill_id)
	for edit in find_children("*", "TextEdit", true, false):
		if edit.has_meta("skill_commit_target"):
			var target: SkillData = edit.get_meta("skill_commit_target")
			_on_description_commit(edit, target)

func _open_tree_dialog() -> void:
	if not open_dialog:
		open_dialog = EditorFileDialog.new()
		open_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		open_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		open_dialog.add_filter("*.tres", "Skill Tree Resource")
		open_dialog.file_selected.connect(_open_tree)
		add_child(open_dialog)
	open_dialog.popup_centered_ratio(0.75)

func _save_tree_dialog() -> void:
	if not save_dialog:
		save_dialog = EditorFileDialog.new()
		save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		save_dialog.add_filter("*.tres", "Skill Tree Resource")
		save_dialog.file_selected.connect(_save_tree_to_path)
		add_child(save_dialog)
	save_dialog.current_file = "SkillTreeData.tres"
	save_dialog.popup_centered_ratio(0.75)

func _save_tree_to_path(path: String) -> void:
	if save_dialog:
		save_dialog.hide()
	# The overwrite confirmation is modal; wait until it has released the
	# editor before changing the resource on disk.
	call_deferred("_save_tree_to_path_deferred", path)

func _save_tree_to_path_deferred(path: String) -> void:
	save_tree(path)

func _open_tree(path: String) -> void:
	if is_opening:
		return
	is_opening = true
	if open_dialog:
		open_dialog.hide()
	# Do not rebuild GraphEdit from inside EditorFileDialog.file_selected.
	# The dialog is modal; rebuilding its parent in the same callback can make
	# the Godot editor appear frozen on Windows.
	call_deferred("_open_tree_deferred", path)

func _open_tree_deferred(path: String) -> void:
	# Ignore the previous in-memory resource. This is important when the user
	# saves over a .tres and opens it again in the same editor session.
	var loaded = ResourceLoader.load(path, "SkillTreeData", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded is SkillTreeData:
		loaded.ensure_default_currency()
		current_tree = _clone_tree(loaded)
		current_path = path
		tree_name_edit.text = current_tree.tree_id
		selected_skill_id = ""
		dirty = false
		_redraw_graph()
		call_deferred("frame_all")
		_show_status("Открыто: %s" % path)
	else:
		_show_status("Файл не является SkillTreeData")
	is_opening = false

func _redraw_graph() -> void:
	if not graph:
		return
	is_rebuilding = true
	for child in graph.get_children():
		if child is GraphNode or child is Label:
			# Graph children can be rebuilt from their own button signals. Detach
			# first so names are reusable, then defer freeing until the signal ends.
			graph.remove_child(child)
			child.queue_free()
	node_by_id.clear()
	graph.clear_connections()
	if current_tree:
		_ensure_categories()
		if tree_name_edit:
			tree_name_edit.text = current_tree.tree_id
		for skill in current_tree.skills:
			if skill and not skill.skill_id.is_empty():
				_create_graph_node(skill)
		for skill in current_tree.skills:
			if skill:
				for requirement in skill.requirements:
					if requirement and current_tree.get_skill(requirement.parent_skill_id):
						graph.connect_node(requirement.parent_skill_id, 0, skill.skill_id, 0)
	is_rebuilding = false
	_update_search_visibility()
	_apply_language()

func _create_graph_node(skill: SkillData) -> void:
	var node := GraphNode.new()
	node.name = skill.skill_id
	node.title = ""
	node.position_offset = skill.editor_position
	node.custom_minimum_size = CARD_SIZE
	node.add_theme_constant_override("separation", 2)
	node.add_theme_constant_override("title_hbox_separation", 2)
	node.resizable = false
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("171b2b")
	card_style.border_color = Color("5965e8")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.shadow_color = Color(0.15, 0.18, 0.45, 0.35)
	card_style.shadow_size = 8
	node.add_theme_stylebox_override("panel", card_style)
	var selected_style := card_style.duplicate() as StyleBoxFlat
	selected_style.border_color = Color("8290ff")
	selected_style.shadow_color = Color(0.3, 0.38, 0.95, 0.55)
	selected_style.shadow_size = 12
	node.add_theme_stylebox_override("panel_selected", selected_style)
	node.add_theme_stylebox_override("panel_focus", selected_style)
	var titlebar_style := StyleBoxFlat.new()
	titlebar_style.bg_color = Color("202844")
	titlebar_style.set_corner_radius_all(7)
	titlebar_style.content_margin_left = 8.0
	titlebar_style.content_margin_right = 8.0
	titlebar_style.content_margin_top = 4.0
	titlebar_style.content_margin_bottom = 4.0
	node.add_theme_stylebox_override("titlebar", titlebar_style)
	node.add_theme_stylebox_override("titlebar_selected", selected_style)
	node.gui_input.connect(_on_node_gui_input.bind(skill.skill_id))
	node.position_offset_changed.connect(func(): _on_graph_node_moved(node, skill.skill_id))
	graph.add_child(node)
	node_by_id[skill.skill_id] = node

	# Keep input and output on different slots. This makes the direction explicit:
	# slot 1 is output-only and slot 0 is input-only.
	var input_port_row := Control.new()
	input_port_row.custom_minimum_size.y = 4
	node.add_child(input_port_row)
	var is_first_skill := current_tree and not current_tree.skills.is_empty() and current_tree.skills[0].skill_id == skill.skill_id
	node.set_slot(0, not is_first_skill, 0, Color(0.35, 0.65, 1.0), false, 0, Color.TRANSPARENT)
	var output_port_row := Control.new()
	output_port_row.custom_minimum_size.y = 4
	node.add_child(output_port_row)
	node.set_slot(1, false, 0, Color.TRANSPARENT, true, 0, Color(0.35, 0.65, 1.0))
	skill.ensure_title_translations(current_tree.get_locales() if current_tree else [])
	var title_box := VBoxContainer.new()
	title_box.name = "TitleTranslations"
	# GraphNode's title bar does not give a VBox with empty minimum width any room to expand.
	# Reserve the card width explicitly so localized title fields remain real, usable inputs.
	title_box.custom_minimum_size = Vector2(CARD_SIZE.x - 24.0, 0.0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	for locale_data in current_tree.get_locales() if current_tree else [{"key": "en", "name": "English"}]:
		var locale_key := str(locale_data.get("key", "en"))
		var title_edit := LineEdit.new()
		title_edit.name = "TitleEdit_%s" % locale_key
		title_edit.placeholder_text = _title_placeholder(locale_key)
		title_edit.set_meta("title_locale", locale_key)
		var localized_title := str((skill.title_translations as Dictionary).get(locale_key, ""))
		title_edit.text = "" if localized_title.is_empty() or localized_title == skill.get_title_fallback() else localized_title
		title_edit.tooltip_text = "%s — %s" % [str(locale_data.get("name", locale_key)), skill.get_title_key()]
		title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_edit.custom_minimum_size = Vector2(0.0, 30.0)
		title_edit.add_theme_font_size_override("font_size", 16)
		_tighten_text_control(title_edit)
		_apply_graph_field_style(title_edit, Color("141823"), Color("4b578b"))
		title_edit.set_meta("skill_old_value", title_edit.text)
		title_edit.focus_exited.connect(_on_title_translation_commit.bind(title_edit, skill, locale_key))
		title_edit.text_submitted.connect(func(_text): _on_title_translation_commit(title_edit, skill, locale_key))
		title_box.add_child(title_edit)
	var titlebar := node.get_titlebar_hbox()
	for child in titlebar.get_children():
		child.free()
	titlebar.add_child(title_box)

	var progression_row := HBoxContainer.new()
	progression_row.name = "ProgressionPreview"
	progression_row.custom_minimum_size = Vector2(0, 28)
	progression_row.add_theme_constant_override("separation", 2)
	var level_label := Label.new()
	level_label.text = "Уровень 0 /"
	progression_row.add_child(level_label)
	var max_level := _add_inline_number(progression_row, skill.max_level, skill, "max_level", skill.skill_id, 1, 999, true)
	max_level.name = "MaxLevelPreview"
	max_level.custom_minimum_size.x = 44
	var cost_preview := Label.new()
	cost_preview.text = "  %s" % _currency_cost_preview(skill)
	cost_preview.tooltip_text = _translated("Стоимость")
	progression_row.add_child(cost_preview)
	node.add_child(progression_row)
	var description := TextEdit.new()
	description.name = "DescriptionEdit"
	description.placeholder_text = "Описание..."
	description.text = skill.description
	description.custom_minimum_size = Vector2(0, 58)
	description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description.scroll_horizontal = 0
	description.add_theme_constant_override("line_spacing", 0)
	_tighten_text_control(description)
	_apply_graph_field_style(description, Color("151a29"), Color("303b61"))
	description.set_meta("skill_old_value", skill.description)
	description.set_meta("skill_commit_target", skill)
	description.set_meta("skill_commit_mode", "description")
	description.focus_exited.connect(_on_description_commit.bind(description, skill))
	node.add_child(description)
	var params_toggle := Button.new()
	params_toggle.name = "ParametersToggle"
	params_toggle.toggle_mode = true
	params_toggle.text = "Параметры  ▸"
	params_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	params_toggle.custom_minimum_size.y = 24
	_apply_graph_section_style(params_toggle)
	node.add_child(params_toggle)
	var params_panel := PanelContainer.new()
	params_panel.name = "Parameters"
	params_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	params_panel.add_theme_stylebox_override("panel", _graph_section_panel_style())
	node.add_child(params_panel)
	var params_box := VBoxContainer.new()
	params_box.name = "ParametersContent"
	params_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	params_box.add_theme_constant_override("separation", 3)
	params_panel.visible = expanded_sections.get(skill.skill_id + ":parameters", false)
	params_panel.add_child(params_box)
	params_toggle.button_pressed = params_panel.visible
	params_toggle.text = "Параметры  ▾" if params_panel.visible else "Параметры  ▸"
	params_toggle.toggled.connect(func(opened):
		params_panel.visible = opened
		params_toggle.text = "Параметры  ▾" if opened else "Параметры  ▸"
		expanded_sections[skill.skill_id + ":parameters"] = opened
		_fit_node(node))
	var category_row := HBoxContainer.new()
	var category_label := Label.new()
	category_label.text = "Категория"
	category_label.custom_minimum_size.x = 74
	category_row.add_child(category_label)
	var category_option := _make_category_option(skill)
	category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_option.item_selected.connect(_on_category_selected.bind(category_option, skill))
	category_row.add_child(category_option)
	params_box.add_child(category_row)
	var icon_row := HBoxContainer.new()
	var icon_label := Label.new()
	icon_label.text = _translated("Иконка")
	icon_label.custom_minimum_size.x = 74
	icon_row.add_child(icon_label)
	var icon_picker := EditorResourcePicker.new()
	icon_picker.base_type = "Texture2D"
	icon_picker.edited_resource = skill.icon
	icon_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_picker.resource_changed.connect(_on_skill_icon_changed.bind(icon_picker, skill))
	icon_row.add_child(icon_picker)
	params_box.add_child(icon_row)
	var cost_toggle := Button.new()
	cost_toggle.toggle_mode = true
	cost_toggle.text = "%s  %s" % [_translated("Стоимость"), "▾" if expanded_sections.get(skill.skill_id + ":cost", false) else "▸"]
	cost_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_graph_section_style(cost_toggle)
	params_box.add_child(cost_toggle)
	var cost_panel := VBoxContainer.new()
	cost_panel.add_theme_constant_override("separation", 3)
	cost_panel.visible = expanded_sections.get(skill.skill_id + ":cost", false)
	params_box.add_child(cost_panel)
	cost_toggle.button_pressed = cost_panel.visible
	cost_toggle.toggled.connect(func(opened: bool):
		cost_panel.visible = opened
		cost_toggle.text = "%s  %s" % [_translated("Стоимость"), "▾" if opened else "▸"]
		expanded_sections[skill.skill_id + ":cost"] = opened
		_fit_node(node))
	_add_currency_option(cost_panel, skill)
	_add_number(cost_panel, _translated("Базовая цена"), skill.base_cost, skill, "base_cost", skill.skill_id, 0, 999999, true)
	_add_number(cost_panel, _translated("Cost growth"), skill.cost_growth_rate, skill, "cost_growth_rate", skill.skill_id, 0, 10, false)
	_add_costs_line(cost_panel, skill)
	var root_check := CheckButton.new()
	root_check.text = "Виден сразу"
	root_check.button_pressed = skill.starts_unlocked
	root_check.toggled.connect(_on_resource_toggle.bind(root_check, skill, "starts_unlocked", skill.skill_id))
	params_box.add_child(root_check)
	for requirement in skill.requirements:
		if requirement and current_tree.get_skill(requirement.parent_skill_id):
			_create_requirement_editor(params_box, skill, requirement)
	var effects_toggle := Button.new()
	effects_toggle.name = "EffectsToggle"
	effects_toggle.toggle_mode = true
	effects_toggle.text = "Эффекты (%d)  %s" % [skill.effects.size(), "▾" if expanded_sections.get(skill.skill_id + ":effects", false) else "▸"]
	effects_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	effects_toggle.custom_minimum_size.y = 24
	_apply_graph_section_style(effects_toggle)
	node.add_child(effects_toggle)
	var effects_panel := PanelContainer.new()
	effects_panel.name = "Effects"
	effects_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects_panel.add_theme_stylebox_override("panel", _graph_section_panel_style())
	node.add_child(effects_panel)
	var effects_box := VBoxContainer.new()
	effects_box.name = "EffectsContent"
	effects_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects_box.add_theme_constant_override("separation", 3)
	effects_panel.add_child(effects_box)
	effects_panel.visible = expanded_sections.get(skill.skill_id + ":effects", false)
	effects_toggle.button_pressed = effects_panel.visible
	effects_toggle.toggled.connect(func(opened):
		effects_panel.visible = opened
		effects_toggle.text = "Эффекты (%d)  %s" % [skill.effects.size(), "▾" if opened else "▸"]
		expanded_sections[skill.skill_id + ":effects"] = opened
		_fit_node(node))
	for effect in skill.effects:
		if effect:
			_create_effect_editor(effects_box, effect, skill)
	var add_effect := Button.new()
	add_effect.name = "AddEffectButton"
	add_effect.text = "+ Создать эффект"
	add_effect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_effect.focus_mode = Control.FOCUS_ALL
	add_effect.pressed.connect(_add_effect.bind(skill))
	effects_box.add_child(add_effect)
	_fit_node(node)

func _title_placeholder(locale_key: String) -> String:
	if locale_key.to_lower().begins_with("ru"):
		return "Название"
	if locale_key.to_lower().begins_with("en"):
		return "Title"
	return "Title"

func _tighten_text_control(control: Control) -> void:
	control.add_theme_constant_override("minimum_character_width", 1)
	control.add_theme_constant_override("line_spacing", 0)
	var normal := control.get_theme_stylebox("normal")
	if normal:
		var compact_style := normal.duplicate() as StyleBox
		compact_style.set_content_margin(SIDE_TOP, 2.0)
		compact_style.set_content_margin(SIDE_BOTTOM, 2.0)
		control.add_theme_stylebox_override("normal", compact_style)

func _apply_graph_field_style(control: Control, background: Color, border: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = border
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 5.0
	normal.content_margin_bottom = 5.0
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Color("6978db")
	focus.set_border_width_all(2)
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_stylebox_override("focus", focus)
	control.add_theme_color_override("font_color", Color("d9def5"))
	control.add_theme_color_override("font_placeholder_color", Color("77809d"))

func _apply_graph_section_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("262d43")
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("35416a")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("43518b")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("d9def5"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)

func _graph_section_panel_style() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("141a2a")
	panel.border_color = Color("303b61")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	panel.content_margin_left = 7.0
	panel.content_margin_right = 7.0
	panel.content_margin_top = 6.0
	panel.content_margin_bottom = 6.0
	return panel

func _fit_node(node: GraphNode) -> void:
	if not is_instance_valid(node):
		return
	call_deferred("_fit_node_after_layout", node.get_instance_id())

func _fit_node_after_layout(node_id: int) -> void:
	var graph_node := instance_from_id(node_id) as GraphNode
	if not graph_node or not is_instance_valid(graph_node):
		return
	var parameters := graph_node.get_node_or_null("Parameters") as Control
	var effects := graph_node.get_node_or_null("Effects") as Control
	var is_compact := (not parameters or not parameters.visible) and (not effects or not effects.visible)
	var minimum_size: Vector2 = graph_node.get_combined_minimum_size()
	if minimum_size.x > CARD_SIZE.x + 0.5:
		push_warning("Skill node '%s' requires %.1f px, above compact width %.1f" % [graph_node.name, minimum_size.x, CARD_SIZE.x])
		for child in graph_node.get_children():
			if child is Control:
				var child_minimum: Vector2 = child.get_combined_minimum_size()
				push_warning("  child '%s' requires %.1f x %.1f px" % [child.name, child_minimum.x, child_minimum.y])
		if status_label:
			_show_status("Layout: %s требует ширину %.0f px" % [graph_node.name, minimum_size.x])
	if is_compact:
		graph_node.size = CARD_SIZE
		return
	graph_node.reset_size()
	graph_node.size = Vector2(CARD_SIZE.x, maxf(CARD_SIZE.y, graph_node.get_combined_minimum_size().y))

func _create_requirement_editor(parent: VBoxContainer, child: SkillData, requirement: SkillRequirementData) -> void:
	var parent_skill := current_tree.get_skill(requirement.parent_skill_id)
	if not parent_skill:
		return
	var row := HBoxContainer.new()
	row.name = "Requirement_%s" % requirement.parent_skill_id
	row.tooltip_text = "Уровень родителя, необходимый для открытия навыка"
	var prefix := Label.new()
	prefix.text = "Требует"
	row.add_child(prefix)
	var label := Label.new()
	label.text = _editor_skill_title(parent_skill)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	var level := SpinBox.new()
	level.tooltip_text = "Минимальный уровень навыка выше"
	level.name = "RequiredLevel"
	level.min_value = 1
	level.max_value = maxi(1, parent_skill.max_level)
	level.step = 1
	level.value = clampi(requirement.required_level, 1, maxi(1, parent_skill.max_level))
	level.custom_minimum_size.x = 58
	level.value_changed.connect(_on_requirement_level_changed.bind(level, requirement, parent_skill, child))
	row.add_child(level)
	var remove := Button.new()
	remove.text = "×"
	remove.tooltip_text = "Удалить связь"
	remove.pressed.connect(_on_requirement_remove_pressed.bind(requirement.parent_skill_id, child.skill_id))
	row.add_child(remove)
	parent.add_child(row)

func _on_requirement_level_changed(value: float, spin: SpinBox, requirement: SkillRequirementData, parent_skill: SkillData, child: SkillData) -> void:
	var new_value := clampi(roundi(value), 1, maxi(1, parent_skill.max_level))
	spin.value = new_value
	var old_value: int = int(spin.get_meta("skill_old_value", requirement.required_level))
	if old_value == new_value:
		return
	spin.set_meta("skill_old_value", new_value)
	_record_property(requirement, "required_level", old_value, new_value, child.skill_id)

func _on_requirement_remove_pressed(parent_id: String, child_id: String) -> void:
	_on_disconnection_request(StringName(parent_id), 0, StringName(child_id), 0)

func _create_effect_editor(parent: VBoxContainer, effect: SkillEffectData, skill: SkillData) -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 2)
	parent.add_child(panel)
	var header := HBoxContainer.new()
	panel.add_child(header)
	var delete := Button.new()
	delete.text = "×"
	delete.tooltip_text = "Удалить эффект"
	delete.pressed.connect(_delete_effect.bind(skill, effect))
	header.add_child(delete)

	var stat_row := HBoxContainer.new()
	var stat_label := Label.new()
	stat_label.text = "Характеристика"
	stat_label.custom_minimum_size.x = 74
	stat_row.add_child(stat_label)
	var stat_option := _make_player_stat_option(effect)
	stat_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_option.item_selected.connect(_on_effect_stat_selected.bind(stat_option, effect, skill.skill_id))
	stat_row.add_child(stat_option)
	panel.add_child(stat_row)
	var target_stat := current_tree.get_player_stat(effect.target_property) if current_tree else null
	var is_array_stat := target_stat and int(target_stat.get("value_type")) == SkillTreeStatData.ValueType.ARRAY
	var is_dictionary_stat := target_stat and int(target_stat.get("value_type")) == SkillTreeStatData.ValueType.DICTIONARY
	var is_collection := is_array_stat or is_dictionary_stat
	var effect_value_type := int(target_stat.get("array_element_type")) if is_collection else effect.value_type
	var is_bool_effect := effect_value_type == SkillTreeStatData.ValueType.BOOL
	# The conditional expression produces an untyped Array in Godot 4.8.
	var operation_items := ["Установить"] if is_bool_effect else ["Прибавить", "Вычесть", "Умножить", "Разделить", "Установить"]
	if is_dictionary_stat:
		operation_items.append("Добавить уникальное")
	if is_array_stat:
		if effect.operation == SkillEffectData.Operation.ADD_UNIQUE:
			effect.operation = SkillEffectData.Operation.ADD
		if effect.operation not in [SkillEffectData.Operation.ADD_UNIQUE, SkillEffectData.Operation.ERASE]:
			effect.target_kind = SkillEffectData.TargetKind.ARRAY_INDEX
	var effect_value_is_int := effect_value_type == SkillTreeStatData.ValueType.INT
	var operation := _make_option(operation_items, 0 if is_bool_effect else _operation_ui_index(effect.operation, is_dictionary_stat))
	operation.item_selected.connect(_on_operation_selected.bind(effect, skill.skill_id, panel))
	panel.add_child(operation)
	if is_array_stat:
		var target_index := _add_number(panel, "Индекс", effect.target_index, effect, "target_index", skill.skill_id, 0, 999999999, true)
		target_index.get_parent().name = "Index"
		var initial_values: Array = target_stat.call("get_base_value")
		target_index.max_value = maxi(0, initial_values.size() - 1)
		target_index.allow_greater = false
		target_index.editable = not initial_values.is_empty()
		target_index.tooltip_text = "Индекс от 0 до %d" % maxi(0, initial_values.size() - 1)
	if is_dictionary_stat:
		_create_dictionary_effect_key_editor(panel, effect, skill, effect.operation == SkillEffectData.Operation.ADD_UNIQUE)
	if is_bool_effect:
		_add_bool(panel, "Effect value", bool(effect.get_base_value()), effect, "base_effect_value", skill.skill_id)
		var toggle_mode := CheckButton.new()
		toggle_mode.text = "Режим переключения"
		toggle_mode.tooltip_text = "После покупки игрок сможет нажимать навык повторно, чтобы включать и выключать это Bool-значение."
		toggle_mode.button_pressed = effect.toggle_mode
		toggle_mode.toggled.connect(_on_resource_toggle.bind(toggle_mode, effect, "toggle_mode", skill.skill_id))
		panel.add_child(toggle_mode)
	else:
		var base_value := _add_number(panel, "Effect value", float(effect.get_base_value()), effect, "base_effect_value", skill.skill_id, -999999999, 999999999, effect_value_is_int)
		base_value.name = "BaseEffectValue"
		_add_number(panel, "Effect growth", effect.effect_value_growth_rate, effect, "effect_value_growth_rate", skill.skill_id, -10, 10, false)
	if not is_bool_effect:
		var clamp_toggle := CheckButton.new()
		clamp_toggle.name = "ClampToggle"
		clamp_toggle.text = "Ограничить минимумом и максимумом"
		clamp_toggle.add_theme_font_size_override("font_size", 12)
		clamp_toggle.custom_minimum_size = Vector2(0, 24)
		clamp_toggle.button_pressed = effect.use_clamp
		clamp_toggle.toggled.connect(_on_clamp_toggled.bind(clamp_toggle, effect, skill.skill_id, panel))
		panel.add_child(clamp_toggle)
		var minimum := _add_number(panel, "Минимум", effect.minimum, effect, "minimum", skill.skill_id, -999999999, 999999999, false)
		minimum.get_parent().name = "Minimum"
		var maximum := _add_number(panel, "Максимум", effect.maximum, effect, "maximum", skill.skill_id, -999999999, 999999999, false)
		maximum.get_parent().name = "Maximum"
	_update_effect_visibility(panel, effect)

func _make_option(items: Array, selected: int) -> OptionButton:
	var option := OptionButton.new()
	for item in items:
		option.add_item(item)
	option.select(clampi(selected, 0, items.size() - 1))
	return option

func _on_skill_icon_changed(resource: Resource, picker: EditorResourcePicker, skill: SkillData) -> void:
	if not current_tree or not skill:
		return
	var before := _clone_tree(current_tree)
	skill.icon = resource as Texture2D
	_commit_snapshot(before, _clone_tree(current_tree), "Изменить иконку навыка")
	picker.edited_resource = skill.icon

func _ensure_categories() -> void:
	if not current_tree:
		return
	if current_tree.categories.is_empty():
		current_tree.categories.append("SKILL_CATEGORY_MAIN")
	for skill in current_tree.skills:
		if skill and not skill.category.strip_edges().is_empty() and not current_tree.categories.has(skill.category):
			current_tree.categories.append(skill.category)

func _make_category_option(skill: SkillData) -> OptionButton:
	var option := OptionButton.new()
	option.set_meta("skill_category_option", true)
	_ensure_categories()
	for category in current_tree.categories:
		option.add_item(_category_display_name(category))
		if category == skill.category:
			option.select(option.item_count - 1)
	return option

func _category_display_name(category: String) -> String:
	if category == "SKILL_CATEGORY_MAIN":
		return "Main" if language == "en" else "Основная"
	return category

func _make_player_stat_option(effect: SkillEffectData) -> OptionButton:
	var option := OptionButton.new()
	var keys := current_tree.get_player_stat_keys() if current_tree else []
	if keys.is_empty():
		option.add_item("Создайте характеристику")
		option.disabled = true
		return option
	for key in keys:
		option.add_item(key)
		if key == effect.target_property:
			option.select(option.item_count - 1)
	return option

func _create_dictionary_effect_key_editor(panel: VBoxContainer, effect: SkillEffectData, skill: SkillData, is_add_unique: bool) -> void:
	if is_add_unique:
		var key_edit := _add_line(panel, "Новый ключ", effect.target_key, effect, "target_key", skill.skill_id)
		key_edit.placeholder_text = "например stick"
		for locale_data in current_tree.get_locales() if current_tree else []:
			var locale_key := str(locale_data.get("key", ""))
			var translation_edit := _add_line(panel, str(locale_data.get("name", locale_key)), str(effect.unique_key_translations.get(locale_key, "")), null, "", skill.skill_id)
			translation_edit.placeholder_text = "Описание ключа" if locale_key != "en" else "Key description"
			translation_edit.focus_exited.connect(_on_unique_key_translation_commit.bind(translation_edit, effect, skill.skill_id, locale_key))
			translation_edit.text_submitted.connect(func(_text): _on_unique_key_translation_commit(translation_edit, effect, skill.skill_id, locale_key))
		return
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Ключ"
	label.custom_minimum_size.x = 74
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stat := current_tree.get_player_stat(effect.target_property) if current_tree else null
	var values: Dictionary = stat.call("get_base_value") if stat else {}
	var keys: Array[String] = []
	for entry_key in values:
		keys.append(str(entry_key))
	keys.sort()
	if keys.is_empty():
		option.add_item("Сначала создайте ключ")
		option.disabled = true
	else:
		for entry_key in keys:
			option.add_item(entry_key)
			if entry_key == effect.target_key:
				option.select(option.item_count - 1)
		option.item_selected.connect(_on_dictionary_effect_key_selected.bind(option, effect, skill.skill_id))
	row.add_child(option)
	panel.add_child(row)

func _on_unique_key_translation_commit(edit: LineEdit, effect: SkillEffectData, skill_id: String, locale_key: String) -> void:
	if not current_tree or str(effect.unique_key_translations.get(locale_key, "")) == edit.text:
		return
	var before := _clone_tree(current_tree)
	var translations := effect.unique_key_translations.duplicate(true)
	translations[locale_key] = edit.text
	effect.unique_key_translations = translations
	_commit_snapshot(before, _clone_tree(current_tree), "Изменить перевод нового ключа")

func _on_dictionary_effect_key_selected(index: int, option: OptionButton, effect: SkillEffectData, skill_id: String) -> void:
	if index >= 0 and index < option.item_count:
		_record_property(effect, "target_key", effect.target_key, option.get_item_text(index), skill_id)

func _on_effect_stat_selected(index: int, option: OptionButton, effect: SkillEffectData, skill_id: String) -> void:
	if index < 0 or index >= option.item_count:
		return
	var key := option.get_item_text(index)
	_record_property(effect, "target_property", effect.target_property, key, skill_id)
	var stat := current_tree.get_player_stat(key) if current_tree else null
	if stat:
		var stat_type := int(stat.get("value_type"))
		var is_array_stat := stat_type == SkillTreeStatData.ValueType.ARRAY
		var is_dictionary_stat := stat_type == SkillTreeStatData.ValueType.DICTIONARY
		_record_property(effect, "array_mode", effect.array_mode, is_array_stat, skill_id)
		var target_kind := SkillEffectData.TargetKind.ARRAY_INDEX if is_array_stat else (SkillEffectData.TargetKind.DICTIONARY_KEY if is_dictionary_stat else SkillEffectData.TargetKind.PROPERTY)
		_record_property(effect, "target_kind", effect.target_kind, target_kind, skill_id)
		var selected_value_type := int(stat.get("array_element_type")) if is_array_stat or is_dictionary_stat else stat_type
		_record_property(effect, "value_type", effect.value_type, selected_value_type, skill_id)
		# Keep the effect value in the same numeric type as the selected stat.
		# This matters for both serialization and the editor's displayed value.
		var converted_value: Variant = _coerce_effect_editor_value(effect.get_base_value(), selected_value_type)
		_record_property(effect, "base_effect_value", effect.get_base_value(), converted_value, skill_id)
		var converted_default: Variant = _coerce_effect_editor_value(effect.default_value, selected_value_type)
		_record_property(effect, "default_value", effect.default_value, converted_default, skill_id)
		if selected_value_type == SkillTreeStatData.ValueType.BOOL:
			_record_property(effect, "operation", effect.operation, SkillEffectData.Operation.SET, skill_id)
		if not is_dictionary_stat and effect.operation == SkillEffectData.Operation.ADD_UNIQUE:
			_record_property(effect, "operation", effect.operation, SkillEffectData.Operation.ADD, skill_id)
		if is_dictionary_stat and effect.target_key.is_empty():
			var values: Dictionary = stat.call("get_base_value")
			if not values.is_empty():
				_record_property(effect, "target_key", effect.target_key, str(values.keys()[0]), skill_id)
	_redraw_graph()

func _on_category_selected(index: int, option: OptionButton, skill: SkillData) -> void:
	if index >= 0 and index < option.item_count:
		_record_property(skill, "category", skill.category, option.get_item_text(index), skill.skill_id)

func _create_category(value: String) -> void:
	if not current_tree:
		return
	var category := value.strip_edges()
	if category.is_empty() or current_tree.categories.has(category):
		return
	current_tree.categories.append(category)
	dirty = true
	_refresh_category_list()
	_redraw_graph()

func _open_category_dialog() -> void:
	if not category_dialog:
		return
	_refresh_category_list()
	category_edit.clear()
	category_rename_edit.clear()
	category_dialog.popup_centered()

func _refresh_category_list() -> void:
	if not category_list or not current_tree:
		return
	_ensure_categories()
	category_list.clear()
	for category in current_tree.categories:
		category_list.add_item(category)

func _get_selected_category_index() -> int:
	if not category_list:
		return -1
	var selected := category_list.get_selected_items()
	return int(selected[0]) if not selected.is_empty() else -1

func _rename_selected_category(value: String) -> void:
	var index := _get_selected_category_index()
	var new_name := value.strip_edges()
	if index < 0 or new_name.is_empty() or current_tree.categories.has(new_name):
		return
	var old_name := current_tree.categories[index]
	var before := _clone_tree(current_tree)
	current_tree.categories[index] = new_name
	for skill in current_tree.skills:
		if skill and skill.category == old_name:
			skill.category = new_name
	_commit_snapshot(before, _clone_tree(current_tree), "Переименовать категорию")
	category_rename_edit.clear()
	_refresh_category_list()
	_redraw_graph()

func _delete_selected_category() -> void:
	var index := _get_selected_category_index()
	if index < 0 or current_tree.categories.size() <= 1:
		return
	var deleted := current_tree.categories[index]
	var replacement := current_tree.categories[0] if index != 0 else current_tree.categories[1]
	var before := _clone_tree(current_tree)
	current_tree.categories.remove_at(index)
	for skill in current_tree.skills:
		if skill and skill.category == deleted:
			skill.category = replacement
	_commit_snapshot(before, _clone_tree(current_tree), "Удалить категорию")
	_refresh_category_list()
	_redraw_graph()

func _open_stats_dialog(hint := "") -> void:
	if not stats_dialog:
		return
	stats_hint_label.text = hint
	stats_hint_label.visible = not hint.is_empty()
	_refresh_stats_list()
	stats_list.deselect_all()
	edit_stat_button.disabled = true
	stat_key_edit.clear()
	_rebuild_stat_translation_inputs()
	stat_type_option.select(1)
	stat_array_element_type_option.select(1)
	stat_base_value.value = 0.0
	stat_bool_value.button_pressed = false
	stat_array_base_value.clear()
	stat_array_draft.clear()
	stat_dictionary_draft.clear()
	_update_stat_base_value_input()
	stats_dialog.size = Vector2i(520, 420)
	stats_dialog.popup_centered()

func _stat_title_key(stat_key: String) -> String:
	return "STAT_%s" % stat_key.strip_edges().to_upper()

func _rebuild_stat_translation_inputs(stat: Resource = null) -> void:
	if not stat_translations_container:
		return
	for child in stat_translations_container.get_children():
		child.queue_free()
	stat_translation_edits.clear()
	if not current_tree:
		return
	var existing: Dictionary = stat.get("translations") if stat else {}
	for locale_data in current_tree.get_locales():
		var locale_key := str(locale_data.get("key", ""))
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(locale_data.get("name", locale_key))
		label.custom_minimum_size.x = 96
		row.add_child(label)
		var edit := LineEdit.new()
		edit.placeholder_text = _stat_title_key(stat_key_edit.text) if not stat_key_edit.text.strip_edges().is_empty() else "Перевод"
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var legacy := ""
		if stat:
			legacy = str(stat.get("title_ru")) if locale_key == "ru" else (str(stat.get("title_en")) if locale_key == "en" else "")
		edit.text = str(existing.get(locale_key, legacy))
		row.add_child(edit)
		stat_translation_edits[locale_key] = edit
		stat_translations_container.add_child(row)

func _get_stat_translation_values() -> Dictionary:
	var result := {}
	for locale_key in stat_translation_edits:
		var edit := stat_translation_edits[locale_key] as LineEdit
		if edit and not edit.text.strip_edges().is_empty():
			result[locale_key] = edit.text.strip_edges()
	return result

func _open_locales_dialog() -> void:
	if not locales_dialog or not current_tree:
		return
	_refresh_locales_list()
	locale_key_edit.clear()
	locale_name_edit.clear()
	locales_dialog.popup_centered()

func _open_currency_dialog() -> void:
	if not current_tree or not currency_dialog:
		return
	current_tree.ensure_default_currency()
	currency_dialog.configure(current_tree, language)
	currency_dialog.popup_centered(Vector2i(540, 430))

func _on_currencies_changed() -> void:
	dirty = true
	_redraw_graph()

func _open_colors_dialog() -> void:
	if not colors_dialog or not current_tree:
		return
	colors_dialog.title = _translated("Цвета")
	colors_dialog.ok_button_text = _translated("Закрыть")
	if state_colors_toggle:
		state_colors_toggle.text = _translated("Состояния навыка  ▾" if state_colors_toggle.button_pressed else "Состояния навыка  ▸")
	_refresh_state_colors()
	colors_dialog.popup_centered()

func _refresh_state_colors() -> void:
	if not state_colors_panel or not current_tree:
		return
	for child in state_colors_panel.get_children():
		child.queue_free()
	state_color_buttons.clear()
	var color_fields := [
		{"key": "enough_currency", "label": "Хватает валюты"},
		{"key": "not_enough_currency", "label": "Не хватает валюты"},
		{"key": "available", "label": "Доступен"},
		{"key": "unavailable", "label": "Недоступен"},
		{"key": "max_level", "label": "Максимальный уровень"},
		{"key": "next_value", "label": "Следующее значение"}
	]
	for field in color_fields:
		var color_key := str(field["key"])
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = _translated(str(field["label"]))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(74, 28)
		picker.color = current_tree.get_state_color(color_key)
		picker.color_changed.connect(_on_state_color_changed.bind(color_key))
		row.add_child(picker)
		state_color_buttons[color_key] = picker
		state_colors_panel.add_child(row)

func _on_state_color_changed(color: Color, color_key: String) -> void:
	if not current_tree or current_tree.get_state_color(color_key) == color:
		return
	var before := _clone_tree(current_tree)
	current_tree.state_colors[color_key] = color
	_commit_snapshot(before, _clone_tree(current_tree), "Изменить цвет состояния")

func _refresh_locales_list() -> void:
	if not locales_list or not current_tree:
		return
	locales_list.clear()
	for locale_data in current_tree.get_locales():
		locales_list.add_item("%s — %s" % [locale_data.get("key", ""), locale_data.get("name", "")])

func _on_locale_selected(index: int) -> void:
	if not current_tree:
		return
	var locales := current_tree.get_locales()
	if index < 0 or index >= locales.size():
		return
	locale_key_edit.text = str(locales[index].get("key", ""))
	locale_name_edit.text = str(locales[index].get("name", ""))

func _add_locale() -> void:
	if not current_tree:
		return
	var locale_key := locale_key_edit.text.strip_edges().to_lower()
	var locale_name := locale_name_edit.text.strip_edges()
	if locale_key.is_empty() or locale_name.is_empty():
		return
	for locale_data in current_tree.get_locales():
		if str(locale_data.get("key", "")) == locale_key:
			return
	var before := _clone_tree(current_tree)
	current_tree.locales.append({"key": locale_key, "name": locale_name})
	_commit_snapshot(before, _clone_tree(current_tree), "Добавить язык")
	_refresh_locales_list()
	locale_key_edit.clear()
	locale_name_edit.clear()

func _remove_selected_locale() -> void:
	if not current_tree or not locales_list:
		return
	var selected := locales_list.get_selected_items()
	if selected.is_empty() or current_tree.locales.size() <= 1:
		return
	var index := int(selected[0])
	if index < 0 or index >= current_tree.locales.size():
		return
	var before := _clone_tree(current_tree)
	current_tree.locales.remove_at(index)
	_commit_snapshot(before, _clone_tree(current_tree), "Удалить язык")
	_refresh_locales_list()
	locale_key_edit.clear()
	locale_name_edit.clear()

func _on_stat_type_selected(index: int) -> void:
	_update_stat_base_value_input()
	if not current_tree or not stats_list:
		return
	var selected := stats_list.get_selected_items()
	if selected.is_empty() or index < 0 or index >= stat_type_option.item_count:
		return
	var stat_index := int(selected[0])
	if stat_index < 0 or stat_index >= current_tree.player_stats.size():
		return
	var stat: Resource = current_tree.player_stats[stat_index]
	var new_type := index
	var new_element_type := _selected_collection_value_type()
	if int(stat.get("value_type")) == new_type and int(stat.get("array_element_type")) == new_element_type:
		return
	var before := _clone_tree(current_tree)
	var old_type := int(stat.get("value_type"))
	var previous_base: Variant = stat.call("get_base_value")
	if previous_base is Array:
		previous_base = previous_base[0] if not previous_base.is_empty() else 0
	elif previous_base is Dictionary:
		previous_base = previous_base.values()[0] if not previous_base.is_empty() else 0
	stat.set("value_type", new_type)
	stat.set("array_element_type", new_element_type)
	if new_type == SkillTreeStatData.ValueType.BOOL:
		stat.set("base_value", bool(previous_base))
	elif new_type == SkillTreeStatData.ValueType.INT:
		stat.set("base_value", _coerce_stat_value(previous_base, SkillTreeStatData.ValueType.INT))
	elif new_type == SkillTreeStatData.ValueType.FLOAT:
		stat.set("base_value", _coerce_stat_value(previous_base, SkillTreeStatData.ValueType.FLOAT))
	for skill in current_tree.skills:
		if not skill:
			continue
		for effect in skill.effects:
			if not effect or effect.target_property != stat.key:
				continue
			var effect_type := new_element_type if new_type in [SkillTreeStatData.ValueType.ARRAY, SkillTreeStatData.ValueType.DICTIONARY] else new_type
			effect.value_type = effect_type
			effect.array_mode = new_type == SkillTreeStatData.ValueType.ARRAY
			effect.target_kind = SkillEffectData.TargetKind.ARRAY_INDEX if new_type == SkillTreeStatData.ValueType.ARRAY else (SkillEffectData.TargetKind.DICTIONARY_KEY if new_type == SkillTreeStatData.ValueType.DICTIONARY else SkillEffectData.TargetKind.PROPERTY)
			effect.base_effect_value = _coerce_effect_editor_value(effect.get_base_value(), effect_type)
			effect.default_value = _coerce_effect_editor_value(effect.default_value, effect_type)
			if effect_type == SkillTreeStatData.ValueType.BOOL:
				effect.operation = SkillEffectData.Operation.SET
				effect.use_clamp = false
			elif old_type == SkillTreeStatData.ValueType.BOOL and effect.operation == SkillEffectData.Operation.SET:
				effect.operation = SkillEffectData.Operation.ADD
	_commit_snapshot(before, _clone_tree(current_tree), "Изменить тип характеристики")
	_refresh_stats_list()
	stats_list.select(stat_index)
	_redraw_graph()

func _update_stat_base_value_input() -> void:
	if not stat_type_option or not stat_base_value:
		return
	var is_array_stat := stat_type_option.selected == SkillTreeStatData.ValueType.ARRAY
	var is_dictionary_stat := stat_type_option.selected == SkillTreeStatData.ValueType.DICTIONARY
	var is_bool_stat := stat_type_option.selected == SkillTreeStatData.ValueType.BOOL
	var is_collection := is_array_stat or is_dictionary_stat
	stat_base_value.visible = not is_collection and not is_bool_stat
	stat_bool_value.visible = is_bool_stat
	stat_base_value.editable = not is_collection
	stat_array_base_row.visible = false
	stat_array_entries.visible = is_array_stat
	stat_dictionary_row.visible = is_dictionary_stat
	stat_array_element_type_option.visible = is_collection
	var type_label := stat_array_element_type_option.get_meta("type_label") as Label
	if type_label:
		type_label.visible = is_collection
	if is_dictionary_stat and stat_dictionary_draft.is_empty():
		stat_dictionary_draft.append({"key": "", "value": 0.0})
		_rebuild_dictionary_draft()
	if is_array_stat and stat_array_draft.is_empty():
		var legacy_values := _parse_array_default(stat_array_base_value.text, _selected_collection_value_type())
		for value in legacy_values:
			stat_array_draft.append({"value": value, "translations": {}})
		_rebuild_array_draft()
	stat_base_value.step = 1.0 if stat_type_option.selected == SkillTreeStatData.ValueType.INT else 0.01

func _add_dictionary_draft_entry() -> void:
	var element_type := _selected_collection_value_type()
	var element_value: Variant = false if element_type == SkillTreeStatData.ValueType.BOOL else (0 if element_type == SkillTreeStatData.ValueType.INT else 0.0)
	stat_dictionary_draft.append({"key": "", "value": element_value, "translations": {}})
	_rebuild_dictionary_draft()

func _add_array_draft_entry() -> void:
	var element_type := _selected_collection_value_type()
	var element_value: Variant = false if element_type == SkillTreeStatData.ValueType.BOOL else (0 if element_type == SkillTreeStatData.ValueType.INT else 0.0)
	stat_array_draft.append({"value": element_value, "translations": {}})
	_rebuild_array_draft()

func _rebuild_array_draft() -> void:
	if not stat_array_entries:
		return
	for child in stat_array_entries.get_children():
		child.queue_free()
	for index in stat_array_draft.size():
		var row := HBoxContainer.new()
		var index_label := Label.new()
		index_label.text = "[%d]" % index
		index_label.custom_minimum_size.x = 36
		row.add_child(index_label)
		if _selected_collection_value_type() == SkillTreeStatData.ValueType.BOOL:
			var value_bool := CheckButton.new()
			value_bool.text = "True"
			value_bool.button_pressed = bool(stat_array_draft[index].get("value", false))
			value_bool.toggled.connect(_on_array_draft_bool_changed.bind(index))
			row.add_child(value_bool)
		else:
			var value_spin := SpinBox.new()
			value_spin.min_value = -999999999
			value_spin.max_value = 999999999
			value_spin.step = 1.0 if _selected_collection_value_type() == SkillTreeStatData.ValueType.INT else 0.01
			value_spin.value = float(stat_array_draft[index].get("value", 0.0))
			value_spin.custom_minimum_size.x = 92
			value_spin.value_changed.connect(_on_array_draft_value_changed.bind(index))
			row.add_child(value_spin)
		var translations_box := VBoxContainer.new()
		translations_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for locale_data in current_tree.get_locales() if current_tree else []:
			var locale_key := str(locale_data.get("key", ""))
			var edit := LineEdit.new()
			var description_label := "Index description" if locale_key == "en" else "Описание индекса"
			edit.placeholder_text = "%s: %s" % [locale_key, description_label]
			edit.text = str((stat_array_draft[index].get("translations", {}) as Dictionary).get(locale_key, ""))
			edit.text_changed.connect(_on_array_translation_changed.bind(index, locale_key))
			translations_box.add_child(edit)
		row.add_child(translations_box)
		var remove := Button.new()
		remove.text = "×"
		remove.pressed.connect(_remove_array_draft_entry.bind(index))
		row.add_child(remove)
		stat_array_entries.add_child(row)
	var add := Button.new()
	add.text = "+ Индекс"
	add.pressed.connect(_add_array_draft_entry)
	stat_array_entries.add_child(add)

func _on_array_draft_value_changed(value: float, index: int) -> void:
	if index >= 0 and index < stat_array_draft.size():
		stat_array_draft[index]["value"] = int(value) if _selected_collection_value_type() == SkillTreeStatData.ValueType.INT else value

func _on_array_draft_bool_changed(value: bool, index: int) -> void:
	if index >= 0 and index < stat_array_draft.size():
		stat_array_draft[index]["value"] = value

func _on_array_translation_changed(value: String, index: int, locale_key: String) -> void:
	if index >= 0 and index < stat_array_draft.size():
		var translations: Dictionary = stat_array_draft[index].get("translations", {})
		translations[locale_key] = value
		stat_array_draft[index]["translations"] = translations

func _remove_array_draft_entry(index: int) -> void:
	if index >= 0 and index < stat_array_draft.size():
		stat_array_draft.remove_at(index)
		_rebuild_array_draft()

func _array_from_draft(element_type: int) -> Array:
	var result: Array = []
	for entry in stat_array_draft:
		result.append(_coerce_stat_value(entry.get("value", false), element_type))
	return result

func _array_translations_from_draft() -> Dictionary:
	var result := {}
	for index in stat_array_draft.size():
		result[str(index)] = (stat_array_draft[index].get("translations", {}) as Dictionary).duplicate(true)
	return result

func _rebuild_dictionary_draft() -> void:
	if not stat_dictionary_entries:
		return
	for child in stat_dictionary_entries.get_children():
		child.queue_free()
	for index in stat_dictionary_draft.size():
		var row := HBoxContainer.new()
		var key_edit := LineEdit.new()
		key_edit.placeholder_text = "Ключ, например hand"
		key_edit.text = str(stat_dictionary_draft[index].get("key", ""))
		key_edit.custom_minimum_size.x = 150
		key_edit.text_changed.connect(_on_dictionary_draft_key_changed.bind(index))
		row.add_child(key_edit)
		if _selected_collection_value_type() == SkillTreeStatData.ValueType.BOOL:
			var value_bool := CheckButton.new()
			value_bool.text = "True"
			value_bool.button_pressed = bool(stat_dictionary_draft[index].get("value", false))
			value_bool.toggled.connect(_on_dictionary_draft_bool_changed.bind(index))
			row.add_child(value_bool)
		else:
			var value_spin := SpinBox.new()
			value_spin.min_value = -999999999
			value_spin.max_value = 999999999
			value_spin.step = 1.0 if _selected_collection_value_type() == SkillTreeStatData.ValueType.INT else 0.01
			value_spin.value = float(stat_dictionary_draft[index].get("value", 0.0))
			value_spin.custom_minimum_size.x = 92
			value_spin.value_changed.connect(_on_dictionary_draft_value_changed.bind(index))
			row.add_child(value_spin)
		var translations_box := VBoxContainer.new()
		translations_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for locale_data in current_tree.get_locales() if current_tree else []:
			var locale_key := str(locale_data.get("key", ""))
			var translation_edit := LineEdit.new()
			translation_edit.placeholder_text = "%s: перевод ключа" % locale_key
			translation_edit.text = str((stat_dictionary_draft[index].get("translations", {}) as Dictionary).get(locale_key, ""))
			translation_edit.text_changed.connect(_on_dictionary_translation_changed.bind(index, locale_key))
			translations_box.add_child(translation_edit)
		row.add_child(translations_box)
		var remove := Button.new()
		remove.text = "×"
		remove.tooltip_text = "Удалить ключ"
		remove.pressed.connect(_remove_dictionary_draft_entry.bind(index))
		row.add_child(remove)
		stat_dictionary_entries.add_child(row)

func _on_dictionary_draft_key_changed(value: String, index: int) -> void:
	if index >= 0 and index < stat_dictionary_draft.size():
		stat_dictionary_draft[index]["key"] = value.strip_edges()

func _on_dictionary_translation_changed(value: String, index: int, locale_key: String) -> void:
	if index >= 0 and index < stat_dictionary_draft.size():
		var translations: Dictionary = stat_dictionary_draft[index].get("translations", {})
		translations[locale_key] = value
		stat_dictionary_draft[index]["translations"] = translations

func _on_dictionary_draft_value_changed(value: float, index: int) -> void:
	if index >= 0 and index < stat_dictionary_draft.size():
		stat_dictionary_draft[index]["value"] = int(value) if _selected_collection_value_type() == SkillTreeStatData.ValueType.INT else value

func _on_dictionary_draft_bool_changed(value: bool, index: int) -> void:
	if index >= 0 and index < stat_dictionary_draft.size():
		stat_dictionary_draft[index]["value"] = value

func _remove_dictionary_draft_entry(index: int) -> void:
	if index >= 0 and index < stat_dictionary_draft.size():
		stat_dictionary_draft.remove_at(index)
		_rebuild_dictionary_draft()

func _dictionary_from_draft(element_type: int) -> Dictionary:
	var result := {}
	for entry in stat_dictionary_draft:
		var entry_key := str(entry.get("key", "")).strip_edges()
		if not entry_key.is_empty() and not result.has(entry_key):
			result[entry_key] = _coerce_stat_value(entry.get("value", false), element_type)
	return result

func _dictionary_translations_from_draft() -> Dictionary:
	var result := {}
	for entry in stat_dictionary_draft:
		var key := str(entry.get("key", "")).strip_edges()
		if not key.is_empty():
			result[key] = (entry.get("translations", {}) as Dictionary).duplicate(true)
	return result

func _refresh_stats_list() -> void:
	if not stats_list or not current_tree:
		return
	stats_list.clear()
	for stat in current_tree.player_stats:
		if stat:
			var type_name: String = ["Int", "Float", "Array", "Dictionary", "Bool"][clampi(int(stat.get("value_type")), 0, 4)]
			if int(stat.get("value_type")) == SkillTreeStatData.ValueType.ARRAY:
				type_name = "Array<%s>" % ["Int", "Float", "Bool"][clampi(int(stat.get("array_element_type")), 0, 2)]
			elif int(stat.get("value_type")) == SkillTreeStatData.ValueType.DICTIONARY:
				type_name = "Dictionary<%s>" % ["Int", "Float", "Bool"][clampi(int(stat.get("array_element_type")), 0, 2)]
			stats_list.add_item("%s = %s (%s)" % [stat.get("key"), stat.call("get_base_value"), type_name])

func _on_stat_selected(index: int) -> void:
	if not current_tree or index < 0 or index >= current_tree.player_stats.size():
		return
	var stat: Resource = current_tree.player_stats[index]
	if not stat:
		return
	stat_key_edit.text = str(stat.get("key"))
	_rebuild_stat_translation_inputs(stat)
	stat_type_option.select(int(stat.get("value_type")))
	stat_array_element_type_option.select(stat_array_element_type_option.get_item_index(int(stat.get("array_element_type"))))
	var base_value: Variant = stat.call("get_base_value")
	if base_value is Array:
		stat_array_draft.clear()
		var collection_translations: Dictionary = stat.get("collection_translations")
		for array_index in base_value.size():
			stat_array_draft.append({"value": base_value[array_index], "translations": collection_translations.get(str(array_index), {}).duplicate(true)})
		_rebuild_array_draft()
	elif base_value is Dictionary:
		stat_dictionary_draft.clear()
		for entry_key in base_value:
			stat_dictionary_draft.append({"key": str(entry_key), "value": base_value[entry_key], "translations": (stat.get("collection_translations") as Dictionary).get(str(entry_key), {}).duplicate(true)})
		_rebuild_dictionary_draft()
	else:
		if int(stat.get("value_type")) == SkillTreeStatData.ValueType.BOOL:
			stat_bool_value.button_pressed = bool(base_value)
		else:
			stat_base_value.value = float(base_value)
	_update_stat_base_value_input()
	edit_stat_button.disabled = false

func _update_selected_player_stat() -> void:
	if not current_tree or not stats_list:
		return
	var selected := stats_list.get_selected_items()
	if selected.is_empty():
		return
	var index := int(selected[0])
	if index < 0 or index >= current_tree.player_stats.size():
		return
	var stat: Resource = current_tree.player_stats[index]
	var new_key := stat_key_edit.text.strip_edges()
	if new_key.is_empty():
		return
	var existing := current_tree.get_player_stat(new_key)
	if existing and existing != stat:
		return
	var before := _clone_tree(current_tree)
	var old_key := str(stat.get("key"))
	stat.set("key", new_key)
	stat.set("title_key", _stat_title_key(new_key))
	stat.set("translations", _get_stat_translation_values())
	stat.set("value_type", stat_type_option.selected)
	stat.set("array_element_type", _selected_collection_value_type())
	var base_value: Variant = _stat_editor_base_value()
	if stat_type_option.selected == SkillTreeStatData.ValueType.ARRAY:
		base_value = _array_from_draft(_selected_collection_value_type())
	elif stat_type_option.selected == SkillTreeStatData.ValueType.DICTIONARY:
		base_value = _dictionary_from_draft(_selected_collection_value_type())
	stat.set("base_value", base_value)
	stat.set("collection_translations", _array_translations_from_draft() if stat_type_option.selected == SkillTreeStatData.ValueType.ARRAY else (_dictionary_translations_from_draft() if stat_type_option.selected == SkillTreeStatData.ValueType.DICTIONARY else {}))
	if old_key != new_key:
		for skill in current_tree.skills:
			if not skill:
				continue
			for effect in skill.effects:
				if effect and effect.target_property == old_key:
					effect.target_property = new_key
	_commit_snapshot(before, _clone_tree(current_tree), "Изменить характеристику")
	_refresh_stats_list()
	stats_list.select(index)
	_redraw_graph()

func _create_player_stat() -> void:
	if not current_tree:
		return
	var key := stat_key_edit.text.strip_edges()
	if key.is_empty() or current_tree.get_player_stat(key):
		return
	var before := _clone_tree(current_tree)
	var stat: Resource = STAT_SCRIPT.new()
	stat.set("key", key)
	stat.set("title_key", _stat_title_key(key))
	stat.set("translations", _get_stat_translation_values())
	stat.set("value_type", stat_type_option.selected)
	stat.set("array_element_type", _selected_collection_value_type())
	var base_value: Variant = _stat_editor_base_value()
	if stat_type_option.selected == SkillTreeStatData.ValueType.ARRAY:
		base_value = _array_from_draft(_selected_collection_value_type())
	elif stat_type_option.selected == SkillTreeStatData.ValueType.DICTIONARY:
		base_value = _dictionary_from_draft(_selected_collection_value_type())
	stat.set("base_value", base_value)
	stat.set("collection_translations", _array_translations_from_draft() if stat_type_option.selected == SkillTreeStatData.ValueType.ARRAY else (_dictionary_translations_from_draft() if stat_type_option.selected == SkillTreeStatData.ValueType.DICTIONARY else {}))
	current_tree.player_stats.append(stat)
	_commit_snapshot(before, _clone_tree(current_tree), "Создать характеристику")
	stat_key_edit.clear()
	_refresh_stats_list()
	_redraw_graph()

func _delete_selected_player_stat() -> void:
	if not current_tree or not stats_list:
		return
	var selected := stats_list.get_selected_items()
	if selected.is_empty():
		return
	var index := int(selected[0])
	if index < 0 or index >= current_tree.player_stats.size():
		return
	var before := _clone_tree(current_tree)
	current_tree.player_stats.remove_at(index)
	_commit_snapshot(before, _clone_tree(current_tree), "Удалить характеристику")
	_refresh_stats_list()
	_redraw_graph()

func _operation_ui_index(operation: int, array_mode := false) -> int:
	match operation:
		SkillEffectData.Operation.ADD: return 0
		SkillEffectData.Operation.SUBTRACT: return 1
		SkillEffectData.Operation.MULTIPLY: return 2
		SkillEffectData.Operation.DIVIDE: return 3
		SkillEffectData.Operation.SET: return 4
		SkillEffectData.Operation.ADD_UNIQUE:
			return 5 if array_mode else 0
		SkillEffectData.Operation.ERASE: return 0
		_: return 0

func _operation_from_ui(index: int, array_mode := false) -> int:
	var operations: Array[int] = [SkillEffectData.Operation.ADD, SkillEffectData.Operation.SUBTRACT, SkillEffectData.Operation.MULTIPLY, SkillEffectData.Operation.DIVIDE, SkillEffectData.Operation.SET]
	if array_mode:
		operations.append(SkillEffectData.Operation.ADD_UNIQUE)
	return operations[clampi(index, 0, operations.size() - 1)]

func _update_effect_visibility(panel: Control, effect: SkillEffectData) -> void:
	var index := panel.get_node_or_null("Index")
	if index:
		var stat := current_tree.get_player_stat(effect.target_property) if current_tree else null
		var is_array_stat := stat and int(stat.get("value_type")) == SkillTreeStatData.ValueType.ARRAY
		index.visible = is_array_stat and effect.operation not in [SkillEffectData.Operation.ADD_UNIQUE, SkillEffectData.Operation.ERASE]
	var minimum := panel.get_node_or_null("Minimum")
	var maximum := panel.get_node_or_null("Maximum")
	if minimum:
		minimum.visible = effect.use_clamp
	if maximum:
		maximum.visible = effect.use_clamp
	var node := panel.get_parent().get_parent() as GraphNode
	if node:
		_fit_node(node)

func _on_clamp_toggled(value: bool, check: CheckButton, effect: SkillEffectData, skill_id: String, panel: Control) -> void:
	check.button_pressed = value
	_record_property(effect, "use_clamp", not value, value, skill_id)
	_update_effect_visibility(panel, effect)

func _add_effect(skill: SkillData) -> void:
	var stat_keys := current_tree.get_player_stat_keys() if current_tree else []
	if stat_keys.is_empty():
		# An effect cannot be configured without a target stat. Keep the graph visible
		# and report the actionable fix in the editor status line instead of opening
		# an empty, misleading statistics dialog.
		if status_label:
			_show_status("Сначала создайте характеристику: она определяет, что сможет менять эффект.")
		return
	var before := _clone_tree(current_tree)
	var effect := EFFECT_SCRIPT.new()
	effect.target_property = stat_keys[0]
	var stat := current_tree.get_player_stat(effect.target_property)
	if stat:
		var stat_type := int(stat.get("value_type"))
		var is_array_stat := stat_type == SkillTreeStatData.ValueType.ARRAY
		var is_dictionary_stat := stat_type == SkillTreeStatData.ValueType.DICTIONARY
		effect.array_mode = is_array_stat
		effect.target_kind = SkillEffectData.TargetKind.ARRAY_INDEX if is_array_stat else (SkillEffectData.TargetKind.DICTIONARY_KEY if is_dictionary_stat else SkillEffectData.TargetKind.PROPERTY)
		if is_array_stat or is_dictionary_stat:
			effect.value_type = int(stat.get("array_element_type"))
			if is_dictionary_stat:
				var values: Dictionary = stat.call("get_base_value")
				if not values.is_empty():
					effect.target_key = str(values.keys()[0])
		else:
			effect.value_type = stat_type
	if effect.value_type == SkillTreeStatData.ValueType.BOOL:
		effect.operation = SkillEffectData.Operation.SET
		effect.base_effect_value = false
		effect.default_value = false
	else:
		effect.base_effect_value = 1.0
		effect.default_value = 1.0
	skill.effects.append(effect)
	_commit_snapshot(before, _clone_tree(current_tree), "Создать эффект")
	_redraw_graph()

func _delete_effect(skill: SkillData, effect: SkillEffectData) -> void:
	var before := _clone_tree(current_tree)
	skill.effects.erase(effect)
	_commit_snapshot(before, _clone_tree(current_tree), "Удалить эффект")
	_redraw_graph()

func _on_operation_selected(index: int, effect: SkillEffectData, skill_id: String, panel: Control) -> void:
	var stat := current_tree.get_player_stat(effect.target_property) if current_tree else null
	var is_array_stat := stat and int(stat.get("value_type")) == SkillTreeStatData.ValueType.ARRAY
	var is_dictionary_stat := stat and int(stat.get("value_type")) == SkillTreeStatData.ValueType.DICTIONARY
	var value_type := int(stat.get("array_element_type")) if is_array_stat or is_dictionary_stat else int(stat.get("value_type"))
	var new_operation := SkillEffectData.Operation.SET if value_type == SkillTreeStatData.ValueType.BOOL else _operation_from_ui(index, is_dictionary_stat)
	_record_property(effect, "operation", effect.operation, new_operation, skill_id)
	var target_kind := SkillEffectData.TargetKind.PROPERTY if new_operation in [SkillEffectData.Operation.ADD_UNIQUE, SkillEffectData.Operation.ERASE] else (SkillEffectData.TargetKind.ARRAY_INDEX if is_array_stat else (SkillEffectData.TargetKind.DICTIONARY_KEY if is_dictionary_stat else SkillEffectData.TargetKind.PROPERTY))
	_record_property(effect, "target_kind", effect.target_kind, target_kind, skill_id)
	_redraw_graph()

func _parse_array_default(value: String, element_type: int) -> Array:
	var source := value.strip_edges()
	if source.begins_with("[") and source.ends_with("]"):
		source = source.trim_prefix("[").trim_suffix("]").strip_edges()
	var parsed := JSON.parse_string("[%s]" % source)
	if not parsed is Array:
		return []
	var result: Array = parsed.duplicate(true)
	for index in result.size():
		result[index] = _coerce_stat_value(result[index], element_type)
	return result

func _coerce_stat_value(value: Variant, value_type: int) -> Variant:
	if value_type == SkillTreeStatData.ValueType.BOOL:
		return bool(value)
	if value is bool:
		return (1 if value else 0) if value_type == SkillTreeStatData.ValueType.INT else (1.0 if value else 0.0)
	return int(value) if value_type == SkillTreeStatData.ValueType.INT else float(value)

func _coerce_effect_editor_value(value: Variant, value_type: int) -> Variant:
	if value_type == SkillTreeStatData.ValueType.BOOL:
		return bool(value)
	if value is bool:
		return (1 if value else 0) if value_type == SkillTreeStatData.ValueType.INT else (1.0 if value else 0.0)
	return int(value) if value_type == SkillTreeStatData.ValueType.INT else float(value)

func _selected_collection_value_type() -> int:
	return stat_array_element_type_option.get_selected_id()

func _stat_editor_base_value() -> Variant:
	if stat_type_option.selected == SkillTreeStatData.ValueType.BOOL:
		return stat_bool_value.button_pressed
	return roundi(stat_base_value.value) if stat_type_option.selected == SkillTreeStatData.ValueType.INT else stat_base_value.value

func _add_line(parent: Node, label_text: String, value: String, target: Resource, property_name: String, skill_id: String) -> LineEdit:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 74
	row.add_child(label)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if target:
		_bind_line(edit, target, property_name, skill_id)
	row.add_child(edit)
	parent.add_child(row)
	return edit

func _bind_line(edit: LineEdit, target: Resource, property_name: String, skill_id: String) -> void:
	_tighten_text_control(edit)
	edit.set_meta("skill_old_value", str(target.get(property_name)))
	edit.set_meta("skill_commit_target", target)
	edit.set_meta("skill_commit_property", property_name)
	edit.set_meta("skill_commit_skill_id", skill_id)
	edit.focus_exited.connect(_on_line_commit.bind(edit, target, property_name, skill_id))
	edit.text_submitted.connect(func(_text): _on_line_commit(edit, target, property_name, skill_id))

func _on_line_commit(edit: LineEdit, target: Resource, property_name: String, skill_id: String) -> void:
	var old_value: Variant = edit.get_meta("skill_old_value", str(target.get(property_name)))
	var new_value: Variant = edit.text
	if property_name == "skill_id":
		if new_value.strip_edges().is_empty() or (current_tree.get_skill(new_value) and current_tree.get_skill(new_value) != target):
			edit.text = str(old_value)
			return
		_rename_skill(str(old_value), new_value)
	else:
		_record_property(target, property_name, old_value, new_value, skill_id)
	edit.set_meta("skill_old_value", edit.text)

func _add_number(parent: Node, label_text: String, value: float, target: Resource, property_name: String, skill_id: String, minimum: float, maximum: float, integer: bool) -> SpinBox:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 74
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1.0 if integer else 0.01
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.value = value
	if not integer:
		# SpinBox otherwise renders an exact integer-looking float as `1`.
		spin.get_line_edit().call_deferred("set_text", "%.1f" % value)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.set_meta("skill_old_value", target.get(property_name))
	spin.value_changed.connect(_on_number_changed.bind(spin, target, property_name, skill_id, integer))
	row.add_child(spin)
	parent.add_child(row)
	return spin

func _add_bool(parent: Node, label_text: String, value: bool, target: Resource, property_name: String, skill_id: String) -> CheckButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 74
	row.add_child(label)
	var check := CheckButton.new()
	check.text = "True"
	check.button_pressed = value
	check.toggled.connect(_on_bool_changed.bind(check, target, property_name, skill_id))
	row.add_child(check)
	parent.add_child(row)
	return check

func _add_inline_number(parent: Node, value: float, target: Resource, property_name: String, skill_id: String, minimum: float, maximum: float, integer: bool) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1.0 if integer else 0.01
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.value = value
	spin.custom_minimum_size = Vector2(44, 24)
	spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	spin.add_theme_constant_override("buttons_width", 12)
	spin.add_theme_constant_override("field_and_buttons_separation", 0)
	spin.add_theme_constant_override("set_min_buttons_width_from_icons", 0)
	var line_edit := spin.get_line_edit()
	line_edit.expand_to_text_length = false
	line_edit.custom_minimum_size = Vector2(28, 24)
	line_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tighten_text_control(line_edit)
	spin.size = Vector2.ZERO
	spin.set_meta("skill_old_value", target.get(property_name))
	spin.value_changed.connect(_on_number_changed.bind(spin, target, property_name, skill_id, integer))
	parent.add_child(spin)
	return spin

func _add_costs_line(parent: Node, skill: SkillData) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Цены вручную"
	label.custom_minimum_size.x = 74
	row.add_child(label)
	var edit := LineEdit.new()
	edit.placeholder_text = "необязательно: 2, 3, 5"
	edit.text = _join_values(skill.costs_by_level)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tighten_text_control(edit)
	edit.set_meta("skill_old_value", skill.costs_by_level.duplicate(true))
	edit.set_meta("skill_commit_target", skill)
	edit.set_meta("skill_commit_property", "costs_by_level")
	edit.set_meta("skill_commit_skill_id", skill.skill_id)
	edit.set_meta("skill_commit_mode", "costs")
	edit.focus_exited.connect(_on_costs_commit.bind(edit, skill))
	row.add_child(edit)
	parent.add_child(row)

func _add_currency_option(parent: Node, skill: SkillData) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = _translated("Валюта")
	label.custom_minimum_size.x = 74
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if current_tree:
		current_tree.ensure_default_currency()
		for currency in current_tree.currencies:
			if not currency:
				continue
			var currency_key := str(currency.get("key"))
			option.add_item(_currency_display_name(currency), option.item_count)
			option.set_item_metadata(option.item_count - 1, currency_key)
			if currency_key == skill.currency_key:
				option.select(option.item_count - 1)
	option.item_selected.connect(_on_skill_currency_selected.bind(option, skill))
	row.add_child(option)
	parent.add_child(row)

func _on_skill_currency_selected(_index: int, option: OptionButton, skill: SkillData) -> void:
	var selected := option.get_selected()
	if selected < 0:
		return
	var new_key := str(option.get_item_metadata(selected))
	if new_key.is_empty() or new_key == skill.currency_key:
		return
	_record_property(skill, "currency_key", skill.currency_key, new_key, skill.skill_id)

func _currency_display_name(currency: Resource) -> String:
	if not currency:
		return ""
	var locale := "en" if language == "en" else "ru"
	var currency_key := str(currency.get("key"))
	return str((currency.get("translations") as Dictionary).get(locale, currency_key))

func _currency_cost_preview(skill: SkillData) -> String:
	if not current_tree:
		return str(skill.base_cost)
	var currency := current_tree.get_currency(skill.currency_key)
	var short_name := skill.currency_key
	if currency:
		var locale := "en" if language == "en" else "ru"
		short_name = str((currency.get("short_translations") as Dictionary).get(locale, skill.currency_key))
	return "%d %s" % [skill.base_cost, short_name]

func _on_costs_commit(edit: LineEdit, skill: SkillData) -> void:
	var parsed: Array[int] = []
	for part in edit.text.split(",", false):
		if part.strip_edges().is_valid_int():
			parsed.append(maxi(0, part.strip_edges().to_int()))
	var old_value: Array = edit.get_meta("skill_old_value", [])
	_record_property(skill, "costs_by_level", old_value, parsed, skill.skill_id)
	edit.set_meta("skill_old_value", parsed.duplicate(true))

func _on_number_changed(value: float, spin: SpinBox, target: Resource, property_name: String, skill_id: String, integer: bool) -> void:
	var old_value: Variant = spin.get_meta("skill_old_value", target.get(property_name))
	var new_value: Variant = int(value) if integer else value
	_record_property(target, property_name, old_value, new_value, skill_id)
	spin.set_meta("skill_old_value", new_value)

func _on_bool_changed(value: bool, check: CheckButton, target: Resource, property_name: String, skill_id: String) -> void:
	check.button_pressed = value
	_record_property(target, property_name, not value, value, skill_id)

func _on_resource_toggle(value: bool, check: CheckButton, target: Resource, property_name: String, skill_id: String) -> void:
	var old_value := not value
	_record_property(target, property_name, old_value, value, skill_id)

func _join_values(values: Array) -> String:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return ", ".join(result)

func _on_description_commit(edit: TextEdit, skill: SkillData) -> void:
	var old_value: String = edit.get_meta("skill_old_value", skill.description)
	_record_property(skill, "description", old_value, edit.text, skill.skill_id)
	edit.set_meta("skill_old_value", edit.text)

func _on_title_translation_commit(edit: LineEdit, skill: SkillData, locale_key: String) -> void:
	var translations := skill.title_translations.duplicate(true)
	var old_translations := translations.duplicate(true)
	translations[locale_key] = edit.text
	_record_property(skill, "title_translations", old_translations, translations, skill.skill_id)
	edit.set_meta("skill_old_value", edit.text)

func _record_property(target: Resource, property_name: String, old_value: Variant, new_value: Variant, _skill_id: String) -> void:
	if str(old_value) == str(new_value) and typeof(old_value) == typeof(new_value):
		target.set(property_name, new_value)
		return
	if undo_redo:
		undo_redo.create_action("Изменить %s" % property_name)
		undo_redo.add_do_method(self, "_set_resource_property", target, property_name, new_value)
		undo_redo.add_undo_method(self, "_set_resource_property", target, property_name, old_value)
		undo_redo.commit_action()
	else:
		target.set(property_name, new_value)
	dirty = true
	if target is SkillData and property_name == "title":
		var node: GraphNode = node_by_id.get(target.skill_id)
		if node: node.title = str(new_value)
	var edited_node: GraphNode = node_by_id.get(_skill_id)
	if edited_node:
		_fit_node(edited_node)

func _set_resource_property(target: Resource, property_name: String, value: Variant) -> void:
	target.set(property_name, value)
	if target is SkillEffectData and property_name == "base_effect_value":
		target.default_value = value
	if target is SkillData and property_name == "title":
		var node: GraphNode = node_by_id.get(target.skill_id)
		if node: node.title = str(value)
	dirty = true

func _rename_skill(old_id: String, new_id: String) -> void:
	var skill := current_tree.get_skill(old_id)
	if not skill:
		return
	var before := _clone_tree(current_tree)
	skill.skill_id = new_id
	for other in current_tree.skills:
		for requirement in other.requirements:
			if requirement and requirement.parent_skill_id == old_id:
				requirement.parent_skill_id = new_id
	selected_skill_id = new_id
	_commit_snapshot(before, _clone_tree(current_tree), "Переименовать навык")
	_redraw_graph()

func _on_graph_node_moved(node: GraphNode, skill_id: String) -> void:
	var skill := current_tree.get_skill(skill_id) if current_tree else null
	if skill:
		skill.editor_position = node.position_offset
		dirty = true

func _on_search_changed(_text: String) -> void:
	_update_search_visibility()

func _editor_skill_title(skill: SkillData) -> String:
	if not skill:
		return ""
	var locale_key := "en" if language == "en" else "ru"
	return str(skill.title_translations.get(locale_key, skill.get_title_fallback()))

func _update_search_visibility() -> void:
	if not graph:
		return
	var query := search_edit.text.to_lower() if search_edit else ""
	for skill_id in node_by_id:
		var skill := current_tree.get_skill(skill_id)
		var node: GraphNode = node_by_id[skill_id]
		node.modulate = Color.WHITE if query.is_empty() or _editor_skill_title(skill).to_lower().contains(query) or skill.skill_id.to_lower().contains(query) else Color(0.35, 0.35, 0.4)

func frame_all() -> void:
	if not graph or not current_tree or current_tree.skills.is_empty():
		return
	var min_position := current_tree.skills[0].editor_position
	var max_position := min_position
	for skill in current_tree.skills:
		if skill:
			min_position = min_position.min(skill.editor_position)
			max_position = max_position.max(skill.editor_position)
	graph.zoom = 0.75
	graph.scroll_offset = (min_position + max_position) * 0.5 - graph.size / (2.0 * graph.zoom)
	_update_zoom_label()

func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_F:
			search_edit.grab_focus()
			search_edit.select_all()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F and not event.ctrl_pressed:
			frame_all()
			get_viewport().set_input_as_handled()

func _commit_snapshot(before: SkillTreeData, after: SkillTreeData, action_name: String) -> void:
	dirty = true
	if not undo_redo:
		return
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(self, "_restore_snapshot", after)
	undo_redo.add_undo_method(self, "_restore_snapshot", before)
	undo_redo.commit_action()

func _restore_snapshot(snapshot: SkillTreeData) -> void:
	current_tree = _clone_tree(snapshot)
	_redraw_graph()
	_refresh_state_colors()

func _clone_tree(source: SkillTreeData) -> SkillTreeData:
	var result := TREE_SCRIPT.new()
	if not source:
		return result
	result.tree_id = source.tree_id
	result.categories = source.categories.duplicate(true)
	result.locales = source.locales.duplicate(true)
	result.state_colors = source.state_colors.duplicate(true)
	result.refund_percent = source.refund_percent
	for currency in source.currencies:
		if currency:
			var currency_copy: Resource = CURRENCY_SCRIPT.new()
			currency_copy.set("key", currency.get("key"))
			currency_copy.set("translations", currency.get("translations").duplicate(true))
			currency_copy.set("short_translations", currency.get("short_translations").duplicate(true))
			currency_copy.set("icon", currency.get("icon"))
			currency_copy.set("initial_amount", currency.get("initial_amount"))
			result.currencies.append(currency_copy)
	for stat in source.player_stats:
		if stat:
			var stat_copy: Resource = STAT_SCRIPT.new()
			stat_copy.set("key", stat.get("key"))
			stat_copy.set("title_key", stat.get("title_key"))
			stat_copy.set("translations", stat.get("translations").duplicate(true))
			stat_copy.set("collection_translations", stat.get("collection_translations").duplicate(true))
			stat_copy.set("title_ru", stat.get("title_ru"))
			stat_copy.set("title_en", stat.get("title_en"))
			stat_copy.set("value_type", stat.get("value_type"))
			stat_copy.set("array_element_type", stat.get("array_element_type"))
			stat_copy.set("base_value", stat.call("get_base_value"))
			result.player_stats.append(stat_copy)
	for skill in source.skills:
		if skill:
			result.skills.append(_clone_skill(skill))
	return result

func _clone_skill(source: SkillData) -> SkillData:
	var result := SKILL_SCRIPT.new()
	result.skill_id = source.skill_id
	result.title = source.title
	result.title_translations = source.title_translations.duplicate(true)
	result.description = source.description
	result.category = source.category
	result.icon = source.icon
	result.editor_position = source.editor_position
	result.starts_unlocked = source.starts_unlocked
	result.max_level = source.max_level
	result.base_cost = source.base_cost
	result.currency_key = source.currency_key
	result.cost_growth_rate = source.cost_growth_rate
	result.costs_by_level = source.costs_by_level.duplicate(true)
	result.legacy_paths = source.legacy_paths.duplicate(true)
	for requirement in source.requirements:
		if requirement:
			var req := REQUIREMENT_SCRIPT.new()
			req.parent_skill_id = requirement.parent_skill_id
			req.required_level = requirement.required_level
			result.requirements.append(req)
	for effect in source.effects:
		if effect:
			result.effects.append(_clone_effect(effect))
	return result

func _clone_effect(source: SkillEffectData) -> SkillEffectData:
	var result := EFFECT_SCRIPT.new()
	result.target_property = source.target_property
	result.target_kind = source.target_kind
	result.target_index = source.target_index
	result.target_key = source.target_key
	result.unique_key_translations = source.unique_key_translations.duplicate(true)
	result.array_mode = source.array_mode
	result.operation = source.operation
	result.value_type = source.value_type
	result.base_effect_value = source.get_base_value()
	result.effect_value_growth_rate = source.effect_value_growth_rate
	result.use_clamp = source.use_clamp
	result.toggle_mode = source.toggle_mode
	result.values_by_level = source.values_by_level.duplicate(true)
	result.default_value = source.default_value
	result.minimum = source.minimum
	result.maximum = source.maximum
	return result

func _tree_fingerprint(tree: SkillTreeData) -> Dictionary:
	var result: Dictionary = {
		"tree_id": tree.tree_id,
		"categories": tree.categories.duplicate(true),
		"locales": tree.locales.duplicate(true),
		"state_colors": tree.state_colors.duplicate(true),
		"refund_percent": tree.refund_percent,
		"currencies": [],
		"player_stats": [],
		"skills": []
	}
	for currency in tree.currencies:
		if currency:
			result["currencies"].append({
				"key": currency.get("key"),
				"translations": currency.get("translations").duplicate(true),
				"short_translations": currency.get("short_translations").duplicate(true),
				"icon": (currency.get("icon") as Texture2D).resource_path if currency.get("icon") else "",
				"initial_amount": currency.get("initial_amount")
			})
	for stat in tree.player_stats:
		if stat:
			result["player_stats"].append({
				"key": stat.get("key"),
				"title_key": stat.get("title_key"),
				"translations": stat.get("translations").duplicate(true),
				"collection_translations": stat.get("collection_translations").duplicate(true),
				"title_ru": stat.get("title_ru"),
				"title_en": stat.get("title_en"),
				"value_type": stat.get("value_type"),
				"array_element_type": stat.get("array_element_type"),
				"base_value": _fingerprint_effect_value(stat.call("get_base_value"), int(stat.get("value_type")))
			})
	for skill in tree.skills:
		if not skill:
			continue
		var skill_data: Dictionary = {
			"skill_id": skill.skill_id,
			"title": skill.title,
			"title_translations": skill.title_translations.duplicate(true),
			"description": skill.description,
			"category": skill.category,
			"icon": skill.icon.resource_path if skill.icon else "",
			"editor_position": skill.editor_position,
			"starts_unlocked": skill.starts_unlocked,
			"max_level": skill.max_level,
			"base_cost": skill.base_cost,
			"currency_key": skill.currency_key,
			"cost_growth_rate": skill.cost_growth_rate,
			"costs_by_level": skill.costs_by_level.duplicate(true),
			"legacy_paths": skill.legacy_paths.duplicate(true),
			"requirements": [],
			"effects": []
		}
		for requirement in skill.requirements:
			if requirement:
				skill_data["requirements"].append({
					"parent_skill_id": requirement.parent_skill_id,
					"required_level": requirement.required_level
				})
		for effect in skill.effects:
			if effect:
				skill_data["effects"].append({
					"target_property": effect.target_property,
					"target_kind": effect.target_kind,
					"target_index": effect.target_index,
					"target_key": effect.target_key,
					"unique_key_translations": effect.unique_key_translations.duplicate(true),
					"array_mode": effect.array_mode,
					"operation": effect.operation,
					"value_type": effect.value_type,
					"base_effect_value": _fingerprint_effect_value(effect.get_base_value(), effect.value_type),
					"effect_value_growth_rate": effect.effect_value_growth_rate,
					"use_clamp": effect.use_clamp,
					"toggle_mode": effect.toggle_mode,
					"values_by_level": effect.values_by_level.duplicate(true),
					"default_value": _fingerprint_effect_value(effect.default_value, effect.value_type),
					"minimum": effect.minimum,
					"maximum": effect.maximum
				})
		result["skills"].append(skill_data)
	return result

func _fingerprint_effect_value(value: Variant, value_type: int) -> Variant:
	if value is Array:
		return value.duplicate(true)
	if value is Dictionary:
		return value.duplicate(true)
	if value == null:
		return null
	return int(value) if value_type == SkillEffectData.ValueType.INT else float(value)
