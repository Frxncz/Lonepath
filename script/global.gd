extends Node

var player_current_attack = false

var current_scene = "world" #world cliff_side
var transition_scene = false

var player_exit_cliffside_posx = 547.0
var player_exit_cliffside_posy = 36.0
var player_start_posx = 560.0
var player_start_posy = 421.0

var game_first_loading = true

# ---- Persistence ----
# Dictionary mapping persistent enemy id -> bool (true = alive, false = dead).
# If an id is absent, treat as alive by default.
var enemy_states: Dictionary = {}

# Whether the world scene textbox has already been read (so we don't show again)
var world_textbox_shown: bool = false

# Whether the cliff_side end-textbox has already been shown
var cliff_end_text_shown: bool = false
# ---------------------

# ---- Persistence ----
# Player health persisted across scenes
var player_health: int = 100
var player_max_health: int = 100
# ---------------------

func finish_changescenes():
	if transition_scene == true:
		transition_scene = false
		if current_scene == "world":
			# use assignment, not comparison
			current_scene = "cliff_side"
		else:
			current_scene = "world"

# Helpers
func mark_enemy_dead(id: String) -> void:
	if id == null or id == "":
		return
	enemy_states[id] = false
	print("global: marked enemy dead -> ", id)

func is_enemy_alive(id: String) -> bool:
	if id == null or id == "":
		return true
	if enemy_states.has(id):
		return bool(enemy_states[id])
	return true

func mark_enemy_alive(id: String) -> void:
	if id == null or id == "":
		return
	enemy_states[id] = true
