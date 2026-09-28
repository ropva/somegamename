@tool
class_name SkillData
extends Resource

## Identity fields used to identify and display the skill.
@export_group("Identity")
## Stable identifier used by requirements and save state.
@export var skill_id: String = ""
## Localized display names keyed by the locale keys configured on the tree.
@export var title_translations: Dictionary = {}
## Legacy title value kept in serialized resources for backward compatibility.
@export_storage var title: String = ""
## Optional player-facing description.
@export_multiline var description: String = ""
## Category label or translation key.
@export var category: String = "SKILL_CATEGORY_MAIN"
## Optional icon displayed by runtime skill UI.
@export var icon: Texture2D

## Graph layout and visibility fields.
@export_group("Graph")
## Top-left position in editor and runtime graph coordinates.
@export var editor_position: Vector2 = Vector2.ZERO
## Makes the skill visible without a fulfilled requirement.
@export var starts_unlocked: bool = false
## Skills and levels required before this skill can be purchased.
@export var requirements: Array[SkillRequirementData] = []

## Purchase cost and level progression fields.
@export_group("Progression")
## Currency key charged when this skill is purchased.
@export var currency_key: String = "skillpoints"
## Maximum purchasable level.
@export_range(1, 999, 1) var max_level: int = 1
## Price of the first level when manual prices are not set.
@export var base_cost: int = 1
## Additional cost applied per next level.
@export var cost_growth_rate: float = 0.5
## Optional exact costs, indexed by level minus one.
@export var costs_by_level: Array[int] = []
## Effects applied for each purchased level.
@export var effects: Array[SkillEffectData] = []

## Compatibility fields for migrating older tree data.
@export_group("Migration")
## Legacy identifiers retained to migrate old saved trees.
@export var legacy_paths: Array[String] = []

func get_title_key() -> String:
	var normalized := skill_id.strip_edges().to_upper()
	var key := ""
	for character in normalized:
		if character == "_" or character.to_upper() != character.to_lower() or character.is_valid_int():
			key += character
		else:
			key += "_"
	return "SKILL_%s_TITLE" % key

func get_title_fallback() -> String:
	if not title.strip_edges().is_empty() and title != "SKILL_NEW_TITLE":
		return title
	return "SKILL_NEW_TITLE"

func ensure_title_translations(locales: Array[Dictionary]) -> void:
	var updated := title_translations.duplicate(true)
	for locale_data in locales:
		var locale_key := str(locale_data.get("key", "")).strip_edges()
		if locale_key.is_empty() or updated.has(locale_key):
			continue
		updated[locale_key] = get_title_fallback()
	title_translations = updated

func get_cost(level: int) -> int:
	if level < 1 or base_cost <= 0: return 0
	if level <= costs_by_level.size():
		return costs_by_level[level - 1]
	return maxi(0, roundi(float(base_cost) * pow(float(maxi(level, 1)), cost_growth_rate)))
