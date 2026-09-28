class_name SkillTreeView
extends Control

enum InteractionMode { DIRECT_PURCHASE, DETAILS_PANEL }
enum DetailsPanelSide { LEFT, RIGHT }

signal opened
signal closed

## Static tree resource rendered by this view.
@export var skill_tree_data: SkillTreeData
## Save namespace used for this tree instance.
@export var save_slot := "default"
## Scene used for each runtime skill card.
@export var skill_node_scene: PackedScene = DEFAULT_SKILL_NODE_SCENE
## Scene used for prerequisite connection lines.
@export var skill_connection_scene: PackedScene = DEFAULT_SKILL_CONNECTION_SCENE
## Scene used for the optional expanded skill details UI.
@export var skill_details_panel_scene: PackedScene = DEFAULT_SKILL_DETAILS_PANEL_SCENE
## Editable row scene used for each currency balance.
@export var currency_row_scene: PackedScene = DEFAULT_CURRENCY_ROW_SCENE
## Editable confirmation scene for the gameplay progression reset.
@export var reset_confirmation_scene: PackedScene = DEFAULT_RESET_CONFIRMATION_SCENE
## Whether cards purchase directly or open the details panel first.
@export var interaction_mode: InteractionMode = InteractionMode.DIRECT_PURCHASE
## Hover duration before a skill opens its details panel.
@export_range(0.05, 2.0, 0.05) var details_hover_delay := 0.15
## Initial canvas zoom factor for this view.
@export_range(0.25, 2.0, 0.05) var zoom := 1.0

@onready var bg_rect: ColorRect = %BgRect
@onready var close_button: SkillTreeButton = %CloseSkillTreeButton
@onready var corner: Control = %SkillTreeCorner
@onready var currency_display: HBoxContainer = %CurrencyDisplay
@onready var reset_button: SkillTreeButton = %ResetProgressionButton

const DEFAULT_SKILL_NODE_SCENE := preload("res://addons/skill_tree_editor/scenes/skill_node.tscn")
const DEFAULT_SKILL_CONNECTION_SCENE := preload("res://addons/skill_tree_editor/scenes/skill_connection.tscn")
const DEFAULT_SKILL_DETAILS_PANEL_SCENE := preload("res://addons/skill_tree_editor/scenes/skill_details_ui.tscn")
const DEFAULT_CURRENCY_ROW_SCENE := preload("res://addons/skill_tree_editor/scenes/skill_tree_currency_row.tscn")
const DEFAULT_RESET_CONFIRMATION_SCENE := preload("res://addons/skill_tree_editor/scenes/skill_tree_reset_confirmation.tscn")

var progression: SkillProgressionService
var skill_tree: Variant
var skill_nodes: Dictionary = {}
var pan := Vector2.ZERO
var dragging := false
var drag_button := -1
var drag_start := Vector2.ZERO
var pan_start := Vector2.ZERO
var transition_tween: Tween
var details_panel
var selected_skill_id := ""
var panel_side := DetailsPanelSide.RIGHT
var panel_layout_queued := false
var reset_panel: SkillTreeResetConfirmation

func _ready() -> void:
	if not skill_node_scene:
		skill_node_scene = DEFAULT_SKILL_NODE_SCENE
	if not skill_connection_scene:
		skill_connection_scene = DEFAULT_SKILL_CONNECTION_SCENE
	if not skill_details_panel_scene:
		skill_details_panel_scene = DEFAULT_SKILL_DETAILS_PANEL_SCENE
	if not currency_row_scene:
		currency_row_scene = DEFAULT_CURRENCY_ROW_SCENE
	if not reset_confirmation_scene:
		reset_confirmation_scene = DEFAULT_RESET_CONFIRMATION_SCENE
	if close_button:
		close_button.text = tr("CLOSE_SKILL_TREE")
		close_button.pressed.connect(close)
	if reset_button:
		reset_button.text = tr("RESET_PROGRESSION")
		reset_button.pressed.connect(_show_reset_confirmation)
	_build_currency_display()
	if reset_confirmation_scene:
		reset_panel = reset_confirmation_scene.instantiate() as SkillTreeResetConfirmation
		if reset_panel:
			add_child(reset_panel)
			reset_panel.z_index = 20
			reset_panel.hide()
			reset_panel.cancelled.connect(func(): reset_panel.hide())
			reset_panel.confirmed.connect(_confirm_progression_reset)
	if skill_details_panel_scene:
		details_panel = skill_details_panel_scene.instantiate()
		if details_panel:
			details_panel.z_index = 10
			details_panel.hide()
			details_panel.action_requested.connect(_on_details_action_requested)
			details_panel.close_requested.connect(_close_details_panel)
			add_child(details_panel)
			details_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_queue_details_layout)
	if not skill_tree_data:
		push_error("SkillTree: skill_tree_data is not assigned")
		return
	skill_tree = get_node_or_null("/root/SkillTree")
	progression = skill_tree.configure(skill_tree_data, save_slot) if skill_tree else null
	if not progression:
		push_error("SkillTree: skill_tree autoload is missing. Enable the Skill Tree addon first.")
		return
	if not progression.skill_state_changed.is_connected(_refresh):
		progression.skill_state_changed.connect(_refresh)
	if not skill_tree.state_changed.is_connected(_on_storage_changed):
		skill_tree.state_changed.connect(_on_storage_changed)
	if not skill_tree.currency_changed.is_connected(_on_currency_changed):
		skill_tree.currency_changed.connect(_on_currency_changed)
	_build_tree()
	_refresh_currency_display()
	call_deferred("_center_canvas")

