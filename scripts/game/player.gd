extends CharacterBody2D
## The hero. Handles movement physics (variable jump, coyote time, jump
## buffering, sprint, ice, water, wind, quicksand), damage, power-ups and
## interaction with enemies, pickups and triggers.

const Res = preload("res://scripts/game/res.gd")

const WALK := 92.0
const RUN := 150.0
const ACCEL := 950.0
const DECEL := 1200.0
const AIR_ACCEL := 700.0
const ICE_ACCEL := 210.0
const ICE_DECEL := 75.0
const GRAVITY := 1000.0
const FALL_GRAVITY := 1250.0
const MAX_FALL := 400.0
const JUMP_V := 378.0
const MEGA_JUMP_V := 470.0
const JUMP_CUT := 0.45
const COYOTE := 0.1
const BUFFER := 0.13
const STOMP_BOUNCE := 250.0
const W := 10.0
const H := 14.0
const MAX_HP := 3
const AIR_MAX := 12.0
const SPEED_TIME := 10.0
const MEGA_TIME := 12.0
const MAGNET_TIME := 15.0

var level: Node
var hp := MAX_HP
var facing := 1
var dead := false
var finished := false
var invuln := 0.0
var hurt_time := 0.0
var coyote := 0.0
var buffer := 0.0
var jumping := false
var shield := false
var speed_t := 0.0
var mega_t := 0.0
var magnet_t := 0.0
var blast_ammo := 0
var blast_cd := 0.0
var air := AIR_MAX
var in_water := false
var head_in_water := false
var drown_t := 0.0
var swim_cd := 0.0
var stomp_chain := 0
var input_enabled := true
var sprite: AnimatedSprite2D
var _shape: CollisionShape2D
var _was_on_floor := true
var _death_t := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	floor_max_angle = deg_to_rad(50)
	safe_margin = 0.05
	_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(W, H)
	_shape.shape = rs
	_shape.position = Vector2(0, -H / 2)
	add_child(_shape)
	sprite = Res.sprite("hero", {
		"idle": [0, 1], "run": [2, 3, 4, 5], "jump": [6], "fall": [7], "hurt": [8],
		"victory": [9], "swim": [10, 11]},
		{"idle": 2.0, "run": 12.0, "swim": 5.0, "jump": 1.0, "fall": 1.0, "hurt": 1.0, "victory": 1.0})
	sprite.position = Vector2(0, -8)
	add_child(sprite)
	z_index = 2


func rect() -> Rect2:
	return Rect2(global_position.x - W / 2, global_position.y - H, W, H)


func center() -> Vector2:
	return global_position + Vector2(0, -H / 2)


