extends RefCounted
## Shared UI construction helpers (theme, buttons, panels, dialogs).

const BG := Color("17122a")
const PANEL := Color("2a2148")
const ACCENT := Color("ffd23f")
const TEXT := Color("fdf6e3")
const DANGER := Color("ff3b5c")


static func _box(color: Color, border: Color, radius := 10, bw := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color("1b1428"))
	t.set_constant("outline_size", "Label", 4)
	t.set_stylebox("normal", "Button", _box(Color("3b2f66"), Color("1b1428")))
	t.set_stylebox("hover", "Button", _box(Color("4b3c80"), Color("1b1428")))
	t.set_stylebox("pressed", "Button", _box(Color("ff8a3a"), Color("1b1428")))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT, 10, 2))
	t.set_stylebox("disabled", "Button", _box(Color("2a2438"), Color("1b1428")))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color("1b1428"))
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color("6a6080"))
	t.set_color("font_outline_color", "Button", Color("1b1428"))
	t.set_constant("outline_size", "Button", 3)
	t.set_font_size("font_size", "Button", 20)
	t.set_stylebox("panel", "Panel", _box(PANEL, Color("1b1428"), 14, 4))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, Color("1b1428"), 14, 4))
	var grab := StyleBoxFlat.new()
	grab.bg_color = ACCENT
	grab.set_corner_radius_all(6)
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color("4b3c80")
	slider_bg.set_corner_radius_all(6)
	slider_bg.content_margin_top = 6
	slider_bg.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	return t


static func root(node: Control) -> void:
	node.theme = Game.theme
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func label(text: String, size := 18, color := TEXT, align := HORIZONTAL_ALIGNMENT_CENTER, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, cb: Callable, min_w := 220, height := 52) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, height)
	b.pressed.connect(func():
		Audio.sfx("click")
		cb.call())
	return b


static func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	return v


static func center_column(parent: Control, sep := 12) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	var v := vbox(sep)
	c.add_child(v)
	return v


static func background(parent: Control, color := BG) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


static func icon(sheet: String, frame: int, size := 16, fw := 16) -> TextureRect:
	var tr := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/%s.png" % sheet)
	at.region = Rect2(frame * fw, 0, fw, at.atlas.get_height())
	tr.texture = at
	tr.custom_minimum_size = Vector2(size, size * at.atlas.get_height() / fw)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func star_row(count: int, earned: Array, size := 22) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in count:
		var on: bool = i < earned.size() and earned[i]
		h.add_child(icon("ui_icons", 0 if on else 1, size))
	return h


## Modal confirmation overlay. Calls on_yes when confirmed.
static func confirm(parent: Node, message: String, on_yes: Callable, yes_text := "Yes") -> Control:
	var overlay := Control.new()
	overlay.theme = Game.theme
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var panel := PanelContainer.new()
	cc.add_child(panel)
	var v := vbox(16)
	v.custom_minimum_size = Vector2(280, 0)
	panel.add_child(v)
	v.add_child(label(message, 18, TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	h.add_child(button("Cancel", func(): overlay.queue_free(), 120))
	var yes := button(yes_text, func():
		overlay.queue_free()
		on_yes.call(), 120)
	yes.add_theme_color_override("font_color", DANGER)
	h.add_child(yes)
	parent.add_child(overlay)
	return overlay
