extends Node

var money = 0

var planets: Array[Planet]

class Planet:
	var iron = int(pow(randf_range(2, 9), 2)-4)
	var titanium = randi_range(0, max(80-iron*1.5, 0))
	var rock = 100 - iron - titanium
	var id = ""
	func _init(_id: String):
		id = _id
func _ready():
	planets = [
		Planet.new("1"),
		Planet.new("2"),
		Planet.new("3"),
		Planet.new("4"),
		Planet.new("5"),
		Planet.new("6"),
		Planet.new("7"),
		Planet.new("8"),
		Planet.new("9"),
		Planet.new("10"),
	]
	for p in planets:
		print(p.id, " Iron:", p.iron, " Titanium:", p.titanium, " Rock:", p.rock)
	
