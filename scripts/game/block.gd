extends StaticBody2D
## Bumpable blocks: bricks (break), coin blocks, power-up blocks and
## hidden blocks (invisible until hit from below).

const Res = preload("res://scripts/game/res.gd")

var kind := "brick"    # brick, coin, power, hidden
var level: Node
var cell := Vector2i.ZERO
var id := ""
var used := false
var revealed := true
var _spr: Sprite2D
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(16, 16)
	_shape.shape = rs
	add_child(_shape)
	_spr = Sprite2D.new()
	_spr.texture = level.tile_texture
	_spr.region_enabled = true
	add_child(_spr)
	if kind == "hidden":
		revealed = false
		_shape.disabled = true
		_spr.visible = false
	_refresh()


func _refresh() -> void:
	var frame := 2
	if used:
		frame = 4
	elif kind == "coin" or kind == "power":
		frame = 3
	elif kind == "hidden":
		frame = 4
	_spr.region_rect = Rect2(frame * 16, 0, 16, 16)


func set_used() -> void:
	used = true
	revealed = true
	_shape.disabled = false
	_spr.visible = true
	_refresh()


func reveal() -> void:
	set_used()
	level.grid_set(cell, "u")
	_bounce()
	level.mark_collected(id)
	level.add_life(global_position + Vector2(0, -16))
	Audio.sfx("secret")


func bump(player) -> void:
	if used:
		Audio.sfx("bump")
		return
	level.bump_enemies_above(global_position)
	match kind:
		"brick":
			Audio.sfx("break")
			Res.burst(level.fx_root(), global_position, level.brick_color, 12, 120, 0.7, 500, 3.0)
			level.add_score(50, global_position)
			level.grid_set(cell, ".")
			level.mark_collected(id)
			queue_free()
		"coin":
			set_used()
			_bounce()
			level.coin_pop(global_position + Vector2(0, -16))
			level.mark_collected(id)
		"power":
			set_used()
			_bounce()
			level.spawn_power_from_block(global_position + Vector2(0, -16), player)
			level.mark_collected(id)


func _bounce() -> void:
	var tw := create_tween()
	tw.tween_property(_spr, "position:y", -5.0, 0.07)
	tw.tween_property(_spr, "position:y", 0.0, 0.09)
