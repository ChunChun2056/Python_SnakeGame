extends AnimatableBody2D
## Moving platforms (horizontal/vertical) and crumbling platforms.

var kind := "move_h"   # move_h, move_v, crumble
var level: Node
var amplitude := 48.0
var period := 4.0
var width_tiles := 3
var home := Vector2.ZERO
var _t := 0.0
var _state := "idle"
var _state_t := 0.0
var _shape: CollisionShape2D
var _visual: Node2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = kind != "crumble"
	home = position
	_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	var w := width_tiles * 16.0
	rs.size = Vector2(w, 6)
	_shape.shape = rs
	_shape.position = Vector2(0, 3)
	_shape.one_way_collision = true
	add_child(_shape)
	_visual = Node2D.new()
	add_child(_visual)
	var frame := 19 if kind == "crumble" else 6
	for i in width_tiles:
		var s := Sprite2D.new()
		s.texture = level.tile_texture
		s.region_enabled = true
		s.region_rect = Rect2(frame * 16, 0, 16, 16)
		s.centered = false
		s.position = Vector2(-w / 2 + i * 16, 0)
		_visual.add_child(s)
	_t = fmod(position.x * 0.01, period)


func _physics_process(delta: float) -> void:
	match kind:
		"move_h":
			_t += delta
			position = home + Vector2(sin(_t / period * TAU) * amplitude, 0)
		"move_v":
			_t += delta
			position = home + Vector2(0, sin(_t / period * TAU) * amplitude)
		"crumble":
			_crumble(delta)


func _crumble(delta: float) -> void:
	_state_t -= delta
	match _state:
		"idle":
			var p = level.player
			if p and p.is_on_floor() and not p.dead:
				var feet: Vector2 = p.global_position
				if abs(feet.x - global_position.x) < 8 + 5 and abs(feet.y - global_position.y) < 2.0:
					_state = "shake"
					_state_t = 0.45
					Audio.sfx("crumble", 1.3)
		"shake":
			_visual.position.x = sin(_state_t * 80.0) * 1.0
			if _state_t <= 0.0:
				_state = "fall"
				_state_t = 2.6
				_shape.set_deferred("disabled", true)
				var tw := create_tween()
				tw.tween_property(_visual, "position:y", 60.0, 0.6).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(_visual, "modulate:a", 0.0, 0.6)
		"fall":
			if _state_t <= 0.0:
				_state = "idle"
				_visual.position = Vector2.ZERO
				_shape.set_deferred("disabled", false)
				var tw := create_tween()
				tw.tween_property(_visual, "modulate:a", 1.0, 0.3)
