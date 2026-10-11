extends CharacterBody2D
## World bosses. Each boss cycles through an attack pattern built from a
## shared set of moves (walk, charge, jump, shoot, fly, swoop, teleport,
## summon). The final boss (umbra) has three phases.

const Res = preload("res://scripts/game/res.gd")

const HP := {"walker": 3, "hopper": 3, "ghost": 4, "flyer": 4, "yeti": 5, "fish": 5, "magma": 6, "umbra": 3}
const NAMES := {"walker": "Grumble King", "hopper": "Dune Tyrant", "ghost": "Wailing Shade",
	"flyer": "Storm Beetle", "yeti": "Frost Colossus", "fish": "Snapfin Leviathan",
	"magma": "Magma Lord", "umbra": "Umbra King"}
const PATTERNS := {
	"walker": ["walk", "charge", "walk", "jump"],
	"hopper": ["jump", "jump", "shoot", "jump", "walk"],
	"ghost": ["fly", "shoot", "fly", "land"],
	"flyer": ["fly", "swoop", "fly", "swoop", "land"],
	"yeti": ["walk", "shoot", "jump", "shoot"],
	"fish": ["jump", "jump", "shoot", "walk", "jump"],
	"magma": ["walk", "shoot", "jump", "charge", "shoot"],
	"umbra1": ["teleport", "shoot", "walk", "jump"],
	"umbra2": ["fly", "shoot", "swoop", "fly", "shoot", "land"],
	"umbra3": ["teleport", "shoot", "summon", "jump", "shoot", "charge"],
}
const ANIMS := {
	"walker": {"move": [0, 1]}, "roller": {"move": [0, 1]}, "flyer": {"move": [0, 1]},
	"hopper": {"move": [0, 1]}, "ghost": {"move": [0, 1]}, "yeti": {"move": [0, 1], "attack": [2]},
	"fish": {"move": [0, 1]}, "magma": {"move": [0, 1], "attack": [2]}, "umbra": {"move": [0, 1], "attack": [2]},
}

var kind := "walker"
var level: Node
var alive := true
var active := false
var hp := 3
var max_hp := 3
var phase := 1
var state := "idle"
var state_t := 0.0
var invuln := 0.0
var dir := -1.0
var flying := false
var size := Vector2(30, 30)
var scale_f := 2.5
var sprite: AnimatedSprite2D
var _pattern: Array = []
var _step := 0
var _t := 0.0
var _shots := 0
var _target := Vector2.ZERO
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 6.0
	if kind == "umbra":
		scale_f = 3.0
	max_hp = HP.get(kind, 3)
	hp = max_hp
	size = Vector2(12, 13) * scale_f
	_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	_shape.shape = rs
	_shape.position = Vector2(0, -size.y / 2)
	add_child(_shape)
	sprite = Res.sprite("boss_" + kind, ANIMS[kind], 5.0)
	sprite.scale = Vector2(scale_f, scale_f)
	sprite.position = Vector2(0, -8 * scale_f)
	add_child(sprite)
	_set_pattern()
	z_index = 1


func _set_pattern() -> void:
	_pattern = PATTERNS[kind + str(phase)] if kind == "umbra" else PATTERNS[kind]
	_step = 0


func display_name() -> String:
	return NAMES.get(kind, "Boss")


func total_hp_fraction() -> float:
	if kind == "umbra":
		return (float(phase - 1) * max_hp + (max_hp - hp)) / (3.0 * max_hp)
	return float(max_hp - hp) / max_hp


func rect() -> Rect2:
	return Rect2(global_position.x - size.x / 2, global_position.y - size.y, size.x, size.y)


func harmful() -> bool:
	return alive and active and state != "dying"


func start_fight() -> void:
	active = true
	state = "intro"
	state_t = 1.2
	Audio.sfx("boss_hit", 0.6)


func _speed() -> float:
	var s: float = 55.0 + (level.world - 1) * 5.0
	if kind == "umbra":
		s += (phase - 1) * 20.0
	return s


