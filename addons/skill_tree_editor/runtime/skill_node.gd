class_name SkillNode
extends PanelContainer

const PRESENTATION := preload("res://addons/skill_tree_editor/runtime/skill_presentation.gd")

signal activated(skill_id: String)

var details_hover_delay := 0.15

@onready var action_button: SkillTreeButton = %ActionButton
@onready var hover_progress_bar: ProgressBar = %HoverProgressBar
@onready var body_margin_container: MarginContainer = %BodyMarginContainer
@onready var body: VBoxContainer = %Body
@onready var title_label: RichTextLabel = %TitleLabel
@onready var small_icon_rect: TextureRect = %SmallIconRect
@onready var big_icon_rect: TextureRect = %BigIconRect
@onready var category_label: RichTextLabel = %CategoryLabel
@onready var level_label: RichTextLabel = %LevelLabel
@onready var description_scroll_container: ScrollContainer = %DescriptionScrollContainer
@onready var effects_values_label: RichTextLabel = %EffectsValuesLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var requirements_label: RichTextLabel = %RequirementsLabel
@onready var cost: HBoxContainer = %Cost
@onready var cost_label: RichTextLabel = %CostLabel
@onready var state_label: RichTextLabel = %StateLabel

var skill_data: SkillData
var progression: SkillProgressionService
var direct_purchase := true

var _hover_tween: Tween
var _details_triggered := false

func _ready() -> void:
	action_button.pressed.connect(_purchase)
	action_button.mouse_entered.connect(_on_mouse_entered)
	action_button.mouse_exited.connect(_on_mouse_exited)
	hover_progress_bar.value = 0.0
	call_deferred("_set_content_mouse_passthrough")

func setup(data: SkillData, service: SkillProgressionService, direct := true) -> void:
	skill_data = data
	progression = service
	direct_purchase = direct
	_update_visual()

func _purchase() -> void:
	if progression and skill_data:
		if not direct_purchase:
			_trigger_details()
			return
		if direct_purchase:
			if progression.get_level(skill_data.skill_id) >= skill_data.max_level and progression.has_toggle_effects(skill_data.skill_id): progression.toggle_skill(skill_data.skill_id)
			else: progression.purchase_skill(skill_data.skill_id)
		_update_visual()

func _update_visual() -> void:
	if not skill_data or not progression:
		return
	var presentation := PRESENTATION.build(skill_data, progression)
	var state: String = presentation.state
	visible = state != progression.STATE_HIDDEN
	if not visible:
		return
	var current_level: int = presentation.current_level
	var next_cost: int = presentation.next_cost
	small_icon_rect.texture = skill_data.icon
	big_icon_rect.texture = skill_data.icon
	# The compact details-mode card uses its dedicated small slot; direct
	# purchase keeps the larger visual configured by the editable scene.
	small_icon_rect.visible = not direct_purchase and skill_data.icon != null
	big_icon_rect.visible = direct_purchase and skill_data.icon != null
	title_label.text = presentation.title
	category_label.text = presentation.category
	level_label.text = presentation.level
	cost_label.text = presentation.cost
	description_label.text = presentation.description
	var has_description: bool = not str(presentation.description).is_empty()
	description_label.visible = has_description
	description_scroll_container.visible = has_description
	requirements_label.text = presentation.requirements
	requirements_label.visible = not presentation.requirements.is_empty()
	effects_values_label.text = presentation.effects
	effects_values_label.visible = not presentation.effects.is_empty()
	state_label.text = presentation.compact_state_text
	if direct_purchase:
		category_label.visible = true
		description_scroll_container.visible = has_description
		requirements_label.visible = not presentation.requirements.is_empty()
		effects_values_label.visible = not presentation.effects.is_empty()
		cost_label.visible = true
		state_label.visible = true
		cost.visible = true
		action_button.enabled(presentation.can_purchase or presentation.can_toggle)
		action_button.tooltip_text = _tooltip_text(presentation)
		hover_progress_bar.visible = false
	else:
		category_label.visible = false
		description_scroll_container.visible = false
		requirements_label.visible = false
		effects_values_label.visible = false
		var is_max_level := state == progression.STATE_MAX_LEVEL
		cost_label.visible = not is_max_level
		state_label.visible = is_max_level
		cost.visible = true
		action_button.enabled(true)
		action_button.tooltip_text = ""
		hover_progress_bar.visible = true
	# State colours are expressed in RichText BBCode. A card-wide modulate would
	# alter them and make user-configured colours inaccurate.
	modulate = Color.WHITE
	
	_reset_card_size()
	call_deferred("_reset_card_size")

