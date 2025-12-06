extends Node

var player_current_attack = false

var current_scene = "world" #world cliff_side
var transition_scene = false

var player_exit_cliffside_posz = 0
var player_exit_cliffside_posy = 0
var player_start_posz = 0
var player_start_posy = 0

func finish_changescenes():
	if transition_scene == true:
		transition_scene = false
		if current_scene == "world":
			# use assignment, not comparison
			current_scene = "cliff_side"
		else:
			current_scene = "world"