func _physics_process(delta: float) -> void:
	if not alive or not active:
		if not alive:
			return
		_gravity(delta)
		move_and_slide()
		return
	_t += delta
	state_t -= delta
	invuln = max(0.0, invuln - delta)
	sprite.modulate.a = 0.4 if invuln > 0.0 and int(invuln * 14.0) % 2 == 0 else 1.0
	var p = level.player
	var px: float = p.global_position.x if p else global_position.x
	match state:
		"intro":
			sprite.position.x = sin(_t * 50.0) * 1.5
			_ground_move(delta, 0)
			if state_t <= 0.0:
				sprite.position.x = 0
				_next()
		"walk":
			dir = sign(px - global_position.x) if abs(px - global_position.x) > 4 else dir
			_ground_move(delta, dir * _speed())
			if state_t <= 0.0:
				_next()
		"charge_wind":
			sprite.position.x = sin(_t * 60.0) * 1.5
			_ground_move(delta, 0)
			if state_t <= 0.0:
				sprite.position.x = 0
				state = "charge"
				state_t = 2.5
		"charge":
			_ground_move(delta, dir * _speed() * 2.8)
			if is_on_wall() or state_t <= 0.0 or _at_arena_edge():
				level.camera_shake(0.25, 3.0)
				Audio.sfx("thud")
				state = "stun"
				state_t = 1.2
		"stun":
			_ground_move(delta, 0)
			sprite.rotation = sin(_t * 20.0) * 0.08
			if state_t <= 0.0:
				sprite.rotation = 0
				_next()
		"jump":
			_gravity(delta)
			move_and_slide()
			if is_on_floor() and state_t <= 0.0:
				velocity.x = 0
				level.camera_shake(0.2, 3.0)
				Audio.sfx("thud")
				Res.burst(level.fx_root(), global_position, Color("e8e0d0"), 12, 90, 0.5, 200)
				if kind in ["hopper", "yeti", "umbra"]:
					for d in [-1, 1]:
						level.spawn_projectile(_proj_kind(), global_position + Vector2(d * size.x / 2, -6), Vector2(d * 110, 0), 0.0)
				state = "stun"
				state_t = 0.5
		"shoot":
			_ground_or_hover(delta)
			if state_t <= 0.0:
				_fire_volley(p)
				_shots -= 1
				state_t = 0.45
				if _shots <= 0:
					state = "stun"
					state_t = 0.6 if not flying else 0.3
		"fly":
			flying = true
			collision_mask = 0
			var cx: float = (level.arena_left() + level.arena_right()) / 2.0
			var tx: float = cx + sin(_t * 1.1) * (level.arena_right() - level.arena_left()) * 0.35
			var ty: float = level.arena_floor() - 110.0 + sin(_t * 2.3) * 10.0
			global_position = global_position.move_toward(Vector2(tx, ty), 120.0 * delta)
			dir = sign(px - global_position.x)
			if state_t <= 0.0:
				_next()
		"swoop":
			global_position = global_position.move_toward(_target, 210.0 * delta)
			if global_position.distance_to(_target) < 3.0:
				state = "fly"
				state_t = 1.4
		"land":
			flying = true
			collision_mask = 0
			global_position.y = move_toward(global_position.y, level.arena_floor(), 140.0 * delta)
			if global_position.y >= level.arena_floor() - 0.5:
				global_position.y = level.arena_floor()
				flying = false
				collision_mask = 1
				state = "stun"
				state_t = 2.2
				Audio.sfx("thud")
		"teleport_out":
			sprite.modulate.a = max(0.0, state_t / 0.4)
			if state_t <= 0.0:
				var left: bool = px > (level.arena_left() + level.arena_right()) / 2.0
				global_position.x = level.arena_left() + 40.0 if left else level.arena_right() - 40.0
				global_position.y = level.arena_floor()
				velocity = Vector2.ZERO
				state = "teleport_in"
				state_t = 0.4
		"teleport_in":
			sprite.modulate.a = 1.0 - max(0.0, state_t / 0.4)
			if state_t <= 0.0:
				sprite.modulate.a = 1.0
				_next()
		"hurt":
			_gravity(delta)
			move_and_slide()
			if state_t <= 0.0 and (is_on_floor() or flying):
				velocity.x = 0
				_next()
		"dying":
			pass
	_face(px)


func _face(px: float) -> void:
	var faces_right := kind == "roller" or kind == "fish"
	var d := sign(px - global_position.x)
	if d != 0:
		sprite.flip_h = (d > 0) != faces_right


func _gravity(delta: float) -> void:
	velocity.y = min(velocity.y + 1000.0 * delta, 450.0)


func _ground_move(delta: float, vx: float) -> void:
	velocity.x = vx
	_gravity(delta)
	move_and_slide()
	global_position.x = clamp(global_position.x, level.arena_left() + size.x / 2, level.arena_right() - size.x / 2)


func _ground_or_hover(delta: float) -> void:
	if flying:
		global_position.y += sin(_t * 3.0) * 0.3
	else:
		_ground_move(delta, 0)


