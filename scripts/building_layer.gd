extends TileMapLayer

#Do we really have to update money and ui every tick
var tick_timer = 0
var tick_scaler = 0.1

const BUILDING_COST_TEMPLATE = preload("res://scenes/building_cost_template.tscn")


@export var planetIndex: int = -1
var selected_tile: String = "housing"

func toast(message: String, time = 3.0):
	%ToastMessage.text = message
	var new_toast = %Toast.duplicate()
	%Toast.get_parent().add_child(new_toast)
	var tween = new_toast.create_tween()
	new_toast.offset_transform_position_ratio = Vector2(0, -1)
	tween.set_trans(Tween.TRANS_SPRING)
	tween.tween_property(new_toast, "offset_transform_position_ratio", Vector2(0, 0), 0.5)
	tween.tween_property(new_toast, "offset_transform_position_ratio", Vector2(0, -1), 0.5)
	tween.tween_callback(new_toast.queue_free.bind())
	await tween.step_finished
	tween.pause()
	await get_tree().create_timer(time).timeout
	tween.play()

func _unhandled_input(event: InputEvent) -> void:
	var planet = Global.planets[planetIndex]
	var tile_coord = local_to_map(to_local(get_global_mouse_position()))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tileIndex = Global.tiles.find_custom(func find(t: Global.Tile): return t.id == selected_tile)
		var tile = Global.tiles[tileIndex]
		
		if get_cell_source_id(tile_coord) != -1:
			toast("Tile occupied")
			return
		
		var enoughItems = true
		
		# check items
		var i = 0
		while i < tile.recipe.size():
			var amount = tile.recipe[i]
			var item = tile.recipe[i+1]
			
			if ((Global.money if item == "money" else planet.resources[item]) < amount):
				toast("Not enough %s" % [item])
				enoughItems = false
			i += 2
		if not enoughItems: return
		i=0
		# remove items
		while i < tile.recipe.size():
			var amount = tile.recipe[i]
			var item = tile.recipe[i+1]
			
			if item == "money":
				Global.money -= amount
			else:
				planet.resources[item] -= amount
			i += 2
		
		
		set_cell(tile_coord,Global.tileSourceArray.find(selected_tile), Vector2(0, 0))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var tileIndex = Global.tiles.find_custom(func find(t: Global.Tile): return t.sprite == get_cell_source_id(tile_coord))
		if tileIndex != -1: 
			var tile: Global.Tile = Global.tiles[tileIndex]
			var i = 0
			while i < tile.recipe.size():
				var amount = tile.recipe[i]
				var item = tile.recipe[i+1]
				
				if item == "money":
					Global.money += amount
				else:
					planet.resources[item] += amount
				i += 2
			set_cell(tile_coord)


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
	var tile: Global.Tile = Global.tiles[Global.tiles.find_custom(func find(t: Global.Tile): return t.id == id)]
	var buttons: Array[Node] = %Hotbar.get_children()
	var tween = create_tween()
	tween.set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	for button in buttons:
		if button is not TextureButton: continue
		if button.name == id:
			tween.tween_property(button as TextureButton, "offset_transform_position_ratio", Vector2(0, -0.3), 0.5)
		else:
			tween.tween_property(button as TextureButton, "offset_transform_position_ratio", Vector2(0, 0), 0.5)
	
	%BuildingTitle.text = tile.name
	%BuildingDesc.text = tile.desc
	
	for child in %BuildingCosts.get_children():
		child.queue_free()
	
	var i = 0
	while i < tile.recipe.size():
		var amount = tile.recipe[i]
		var item = tile.recipe[i+1]
		var new_cost_row = BUILDING_COST_TEMPLATE.instantiate()
		new_cost_row.item = item
		new_cost_row.amount = amount
		%BuildingCosts.add_child(new_cost_row)
		i += 2
	selected_tile=id
	
