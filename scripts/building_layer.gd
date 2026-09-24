extends TileMapLayer

@export var people = 0
@export var robots = 0

@export var steel = 0
@export var titanium = 0
@export var electricity = 0

var planet = Global.planets[Global.selected_planet]

#Do we really have to update money and ui every tick
var tick_timer = 0
var tick_scaler = 0.5

func _ready() -> void:
	%Background.color = planet.color

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#psa don't use scales with these lmao
		var tile_coord = %BuildingLayer.local_to_map(event.position)
		%BuildingLayer.set_cell(tile_coord,0,Vector2i(0,0))
		
func _physics_process(delta: float) -> void:
	#Do we really have to update money and ui every tick
	tick_timer=tick_timer+delta
	
	#building output
	if(tick_scaler<tick_timer):
		tick_timer=tick_timer-tick_scaler
		var cells = %BuildingLayer.get_used_cells()
		for cell in cells:
			# we gotta get a better system asap
			# 0 mine
			# 1 panel
			#
			#
			#
			#
			if(%BuildingLayer.get_cell_source_id(cell)==0):
				steel=steel+1*tick_scaler
			elif(%BuildingLayer.get_cell_source_id(cell)==1):
				electricity=electricity+1*tick_scaler
	# update ui
	%MoneyLabel.text = str(int(Global.money))
	%PopLabel.text = str(int(people))
	%RobotLabel.text = str(int(robots))
	%SteelLabel.text = str(int(titanium))
	%TitaniumLabel.text = str(int(steel))
	%ElectricityLabel.text = str(int(electricity))


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/overview.tscn")
