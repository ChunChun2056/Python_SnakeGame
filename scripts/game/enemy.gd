extends CharacterBody2D
## Regular enemies. One script, several behaviours selected by `kind`.
## States: patrol -> detect -> attack -> recover, plus shell/roll for
## armored rollers and defeated for all.

const Res = preload("res://scripts/game/res.gd")

const KIND_BY_CHAR := {"e": "walker", "r": "roller", "f": "flyer", "h": "hopper", "G": "ghost",
	"y": "yeti", "n": "fish", "m": "magma"}
const ANIMS := {
	"walker": {"walk": [0, 1], "dead": [2]},
	"roller": {"walk": [0, 1], "shell": [2], "roll": [2, 3]},
	"flyer": {"fly": [0, 1]},
	"hopper": {"idle": [0], "jump": [1]},
	"ghost": {"chase": [0], "shy": [1]},
	"yeti": {"walk": [0, 1], "throw": [2]},
	"fish": {"swim": [0, 1]},
	"magma": {"walk": [0, 1], "shoot": [2]},
}
## Per-world tints give every world its own enemy variants.
const WORLD_TINT := [Color(1, 1, 1), Color(1.15, 0.95, 0.7), Color(0.75, 0.85, 1.2), Color(1.1, 1.1, 1.25),
	Color(0.85, 1.0, 1.25), Color(0.7, 1.1, 1.05), Color(1.3, 0.75, 0.65), Color(0.85, 0.7, 1.15)]

var kind := "walker"
var level: Node
var alive := true
var active := false
var state := "patrol"
var state_t := 0.0
var dir := -1.0
var speed := 30.0
var flying := false
var home := Vector2.ZERO
var size := Vector2(12, 12)
var grace := 0.0
var attack_cd := 1.0
var sprite: AnimatedSprite2D
var _t := 0.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 4.0
	home = global_position
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	match kind:
		"flyer", "ghost", "fish":
			flying = true
	match kind:
		"roller":
			size = Vector2(13, 11)
			speed = 26.0
		"hopper":
			size = Vector2(13, 10)
		"yeti":
			size = Vector2(12, 13)
			speed = 22.0
		"magma":
			size = Vector2(12, 13)
			speed = 14.0
		"flyer":
			speed = 32.0
		"ghost":
			size = Vector2(11, 12)
			speed = 34.0
		"fish":
			size = Vector2(13, 8)
			speed = 28.0
	rs.size = size
	shape.shape = rs
	shape.position = Vector2(0, -size.y / 2)
	add_child(shape)
	if flying:
		collision_mask = 0
	sprite = Res.sprite("enemy_" + kind, ANIMS[kind], 5.0)
	sprite.position = Vector2(0, -8)
	sprite.modulate = WORLD_TINT[clamp(level.world - 1, 0, 7)] if kind in ["walker", "flyer", "roller", "hopper"] else Color.WHITE
	if kind == "ghost":
		sprite.modulate.a = 0.85
	add_child(sprite)
	_t = randf() * 6.0
	attack_cd = 0.5 + randf()


func rect() -> Rect2:
	return Rect2(global_position.x - size.x / 2, global_position.y - size.y, size.x, size.y)


func harmful() -> bool:
	if not alive:
		return false
	if state == "shell":
		return false
	if state == "roll" and grace > 0.0:
		return false
	return true


func _player():
	return level.player


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not active:
		if level.near_camera(global_position, 40.0):
			active = true
		else:
			return
	elif not level.near_camera(global_position, 160.0) and state != "roll":
		return
	_t += delta
	state_t -= delta
	grace = max(0.0, grace - delta)
	attack_cd -= delta
	var p = _player()
	var to_p: Vector2 = (p.center() - global_position) if p else Vector2(9999, 0)
	match kind:
		"walker":
			_walker(delta, to_p)
		"roller":
			_roller(delta)
		"flyer":
			_flyer(delta, to_p)
		"hopper":
			_hopper(delta, to_p)
		"ghost":
			_ghost(delta, to_p, p)
		"yeti":
			_yeti(delta, to_p)
		"fish":
			_fish(delta, to_p)
		"magma":
			_magma(delta, to_p)
	if global_position.y > level.bottom_y() + 64:
		queue_free()


# ------------------------------------------------------------------ helpers
func _gravity(delta: float) -> void:
	velocity.y = min(velocity.y + 1000.0 * delta, 400.0)


func _walk(delta: float, spd: float, ledge_check := true) -> void:
	velocity.x = dir * spd
	_gravity(delta)
	move_and_slide()
	if is_on_wall():
		dir = -dir
	elif ledge_check and is_on_floor():
		var ahead := global_position + Vector2(dir * (size.x / 2 + 2), 4)
		if not level.is_ground_at(ahead):
			dir = -dir
	_face(dir)


func _face(d: float) -> void:
	if d == 0.0:
		return
	var faces_right := kind == "roller" or kind == "fish"
	sprite.flip_h = (d > 0.0) != faces_right


