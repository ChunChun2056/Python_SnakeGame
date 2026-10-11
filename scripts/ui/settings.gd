extends Control
## Settings: audio volumes, control size, tutorial and progress reset.

const UIKit = preload("res://scripts/ui/ui_kit.gd")


func _ready() -> void:
	UIKit.root(self)
	UIKit.background(self)
	var v := UIKit.center_column(self, 16)
	v.add_child(UIKit.label("Settings", 32, UIKit.ACCENT))
	v.add_child(_slider("Music", "music", 0.0, 1.0))
	v.add_child(_slider("Sound FX", "sfx", 0.0, 1.0))
	v.add_child(_slider("Controls size", "ui_scale", 0.7, 1.4))
	v.add_child(UIKit.label("Controls size applies in the next level.", 12, Color("a89cc8")))
	var tut := CheckButton.new()
	tut.text = "Show tutorial again"
	tut.button_pressed = not Game.setting("tutorial_seen")
	tut.toggled.connect(func(on): Game.set_setting("tutorial_seen", not on))
	v.add_child(tut)
	var reset := UIKit.button("Reset Progress", func():
		UIKit.confirm(self, "Erase ALL progress, stars and best scores?\nThis cannot be undone.", func():
			Game.reset_progress()
			Game.goto("res://scripts/ui/main_menu.gd"), "Erase"))
	reset.add_theme_color_override("font_color", UIKit.DANGER)
	v.add_child(reset)
	v.add_child(UIKit.button("Back", on_back))


func _slider(text: String, key: String, lo: float, hi: float) -> Control:
	var box := UIKit.vbox(4)
	box.add_child(UIKit.label(text, 18))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Game.setting(key))
	s.custom_minimum_size = Vector2(260, 32)
	s.value_changed.connect(func(val):
		Game.set_setting(key, val)
		if key == "sfx":
			Audio.sfx("coin"))
	box.add_child(s)
	return box


func on_back() -> void:
	Game.save_game()
	Game.goto("res://scripts/ui/main_menu.gd")
