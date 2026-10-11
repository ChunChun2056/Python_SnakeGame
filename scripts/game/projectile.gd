extends Node2D
## Projectiles: the player's energy blast and enemy/boss shots.

const Res = preload("res://scripts/game/res.gd")
const FRAMES := {"fire": [0, 1], "snow": [2], "blast": [3], "orb": [4]}

var kind := "fire"
var level: Node
var vel := Vector2.ZERO
var gravity := 0.0
var life := 4.0
var friendly := false
var _spr: AnimatedSprite2D


func _ready() -> void:
	_spr = Res.sprite("projectiles", {"fly": FRAMES[kind]}, 10.0, 8, 8)
	add_child(_spr)
	if kind == "orb":
		_spr.scale = Vector2(1.5, 1.5)
	if not friendly:
		add_to_group("hazards")


func rect() -> Rect2:
	var r := 3.0 if kind != "orb" else 5.0
	return Rect2(global_position.x - r, global_position.y - r, r * 2, r * 2)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	vel.y += gravity * delta
	var nxt := position + vel * delta
	if friendly:
		# bounce along the floor like a skipping stone
		if level.solid_at(nxt + Vector2(0, 3)) and vel.y > 0:
			vel.y = -170.0
			nxt.y = position.y
		if level.solid_at(nxt + Vector2(sign(vel.x) * 3, 0)):
			_pop()
			return
		position = nxt
		var r := rect()
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.alive and e.active and r.intersects(e.rect()):
				e.hit_by_blast(sign(vel.x))
				_pop()
				return
	else:
		position = nxt
		if kind != "orb" and level.solid_at(position):
			_pop()
			return
	_spr.rotation += delta * 10.0


func _pop() -> void:
	Res.burst(level.fx_root(), global_position, Color("ffe14a") if kind != "snow" else Color("ffffff"), 6, 50, 0.3, 0)
	queue_free()
