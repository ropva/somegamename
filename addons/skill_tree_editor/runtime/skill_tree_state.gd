class_name SkillTreeState
extends RefCounted

const VERSION := 3

var tree_id := "main"
var currencies: Dictionary = {}
var levels: Dictionary = {}
var values: Dictionary = {}
var spent_currencies: Dictionary = {}
var legacy_state_requires_reset := false

func to_dictionary() -> Dictionary:
	return {
		"version": VERSION,
		"tree_id": tree_id,
		"currencies": currencies.duplicate(true),
		"levels": levels.duplicate(true),
		"values": values.duplicate(true),
		"spent_currencies": spent_currencies.duplicate(true),
	}

static func from_dictionary(data: Dictionary, fallback_tree_id := "main") -> SkillTreeState:
	var result := SkillTreeState.new()
	result.tree_id = str(data.get("tree_id", fallback_tree_id))
	if int(data.get("version", 1)) < 3:
		# Price history did not exist in v2. The owner resets that legacy state
		# before configuring it, so no historical refund can be invented.
		result.legacy_state_requires_reset = true
		return result
	var saved_currencies: Variant = data.get("currencies", {})
	if saved_currencies is Dictionary:
		for currency_key in saved_currencies:
			result.currencies[str(currency_key)] = maxi(0, int(saved_currencies[currency_key]))
	# Version 1 stored a single skill_points balance. Keep this only as a one-time
	# read migration; every subsequent save uses the version 2 currencies map.
	elif data.has("skill_points"):
		result.currencies["skillpoints"] = maxi(0, int(data.get("skill_points", 0)))
	var saved_levels: Variant = data.get("levels", {})
	if saved_levels is Dictionary:
		for key in saved_levels:
			result.levels[str(key)] = maxi(0, int(saved_levels[key]))
	var saved_values: Variant = data.get("values", {})
	if saved_values is Dictionary:
		result.values = saved_values.duplicate(true)
	var spent: Variant = data.get("spent_currencies", {})
	if spent is Dictionary:
		for currency_key in spent:
			result.spent_currencies[str(currency_key)] = maxi(0, int(spent[currency_key]))
	return result
