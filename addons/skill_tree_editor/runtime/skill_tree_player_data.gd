extends RefCounted

var _service: Variant

func bind(service: Variant) -> void:
	_service = service

func get_value(key: StringName, fallback: Variant = null) -> Variant:
	return _service.get_value(str(key), fallback) if _service else fallback

func set_value(key: StringName, value: Variant) -> bool:
	return _service.set_value(str(key), value) if _service else false

func _get(property: StringName) -> Variant:
	return get_value(property)

func _set(property: StringName, value: Variant) -> bool:
	return set_value(property, value)
