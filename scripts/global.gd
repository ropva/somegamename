extends Node

var money = 0

class Tile:
	var id = ""
	var sprite = ""
	func _init(_id: String, _sprite: String):
		id = _id
		sprite = _sprite

var tiles = [
	Tile.new("solar_plant", "asset_solar_plant_1x")
]