func _physics_process(delta: float) -> void:
	if dead:
		_death_t += delta
		if _death_t > 0.35:
			velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL)
			position += velocity * delta
		return
	if finished:
		velocity.x = move_toward(velocity.x, 0, DECEL * delta)
		velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		_animate()
		return

	_timers(delta)

	var dir := 0.0
	var run_held := false
	var jump_pressed := false
	var jump_held := false
	var fire_pressed := false
	if input_enabled and hurt_time <= 0.0:
		dir = Input.get_axis("move_left", "move_right")
		run_held = Input.is_action_pressed("run")
		jump_pressed = Input.is_action_just_pressed("jump")
		jump_held = Input.is_action_pressed("jump")
		fire_pressed = Input.is_action_just_pressed("run")
	if dir != 0.0:
		facing = 1 if dir > 0 else -1

	# --- environment sampling
	var c_center: String = level.char_at_pos(center())
	var c_head: String = level.char_at_pos(global_position + Vector2(0, -H + 2))
	var c_feet: String = level.char_at_pos(global_position + Vector2(0, -2))
	var c_below: String = level.char_at_pos(global_position + Vector2(0, 2))
	var was_in_water := in_water
	in_water = level.is_water(c_center) or level.is_water(c_feet) and level.is_water(c_head)
	head_in_water = level.is_water(c_head)
	var quick := c_feet == "Q" or c_center == "Q"
	var wind := c_center == "Z" or c_feet == "Z"
	var current := 0.0
	if c_center == "<":
		current = -55.0
	elif c_center == ">":
		current = 55.0
	var on_floor := is_on_floor()
	var ice := on_floor and c_below == "I"
	if in_water != was_in_water and abs(velocity.y) > 60:
		Res.burst(level.fx_root(), global_position + Vector2(0, -6), Color("bfe8ff"), 8, 60, 0.4, 200)
		Audio.sfx("swim", 0.8)

	# --- horizontal
	var max_speed := RUN if run_held else WALK
	if speed_t > 0.0:
		max_speed *= 1.45
	if in_water:
		max_speed = 72.0 * (1.3 if run_held else 1.0)
	if quick:
		max_speed *= 0.4
	var target := dir * max_speed + current
	var accel := AIR_ACCEL
	if on_floor:
		accel = ACCEL if dir != 0.0 else DECEL
		if ice:
			accel = ICE_ACCEL if dir != 0.0 else ICE_DECEL
	if in_water:
		accel = 500.0
	velocity.x = move_toward(velocity.x, target, accel * delta)

	# --- vertical
	if on_floor:
		coyote = COYOTE
		stomp_chain = 0
	else:
		coyote -= delta
	if jump_pressed:
		buffer = BUFFER
	else:
		buffer -= delta

	if in_water:
		velocity.y = min(velocity.y + 320.0 * delta, 75.0)
		if buffer > 0.0 and swim_cd <= 0.0:
			buffer = 0.0
			swim_cd = 0.18
			if not head_in_water:
				velocity.y = -330.0
				Audio.sfx("jump")
			else:
				velocity.y = -150.0
				Audio.sfx("swim")
		jumping = false
	else:
		if wind:
			velocity.y = max(velocity.y - 1800.0 * delta, -175.0)
		else:
			var g := FALL_GRAVITY if velocity.y > 0.0 else GRAVITY
			velocity.y = min(velocity.y + g * delta, MAX_FALL)
		if buffer > 0.0 and coyote > 0.0:
			var jv := MEGA_JUMP_V if mega_t > 0.0 else JUMP_V
			if quick:
				jv *= 0.72
			velocity.y = -jv
			buffer = 0.0
			coyote = 0.0
			jumping = true
			Audio.sfx("jump", 1.0 + randf() * 0.06)
			Res.burst(level.fx_root(), global_position, Color("e8e0d0"), 5, 40, 0.3, 50)
	if jumping and not jump_held and velocity.y < 0.0:
		velocity.y *= JUMP_CUT
		jumping = false
	if velocity.y >= 0.0:
		jumping = false
	if quick:
		velocity.y = min(velocity.y, 22.0)

	# --- hidden blocks are revealed by hitting them from below
	if velocity.y < 0.0:
		var head_y := global_position.y - H + velocity.y * delta
		for ox in [0.0, -W / 2 + 1, W / 2 - 1]:
			if level.try_reveal_hidden(Vector2(global_position.x + ox, head_y), global_position.y - H):
				velocity.y = 0.0
				jumping = false
				break

	# --- blast
	if fire_pressed and blast_ammo > 0 and blast_cd <= 0.0:
		blast_ammo -= 1
		blast_cd = 0.28
		level.spawn_blast(center() + Vector2(facing * 6, 0), facing)

	var vy_before := velocity.y
	var bottom_before := global_position.y
	move_and_slide()

	if vy_before < 0.0 and is_on_ceiling():
		level.bump_from_below(Vector2(global_position.x, global_position.y - H - 4), self)
		jumping = false

	if is_on_floor() and not _was_on_floor and vy_before > 220.0:
		Res.burst(level.fx_root(), global_position, Color("e8e0d0"), 4, 30, 0.25, 50)
	_was_on_floor = is_on_floor()

	_hazards(delta)
	if not dead:
		_interact(vy_before, bottom_before, jump_held)
	_animate()


func _timers(delta: float) -> void:
	invuln = max(0.0, invuln - delta)
	hurt_time = max(0.0, hurt_time - delta)
	speed_t = max(0.0, speed_t - delta)
	mega_t = max(0.0, mega_t - delta)
	magnet_t = max(0.0, magnet_t - delta)
	blast_cd = max(0.0, blast_cd - delta)
	swim_cd = max(0.0, swim_cd - delta)
	if head_in_water:
		air -= delta
		if air <= 0.0:
			air = 0.0
			drown_t -= delta
			if drown_t <= 0.0:
				drown_t = 1.5
				hurt(global_position.x, true)
	else:
		air = min(AIR_MAX, air + delta * 6.0)
		drown_t = 0.0
	if speed_t > 0.0 and Engine.get_physics_frames() % 4 == 0 and abs(velocity.x) > 60:
		Res.burst(level.fx_root(), global_position + Vector2(-facing * 4, -6), Color("ffd23f"), 1, 10, 0.3, 0, 1.5)


func _hazards(_delta: float) -> void:
	if global_position.y > level.bottom_y() + 40.0:
		die()
		return
	var r := rect()
	if level.rect_touches(r.grow(-2), "L", 6.0):
		die()
		return
	if level.rect_touches(r.grow(-1), "^", 8.0):
		hurt(global_position.x - facing * 4.0)
		if not dead:
			velocity.y = -260.0


