extends PanelContainer

signal buy

@export var id = ""
@export var title = ""
@export var price = 0

func _ready() -> void:
	%TextureRect.texture = load("res://res/asset_icon_%s_4x.png" % [id])
	%Label.text = title
	%Cost.amount = price
	%Cost.update()
	%Buy.pressed.connect(func buy(): buy.emit(1))
	%Buy10.pressed.connect(func buy(): buy.emit(10))
	%Buy100.pressed.connect(func buy(): buy.emit(100))
