@tool
class_name SkillTreeStatData
extends Resource

## BOOL is appended to keep values saved by earlier .tres resources stable.
enum ValueType { INT, FLOAT, ARRAY, DICTIONARY, BOOL }

## Stable value key used by effects and public SkillTree API.
@export var key: String = ""
## Translation key for the stat title.
@export var title_key: String = ""
## Maps locale keys (for example, "ru" or "en") to the translated stat title.
@export var translations: Dictionary = {}
## Per-element translations: array index or dictionary key -> locale -> text.
@export var collection_translations: Dictionary = {}
## Legacy fields are retained only so trees created before locale support still load.
## Legacy Russian stat title.
@export var title_ru: String = ""
## Legacy English stat title.
@export var title_en: String = ""
## Stored value type for this stat.
@export var value_type: ValueType = ValueType.FLOAT
## Type enforced for values in arrays and dictionaries.
@export var array_element_type: ValueType = ValueType.FLOAT
## Value assigned when a new progression state is created.
@export var base_value: Variant = 0.0

func get_base_value() -> Variant:
	if value_type == ValueType.ARRAY:
		var result: Array = base_value.duplicate(true) if base_value is Array else []
		for index in result.size():
			result[index] = _coerce_value(result[index], array_element_type)
		return result
	if value_type == ValueType.DICTIONARY:
		var result: Dictionary = base_value.duplicate(true) if base_value is Dictionary else {}
		for entry_key in result:
			result[entry_key] = _coerce_value(result[entry_key], array_element_type)
		return result
	return _coerce_value(base_value, value_type)

func _coerce_value(value: Variant, type: ValueType) -> Variant:
	if type == ValueType.BOOL:
		return bool(value)
	if value is bool:
		return (1 if value else 0) if type == ValueType.INT else (1.0 if value else 0.0)
	return int(value) if type == ValueType.INT else float(value)
