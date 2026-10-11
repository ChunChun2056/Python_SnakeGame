extends Node2D
## Environmental hazards: falling rock, crusher, spike ball, lava jumper.
## All are "hazards" group members exposing rect().

const Res = preload("res://scripts/game/res.gd")

var kind := "rock"
var level: Node
var state := "idle"
var state_t := 0.0
var vel := Vector2.ZERO
var home := Vector2.ZERO
var _spr: Node2D
var _t := 0.0
var _armed := true


func _ready() -> void:
	home = position
	match kind:
		"rock":
			var s := Sprite2D.new()
			s.texture = Res.tex("rock")
			_spr = s
		"crusher":
			var s := Sprite2D.new()
			s.texture = Res.tex("crusher")
			s.position = Vector2(0, 0)
			_spr = s
			state = "wait"
			state_t = 1.0 + fmod(position.x * 0.013, 1.5)
		"spikeball":
			var s := Sprite2D.new()
			s.texture = Res.tex("spikeball")
			_spr = s
			_t = position.x * 0.02
		"jumper":
			_spr = Res.sprite("projectiles", {"burn": [0, 1]}, 10.0, 8, 8)
			_spr.scale = Vector2(1.6, 1.6)
			state = "wait"
			state_t = 1.0 + fmod(position.x * 0.017, 1.5)
			visible = false
	add_child(_spr)
	if kind != "rock" and kind != "jumper":
		add_to_group("hazards")


func rect() -> Rect2:
	match kind:
		"crusher":
			return Rect2(global_position.x - 14, global_position.y - 15, 28, 30)
		"spikeball":
			return Rect2(global_position.x - 6, global_position.y - 6, 12, 12)
		"jumper":
			return Rect2(global_position.x - 5, global_position.y - 5, 10, 10)
	return Rect2(global_position.x - 6, global_position.y - 6, 12, 12)


func _physics_process(delta: float) -> void:
	if not level.near_camera(global_position, 200.0) and state != "fall":
		return
	_t += delta
	state_t -= delta
	match kind:
		"rock":
			_rock(delta)
		"crusher":
			_crusher(delta)
		"spikeball":
			position = home + Vector2(sin(_t * 1.6) * 40.0, cos(_t * 1.6) * 6.0)
			_spr.rotation += delta * 4.0
		"jumper":
			_jumper(delta)


func _rock(delta: float) -> void:
	var p = level.player
	match state:
		"idle":
			if p and abs(p.global_position.x - global_position.x) < 26 and p.global_position.y > global_position.y:
				state = "shake"
				state_t = 0.5
				Audio.sfx("crumble")
		"shake":
			_spr.position.x = sin(_t * 70.0) * 1.2
			if state_t <= 0.0:
				_spr.position.x = 0
				state = "fall"
				add_to_group("hazards")
		"fall":
			vel.y = min(vel.y + 900.0 * delta, 420.0)
			position += vel * delta
			if level.solid_at(global_position + Vector2(0, 8)) or global_position.y > level.bottom_y() + 32:
				Audio.sfx("thud")
				Res.burst(level.fx_root(), global_position, Color("8a7a6a"), 10, 90, 0.5, 400, 2.5)
				queue_free()


func _crusher(delta: float) -> void:
	match state:
		"wait":
			if state_t <= 0.0:
				state = "shake"
				state_t = 0.45
		"shake":
			_spr.position.x = sin(_t * 70.0) * 1.0
			if state_t <= 0.0:
				_spr.position.x = 0
				state = "slam"
				vel.y = 0
		"slam":
			vel.y = min(vel.y + 1600.0 * delta, 520.0)
			position.y += vel.y * delta
			if level.solid_at(global_position + Vector2(-10, 16)) or level.solid_at(global_position + Vector2(10, 16)):
				position.y = floor((position.y + 16) / 16.0) * 16.0 - 16.0
				state = "rest"
				state_t = 0.9
				Audio.sfx("thud")
				level.camera_shake(0.15, 2.0)
				Res.burst(level.fx_root(), global_position + Vector2(0, 16), Color("c9c2d6"), 10, 70, 0.4, 200)
		"rest":
			if state_t <= 0.0:
				state = "rise"
		"rise":
			position.y = move_toward(position.y, home.y, 50.0 * delta)
			if position.y <= home.y:
				state = "wait"
				state_t = 1.6


func _jumper(delta: float) -> void:
	match state:
		"wait":
			visible = false
			if state_t <= 0.4 and state_t > 0.38:
				Res.burst(level.fx_root(), home + Vector2(0, -4), Color("ffb020"), 5, 40, 0.4, 0)
			if state_t <= 0.0:
				state = "jump"
				visible = true
				position = home
				vel = Vector2(0, -400)
				add_to_group("hazards")
		"jump":
			vel.y += 700.0 * delta
			position += vel * delta
			_spr.flip_v = vel.y > 0
			if position.y >= home.y and vel.y > 0:
				state = "wait"
				state_t = 2.4
				remove_from_group("hazards")
				visible = false
