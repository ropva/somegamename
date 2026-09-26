extends TileMapLayer

#Do we really have to update money and ui every tick
var tick_timer = 0
var tick_scaler = 0.1


@export var planetIndex: int = -1
var selected_tile: String = "housing"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tile_coord = local_to_map(to_local(event.position))		
		set_cell(tile_coord,Global.tileSourceArray.find(selected_tile), Vector2(0, 0))

func _ready() -> void:
	for tile in Global.tiles:
		var new_button: TextureButton = %TileButton.duplicate()
		new_button.visible = true
		new_button.texture_normal = load(tile.sprite_path)
		new_button.name=tile.id
		%Hotbar.add_child(new_button)
		new_button.pressed.connect(
			func button_pressed(): _on_tile_button_selected(tile.id)
		)
	#idk what to do with the original one after this
	%TileButton.queue_free()
	_on_tile_button_selected("housing")
	
func _physics_process(delta: float) -> void:
	
	var planet = Global.planets[planetIndex]
	#Do we really have to update money and ui every tick
	tick_timer=tick_timer+delta
	
	#building output
	if(tick_scaler<tick_timer):
		tick_timer=tick_timer-tick_scaler
		var cells = get_used_cells()
		for cell in cells:
			# this relies on declarations in global.gd matching the actual TileSet
			var tileIndex = Global.tiles.find_custom(func find(t: Global.Tile): return t.sprite == get_cell_source_id(cell))
			if tileIndex == -1: continue
			var tile: Global.Tile = Global.tiles[tileIndex]
			if(tile.id == "open_pit_mine"):
				planet.resources.steel=planet.resources.steel+1*tick_scaler*(planet.iron / 100.0)
				planet.resources.titanium=planet.resources.titanium+1*tick_scaler*(planet.titanium / 100.0)
			elif(tile.id == "solar_plant"):
				planet.resources.electricity=planet.resources.electricity+1*tick_scaler
	# update ui
	%MoneyLabel.text = str(int(Global.money))
	%PopLabel.text = str(int(planet.resources.people))
	%RobotLabel.text = str(int(planet.resources.robots))
	%SteelLabel.text = str(int(planet.resources.steel))
	%TitaniumLabel.text = str(int(planet.resources.titanium))
	%ElectricityLabel.text = str(int(planet.resources.electricity))
func _on_tile_button_selected(id) -> void:
	var buttons: Array[Node] = %Hotbar.get_children()
	var tween = create_tween()
	tween.set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	for button in buttons:
		if button is not TextureButton: continue
		if button.name == id:
			tween.tween_property(button as TextureButton, "offset_transform_position_ratio", Vector2(0, -0.3), 0.5)
		else:
			tween.tween_property(button as TextureButton, "offset_transform_position_ratio", Vector2(0, 0), 0.5)
	selected_tile=id
