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

# Regen configuration
var _regen_timer: Timer = null
var regen_interval: float = 2.0   # seconds between heals
var regen_amount: int = 5         # HP per tick

func _ready():
	current_dir = "down"
	
	# Restore health from global (persisted across scenes)
	if Engine.has_singleton("global"):
		# global is autoload; use its values
		health = global.player_health if global.player_health != null else health
		# ensure max in global matches (optional)
		if global.player_max_health == null:
			global.player_max_health = 100

	# Create a regen timer (one per player). It won't autostart.
	if not has_node("RegenTimer"):
		_regen_timer = Timer.new()
		_regen_timer.name = "RegenTimer"
		_regen_timer.wait_time = regen_interval
		_regen_timer.one_shot = false
		add_child(_regen_timer)
		_regen_timer.connect("timeout", Callable(self, "_on_regen_timeout"))
	else:
		_regen_timer = $RegenTimer
		_regen_timer.wait_time = regen_interval

	# Connect animated sprite signal
	if $AnimatedSprite2D:
		$AnimatedSprite2D.connect("animation_finished", Callable(self, "_on_animated_sprite_animation_finished"))
	else:
		print("ERROR: AnimatedSprite2D node not found")

	# Sync UI immediately
	update_health()
	# persist initial health
	if Engine.has_singleton("global"):
		global.player_health = health
		global.player_max_health = global.player_max_health if global.player_max_health != null else 100

func _physics_process(delta):
	update_health()
	
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# If the player is being knocked back allow the player to cancel it by providing movement input.
	if knockback_duration > 0:
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
		# persist death health
		if Engine.has_singleton("global"):
			global.player_health = health
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
	if attack_ip or is_dead:
		return
	
	var dir = current_dir
	var anim = $AnimatedSprite2D
	var current_animation = anim.animation

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
	print("player health = ", health)  # debug print whenever player loses health

	# persist immediately
	if Engine.has_singleton("global"):
		global.player_health = health

	# restart the regen timer so healing begins 2s after last damage
	if _regen_timer:
		_regen_timer.stop()
		_regen_timer.wait_time = regen_interval
		# start only if still alive and not at max
		if health > 0 and health < global.player_max_health:
			_regen_timer.start()

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
		# persist death health
		if Engine.has_singleton("global"):
			global.player_health = health
		if $AnimatedSprite2D:
			$AnimatedSprite2D.play("death")
		# stop regen
		if _regen_timer:
			_regen_timer.stop()
		return

	# Play hit animation when still alive.
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
		attack_ip = false
	elif current_anim == "death":
		get_tree().change_scene_to_file("res://scene/game_over.tscn")
	elif current_anim == "attack":
		attack_ip = false

func current_camera():
	if global.current_scene == "world":
		$world_camera.enabled = true
		$cliffside_camera.enabled = false
	elif global.current_scene == "cliffside":
		$world_camera.enabled = true
		$cliffside_camera.enabled = false

func update_health():
	var healthbar = $healthbar
	if healthbar:
		healthbar.value = health

# Regen handler called by _regen_timer every regen_interval seconds.
func _on_regen_timeout() -> void:
	# Don't regen when dead
	if is_dead:
		if _regen_timer:
			_regen_timer.stop()
		return

	# Use global max if available
	var max_h = global.player_max_health if Engine.has_singleton("global") else 100
	if health < max_h:
		health = min(health + regen_amount, max_h)
		# persist and update UI
		if Engine.has_singleton("global"):
			global.player_health = health
		update_health()
		print("player regen -> ", health)
		# stop when full
		if health >= max_h and _regen_timer:
			_regen_timer.stop()
	else:
		if _regen_timer:
			_regen_timer.stop()
