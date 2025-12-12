extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if global.game_first_loading == true:
		$player.position.x = global.player_start_posx
		$player.position.y = global.player_start_posy
	else:
		$player.position.x = global.player_exit_cliffside_posx
		$player.position.y = global.player_exit_cliffside_posy

	# Restore persistent enemies (slimes) based on global.enemy_states
	_restore_persistent_enemies()

	# If the world textbox was already read, hide/disable it here.
	# You need to adapt the path below to match your textbox node name.
	if global.world_textbox_shown:
		if has_node("Textbox_start"):
			var tb = get_node("Textbox_start")
			if tb and tb.has_method("hide_textbox"):
				tb.hide_textbox()

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

# --- Persistence helpers for world scene ---
func _restore_persistent_enemies() -> void:
	# 1) Try nodes in group 'persistent_enemy' (recommended for editor setup)
	var enemies: Array = []
	if get_tree().has_group("persistent_enemy"):
		enemies = get_tree().get_nodes_in_group("persistent_enemy")
	else:
		# 2) Fallback: search the scene tree for nodes whose script ends with enemy_slime or enemy_orc etc.
		_collect_persistent_enemies(self, enemies)

	for enemy in enemies:
		if not enemy:
			continue

		# determine id: prefer exported persistent_id property if supplied, otherwise use node name
		var id := ""
		var pid = null
		# Only call get if available; get() on Node exists, but guard anyway
		if enemy.has_method("get"):
			# get() returns null if property doesn't exist, so this is safe
			pid = enemy.get("persistent_id")
		if pid != null and str(pid) != "":
			id = str(pid)
		else:
			id = str(enemy.name)

		# If global says dead, remove the node
		if not global.is_enemy_alive(id):
			print("world: removing persistent enemy (dead) -> ", id)
			enemy.queue_free()
			continue

		# Connect to died to mark persistent state when it happens.
		# Bind the id so the handler can update global easily.
		if enemy.has_signal("died"):
			var cb = Callable(self, "_on_persistent_enemy_died").bind(id)
			if not enemy.is_connected("died", cb):
				enemy.connect("died", cb)
		elif enemy.has_node("AnimatedSprite2D"):
			var anim = enemy.get_node("AnimatedSprite2D")
			var cb2 := Callable(self, "_on_persistent_enemy_anim_finished").bind(enemy, id)
			if not anim.is_connected("animation_finished", cb2):
				anim.connect("animation_finished", cb2)
		else:
			var cb3 := Callable(self, "_on_persistent_enemy_tree_exited").bind(enemy, id)
			if not enemy.is_connected("tree_exited", cb3):
				enemy.connect("tree_exited", cb3)


# Recursively collect nodes that look like persistent enemies by script filename or name containing slime/orc.
func _collect_persistent_enemies(node: Node, out_array: Array) -> void:
	for child in node.get_children():
		if not child is Node:
			continue
		# check script resource path if present
		var scr: Script = null
		if child.has_method("get_script"):
			scr = child.get_script()
		elif child.get("script") != null:
			scr = child.get("script")
		var added: bool = false
		if scr != null:
			var path = str(scr.resource_path).to_lower()
			if path.ends_with("enemy_slime.gd") or path.find("enemy_slime") != -1 or path.find("enemy_orc") != -1:
				out_array.append(child)
				added = true
		# fallback: name contains slime or orc
		if not added and (child.name.to_lower().find("slime") != -1 or child.name.to_lower().find("orc") != -1):
			if child.has_node("AnimatedSprite2D") or child is CharacterBody2D:
				out_array.append(child)
				added = true
		_collect_persistent_enemies(child, out_array)


func _on_persistent_enemy_died(id: String) -> void:
	if id != "":
		global.mark_enemy_dead(id)

func _on_persistent_enemy_anim_finished(enemy: Node, id: String) -> void:
	if enemy != null and enemy.has_method("get") and enemy.get("is_dead") == true:
		if id != "":
			global.mark_enemy_dead(id)

func _on_persistent_enemy_tree_exited(enemy: Node, id: String) -> void:
	if id != "":
		global.mark_enemy_dead(id)
