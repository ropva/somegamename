extends TileMapLayer

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tile_coord = %BuildingLayer.local_to_map(event.position)
		%BuildingLayer.set_cell(tile_coord,0,Vector2i(0,0))
		
		
func _physics_process(delta: float) -> void:
	var cells = %BuildingLayer.get_used_cells()
	for cell in cells:
		print(%BuildingLayer.get_cell_source_id(cell))
