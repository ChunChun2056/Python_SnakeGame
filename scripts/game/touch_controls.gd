extends CanvasLayer
## Multi-touch on-screen controls for portrait play.
## Left half of the bottom panel: move left / right (slide to switch).
## Right half: big JUMP button, RUN / BLAST button above it.
## Every finger is tracked separately so moving + jumping + running work
## at the same time.

signal pause_requested

var _pad: Control
var _touches := {}          # finger index -> button name
var _pressed := {"move_left": false, "move_right": false, "jump": false, "run": false}
var _scale := 1.0


func _ready() -> void:
	layer = 10
	_scale = clamp(float(Game.setting("ui_scale")), 0.7, 1.4)
	_pad = Control.new()
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)


func panel_height() -> float:
	var vs := get_viewport().get_visible_rect().size
	return min(206.0 * _scale, vs.y * 0.38)


func _geom() -> Dictionary:
	var vs := get_viewport().get_visible_rect().size
	var s := panel_height() / 206.0
	var r_move := 36.0 * s
	var left_c := Vector2(18.0 * s + r_move, vs.y - panel_height() * 0.42)
	var right_c := Vector2(left_c.x + 2.0 * r_move + 18.0 * s, left_c.y)
	var r_jump := 46.0 * s
	var jump_c := Vector2(vs.x - 18.0 * s - r_jump, vs.y - 22.0 * s - r_jump)
	var r_run := 32.0 * s
	var run_c := Vector2(jump_c.x, jump_c.y - r_jump - r_run - 14.0 * s)
	return {"vs": vs, "s": s, "left": left_c, "right": right_c, "r_move": r_move,
		"jump": jump_c, "r_jump": r_jump, "run": run_c, "r_run": r_run}


func _button_at(pos: Vector2) -> String:
	var g := _geom()
	var vs: Vector2 = g["vs"]
	var top: float = vs.y - panel_height() - 24.0
	if pos.y < top:
		return ""
	if pos.x < vs.x * 0.5:
		var split: float = (g["left"].x + g["right"].x) / 2.0
		return "move_left" if pos.x < split else "move_right"
	var boundary: float = g["jump"].y - g["r_jump"] - 7.0 * g["s"]
	return "run" if pos.y < boundary else "jump"


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var b := _button_at(event.position)
			if b != "":
				_touches[event.index] = b
		else:
			_touches.erase(event.index)
		_sync()
	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			var b := _button_at(event.position)
			# keep the old button if the finger drifts off the panel
			if b != "" and b != _touches[event.index]:
				# only allow sliding between the two move buttons, or jump<->run
				var old: String = _touches[event.index]
				var both_move: bool = old.begins_with("move") and b.begins_with("move")
				var both_act: bool = not old.begins_with("move") and not b.begins_with("move")
				if both_move or both_act:
					_touches[event.index] = b
					_sync()


func _sync() -> void:
	var want := {"move_left": false, "move_right": false, "jump": false, "run": false}
	for i in _touches:
		want[_touches[i]] = true
	for a in want:
		if want[a] != _pressed[a]:
			_pressed[a] = want[a]
			if want[a]:
				Input.action_press(a)
			else:
				Input.action_release(a)
	_pad.queue_redraw()


func release_all() -> void:
	_touches.clear()
	_sync()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()


var _last_blast := false


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		pause_requested.emit()
	var p = get_parent().get("player")
	var blast: bool = p != null and p.blast_ammo > 0
	if blast != _last_blast:
		_last_blast = blast
		_pad.queue_redraw()


func _draw_pad() -> void:
	var g := _geom()
	var vs: Vector2 = g["vs"]
	var ph := panel_height()
	var top := vs.y - ph
	_pad.draw_rect(Rect2(0, top, vs.x, ph), Color(0.05, 0.03, 0.1, 0.55))
	_pad.draw_line(Vector2(0, top), Vector2(vs.x, top), Color(1, 1, 1, 0.12), 2.0)
	var font := ThemeDB.fallback_font
	var p = get_parent().get("player")
	var blast: bool = p != null and p.blast_ammo > 0
	_button(g["left"], g["r_move"], _pressed["move_left"], "", font, -1)
	_button(g["right"], g["r_move"], _pressed["move_right"], "", font, 1)
	_button(g["jump"], g["r_jump"], _pressed["jump"], "JUMP", font, 0, Color("ff8a3a"))
	_button(g["run"], g["r_run"], _pressed["run"], "BLAST" if blast else "RUN", font, 0,
		Color("ff5a3a") if blast else Color("3a7bd5"))


func _button(c: Vector2, r: float, down: bool, text: String, font: Font, arrow: int, tint := Color("5a4a90")) -> void:
	var rr := r * (0.92 if down else 1.0)
	_pad.draw_circle(c + Vector2(0, 3), rr, Color(0, 0, 0, 0.35))
	_pad.draw_circle(c, rr, Color(tint, 0.85 if down else 0.55))
	_pad.draw_arc(c, rr, 0, TAU, 40, Color(1, 1, 1, 0.75 if down else 0.4), 2.5)
	if arrow != 0:
		var a := rr * 0.45
		var pts := PackedVector2Array([
			c + Vector2(arrow * a, 0), c + Vector2(-arrow * a * 0.6, -a), c + Vector2(-arrow * a * 0.6, a)])
		_pad.draw_colored_polygon(pts, Color(1, 1, 1, 0.9))
	if text != "":
		var fs := int(max(11.0, rr * 0.36))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_pad.draw_string(font, c + Vector2(-w / 2, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
