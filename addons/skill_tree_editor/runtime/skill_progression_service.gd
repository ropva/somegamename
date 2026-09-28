class_name SkillProgressionService
extends Node

const STATE_SCRIPT := preload("res://addons/skill_tree_editor/runtime/skill_tree_state.gd")

signal skill_purchased(skill_id: String, new_level: int)
signal skill_toggled(skill_id: String)
signal skill_state_changed(skill_id: String)
signal skill_purchase_failed(skill_id: String, reason: String)
signal currency_changed(currency_key: String, amount: int)

const STATE_HIDDEN := "hidden"
const STATE_LOCKED := "locked"
const STATE_NOT_ENOUGH_CURRENCY := "not_enough_currency"
const STATE_AVAILABLE := "available"
const STATE_MAX_LEVEL := "max_level"

var tree_data: SkillTreeData
var state: SkillTreeState
var slot := "default"
var created_state := false
var _storage_service: SkillTreeStorageService

## Injected by SkillTreeService; this class must not depend on an autoload.
func set_storage(storage: SkillTreeStorageService) -> void:
	_storage_service = storage

func configure(data: SkillTreeData, save_slot := "default") -> void:
	if not data or not _storage_service:
		return
	tree_data = data
	slot = save_slot
	var had_state := _storage().has_state(data.tree_id, slot)
	created_state = not had_state
	state = _storage().get_state(data.tree_id, slot)
	if had_state and state.legacy_state_requires_reset:
		# v2 state was intentionally invalidated by SkillTreeState migration.
		state = SkillTreeState.new()
		state.tree_id = data.tree_id
	state.tree_id = data.tree_id
	tree_data.ensure_default_currency()
	var defaults_changed := _apply_player_data_defaults() or _apply_currency_defaults()
	if not had_state or defaults_changed:
		_storage().save_state(state, slot)

func _apply_player_data_defaults() -> bool:
	if not state or not tree_data:
		return false
	var changed := false
	var defaults := tree_data.get_player_data_defaults()
	for key in defaults:
		if not state.values.has(key):
			state.values[key] = defaults[key]
			changed = true
	return changed

func get_level(skill_id: String) -> int:
	return int(state.levels.get(skill_id, 0)) if state else 0

func get_currency(currency_key: String) -> int:
	return int(state.currencies.get(currency_key, 0)) if state else 0

func set_currency(currency_key: String, amount: int) -> bool:
	if not state or not tree_data or not tree_data.get_currency(currency_key):
		return false
	state.currencies[currency_key] = maxi(0, amount)
	var saved := _storage().save_state(state, slot)
	if saved:
		currency_changed.emit(currency_key, int(state.currencies[currency_key]))
	return saved

func add_currency(currency_key: String, amount: int) -> bool:
	return set_currency(currency_key, get_currency(currency_key) + amount)

func can_afford(currency_key: String, amount: int) -> bool:
	return amount <= 0 or get_currency(currency_key) >= amount

func spend_currency(currency_key: String, amount: int) -> bool:
	if amount < 0 or not can_afford(currency_key, amount):
		return false
	return set_currency(currency_key, get_currency(currency_key) - amount)

func get_value(key: String, fallback: Variant = null) -> Variant:
	return state.values.get(key, fallback) if state else fallback

func set_value(key: String, value: Variant) -> bool:
	if not state or not tree_data or not tree_data.get_player_stat(key): return false
	state.values[key] = value
	return _storage().save_state(state, slot)

func get_skill_state(skill_id: String) -> String:
	var skill := _get_skill(skill_id)
	if not skill or not state:
		return STATE_HIDDEN
	var level := get_level(skill_id)
	if level >= skill.max_level:
		return STATE_MAX_LEVEL
	if not is_visible(skill_id):
		return STATE_HIDDEN
	if not prerequisites_met(skill_id):
		return STATE_LOCKED
	if not can_afford(skill.currency_key, skill.get_cost(level + 1)):
		return STATE_NOT_ENOUGH_CURRENCY
	return STATE_AVAILABLE

func is_visible(skill_id: String) -> bool:
	var skill := _get_skill(skill_id)
	if not skill:
		return false
	if skill.starts_unlocked or skill.requirements.is_empty():
		return true
	for requirement in skill.requirements:
		if requirement and get_level(requirement.parent_skill_id) >= requirement.required_level:
			return true
	return false

