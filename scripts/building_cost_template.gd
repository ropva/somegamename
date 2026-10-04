extends HBoxContainer

@export var item = ""
@export var amount = 0.0

func update() -> void:
	%TextureRect.texture = load("res://res/asset_icon_%s_0.5x.png" % [item])
	%Label.text = str(amount)
func _ready():
	update()
