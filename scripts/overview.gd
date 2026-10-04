extends Node2D

var PlanetScene = load("res://scenes/planet.tscn")
var _tree_view: YggdrasilTreeView

func hovered_planet(screen_position: Vector2) -> int:
	var screen_size = get_viewport_rect().size
	return Global.planets.find_custom(
		func f(p: Global.Planet):
			var pos = p.pos * screen_size
			return p.mini_node.visible and screen_position.distance_squared_to(pos) <= pow(p.size * max(screen_size.x, screen_size.y), 2)
	)

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

func close_planet(container: SubViewportContainer, layer: CanvasLayer): 
	Global.selected_planet = -1
	visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(container, "scale", Vector2.ONE * 0.0001, 0.3)
	tween.tween_callback(func(): layer.visible = false)
	await tween.finished

func open_planet(index: int, do_tween = true):
	var planet = Global.planets[index]
	
	if do_tween:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func(): planet.layer.visible = true)
		tween.tween_property(planet.container, "scale", Vector2.ONE, 0.3)
		await tween.finished
		visible = false
		%PlanetTooltip.visible = false
	else:
		planet.container.scale = Vector2.ONE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var planetIndex = hovered_planet(event.position)
		if planetIndex == -1 or Global.selected_planet != -1:
			return
		Global.selected_planet = planetIndex
		open_planet(planetIndex)
	
	if event is InputEventMouseMotion:
		var planetIndex = hovered_planet(event.position)
		%PlanetTooltip.visible = planetIndex != -1
		if (planetIndex != -1):
			var planet = Global.planets[planetIndex]
			%PlanetTooltip.position = event.position
			%PlanetTooltipTitle.text = planet.name
			if (planet.titanium > planet.iron):
				%PlanetTooltipDesc.text = "Titanium: {0}%\nIron: {1}%\nSolar: {2}%".format([ planet.titanium, planet.iron, planet.solar])
			else:
				%PlanetTooltipDesc.text = "Iron: {0}%\nTitanium: {1}%\nSolar: {2}%".format([ planet.iron, planet.titanium, planet.solar])
				
func _ready():
	draw_planets()
	get_viewport().size_changed.connect(
		func resize():
			update_planets()
	) 
	update_planets()
	
	Global.prop_update.connect(_on_global_update.bind())
	_on_global_update()
	
	if Global.selected_planet != -1:
		open_planet(Global.selected_planet, false)
		
	var builder: YggdrasilBuilder = YggdrasilBuilder.new(Global.tech_tree)
	builder.set_parent(%TechTreeContainer)

	# These kinda have to be hardcoded
	builder.node_allocated_callback(
		func allocated(n):
			if n.name == "Node_2":
				# Improved battery
				Global.battery_capacity_mult = 1.25
			elif n.name == "Node_3":
				# Robot unlock
				Global.robots_unlocked = true
				Global.tiles.push_back(Global.ROBOT_PLANT)
			elif n.name == "Node_4":
				# Demolition
				Global.demolition_loss = 1.0
			elif n.name == "Node_11":
				# Better demolition
				Global.demolition_loss = 0.5
			elif n.name == "Node_12":
				# Better demolition
				Global.demolition_loss = 0.25
			elif n.name == "Node_13":
				# Better demolition
				Global.demolition_loss = 0.1
			elif n.name == "Node_14":
				# Better demolition
				Global.demolition_loss = 0.0
			elif n.name == "Node_8":
				# Red science
				Global.electronics_unlocked = true
			elif n.name == "Node_9":
				# Red science
				Global.tiles.push_back(Global.ELECTRONICS_PLANT)
			elif n.name == "Node_15":
				# Red science
				Global.production_multiplier.electronics_plant = 2
			elif n.name == "Node_11":
				# Blue science
				Global.tiles.push_back(Global.BLUE_LAB_TILE)
			elif n.name == "Node_7":
				# Blue science
				Global.tiles.push_back(Global.RED_LAB_TILE)
			elif n.name == "Node_18":
				Global.building_cost_multiplier.open_pit_mine = 0.95 
			elif n.name == "Node_21":
				Global.building_cost_multiplier.open_pit_mine = 0.85
			elif n.name == "Node_22":
				Global.building_cost_multiplier.open_pit_mine = 0.75
			elif n.name == "Node_23":
				Global.production_multiplier.open_pit_mine = 10.5
			elif n.name == "Node_25":
				Global.production_multiplier.open_pit_mine = 11.5 #starts at 10 for some reason
			elif n.name == "Node_26":
				Global.battery_capacity_mult = 1.5
			elif n.name == "Node_28":
				Global.tiles.push_back(Global.WIND_FARM)
			elif n.name == "Node_29":
				Global.production_multiplier.solar_plant = 1.15
			elif n.name == "Node_30":
				Global.production_multiplier.solar_plant = 1.1
			elif n.name == "Node_31":
				Global.production_multiplier.solar_plant = 1.25
			elif n.name == "Node_32":
				Global.building_cost_multiplier.solar_plant = 0.90
			elif n.name == "Node_33":
				Global.tiles.push_back(Global.GEOTHERMAL_PLANT)
			elif n.name == "Node_35":
				Global.production_multiplier.wind_farm = 1.10
			elif n.name == "Node_36":
				Global.production_multiplier.wind_farm = 1.20
			elif n.name == "Node_37":
				Global.production_multiplier.geothermal_plant = 1.05
			elif n.name == "Node_38":
				Global.production_multiplier.geothermal_plant = 1.15
			elif n.name == "Node_1":
				# Root node, nothing to do
				pass
			else:
				print(n.name, ": No function defined")
			Global.prop_update.emit()
	)
	builder.allocation_check_callback(
		func alloc(n: YggdrasilNodeButton):
			var science_green = n.attributes.cost_green[0]
			var science_red = n.attributes.cost_red[0]
			var science_blue = n.attributes.cost_blue[0]
			
			if Global.science_green < science_green:
				toast("Not enough green science")
			elif Global.science_red < science_red:
				toast("Not enough red science")
			elif Global.science_blue < science_blue:
				toast("Not enough blue science")
			else: 
				Global.science_green -= science_green
				Global.science_red -= science_red
				Global.science_blue -= science_blue
				return true
			return false
	)
	builder.deallocation_check_callback(
		func dealloc():
			return false
	)
	_tree_view = builder.build()
