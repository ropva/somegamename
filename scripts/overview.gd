extends Node2D


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
