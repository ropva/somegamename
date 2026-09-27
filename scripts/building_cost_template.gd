extends HBoxContainer

@export var item = ""
@export var amount = 0

func _ready() -> void:
	%TextureRect.texture = load("res://res/asset_icon_%s_0.5x.png" % [item])
	%Label.text = "%d" % [amount]
