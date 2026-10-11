extends Control
## Scrolling credits. Also reused by the victory screen.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

const LINES := [
	["ADVENTURE QUEST", 30], ["Pixel Kingdom", 22], ["", 18],
	["Game Design & Programming", 16], ["Built with Godot Engine 4", 20], ["", 18],
	["Characters", 16], ["Pip the Explorer", 20], ["Grumblets, Shellbacks, Buzzwings", 14],
	["Dunehoppers, Glimmershades, Frostbites", 14], ["Snapfins and Magmaws", 14], ["", 18],
	["Bosses", 16], ["Grumble King  ·  Dune Tyrant", 14], ["Wailing Shade  ·  Storm Beetle", 14],
	["Frost Colossus  ·  Snapfin Leviathan", 14], ["Magma Lord  ·  Umbra King", 14], ["", 18],
	["Art", 16], ["Procedurally drawn original pixel art", 14], ["", 18],
	["Music & Sound", 16], ["Original chiptune synthesized for this game", 14], ["", 18],
	["Worlds", 16], ["Green Meadows · Sunbaked Desert", 14], ["Crystal Caverns · Sky Islands", 14],
	["Frozen Peaks · Sunken Ruins", 14], ["Volcanic Depths · Shadow Citadel", 14], ["", 18],
	["Thank you for playing!", 22],
]

var auto_back := false
var _scroll: VBoxContainer
var _t := 0.0


func _ready() -> void:
	UIKit.root(self)
	UIKit.background(self)
	clip_contents = true
	_scroll = UIKit.vbox(6)
	_scroll.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(_scroll)
	for l in LINES:
		_scroll.add_child(UIKit.label(l[0], l[1], UIKit.ACCENT if l[1] >= 20 else UIKit.TEXT))
	var back := UIKit.button("Back", on_back, 160)
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-80, -70)
	add_child(back)
	Audio.play_music("menu")


func _process(delta: float) -> void:
	_t += delta
	_scroll.position.y = size.y - _t * 40.0
	if _scroll.position.y < -_scroll.size.y:
		_t = 0.0


func on_back() -> void:
	Game.goto("res://scripts/ui/main_menu.gd")
