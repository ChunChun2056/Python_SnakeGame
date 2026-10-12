extends Node
## Automated smoke test. Run with:
##   godot -- --test [--shots=DIR] [--only=W_L]
## Loads every level, sweeps the player through it (invulnerable) so all
## entities activate, fights each boss to defeat, completes the level and
## opens every menu screen. Prints a summary line per level and optional
## screenshots. Exit code is the number of failures.

const LEVEL := "res://scripts/game/level.gd"

var shots_dir := ""
var only := ""
var failures := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a.begins_with("--only="):
			only = a.substr(7)
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	Game.data["settings"]["tutorial_seen"] = true
	Game.data["settings"]["music"] = 0.0
	Game.data["settings"]["sfx"] = 0.0
	await _run()


func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	# menus
	for s in ["main_menu", "world_select", "settings", "credits", "victory"]:
		if only != "" and only != "menus":
			break
		var node: Node = load("res://scripts/ui/%s.gd" % s).new()
		_swap(node)
		await _frames(30)
		await _shot("menu_" + s)
	if only == "" or only == "menus":
		var ls: Node = load("res://scripts/ui/level_select.gd").new()
		ls.world = 1
		_swap(ls)
		await _frames(30)
		await _shot("menu_level_select")
	if only == "" or only == "menus":
		await _test_controls_and_pause()
		await _test_mechanics()
		await _test_terrain()
	for w in range(1, Game.WORLDS + 1):
		for l in range(1, Game.LEVELS + 1):
			if only != "" and not ("%d_%d" % [w, l]) in only.split(","):
				continue
			await _test_level(w, l)
	print("TEST SUMMARY failures=%d" % failures)
	get_tree().quit(failures)


func _swap(node: Node) -> void:
	get_tree().paused = false
	var old := get_tree().current_scene
	get_tree().root.add_child(node)
	get_tree().current_scene = node
	if old and old != self:
		old.queue_free()


func _test_level(w: int, l: int) -> void:
	Game.world = w
	Game.level = l
	Game.checkpoint = {}
	Game.lives = 5
	var lvl: Node = load(LEVEL).new()
	lvl.no_death = true
	_swap(lvl)
	await _frames(20)
	var p = lvl.player
	var ok := true
	if p == null:
		print("FAIL %d-%d no player" % [w, l])
		failures += 1
		return
	await _shot("w%d_%d_start" % [w, l])
	# sweep through the level with the player invulnerable
	var end_x: float = lvl._main_end
	var steps := 8
	for i in steps:
		var x := lerpf(64.0, end_x - 120.0, float(i) / (steps - 1))
		p.invuln = 99.0
		p.teleport(_safe_spot(lvl, x))
		Input.action_press("move_right")
		Input.action_press("run")
		for f in 50:
			p.invuln = 99.0
			if f % 20 == 0:
				Input.action_press("jump")
			elif f % 20 == 12:
				Input.action_release("jump")
			await get_tree().physics_frame
		Input.action_release("move_right")
		Input.action_release("run")
		Input.action_release("jump")
		if i == 3 or i == 6:
			await _shot("w%d_%d_mid%d" % [w, l, i])
		if p.dead:
			# pits can still kill: revive for the sweep
			p.dead = false
			p.hp = 3
			p.collision_mask = 1
			p.z_index = 2
			lvl.state = "play"
	# boss fight
	if lvl.boss != null:
		var b = lvl.boss
		p.invuln = 99.0
		p.teleport(Vector2(lvl._arena.x * 16 + 60, 14 * 16))
		await _frames(120)
		await _shot("w%d_%d_boss" % [w, l])
		if not lvl._boss_started:
			print("FAIL %d-%d boss did not start" % [w, l])
			ok = false
		var guard := 0
		while is_instance_valid(b) and b.alive and guard < 40:
			p.invuln = 99.0
			b.invuln = 0.0
			b.on_stomp(p)
			await _frames(30)
			guard += 1
		await _frames(120)
		if not lvl.goal.enabled:
			print("FAIL %d-%d goal not enabled after boss" % [w, l])
			ok = false
	# finish
	p.invuln = 99.0
	lvl.goal.on_touch(p)
	await _frames(150)
	await _shot("w%d_%d_clear" % [w, l])
	var done := Game.is_level_done(w, l)
	if not done:
		ok = false
		print("FAIL %d-%d not recorded as done" % [w, l])
	var enemies := get_tree().get_nodes_in_group("enemies").size()
	print("%s %d-%d coins=%d/%d secrets=%d score=%d enemies_left=%d" % [
		"PASS" if ok else "FAIL", w, l, lvl.coins, lvl.total_coins, lvl.total_secrets, lvl.score, enemies])
	if not ok:
		failures += 1
	get_tree().paused = false


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = get_viewport().get_final_transform() * pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		print("FAIL check: " + what)
	else:
		print("PASS check: " + what)


