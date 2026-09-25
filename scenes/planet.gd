extends Node2D

signal on_back

var planet = Global.planets[Global.selected_planet]

func _ready() -> void:
	%Background.color = planet.color

func _process(delta: float) -> void:
	pass
	
func _on_back_button_pressed() -> void:
	print("jdkjdj")
	print(on_back.get_connections())
	on_back.emit()
