extends Node2D

# Use global.cliff_end_text_shown so the end textbox persists across scenes

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Remove any enemies already marked dead and connect remaining ones
	_restore_persistent_enemies()

	# If cliff end textbox was already shown, hide it
	if global.cliff_end_text_shown:
		var tb = _find_textbox_node()
		if tb and tb.has_method("hide_textbox"):
			tb.hide_textbox()

	# Connect death handlers for any remaining orcs
	_connect_orc_death()

# Called every frame. 'delta' is the elapsed time since the previous frame.
# prefixed to avoid unused parameter warning
func _process(_delta: float) -> void:
	change_scene()

func _on_cliffside_exitpoint_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		global.transition_scene = true

func _on_cliffside_exitpoint_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		global.transition_scene = false

func change_scene() -> void:
	if global.transition_scene == true:
		if global.current_scene == "world":
			get_tree().change_scene_to_file("res://scene/world.tscn")
			global.finish_changescenes()


# -------------------------
# ORC DEATH -> SHOW TEXTBOX
# -------------------------

# Find orc nodes under this scene and connect to their death events.
func _connect_orc_death() -> void:
	var orcs: Array = []
	_collect_orcs(self, orcs)
	if orcs.size() == 0:
		print("cliff_side: no orcs found to connect to")
	for orc in orcs:
		if not orc:
			continue
		# Prefer an explicit `died` signal if present
		if orc.has_signal("died"):
			var cb = Callable(self, "_on_orc_died")
			if not orc.is_connected("died", cb):
				orc.connect("died", cb)
			print("cliff_side: connected to orc.died for ", orc.name)
		# Fallback: watch the AnimatedSprite2D finishing its animation (bind the orc)
		elif orc.has_node("AnimatedSprite2D"):
			var anim: Node = orc.get_node("AnimatedSprite2D")
			var cb2 := Callable(self, "_on_orc_anim_finished").bind(orc)
			if not anim.is_connected("animation_finished", cb2):
				anim.connect("animation_finished", cb2)
			print("cliff_side: connected to AnimatedSprite2D.animation_finished for ", orc.name)
		else:
			var cb3 := Callable(self, "_on_orc_tree_exited").bind(orc)
			if not orc.is_connected("tree_exited", cb3):
				orc.connect("tree_exited", cb3)
			print("cliff_side: connected to tree_exited for ", orc.name)


# Recursively collect nodes that look like the orc enemy.
# Detection by script resource path ending in "enemy_orc.gd" OR node name containing "orc".
func _collect_orcs(node: Node, out_array: Array) -> void:
	for child in node.get_children():
		if not child is Node:
			continue
		var added: bool = false
		# 1) check script resource path if present
		var scr: Script = null
		if child.has_method("get_script"):
			# get_script may return a Script resource or null
			scr = child.get_script()
		elif child.get("script") != null:
			scr = child.get("script")
		if scr != null and str(scr.resource_path).ends_with("enemy_orc.gd"):
			out_array.append(child)
			added = true
		# 2) fallback: check name contains "orc"
		if not added and child.name.to_lower().find("orc") != -1:
			if child.has_node("AnimatedSprite2D") or child is CharacterBody2D:
				out_array.append(child)
				added = true
		# Recurse into children to find nested instances
		_collect_orcs(child, out_array)


# Handler for the explicit `died(message)` signal from an enemy.
# The enemy emits one string message; we build a 3-sentence sequence here and call the textbox.
func _on_orc_died(message: String = "") -> void:
	print("cliff_side: on_orc_died called, message=", message)
	# only show once (persisted)
	if global.cliff_end_text_shown:
		print("cliff_side: cliff_end_text_shown already true; skipping textbox")
		return
	# mark persisted flag early so we don't show twice
	global.cliff_end_text_shown = true

	var first: String = message if message != "" else "You struck the final blow and the Orc fell to the ground."
	var second: String = "Your victory revealed new paths across the cliffside, and hope began to spread through the nearby villages."
	var third: String = "Thank you for playing our demo — your journey isn't over yet, but this battle is done."
	_show_end_text([first, second, third])


# Handler for AnimatedSprite2D.animation_finished (we bound the orc as the argument).
func _on_orc_anim_finished(orc: Node) -> void:
	if global.cliff_end_text_shown:
		return
	if orc == null:
		return
	var is_dead_flag: bool = false
	if orc.has_method("get") and orc.get("is_dead") == true:
		is_dead_flag = true
	if orc.has_node("AnimatedSprite2D"):
		var anim_node: Node = orc.get_node("AnimatedSprite2D")
		if anim_node.has_method("get") and anim_node.get("animation") == "death":
			if is_dead_flag:
				global.cliff_end_text_shown = true
				_show_end_text(["You defeated the Orc!", "Your victory revealed new paths across the cliffside.", "Thank you for playing our demo."])
			return
	if is_dead_flag:
		global.cliff_end_text_shown = true
		_show_end_text(["You defeated the Orc!", "Your victory revealed new paths across the cliffside.", "Thank you for playing our demo."])


