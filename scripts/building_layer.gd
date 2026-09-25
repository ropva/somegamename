extends TileMapLayer

#Do we really have to update money and ui every tick
var tick_timer = 0
var tick_scaler = 0.001

@export var planetIndex: int = -1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tile_coord = local_to_map(to_local(event.position))
		print(tile_coord)
		set_cell(tile_coord,1, Vector2(0, 0))
		
func _physics_process(delta: float) -> void:
	
	var planet = Global.planets[planetIndex]
	#Do we really have to update money and ui every tick
	tick_timer=tick_timer+delta
	
	#building output
	if(tick_scaler<tick_timer):
		tick_timer=tick_timer-tick_scaler
		var cells = get_used_cells()
		for cell in cells:
			if(get_cell_source_id(cell)==2):
				planet.resources.steel=planet.resources.steel+1*tick_scaler
			elif(get_cell_source_id(cell)==3):
				planet.resources.electricity=planet.resources.electricity+1*tick_scaler
	# update ui
	%MoneyLabel.text = str(int(Global.money))
	%PopLabel.text = str(int(planet.resources.people))
	%RobotLabel.text = str(int(planet.resources.robots))
	%SteelLabel.text = str(int(planet.resources.titanium))
	%TitaniumLabel.text = str(int(planet.resources.steel))
	%ElectricityLabel.text = str(int(planet.resources.electricity))
