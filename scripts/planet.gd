extends Node2D

signal on_back
signal on_tech_tree

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
	_on_tile_update()

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
	var tile_coord = %BuildingLayer.local_to_map(%BuildingLayer.to_local(get_global_mouse_position()))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tileIndex = Global.tiles.find_custom(func find(t: Global.Tile): return t.id == selected_tile)
		var tile = Global.tiles[tileIndex]
		
		if %BuildingLayer.get_cell_source_id(tile_coord) != -1:
			toast("Tile occupied")
			return
		
		var enoughItems = true
		
		# check items
		var i = 0
		while i < tile.recipe.size():
			var amount = tile.recipe[i]
			var item = tile.recipe[i+1]
			if (get_item_var(item) < amount):
				toast("Not enough %s" % [item])
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
	if item == "money":
		return Global.money
	elif item == "science":
		return Global.science
	else:
		return planet.resources[item]

func get_item_storage(item):
	var planet = Global.planets[planetIndex]
	if item == "money":
		return -1
	elif item == "science":
		return -1
	else:
		return planet.storage[item]

func set_item_var(item, value):
	var planet = Global.planets[planetIndex]
	if item == "money":
		Global.money = value
	elif item == "science":
		Global.science = value
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
			planet.storage.electricity += Global.BATTERY_BASE_CAPACITY * Global.battery_capacity_mult

	%Robots.visible = Global.robots_unlocked
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
			if(tile.id == "housing"):
				handle_resource("people", 0.2)
			elif(tile.id == "open_pit_mine"):
				handle_resource("steel", planet.iron / 100.0)
				handle_resource("titanium", planet.titanium / 100.0)
			elif(tile.id == "solar_plant"):
				handle_resource("electricity", planet.solar / 100.0)
	# update ui
	%MoneyLabel.text = str(int(Global.money))
	%ScienceLabel.text = str(int(Global.science))
	%PopLabel.text = str(int(planet.resources.people))
	%PopJobsLabel.text = str(int(0))
	%FreeHousingLabel.text = str(int(planet.storage.people))
	%RobotsLabel.text = str(int(planet.resources.robots))
	%RobotsJobsLabel.text = str(int(0))
	%SteelLabel.text = str(int(planet.resources.steel))
	%TitaniumLabel.text = str(int(planet.resources.titanium))
	%ElectricityLabel.text = str(int(planet.resources.electricity))
	%ElectricityStorageLabel.text = str(int(planet.storage.electricity))

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

	
func _on_back_button_pressed() -> void:
	on_back.emit()


func _on_tech_tree_button_pressed() -> void:
	on_tech_tree.emit()