func _interact(vy_before: float, bottom_before: float, jump_held: bool) -> void:
	var r := rect()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.alive or not e.active:
			continue
		var er: Rect2 = e.rect()
		if not r.intersects(er):
			continue
		var from_above := vy_before > 0.0 and bottom_before <= er.position.y + 7.0
		if from_above and e.on_stomp(self):
			stomp_chain += 1
			velocity.y = -(STOMP_BOUNCE + (130.0 if jump_held else 0.0))
			jumping = jump_held
			global_position.y = min(global_position.y, er.position.y)
			var pts: int = 100 * int(pow(2, min(stomp_chain, 6)))
			level.add_score(pts, e.global_position)
			if stomp_chain >= 7:
				level.add_life(e.global_position)
			continue
		if not e.on_side_touch(self) and e.harmful():
			hurt(er.get_center().x)
	for h in get_tree().get_nodes_in_group("hazards"):
		if r.grow(-1).intersects(h.rect()):
			hurt(h.global_position.x)
	var magnet := magnet_t > 0.0
	for p in get_tree().get_nodes_in_group("pickups"):
		if magnet and p.is_coin and p.global_position.distance_squared_to(center()) < 90.0 * 90.0:
			p.attract(center())
		if r.grow(2).intersects(p.rect()):
			p.collect(self)
	for t in get_tree().get_nodes_in_group("triggers"):
		if r.intersects(t.rect()):
			t.on_touch(self)


func hurt(from_x: float, ignore_invuln := false) -> void:
	if dead or finished:
		return
	if invuln > 0.0 and not ignore_invuln:
		return
	if shield:
		shield = false
		invuln = 1.0
		Audio.sfx("shield")
		Res.burst(level.fx_root(), center(), Color("8fe0ff"), 14, 100, 0.5, 0)
		queue_redraw()
		return
	hp -= 1
	level.camera_shake(0.2, 3.0)
	if hp <= 0:
		die()
		return
	Audio.sfx("hurt")
	invuln = 1.6
	hurt_time = 0.3
	var push := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(push * 140.0, -220.0)


func die() -> void:
	if dead or finished:
		return
	dead = true
	hp = 0
	velocity = Vector2(0, -320)
	collision_mask = 0
	sprite.play("hurt")
	sprite.visible = true
	z_index = 40
	Audio.stop_music()
	Audio.sfx("death")
	level.on_player_dead()


func finish() -> void:
	finished = true
	input_enabled = false
	sprite.play("victory")


func apply_power(kind: String) -> void:
	match kind:
		"speed":
			speed_t = SPEED_TIME
		"shield":
			shield = true
			Audio.sfx("shield")
		"mega":
			mega_t = MEGA_TIME
		"blast":
			blast_ammo = min(blast_ammo + 8, 20)
		"magnet":
			magnet_t = MAGNET_TIME
		"life":
			level.add_life(global_position)
			return
		"heart":
			hp = min(MAX_HP, hp + 1)
	Audio.sfx("powerup")
	Res.burst(level.fx_root(), center(), Color("ffd23f"), 16, 90, 0.6, 0)
	queue_redraw()


func spring_launch(v: float) -> void:
	velocity.y = -v
	jumping = false
	coyote = 0.0
	buffer = 0.0
	stomp_chain = 0
	Audio.sfx("jump", 0.7)
	Res.burst(level.fx_root(), global_position, Color("ff8aa0"), 6, 60, 0.3, 50)


func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	jumping = false


func _animate() -> void:
	var anim := "idle"
	if dead or hurt_time > 0.0:
		anim = "hurt"
	elif finished:
		anim = "victory" if is_on_floor() else "jump"
	elif in_water and not is_on_floor():
		anim = "swim"
	elif not is_on_floor():
		anim = "jump" if velocity.y < 0.0 else "fall"
	elif abs(velocity.x) > 8.0:
		anim = "run"
		sprite.speed_scale = clamp(abs(velocity.x) / WALK, 0.6, 1.8)
	if anim != "run":
		sprite.speed_scale = 1.0
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = facing < 0
	if invuln > 0.0 and not dead:
		sprite.modulate.a = 0.35 if int(invuln * 16.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0
	if mega_t > 0.0:
		sprite.modulate = Color(0.75, 1.0, 0.75, sprite.modulate.a)
	elif speed_t > 0.0:
		sprite.modulate = Color(1.0, 1.0, 0.7, sprite.modulate.a)
	else:
		sprite.modulate = Color(1, 1, 1, sprite.modulate.a)
	if shield or magnet_t > 0.0:
		queue_redraw()


func _draw() -> void:
	if shield:
		var a := 0.55 + 0.25 * sin(Time.get_ticks_msec() / 120.0)
		draw_arc(Vector2(0, -7), 11.0, 0, TAU, 24, Color(0.56, 0.88, 1.0, a), 1.5)
	if magnet_t > 0.0:
		var r := 14.0 + fmod(Time.get_ticks_msec() / 40.0, 10.0)
		draw_arc(Vector2(0, -7), r, 0, TAU, 24, Color(1.0, 0.3, 0.4, 0.35), 1.0)
