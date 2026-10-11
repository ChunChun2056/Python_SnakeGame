extends RefCounted
## Parses a level text file (see README "Level format").

var header := {}
var warps: Array = []        # [{src: Vector2i, dst: Vector2i}]
var signs: PackedStringArray = []
var rows: Array = []         # Array of Array[String] (one char per cell)
var width := 0
var height := 0


static func load_level(world: int, level: int) -> RefCounted:
	var d = load("res://scripts/game/level_data.gd").new()
	d.parse_file("res://levels/w%d_%d.txt" % [world, level])
	return d


func parse_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing level file " + path)
		return
	parse_text(f.get_as_text())


func parse_text(text: String) -> void:
	var in_grid := false
	for raw in text.split("\n"):
		var line := raw.strip_edges(false, true)
		if not in_grid:
			if line == "---":
				in_grid = true
				continue
			if line.is_empty() or line.begins_with(";"):
				continue
			var eq := line.find("=")
			if eq < 0:
				continue
			var key := line.substr(0, eq).strip_edges()
			var val := line.substr(eq + 1).strip_edges()
			match key:
				"warp":
					var parts := val.split(">")
					var a := parts[0].split(",")
					var b := parts[1].split(",")
					warps.append({"src": Vector2i(int(a[0]), int(a[1])), "dst": Vector2i(int(b[0]), int(b[1]))})
				"sign":
					signs.append(val)
				_:
					header[key] = val
		else:
			if line.is_empty():
				continue
			var r: Array = []
			for i in line.length():
				r.append(line[i])
			rows.append(r)
			width = max(width, r.size())
	height = rows.size()
	for r in rows:
		while r.size() < width:
			r.append(".")


func get_int(key: String, def := 0) -> int:
	return int(header.get(key, str(def)))


func get_str(key: String, def := "") -> String:
	return str(header.get(key, def))
