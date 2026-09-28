class_name SkillTreeButton
extends Button

## UI control whose hover and press feedback is animated by this button.
@export var target_ui: Control
## Reference size used to normalize the visual feedback animation.
@export var animation_reference_size := Vector2(64.0, 64.0)

var _base_scale := Vector2.ONE
var _scale_tween: Tween

func _ready() -> void:
	if not target_ui:
		target_ui = self
	_base_scale = target_ui.scale
	pivot_offset_ratio = Vector2(0.5, 0.5)
	target_ui.pivot_offset_ratio = Vector2(0.5, 0.5)
	mouse_entered.connect(_animate_hover)
	focus_entered.connect(_animate_hover)
	mouse_exited.connect(_restore_scale)
	focus_exited.connect(_restore_scale)
	button_down.connect(_animate_press)
	button_up.connect(_restore_scale)

func enabled(value: bool) -> void:
	disabled = not value
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	if target_ui != self and target_ui.has_method("enabled"):
		target_ui.enabled(value)

func _target_scale(multiplier: float) -> Vector2:
	pivot_offset_ratio = Vector2(0.5, 0.5)
	target_ui.pivot_offset_ratio = Vector2(0.5, 0.5)
	var ui_size := target_ui.size
	if ui_size.x <= 0.0 or ui_size.y <= 0.0:
		return _base_scale
	var offset := animation_reference_size * (multiplier - 1.0)
	return Vector2(
		_base_scale.x + offset.x / ui_size.x,
		_base_scale.y + offset.y / ui_size.y
	)

func _animate_hover() -> void:
	if disabled:
		return
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.tween_property(target_ui, "scale", _target_scale(1.16), 0.08)

func _animate_press() -> void:
	if disabled:
		return
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.tween_property(target_ui, "scale", _target_scale(0.84), 0.08)

func _restore_scale() -> void:
	if disabled:
		return
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.tween_property(target_ui, "scale", _base_scale, 0.1)

func _kill_scale_tween() -> void:
	if _scale_tween and _scale_tween.is_running():
		_scale_tween.kill()
