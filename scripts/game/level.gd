extends Node2D
## Builds and runs one level from its text data: tiles, merged collision,
## entities, camera, parallax, HUD, touch controls, pause and results.

const Res = preload("res://scripts/game/res.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const LevelData = preload("res://scripts/game/level_data.gd")
const PlayerScript = preload("res://scripts/game/player.gd")
const EnemyScript = preload("res://scripts/game/enemy.gd")
const BossScript = preload("res://scripts/game/boss.gd")
const PickupScript = preload("res://scripts/game/pickup.gd")
const BlockScript = preload("res://scripts/game/block.gd")
const TriggerScript = preload("res://scripts/game/trigger.gd")
const HazardScript = preload("res://scripts/game/hazard.gd")
const PlatformScript = preload("res://scripts/game/platform.gd")
const ProjectileScript = preload("res://scripts/game/projectile.gd")
const HudScript = preload("res://scripts/game/hud.gd")
const ControlsScript = preload("res://scripts/game/touch_controls.gd")

const T := 16
const SOLID := {"#": true, "X": true, "I": true, "B": true, "?": true, "U": true, "u": true}
const LEDGE := {"=": true, "c": true}
const WATER := {"W": true, "<": true, ">": true, "A": true}
const BRICK_COLORS := ["c8643a", "d08048", "56609a", "9ab0e0", "8ab4e0", "4a8a8a", "6a3a30", "4a4060"]

var world := 1
var level_num := 1
var data: RefCounted
var grid: Array = []
var W := 0
var H := 18
var tile_texture: Texture2D
var brick_color := Color.WHITE

var player: CharacterBody2D
var cam: Camera2D
var hud: CanvasLayer
var controls: CanvasLayer
var boss: Node = null
var goal: Node = null

var coins := 0
var total_coins := 0
var gems := 0
var score := 0
var secrets := 0
var total_secrets := 0
var time := 0.0
var par := 120
var collected := {}
var state := "play"
## Used by the automated test runner: deaths do not reload the level.
var no_death := false

var _entities: Node2D
var _fx: Node2D
var _tiles: TileMapLayer
var _liquid: TileMapLayer
var _fake: TileMapLayer
var _blocks := {}
var _power_list: PackedStringArray = []
var _power_idx := 0
var _main_end := 0.0
var _rooms: Array = []
var _arena := Vector2i(-1, -1)
var _boss_started := false
var _spawn := Vector2.ZERO
var _shake_t := 0.0
var _shake_amp := 0.0
var _cam_pos := Vector2.ZERO
var _zoom := 1.5
var _base_cam_y := 0.0
var _lim := Vector2(0, 0)
var _sign_text := ""
var _sign_t := 0.0
var _dark: ColorRect
var _pause_layer: CanvasLayer
var _overlay: Control
var _coins_for_life := 0


func _ready() -> void:
	world = Game.world
	level_num = Game.level
	data = LevelData.load_level(world, level_num)
	grid = data.rows
	W = data.width
	H = data.height
	par = data.get_int("par", 120)
	_main_end = data.get_int("main_end", W) * T
	_power_list = data.get_str("powerups", "shield").split(",")
	tile_texture = load("res://assets/tiles/world%d.png" % world)
	brick_color = Color(BRICK_COLORS[world - 1])
	for k in data.header:
		if k == "room":
			var r: PackedStringArray = data.header[k].split(",")
			_rooms.append(Vector2i(int(r[0]), int(r[1])))
	if data.header.has("arena"):
		var a: PackedStringArray = data.get_str("arena").split(",")
		_arena = Vector2i(int(a[0]), int(a[1]))
	_parse_rooms_multi()

	_build_background()
	_tiles = _make_layer(0)
	_liquid = _make_layer(3)
	_liquid.modulate = Color(1, 1, 1, 0.85)
	_fake = _make_layer(4)
	_entities = Node2D.new()
	_entities.name = "Entities"
	add_child(_entities)
	_fx = Node2D.new()
	_fx.z_index = 10
	add_child(_fx)

	_restore_checkpoint_state()
	_paint_tiles()
	_build_collision()
	_spawn_entities()
	_spawn_warps()

	player = PlayerScript.new()
	player.level = self
	player.position = _spawn
	add_child(player)

	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()

	if data.get_str("underwater") == "1":
		var cm := CanvasModulate.new()
		cm.color = Color(0.72, 0.88, 1.0)
		add_child(cm)
	if data.get_str("dark") == "1":
		_build_darkness()

	hud = HudScript.new()
	hud.level = self
	add_child(hud)
	controls = ControlsScript.new()
	add_child(controls)
	controls.pause_requested.connect(open_pause)
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 30
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)

	get_viewport().size_changed.connect(_layout)
	_layout()
	_cam_pos = _camera_target()
	cam.position = _cam_pos
	Audio.play_music(data.get_str("music", "w1"))
	Audio.duck_music(false)
	if Game.checkpoint.is_empty():
		show_banner("%d-%d  %s" % [world, level_num, data.get_str("name")])
	else:
		show_banner("Checkpoint")
	if world == 1 and level_num == 1 and not Game.setting("tutorial_seen"):
		_show_tutorial()


