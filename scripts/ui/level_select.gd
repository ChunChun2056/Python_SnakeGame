extends Control
## Level map for one world: five stops on a winding trail with stars.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Scenic = preload("res://scripts/ui/scenic.gd")

const LEVEL_NAMES := [
	["First Steps", "Clover Hills", "Buzzing Brook", "Windmill Way", "Grumble Keep"],
	["Dune Road", "Quicksand Basin", "Scorpion Steps", "Mirage Market", "Sandstone Bastion"],
	["Glowstone Gate", "Dark Tunnels", "Geode Gallery", "Echo Hollow", "Shade Sanctum"],
	["Cloud Hop", "Gusty Gardens", "Floating Fields", "Thunder Bridge", "Storm Spire"],
	["Snowy Trail", "Slippery Slopes", "Icicle Cavern", "Avalanche Pass", "Frost Fortress"],
	["Tide Pools", "Coral Depths", "Drowned Plaza", "Current Canyon", "Abyssal Temple"],
	["Ember Path", "Magma Falls", "Cinder Bridges", "Furnace Core", "Molten Throne"],
	["Citadel Gates", "Gear Works", "Midnight Halls", "Traitor's Climb", "Umbra Throne"],
]

var world := 1
var _map: Control
var _nodes: Array = []


func _ready() -> void:
	UIKit.root(self)
	var bg := Scenic.new()
	bg.world = world
	bg.speed = 8.0
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.1, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title := UIKit.label("World %d\n%s" % [world, Game.WORLD_NAMES[world - 1]], 26, Game.WORLD_COLORS[world - 1].lightened(0.3))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 20
	title.size.y = 80
	add_child(title)
	_map = Control.new()
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.offset_top = 110
	_map.offset_bottom = -130
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_path)
	add_child(_map)
	for l in range(1, Game.LEVELS + 1):
		_nodes.append(_level_node(l))
	_map.resized.connect(_place)
	var back := UIKit.button("Worlds", on_back, 160)
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-80, -72)
	add_child(back)
	Audio.play_music("w%d" % world)
	_place.call_deferred()


func _level_node(l: int) -> Control:
	var unlocked := Game.is_level_unlocked(world, l)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size = Vector2(150, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	var boss := l == Game.LEVELS
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(32)
	sb.set_border_width_all(4)
	sb.border_color = Color("1b1428")
	sb.bg_color = (Color("ff3b5c") if boss else Game.WORLD_COLORS[world - 1]) if unlocked else Color("3a3448")
	if Game.is_level_done(world, l):
		sb.border_color = UIKit.ACCENT
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("disabled", sb)
	var sp := sb.duplicate()
	sp.bg_color = sb.bg_color.lightened(0.3)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_font_size_override("font_size", 26)
	b.disabled = not unlocked
	if unlocked:
		b.text = str(l) if not boss else "B"
		b.pressed.connect(func():
			Audio.sfx("click")
			Game.start_level(world, l))
	else:
		var lock := UIKit.icon("ui_icons", 2, 30)
		lock.set_anchors_preset(Control.PRESET_CENTER)
		lock.position = Vector2(-15, -15)
		b.add_child(lock)
	box.add_child(b)
	var info := Game.level_info(world, l)
	box.add_child(UIKit.star_row(3, info.get("stars", [false, false, false]), 18))
	var name_l := UIKit.label(LEVEL_NAMES[world - 1][l - 1], 14)
	box.add_child(name_l)
	if info.has("best_score"):
		box.add_child(UIKit.label("Best %d" % int(info["best_score"]), 11, Color("c8c0e0")))
	_map.add_child(box)
	return box


func _positions() -> Array:
	var s := _map.size
	var pts := []
	for i in Game.LEVELS:
		var t := float(i) / (Game.LEVELS - 1)
		var x := s.x * (0.28 if i % 2 == 0 else 0.72)
		var y := s.y * (0.9 - t * 0.82)
		pts.append(Vector2(x, y))
	return pts


func _place() -> void:
	var pts := _positions()
	for i in _nodes.size():
		var n: Control = _nodes[i]
		n.reset_size()
		n.position = pts[i] - Vector2(n.size.x / 2, 34)
	_map.queue_redraw()


func _draw_path() -> void:
	var pts := _positions()
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var done := Game.is_level_done(world, i + 1)
		var col := UIKit.ACCENT if done else Color(1, 1, 1, 0.35)
		var steps := 12
		for k in steps:
			var p := a.lerp(b, (k + 0.5) / steps)
			_map.draw_circle(p, 3.0, col)


func on_back() -> void:
	Game.goto("res://scripts/ui/world_select.gd")
