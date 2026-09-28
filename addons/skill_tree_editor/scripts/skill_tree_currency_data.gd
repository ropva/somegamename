@tool
class_name SkillTreeCurrencyData
extends Resource

## Lowercase stable identifier used by balances and skills.
@export var key: String = ""
## Full localized name mapped by locale key.
@export var translations: Dictionary = {}
## Localized abbreviation mapped by locale key.
@export var short_translations: Dictionary = {}
## Optional icon rendered next to a price.
@export var icon: Texture2D
## Balance assigned when a save state is first created.
@export_range(0, 999999999, 1) var initial_amount: int = 0

func get_translation_key() -> String:
	return "CURRENCY_%s" % key.to_upper()

func get_short_translation_key() -> String:
	return "%s_SHORT" % get_translation_key()

func get_display_name(locale_key: String) -> String:
	return str(translations.get(locale_key, key))

func get_short_name(locale_key: String) -> String:
	return str(short_translations.get(locale_key, get_display_name(locale_key)))

static func normalize_key(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	var result := ""
	for character in normalized:
		if character.unicode_at(0) >= 97 and character.unicode_at(0) <= 122 or character.is_valid_int() or character == "_":
			result += character
	return result

static func is_valid_key(value: String) -> bool:
	if value.is_empty() or not (value[0] == "_" or value[0].to_lower() != value[0].to_upper()):
		return false
	return normalize_key(value) == value