func prerequisites_met(skill_id: String) -> bool:
	var skill := _get_skill(skill_id)
	if not skill:
		return false
	for requirement in skill.requirements:
		if not requirement or get_level(requirement.parent_skill_id) < requirement.required_level:
			return false
	return true

func purchase_skill(skill_id: String) -> bool:
	var skill := _get_skill(skill_id)
	var reason := ""
	if not skill: reason = "UNKNOWN_SKILL"
	elif get_skill_state(skill_id) == STATE_HIDDEN: reason = "HIDDEN"
	elif not prerequisites_met(skill_id): reason = "PREREQUISITES"
	var current_level := get_level(skill_id)
	var cost := skill.get_cost(current_level + 1) if skill else 0
	var currency_key := skill.currency_key if skill else ""
	var before_currency := get_currency(currency_key)
	if reason.is_empty() and not can_afford(currency_key, cost): reason = "NOT_ENOUGH_CURRENCY"
	var before_values: Dictionary = state.values.duplicate(true) if state else {}
	if reason.is_empty():
		for effect in skill.effects:
			if not _apply_effect(effect, current_level + 1):
				reason = "INVALID_EFFECT"
				break
	if not reason.is_empty():
		state.values = before_values
		skill_purchase_failed.emit(skill_id, reason)
		return false
	state.levels[skill_id] = current_level + 1
	state.currencies[currency_key] = before_currency - cost
	state.spent_currencies[currency_key] = int(state.spent_currencies.get(currency_key, 0)) + cost
	if not _storage().save_state(state, slot):
		state.values = before_values
		if current_level > 0: state.levels[skill_id] = current_level
		else: state.levels.erase(skill_id)
		state.currencies[currency_key] = before_currency
		state.spent_currencies[currency_key] = maxi(0, int(state.spent_currencies.get(currency_key, 0)) - cost)
		skill_purchase_failed.emit(skill_id, "SAVE_FAILED")
		return false
	skill_purchased.emit(skill_id, current_level + 1)
	currency_changed.emit(currency_key, int(state.currencies[currency_key]))
	for changed_id in tree_data.get_skill_ids():
		skill_state_changed.emit(changed_id)
	return true

func reset_progression_with_refund() -> Dictionary:
	if not state or not tree_data:
		return {}
	var refund: Dictionary = {}
	for currency_key in state.spent_currencies:
		var amount := int(state.spent_currencies[currency_key])
		refund[currency_key] = floori(float(amount) * tree_data.refund_percent / 100.0)
	var before := state.to_dictionary()
	var reset := SkillTreeState.new()
	reset.tree_id = tree_data.tree_id
	reset.currencies = state.currencies.duplicate(true)
	for currency_key in refund:
		reset.currencies[currency_key] = int(reset.currencies.get(currency_key, 0)) + int(refund[currency_key])
	_apply_defaults_to_state(reset)
	if not _storage().save_state(reset, slot):
		return {}
	state = reset
	for currency_key in reset.currencies:
		currency_changed.emit(str(currency_key), int(reset.currencies[currency_key]))
	for skill_id in tree_data.get_skill_ids():
		skill_state_changed.emit(skill_id)
	return {"refund": refund, "before": before}

func get_progression_reset_preview() -> Dictionary:
	var lines: Array[String] = []
	var entries: Array[Dictionary] = []
	if not state or not tree_data:
		return {"text": ""}
	for currency_key in state.spent_currencies:
		var spent := int(state.spent_currencies[currency_key])
		if spent <= 0:
			continue
		var refund := floori(float(spent) * tree_data.refund_percent / 100.0)
		var currency := tree_data.get_currency(str(currency_key))
		var short := str(currency_key)
		if currency:
			short = str((currency.get("short_translations") as Dictionary).get(TranslationServer.get_locale().get_slice("_", 0).to_lower(), currency_key))
		lines.append("[color=#e56a6a][s]%d %s[/s][/color] → %d %s" % [spent, short, refund, short])
		entries.append({"spent": spent, "refund": refund, "currency": short})
	return {"text": "\n".join(lines), "entries": entries}

func reset_debug() -> bool:
	if not tree_data:
		return false
	var reset := SkillTreeState.new()
	reset.tree_id = tree_data.tree_id
	_apply_defaults_to_state(reset)
	if not _storage().save_state(reset, slot):
		return false
	# Keep the active tree and its UI in sync with the just-written debug state.
	state = reset
	for currency_key in reset.currencies:
		currency_changed.emit(str(currency_key), int(reset.currencies[currency_key]))
	for skill_id in tree_data.get_skill_ids():
		skill_state_changed.emit(skill_id)
	return true

