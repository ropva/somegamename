extends Node2D

signal on_back

@export var planetIndex: int = -1

func _ready() -> void:
	%BuildingLayer.planetIndex = planetIndex
	%Background.color = Global.planets[planetIndex].color

func _process(delta: float) -> void:
	pass
	
func _on_back_button_pressed() -> void:
	on_back.emit()
