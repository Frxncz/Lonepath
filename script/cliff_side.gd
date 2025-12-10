extends Node2D

# Only show end textbox once
var _end_text_shown: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_connect_orc_death()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
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
		# Prefer an explicit `died` signal if present
		if orc.has_signal("died"):
			# simple connection, died signal will pass the message string
			orc.connect("died", Callable(self, "_on_orc_died"))
			print("cliff_side: connected to orc.died for ", orc.name)
		# Fallback: watch the AnimatedSprite2D finishing its animation (bind the orc)
		elif orc.has_node("AnimatedSprite2D"):
			var anim: Node = orc.get_node("AnimatedSprite2D")
			# animation_finished usually emits no args; create a bound Callable so our handler receives the orc
			var cb := Callable(self, "_on_orc_anim_finished").bind(orc)
			anim.connect("animation_finished", cb)
			print("cliff_side: connected to AnimatedSprite2D.animation_finished for ", orc.name)
		else:
			# final fallback: if the node is removed from the tree, assume it died
			# create a bound Callable so the handler receives the orc
			var cb2 := Callable(self, "_on_orc_tree_exited").bind(orc)
			orc.connect("tree_exited", cb2)
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
	# only show once
	if _end_text_shown:
		return
	_end_text_shown = true

	# Build a 3-sentence ending sequence. If the orc provided a custom message use it as the first sentence.
	var first: String = message if message != "" else "You struck the final blow and the Orc fell to the ground."
	var second: String = "Your victory revealed new paths across the cliffside, and hope began to spread through the nearby villages."
	var third: String = "Thank you for playing our demo — your journey isn't over yet, but this battle is done."
	_show_end_text([first, second, third])


# Handler for AnimatedSprite2D.animation_finished (we bound the orc as the argument).
# AnimatedSprite2D's signal typically provides no args, so our bound orc is the parameter.
func _on_orc_anim_finished(orc: Node) -> void:
	if _end_text_shown:
		return
	if orc == null:
		return
	# require the orc to actually be marked dead before showing the textbox
	var is_dead_flag: bool = false
	if orc.has_method("get"):
		var v = orc.get("is_dead")
		if v == true:
			is_dead_flag = true
	# Check animation name if possible
	if orc.has_node("AnimatedSprite2D"):
		var anim_node: Node = orc.get_node("AnimatedSprite2D")
		# safe-check for property 'animation'
		if anim_node.has_method("get") and str(anim_node.get("animation")) == "death":
			if is_dead_flag:
				_end_text_shown = true
				_show_end_text(["You defeated the Orc!", "Your victory revealed new paths across the cliffside.", "Thank you for playing our demo."])
			return
	if is_dead_flag:
		_end_text_shown = true
		_show_end_text(["You defeated the Orc!", "Your victory revealed new paths across the cliffside.", "Thank you for playing our demo."])


# Handler when the orc node is removed from the tree (fallback)
func _on_orc_tree_exited(orc: Node) -> void:
	# only show once and only if the orc was actually dead
	if _end_text_shown:
		return
	if orc != null and orc.has_method("get") and orc.get("is_dead") == true:
		_end_text_shown = true
		_show_end_text(["You defeated the Orc!", "Your victory revealed new paths across the cliffside.", "Thank you for playing our demo."])


# Find the Textbox_end node in the current scene (search descendants). Returns null if not found.
func _find_textbox_node() -> Node:
	if has_node("Textbox_end"):
		return get_node("Textbox_end")
	var queue: Array = [self]
	while queue.size() > 0:
		var n: Node = queue.pop_front()
		for c in n.get_children():
			if c is Node:
				if c.name == "Textbox_end":
					return c
				queue.append(c)
	return null


# Call the textbox to start showing end texts.
# Accepts either a String (single sentence) or an Array of strings (each will be shown in order).
func _show_end_text(message) -> void:
	var tb: Node = _find_textbox_node()
	if tb == null:
		# As a last resort, search the scene tree root
		var root_tb: Node = null
		for n in get_tree().get_root().get_children():
			if n.name == "Textbox_end":
				root_tb = n
				break
		tb = root_tb
	if tb == null:
		push_error("cliff_side: Textbox_end node not found - cannot show end textbox")
		return

	# Build an array of texts to pass to textbox.start_texts
	var texts_to_show: Array = []
	if typeof(message) == TYPE_ARRAY:
		texts_to_show = message.duplicate()
	else:
		# single string -> build three sentences using defaults
		var first: String = str(message)
		var second: String = "Your victory revealed new paths across the cliffside, and hope began to spread through the nearby villages."
		var third: String = "Thank you for playing our demo — your journey isn't over yet, but this battle is done."
		texts_to_show = [first, second, third]

	# Use start_texts so the typing effect plays; fallback to show_textbox or direct label set.
	if tb.has_method("start_texts"):
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
