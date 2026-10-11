extends Control
## Final victory screen with fireworks and a credits roll.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Res = preload("res://scripts/game/res.gd")
const Credits = preload("res://scripts/ui/credits.gd")

var _fx: Node2D
var _t := 0.0
var _scroll: VBoxContainer


func _ready() -> void:
	UIKit.root(self)
	UIKit.background(self, Color("0e0a1e"))
	clip_contents = true
	_fx = Node2D.new()
	add_child(_fx)
	var head := UIKit.vbox(8)
	head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	head.position.y = 40
	add_child(head)
	head.add_child(UIKit.label("VICTORY!", 40, UIKit.ACCENT))
	head.add_child(UIKit.label("The Umbra King is defeated and\nthe Pixel Kingdom shines again!", 18))
	var hero := Res.sprite("hero", {"win": [9, 0]}, 2.0)
	hero.scale = Vector2(5, 5)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 90)
	holder.add_child(hero)
	holder.resized.connect(func(): hero.position = Vector2(holder.size.x / 2, 45))
	head.add_child(holder)
	var total := 0
	for k in Game.data["levels"]:
		total += int(Game.data["levels"][k].get("best_score", 0))
	head.add_child(UIKit.label("Stars  %d / %d" % [Game.total_stars(), Game.WORLDS * Game.LEVELS * 3], 18, UIKit.ACCENT))
	head.add_child(UIKit.label("Total best score  %d" % total, 16))
	_scroll = UIKit.vbox(6)
	_scroll.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(_scroll)
	for l in Credits.LINES:
		_scroll.add_child(UIKit.label(l[0], l[1], UIKit.ACCENT if l[1] >= 20 else UIKit.TEXT))
	var back := UIKit.button("Main Menu", func(): Game.goto("res://scripts/ui/main_menu.gd"), 180)
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-90, -70)
	add_child(back)
	Audio.play_music("victory")
	Audio.sfx("clear")


func _process(delta: float) -> void:
	_t += delta
	_scroll.position.y = size.y + 40 - max(0.0, _t - 4.0) * 35.0
	if _scroll.position.y < -_scroll.size.y:
		_t = 4.0
	if randf() < delta * 2.5:
		var p := Vector2(randf_range(40, size.x - 40), randf_range(60, size.y * 0.5))
		var c := Color.from_hsv(randf(), 0.6, 1.0)
		Res.burst(_fx, p, c, 30, 160, 1.2, 120, 3.0)
		Audio.sfx("break", 1.6)


func on_back() -> void:
	Game.goto("res://scripts/ui/main_menu.gd")