func _test_controls_and_pause() -> void:
	Game.world = 1
	Game.level = 1
	Game.checkpoint = {}
	Game.data["settings"]["tutorial_seen"] = false
	var lvl: Node = load(LEVEL).new()
	lvl.no_death = true
	_swap(lvl)
	await _frames(10)
	await _shot("tutorial")
	_check(get_tree().paused, "tutorial pauses the game on first play")
	Game.data["settings"]["tutorial_seen"] = true
	for c in lvl._pause_layer.get_children():
		c.queue_free()
	get_tree().paused = false
	await _frames(5)
	var vs := get_viewport().get_visible_rect().size
	var g: Dictionary = lvl.controls._geom()
	# finger 0 on the right arrow, finger 1 on jump at the same time
	_touch(0, g["right"], true)
	_touch(1, g["jump"], true)
	await _frames(2)
	_check(Input.is_action_pressed("move_right") and Input.is_action_pressed("jump"), "simultaneous move + jump")
	var x0: float = lvl.player.global_position.x
	await _frames(20)
	_check(lvl.player.global_position.x > x0 + 10, "player moves right from touch")
	# slide finger 0 onto the left arrow
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = get_viewport().get_final_transform() * g["left"]
	Input.parse_input_event(drag)
	await _frames(2)
	_check(Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "slide between arrows")
	_touch(2, g["run"], true)
	await _frames(2)
	_check(Input.is_action_pressed("run"), "run button")
	_touch(0, g["left"], false)
	_touch(1, g["jump"], false)
	_touch(2, g["run"], false)
	await _frames(2)
	_check(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("jump"), "release")
	await _shot("controls")
	lvl.open_pause()
	await _frames(5)
	_check(get_tree().paused, "pause menu pauses")
	await _shot("pause")
	lvl.close_pause()
	await _frames(2)
	_check(not get_tree().paused, "resume")
	lvl.auto_pause()
	_check(get_tree().paused, "auto pause on app focus loss")
	lvl.close_pause()
	await _frames(2)


func _test_mechanics() -> void:
	Game.world = 1
	Game.level = 1
	Game.checkpoint = {}
	Game.lives = 5
	var lvl: Node = load(LEVEL).new()
	lvl.no_death = true
	_swap(lvl)
	await _frames(10)
	var p = lvl.player
	# full jump height
	p.teleport(Vector2(8 * 16 + 8, 15 * 16))
	await _frames(10)
	var y0: float = p.global_position.y
	Input.action_press("jump")
	var apex := y0
	for i in 50:
		await get_tree().physics_frame
		apex = min(apex, p.global_position.y)
		if i == 20:
			# second press mid-air must not double jump
			Input.action_release("jump")
			await get_tree().physics_frame
			Input.action_press("jump")
	Input.action_release("jump")
	var rise := y0 - apex
	_check(rise > 58.0 and rise < 76.0, "full jump rise %.1f px (expected ~70)" % rise)
	await _frames(40)
	_check(p.is_on_floor() and absf(p.global_position.y - y0) < 0.5, "lands back on the floor")
	# short hop
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	apex = y0
	for i in 40:
		await get_tree().physics_frame
		apex = min(apex, p.global_position.y)
	_check(y0 - apex < 30.0, "tap gives a short hop (%.1f px)" % (y0 - apex))
	await _frames(30)
	# stomp an enemy
	var e = lvl.spawn_enemy("e", Vector2(20 * 16 + 8, 15 * 16))
	await _frames(5)
	e.active = true
	p.teleport(e.global_position + Vector2(0, -40))
	p.velocity = Vector2(0, 100)
	await _frames(30)
	_check(not e.alive and p.hp == 3, "stomp defeats enemy without damage")
	# side hit hurts
	var e2 = lvl.spawn_enemy("e", Vector2(20 * 16 + 8, 15 * 16))
	await _frames(5)
	e2.active = true
	p.invuln = 0.0
	p.teleport(e2.global_position + Vector2(-4, 0))
	await _frames(3)
	_check(p.hp == 2, "side contact costs a heart (hp=%d)" % p.hp)
	await _frames(100)
	# checkpoint + death respawn
	p.invuln = 0.0
	p.hp = 3
	p.teleport(Vector2(64 * 16 + 8, 15 * 16))
	await _frames(5)
	_check(not Game.checkpoint.is_empty(), "checkpoint activates")
	lvl.no_death = false
	var lives := Game.lives
	p.die()
	await _frames(200)
	var nl: Node = get_tree().current_scene
	_check(Game.lives == lives - 1, "death costs a life")
	_check(nl != lvl and nl.player != null and nl.player.global_position.distance_to(Vector2(64 * 16 + 8, 15 * 16)) < 4.0,
		"respawn at checkpoint")
	nl.no_death = true
	# save / load round trip
	Game.data["levels"]["9-9"] = {"done": true, "stars": [true, false, true], "best_score": 1234}
	Game.save_game()
	Game.data = {}
	Game.load_game()
	_check(Game.level_info(9, 9).get("best_score", 0) == 1234, "save data persists")
	Game.data["levels"].erase("9-9")
	Game.save_game()


