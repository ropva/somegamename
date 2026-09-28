@tool
extends EditorPlugin

var editor: Control

const SKILL_TREE_AUTOLOAD_PATH := "res://addons/skill_tree_editor/runtime/skill_tree_service.gd"
const LEGACY_AUTOLOADS := {
	"SkillTreeStorage": "res://addons/skill_tree_editor/runtime/skill_tree_storage.gd",
	"SkillProgression": "res://addons/skill_tree_editor/runtime/skill_progression_service.gd",
}

const ADDON_TRANSLATIONS := [
	"res://addons/skill_tree_editor/translations/skill_tree_translations.ru.translation",
	"res://addons/skill_tree_editor/translations/skill_tree_translations.en.translation",
]

func _enter_tree() -> void:
	_ensure_addon_translations()
	_ensure_debug_reset_action()
	_remove_legacy_addon_autoloads()
	_ensure_skill_tree_autoload()
	editor = preload("res://addons/skill_tree_editor/skill_tree_editor.gd").new()
	editor.plugin = self
	get_editor_interface().get_editor_main_screen().add_child(editor)
	editor.hide()

func _ensure_debug_reset_action() -> void:
	var setting := "input/reset_skilltree_data"
	if ProjectSettings.has_setting(setting):
		# The plugin may have already created this action in an earlier editor session.
		# Treat the expected binding as owned by the addon; warn only on a real conflict.
		if _has_default_debug_reset_binding():
			return
		push_warning("Skill Tree: existing reset_skilltree_data action was preserved; the addon did not overwrite project input bindings.")
		return
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.ctrl_pressed = true
	ProjectSettings.set_setting(setting, {"deadzone": 0.0, "events": [key]})
	ProjectSettings.save()

func _has_default_debug_reset_binding() -> bool:
	var configured: Variant = ProjectSettings.get_setting("input/reset_skilltree_data", {})
	var events: Array = configured.get("events", []) if configured is Dictionary else []
	if events.is_empty() and InputMap.has_action("reset_skilltree_data"):
		events = InputMap.action_get_events("reset_skilltree_data")
	for event in events:
		if event is InputEventKey and event.ctrl_pressed and event.physical_keycode == KEY_R:
			return true
	return false

func _remove_legacy_addon_autoloads() -> void:
	# Never touch an identically named autoload owned by the host project.
	for autoload_name in LEGACY_AUTOLOADS:
		var setting := "autoload/%s" % autoload_name
		if ProjectSettings.has_setting(setting) and str(ProjectSettings.get_setting(setting)).trim_prefix("*") == LEGACY_AUTOLOADS[autoload_name]:
			remove_autoload_singleton(autoload_name)

func _ensure_skill_tree_autoload() -> void:
	var setting := "autoload/SkillTree"
	if not ProjectSettings.has_setting(setting):
		# Persist the autoload explicitly. EditorPlugin's helper updates a running
		# editor reliably, but a clean headless first scan may exit before it writes.
		add_autoload_singleton("SkillTree", SKILL_TREE_AUTOLOAD_PATH)
		ProjectSettings.set_setting(setting, "*%s" % SKILL_TREE_AUTOLOAD_PATH)
		ProjectSettings.save()
		return
	var configured_path := str(ProjectSettings.get_setting(setting)).trim_prefix("*")
	if configured_path != SKILL_TREE_AUTOLOAD_PATH:
		push_error("Skill Tree addon needs autoload 'SkillTree' at %s, but the project uses %s. Rename or remove the conflicting autoload." % [SKILL_TREE_AUTOLOAD_PATH, configured_path])

func _ensure_addon_translations() -> void:
	var translations := PackedStringArray(ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()))
	var changed := false
	for translation_path in ADDON_TRANSLATIONS:
		if translation_path in translations:
			continue
		translations.append(translation_path)
		changed = true
	if changed:
		ProjectSettings.set_setting("internationalization/locale/translations", translations)
		ProjectSettings.save()

func _exit_tree() -> void:
	if editor:
		# EditorPlugin is unloaded while the editor is shutting down; free the
		# main-screen control immediately so its GraphEdit controls do not leak.
		if editor.get_parent():
			editor.get_parent().remove_child(editor)
		editor.free()
		editor = null

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if editor:
		editor.visible = visible

func _get_plugin_name() -> String:
	return "Skill Tree"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Tree", "EditorIcons")
