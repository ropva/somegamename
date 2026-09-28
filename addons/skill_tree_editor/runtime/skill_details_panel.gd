class_name SkillDetailsPanel
extends Control

const PRESENTATION := preload("res://addons/skill_tree_editor/runtime/skill_presentation.gd")

enum PanelSide { LEFT, RIGHT }

signal action_requested(skill_id: String)
signal close_requested

## Space between the panel and the edge it slides from.
@export_range(0.0, 128.0, 1.0) var reveal_gap := 16.0
## Duration of the opening and closing slide animation.
@export_range(0.01, 1.0, 0.01) var slide_duration := 0.22
## Duration of the bounce used when changing the selected skill.
@export_range(0.01, 1.0, 0.01) var bounce_duration := 0.16
## Initial scale for the selected-skill bounce animation.
@export_range(0.5, 1.0, 0.01) var bounce_start_scale := 0.96

@onready var landscape_panel: PanelContainer = %LandscapePanel
@onready var portrait_panel: PanelContainer = %PortraitPanel
@onready var landscape_action_button: SkillTreeButton = %LandscapeActionButton
@onready var portrait_action_button: SkillTreeButton = %PortraitActionButton
@onready var landscape_close_button: SkillTreeButton = %LandscapeCloseButton
@onready var portrait_close_button: SkillTreeButton = %PortraitCloseButton

@onready var landscape_icon: TextureRect = %LandscapeIconTextureRect
@onready var landscape_title: RichTextLabel = %LandscapeTitleLabel
@onready var landscape_category: RichTextLabel = %LandscapeCategoryLabel
@onready var landscape_level: RichTextLabel = %LandscapeLevelLabel
@onready var landscape_effects: RichTextLabel = %LandscapeEffectsLabel
@onready var landscape_description: RichTextLabel = %LandscapeDescriptionLabel
@onready var landscape_requirements: RichTextLabel = %LandscapeRequirementsLabel
@onready var landscape_cost: RichTextLabel = %LandscapeCostLabel

@onready var portrait_icon: TextureRect = %PortraitIconTextureRect
@onready var portrait_title: RichTextLabel = %PortraitTitleLabel
@onready var portrait_category: RichTextLabel = %PortraitCategoryLabel
@onready var portrait_level: RichTextLabel = %PortraitLevelLabel
@onready var portrait_effects: RichTextLabel = %PortraitEffectsLabel
@onready var portrait_description: RichTextLabel = %PortraitDescriptionLabel
@onready var portrait_requirements: RichTextLabel = %PortraitRequirementsLabel
@onready var portrait_cost: RichTextLabel = %PortraitCostLabel

var skill_data: SkillData
var progression: SkillProgressionService
var is_landscape := true
var panel_side := PanelSide.RIGHT
var _motion_tween: Tween
var _layout_revision := 0

func _ready() -> void:
	# The full-screen root must pass outside clicks to SkillTreeView, while the
	# actual card must stop them so SkillTreeView cannot treat a panel click as
	# an outside click. Buttons are explicitly restored to STOP because the
	# scene also uses recursive mouse settings for its presentation controls.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_configure_mouse_behavior()
	landscape_close_button.pressed.connect(func(): close_requested.emit())
	portrait_close_button.pressed.connect(func(): close_requested.emit())
	landscape_action_button.pressed.connect(_emit_action)
	portrait_action_button.pressed.connect(_emit_action)
	_select_layout(true)
	hide()

func _configure_mouse_behavior() -> void:
	for panel in [landscape_panel, portrait_panel]:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
	for button in [landscape_action_button, portrait_action_button, landscape_close_button, portrait_close_button]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP

func present(skill: SkillData, service: SkillProgressionService, landscape: bool, side: int, animate_entry: bool) -> void:
	skill_data = skill
	progression = service
	panel_side = side
	_select_layout(landscape)
	_apply_content()
	# For an animated entry the panel must remain hidden while its natural size
	# is measured. Otherwise it is rendered once at the centered/default offset.
	if animate_entry:
		hide()
	else:
		show()
	_queue_layout(animate_entry)

func refresh() -> void:
	if not skill_data or not progression:
		return
	_apply_content()
	_queue_layout(false)

func relayout(landscape: bool, side: int) -> void:
	panel_side = side
	_select_layout(landscape)
	_apply_content()
	_queue_layout(false)