func _load(w: int, l: int) -> Node:
	Game.world = w
	Game.level = l
	Game.checkpoint = {}
	var lvl: Node = load(LEVEL).new()
	lvl.no_death = true
	_swap(lvl)
	await _frames(10)
	lvl.player.invuln = 999.0
	return lvl


func _find(lvl, ch: String) -> Vector2i:
	for x in lvl.W:
		for y in lvl.H:
			if lvl.grid[y][x] == ch:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _test_terrain() -> void:
	# wind lifts the player
	var lvl: Node = await _load(4, 1)
	var z := _find(lvl, "Z")
	var bottom := z.y
	while lvl.cell(z.x, bottom + 1) == "Z":
		bottom += 1
	lvl.player.teleport(Vector2(z.x * 16 + 8, bottom * 16))
	var y0: float = lvl.player.global_position.y
	await _frames(40)
	_check(lvl.player.global_position.y < y0 - 40.0, "wind column lifts the player (%.0f px)" % (y0 - lvl.player.global_position.y))
	# moving platform carries the player
	var plat = null
	for n in lvl._entities.get_children():
		if n.get("kind") == "move_h":
			plat = n
			break
	if plat:
		lvl.player.teleport(plat.global_position + Vector2(0, -2))
		await _frames(4)
		var px: float = lvl.player.global_position.x
		var ppx: float = plat.global_position.x
		await _frames(30)
		var moved: float = plat.global_position.x - ppx
		_check(absf((lvl.player.global_position.x - px) - moved) < 4.0 and lvl.player.is_on_floor(),
			"moving platform carries the player")
	# spring launches the player high
	lvl = await _load(1, 3)
	var spring = null
	for n in lvl._entities.get_children():
		if n.get("kind") == "spring":
			spring = n
			break
	_check(spring != null, "level 1-3 has a spring")
	if spring:
		lvl.player.teleport(spring.global_position + Vector2(0, -20))
		var sy: float = spring.global_position.y
		var top := sy
		for i in 40:
			await get_tree().physics_frame
			top = min(top, lvl.player.global_position.y)
		_check(sy - top > 110.0, "spring launches high (%.0f px)" % (sy - top))
	# water: slow sinking and swim strokes
	lvl = await _load(6, 2)
	var wc := Vector2i(-1, -1)
	for x in range(10, lvl.W):
		if lvl.cell(x, 8) == "W" and lvl.cell(x, 9) == "W" and lvl.cell(x, 7) == "W":
			wc = Vector2i(x, 9)
			break
	lvl.player.teleport(Vector2(wc.x * 16 + 8, wc.y * 16))
	await _frames(30)
	_check(lvl.player.in_water and lvl.player.velocity.y <= 76.0, "water slows falling")
	var wy: float = lvl.player.global_position.y
	for i in 4:
		Input.action_press("jump")
		await _frames(2)
		Input.action_release("jump")
		await _frames(10)
	_check(lvl.player.global_position.y < wy - 8.0, "swim strokes rise")
	_check(lvl.player.air < lvl.player.AIR_MAX, "air meter drains underwater")
	# quicksand slows movement
	lvl = await _load(2, 2)
	var q := _find(lvl, "Q")
	lvl.player.teleport(Vector2(q.x * 16 + 8, q.y * 16))
	Input.action_press("move_right")
	await _frames(40)
	var vq: float = absf(lvl.player.velocity.x)
	Input.action_release("move_right")
	_check(vq < 45.0, "quicksand slows walking (%.0f px/s)" % vq)
	# crumbling platform falls after being stood on
	var cr = null
	for n in lvl._entities.get_children():
		if n.get("kind") == "crumble":
			cr = n
			break
	if cr:
		lvl.player.teleport(cr.global_position + Vector2(0, -1))
		await _frames(50)
		_check(cr._state == "fall", "crumbling platform collapses")
	# ice: sliding stop distance is longer
	lvl = await _load(5, 1)
	var p = lvl.player
	var ice := Vector2i(-1, -1)
	for x in range(8, lvl.W - 20):
		var ok := true
		for k in 14:
			if lvl.cell(x + k, 15) != "I" or lvl.cell(x + k, 14) != "." or lvl.cell(x + k, 13) != ".":
				ok = false
				break
		if ok:
			ice = Vector2i(x, 15)
			break
	p.teleport(Vector2(ice.x * 16 + 8, 15 * 16))
	Input.action_press("move_right")
	await _frames(45)
	Input.action_release("move_right")
	var sx: float = p.global_position.x
	await _frames(60)
	var slide: float = p.global_position.x - sx
	_check(slide > 20.0, "ice keeps momentum (slid %.0f px)" % slide)


func _safe_spot(lvl, x: float) -> Vector2:
	var cx := int(x / 16)
	for dx in range(0, 40):
		for c in [cx + dx, cx - dx]:
			for y in range(2, 17):
				var below: String = lvl.cell(c, y + 1)
				if lvl.cell(c, y) == "." and lvl.cell(c, y - 1) == "." and (below in ["#", "X", "I"]):
					return Vector2(c * 16 + 8, (y + 1) * 16)
	return Vector2(x, 14 * 16)
