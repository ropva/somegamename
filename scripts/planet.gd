extends Node2D

signal on_back
signal on_tech_tree
signal on_store
signal on_toast

@export var planetIndex: int = -1

var tick_timer = 0
var tick_scaler = 0.5

const BUILDING_COST_TEMPLATE = preload("res://scenes/building_cost_template.tscn")


var selected_tile: String = "housing"


func _ready() -> void:
	
	var planet = Global.planets[planetIndex]
	
	var style = StyleBoxFlat.new()
	style.bg_color = planet.color
	style.border_color = lerp(planet.color, Color.BLACK, 0.5)
	style.border_width_bottom = 16
	style.border_width_top = 16
	style.border_width_left = 16
	style.border_width_right = 16
	
	%Background.add_theme_stylebox_override("panel",style)
	
	%PlanetTitle.text = planet.name
	if (planet.titanium > planet.iron):
		%PlanetDesc.text = "Titanium: {0}%\nIron: {1}%\nSolar: {2}%".format([ planet.titanium, planet.iron, planet.solar])
	else:
		%PlanetDesc.text = "Iron: {0}%\nTitanium: {1}%\nSolar: {2}%".format([ planet.iron, planet.titanium, planet.solar])
	
	Global.prop_update.connect(_on_tile_update.bind())

	_on_tile_button_selected("housing")
	_on_tile_update()

func _unhandled_input(event: InputEvent) -> void:
	var tile_coord = %BuildingLayer.local_to_map(%BuildingLayer.to_local(get_global_mouse_position()))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tileIndex = Global.tiles.find_custom(func find(t: Global.Tile): return t.id == selected_tile)
		var tile = Global.tiles[tileIndex]
		
		if %BuildingLayer.get_cell_source_id(tile_coord) != -1:
			on_toast.emit("Tile occupied")
			return
		
		var enoughItems = true
		
		# check items
		var i = 0
		while i < tile.recipe.size():
			var amount = tile.recipe[i]
			var item = tile.recipe[i+1]
			if (get_item_var(item) < amount):
				on_toast.emit("Not enough %s" % [item])
				enoughItems = false
			i += 2
		if not enoughItems: return
		i=0
		# remove items
		while i < tile.recipe.size():
			var amount = tile.recipe[i]
			var item = tile.recipe[i+1]
			
			set_item_var(item, get_item_var(item) - amount)
			i += 2
		
		
		%BuildingLayer.set_cell(tile_coord,tile.sprite, Vector2(0, 0))
		_on_tile_update()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var tileIndex = Global.tiles.find_custom(func find(t: Global.Tile): return t.sprite == %BuildingLayer.get_cell_source_id(tile_coord))
		if tileIndex != -1: 
			var tile: Global.Tile = Global.tiles[tileIndex]
			var i = 0
			while i < tile.recipe.size():
				var amount = tile.recipe[i]
				var item = tile.recipe[i+1]
				
				set_item_var(item, get_item_var(item) + amount * (1- Global.demolition_loss))
				i += 2
			%BuildingLayer.set_cell(tile_coord)
			_on_tile_update()

func get_item_var(item):
	var planet = Global.planets[planetIndex]
	if item == "money" or item == "science_green" or item == "science_red" or item == "science_blue":
		return Global[item]
	else:
		return planet.resources[item]

func get_item_storage(item):
	var planet = Global.planets[planetIndex]
	if item == "money" or item == "science_green" or item == "science_red" or item == "science_blue":
		return -1
	else:
		return planet.storage[item]

func set_item_var(item, value):
	var planet = Global.planets[planetIndex]
	if item == "money" or item == "science_green" or item == "science_red" or item == "science_blue":
		Global[item] = value
	else:
		planet.resources[item] = value
	
func _on_tile_update():
	var planet = Global.planets[planetIndex]
	for item in planet.storage.keys():
		if (planet.storage[item] != -1): planet.storage[item] = 0
	var cells = %BuildingLayer.get_used_cells()
	for cell in cells:
		# this relies on declarations in global.gd matching the actual TileSet
		var tileIndex = Global.tiles.find_custom(func find(t: Global.Tile): return t.sprite == %BuildingLayer.get_cell_source_id(cell))
		if tileIndex == -1: continue
		var tile: Global.Tile = Global.tiles[tileIndex]
		if(tile.id == "housing"):
			planet.storage.people += Global.HOUSING_BASE_CAPACITY
		elif(tile.id == "battery_bank"):
			planet.storage.energy += Global.BATTERY_BASE_CAPACITY * Global.battery_capacity_mult

	for child in %Hotbar.get_children():
		if child.visible: 
			child.queue_free()
	for tile in Global.tiles:
		var new_button: TextureButton = %TileButton.duplicate()
		new_button.visible = true
		new_button.texture_normal = load(tile.sprite_path)
		new_button.name=tile.id
		%Hotbar.add_child(new_button)
		new_button.pressed.connect(
			func button_pressed(): _on_tile_button_selected(tile.id)
		)
	
	%Robots.visible = Global.robots_unlocked
	%ScienceRed.visible = Global.tiles.find_custom(func find(e): return e.id == Global.RED_LAB_TILE.id) != -1
	%ScienceBlue.visible = Global.tiles.find_custom(func find(e): return e.id == Global.BLUE_LAB_TILE.id) != -1
	
