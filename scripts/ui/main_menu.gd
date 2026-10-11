extends Control
## Main menu: Play, Worlds, Settings, Credits.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Scenic = preload("res://scripts/ui/scenic.gd")
const Res = preload("res://scripts/game/res.gd")


func _ready() -> void:
	UIKit.root(self)
	var bg := Scenic.new()
	bg.world = 1
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.1, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var v := UIKit.center_column(self, 14)
	var title := UIKit.label("ADVENTURE\nQUEST", 44, UIKit.ACCENT)
	v.add_child(title)
	v.add_child(UIKit.label("Pixel Kingdom", 24, Color("8fe0ff")))
	var hero := Res.sprite("hero", {"idle": [0, 1]}, 2.0)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 72)
	hero.scale = Vector2(4, 4)
	hero.position = Vector2(0, 36)
	holder.add_child(hero)
	holder.resized.connect(func(): hero.position.x = holder.size.x / 2)
	v.add_child(holder)
	var next: Array = Game.next_open_level()
	var play_text := "Play" if Game.data["levels"].is_empty() else "Continue %d-%d" % [next[0], next[1]]
	v.add_child(UIKit.button(play_text, func(): Game.start_level(next[0], next[1])))
	v.add_child(UIKit.button("Worlds", func(): Game.goto("res://scripts/ui/world_select.gd")))
	v.add_child(UIKit.button("Settings", func(): Game.goto("res://scripts/ui/settings.gd")))
	v.add_child(UIKit.button("Credits", func(): Game.goto("res://scripts/ui/credits.gd")))
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_child(UIKit.icon("ui_icons", 0, 20))
	stars.add_child(UIKit.label(" %d / %d" % [Game.total_stars(), Game.WORLDS * Game.LEVELS * 3], 18))
	v.add_child(stars)
	var tw := create_tween().set_loops()
	tw.tween_property(title, "position:y", -4.0, 1.2).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "position:y", 4.0, 1.2).as_relative().set_trans(Tween.TRANS_SINE)
	Audio.play_music("menu")


func on_back() -> void:
	UIKit.confirm(self, "Quit Adventure Quest?", func():
		Game.save_game()
		get_tree().quit(), "Quit")