func _parse_rooms_multi() -> void:
	# room= may appear once per bonus room; LevelData keeps the last, so rescan
	_rooms.clear()
	var f := FileAccess.open("res://levels/w%d_%d.txt" % [world, level_num], FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line()
		if line == "---":
			break
		if line.begins_with("room="):
			var r := line.substr(5).split(",")
			_rooms.append(Vector2i(int(r[0]), int(r[1])))


# ------------------------------------------------------------------ building
func _make_layer(z: int) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = _tileset()
	l.z_index = z
	add_child(l)
	return l


var _ts: TileSet = null


func _tileset() -> TileSet:
	if _ts:
		return _ts
	_ts = TileSet.new()
	_ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = tile_texture
	src.texture_region_size = Vector2i(T, T)
	_ts.add_source(src, 0)
	for i in 20:
		src.create_tile(Vector2i(i, 0))
	return _ts


func _tile_for(x: int, y: int) -> int:
	var ch := cell(x, y)
	var above := cell(x, y - 1)
	match ch:
		"#":
			return 1 if above in ["#", "O", "Q"] else 0
		"X":
			return 5
		"I":
			return 12
		"=":
			return 6
		"^":
			return 7
		"Q":
			return 14 if above == "Q" else 13
		"d":
			return 16
		"D":
			return 17
	return -1


## Cells drawn as fake wall: every "O" plus treasures tucked inside them.
func _fake_cells() -> Dictionary:
	var fake := {}
	for y in H:
		for x in W:
			if grid[y][x] == "O":
				fake[Vector2i(x, y)] = true
	var changed := true
	while changed:
		changed = false
		for y in H:
			for x in W:
				var c := Vector2i(x, y)
				if fake.has(c) or not (grid[y][x] in ["o", "*", "g"]):
					continue
				for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					if fake.has(c + d):
						fake[c] = true
						changed = true
						break
	return fake


func _paint_tiles() -> void:
	for c in _fake_cells():
		var above := cell(c.x, c.y - 1)
		_fake.set_cell(c, 0, Vector2i(1 if above in ["#", "O", "o", "*", "g"] else 0, 0))
	for y in H:
		for x in W:
			var ch: String = grid[y][x]
			var t := _tile_for(x, y)
			if t >= 0:
				_tiles.set_cell(Vector2i(x, y), 0, Vector2i(t, 0))
			if ch == "L" or ch == "j":
				var above := cell(x, y - 1)
				_liquid.set_cell(Vector2i(x, y), 0, Vector2i(9 if above in ["L", "j"] else 8, 0))
			elif WATER.has(ch) or _is_water_entity(x, y):
				var above := cell(x, y - 1)
				var top := not (WATER.has(above) or _is_water_entity(x, y - 1))
				var idx := 10 if top else (18 if ch in ["<", ">"] else 11)
				_liquid.set_cell(Vector2i(x, y), 0, Vector2i(idx, 0))


func _is_water_entity(x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	var ch: String = grid[y][x]
	if ch in ["n", "o", "g", "*", "A", "1", "2", "3", "4", "5", "6", "e", "f", "C", "T"]:
		return data.get_str("underwater") == "1" and y >= 3 and y < 15 or _water_neighbour(x, y)
	return false


func _water_neighbour(x: int, y: int) -> bool:
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		var c := cell(x + d.x, y + d.y)
		if WATER.has(c):
			return true
	return false


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	# merge solid cells into large rectangles (no seams for smooth sliding)
	var open := {}
	var rects: Array = []
	for y in H + 1:
		var runs := {}
		if y < H:
			var x := 0
			while x < W:
				if grid[y][x] in ["#", "X", "I"]:
					var x0 := x
					while x < W and grid[y][x] in ["#", "X", "I"]:
						x += 1
					runs[Vector2i(x0, x)] = true
				else:
					x += 1
		for k in open.keys():
			if not runs.has(k):
				rects.append(Rect2i(k.x, open[k], k.y - k.x, y - open[k]))
				open.erase(k)
		for k in runs:
			if not open.has(k):
				open[k] = y
	for r in rects:
		_add_rect(body, Rect2(r.position.x * T, r.position.y * T, r.size.x * T, r.size.y * T), false)
	# world borders and ceiling
	_add_rect(body, Rect2(-T, -T * 8, T, (H + 10) * T), false)
	_add_rect(body, Rect2(W * T, -T * 8, T, (H + 10) * T), false)
	_add_rect(body, Rect2(0, -T * 9, W * T, T), false)
	# one-way platforms
	var ow := StaticBody2D.new()
	ow.collision_layer = 1
	add_child(ow)
	for y in H:
		var x := 0
		while x < W:
			if grid[y][x] == "=":
				var x0 := x
				while x < W and grid[y][x] == "=":
					x += 1
				_add_rect(ow, Rect2(x0 * T, y * T, (x - x0) * T, 6), true)
			else:
				x += 1


func _add_rect(body: StaticBody2D, r: Rect2, one_way: bool) -> void:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	cs.position = r.position + r.size / 2
	cs.one_way_collision = one_way
	body.add_child(cs)


func _restore_checkpoint_state() -> void:
	var cp := Game.checkpoint
	if cp.is_empty() or cp.get("key", "") != Game.level_key(world, level_num):
		Game.checkpoint = {}
		return
	coins = cp["coins"]
	gems = cp["gems"]
	score = cp["score"]
	secrets = cp["secrets"]
	time = cp["time"]
	collected = cp["collected"].duplicate()
	_coins_for_life = cp.get("coins_for_life", 0)


func _spawn_entities() -> void:
	var sign_idx := 0
	var start := Vector2.ZERO
	for x in W:
		for y in H:
			var ch: String = grid[y][x]
			var id := "%d,%d" % [x, y]
			var pos := Vector2(x * T + T / 2.0, y * T + T / 2.0)
			var feet := Vector2(x * T + T / 2.0, (y + 1) * T)
			var keep := ""
			match ch:
				"S":
					start = feet
				"o":
					total_coins += 1
					if not collected.has(id):
						_pickup("coin", pos, id)
				"g":
					if not collected.has(id):
						_pickup("gem", pos, id)
				"*":
					total_secrets += 1
					if not collected.has(id):
						_pickup("star", pos, id)
				"1", "2", "3", "4", "5", "6":
					if not collected.has(id):
						var kinds := ["speed", "shield", "mega", "blast", "magnet", "life"]
						_pickup("power", pos, id, kinds[int(ch) - 1])
				"B", "?", "U", "H":
					keep = ch
					if ch == "?":
						total_coins += 1
					var b_kind: String = {"B": "brick", "?": "coin", "U": "power", "H": "hidden"}[ch]
					if collected.has(id):
						if ch == "B":
							keep = "."
						else:
							_block(b_kind, x, y, id, true)
							keep = "u"
					else:
						_block(b_kind, x, y, id, false)
						if ch == "H":
							keep = "."
				"c":
					_platform("crumble", Vector2(pos.x, y * T), 1)
					keep = "c"
				"M":
					_moving_platform(x, y, false)
				"V":
					_moving_platform(x, y, true)
				"C":
					var t := _trigger("checkpoint", feet)
					if not Game.checkpoint.is_empty() and Game.checkpoint.get("pos") == feet:
						t.set_active_visual()
				"F":
					goal = _trigger("goal", feet)
					if data.header.has("boss"):
						goal.enabled = false
						goal.visible = false
				"T":
					var t := _trigger("sign", feet)
					t.text = data.signs[sign_idx] if sign_idx < data.signs.size() else ""
					sign_idx += 1
				"k":
					_trigger("spring", feet)
				"A":
					_trigger("vent", feet)
					keep = "W"
				"R":
					_hazard("rock", pos)
				"Y":
					_hazard("crusher", Vector2(x * T + T, y * T + T))
				"z":
					_hazard("spikeball", pos)
				"j":
					_hazard("jumper", Vector2(pos.x, y * T + 4))
					keep = "L"
				"e", "r", "f", "h", "G", "y", "n", "m":
					spawn_enemy(ch, feet)
				"K":
					boss = BossScript.new()
					boss.kind = data.get_str("boss", "walker")
					boss.level = self
					boss.position = feet
					_entities.add_child(boss)
				"Z":
					keep = "Z"
					if cell(x, y - 1) != "Z":
						_wind_column(x, y)
				_:
					keep = ch
			if keep == "" or ch in ["S", "o", "g", "*", "1", "2", "3", "4", "5", "6", "M", "V", "C", "F", "T", "R", "k",
					"Y", "z", "e", "r", "f", "h", "G", "y", "n", "m", "K"]:
				keep = "W" if _is_water_entity(x, y) else "."
			grid[y][x] = keep
	if not Game.checkpoint.is_empty():
		_spawn = Game.checkpoint["pos"]
	else:
		_spawn = start


func _pickup(kind: String, pos: Vector2, id: String, power := "") -> Node:
	var p := PickupScript.new()
	p.kind = kind
	p.power = power
	p.level = self
	p.id = id
	p.position = pos
	_entities.add_child(p)
	return p


func _block(kind: String, x: int, y: int, id: String, used: bool) -> void:
	var b := BlockScript.new()
	b.kind = kind
	b.level = self
	b.cell = Vector2i(x, y)
	b.id = id
	b.position = Vector2(x * T + 8, y * T + 8)
	_entities.add_child(b)
	if used:
		b.set_used()
	_blocks[Vector2i(x, y)] = b


func _platform(kind: String, pos: Vector2, width: int) -> Node:
	var p := PlatformScript.new()
	p.kind = kind
	p.level = self
	p.width_tiles = width
	p.position = pos
	_entities.add_child(p)
	return p


func _moving_platform(x: int, y: int, vertical: bool) -> void:
	# find the pit edges on the ground row beneath to size the motion
	var row := mini(y + 1, H - 1)
	var l := x
	while l > 0 and not (grid[row][l] in ["#", "X", "I"]):
		l -= 1
	var r := x
	while r < W - 1 and not (grid[row][r] in ["#", "X", "I"]):
		r += 1
	var mid := (l + r + 1) / 2.0 * T
	if vertical:
		var p := _platform("move_v", Vector2(mid, (y + 2) * T - 24), 3)
		p.amplitude = 40.0
		p.period = 4.5
	else:
		var span := (r - l - 1) * T
		var p := _platform("move_h", Vector2(mid, (y + 1) * T), 3)
		p.amplitude = max(8.0, span / 2.0 - 24.0)
		p.period = 2.0 + span / 40.0


func _trigger(kind: String, pos: Vector2) -> Node:
	var t := TriggerScript.new()
	t.kind = kind
	t.level = self
	t.position = pos
	_entities.add_child(t)
	return t


func _hazard(kind: String, pos: Vector2) -> Node:
	var h := HazardScript.new()
	h.kind = kind
	h.level = self
	h.position = pos
	_entities.add_child(h)
	return h


func spawn_enemy(ch: String, feet: Vector2) -> Node:
	var e := EnemyScript.new()
	e.kind = EnemyScript.KIND_BY_CHAR.get(ch, "walker")
	e.level = self
	e.position = feet
	if e.kind in ["flyer", "ghost", "fish"]:
		e.position = feet + Vector2(0, -2)
	_entities.add_child(e)
	return e


func _spawn_warps() -> void:
	for w in data.warps:
		var src: Vector2i = w["src"]
		var dst: Vector2i = w["dst"]
		var t := _trigger("warp", Vector2(src.x * T + 8, (src.y + 1) * T))
		t.target = Vector2(dst.x * T + 8, (dst.y + 1) * T)


func _wind_column(x: int, y: int) -> void:
	var bottom := y
	while bottom < H and cell(x, bottom) == "Z":
		bottom += 1
	var p := CPUParticles2D.new()
	p.amount = 10
	p.lifetime = 1.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(7, 4)
	p.direction = Vector2.UP
	p.spread = 4.0
	p.gravity = Vector2.ZERO
	var h := (bottom - y) * T
	p.initial_velocity_min = h / 1.2
	p.initial_velocity_max = h / 1.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(1, 1, 1, 0.55)
	p.position = Vector2(x * T + 8, bottom * T)
	p.z_index = 1
	add_child(p)


func _build_background() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	var sky := TextureRect.new()
	sky.texture = load("res://assets/bg/w%d_sky.png" % world)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sky_layer.add_child(sky)
	var layers := [["far", 0.25, -4], ["near", 0.55, 8]]
	for spec in layers:
		var px := Parallax2D.new()
		px.scroll_scale = Vector2(spec[1], 1.0)
		px.repeat_size = Vector2(512, 0)
		px.repeat_times = 3
		px.z_index = -10
		var s := Sprite2D.new()
		s.texture = load("res://assets/bg/w%d_%s.png" % [world, spec[0]])
		s.centered = false
		s.position = Vector2(0, H * T - 256 + spec[2])
		px.add_child(s)
		add_child(px)


func _build_darkness() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_dark = ColorRect.new()
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec2 center = vec2(180.0, 300.0);
uniform vec2 rect_size = vec2(360.0, 640.0);
uniform float radius = 90.0;
void fragment() {
	vec2 p = UV * rect_size;
	float d = distance(p, center);
	float a = smoothstep(radius * 0.55, radius, d) * 0.93;
	COLOR = vec4(0.02, 0.01, 0.06, a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_dark.material = mat
	layer.add_child(_dark)


# ------------------------------------------------------------------ grid queries
func cell(x: int, y: int) -> String:
	if x < 0 or x >= W:
		return "#"
	if y < 0 or y >= H:
		return "."
	return grid[y][x]


func char_at_pos(p: Vector2) -> String:
	return cell(floori(p.x / T), floori(p.y / T))


func is_water(ch: String) -> bool:
	return WATER.has(ch)


func solid_at(p: Vector2) -> bool:
	return SOLID.has(char_at_pos(p))


func is_ground_at(p: Vector2) -> bool:
	var ch := char_at_pos(p)
	return SOLID.has(ch) or LEDGE.has(ch)


func grid_set(c: Vector2i, ch: String) -> void:
	if c.x >= 0 and c.x < W and c.y >= 0 and c.y < H:
		grid[c.y][c.x] = ch


## True if rect overlaps any cell of the given char (with the cell's top
## shrunk by top_inset so you must actually sink into it).
func rect_touches(r: Rect2, ch: String, top_inset: float) -> bool:
	var x0 := floori(r.position.x / T)
	var x1 := floori((r.end.x - 0.01) / T)
	var y0 := floori(r.position.y / T)
	var y1 := floori((r.end.y - 0.01) / T)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if cell(x, y) == ch:
				var cr := Rect2(x * T + 1, y * T + top_inset, T - 2, T - top_inset)
				if r.intersects(cr):
					return true
	return false


func bottom_y() -> float:
	return H * T


func fx_root() -> Node:
	return _fx


func near_camera(p: Vector2, margin: float) -> bool:
	var half := get_viewport_rect().size.x / 2.0 / _zoom
	return abs(p.x - _cam_pos.x) < half + margin


# ------------------------------------------------------------------ blocks
func try_reveal_hidden(head: Vector2, head_y_now: float) -> bool:
	var c := Vector2i(floori(head.x / T), floori(head.y / T))
	var b = _blocks.get(c)
	if b == null or b.kind != "hidden" or b.revealed:
		return false
	var block_bottom := (c.y + 1) * T
	if head_y_now < block_bottom - 1:
		return false
	b.reveal()
	player.global_position.y = block_bottom + player.H + 0.1
	return true


func bump_from_below(head: Vector2, p) -> void:
	var cy := floori(head.y / T)
	var best = null
	var best_key := Vector2i.ZERO
	var best_d := 999.0
	for ox in [0.0, -5.0, 5.0]:
		var c := Vector2i(floori((head.x + ox) / T), cy)
		var b = _blocks.get(c)
		if b and is_instance_valid(b) and b.revealed:
			var d: float = abs(b.global_position.x - head.x)
			if d < best_d:
				best_d = d
				best = b
				best_key = c
	if best:
		var breaks: bool = best.kind == "brick" and not best.used
		best.bump(p)
		if breaks:
			_blocks.erase(best_key)
	else:
		Audio.sfx("bump", 1.2)


func bump_enemies_above(block_pos: Vector2) -> void:
	var r := Rect2(block_pos.x - 8, block_pos.y - 8 - 6, 16, 6)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.alive and r.intersects(e.rect()) and e.has_method("knock"):
			e.knock(0.0)
			add_score(200, e.global_position)
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.is_coin and r.intersects(p.rect()):
			p.collect(player)


func spawn_power_from_block(pos: Vector2, p) -> void:
	var kind: String = _power_list[_power_idx % _power_list.size()]
	_power_idx += 1
	if kind == "shield" and p.shield:
		kind = "heart" if p.hp < p.MAX_HP else "life"
	var item := _pickup("power", pos + Vector2(0, 12), "", kind)
	item.collected = true
	var tw := item.create_tween()
	tw.tween_property(item, "position:y", pos.y, 0.4)
	tw.tween_callback(func():
		item.collected = false
		item._base_y = item.position.y)
	Audio.sfx("powerup", 0.7)


func coin_pop(pos: Vector2) -> void:
	add_coin(pos)
	var s := Res.sprite("coin", {"spin": [0, 1, 2, 3]}, 16.0)
	s.position = pos
	_fx.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", pos.y - 24, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", pos.y - 8, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)


# ------------------------------------------------------------------ spawning
func spawn_blast(pos: Vector2, dir: int) -> void:
	var p := ProjectileScript.new()
	p.kind = "blast"
	p.friendly = true
	p.level = self
	p.position = pos
	p.vel = Vector2(dir * 230.0, 60.0)
	p.gravity = 600.0
	p.life = 1.6
	_entities.add_child(p)
	Audio.sfx("blast")


func spawn_projectile(kind: String, pos: Vector2, vel: Vector2, gravity: float) -> void:
	var p := ProjectileScript.new()
	p.kind = kind
	p.level = self
	p.position = pos
	p.vel = vel
	p.gravity = gravity
	_entities.add_child(p)


# ------------------------------------------------------------------ scoring
func add_score(pts: int, pos: Vector2) -> void:
	score += pts
	Res.popup(_fx, pos, str(pts))


func add_coin(pos: Vector2) -> void:
	coins += 1
	score += 50
	_coins_for_life += 1
	Audio.sfx("coin")
	Res.burst(_fx, pos, Color("ffd23f"), 4, 40, 0.3, 0, 1.5)
	if _coins_for_life >= 100:
		_coins_for_life -= 100
		add_life(pos)


func add_gem(pos: Vector2) -> void:
	gems += 1
	add_score(500, pos)
	Audio.sfx("gem")
	Res.burst(_fx, pos, Color("3fd6ff"), 10, 60, 0.5, 0)


func add_secret(pos: Vector2) -> void:
	secrets += 1
	add_score(2000, pos)
	Audio.sfx("secret")
	Res.burst(_fx, pos, Color("ff5fd2"), 20, 100, 0.8, 0)
	show_banner("Secret found! %d/%d" % [secrets, total_secrets])


func add_life(pos: Vector2) -> void:
	Game.lives = mini(Game.lives + 1, 99)
	Audio.sfx("oneup")
	Res.popup(_fx, pos, "1UP", Color("4caf50"))


func mark_collected(id: String) -> void:
	if id != "":
		collected[id] = true


# ------------------------------------------------------------------ events
func set_checkpoint(pos: Vector2) -> void:
	Game.checkpoint = {
		"key": Game.level_key(world, level_num),
		"pos": pos,
		"coins": coins, "gems": gems, "score": score, "secrets": secrets, "time": time,
		"collected": collected.duplicate(), "coins_for_life": _coins_for_life,
	}
	show_banner("Checkpoint!")


func show_sign(text: String) -> void:
	_sign_text = text
	_sign_t = 0.15


func show_banner(text: String) -> void:
	if hud:
		hud.banner(text)


func camera_shake(t: float, amp: float) -> void:
	_shake_t = max(_shake_t, t)
	_shake_amp = max(_shake_amp, amp)


func warp_player(target: Vector2) -> void:
	Audio.sfx("secret", 1.2)
	Res.burst(_fx, player.center(), Color("a47cff"), 16, 90, 0.5, 0)
	player.teleport(target)
	_cam_pos = _camera_target()
	Res.burst(_fx, player.center(), Color("a47cff"), 16, 90, 0.5, 0)


func on_player_dead() -> void:
	if no_death:
		return
	state = "dead"
	controls.release_all()
	Game.lives -= 1
	await get_tree().create_timer(1.8).timeout
	if Game.lives <= 0:
		_show_game_over()
	else:
		Game.goto(Game.LEVEL_SCRIPT)


func complete(_pos: Vector2) -> void:
	if state != "play":
		return
	state = "complete"
	controls.release_all()
	player.finish()
	Audio.stop_music()
	Audio.sfx("clear")
	var time_bonus := maxi(0, par - int(time)) * 20
	score += time_bonus + player.hp * 300
	var stars := [coins >= ceili(total_coins * 0.7), secrets >= total_secrets, time <= par]
	var res := Game.record_result(world, level_num, score, time, stars, coins)
	Game.checkpoint = {}
	await get_tree().create_timer(1.6).timeout
	_show_results(stars, time_bonus, res)


func boss_defeated(pos: Vector2) -> void:
	add_score(5000, pos)
	Audio.play_music(data.get_str("music", "w1"))
	hud.hide_boss()
	show_banner("Victory!")
	if goal:
		goal.activate_goal()


# ------------------------------------------------------------------ arena
func arena_left() -> float:
	return _arena.x * T


func arena_right() -> float:
	return _arena.y * T


func arena_floor() -> float:
	return 15 * T


func _check_boss() -> void:
	if boss == null or _boss_started or _arena.x < 0:
		return
	if player.global_position.x > _arena.x * T + 40:
		_boss_started = true
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		add_child(wall)
		_add_rect(wall, Rect2(_arena.x * T - T, -T * 8, T, (H + 8) * T), false)
		var barrier := Node2D.new()
		for y in range(1, 15):
			var s := Sprite2D.new()
			s.texture = tile_texture
			s.region_enabled = true
			s.region_rect = Rect2(5 * T, 0, T, T)
			s.position = Vector2(_arena.x * T - 8, y * T + 8)
			barrier.add_child(s)
		add_child(barrier)
		Audio.play_music("boss")
		hud.show_boss(boss)
		show_banner(boss.display_name())
		boss.start_fight()


# ------------------------------------------------------------------ loop
func _physics_process(delta: float) -> void:
	if state == "play":
		time += delta
	_sign_t -= delta
	_check_boss()
	# fake walls fade when the player is behind them
	var behind := _fake.get_cell_source_id(Vector2i(floori(player.center().x / T), floori(player.center().y / T))) != -1
	_fake.modulate.a = move_toward(_fake.modulate.a, 0.45 if behind else 1.0, delta * 3.0)


func _process(delta: float) -> void:
	if player == null:
		return
	var target := _camera_target()
	_cam_pos.x = lerp(_cam_pos.x, target.x, min(1.0, delta * 7.0))
	_cam_pos.y = lerp(_cam_pos.y, target.y, min(1.0, delta * 5.0))
	if abs(_cam_pos.x - target.x) > 300:
		_cam_pos = target
	var off := Vector2.ZERO
	if _shake_t > 0.0:
		_shake_t -= delta
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amp
	else:
		_shake_amp = 0.0
	cam.position = (_cam_pos + off).round()
	hud.set_sign(_sign_text if _sign_t > 0.0 else "")
	if _dark:
		var vs := get_viewport_rect().size
		var sp: Vector2 = player.get_global_transform_with_canvas().origin + Vector2(0, -7 * _zoom)
		var m: ShaderMaterial = _dark.material
		m.set_shader_parameter("center", sp)
		m.set_shader_parameter("rect_size", vs)
		m.set_shader_parameter("radius", 95.0 * _zoom)


func _layout() -> void:
	var vs := get_viewport_rect().size
	var panel: float = controls.panel_height()
	var avail := vs.y - panel
	_zoom = clamp(avail / ((H + 0.6) * T), 1.0, vs.x / (15.0 * T))
	_zoom = max(_zoom, 1.0)
	cam.zoom = Vector2(_zoom, _zoom)
	_base_cam_y = H * T - (vs.y / 2.0 - panel) / _zoom


func _limits() -> Vector2:
	var px: float = player.global_position.x
	if _boss_started and boss != null and is_instance_valid(boss):
		return Vector2(_arena.x * T - T, _arena.y * T + T)
	for r in _rooms:
		if px >= r.x * T and px <= r.y * T:
			return Vector2(r.x * T, r.y * T)
	return Vector2(0, _main_end)


func _camera_target() -> Vector2:
	var vs := get_viewport_rect().size
	var half_w := vs.x / 2.0 / _zoom
	var half_h := vs.y / 2.0 / _zoom
	var lim := _limits()
	var x: float = player.global_position.x + player.facing * 20.0
	if lim.y - lim.x <= half_w * 2.0:
		x = (lim.x + lim.y) / 2.0
	else:
		x = clamp(x, lim.x + half_w, lim.y - half_w)
	var y := _base_cam_y
	var top := y - half_h
	if player.global_position.y - 40.0 < top:
		y = player.global_position.y - 40.0 + half_h
	return Vector2(x, y)


# ------------------------------------------------------------------ pause / overlays
func auto_pause() -> void:
	if state == "play" and not get_tree().paused:
		open_pause()


func on_back() -> void:
	if _overlay and is_instance_valid(_overlay):
		if state == "play":
			close_pause()
		return
	if state == "play":
		open_pause()


func open_pause() -> void:
	if state != "play" or get_tree().paused:
		return
	controls.release_all()
	get_tree().paused = true
	Audio.sfx("pause")
	Audio.duck_music(true)
	_overlay = _make_overlay("Paused")
	var v: VBoxContainer = _overlay.get_meta("box")
	v.add_child(UIKit.label("%d-%d  %s" % [world, level_num, data.get_str("name")], 16, UIKit.ACCENT))
	v.add_child(UIKit.button("Resume", close_pause))
	v.add_child(UIKit.button("Restart", func():
		UIKit.confirm(_overlay, "Restart this level from the beginning?", func():
			get_tree().paused = false
			Game.restart_level(), "Restart")))
	v.add_child(_volume_row("Music", "music"))
	v.add_child(_volume_row("Sound", "sfx"))
	v.add_child(UIKit.button("Main Menu", func():
		UIKit.confirm(_overlay, "Quit to the main menu? Progress in this level will be lost.", func():
			Game.checkpoint = {}
			Game.goto("res://scripts/ui/main_menu.gd"), "Quit")))


func close_pause() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	get_tree().paused = false
	Audio.duck_music(false)
	Game.save_game()


func _volume_row(text: String, key: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := UIKit.label(text, 16)
	l.custom_minimum_size = Vector2(70, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 1
	s.step = 0.05
	s.value = Game.setting(key)
	s.custom_minimum_size = Vector2(150, 30)
	s.value_changed.connect(func(v): Game.set_setting(key, v))
	h.add_child(s)
	return h


func _make_overlay(title: String) -> Control:
	var root := Control.new()
	UIKit.root(root)
	_pause_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.1, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var panel := PanelContainer.new()
	cc.add_child(panel)
	var v := UIKit.vbox(12)
	v.custom_minimum_size = Vector2(280, 0)
	panel.add_child(v)
	v.add_child(UIKit.label(title, 30, UIKit.ACCENT))
	root.set_meta("box", v)
	return root


func _show_results(stars: Array, time_bonus: int, res: Dictionary) -> void:
	get_tree().paused = true
	_overlay = _make_overlay("Level Clear!")
	var v: VBoxContainer = _overlay.get_meta("box")
	v.add_child(UIKit.star_row(3, stars, 40))
	var labels := ["Coins %d%%+" % 70, "All secrets", "Par time"]
	var hl := HBoxContainer.new()
	hl.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var l := UIKit.label(labels[i], 11, UIKit.ACCENT if stars[i] else Color("8a80a0"))
		l.custom_minimum_size = Vector2(84, 0)
		hl.add_child(l)
	v.add_child(hl)
	var mins := int(time) / 60
	var secs := int(time) % 60
	var lines := [
		"Score   %d%s" % [score, "  NEW BEST!" if res.get("new_best") else ""],
		"Coins   %d / %d" % [coins, total_coins],
		"Gems   %d     Secrets   %d / %d" % [gems, secrets, total_secrets],
		"Time   %d:%02d   (par %d:%02d)" % [mins, secs, par / 60, par % 60],
		"Time bonus   +%d" % time_bonus,
	]
	for line in lines:
		v.add_child(UIKit.label(line, 16))
	var final := world == Game.WORLDS and level_num == Game.LEVELS
	if final:
		v.add_child(UIKit.button("Continue", func(): Game.goto("res://scripts/ui/victory.gd")))
	else:
		v.add_child(UIKit.button("Next Level", func():
			var w := world
			var l := level_num + 1
			if l > Game.LEVELS:
				w += 1
				l = 1
			Game.start_level(w, l)))
	v.add_child(UIKit.button("Replay", func(): Game.start_level(world, level_num)))
	v.add_child(UIKit.button("Level Map", func():
		Game.goto("res://scripts/ui/level_select.gd", {"world": world})))


func _show_game_over() -> void:
	Audio.sfx("gameover")
	get_tree().paused = true
	_overlay = _make_overlay("Game Over")
	var v: VBoxContainer = _overlay.get_meta("box")
	v.add_child(UIKit.label("You ran out of lives.\nYour unlocked levels are safe!", 16))
	v.add_child(UIKit.button("Retry", func():
		Game.lives = Game.START_LIVES
		Game.start_level(world, level_num)))
	v.add_child(UIKit.button("Main Menu", func():
		Game.lives = Game.START_LIVES
		Game.goto("res://scripts/ui/main_menu.gd")))


func _show_tutorial() -> void:
	get_tree().paused = true
	var root := Control.new()
	UIKit.root(root)
	_pause_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.1, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var vs := get_viewport_rect().size
	var ph: float = controls.panel_height()
	var tips := [
		[Vector2(vs.x * 0.25, vs.y - ph * 0.55), "MOVE\nslide your thumb\nleft / right"],
		[Vector2(vs.x * 0.75, vs.y - ph * 0.3), "JUMP\nhold = higher"],
		[Vector2(vs.x * 0.75, vs.y - ph * 0.82), "RUN / BLAST"],
		[Vector2(56, 70), "Pause"],
	]
	for t in tips:
		var l := UIKit.label(t[1], 16, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, true)
		l.size = Vector2(170, 70)
		l.position = t[0] - Vector2(85, 30)
		root.add_child(l)
	var head := UIKit.label("Welcome to the Pixel Kingdom!\nReach the beacon at the end of each level.\n\nTap anywhere to start", 18, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	head.size = Vector2(vs.x - 32, 160)
	head.position = Vector2(16, vs.y * 0.22)
	root.add_child(head)
	root.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			Game.set_setting("tutorial_seen", true)
			Game.save_game()
			root.queue_free()
			get_tree().paused = false)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
