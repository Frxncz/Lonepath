extends CharacterBody2D

var enemy_in_attack_range = false
var health = 100
var player_alive = true
var attack_ip = false

const speed = 130
var current_dir = "none"

var is_dead = false

var knockback_velocity = Vector2.ZERO
var knockback_force = 150
var knockback_duration = 0.0
var max_knockback_duration = 0.2

func _ready():
	current_dir = "down"
	
	if $AnimatedSprite2D:
		$AnimatedSprite2D.connect("animation_finished", Callable(self, "_on_animated_sprite_animation_finished"))
	else:
		print("ERROR: AnimatedSprite2D node not found")

func _physics_process(delta):
	
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return


	
	# If the player is being knocked back allow the player to cancel it by providing movement input.
	# This makes the "hit" state cancel immediately if the player wants to move again.
	if knockback_duration > 0:
		# If any movement key is pressed, cancel knockback and continue to normal movement.
		var input_moving = Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D) \
			or Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A) \
			or Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) \
			or Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W)
		if input_moving:
			knockback_duration = 0.0
			knockback_velocity = Vector2.ZERO
		else:
			knockback_duration -= delta
			velocity = knockback_velocity
			knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 0.3)
			move_and_slide()
			return

	player_movement(delta)
	attack()

	# keep this as a safeguard; death is primarily handled immediately in take_damage now
	if health <= 0 and player_alive:
		player_alive = false
		health = 0
		is_dead = true
		print("player has been killed")
		if $AnimatedSprite2D:
			$AnimatedSprite2D.play("death")

func player_movement(delta):
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		current_dir = "right"
		play_anim(1)
		velocity.x = speed
		velocity.y = 0
	elif Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		current_dir = "left"
		play_anim(1)
		velocity.x = -speed
		velocity.y = 0
	elif Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		current_dir = "down"
		play_anim(1)
		velocity.y = speed
		velocity.x = 0
	elif Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		current_dir = "up"
		play_anim(1)
		velocity.y = -speed
		velocity.x = 0
	else:
		play_anim(0)
		velocity.x = 0
		velocity.y = 0

	move_and_slide()

func play_anim(movement):
	# Do not block movement animations when the sprite is currently set to "hit".
	# We still block animations during an attack or when dead.
	if attack_ip or is_dead:
		return
	
	var dir = current_dir
	var anim = $AnimatedSprite2D
	var current_animation = anim.animation

	# Note: we intentionally removed the early return that prevented changing animations
	# when the current animation was "hit". This allows the player to immediately cancel
	# the 'hit' animation by moving and resume normal walking/idle animations.

	if dir == "right":
		anim.flip_h = false
		if movement == 1:
			if current_animation != "walk":
				anim.play("walk")
		elif movement == 0:
			if current_animation != "idle":
				anim.play("idle")

	if dir == "left":
		anim.flip_h = true
		if movement == 1:
			if current_animation != "walk":
				anim.play("walk")
		elif movement == 0:
			if current_animation != "idle":
				anim.play("idle")

	if dir == "down":
		if movement == 1:
			if current_animation != "walk":
				anim.play("walk")
		elif movement == 0:
			if current_animation != "idle":
				anim.play("idle")

	if dir == "up":
		if movement == 1:
			if current_animation != "walk":
				anim.play("walk")
		elif movement == 0:
			if current_animation != "idle":
				anim.play("idle")

func player():
	pass

func _on_player_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("enemy"):
		enemy_in_attack_range = true

func _on_player_hitbox_body_exited(body: Node2D) -> void:
	if body.has_method("enemy"):
		enemy_in_attack_range = false

func take_damage(damage_amount, attacker_position = null):
	if is_dead:
		return

	health -= damage_amount
	print("player health = ", health)  # <-- debug print whenever player loses health

	if attacker_position != null:
		var knock_dir = (global_position - attacker_position).normalized()
		knockback_velocity = knock_dir * knockback_force
		knockback_duration = max_knockback_duration

	# If health drops to zero or below, play death immediately and mark dead.
	if health <= 0:
		health = 0
		is_dead = true
		player_alive = false
		print("player has been killed")
		if $AnimatedSprite2D:
			$AnimatedSprite2D.play("death")
		return

	# Play hit animation when still alive.
	# Movement input will now immediately override this animation and cancel knockback.
	if $AnimatedSprite2D:
		$AnimatedSprite2D.play("hit")


func attack():
	if is_dead:
		return
	
	var dir = current_dir

	if Input.is_action_just_pressed("attack"):
		global.player_current_attack = true
		attack_ip = true
		if dir == "right":
			$AnimatedSprite2D.flip_h = false
			$AnimatedSprite2D.play("attack")
			$deal_attack_timer.start()
		if dir == "left":
			$AnimatedSprite2D.flip_h = true
			$AnimatedSprite2D.play("attack")
			$deal_attack_timer.start()
		if dir == "down":
			$AnimatedSprite2D.play("attack")
			$deal_attack_timer.start()
		if dir == "up":
			$AnimatedSprite2D.play("attack")
			$deal_attack_timer.start()

func _on_deal_attack_timer_timeout() -> void:
	$deal_attack_timer.stop()
	global.player_current_attack = false
	attack_ip = false

func _on_animated_sprite_animation_finished():
	var current_anim = $AnimatedSprite2D.animation
	
	if current_anim == "hit":
		# finishing 'hit' is not needed to re-enable movement anymore,
		# since movement immediately overrides the animation. Keep this
		# here for compatibility with any other logic that relied on it.
		attack_ip = false
	elif current_anim == "death":
		queue_free()
	elif current_anim == "attack":
		attack_ip = false