func _player_near(to_p: Vector2, dx: float, dy: float) -> bool:
	return abs(to_p.x) < dx and abs(to_p.y) < dy and not level.player.dead


# ------------------------------------------------------------------ behaviours
func _walker(delta: float, to_p: Vector2) -> void:
	match state:
		"patrol":
			_walk(delta, speed)
			if level.world >= 2 and _player_near(to_p, 80, 24) and attack_cd <= 0.0:
				state = "detect"
				state_t = 0.35
				velocity.y = -120.0
		"detect":
			_walk(delta, 0.0)
			if state_t <= 0.0:
				dir = sign(to_p.x) if to_p.x != 0 else dir
				state = "attack"
				state_t = 1.6
		"attack":
			_walk(delta, speed * 1.9)
			if state_t <= 0.0:
				state = "recover"
				state_t = 1.0
		"recover":
			_walk(delta, speed * 0.5)
			if state_t <= 0.0:
				state = "patrol"
				attack_cd = 2.5


func _roller(delta: float) -> void:
	match state:
		"patrol":
			_walk(delta, speed)
			sprite.play("walk")
		"shell":
			velocity.x = 0.0
			_gravity(delta)
			move_and_slide()
			sprite.play("shell")
			sprite.position.x = (sin(_t * 40.0) * 1.0) if state_t < 1.2 else 0.0
			if state_t <= 0.0:
				sprite.position.x = 0
				state = "patrol"
				velocity.y = -150
		"roll":
			velocity.x = dir * 210.0
			_gravity(delta)
			move_and_slide()
			if is_on_wall():
				dir = -dir
				Audio.sfx("bump")
			sprite.play("roll")
			sprite.speed_scale = 3.0
			var r := rect()
			for e in get_tree().get_nodes_in_group("enemies"):
				if e != self and e.alive and e.active and r.intersects(e.rect()):
					e.knock(dir)
					level.add_score(200, e.global_position)


func _flyer(delta: float, to_p: Vector2) -> void:
	match state:
		"patrol":
			global_position.x = home.x + sin(_t * 0.9) * 40.0
			global_position.y = home.y + sin(_t * 3.0) * 6.0
			if level.world >= 3 and _player_near(to_p, 70, 90) and attack_cd <= 0.0 and to_p.y > 0:
				state = "attack"
				state_t = 1.2
				velocity = to_p.normalized() * 70.0
		"attack":
			global_position += velocity * delta
			if state_t <= 0.0:
				state = "recover"
		"recover":
			var back := Vector2(home.x + sin(_t * 0.9) * 40.0, home.y)
			global_position = global_position.move_toward(back, 40.0 * delta)
			if global_position.distance_to(back) < 2.0:
				state = "patrol"
				attack_cd = 3.0
	_face(cos(_t * 0.9) if state == "patrol" else velocity.x)


func _hopper(delta: float, to_p: Vector2) -> void:
	_gravity(delta)
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, 600 * delta)
		sprite.play("idle")
		if state == "attack" and state_t <= 0.0:
			state = "recover"
			state_t = 0.9
		elif state != "attack" and state_t <= 0.0:
			var near := _player_near(to_p, 110, 60)
			dir = sign(to_p.x) if near and to_p.x != 0 else -dir
			velocity = Vector2(dir * (75.0 if near else 30.0), -300.0 if near else -180.0)
			state = "attack"
			state_t = 0.3
	else:
		sprite.play("jump")
	move_and_slide()
	if is_on_wall():
		dir = -dir
		velocity.x = -velocity.x
	_face(dir)


func _ghost(delta: float, to_p: Vector2, p) -> void:
	if p == null:
		return
	var looking: bool = (p.facing > 0 and to_p.x < 0) or (p.facing < 0 and to_p.x > 0)
	if state == "recover":
		sprite.play("shy")
		if state_t <= 0.0:
			state = "patrol"
		return
	if _player_near(to_p, 170, 120):
		if looking:
			state = "detect"
			sprite.play("shy")
			sprite.modulate.a = 0.55
		else:
			state = "attack"
			sprite.play("chase")
			sprite.modulate.a = 0.85
			global_position += to_p.normalized() * speed * delta
			_face(to_p.x)
	else:
		state = "patrol"
		sprite.play("chase")
		global_position.y = home.y + sin(_t * 2.0) * 5.0


func _yeti(delta: float, to_p: Vector2) -> void:
	match state:
		"patrol":
			_walk(delta, speed)
			sprite.play("walk")
			if _player_near(to_p, 130, 60) and attack_cd <= 0.0:
				state = "attack"
				state_t = 0.5
				dir = sign(to_p.x) if to_p.x != 0 else dir
				_face(dir)
		"attack":
			_walk(delta, 0.0)
			sprite.play("throw")
			if state_t <= 0.0:
				var v := Vector2(clamp(to_p.x * 1.1, -150, 150), -230)
				level.spawn_projectile("snow", global_position + Vector2(0, -14), v, 700.0)
				state = "recover"
				state_t = 0.8
		"recover":
			_walk(delta, 0.0)
			sprite.play("walk")
			if state_t <= 0.0:
				state = "patrol"
				attack_cd = 2.4