func _physics_process(delta: float) -> void:
	
	var planet = Global.planets[planetIndex]
	#Do we really have to update money and ui every tick
	tick_timer=tick_timer+delta
	
	#building output
	if(tick_scaler<tick_timer):
		tick_timer=tick_timer-tick_scaler
		
		var cells = %BuildingLayer.get_used_cells()
		for cell in cells:
			# this relies on declarations in global.gd matching the actual TileSet
			var tileIndex = Global.tiles.find_custom(func find(t: Global.Tile): return t.sprite == %BuildingLayer.get_cell_source_id(cell))
			if tileIndex == -1: continue
			var tile: Global.Tile = Global.tiles[tileIndex]
			
			# consumption
			var i = 0
			var consumption_successful = true
			while i < tile.consumes.size():
				var amount = tile.consumes[i]
				var item = tile.consumes[i+1]
				if amount > get_item_var(item):
					%OverlayLayer.set_cell(cell, 0, Vector2(0,0))
					consumption_successful = false
				else:
					%OverlayLayer.set_cell(cell)
					handle_resource(item, -amount)
				i += 2
			if not consumption_successful: continue
			# production
			i = 0
			while i < tile.produces.size():
				var amount = tile.produces[i]
				var item = tile.produces[i+1]
				handle_resource(item, amount * tick_scaler * get_building_production_multiplier(tile.id, item))
				i += 2
	# update ui
	%MoneyLabel.text = str(int(Global.money))
	%GreenScienceLabel.text = str(int(Global.science_green))
	%RedScienceLabel.text = str(int(Global.science_red))
	%BlueScienceLabel.text = str(int(Global.science_blue))
	%PopLabel.text = str(int(planet.resources.people))
	%PopJobsLabel.text = str(int(0))
	%FreeHousingLabel.text = str(int(planet.storage.people))
	%RobotsLabel.text = str(int(planet.resources.robots))
	%RobotsJobsLabel.text = str(int(0))
	%SteelLabel.text = str(int(planet.resources.steel))
	%TitaniumLabel.text = str(int(planet.resources.titanium))
	%ElectricityLabel.text = str(int(planet.resources.energy))
	%ElectricityStorageLabel.text = str(int(planet.storage.energy))

func handle_resource(item: String, amount: float):
	set_item_var(item, clamp_resource(get_item_var(item) + amount * tick_scaler, get_item_storage(item)))

func clamp_resource(amount, max_amount):
	if max_amount == -1:
		return amount
	else:
		return min(amount, max_amount)

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
	
	%BuildingJobsContainer.visible = tile.workers != 0
	%BuildingRobot.visible = !tile.human_only
	%BuildingWorkers.text = str(tile.workers)
	
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
	
	%BuildingRecipeContainer.visible = tile.consumes.size() > 0 or tile.produces.size() > 0
	
	for child in %BuildingConsumes.get_children():
		child.queue_free()
	
	i = 0
	while i < tile.consumes.size():
		var amount = tile.consumes[i]
		var item = tile.consumes[i+1]
		var new_cost_row = BUILDING_COST_TEMPLATE.instantiate()
		new_cost_row.item = item
		new_cost_row.amount = amount
		%BuildingConsumes.add_child(new_cost_row)
		i += 2
	
	
	for child in %BuildingProduces.get_children():
		child.queue_free()
	
	i = 0
	while i < tile.produces.size():
		var amount = tile.produces[i]
		var item = tile.produces[i+1]
		var new_cost_row = BUILDING_COST_TEMPLATE.instantiate()
		new_cost_row.item = item
		new_cost_row.amount = amount * get_building_production_multiplier(tile.id, item)
		%BuildingProduces.add_child(new_cost_row)
		i += 2
	
	selected_tile=id

func get_building_production_multiplier(building: String, item: String):
	var global_mult = Global.production_multiplier[building]
	var planet = Global.planets[planetIndex]
	if(building == "housing"):
		return global_mult * 0.2
	elif(building == "open_pit_mine"):
		if item == "titanium":
			return global_mult * planet.titanium / 100.0
		else:
			return global_mult * planet.iron / 100.0
	elif(building == "solar_plant"):
		return global_mult * planet.solar / 100.0
	else:
		return global_mult
	
func _on_back_button_pressed() -> void:
	on_back.emit()
	on_back.emit()


func _on_tech_tree_button_pressed() -> void:
	on_tech_tree.emit()


func _on_store_button_pressed() -> void:
	on_store.emit()
