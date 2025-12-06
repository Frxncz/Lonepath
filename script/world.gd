extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if global.game_first_loading == true:
		$player.position.x = global.player_start_posx
		$player.position.y = global.player_start_posy
	else:
		$player.position.x = global.player_exit_cliffside_posx
		$player.position.y = global.player_exit_cliffside_posy

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	change_scene()

func _on_cliffside_transition_point_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		global.transition_scene = true

func _on_cliffside_transition_point_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		# fixed misspelling: transtion_scene -> transition_scene
		global.transition_scene = false

func change_scene() -> void:
	if global.transition_scene == true:
		if global.current_scene == "world":
			get_tree().change_scene_to_file("res://scene/cliff_side.tscn")
			global.game_first_loading = false
			global.finish_changescenes()
