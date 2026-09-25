extends Node2D

signal on_back

@export var planetIndex: int = -1

func _ready() -> void:
	%BuildingLayer.planetIndex = planetIndex
	
	var planet = Global.planets[planetIndex]
	
	var style = StyleBoxFlat.new()
	style.bg_color = planet.color
	style.border_color = lerp(planet.color, Color.BLACK, 0.5)
	style.border_width_bottom = 16
	style.border_width_top = 16
	style.border_width_left = 16
	style.border_width_right = 16
	
	%Background.add_theme_stylebox_override("panel",style)

func _process(_delta: float) -> void:
	pass
	
func _on_back_button_pressed() -> void:
	on_back.emit()
