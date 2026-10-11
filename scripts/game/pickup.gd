extends Node2D
## Coins, gems, secret star gems and power-up items.

const Res = preload("res://scripts/game/res.gd")
const POWER_FRAMES := {"speed": 0, "shield": 1, "mega": 2, "blast": 3, "magnet": 4, "life": 5, "heart": 6}

var kind := "coin"      # coin, gem, star, power
var power := ""
var level: Node
var id := ""
var is_coin := false
var collected := false
var _base_y := 0.0
var _t := 0.0
var _attracted := false
var _spr: Node2D


func _ready() -> void:
	add_to_group("pickups")
	is_coin = kind == "coin"
	match kind:
		"coin":
			_spr = Res.sprite("coin", {"spin": [0, 1, 2, 3]}, 8.0)
		"gem":
			var s := Sprite2D.new()
			s.texture = Res.atlas("gems", 0)
			_spr = s
		"star":
			_spr = Res.sprite("gems", {"shine": [1, 2]}, 4.0)
		"power":
			var s := Sprite2D.new()
			s.texture = Res.atlas("powerups", POWER_FRAMES.get(power, 0))
			_spr = s
	add_child(_spr)
	_base_y = position.y
	_t = position.x * 0.05


func rect() -> Rect2:
	return Rect2(global_position.x - 6, global_position.y - 7, 12, 14)


func attract(target: Vector2) -> void:
	_attracted = true
	global_position = global_position.move_toward(target, 220.0 * get_physics_process_delta_time())


func _process(delta: float) -> void:
	if collected or _attracted:
		return
	_t += delta
	if kind != "coin":
		position.y = _base_y + sin(_t * 3.0) * 1.5


func collect(player) -> void:
	if collected:
		return
	collected = true
	remove_from_group("pickups")
	match kind:
		"coin":
			level.add_coin(global_position)
		"gem":
			level.add_gem(global_position)
		"star":
			level.add_secret(global_position)
		"power":
			player.apply_power(power)
	level.mark_collected(id)
	queue_free()
