extends Node
## Global game state: save data, settings, run state (lives), progression,
## input map and screen transitions.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

const TILE := 16
const WORLDS := 8
const LEVELS := 5
const START_LIVES := 5
const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

const WORLD_NAMES := ["Green Meadows", "Sunbaked Desert", "Crystal Caverns", "Sky Islands",
	"Frozen Peaks", "Sunken Ruins", "Volcanic Depths", "Shadow Citadel"]
const WORLD_COLORS := [Color("5cc94a"), Color("f2c46d"), Color("6b7fd6"), Color("4aa8ff"),
	Color("bfe0ff"), Color("2a8aa8"), Color("ff6a1a"), Color("a47cff")]

const LEVEL_SCRIPT := "res://scripts/game/level.gd"

var data: Dictionary = {}
var lives := START_LIVES
var world := 1
var level := 1
## Snapshot taken at the last checkpoint touched in the current level.
var checkpoint: Dictionary = {}
var theme: Theme

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_game()
	theme = UIKit.make_theme()
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.05, 0.03, 0.1, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)
	if "--test" in OS.get_cmdline_user_args():
		var runner: Node = load("res://scripts/tests/test_runner.gd").new()
		add_child.call_deferred(runner)


# ------------------------------------------------------------------ input
func _setup_input() -> void:
	var map := {
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"jump": [KEY_SPACE, KEY_Z, KEY_UP, KEY_W],
		"run": [KEY_SHIFT, KEY_X],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	var pads := {"jump": JOY_BUTTON_A, "run": JOY_BUTTON_X, "pause": JOY_BUTTON_START,
		"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT}
	for action in pads:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pads[action]
		InputMap.action_add_event(action, jb)


# ------------------------------------------------------------------ save data
func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"levels": {},
		"settings": {"music": 0.7, "sfx": 0.8, "ui_scale": 1.0, "tutorial_seen": false},
	}


func load_game() -> void:
	data = _default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in parsed:
			if k == "settings" and typeof(parsed[k]) == TYPE_DICTIONARY:
				for s in parsed[k]:
					data["settings"][s] = parsed[k][s]
			else:
				data[k] = parsed[k]


func save_game() -> void:
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))


func reset_progress() -> void:
	var settings: Dictionary = data["settings"]
	data = _default_data()
	data["settings"] = settings
	data["settings"]["tutorial_seen"] = false
	save_game()


func setting(key: String):
	return data["settings"].get(key, _default_data()["settings"].get(key))


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	if key == "music" or key == "sfx":
		Audio.apply_volumes()


static func level_key(w: int, l: int) -> String:
	return "%d-%d" % [w, l]


func level_info(w: int, l: int) -> Dictionary:
	return data["levels"].get(level_key(w, l), {})


func is_level_done(w: int, l: int) -> bool:
	return level_info(w, l).get("done", false)


func is_world_unlocked(w: int) -> bool:
	if w <= 1:
		return true
	return is_level_done(w - 1, LEVELS)


func is_level_unlocked(w: int, l: int) -> bool:
	if not is_world_unlocked(w):
		return false
	if l <= 1:
		return true
	return is_level_done(w, l - 1)


func level_stars(w: int, l: int) -> int:
	var s: Array = level_info(w, l).get("stars", [false, false, false])
	var n := 0
	for b in s:
		if b:
			n += 1
	return n


func world_stars(w: int) -> int:
	var n := 0
	for l in range(1, LEVELS + 1):
		n += level_stars(w, l)
	return n


func total_stars() -> int:
	var n := 0
	for w in range(1, WORLDS + 1):
		n += world_stars(w)
	return n


## Returns [world, level] of the furthest unlocked level not yet finished.
func next_open_level() -> Array:
	for w in range(1, WORLDS + 1):
		for l in range(1, LEVELS + 1):
			if is_level_unlocked(w, l) and not is_level_done(w, l):
				return [w, l]
	return [WORLDS, LEVELS]


func record_result(w: int, l: int, score: int, time: float, stars: Array, coins: int) -> Dictionary:
	var key := level_key(w, l)
	var info: Dictionary = data["levels"].get(key, {})
	var first: bool = not info.get("done", false)
	var best: Array = info.get("stars", [false, false, false])
	var merged := []
	for i in 3:
		merged.append(bool(best[i]) or bool(stars[i]))
	info["done"] = true
	info["stars"] = merged
	var new_best: bool = score > int(info.get("best_score", 0))
	info["best_score"] = max(int(info.get("best_score", 0)), score)
	if not info.has("best_time") or time < float(info["best_time"]):
		info["best_time"] = time
	info["best_coins"] = max(int(info.get("best_coins", 0)), coins)
	data["levels"][key] = info
	save_game()
	return {"first": first, "new_best": new_best}


# ------------------------------------------------------------------ flow
func start_level(w: int, l: int, fresh := true) -> void:
	if fresh:
		checkpoint = {}
		if lives <= 0:
			lives = START_LIVES
	world = w
	level = l
	goto(LEVEL_SCRIPT)


func restart_level() -> void:
	checkpoint = {}
	goto(LEVEL_SCRIPT)


func goto(script_path: String, params: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	await fade(1.0, 0.25)
	get_tree().paused = false
	var old := get_tree().current_scene
	var node: Node = load(script_path).new()
	for k in params:
		node.set(k, params[k])
	get_tree().root.add_child(node)
	get_tree().current_scene = node
	if old:
		old.queue_free()
	await fade(0.0, 0.25)
	_busy = false


func fade(alpha: float, time: float) -> void:
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.5 else Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade_rect, "color:a", alpha, time)
	await tw.finished


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			save_game()
			var scene := get_tree().current_scene
			if scene and scene.has_method("auto_pause"):
				scene.auto_pause()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			var scene := get_tree().current_scene
			if scene and scene.has_method("on_back"):
				scene.on_back()
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_game()