func update_planets():
	var screen_size = get_viewport_rect().size
	var i = 0
	for p in Global.planets:
		var mini_node: Sprite2D = p.mini_node
		var container: SubViewportContainer = p.container
		mini_node.scale = Vector2(
			(p.size * max(screen_size.x, screen_size.y)) / mini_node.texture.get_size().x * 2, 
			(p.size * max(screen_size.x, screen_size.y)) / mini_node.texture.get_size().y * 2
		)
		mini_node.position = p.pos*screen_size
		
		container.size = screen_size + Vector2(32,32)
		mini_node.visible = i < Global.planets_unlocked
		i += 1

func draw_planets():
	var screen_size = get_viewport_rect().size
	var idx = 0
	for p in Global.planets:
		var new_planet: Sprite2D = %Planet.duplicate()
		new_planet.visible = true
		new_planet.modulate = p.color
		new_planet.scale = Vector2(
			(p.size * max(screen_size.x, screen_size.y)) / new_planet.texture.get_size().x * 2, 
			(p.size * max(screen_size.x, screen_size.y)) / new_planet.texture.get_size().y * 2
		)
		new_planet.position = p.pos*screen_size
		add_child(new_planet)
		p.mini_node = new_planet
		var planetScene: Node2D = PlanetScene.instantiate()
		
		planetScene.planetIndex = idx

		var vp := SubViewport.new()
		vp.add_child(planetScene)
		

		var container := SubViewportContainer.new()
		container.stretch = true
		container.position = Vector2(-16, -16)
		container.size = screen_size + Vector2(32,32)
		container.pivot_offset = p.pos * get_viewport_rect().size + Vector2(16, 16)
		container.scale = Vector2.ONE * 0.0001
		container.mouse_filter = Control.MOUSE_FILTER_STOP
		container.add_child(vp)

		var layer := CanvasLayer.new()
		layer.layer = 100
		layer.add_child(container)
		add_child(layer)
		
		planetScene.on_back.connect(
			func on_exit():
				close_planet(container, layer)
		)
		planetScene.on_tech_tree.connect(open_tech_tree.bind())
		planetScene.on_store.connect(open_store.bind())
		planetScene.on_toast.connect(toast.bind())
		p.container = container
		p.layer = layer
		idx+=1
		
func _on_global_update():
	%ScienceRed.visible = Global.tiles.find_custom(func find(e): return e.id == Global.RED_LAB_TILE.id) != -1
	%ScienceBlue.visible = Global.tiles.find_custom(func find(e): return e.id == Global.BLUE_LAB_TILE.id) != -1

func _physics_process(delta: float) -> void:
	
	# update ui
	%MoneyLabel.text = str(int(Global.money))
	%GreenScienceLabel.text = str(int(Global.science_green))
	%RedScienceLabel.text = str(int(Global.science_red))
	%BlueScienceLabel.text = str(int(Global.science_blue))
	
func open_tech_tree():
	var screen_size = get_viewport_rect().size
	%TechTree.transform = Transform2D(0, screen_size * Vector2(0,-1))
	%TechTree.visible = true
	var tween = %TechTree.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(%TechTree as CanvasLayer, "transform", Transform2D(0, screen_size * Vector2(0,0)), 1.0)
	
func close_tech_tree():
	var screen_size = get_viewport_rect().size
	var tween = %TechTree.create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(%TechTree as CanvasLayer, "transform", Transform2D(0, screen_size * Vector2(0,-1)), 0.3)
	await tween.finished
	%TechTree.visible = false

func open_store():
	var screen_size = get_viewport_rect().size
	%Store.transform = Transform2D(0, screen_size * Vector2(0,-1))
	%Store.visible = true
	var tween = %Store.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(%Store as CanvasLayer, "transform", Transform2D(0, screen_size * Vector2(0,0)), 1.0)
func close_store():
	var screen_size = get_viewport_rect().size
	var tween = %Store.create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(%Store as CanvasLayer, "transform", Transform2D(0, screen_size * Vector2(0,-1)), 0.3)
	await tween.finished
	%Store.visible = false

func _on_exit_button_pressed() -> void:
	close_tech_tree()


func _on_exit_store_button_pressed() -> void:
	close_store()
