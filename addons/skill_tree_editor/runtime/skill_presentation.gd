extends RefCounted

static func build(skill: SkillData, progression: SkillProgressionService) -> Dictionary:
	if not skill or not progression:
		return {}
	var state := progression.get_skill_state(skill.skill_id)
	var current_level := progression.get_level(skill.skill_id)
	var next_cost := skill.get_cost(current_level + 1)
	var level_text := TranslationServer.translate("SKILL_LEVEL") % [current_level, skill.max_level]
	var tree := progression.tree_data
	var cost_text := _format_cost(next_cost, skill.currency_key, tree)
	var action_text_key := _action_text_key(state, current_level, skill.max_level, progression.has_toggle_effects(skill.skill_id), progression.is_toggle_skill_active(skill.skill_id), next_cost)
	var can_toggle := state == progression.STATE_MAX_LEVEL and progression.has_toggle_effects(skill.skill_id)
	var action_color_key := _action_color_key(state, can_toggle)
	var result := {
		"state": state,
		"current_level": current_level,
		"next_cost": next_cost,
		"title": TranslationServer.translate(skill.get_title_key()),
		"category": TranslationServer.translate(skill.category),
		"description": TranslationServer.translate(skill.description),
		"level": _with_color(level_text, tree, "max_level") if state == progression.STATE_MAX_LEVEL else level_text,
		"cost": cost_text,
		"requirements": "",
		"effects": _build_effects(skill, progression, current_level),
		"can_purchase": state == progression.STATE_AVAILABLE,
		"can_toggle": can_toggle,
		"toggle_active": progression.is_toggle_skill_active(skill.skill_id),
		"action_text_key": action_text_key,
		"action_text": TranslationServer.translate(action_text_key),
		"action_enabled": state == progression.STATE_AVAILABLE or can_toggle,
		"action_color": tree.get_state_color(action_color_key) if tree else Color.WHITE
	}
	if state == progression.STATE_AVAILABLE:
		result.cost = _with_color(cost_text, tree, "enough_currency")
	elif state == progression.STATE_NOT_ENOUGH_CURRENCY:
		result.cost = _with_color(cost_text, tree, "not_enough_currency")
	var missing_text: Array[String] = []
	for requirement in progression.get_missing_prerequisites(skill.skill_id):
		var parent := tree.get_skill(str(requirement["skill_id"]))
		if parent:
			missing_text.append(TranslationServer.translate("SKILL_REQUIRED") % [TranslationServer.translate(parent.get_title_key()), requirement["required_level"]])
	if not missing_text.is_empty():
		result.requirements = TranslationServer.translate("SKILL_REQUIREMENTS") % ", ".join(missing_text)
	var state_text := _state_text(state)
	result.state_text = _with_color(state_text, tree, "available") if state == progression.STATE_AVAILABLE else (_with_color(state_text, tree, "unavailable") if state in [progression.STATE_LOCKED, progression.STATE_NOT_ENOUGH_CURRENCY] else (_with_color(state_text, tree, "max_level") if state == progression.STATE_MAX_LEVEL else state_text))
	var compact_state_text := _compact_state_text(state)
	result.compact_state_text = _with_color(compact_state_text, tree, "available") if state == progression.STATE_AVAILABLE else (_with_color(compact_state_text, tree, "unavailable") if state in [progression.STATE_LOCKED, progression.STATE_NOT_ENOUGH_CURRENCY] else (_with_color(compact_state_text, tree, "max_level") if state == progression.STATE_MAX_LEVEL else compact_state_text))
	return result

static func _action_color_key(state: String, can_toggle: bool) -> String:
	if can_toggle or state == "available":
		return "available"
	if state == "max_level":
		return "max_level"
	return "unavailable"

static func _action_text_key(state: String, current_level: int, max_level: int, has_toggle: bool, toggle_active: bool, _next_cost: int) -> String:
	if state == "max_level":
		return "DISABLE" if has_toggle and toggle_active else ("ENABLE" if has_toggle else "MAX_LEVEL")
	if state == "not_enough_sp":
		return "NOT_ENOUGH_FUNDS"
	if state == "locked":
		return "LOCKED"
	if state == "available":
		return "OPEN" if current_level == 0 else "UPGRADE"
	return "LOCKED"

