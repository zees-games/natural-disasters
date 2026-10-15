@tool
extends EditorPlugin

## Editor entry point for natural-disasters. Registers inspector types only.
##
## No autoloads. A disaster manager belongs to a world, and a process that runs a server and
## a client needs two of them; a global would make that the one arrangement this family cannot
## have.

const _TYPES := [
	["DotDisasterManager", "Node", "res://addons/natural_disasters/runtime/dot_disaster_manager.gd"],
	["DotDisasterDirector", "Node", "res://addons/natural_disasters/runtime/dot_disaster_director.gd"],
	["DotDisasterShake", "Node", "res://addons/natural_disasters/runtime/dot_disaster_shake.gd"],
]


func _enter_tree() -> void:
	for entry in _TYPES:
		add_custom_type(entry[0], entry[1], load(entry[2]), null)


func _exit_tree() -> void:
	for i in range(_TYPES.size() - 1, -1, -1):
		remove_custom_type(_TYPES[i][0])