func _fish(delta: float, to_p: Vector2) -> void:
	var in_water: bool = level.is_water(level.char_at_pos(global_position + Vector2(0, -4)))
	match state:
		"patrol":
			global_position.x += dir * speed * delta
			global_position.y = home.y + sin(_t * 2.0) * 4.0
			if abs(global_position.x - home.x) > 40:
				dir = -sign(global_position.x - home.x)
			if level.solid_at(global_position + Vector2(dir * 9, -4)):
				dir = -dir
			if _player_near(to_p, 90, 50) and attack_cd <= 0.0 and level.player.in_water:
				state = "detect"
				state_t = 0.4
		"detect":
			sprite.position.x = sin(_t * 50.0)
			if state_t <= 0.0:
				sprite.position.x = 0
				velocity = to_p.normalized() * 125.0
				dir = sign(velocity.x) if velocity.x != 0 else dir
				state = "attack"
				state_t = 0.7
		"attack":
			var nxt := global_position + velocity * delta
			if level.solid_at(nxt + Vector2(0, -4)) or not level.is_water(level.char_at_pos(nxt + Vector2(0, -4))):
				state_t = 0.0
			else:
				global_position = nxt
			if state_t <= 0.0:
				state = "recover"
				state_t = 1.2
		"recover":
			global_position = global_position.move_toward(home, 30.0 * delta)
			if state_t <= 0.0:
				state = "patrol"
				attack_cd = 2.0
	if not in_water and state == "patrol":
		global_position.y += 40.0 * delta
	_face(dir)


func _magma(delta: float, to_p: Vector2) -> void:
	match state:
		"patrol":
			_walk(delta, speed)
			sprite.play("walk")
			if _player_near(to_p, 150, 40) and attack_cd <= 0.0:
				state = "attack"
				state_t = 0.6
				dir = sign(to_p.x) if to_p.x != 0 else dir
				_face(dir)
		"attack":
			_walk(delta, 0.0)
			sprite.play("shoot")
			sprite.position.x = sin(_t * 60.0) * 0.7
			if state_t <= 0.0:
				sprite.position.x = 0
				level.spawn_projectile("fire", global_position + Vector2(dir * 8, -9), Vector2(dir * 120, 0), 0.0)
				Audio.sfx("shoot")
				state = "recover"
				state_t = 0.6
		"recover":
			_walk(delta, 0.0)
			if state_t <= 0.0:
				state = "patrol"
				attack_cd = 2.6


# ------------------------------------------------------------------ damage
## Called when the player lands on top. Return true to bounce the player.
func on_stomp(player) -> bool:
	match kind:
		"ghost":
			state = "recover"
			state_t = 1.0
			Audio.sfx("bump")
			return true
		"roller":
			if state == "shell":
				_kick(player)
				return true
			Audio.sfx("stomp")
			state = "shell"
			state_t = 6.0
			velocity.x = 0
			Res.burst(level.fx_root(), global_position + Vector2(0, -8), Color("ffffff"), 6, 60, 0.3, 100)
			return true
	_defeat(true)
	return true


## Called on side contact. Return true if the touch was harmless.
func on_side_touch(player) -> bool:
	if kind == "roller" and state == "shell":
		_kick(player)
		return true
	return false


func _kick(player) -> void:
	dir = 1.0 if global_position.x >= player.global_position.x else -1.0
	state = "roll"
	grace = 0.3
	Audio.sfx("kick")
	level.add_score(100, global_position)


func hit_by_blast(from_dir: float) -> void:
	knock(from_dir)
	level.add_score(200, global_position)


func knock(from_dir: float) -> void:
	if not alive:
		return
	alive = false
	remove_from_group("enemies")
	Audio.sfx("stomp", 0.8)
	Res.burst(level.fx_root(), global_position + Vector2(0, -8), Color("ffffff"), 8, 80, 0.4, 100)
	_tumble(from_dir)


func _tumble(from_dir: float) -> void:
	collision_layer = 0
	collision_mask = 0
	sprite.flip_v = true
	sprite.speed_scale = 0
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector2(from_dir * 30, -24), 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", position + Vector2(from_dir * 50, 200), 0.9).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _defeat(stomped: bool) -> void:
	alive = false
	remove_from_group("enemies")
	Audio.sfx("stomp")
	Res.burst(level.fx_root(), global_position + Vector2(0, -6), Color("ffffff"), 8, 70, 0.35, 120)
	collision_layer = 0
	collision_mask = 0
	if kind == "walker" and stomped:
		sprite.play("dead")
		var tw := create_tween()
		tw.tween_interval(0.4)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.2)
		tw.tween_callback(queue_free)
	else:
		_tumble(0.0)