static func _build_effects(skill: SkillData, progression: SkillProgressionService, current_level: int) -> String:
	var values: Array[String] = []
	for effect in skill.effects:
		if not effect:
			continue
		var stat := progression.tree_data.get_player_stat(effect.target_property)
		var title_key := str(stat.get("title_key")) if stat else ""
		var title := TranslationServer.translate(title_key) if not title_key.is_empty() else effect.target_property
		var is_collection := stat and int(stat.get("value_type")) in [SkillTreeStatData.ValueType.ARRAY, SkillTreeStatData.ValueType.DICTIONARY]
		var element_title := _element_title(stat, effect)
		var display_title: String = title + ("\n" + element_title if is_collection else "")
		if effect.operation == SkillEffectData.Operation.ADD_UNIQUE:
			var unique_value := effect.get_value_for_level(maxi(1, current_level + 1))
			var stored := progression.get_value(effect.target_property, {})
			if stored is Dictionary and stored.has(effect.target_key): unique_value = stored[effect.target_key]
			values.append(_with_color("(%s) %s: %s" % [TranslationServer.translate("NEW"), element_title, _format_value(unique_value)], progression.tree_data, "next_value"))
			continue
		var preview := progression.get_effect_preview(effect, current_level + 1) if current_level < skill.max_level else progression.get_effect_preview(effect, current_level)
		if preview.get("valid", false):
			var text := "%s: %s" % [display_title, _format_value(preview["current"])]
			if current_level < skill.max_level:
				text += " %s" % _with_color("→ %s" % _format_value(preview["next"]), progression.tree_data, "next_value")
			values.append(text)
	return "\n".join(values)

static func _element_title(stat: Resource, effect: SkillEffectData) -> String:
	if not stat: return effect.target_key if not effect.target_key.is_empty() else str(effect.target_index)
	var raw_key := str(effect.target_index) if effect.target_kind == SkillEffectData.TargetKind.ARRAY_INDEX else effect.target_key
	var key := "TR_%s_%s" % [str(stat.get("key")).to_upper(), raw_key] if effect.target_kind == SkillEffectData.TargetKind.ARRAY_INDEX else "%s_%s" % [str(stat.get("key")).to_upper(), raw_key.to_upper()]
	var locale := TranslationServer.get_locale().split("_")[0]
	var translations: Dictionary = stat.get("collection_translations")
	var fallback := str((translations.get(raw_key, {}) as Dictionary).get(locale, raw_key))
	var translated := TranslationServer.translate(key)
	return translated if translated != key else fallback

static func _with_color(text: String, tree: SkillTreeData, color_key: String) -> String:
	var color := tree.get_state_color(color_key) if tree else Color.WHITE
	return "[color=#%s]%s[/color]" % [color.to_html(true), text]

static func _format_value(value: Variant) -> String:
	return "%.1f" % value if value is float else str(value)

static func _format_cost(amount: int, currency_key: String, tree: SkillTreeData) -> String:
	if amount == 0:
		return TranslationServer.translate("FREE")
	var currency: Resource = tree.get_currency(currency_key) if tree else null
	var token := currency_key
	if currency:
		var icon: Texture2D = currency.get("icon") as Texture2D
		if icon and not icon.resource_path.is_empty():
			token = "[img=24x24]%s[/img]" % icon.resource_path
		else:
			var short_key := "CURRENCY_%s_SHORT" % currency_key.to_upper()
			token = TranslationServer.translate(short_key)
			if token == short_key:
				token = TranslationServer.translate("CURRENCY_%s" % currency_key.to_upper())
	return TranslationServer.translate("SKILL_COST") % [amount, token]

static func _state_text(state: String) -> String:
	match state:
		"available": return TranslationServer.translate("SKILL_AVAILABLE")
		"locked": return TranslationServer.translate("SKILL_LOCKED")
		"not_enough_currency": return TranslationServer.translate("SKILL_NOT_ENOUGH_CURRENCY")
		"max_level": return TranslationServer.translate("SKILL_MAX_LEVEL")
		_: return ""

static func _compact_state_text(state: String) -> String:
	return TranslationServer.translate("SKILL_MAX_LEVEL_SHORT") if state == "max_level" else _state_text(state)
