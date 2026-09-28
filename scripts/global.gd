extends Node

var money = 100
var science = 0

var planets: Array[Planet]
var selected_planet: int = -1

# upgrades
var planets_unlocked = 1
var demolition_loss = 0.2

# config
const TOTAL_PLANETS = 10.0
const PLANET_SPACING = -0.01

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
	var i = 0
	while i < TOTAL_PLANETS:
		var pos = Vector2(randf(), randf())
		if planets.all(
			func planet_dist(e: Planet):
				return e.pos.distance_squared_to(pos) > e.size + PLANET_SPACING and pos.x > e.size + PLANET_SPACING and pos.x < 1- e.size - PLANET_SPACING and pos.y > e.size + PLANET_SPACING and pos.y < 1- e.size - PLANET_SPACING 
		):
			return pos
		i += 1
	return Vector2(0.5,0.5)

class Planet:
	var iron = min(max(int(pow(randf_range(3, 10), 2) + randf_range(-40, 15)), 0), 100)
	var titanium = randi_range(0, max(80-iron*1.7, 0))
	var color = lerp(ROCK_COLOR, IRON_COLOR, iron / 100.0) if iron > titanium else lerp(ROCK_COLOR, TITANIUM_COLOR, titanium / 100.0)
	var size = randf_range(0.1/TOTAL_PLANETS+0.005, 0.5/TOTAL_PLANETS+0.01)
	var solar = min(randi_range(0, 110), 100)
	var pos: Vector2 = Global.generate_planet_pos()
	var resources = {
		titanium = 10,
		steel = 20,
		electricity = 0,
		robots = 0,
		people = 10
	}
	var mini: Sprite2D
	var layer: CanvasLayer
	var container: SubViewportContainer
	var id = ""
	var name = ""
	func _init(n_id: String, n_name: String):
		id = n_id
		name = n_name

func _ready():
	var i: int = 0
	var best_planet = 0
	var best_score = 0
	print(planets.size())
	
	seed("TESTING".hash())
	
	
	while i < TOTAL_PLANETS:
		var new_planet = Planet.new(str(i), generate_planet_name(i))
		planets.push_back(new_planet)
		
		var score = (100-abs(new_planet.iron - new_planet.titanium)) * (max(new_planet.solar,50)/4) * (max(new_planet.titanium + new_planet.iron,40)/2)
		if score > best_score:
			best_score = score
			best_planet = i
		
		i += 1
	
	selected_planet = best_planet
	
	var building_tile_set: TileSet=load("res://res/building_tile_set.tres")
	for src in building_tile_set.get_source_count()+1:
		if(building_tile_set.has_source(src)):
			tileSourceArray.resize(tileSourceArray.size()+1)
			tileSourceArray[src]=building_tile_set.get_source(src).resource_name


class Tile:
	var id: String
	var name: String
	var desc: String
	var sprite: int
	var sprite_path: String
	var recipe: Array
	func _init(_id: String,_name: String,_desc: String, _sprite: int, _sprite_path: String, _recipe: Array):
		id = _id
		name = _name
		desc = _desc
		sprite = _sprite
		sprite_path = _sprite_path
		recipe = _recipe

var tiles: Array[Tile] = [
	Tile.new("solar_plant", "Solar plant", 
	"The most basic way of producing power.", 
	2, "res://res/asset_solar_plant_0.5x.png", 
	[10, "steel", 3, "titanium"]),
	Tile.new("housing", "Housing", 
	"Basically storage for humans.", 
	0, "res://res/asset_housing_0.5x.png", 
	[10, "steel", 20, "money"]),
	Tile.new("open_pit_mine", "Open pit mine", 
	"Basic mine. Generated resource is determined by planet properties",
	 1, "res://res/asset_open_pit_mine_0.5x.png", 
	[10, "steel"])
]

	