func _apply_defaults_to_state(target: SkillTreeState) -> void:
	for stat in tree_data.player_stats:
		if stat:
			target.values[str(stat.get("key"))] = stat.call("get_base_value")
	for currency in tree_data.currencies:
		if currency:
			target.currencies[str(currency.get("key"))] = maxi(0, int(currency.get("initial_amount"))) if not target.currencies.has(str(currency.get("key"))) else target.currencies[str(currency.get("key"))]

func _apply_currency_defaults() -> bool:
	if not state or not tree_data:
		return false
	var changed := false
	for currency in tree_data.currencies:
		if not currency:
			continue
		var currency_key := str(currency.get("key"))
		if currency_key.is_empty() or state.currencies.has(currency_key):
			continue
		state.currencies[currency_key] = maxi(0, int(currency.get("initial_amount")))
		changed = true
	return changed

func has_toggle_effects(skill_id: String) -> bool:
	var skill := _get_skill(skill_id)
	if not skill:
		return false
	for effect in skill.effects:
		if effect and effect.toggle_mode and _is_bool_effect(effect):
			return true
	return false

func toggle_skill(skill_id: String) -> bool:
	return set_toggle_skill_active(skill_id, not is_toggle_skill_active(skill_id))

func is_toggle_skill_active(skill_id: String) -> bool:
	var skill := _get_skill(skill_id)
	if not skill or not has_toggle_effects(skill_id):
		return false
	for effect in skill.effects:
		if effect and effect.toggle_mode:
			var current := _read_target(effect)
			if not current.valid or not bool(current.value):
				return false
	return true

func set_toggle_skill_active(skill_id: String, active: bool) -> bool:
	var skill := _get_skill(skill_id)
	if not skill or get_level(skill_id) < skill.max_level or not has_toggle_effects(skill_id):
		return false
	var before_values := state.values.duplicate(true)
	for effect in skill.effects:
		if not effect or not effect.toggle_mode:
			continue
		var current := _read_target(effect)
		if not current.valid or not current.value is bool:
			state.values = before_values
			return false
		_write_target(effect, active)
	if not _storage().save_state(state, slot):
		state.values = before_values
		return false
	skill_toggled.emit(skill_id)
	for changed_id in tree_data.get_skill_ids():
		skill_state_changed.emit(changed_id)
	return true

