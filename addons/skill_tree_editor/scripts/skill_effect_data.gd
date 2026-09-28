@tool
class_name SkillEffectData
extends Resource

## PROPERTY/ARRAY_INDEX names are retained as aliases for old resources.
enum TargetKind { VALUE, ARRAY, DICTIONARY_KEY, PROPERTY = 0, ARRAY_INDEX = 1 }
## The first four values remain stable so existing .tres files keep loading.
enum Operation { ADD, SET, ADD_UNIQUE, ERASE, SUBTRACT, MULTIPLY, DIVIDE, ARRAY_APPEND_UNIQUE = 2, ARRAY_ERASE = 3 }
## BOOL is appended to preserve numeric values in existing resources.
enum ValueType { INT, FLOAT, BOOL = 4 }

## Key of the tree stat changed by this effect.
@export var target_property: String = ""
## Location of the value within the target stat.
@export var target_kind: TargetKind = TargetKind.PROPERTY
## Array element index when the target kind is ARRAY_INDEX.
@export var target_index: int = 0
## Dictionary key when the target kind is DICTIONARY_KEY or ADD_UNIQUE.
@export var target_key: String = ""
## Translations for a key created by ADD_UNIQUE: locale -> text.
@export var unique_key_translations: Dictionary = {}
## Legacy array marker retained for backwards-compatible resources.
@export var array_mode: bool = false
## Operation applied to the current target value.
@export var operation: Operation = Operation.ADD
## Required numeric or boolean value type.
@export var value_type: ValueType = ValueType.FLOAT
## Effect amount at the first purchased level.
@export var base_effect_value: Variant = 1.0
## Exponent used to scale the effect amount per level.
@export var effect_value_growth_rate: float = 0.0
## Enables minimum and maximum clamping for numeric results.
@export var use_clamp: bool = false
## Once the skill is purchased, clicking its card again flips this Bool value.
@export var toggle_mode: bool = false

## Kept for saves made by the first data-driven implementation.
## Legacy explicit per-level values, preferred when present.
@export var values_by_level: Array[Variant] = []
## Legacy fallback effect amount.
@export var default_value: Variant = 1.0
## Lower clamp limit when clamping is enabled.
@export var minimum: float = -1000000000.0
## Upper clamp limit when clamping is enabled.
@export var maximum: float = 1000000000.0

func get_value_for_level(level: int) -> Variant:
	if level > 0 and level <= values_by_level.size():
		return values_by_level[level - 1]
	var base: Variant = base_effect_value
	if not base_effect_value is bool and not default_value is bool and base_effect_value == 1.0 and default_value != 1.0:
		base = default_value
	if operation in [Operation.ADD_UNIQUE, Operation.ERASE]:
		return base
	if value_type == ValueType.BOOL:
		return bool(base)
	var scaled: float = float(base) * pow(float(maxi(1, level)), effect_value_growth_rate)
	# Keep the explicit branch: a ternary between int and float produces an
	# incompatible-type warning in Godot 4.8 even though this method returns Variant.
	if value_type == ValueType.INT:
		return roundi(scaled)
	return scaled

func get_base_value() -> Variant:
	# Bool cannot be compared to Float in Godot 4.8.
	if not base_effect_value is bool and not default_value is bool and base_effect_value == 1.0 and default_value != 1.0:
		return default_value
	return base_effect_value
