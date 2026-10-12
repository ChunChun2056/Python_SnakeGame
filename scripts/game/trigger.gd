extends Node2D
## Touch-activated objects: checkpoint, goal beacon, warp portal,
## tutorial sign and air-bubble vent.

const Res = preload("res://scripts/game/res.gd")

const SPRING_V := 560.0

var kind := "checkpoint"
var level: Node
var target := Vector2.ZERO   # warp destination (world position of feet)
var text := ""
var enabled := true
var activated := false
var _spr: Node2D
var _cool := 0.0


func _ready() -> void:
	add_to_group("triggers")
	match kind:
		"checkpoint":
			_spr = Res.sprite("checkpoint", {"off": [0], "on": [1, 2]}, 4.0, 16, 32)
			_spr.position = Vector2(0, -16)
		"goal":
			_spr = Res.sprite("goal", {"wave": [0, 1]}, 3.0, 24, 64)
			_spr.position = Vector2(4, -32)
		"warp":
			_spr = Res.sprite("warp", {"spin": [0, 1]}, 4.0)
			_spr.position = Vector2(0, -8)
		"spring":
			_spr = Res.sprite("spring", {"idle": [0], "boing": [1]}, 1.0)
			_spr.position = Vector2(0, -8)
		"sign":
			var s := Sprite2D.new()
			s.texture = Res.tex("sign")
			s.position = Vector2(0, -8)
			_spr = s
			z_index = -1
		"vent":
			_spr = Node2D.new()
			var p := CPUParticles2D.new()
			p.amount = 6
			p.lifetime = 2.0
			p.direction = Vector2.UP
			p.spread = 10.0
			p.gravity = Vector2(0, -20)
			p.initial_velocity_min = 15
			p.initial_velocity_max = 25
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.0
			p.color = Color(0.8, 0.95, 1.0, 0.8)
			p.position = Vector2(0, -2)
			_spr.add_child(p)
	add_child(_spr)
	if kind == "goal" and not enabled:
		visible = false


func rect() -> Rect2:
	match kind:
		"checkpoint":
			return Rect2(global_position.x - 6, global_position.y - 32, 12, 32)
		"goal":
			return Rect2(global_position.x - 4, global_position.y - 64, 12, 64)
		"sign":
			return Rect2(global_position.x - 20, global_position.y - 24, 40, 24)
		"vent":
			return Rect2(global_position.x - 8, global_position.y - 40, 16, 40)
		"spring":
			return Rect2(global_position.x - 7, global_position.y - 8, 14, 8)
	return Rect2(global_position.x - 6, global_position.y - 14, 12, 14)


func _process(delta: float) -> void:
	_cool = max(0.0, _cool - delta)


func on_touch(player) -> void:
	if not enabled:
		return
	match kind:
		"checkpoint":
			if activated:
				return
			activated = true
			(_spr as AnimatedSprite2D).play("on")
			Audio.sfx("checkpoint")
			Res.burst(level.fx_root(), global_position + Vector2(4, -24), Color("4caf50"), 14, 90, 0.6, 100)
			level.set_checkpoint(global_position)
		"goal":
			if activated:
				return
			activated = true
			level.complete(global_position)
		"warp":
			if _cool > 0.0:
				return
			_cool = 1.0
			level.warp_player(target)
		"sign":
			level.show_sign(text)
		"vent":
			player.air = player.AIR_MAX
		"spring":
			if player.velocity.y < 0.0 or _cool > 0.0:
				return
			_cool = 0.15
			player.spring_launch(SPRING_V)
			var a := _spr as AnimatedSprite2D
			a.play("boing")
			get_tree().create_timer(0.25).timeout.connect(func(): a.play("idle"))


func activate_goal() -> void:
	enabled = true
	visible = true
	Res.burst(level.fx_root(), global_position + Vector2(0, -32), Color("ffd23f"), 24, 120, 0.8, 0)


func set_active_visual() -> void:
	activated = true
	if _spr is AnimatedSprite2D and kind == "checkpoint":
		(_spr as AnimatedSprite2D).play("on")