func get_missing_prerequisites(skill_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var skill := _get_skill(skill_id)
	if not skill: return result
	for requirement in skill.requirements:
		if requirement and get_level(requirement.parent_skill_id) < requirement.required_level:
			result.append({"skill_id": requirement.parent_skill_id, "required_level": requirement.required_level})
	return result

func get_effect_preview(effect: SkillEffectData, next_level: int) -> Dictionary:
	if not effect: return {"valid": false}
	var current := _read_target(effect)
	if not current.valid:
		return {"valid": false}
	var next := _calculate_value(effect, current.value, effect.get_value_for_level(next_level))
	return {"valid": next.valid, "current": current.value, "next": next.value if next.valid else null}

func export_state() -> Dictionary:
	return state.to_dictionary() if state else {}

func import_state(snapshot: Dictionary) -> bool:
	state = SkillTreeState.from_dictionary(snapshot, tree_data.tree_id if tree_data else "main")
	return _storage().save_state(state, slot)

func _storage() -> SkillTreeStorageService:
	return _storage_service

func _apply_effect(effect: SkillEffectData, level: int) -> bool:
	var current := _read_target(effect)
	if not current.valid: return false
	var applied := _calculate_value(effect, current.value, effect.get_value_for_level(level))
	if not applied.valid: return false
	_write_target(effect, applied.value)
	return true

func _read_target(effect: SkillEffectData) -> Dictionary:
	if not state or not tree_data or effect.target_property.is_empty(): return {"valid": false}
	var stat: Resource = tree_data.get_player_stat(effect.target_property)
	if not stat:
		return {"valid": false}
	var root: Variant = state.values.get(effect.target_property, stat.call("get_base_value"))
	if effect.operation == SkillEffectData.Operation.ADD_UNIQUE and root is Dictionary:
		return {"valid": true, "value": root}
	if effect.target_kind == SkillEffectData.TargetKind.PROPERTY:
		return {"valid": true, "value": root}
	if effect.target_kind == SkillEffectData.TargetKind.ARRAY_INDEX and root is Array and effect.target_index >= 0 and effect.target_index < root.size():
		return {"valid": true, "value": root[effect.target_index]}
	if effect.target_kind == SkillEffectData.TargetKind.DICTIONARY_KEY and root is Dictionary and root.has(effect.target_key):
		return {"valid": true, "value": root[effect.target_key]}
	return {"valid": false}

func _write_target(effect: SkillEffectData, value: Variant) -> void:
	var stat: Resource = tree_data.get_player_stat(effect.target_property)
	var root: Variant = state.values.get(effect.target_property, stat.call("get_base_value")) if stat else _default_target(effect)
	if effect.target_kind == SkillEffectData.TargetKind.PROPERTY:
		state.values[effect.target_property] = value
	elif effect.target_kind == SkillEffectData.TargetKind.ARRAY_INDEX:
		var array_value: Array = root.duplicate(true)
		array_value[effect.target_index] = value
		state.values[effect.target_property] = array_value
	elif effect.target_kind == SkillEffectData.TargetKind.DICTIONARY_KEY:
		var dictionary_value: Dictionary = root.duplicate(true)
		dictionary_value[effect.target_key] = value
		state.values[effect.target_property] = dictionary_value

func _calculate_value(effect: SkillEffectData, current: Variant, amount: Variant) -> Dictionary:
	if effect.operation == SkillEffectData.Operation.ADD_UNIQUE:
		if current is Dictionary:
			if effect.target_key.strip_edges().is_empty() or current.has(effect.target_key):
				return {"valid": not effect.target_key.strip_edges().is_empty(), "value": current}
			var added_key: Dictionary = current.duplicate(true)
			added_key[effect.target_key] = amount
			return {"valid": true, "value": added_key}
		return {"valid": false}
	if effect.operation == SkillEffectData.Operation.ERASE:
		if not current is Array: return {"valid": false}
		var erased: Array = current.duplicate(true); erased.erase(amount); return {"valid": true, "value": erased}
	if effect.operation == SkillEffectData.Operation.SET:
		return {"valid": true, "value": _coerce(amount, current)}
	if not _is_number(current) or not _is_number(amount): return {"valid": false}
	var result := float(current)
	match effect.operation:
		SkillEffectData.Operation.ADD: result += float(amount)
		SkillEffectData.Operation.SUBTRACT: result -= float(amount)
		SkillEffectData.Operation.MULTIPLY: result *= float(amount)
		SkillEffectData.Operation.DIVIDE:
			if is_zero_approx(float(amount)): return {"valid": false}
			result /= float(amount)
		_: return {"valid": false}
	if effect.use_clamp: result = clampf(result, effect.minimum, effect.maximum)
	return {"valid": true, "value": roundi(result) if effect.value_type == SkillEffectData.ValueType.INT or current is int else result}

func _is_bool_effect(effect: SkillEffectData) -> bool:
	if not tree_data or not effect:
		return false
	var stat := tree_data.get_player_stat(effect.target_property)
	if not stat:
		return false
	var stat_type := int(stat.get("value_type"))
	var value_type := int(stat.get("array_element_type")) if stat_type in [SkillTreeStatData.ValueType.ARRAY, SkillTreeStatData.ValueType.DICTIONARY] else stat_type
	return value_type == SkillTreeStatData.ValueType.BOOL

func _default_target(effect: SkillEffectData) -> Variant:
	if effect.target_kind != SkillEffectData.TargetKind.PROPERTY:
		return [] if effect.target_kind == SkillEffectData.TargetKind.ARRAY_INDEX else {}
	if effect.operation in [SkillEffectData.Operation.ADD_UNIQUE, SkillEffectData.Operation.ERASE]: return []
	return 1 if effect.operation == SkillEffectData.Operation.DIVIDE else 0

func _coerce(value: Variant, example: Variant) -> Variant:
	if example is bool:
		return bool(value)
	if effect_value_type_is_int(value): return roundi(float(value))
	return float(value) if example is float else value

func effect_value_type_is_int(value: Variant) -> bool:
	return value is int

func _is_number(value: Variant) -> bool:
	return value is int or value is float

func _get_skill(skill_id: String) -> SkillData:
	return tree_data.get_skill(skill_id) if tree_data else null