func _build_tree() -> void:
	for child in corner.get_children():
		child.queue_free()
	skill_nodes.clear()
	for data in skill_tree_data.skills:
		if not data or data.skill_id.is_empty():
			continue
		var node: SkillNode = skill_node_scene.instantiate() as SkillNode
		if not node:
			push_error("SkillTree: skill_node_scene must instantiate SkillNode")
			continue
		node.name = "Skill_%s" % data.skill_id
		node.details_hover_delay = details_hover_delay
		corner.add_child(node)
		node.setup(data, progression, interaction_mode == InteractionMode.DIRECT_PURCHASE)
		node.activated.connect(_on_skill_activated)
		skill_nodes[data.skill_id] = node
	_refresh()

func _refresh(_skill_id := "") -> void:
	if not corner or not skill_tree_data:
		return
	for skill_id in skill_nodes:
		var node: SkillNode = skill_nodes[skill_id]
		var data := skill_tree_data.get_skill(skill_id)
		if not data:
			continue
		# Editor positions are the top-left of the 384 px card. Therefore a
		# node at (-192, -192) has its visual center exactly at runtime Origin.
		node.position = data.editor_position
		node._update_visual()
	_rebuild_connections()

func _rebuild_connections() -> void:
	for child in corner.get_children():
		if child is Line2D:
			child.queue_free()
	for child_data in skill_tree_data.skills:
		if not child_data:
			continue
		var child := skill_nodes.get(child_data.skill_id) as Control
		if not child or not child.visible:
			continue
		for requirement in child_data.requirements:
			if not requirement:
				continue
			var parent := skill_nodes.get(requirement.parent_skill_id) as Control
			if not parent or not parent.visible:
				continue
			var connection := skill_connection_scene.instantiate() as Line2D
			if not connection:
				continue
			connection.points = PackedVector2Array([
				parent.position + parent.size * 0.5,
				child.position + child.size * 0.5
			])
			connection.default_color = _connection_color(progression.get_skill_state(child_data.skill_id))
			corner.add_child(connection)
			corner.move_child(connection, 0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center_canvas()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_stop_dragging()

func open() -> void:
	# TranslationServer can change language while this overlay is hidden. Rebuild
	# all labels immediately before it becomes visible again.
	if close_button:
		close_button.text = tr("CLOSE_SKILL_TREE")
	if reset_button:
		reset_button.text = tr("RESET_PROGRESSION")
	_refresh_currency_display()
	_refresh()
	if visible and not transition_tween:
		return
	_stop_transition()
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	scale = Vector2.ONE * 0.96
	transition_tween = create_tween().set_parallel()
	transition_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	transition_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	transition_tween.chain().tween_callback(func():
		transition_tween = null
		opened.emit()
	)

func close(immediate := false) -> void:
	if not visible:
		return
	_stop_dragging()
	_close_details_panel(true)
	_stop_transition()
	if immediate:
		hide()
		modulate.a = 1.0
		scale = Vector2.ONE
		return
	transition_tween = create_tween().set_parallel()
	transition_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	transition_tween.tween_property(self, "scale", Vector2.ONE * 0.96, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	transition_tween.chain().tween_callback(func():
		hide()
		modulate.a = 1.0
		scale = Vector2.ONE
		transition_tween = null
		closed.emit()
	)

func is_open() -> bool:
	return visible

func _stop_transition() -> void:
	if transition_tween and transition_tween.is_running():
		transition_tween.kill()
	transition_tween = null

func _center_canvas() -> void:
	if not corner:
		return
	corner.position = size * 0.5 + pan
	corner.scale = Vector2.ONE * zoom
	_rebuild_connections()
	_queue_details_layout()

func _gui_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_stop_dragging()
		return
	var local_position := get_local_mouse_position()
	if event is InputEventScreenTouch:
		local_position = get_global_transform().affine_inverse() * event.position
		if event.pressed and _close_details_if_outside(local_position):
			accept_event()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close_details_if_outside(local_position)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(local_position, 0.1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(local_position, -0.1)
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed and _can_start_drag(local_position):
				dragging = true
				drag_button = event.button_index
				drag_start = local_position
				pan_start = pan
				accept_event()
			elif not event.pressed and dragging and event.button_index == drag_button:
				_stop_dragging()
				accept_event()
	elif event is InputEventMouseMotion and dragging:
		pan = pan_start + local_position - drag_start
		_center_canvas()
		accept_event()

func _is_over_skill(local_position: Vector2) -> bool:
	var global_position := get_global_transform() * local_position
	for node in skill_nodes.values():
		if is_instance_valid(node) and node.get_global_rect().has_point(global_position):
			return true
	return false

func _can_start_drag(local_position: Vector2) -> bool:
	var global_position := get_global_transform() * local_position
	if details_panel and details_panel.contains_global_point(global_position):
		return false
	var hovered_control := get_viewport().gui_get_hovered_control()
	if hovered_control and hovered_control != self and not is_ancestor_of(hovered_control):
		return false
	return not _is_over_skill(local_position)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_stop_dragging()
		return
	# Keyboard navigation is checked directly so the addon does not mutate the
	# host project's InputMap or depend on project-specific action names.
	var direction := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	if direction.length_squared() > 0.0:
		pan += direction * 600.0 * delta
		_center_canvas()

func _stop_dragging() -> void:
	dragging = false
	drag_button = -1

func _zoom_at(screen_position: Vector2, delta: float) -> void:
	var old_zoom := zoom
	var world_position := (screen_position - (size * 0.5 + pan)) / old_zoom
	zoom = clampf(zoom + delta, 0.25, 2.0)
	pan = screen_position - size * 0.5 - world_position * zoom
	_center_canvas()

func center_origin() -> void:
	pan = Vector2.ZERO
	_center_canvas()

func get_level_for_skill(skill_id: String) -> int:
	return progression.get_level(skill_id) if progression else 0

func get_currency(currency_key: String) -> int:
	return progression.get_currency(currency_key) if progression else 0

func set_currency(currency_key: String, amount: int) -> bool:
	return progression.set_currency(currency_key, amount) if progression else false

func add_currency(currency_key: String, amount: int) -> bool:
	return progression.add_currency(currency_key, amount) if progression else false

func can_afford(currency_key: String, amount: int) -> bool:
	return progression.can_afford(currency_key, amount) if progression else false

func spend_currency(currency_key: String, amount: int) -> bool:
	return progression.spend_currency(currency_key, amount) if progression else false

func get_value(key: String, fallback: Variant = null) -> Variant:
	return progression.get_value(key, fallback) if progression else fallback

func set_value(key: String, value: Variant) -> bool:
	return progression.set_value(key, value) if progression else false

func export_state() -> Dictionary:
	return progression.export_state() if progression else {}

func import_state(snapshot: Dictionary) -> bool:
	return progression.import_state(snapshot) if progression else false

func _on_storage_changed(changed_tree_id: String, _snapshot: Dictionary) -> void:
	if skill_tree_data and changed_tree_id == skill_tree_data.tree_id:
		_refresh()
		if details_panel and details_panel.visible:
			details_panel.refresh()

func _on_currency_changed(_currency_key: String, _amount: int) -> void:
	_refresh_currency_display()

func _build_currency_display() -> void:
	if currency_display:
		currency_display.add_theme_constant_override("separation", 6)

func _refresh_currency_display() -> void:
	if not currency_display or not skill_tree_data or not skill_tree:
		return
	for child in currency_display.get_children():
		child.queue_free()
	for currency in skill_tree_data.currencies:
		if not currency:
			continue
		var row := currency_row_scene.instantiate() as Control
		if not row:
			continue
		currency_display.add_child(row)
		var icon := row.get_node_or_null("Icon") as TextureRect
		# Currency rows are user-editable scenes; both text fields are RichTextLabel
		# so projects can render icons/BBCode consistently with skill costs.
		var short_name := row.get_node_or_null("ShortName") as RichTextLabel
		var amount := row.get_node_or_null("Amount") as RichTextLabel
		var key := str(currency.get("key"))
		var locale := TranslationServer.get_locale().get_slice("_", 0).to_lower()
		var short := str((currency.get("short_translations") as Dictionary).get(locale, key))
		if icon:
			icon.texture = currency.get("icon") as Texture2D
			icon.visible = icon.texture != null
		if short_name:
			short_name.text = short
			# The Icon node exists even when no texture was configured; the
			# abbreviation must depend on the actual texture, not node presence.
			short_name.visible = icon == null or icon.texture == null
		if amount:
			amount.text = str(skill_tree.get_currency(key))

func _show_reset_confirmation() -> void:
	if not reset_panel or not skill_tree:
		return
	var summary: Dictionary = skill_tree.get_progression_reset_preview()
	reset_panel.present(tr("RESET_PROGRESSION_TITLE"), tr("RESET_PROGRESSION_MESSAGE"), summary, tr("YOU_WILL_RECEIVE"), tr("CANCEL"), tr("RESET_PROGRESSION"))

func _confirm_progression_reset() -> void:
	if skill_tree:
		skill_tree.reset_progression_with_refund()
	if reset_panel:
		reset_panel.hide()

func _connection_color(state: String) -> Color:
	if not skill_tree_data:
		return Color.WHITE
	if state == progression.STATE_AVAILABLE:
		return skill_tree_data.get_state_color("available")
	if state in [progression.STATE_LOCKED, progression.STATE_NOT_ENOUGH_CURRENCY]:
		return skill_tree_data.get_state_color("unavailable")
	if state == progression.STATE_MAX_LEVEL:
		return skill_tree_data.get_state_color("max_level")
	return Color.WHITE

func _on_skill_activated(skill_id: String) -> void:
	if interaction_mode != InteractionMode.DETAILS_PANEL:
		return
	var was_open: bool = details_panel != null and details_panel.visible
	var changed_skill: bool = selected_skill_id != skill_id
	selected_skill_id = skill_id
	_open_details_panel(was_open, changed_skill)

func _on_details_action_requested(skill_id: String) -> void:
	if not progression:
		return
	if progression.get_level(skill_id) >= skill_tree_data.get_skill(skill_id).max_level and progression.has_toggle_effects(skill_id):
		progression.toggle_skill(skill_id)
	else:
		progression.purchase_skill(skill_id)
	_refresh()
	if details_panel and details_panel.visible:
		details_panel.refresh()

func _open_details_panel(was_open := false, changed_skill := false) -> void:
	if not details_panel or selected_skill_id.is_empty() or not progression:
		return
	var skill := skill_tree_data.get_skill(selected_skill_id)
	if not skill:
		return
	var is_landscape := size.x >= size.y
	panel_side = _get_details_panel_side()
	details_panel.present(skill, progression, is_landscape, panel_side, not was_open)
	if was_open and changed_skill:
		details_panel.play_bounce()

func _close_details_panel(immediate := false) -> void:
	selected_skill_id = ""
	if details_panel:
		details_panel.close_panel(immediate)

func _queue_details_layout() -> void:
	if panel_layout_queued:
		return
	panel_layout_queued = true
	call_deferred("_apply_queued_details_layout")

func _apply_queued_details_layout() -> void:
	panel_layout_queued = false
	if details_panel and details_panel.visible and not selected_skill_id.is_empty():
		_relayout_details_panel()

func _relayout_details_panel() -> void:
	if not details_panel or selected_skill_id.is_empty():
		return
	panel_side = _get_details_panel_side()
	details_panel.relayout(size.x >= size.y, panel_side)

func _get_details_panel_side() -> int:
	var node := skill_nodes.get(selected_skill_id) as Control
	var node_center_x := corner.position.x + (node.position.x + node.size.x * 0.5) * zoom if node else size.x * 0.5
	return DetailsPanelSide.RIGHT if node_center_x <= size.x * 0.5 else DetailsPanelSide.LEFT

func _close_details_if_outside(local_position: Vector2) -> bool:
	if not details_panel or not details_panel.visible:
		return false
	var global_position := get_global_transform() * local_position
	if details_panel.contains_global_point(global_position) or _is_over_skill(local_position):
		return false
	_close_details_panel()
	return true
