extends TextureButton

signal selected

func _pressed() -> void:
	selected.emit(name)