# Handler when the orc node is removed from the tree (fallback)
func _on_orc_tree_exited(orc: Node) -> void:
	if global.cliff_end_text_shown:
		return
	if orc != null and orc.has_method("get") and orc.get("is_dead") == true:
		global.cliff_end_text_shown = true
		_show_end_text(["You defeated the Orc!", "Your victory revealed new paths across the cliffside.", "Thank you for playing our demo."])


# Find the Textbox_end node in the current scene (search descendants). Returns null if not found.
func _find_textbox_node() -> Node:
	# Fast path: child of this scene
	if has_node("Textbox_end"):
		return get_node("Textbox_end")
	# Search descendants of this scene
	var queue: Array = [self]
	while queue.size() > 0:
		var n: Node = queue.pop_front()
		for c in n.get_children():
			if c is Node:
				if c.name == "Textbox_end":
					return c
				queue.append(c)
	# Fallback: search entire scene tree root recursively (robust)
	var found = _find_node_in_root("Textbox_end")
	if found:
		print("cliff_side: Textbox_end found at: ", found.get_path())
		return found
	# not found
	print("cliff_side: Textbox_end NOT found")
	return null


# Helper: recursively search the scene tree root for a node with the given name.
func _find_node_in_root(name: String) -> Node:
	var root = get_tree().get_root()
	# Depth-first
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n.name == name:
			return n
		for child in n.get_children():
			if child is Node:
				stack.append(child)
	return null


# Call the textbox to start showing end texts.
# Accepts either a String (single sentence) or an Array of strings (each will be shown in order).
func _show_end_text(message) -> void:
	var tb: Node = _find_textbox_node()
	if tb == null:
		push_error("cliff_side: Textbox_end node not found - cannot show end textbox")
		return

	var texts_to_show: Array = []
	if typeof(message) == TYPE_ARRAY:
		texts_to_show = message.duplicate()
	else:
		var first: String = str(message)
		var second: String = "Your victory revealed new paths across the cliffside, and hope began to spread through the nearby villages."
		var third: String = "Thank you for playing our demo — your journey isn't over yet, but this battle is done."
		texts_to_show = [first, second, third]

	if tb.has_method("start_texts"):
		print("cliff_side: starting textbox with texts:", texts_to_show)
		tb.start_texts(texts_to_show)
	elif tb.has_method("show_textbox"):
		# fallback: show the first text directly
		var label_path: String = "textboxContainer/MarginContainer/HBoxContainer/Label2"
		if texts_to_show.size() > 0 and tb.has_node(label_path):
			var label = tb.get_node(label_path)
			if label is Label:
				label.text = texts_to_show[0]
		tb.show_textbox()
	else:
		push_error("cliff_side: Textbox_end does not expose start_texts() or show_textbox()")


# -----------------------------
# Persistent enemy restoration
# Removes enemies that global says are dead, and connects live ones.
# -----------------------------
func _restore_persistent_enemies() -> void:
	var enemies: Array = []
	if get_tree().has_group("persistent_enemy"):
		enemies = get_tree().get_nodes_in_group("persistent_enemy")
	else:
		# fallback: scan for orcs/slimes by script or name
		_collect_persistent_enemies(self, enemies)

	for enemy in enemies:
		if not enemy:
			continue
		var pid = enemy.get("persistent_id")
		var id = ""
		if pid != null and str(pid) != "":
			id = str(pid)
		else:
			id = str(enemy.name)

		# If marked dead in global, remove it now so the scene appears as left
		if not global.is_enemy_alive(id):
			print("cliff_side: removing persistent enemy (dead) -> ", id)
			enemy.queue_free()
			continue

		# Connect to died so we mark global (bind id)
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


func _collect_persistent_enemies(node: Node, out_array: Array) -> void:
	for child in node.get_children():
		if not child is Node:
			continue
		var scr: Script = null
		if child.has_method("get_script"):
			scr = child.get_script()
		elif child.get("script") != null:
			scr = child.get("script")
		var added: bool = false
		if scr != null:
			var path = str(scr.resource_path).to_lower()
			if path.find("enemy_orc") != -1 or path.find("enemy_slime") != -1:
				out_array.append(child)
				added = true
		if not added and (child.name.to_lower().find("orc") != -1 or child.name.to_lower().find("slime") != -1):
			if child.has_node("AnimatedSprite2D") or child is CharacterBody2D:
				out_array.append(child)
				added = true
		_collect_persistent_enemies(child, out_array)


# Callbacks to mark global when a connected enemy dies (used when enemy doesn't mark global itself).
func _on_persistent_enemy_died(id: String) -> void:
	if id != "":
		global.mark_enemy_dead(id)

func _on_persistent_enemy_anim_finished(enemy: Node, id: String) -> void:
	if enemy != null and enemy.has_method("get") and enemy.get("is_dead") == true:
		if id != "":
			global.mark_enemy_dead(id)

# prefixed the unused parameter to silence the warning
func _on_persistent_enemy_tree_exited(_enemy: Node, id: String) -> void:
	if id != "":
		global.mark_enemy_dead(id)
