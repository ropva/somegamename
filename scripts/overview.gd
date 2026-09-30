extends Node2D

var PlanetScene = load("res://scenes/planet.tscn")
var _tree_view: YggdrasilTreeView

func hovered_planet(screen_position: Vector2) -> int:
	var screen_size = get_viewport_rect().size
	return Global.planets.find_custom(
		func f(p: Global.Planet):
			var pos = p.pos * screen_size
			return screen_position.distance_squared_to(pos) <= pow(p.size * max(screen_size.x, screen_size.y), 2)
	)

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
	if Global.selected_planet != -1:
		open_planet(Global.selected_planet, false)
		
	var builder: YggdrasilBuilder = YggdrasilBuilder.new(Global.tech_tree)
	builder.set_parent(%TechTreeContainer)
	builder.node_created_callback(
		func(n: BaseButton):
			n.pressed.connect(
				func pressed():
					if n.name == "Node_2":
						Global.battery_capacity_mult = 1.25
						Global.prop_update.emit()
						pass
					elif n.name == "Node_3":
						Global.robots_unlocked = true
						Global.prop_update.emit()
						pass
			)
	)
	builder.deallocation_check_callback(
		func dealloc():
			return false
	)
	_tree_view = builder.build()
func update_planets():
	var screen_size = get_viewport_rect().size
	for p in Global.planets:
		var mini_node: Sprite2D = p.mini_node
		var container: SubViewportContainer = p.container
		mini_node.scale = Vector2(
			(p.size * max(screen_size.x, screen_size.y)) / mini_node.texture.get_size().x * 2, 
			(p.size * max(screen_size.x, screen_size.y)) / mini_node.texture.get_size().y * 2
		)
		mini_node.position = p.pos*screen_size
		
		container.size = screen_size + Vector2(32,32)

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
		p.container = container
		p.layer = layer
		idx+=1

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func open_tech_tree():
	%TechTree.visible = true
func close_tech_tree():
	%TechTree.visible = false


func _on_exit_button_pressed() -> void:
	close_tech_tree()
