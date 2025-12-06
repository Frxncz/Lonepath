extends Node

var player_current_attack = false

var current_scene = "world" #world cliff_side
var transition_scene = false

var player_exit_cliffside_posx = 547.0
var player_exit_cliffside_posy = 36.0
var player_start_posx = 560.0
var player_start_posy = 421.0

var game_first_loading = true

func finish_changescenes():
	if transition_scene == true:
		transition_scene = false
		if current_scene == "world":
			# use assignment, not comparison
			current_scene = "cliff_side"
		else:
			current_scene = "world"
