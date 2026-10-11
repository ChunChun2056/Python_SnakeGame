extends Control
## Animated splash screen.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Res = preload("res://scripts/game/res.gd")

var _hero: TextureRect
var _frames: Array = []
var _t := 0.0
var _done := false


func _ready() -> void:
	UIKit.root(self)
	UIKit.background(self, Color("17122a"))
	var v := UIKit.center_column(self, 10)
	var title := UIKit.label("ADVENTURE QUEST", 34, UIKit.ACCENT)
	var sub := UIKit.label("Pixel Kingdom", 26, Color("8fe0ff"))
	var tag := UIKit.label("an original platform adventure", 14, Color("a89cc8"))
	for l in [title, sub, tag]:
		l.modulate.a = 0.0
		v.add_child(l)
	for i in [2, 3, 4, 3]:
		_frames.append(Res.atlas("hero", i))
	_hero = TextureRect.new()
	_hero.texture = _frames[0]
	_hero.size = Vector2(64, 64)
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_hero)
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(title, "scale", Vector2.ONE, 0.5).from(Vector2(0.6, 0.6))
	tw.tween_property(sub, "modulate:a", 1.0, 0.4)
	tw.tween_property(tag, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.4)
	tw.tween_callback(_finish)
	Audio.sfx("splash")


func _process(delta: float) -> void:
	_t += delta
	_hero.texture = _frames[int(_t * 10.0) % _frames.size()]
	_hero.position = Vector2(-64 + _t * 150.0, size.y * 0.68)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	Game.goto("res://scripts/ui/main_menu.gd")
