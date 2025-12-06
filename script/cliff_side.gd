extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	change_scene()

func _on_cliffside_exitpoint_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		global.transition_scene = true


func _on_cliffside_exitpoint_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		# fixed misspelling: transtion_scene -> transition_scene
		global.transition_scene = false

func change_scene() -> void:
	if global.transition_scene == true:
		if global.current_scene == "world":
			get_tree().change_scene_to_file("res://scene/world.tscn")
			global.finish_changescenes()
