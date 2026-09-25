extends Node

var money = 0

var planets: Array[Planet]
var selected_planet: int = -1


const IRON_COLOR = Color(0.82, 0.219, 0.0, 1.0)
const TITANIUM_COLOR=Color(0.0, 0.0, 0.0, 1.0)
const ROCK_COLOR = Color(0.741, 0.706, 0.753, 1.0)

const SYLLABLES_START = ["Zul", "Var", "Kry", "Xan", "Bel", "Thra", "Myr", "Oph", "Hex", "Quar"]
const SYLLABLES_MID = ["o", "i", "a", "u", "e", "an", "on", "or"]
const SYLLABLES_END = ["s", "x", "n", "th", "d", "m", "ria", "tium", "vis", "cion"]
const PLANET_IDS = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "G"]
	
var start = SYLLABLES_START[randi() % SYLLABLES_START.size()]
var mid = SYLLABLES_MID[randi() % SYLLABLES_MID.size()]
var end = SYLLABLES_END[randi() % SYLLABLES_END.size()]
var num = randi_range(1, 150)

var system = start + mid + end
var SYSTEM_NAME = "%d %s" % [num, system]

var tileSourceArray = []


func generate_planet_name(i):
	var planet_name = PLANET_IDS[i % PLANET_IDS.size()] + str(i)

	return "%s %s" % [SYSTEM_NAME, planet_name]
	
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
	var name = ""
	func _init(n_id: String, n_name: String):
		id = n_id
		name = n_name

func _ready():
	var i: int = 0
	while i < 10:
		planets.push_back(Planet.new(str(i), generate_planet_name(i)))
		i += 1
		
	var building_tile_set=load("res://res/building_tile_set.tres")
	for src in building_tile_set.get_source_count()+1:
		if(not building_tile_set.get_source(src)==null):
			tileSourceArray.resize(tileSourceArray.size()+1)
			tileSourceArray[src]=building_tile_set.get_source(src).resource_name
# INGREDIENTS
# 0: titanium
# 1: steel
# 2: money


class Tile:
	var id: String
	var name: String
	var sprite: int
	var sprite_path: String
	var recipe: Array[int]
	func _init(_id: String,_name: String, _sprite: int, _sprite_path: String, _recipe: Array[int]):
		id = _id
		name = _name
		sprite = _sprite
		sprite_path = _sprite_path
		recipe = _recipe

var tiles: Array[Tile] = [
	Tile.new("solar_plant", "Solar plant", 3, "res://res/asset_solar_plant_0.5x.png", [10, 1, 3, 0]),
	Tile.new("housing", "Housing", 1, "res://res/asset_housing_0.5x.png", [10, 1, 20, 2]),
	Tile.new("open_pit_mine", "Open pit mine", 1, "res://res/asset_open_pit_mine_0.5x.png", [10, 1, 20, 2])
]

	
