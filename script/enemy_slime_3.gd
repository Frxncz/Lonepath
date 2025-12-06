extends CharacterBody2D

var speed = 55
var player_chase = false
var player = null
var health = 150
var player_inattack_zone = false
var can_take_damage = true

# renamed to avoid collision with Timer node name
var can_attack = true

var has_dealt_damage = false
var is_hit = false
var is_dead = false

func _ready():
	# Explicitly connect AnimatedSprite2D signals so naming/case issues don't break things.
	if $AnimatedSprite2D:
		$AnimatedSprite2D.connect("frame_changed", Callable(self, "_on_animated_sprite_frame_changed"))
		$AnimatedSprite2D.connect("animation_finished", Callable(self, "_on_animated_sprite_animation_finished"))
	# Connect timers if present to keep behavior deterministic
	if has_node("enemy_attack_cooldown"):
		$enemy_attack_cooldown.connect("timeout", Callable(self, "_on_enemy_attack_cooldown_timeout"))
	if has_node("take_damage_cooldown"):
		$take_damage_cooldown.connect("timeout", Callable(self, "_on_take_damage_cooldown_timeout"))

func _physics_process(delta):
	if is_dead:
		# don't do anything once dead
		return

	deal_with_damage()
	
	# Don't do anything while being hit
	if is_hit:
		return
	
	# Only attempt to start an attack if ready
	if player_inattack_zone and can_attack:
		# ensure we reset per-attack damage flag when starting a new attack
		if $AnimatedSprite2D.animation != "attack":
			has_dealt_damage = false
			$AnimatedSprite2D.play("attack")
		return
	
	if player_chase and player != null:
		position += (player.position - position)/speed
		$AnimatedSprite2D.play("walk")
		
		if (player.position.x - position.x) < 0:
			$AnimatedSprite2D.flip_h = true
		else:
			$AnimatedSprite2D.flip_h = false
	else:
		$AnimatedSprite2D.play("idle")

func _on_detection_area_body_entered(body: Node2D) -> void:
	# Try to find the player node robustly: either the body itself or its parent may be the player node.
	var candidate = body
	if not candidate.has_method("take_damage") and candidate.get_parent() != null:
		candidate = candidate.get_parent()
	if candidate != null and candidate.has_method("take_damage"):
		player = candidate
		player_chase = true

func _on_detection_area_body_exited(body: Node2D) -> void:
	# If the body leaving is the currently tracked player, clear reference.
	var candidate = body
	if not candidate.has_method("take_damage") and candidate.get_parent() != null:
		candidate = candidate.get_parent()
	if candidate == player:
		player = null
		player_chase = false

func enemy():
	pass

func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
	# Robustly detect the player (the body or its parent with take_damage)
	var candidate = body
	if not candidate.has_method("take_damage") and candidate.get_parent() != null:
		candidate = candidate.get_parent()
	if candidate != null and candidate.has_method("take_damage"):
		player_inattack_zone = true
		player = candidate

func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
	var candidate = body
	if not candidate.has_method("take_damage") and candidate.get_parent() != null:
		candidate = candidate.get_parent()
	if candidate != null and candidate.has_method("take_damage"):
		player_inattack_zone = false
		# don't clear `player` here necessarily — detection area handles chase clearing

# Frame-based damage dealing — called when the AnimatedSprite2D frame changes.
func _on_animated_sprite_frame_changed():
	# Ensure we are in the attack animation and at the damage frame.
	if $AnimatedSprite2D.animation == "attack" and $AnimatedSprite2D.frame == 6:
		# Only deal once per attack
		if player_inattack_zone and player != null and !has_dealt_damage:
			if player.has_method("take_damage"):
				player.take_damage(20, self.global_position)
				has_dealt_damage = true

# Called when animations finish
func _on_animated_sprite_animation_finished():
	if $AnimatedSprite2D.animation == "attack":
		# finished attack: start cooldown before next attack
		# block further attacks until timer finishes
		can_attack = false
		# reset per-attack flag so next attack can deal again (safe fallback)
		has_dealt_damage = false
		if has_node("enemy_attack_cooldown"):
			$enemy_attack_cooldown.start()
	
	elif $AnimatedSprite2D.animation == "hit":
		is_hit = false

	elif $AnimatedSprite2D.animation == "death":
		# remove enemy once death animation is done
		queue_free()

func _on_enemy_attack_cooldown_timeout() -> void:
	can_attack = true

func deal_with_damage():
	# Player attacking enemy
	# Player attack state is stored in global.player_current_attack
	if player_inattack_zone and global.player_current_attack == true and !is_hit:
		if can_take_damage == true:
			health -= 10
			is_hit = true
			$AnimatedSprite2D.play("hit")
			if has_node("take_damage_cooldown"):
				$take_damage_cooldown.start()
			can_take_damage = false
			print("orc health = ", health)
			if health <= 0:
				# Play death animation and mark as dead so it can finish
				is_dead = true
				$AnimatedSprite2D.play("death")

func _on_take_damage_cooldown_timeout() -> void:
	can_take_damage = true
