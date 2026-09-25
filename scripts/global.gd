extends Node

var money = 0

var planets: Array[Planet]
var selected_planet: int = -1


const IRON_COLOR = Color(1.0, 0.353, 0.0, 1.0)
const TITANIUM_COLOR=Color(0.0, 0.0, 0.0, 1.0)
const ROCK_COLOR = Color(0.741, 0.706, 0.753, 1.0)

func generate_planet_pos():
	while true:
		var pos = Vector2(randf_range(0.1, 0.9), randf_range(0.1, 0.9))
		if planets.all(
			func planet_dist(e: Planet):
				return e.pos.distance_squared_to(pos) > 0.015
		):
			return pos

class Planet:
	var iron = max(int(pow(randf_range(2, 10), 2)-10), 0)
	var titanium = randi_range(0, max(80-iron*1.7, 0))
	var rock = 100 - iron - titanium
	var color = lerp(ROCK_COLOR, IRON_COLOR, iron / 100.0) if iron > titanium else lerp(ROCK_COLOR, TITANIUM_COLOR, titanium / 100.0)
	var size = randi_range(30, 80)
	var pos: Vector2 = Global.generate_planet_pos()
	var resources = {
		titanium = 0,
		steel = 0,
		electricity = 0,
		robots = 0,
		people = 10
	}
	var layer: CanvasLayer
	var container: SubViewportContainer
	var id = ""
	func _init(_id: String):
		id = _id
func _ready():
	planets.push_back(Planet.new("1"))
	planets.push_back(Planet.new("2"))
	planets.push_back(Planet.new("3"))
	planets.push_back(Planet.new("4"))
	planets.push_back(Planet.new("5"))
	planets.push_back(Planet.new("6"))
	planets.push_back(Planet.new("7"))
	planets.push_back(Planet.new("8"))
	planets.push_back(Planet.new("9"))
	planets.push_back(Planet.new("7"))
	

class Tile:
	var id = ""
	var sprite = ""
	func _init(_id: String, _sprite: String):
		id = _id
		sprite = _sprite

var tiles = [
	Tile.new("solar_plant", "asset_solar_plant_1x")
]
