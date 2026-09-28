@tool
class_name SkillTreeData
extends Resource

const STAT_SCRIPT := preload("res://addons/skill_tree_editor/scripts/skill_tree_stat_data.gd")
const CURRENCY_SCRIPT := preload("res://addons/skill_tree_editor/scripts/skill_tree_currency_data.gd")

## Stable tree identifier used in local save file names.
@export var tree_id: String = "main"
## Categories available to skills in this tree.
@export var categories: Array[String] = ["SKILL_CATEGORY_MAIN"]
## Supported editor and runtime locales.
@export var locales: Array[Dictionary] = [{"key": "ru", "name": "Русский"}, {"key": "en", "name": "English"}]
## Colors used to represent runtime skill states.
@export var state_colors: Dictionary = {
	"enough_currency": Color("69e58c"),
	"not_enough_currency": Color("e56a6a"),
	"available": Color("69e58c"),
	"unavailable": Color("e56a6a"),
	"max_level": Color("f3c969"),
	"next_value": Color("69e58c")
}
## Currencies that can pay for this tree's skills.
@export var currencies: Array[Resource] = []
## Values that skills may modify in progression state.
@export var player_stats: Array[Resource] = []
## Static skills and their graph layout.
@export var skills: Array[SkillData] = []
## Percentage of recorded skill costs returned by the gameplay reset.
@export_range(0.0, 100.0, 1.0) var refund_percent: float = 50.0

func get_skill(skill_id: String) -> SkillData:
	for skill in skills:
		if skill != null and skill.skill_id == skill_id:
			return skill
	return null

func get_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for skill in skills:
		if skill != null:
			ids.append(skill.skill_id)
	return ids

func get_player_stat(key: String) -> Resource:
	for stat in player_stats:
		if stat and str(stat.get("key")) == key:
			return stat
	return null

func ensure_default_currency() -> void:
	if not currencies.is_empty():
		return
	var currency: Resource = CURRENCY_SCRIPT.new()
	currency.set("key", "skillpoints")
	currency.set("translations", {"ru": "Очки навыков", "en": "Skill Points"})
	currency.set("short_translations", {"ru": "СП", "en": "SP"})
	currencies.append(currency)

func get_currency(currency_key: String) -> Resource:
	for currency in currencies:
		if currency and str(currency.get("key")) == currency_key:
			return currency
	return null

func get_base_currency() -> Resource:
	ensure_default_currency()
	return currencies[0] if not currencies.is_empty() else null

func get_player_stat_keys() -> Array[String]:
	var keys: Array[String] = []
	for stat in player_stats:
		var key := str(stat.get("key")) if stat else ""
		if not key.is_empty():
			keys.append(key)
	return keys

func get_player_data_defaults() -> Dictionary:
	var defaults := {}
	for stat in player_stats:
		var key := str(stat.get("key")) if stat else ""
		if not key.is_empty():
			defaults[key] = stat.call("get_base_value")
	return defaults

func get_locales() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for locale_data in locales:
		var locale_key := str(locale_data.get("key", "")).strip_edges()
		if locale_key.is_empty():
			continue
		result.append({"key": locale_key, "name": str(locale_data.get("name", locale_key)).strip_edges()})
	if result.is_empty():
		result.append({"key": "en", "name": "English"})
	return result

func get_state_color(color_key: String) -> Color:
	var defaults := {
		"enough_currency": Color("69e58c"),
		"not_enough_currency": Color("e56a6a"),
		"available": Color("69e58c"),
		"unavailable": Color("e56a6a"),
		"max_level": Color("f3c969"),
		"next_value": Color("69e58c")
	}
	var value: Variant = state_colors.get(color_key, defaults.get(color_key, Color.WHITE))
	return value if value is Color else defaults.get(color_key, Color.WHITE)
