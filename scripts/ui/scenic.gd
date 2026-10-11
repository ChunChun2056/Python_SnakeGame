extends Control
## Animated parallax backdrop used behind menus.

var world := 1
var speed := 18.0
var _far: TextureRect
var _near: TextureRect
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sky := TextureRect.new()
	sky.texture = load("res://assets/bg/w%d_sky.png" % world)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	_far = _layer("far")
	_near = _layer("near")
	resized.connect(_fit)
	_fit()


func _layer(name_: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://assets/bg/w%d_%s.png" % [world, name_])
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _fit() -> void:
	var k: float = max(1.0, size.y / 256.0 * 0.55)
	for r in [_far, _near]:
		r.scale = Vector2(k, k)
		r.size = Vector2(size.x / k + 1024, 256)
		r.position.y = size.y - 256 * k


func _process(delta: float) -> void:
	_t += delta
	var k := _far.scale.x
	_far.position.x = -fmod(_t * speed * 0.4, 512.0) * k
	_near.position.x = -fmod(_t * speed, 512.0) * k
