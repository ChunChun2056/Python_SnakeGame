extends CanvasLayer
## In-game HUD: pause button, hearts, lives, coins, score, timer, active
## power-ups, air meter, boss health, tutorial signs and banners.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Res = preload("res://scripts/game/res.gd")

var level: Node
var _root: Control
var _hearts: Array = []
var _lives: Label
var _coins: Label
var _score: Label
var _time: Label
var _powers: HBoxContainer
var _power_labels := {}
var _air_bg: ColorRect
var _air: ColorRect
var _boss_box: VBoxContainer
var _boss_bar: ColorRect
var _boss_bg: ColorRect
var _boss: Node
var _sign_panel: PanelContainer
var _sign_label: Label
var _banner: Label
var _cache := {}


func _ready() -> void:
	layer = 5
	_root = Control.new()
	UIKit.root(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var bar := ColorRect.new()
	bar.color = Color(0.06, 0.04, 0.12, 0.55)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 64)
	bar.size = Vector2(0, 64)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)

	var pause := Button.new()
	pause.text = "II"
	pause.position = Vector2(8, 8)
	pause.custom_minimum_size = Vector2(48, 48)
	pause.size = Vector2(48, 48)
	pause.focus_mode = Control.FOCUS_NONE
	pause.pressed.connect(func(): level.open_pause())
	_root.add_child(pause)

	_time = UIKit.label("0:00", 18)
	_time.position = Vector2(64, 8)
	_time.size = Vector2(70, 24)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_root.add_child(_time)
	var lvl := UIKit.label("%d-%d" % [level.world, level.level_num], 14, UIKit.ACCENT)
	lvl.position = Vector2(64, 32)
	lvl.size = Vector2(70, 20)
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_root.add_child(lvl)

	# top-right: score, coins, hearts + lives
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-208, 4)
	right.size = Vector2(200, 56)
	right.add_theme_constant_override("separation", 0)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_END
	row1.add_theme_constant_override("separation", 6)
	right.add_child(row1)
	row1.add_child(UIKit.icon("coin", 0, 16))
	_coins = UIKit.label("0", 16, UIKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_coins.autowrap_mode = TextServer.AUTOWRAP_OFF
	row1.add_child(_coins)
	_score = UIKit.label("0", 16, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_score.autowrap_mode = TextServer.AUTOWRAP_OFF
	_score.custom_minimum_size = Vector2(80, 0)
	row1.add_child(_score)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_END
	row2.add_theme_constant_override("separation", 2)
	right.add_child(row2)
	for i in 3:
		var h := UIKit.icon("powerups", 6, 18)
		_hearts.append(h)
		row2.add_child(h)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	row2.add_child(spacer)
	var head := UIKit.icon("powerups", 5, 18)
	row2.add_child(head)
	_lives = UIKit.label("x5", 16, UIKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_lives.autowrap_mode = TextServer.AUTOWRAP_OFF
	row2.add_child(_lives)

	# power-up row under the bar
	_powers = HBoxContainer.new()
	_powers.position = Vector2(8, 68)
	_powers.add_theme_constant_override("separation", 8)
	_powers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_powers)
	for p in [["shield", 1], ["speed", 0], ["mega", 2], ["magnet", 4], ["blast", 3]]:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.add_child(UIKit.icon("powerups", p[1], 18))
		var l := UIKit.label("", 13, UIKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		box.add_child(l)
		box.visible = false
		_powers.add_child(box)
		_power_labels[p[0]] = [box, l]

	# air meter
	_air_bg = ColorRect.new()
	_air_bg.color = Color(0, 0, 0, 0.5)
	_air_bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_air_bg.position = Vector2(-60, 70)
	_air_bg.size = Vector2(120, 10)
	_air_bg.visible = false
	_root.add_child(_air_bg)
	_air = ColorRect.new()
	_air.color = Color("8fdcff")
	_air.position = Vector2(2, 2)
	_air.size = Vector2(116, 6)
	_air_bg.add_child(_air)
	var air_l := UIKit.label("AIR", 10)
	air_l.position = Vector2(-30, -2)
	air_l.size = Vector2(28, 12)
	_air_bg.add_child(air_l)

	# boss bar
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.position = Vector2(-120, 90)
	_boss_box.size = Vector2(240, 30)
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_box)
	_boss_box.add_child(UIKit.label("", 14, UIKit.DANGER))
	_boss_bg = ColorRect.new()
	_boss_bg.color = Color(0, 0, 0, 0.6)
	_boss_bg.custom_minimum_size = Vector2(240, 10)
	_boss_box.add_child(_boss_bg)
	_boss_bar = ColorRect.new()
	_boss_bar.color = UIKit.DANGER
	_boss_bar.position = Vector2(2, 2)
	_boss_bar.size = Vector2(236, 6)
	_boss_bg.add_child(_boss_bar)

	# sign
	_sign_panel = PanelContainer.new()
	_sign_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sign_panel.position = Vector2(-160, 120)
	_sign_panel.custom_minimum_size = Vector2(320, 0)
	_sign_panel.visible = false
	_sign_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_sign_panel)
	_sign_label = UIKit.label("", 16, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	_sign_label.custom_minimum_size = Vector2(290, 0)
	_sign_panel.add_child(_sign_label)

	_banner = UIKit.label("", 26, UIKit.ACCENT)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-170, 190)
	_banner.size = Vector2(340, 40)
	_banner.modulate.a = 0.0
	_root.add_child(_banner)


func _txt(node: Label, key: String, text: String) -> void:
	if _cache.get(key) != text:
		_cache[key] = text
		node.text = text


func _process(_delta: float) -> void:
	var p = level.player
	if p == null:
		return
	var t := int(level.time)
	_txt(_time, "time", "%d:%02d" % [t / 60, t % 60])
	_txt(_coins, "coins", str(level.coins))
	_txt(_score, "score", str(level.score))
	_txt(_lives, "lives", "x%d" % Game.lives)
	for i in 3:
		_hearts[i].modulate = Color(1, 1, 1, 1) if i < p.hp else Color(0.25, 0.2, 0.3, 0.8)
	_power(p.shield, "shield", "")
	_power(p.speed_t > 0, "speed", "%d" % ceili(p.speed_t))
	_power(p.mega_t > 0, "mega", "%d" % ceili(p.mega_t))
	_power(p.magnet_t > 0, "magnet", "%d" % ceili(p.magnet_t))
	_power(p.blast_ammo > 0, "blast", "x%d" % p.blast_ammo)
	var show_air: bool = p.head_in_water or p.air < p.AIR_MAX - 0.05
	_air_bg.visible = show_air
	if show_air:
		_air.size.x = 116.0 * p.air / p.AIR_MAX
		_air.color = Color("8fdcff") if p.air > 3.0 else UIKit.DANGER
	if _boss and is_instance_valid(_boss):
		_boss_bar.size.x = 236.0 * (1.0 - _boss.total_hp_fraction())


func _power(on: bool, key: String, text: String) -> void:
	var pair: Array = _power_labels[key]
	pair[0].visible = on
	if on:
		_txt(pair[1], "p_" + key, text)


func set_sign(text: String) -> void:
	_sign_panel.visible = text != ""
	if text != "":
		_txt(_sign_label, "sign", text)


func banner(text: String) -> void:
	_banner.text = text
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


func show_boss(b: Node) -> void:
	_boss = b
	_boss_box.visible = true
	(_boss_box.get_child(0) as Label).text = b.display_name()


func hide_boss() -> void:
	_boss_box.visible = false
	_boss = null