func _reset_card_size() -> void:
	reset_size()
	call_deferred("_set_content_mouse_passthrough")

func _set_content_mouse_passthrough() -> void:
	for control in find_children("*", "Control", true, false):
		if control != action_button:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _format_effect_value(value: Variant) -> String:
	if value is float:
		return "%.1f" % value
	return str(value)

func _effect_element_title(stat: Resource, effect: SkillEffectData) -> String:
	if not stat:
		return effect.target_key if not effect.target_key.is_empty() else str(effect.target_index)
	var collection: Dictionary = stat.get("collection_translations")
	var locale := TranslationServer.get_locale().split("_")[0]
	var raw_key := str(effect.target_index) if effect.target_kind == SkillEffectData.TargetKind.ARRAY_INDEX else effect.target_key
	var translation_key := "TR_%s_%s" % [str(stat.get("key")).to_upper(), raw_key] if effect.target_kind == SkillEffectData.TargetKind.ARRAY_INDEX else "%s_%s" % [str(stat.get("key")).to_upper(), raw_key.to_upper()]
	var fallback := raw_key
	var local_values: Dictionary = collection.get(raw_key, {})
	if local_values.has(locale):
		fallback = str(local_values[locale])
	return tr(translation_key) if tr(translation_key) != translation_key else fallback

func _with_color(text: String, color_key: String) -> String:
	var color := progression.tree_data.get_state_color(color_key) if progression and progression.tree_data else Color.WHITE
	return "[color=#%s]%s[/color]" % [color.to_html(true), text]

func _state_text(state: String) -> String:
	match state:
		"available":
			return tr("SKILL_AVAILABLE")
		"locked":
			return tr("SKILL_LOCKED")
		"not_enough_currency":
			return tr("SKILL_NOT_ENOUGH_CURRENCY")
		"max_level":
			return tr("SKILL_MAX_LEVEL_SHORT")
		_:
			return ""

func _tooltip_text(presentation: Dictionary) -> String:
	var parts: Array[String] = [
		str(presentation.title),
		str(presentation.category),
		str(presentation.level),
		str(presentation.effects),
		str(presentation.description),
		str(presentation.requirements),
		str(presentation.cost),
		str(presentation.state_text)
	]
	var result := "\n".join(parts.filter(func(value: String): return not value.is_empty()))
	var bbcode := RegEx.new()
	bbcode.compile("\\[/?[^\\]]+\\]")
	return bbcode.sub(result, "", true)

func _on_mouse_entered() -> void:
	if direct_purchase or _details_triggered:
		return
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	hover_progress_bar.value = 0.0
	_hover_tween = create_tween()
	_hover_tween.tween_property(hover_progress_bar, "value", 100.0, details_hover_delay)
	_hover_tween.tween_callback(func():
		_trigger_details()
	)

func _on_mouse_exited() -> void:
	if direct_purchase:
		return
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = null
	hover_progress_bar.value = 0.0
	_details_triggered = false

func _trigger_details() -> void:
	if direct_purchase or _details_triggered or not skill_data or not is_inside_tree():
		return
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = null
	_details_triggered = true
	hover_progress_bar.value = 100.0
	activated.emit(skill_data.skill_id)