func _at_arena_edge() -> bool:
	return global_position.x <= level.arena_left() + size.x / 2 + 1 or global_position.x >= level.arena_right() - size.x / 2 - 1


func _proj_kind() -> String:
	match kind:
		"yeti":
			return "snow"
		"ghost", "umbra", "flyer":
			return "orb"
	return "fire"


func _fire_volley(p) -> void:
	if p == null:
		return
	Audio.sfx("shoot")
	var origin := global_position + Vector2(0, -size.y * 0.6)
	var to: Vector2 = (p.center() - origin).normalized()
	var spread := [0.0] if kind in ["walker", "hopper"] else [-0.25, 0.0, 0.25]
	if kind == "umbra" and phase == 3:
		spread = [-0.4, -0.2, 0.0, 0.2, 0.4]
	for a in spread:
		var v: Vector2 = to.rotated(a) * (120.0 + level.world * 6.0)
		var g := 0.0
		if kind == "yeti":
			v = Vector2(sign(to.x) * (90.0 + abs(a) * 200.0), -260.0)
			g = 700.0
		level.spawn_projectile(_proj_kind(), origin, v, g)


func _next() -> void:
	var move: String = _pattern[_step % _pattern.size()]
	_step += 1
	sprite.play("attack" if move == "shoot" and sprite.sprite_frames.has_animation("attack") else "move")
	var p = level.player
	var px: float = p.global_position.x if p else global_position.x
	match move:
		"walk":
			state = "walk"
			state_t = 1.8
		"charge":
			dir = sign(px - global_position.x) if px != global_position.x else -dir
			state = "charge_wind"
			state_t = 0.6
		"jump":
			if flying:
				_next()
				return
			state = "jump"
			state_t = 0.15
			var dx: float = clamp(px - global_position.x, -170.0, 170.0)
			velocity = Vector2(dx / 0.85, -430.0)
		"shoot":
			state = "shoot"
			state_t = 0.5
			_shots = 2 if kind != "umbra" else 1 + phase
		"fly":
			state = "fly"
			state_t = 3.0
			flying = true
			collision_mask = 0
		"swoop":
			if not flying:
				_next()
				return
			state = "swoop"
			_target = Vector2(px, level.arena_floor() - 10.0)
		"land":
			state = "land"
		"teleport":
			state = "teleport_out"
			state_t = 0.4
			Audio.sfx("secret", 0.6)
		"summon":
			state = "stun"
			state_t = 1.0
			level.spawn_enemy("e", Vector2(level.arena_left() + 24, level.arena_floor() - 40))
			level.spawn_enemy("e", Vector2(level.arena_right() - 24, level.arena_floor() - 40))
			Audio.sfx("powerup", 0.5)


func on_stomp(_player) -> bool:
	if not alive or state == "dying":
		return false
	if invuln > 0.0:
		return true
	_damage()
	return true


func on_side_touch(_player) -> bool:
	return false


func hit_by_blast(_from_dir: float) -> void:
	if invuln > 0.0 or not alive:
		return
	_damage()


func knock(_d: float) -> void:
	pass


func _damage() -> void:
	hp -= 1
	invuln = 1.3
	Audio.sfx("boss_hit")
	level.camera_shake(0.3, 4.0)
	Res.burst(level.fx_root(), global_position + Vector2(0, -size.y / 2), Color("ffffff"), 16, 120, 0.5, 100)
	if hp <= 0:
		if kind == "umbra" and phase < 3:
			phase += 1
			hp = max_hp
			_set_pattern()
			level.show_banner("Phase %d!" % phase)
			state = "teleport_out"
			state_t = 0.4
			invuln = 2.0
			return
		_die()
		return
	var p = level.player
	var away: float = sign(global_position.x - p.global_position.x) if p else 1.0
	if flying:
		state = "fly"
		state_t = 1.5
	else:
		state = "hurt"
		state_t = 0.3
		velocity = Vector2(away * 140.0, -260.0)


func _die() -> void:
	state = "dying"
	alive = false
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	var tw := create_tween()
	for i in 6:
		tw.tween_callback(func():
			Audio.sfx("break")
			level.camera_shake(0.15, 3.0)
			Res.burst(level.fx_root(), global_position + Vector2(randf_range(-16, 16), -randf_range(4, 30)),
				Color("ffd23f"), 14, 120, 0.6, 50, 3.0))
		tw.tween_interval(0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		level.boss_defeated(global_position)
		queue_free())
