extends RefCounted
## Cached sprite resources and small visual-effect helpers.

static var _frames := {}
static var _textures := {}


static func tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load("res://assets/sprites/%s.png" % name)
	return _textures[name]


static func atlas(name: String, frame: int, w := 16, h := 16) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex(name)
	at.region = Rect2(frame * w, 0, w, h)
	return at


## Builds (and caches) SpriteFrames from a horizontal strip.
## anims: {name: [frame indices], ...}; fps: {name: speed} or a float.
static func frames(sheet: String, anims: Dictionary, fps = 8.0, w := 16, h := 16) -> SpriteFrames:
	var key := sheet + str(anims) + str(fps)
	if _frames.has(key):
		return _frames[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in anims:
		sf.add_animation(a)
		var speed: float = fps.get(a, 8.0) if fps is Dictionary else float(fps)
		sf.set_animation_speed(a, speed)
		sf.set_animation_loop(a, true)
		for i in anims[a]:
			sf.add_frame(a, atlas(sheet, i, w, h))
	_frames[key] = sf
	return sf


static func sprite(sheet: String, anims: Dictionary, fps = 8.0, w := 16, h := 16) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(sheet, anims, fps, w, h)
	s.animation = anims.keys()[0]
	s.play()
	return s


## One-shot burst of square particles.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 10, speed := 90.0, life := 0.5,
		gravity := 300.0, size := 2.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.5
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.z_index = 20
	parent.add_child(p)
	p.emitting = true
	var t := p.get_tree().create_timer(life + 0.2, false)
	t.timeout.connect(p.queue_free)


## Floating score / text popup.
static func popup(parent: Node, pos: Vector2, text: String, color := Color("fdf6e3")) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label.new()
	l.text = text
	l.position = pos + Vector2(-24, -20)
	l.size = Vector2(48, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("1b1428"))
	l.add_theme_constant_override("outline_size", 3)
	l.z_index = 30
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 18, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.tween_callback(l.queue_free)
