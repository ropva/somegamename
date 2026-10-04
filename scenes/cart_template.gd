extends HBoxContainer

@export var title = ""
@export var price = 0
@export var amount = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"./Label".text = "%s x%d" % [title, amount]
	$"./BuildingCostTemplate".amount = amount * price
	$"./BuildingCostTemplate".update()
