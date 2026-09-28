@tool
class_name SkillTreeValidator
extends RefCounted

const CURRENCY_SCRIPT := preload("res://addons/skill_tree_editor/scripts/skill_tree_currency_data.gd")

static func validate(tree: SkillTreeData) -> PackedStringArray:
	var errors := PackedStringArray()
	if not tree:
		errors.append("Дерево не назначено")
		return errors
	if tree.currencies.is_empty():
		errors.append("В дереве должна быть хотя бы одна валюта")
	var currency_keys := {}
	for currency in tree.currencies:
		if not currency:
			errors.append("Найдена пустая валюта")
			continue
		var currency_key := str(currency.get("key"))
		if not CURRENCY_SCRIPT.is_valid_key(currency_key):
			errors.append("Некорректный ключ валюты: %s" % currency_key)
		elif currency_keys.has(currency_key):
			errors.append("Повторяющийся ключ валюты: %s" % currency_key)
		else:
			currency_keys[currency_key] = true
	var ids := {}
	for skill in tree.skills:
		if not skill:
			errors.append("Найден пустой SkillData")
			continue
		if skill.skill_id.strip_edges().is_empty():
			errors.append("У навыка '%s' пустой ID" % skill.title)
		elif ids.has(skill.skill_id):
			errors.append("Повторяющийся ID: %s" % skill.skill_id)
		else:
			ids[skill.skill_id] = skill
		if not currency_keys.has(skill.currency_key):
			errors.append("Навык '%s': валюта '%s' не создана" % [skill.skill_id, skill.currency_key])

	for skill in tree.skills:
		if not skill:
			continue
		var seen_requirements := {}
		for requirement in skill.requirements:
			if not requirement or requirement.parent_skill_id.strip_edges().is_empty():
				errors.append("Навык '%s': пустой prerequisite" % skill.skill_id)
				continue
			if not ids.has(requirement.parent_skill_id):
				errors.append("Навык '%s': отсутствует родитель '%s'" % [skill.skill_id, requirement.parent_skill_id])
			if requirement.required_level < 1:
				errors.append("Навык '%s': required level должен быть больше 0" % skill.skill_id)
			elif ids.has(requirement.parent_skill_id) and requirement.required_level > ids[requirement.parent_skill_id].max_level:
				errors.append("Навык '%s': required level выше max_level родителя" % skill.skill_id)
			var edge_key := requirement.parent_skill_id
			if seen_requirements.has(edge_key):
				errors.append("Навык '%s': дублированная связь с '%s'" % [skill.skill_id, requirement.parent_skill_id])
			seen_requirements[edge_key] = true
		_validate_effects(skill, tree, errors)

	for skill in tree.skills:
		if skill and not skill.skill_id.is_empty() and _has_cycle(skill.skill_id, tree, {}, {}):
			errors.append("Обнаружен цикл, начиная с '%s'" % skill.skill_id)
	return errors

static func _has_cycle(skill_id: String, tree: SkillTreeData, visiting: Dictionary, visited: Dictionary) -> bool:
	if visiting.has(skill_id):
		return true
	if visited.has(skill_id):
		return false
	var skill := tree.get_skill(skill_id)
	if not skill:
		return false
	visiting[skill_id] = true
	for requirement in skill.requirements:
		if requirement and _has_cycle(requirement.parent_skill_id, tree, visiting, visited):
			return true
	visiting.erase(skill_id)
	visited[skill_id] = true
	return false

static func _validate_effects(skill: SkillData, tree: SkillTreeData, errors: PackedStringArray) -> void:
	for effect in skill.effects:
		if not effect:
			errors.append("Навык '%s': пустой эффект" % skill.skill_id)
			continue
		var stat: Resource = null
		if effect.target_property.strip_edges().is_empty():
			errors.append("Навык '%s': пустое поле Data" % skill.skill_id)
			continue
		stat = tree.get_player_stat(effect.target_property)
		if not stat:
			errors.append("Навык '%s': характеристика '%s' не создана" % [skill.skill_id, effect.target_property])
			continue
		var is_array_stat := int(stat.get("value_type")) == SkillTreeStatData.ValueType.ARRAY
		var is_dictionary_stat := int(stat.get("value_type")) == SkillTreeStatData.ValueType.DICTIONARY
		var effect_value_type := int(stat.get("array_element_type")) if is_array_stat or is_dictionary_stat else int(stat.get("value_type"))
		if effect_value_type == SkillTreeStatData.ValueType.BOOL and effect.operation != SkillEffectData.Operation.SET:
			errors.append("Навык '%s': Bool-характеристика поддерживает только «Установить»" % skill.skill_id)
		if effect.operation == SkillEffectData.Operation.DIVIDE and is_zero_approx(float(effect.get_value_for_level(1))):
			errors.append("Навык '%s': деление на ноль" % skill.skill_id)
		if effect.operation == SkillEffectData.Operation.ADD_UNIQUE and not is_dictionary_stat:
			errors.append("Навык '%s': «Добавить уникальное» требует характеристику Dictionary" % skill.skill_id)
		if effect.operation == SkillEffectData.Operation.ADD_UNIQUE and effect.target_key.strip_edges().is_empty():
			errors.append("Навык '%s': для «Добавить уникальное» нужен новый ключ" % skill.skill_id)
		if is_array_stat and effect.operation not in [SkillEffectData.Operation.ADD_UNIQUE, SkillEffectData.Operation.ERASE] and effect.target_kind != SkillEffectData.TargetKind.ARRAY_INDEX:
			errors.append("Навык '%s': числовая операция массива требует индекс" % skill.skill_id)
		if is_dictionary_stat and effect.operation not in [SkillEffectData.Operation.ADD_UNIQUE, SkillEffectData.Operation.ERASE] and effect.target_kind != SkillEffectData.TargetKind.DICTIONARY_KEY:
			errors.append("Навык '%s': числовая операция словаря требует ключ" % skill.skill_id)
		if effect.operation == SkillEffectData.Operation.ADD_UNIQUE and effect.target_kind != SkillEffectData.TargetKind.PROPERTY:
			errors.append("Навык '%s': «Добавить уникальное» должно работать со словарём целиком" % skill.skill_id)
