extends Control
## World selection: eight world cards in a vertical scroll list.

const UIKit = preload("res://scripts/ui/ui_kit.gd")


func _ready() -> void:
	UIKit.root(self)
	UIKit.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var outer := UIKit.vbox(12)
	outer.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(outer)
	outer.add_child(UIKit.label("Choose a World", 28, UIKit.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := UIKit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for w in range(1, Game.WORLDS + 1):
		list.add_child(_card(w))
	outer.add_child(UIKit.button("Back", on_back))
	Audio.play_music("menu")


func _card(w: int) -> Control:
	var unlocked := Game.is_world_unlocked(w)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not unlocked
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Game.WORLD_COLORS[w - 1].darkened(0.45) if unlocked else Color("2a2438")
	sb.border_color = Game.WORLD_COLORS[w - 1] if unlocked else Color("1b1428")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	for st in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	var pressed := sb.duplicate()
	pressed.bg_color = Game.WORLD_COLORS[w - 1].darkened(0.2)
	b.add_theme_stylebox_override("pressed", pressed)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	b.add_child(h)
	var num := UIKit.label(str(w), 32, Game.WORLD_COLORS[w - 1] if unlocked else Color("6a6080"))
	num.custom_minimum_size = Vector2(36, 0)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(num)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(info)
	info.add_child(UIKit.label(Game.WORLD_NAMES[w - 1], 20, UIKit.TEXT if unlocked else Color("6a6080"), HORIZONTAL_ALIGNMENT_LEFT))
	if unlocked:
		var done := 0
		for l in range(1, Game.LEVELS + 1):
			if Game.is_level_done(w, l):
				done += 1
		info.add_child(UIKit.label("%d/5 cleared" % done, 14, Color("c8c0e0"), HORIZONTAL_ALIGNMENT_LEFT))
		var stars := HBoxContainer.new()
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stars.add_child(UIKit.icon("ui_icons", 0, 18))
		stars.add_child(UIKit.label("%d/15" % Game.world_stars(w), 16))
		h.add_child(stars)
		b.pressed.connect(func():
			Audio.sfx("click")
			Game.goto("res://scripts/ui/level_select.gd", {"world": w}))
	else:
		info.add_child(UIKit.label("Defeat the boss of world %d" % (w - 1), 13, Color("6a6080"), HORIZONTAL_ALIGNMENT_LEFT))
		var lock := UIKit.icon("ui_icons", 2, 26)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(lock)
	return b


func on_back() -> void:
	Game.goto("res://scripts/ui/main_menu.gd")
