extends CharacterBody2D

signal died(message: String)
@export var persistent_id: String = ""

var speed = 63
var player_chase = false
var player = null
var health = 100
var player_inattack_zone = false
var can_take_damage = true

var can_attack = true

var has_dealt_damage = false
var is_hit = false
var is_dead = false

var knockback_velocity := Vector2.ZERO
var knockback_force := 200.0
var knockback_duration := 0.0
var max_knockback_duration := 0.12

var died_emitted: bool = false

func _ready():
	if $AnimatedSprite2D:
		$AnimatedSprite2D.connect("frame_changed", Callable(self, "_on_animated_sprite_frame_changed"))
		$AnimatedSprite2D.connect("animation_finished", Callable(self, "_on_animated_sprite_animation_finished"))
	if has_node("enemy_attack_cooldown"):
		$enemy_attack_cooldown.connect("timeout", Callable(self, "_on_enemy_attack_cooldown_timeout"))
	if has_node("take_damage_cooldown"):
		$take_damage_cooldown.connect("timeout", Callable(self, "_on_take_damage_cooldown_timeout"))

func _physics_process(delta):
	update_health()
	if is_dead:
		return

	deal_with_damage()

	if knockback_duration > 0.0:
		position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 0.3)
		knockback_duration -= delta
		return
	
	if is_hit:
		return
	
	if player_inattack_zone and can_attack:
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
	var candidate = body
	if not candidate.has_method("take_damage") and candidate.get_parent() != null:
		candidate = candidate.get_parent()
	if candidate != null and candidate.has_method("take_damage"):
		player = candidate
		player_chase = true

func _on_detection_area_body_exited(body: Node2D) -> void:
	var candidate = body
	if not candidate.has_method("take_damage") and candidate.get_parent() != null:
		candidate = candidate.get_parent()
	if candidate == player:
		player = null
		player_chase = false

func enemy():
	pass

func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
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

func _on_animated_sprite_frame_changed():
	if $AnimatedSprite2D.animation == "attack" and $AnimatedSprite2D.frame == 6:
		if player_inattack_zone and player != null and !has_dealt_damage:
			if player.has_method("take_damage"):
				player.take_damage(20, self.global_position)
				has_dealt_damage = true

func _on_animated_sprite_animation_finished():
	if $AnimatedSprite2D.animation == "attack":
		can_attack = false
		has_dealt_damage = false
		if has_node("enemy_attack_cooldown"):
			$enemy_attack_cooldown.start()
	
	elif $AnimatedSprite2D.animation == "hit":
		is_hit = false

	elif $AnimatedSprite2D.animation == "death":
		queue_free()

func _on_enemy_attack_cooldown_timeout() -> void:
	can_attack = true

func deal_with_damage():
	if player_inattack_zone and global.player_current_attack == true and !is_hit:
		if can_take_damage == true:
			health -= 10
			is_hit = true
			$AnimatedSprite2D.play("hit")
			if has_node("take_damage_cooldown"):
				$take_damage_cooldown.start()
			can_take_damage = false
			print("slime3 health = ", health)

			if player != null:
				var knock_dir = (global_position - player.global_position).normalized()
				knockback_velocity = knock_dir * knockback_force
				knockback_duration = max_knockback_duration

			if health <= 0:
				is_dead = true
				if not died_emitted:
					died_emitted = true
					var id = persistent_id if persistent_id != "" else name
					global.mark_enemy_dead(id)
					emit_signal("died", "You defeated the Slime!")
				$AnimatedSprite2D.play("death")

func _on_take_damage_cooldown_timeout() -> void:
	can_take_damage = true

func update_health():
	var healthbar = $healthbar
	healthbar.value = health