func play_bounce() -> void:
	if not visible:
		return
	_layout_revision += 1
	_stop_motion_tween()
	var panel := _active_panel()
	panel.offset_transform_position = _target_offset(panel)
	panel.offset_transform_scale = Vector2.ONE * bounce_start_scale
	_motion_tween = create_tween()
	_motion_tween.tween_property(panel, "offset_transform_scale", Vector2.ONE, bounce_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close_panel(immediate := false) -> void:
	_layout_revision += 1
	_stop_motion_tween()
	if immediate or not visible:
		hide()
		_reset_transforms()
		return
	var panel := _active_panel()
	panel.offset_transform_scale = Vector2.ONE
	_motion_tween = create_tween()
	_motion_tween.tween_property(panel, "offset_transform_position", _hidden_offset(panel), slide_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.tween_callback(func():
		if not is_instance_valid(self):
			return
		hide()
		_reset_transforms()
	)

func contains_global_point(global_position: Vector2) -> bool:
	return visible and _visual_rect(_active_panel()).has_point(global_position)

func _gui_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var global_position := get_global_transform() * get_local_mouse_position()
	var panel := _active_panel()
	if not _visual_rect(panel).has_point(global_position):
		return
	# offset_transform_position changes drawing and does not move Control's
	# normal input rect. Handle the visible button rectangles here as a fallback
	# so the configured scene buttons remain usable at either side of the tree.
	if _visual_rect(_active_close_button()).has_point(global_position):
		close_requested.emit()
	elif not _active_action_button().disabled and _visual_rect(_active_action_button()).has_point(global_position):
		_emit_action()
	accept_event()

func _emit_action() -> void:
	if skill_data:
		action_requested.emit(skill_data.skill_id)

func _select_layout(landscape: bool) -> void:
	is_landscape = landscape
	landscape_panel.visible = is_landscape
	portrait_panel.visible = not is_landscape

func _queue_layout(animate_entry: bool) -> void:
	_layout_revision += 1
	_stop_motion_tween()
	var panel := _active_panel()
	# A visible landscape panel has a non-zero side offset. Resetting it here
	# makes it flash in the centre during refreshes and rapid clicks.
	panel.offset_transform_position = Vector2.ZERO if animate_entry or not visible else _target_offset(panel)
	panel.offset_transform_scale = Vector2.ONE
	call_deferred("_finish_layout", _layout_revision, animate_entry)

func _finish_layout(revision: int, animate_entry: bool) -> void:
	# A reset or tree close can remove this panel while the deferred layout is
	# waiting. Never access SceneTree from a detached control.
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if revision != _layout_revision:
		return
	var panel := _active_panel()
	if not animate_entry:
		panel.offset_transform_position = _target_offset(panel)
		show()
		return
	panel.offset_transform_position = _hidden_offset(panel)
	show()
	_motion_tween = create_tween()
	_motion_tween.tween_property(panel, "offset_transform_position", _target_offset(panel), slide_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _hidden_offset(panel: PanelContainer) -> Vector2:
	if not is_landscape:
		return Vector2(0.0, panel.size.y + reveal_gap)
	var half_viewport_width := size.x * 0.5
	var half_panel_width := panel.size.x * 0.5
	return Vector2(-(half_viewport_width + half_panel_width) if panel_side == PanelSide.LEFT else (half_viewport_width + half_panel_width), 0.0)

func _target_offset(panel: PanelContainer) -> Vector2:
	if not is_landscape:
		return Vector2.ZERO
	var half_viewport_width := size.x * 0.5
	var half_panel_width := panel.size.x * 0.5
	return Vector2(-half_viewport_width + half_panel_width if panel_side == PanelSide.LEFT else half_viewport_width - half_panel_width, 0.0)

func _active_panel() -> PanelContainer:
	return landscape_panel if is_landscape else portrait_panel

func _active_action_button() -> SkillTreeButton:
	return landscape_action_button if is_landscape else portrait_action_button

func _active_close_button() -> SkillTreeButton:
	return landscape_close_button if is_landscape else portrait_close_button

func _visual_rect(control: Control) -> Rect2:
	# Control.get_global_rect() follows its layout rect. The active panel is
	# drawn with an additional offset-transform, which has to be applied to all
	# descendants for hit testing as well.
	var rect := control.get_global_rect()
	var panel_offset := _active_panel().offset_transform_position
	rect.position += panel_offset
	return rect

func _stop_motion_tween() -> void:
	if _motion_tween and _motion_tween.is_running():
		_motion_tween.kill()
	_motion_tween = null

func _reset_transforms() -> void:
	for panel in [landscape_panel, portrait_panel]:
		panel.offset_transform_position = Vector2.ZERO
		panel.offset_transform_scale = Vector2.ONE

func _apply_content() -> void:
	var view := PRESENTATION.build(skill_data, progression)
	if view.is_empty():
		return
	_apply_landscape_content(view)
	_apply_portrait_content(view)

func _apply_landscape_content(view: Dictionary) -> void:
	landscape_icon.texture = skill_data.icon
	landscape_icon.visible = skill_data.icon != null
	landscape_title.text = view.title
	landscape_category.text = view.category
	landscape_level.text = view.level
	landscape_effects.text = view.effects
	landscape_effects.visible = not view.effects.is_empty()
	landscape_description.text = view.description
	landscape_description.visible = not view.description.is_empty()
	landscape_requirements.text = view.requirements
	landscape_requirements.visible = not view.requirements.is_empty()
	landscape_cost.text = view.cost
	landscape_cost.visible = str(view.get("state", "")) != SkillProgressionService.STATE_MAX_LEVEL
	_apply_action(landscape_action_button, view)

func _apply_portrait_content(view: Dictionary) -> void:
	portrait_icon.texture = skill_data.icon
	portrait_icon.visible = skill_data.icon != null
	portrait_title.text = view.title
	portrait_category.text = view.category
	portrait_level.text = view.level
	portrait_effects.text = view.effects
	portrait_effects.visible = not view.effects.is_empty()
	portrait_description.text = view.description
	portrait_description.visible = not view.description.is_empty()
	portrait_requirements.text = view.requirements
	portrait_requirements.visible = not view.requirements.is_empty()
	portrait_cost.text = view.cost
	portrait_cost.visible = str(view.get("state", "")) != SkillProgressionService.STATE_MAX_LEVEL
	_apply_action(portrait_action_button, view)

func _apply_action(action: SkillTreeButton, view: Dictionary) -> void:
	action.text = view.action_text
	action.remove_theme_color_override("font_color")
	action.remove_theme_color_override("font_disabled_color")
	action.add_theme_color_override("font_color", view.action_color)
	action.add_theme_color_override("font_disabled_color", view.action_color)
	action.enabled(view.action_enabled)
