extends Camera2D

@export var min_zoom: float = 0.2
@export var max_zoom: float = 3.0
@export var zoom_step: float = 0.2

var is_panning: bool = false

var target_zoom = 1.0

func _ready() -> void:
	target_zoom = zoom.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clamp(target_zoom + zoom_step, min_zoom, max_zoom)
			zoom_mouse()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clamp(target_zoom - zoom_step, min_zoom, max_zoom)
			zoom_mouse()
	elif event is InputEventMouseMotion and is_panning:
		position -= event.relative / zoom

func _process(delta: float) -> void:
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), 15 * delta)

func zoom_mouse() -> void:
	var mouse_pos = get_global_mouse_position()
	position = mouse_pos - (mouse_pos - position) * (zoom / Vector2(target_zoom, target_zoom))
