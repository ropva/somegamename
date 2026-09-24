extends Node2D

var PlanetScene = load("res://scenes/planet.tscn")

func hovered_planet(screen_position: Vector2) -> int:
	return Global.planets.find_custom(
		func f(p: Global.Planet):
			var pos = p.pos * get_viewport_rect().size
			return screen_position.distance_squared_to(pos) <= pow(p.size, 2)
	)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var planet = hovered_planet(event.position)
		Global.selected_planet = planet
		get_tree().change_scene_to_file("res://scenes/planet.tscn")
	if event is InputEventMouseMotion:
		var planetIndex = hovered_planet(event.position)
		%PlanetTooltip.visible = planetIndex != -1
		if (planetIndex != -1):
			var planet = Global.planets[planetIndex]
			%PlanetTooltip.position = event.position
			%PlanetTooltipTitle.text = "Planet " + planet.id
			if (planet.titanium > planet.iron):
				%PlanetTooltipDesc.text = "Titanium: {0}%\nIron: {1}%".format([ planet.titanium, planet.iron])
			else:
				%PlanetTooltipDesc.text = "Iron: {0}%\nTitanium: {1}%".format([ planet.iron, planet.titanium])
				
func _ready():
	draw_planets()
	if (Global.selected_planet >= 0):
		var planet: Global.Planet = Global.planets[Global.selected_planet]
		var planetScene: Node2D = PlanetScene.instantiate()
		var screen_size: Vector2 = get_viewport().get_visible_rect().size

		var vp := SubViewport.new()
		vp.add_child(PlanetScene.instantiate())

		var container := SubViewportContainer.new()
		container.stretch = true
		container.size = screen_size
		container.pivot_offset = planet.pos * get_viewport_rect().size
		container.scale = Vector2.ONE
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(vp)

		var layer := CanvasLayer.new()
		layer.layer = 100
		layer.add_child(container)
		get_tree().root.add_child(layer)

		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(container, "scale", Vector2.ONE * 0.0001, 0.5)
		await tween.finished
		tween.tween_callback(vp.queue_free.bind())

func draw_planets():
	var screen_size = get_viewport_rect().size
	for p in Global.planets:
		var new_planet: Sprite2D = %Planet.duplicate()
		new_planet.visible = true
		new_planet.modulate = p.color
		new_planet.scale = Vector2(p.size / new_planet.texture.get_size().x * 2, p.size / new_planet.texture.get_size().y * 2)
		new_planet.position = p.pos*screen_size
		add_child(new_planet)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
