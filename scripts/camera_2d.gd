extends Camera2D

@export var min_zoom: float = 0.2
@export var max_zoom: float = 3.0
@export var zoom_step: float = 0.2

var is_panning: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_zoom = clamp(zoom.x + zoom_step, min_zoom, max_zoom)
			zoom_mouse(new_zoom)
			zoom = Vector2(new_zoom, new_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_zoom = clamp(zoom.x - zoom_step, min_zoom, max_zoom)
			zoom_mouse(new_zoom)
			zoom = Vector2(new_zoom, new_zoom)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			is_panning = false
	elif event is InputEventMouseMotion and is_panning:
		offset -= event.relative / zoom


func zoom_mouse(new_zoom: float) -> void:
	var mouse_pos = get_global_mouse_position()
	offset = mouse_pos - (mouse_pos - offset) * (zoom / Vector2(new_zoom, new_zoom))
