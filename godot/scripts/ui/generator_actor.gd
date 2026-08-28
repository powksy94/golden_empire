class_name GeneratorActor
extends Node2D
## Représentation visuelle d'un type de générateur dans le diorama : une
## silhouette géométrique simple (aucun asset externe pour l'instant, cf.
## README § UI), avec une légère animation idle et un badge de niveau.
## Remplaçable plus tard par de vrais sprites (Sprite2D/AnimatedSprite2D)
## sans changer DioramaView — seul _make_shape() aurait à changer.

var _shape: Node2D
var _badge: Label
var _bob_phase: float
var _locked: bool = true


static func create(def: GeneratorDef) -> GeneratorActor:
	var a := GeneratorActor.new()
	a._bob_phase = randf() * TAU
	a._build(def)
	return a


func _build(def: GeneratorDef) -> void:
	_shape = _make_shape(def.tier)
	add_child(_shape)

	_badge = Label.new()
	_badge.theme_type_variation = "RowMeta"
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.custom_minimum_size = Vector2(80, 0)
	_badge.position = Vector2(-40, 8)
	add_child(_badge)

	set_locked(true)


func _process(delta: float) -> void:
	if _locked:
		return
	_bob_phase += delta * 2.0
	_shape.position.y = sin(_bob_phase) * 4.0


func set_locked(locked: bool) -> void:
	_locked = locked
	_shape.modulate = Color(1, 1, 1, 0.12) if locked else Color(1, 1, 1, 1)
	_badge.visible = not locked


func set_level(level: int) -> void:
	_badge.text = "niv. %d" % level


# ------------------------------------------------------------------ silhouettes
# Une forme distincte par palier (1..7), en attendant de vrais assets. Chaque
# silhouette a son "sol" en y=0 et s'étend vers le haut (y négatif).

func _make_shape(tier: int) -> Node2D:
	match tier:
		1: return _peasant()
		2: return _farm()
		3: return _mine()
		4: return _caravan()
		5: return _bank()
		6: return _port()
		_: return _guild()


func _poly(points: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	return p


func _circle_points(center: Vector2, radius: float, segments: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


func _peasant() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-9,-40),Vector2(9,-40),Vector2(9,0),Vector2(-9,0)]), EmpireTheme.PARCHMENT))
	n.add_child(_poly(_circle_points(Vector2(0,-48), 10), EmpireTheme.GOLD))
	return n


func _farm() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-26,0),Vector2(26,0),Vector2(26,-30),Vector2(-26,-30)]), EmpireTheme.GOLD_DIM))
	n.add_child(_poly(PackedVector2Array([Vector2(-30,-30),Vector2(30,-30),Vector2(0,-52)]), EmpireTheme.COPPER))
	return n


func _mine() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-34,0),Vector2(34,0),Vector2(0,-56)]), Color("4a4038")))
	n.add_child(_poly(PackedVector2Array([Vector2(-10,0),Vector2(10,0),Vector2(10,-18),Vector2(-10,-18)]), Color("18120c")))
	n.add_child(_poly(PackedVector2Array([Vector2(4,-30),Vector2(12,-26),Vector2(6,-18)]), EmpireTheme.GOLD))
	return n


func _caravan() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-28,-8),Vector2(24,-8),Vector2(30,-30),Vector2(-22,-30)]), EmpireTheme.COPPER))
	n.add_child(_poly(_circle_points(Vector2(-16,0), 8), Color("2a2015")))
	n.add_child(_poly(_circle_points(Vector2(16,0), 8), Color("2a2015")))
	return n


func _bank() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-32,0),Vector2(32,0),Vector2(32,-36),Vector2(-32,-36)]), EmpireTheme.GOLD_DIM))
	n.add_child(_poly(PackedVector2Array([Vector2(-36,-36),Vector2(36,-36),Vector2(0,-56)]), EmpireTheme.GOLD))
	for x in [-20, 0, 20]:
		n.add_child(_poly(PackedVector2Array([Vector2(x-4,0),Vector2(x+4,0),Vector2(x+4,-36),Vector2(x-4,-36)]), EmpireTheme.PANEL))
	return n


func _port() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-32,0),Vector2(32,0),Vector2(22,-16),Vector2(-22,-16)]), EmpireTheme.SAGE))
	n.add_child(_poly(PackedVector2Array([Vector2(0,-16),Vector2(0,-56),Vector2(24,-16)]), EmpireTheme.PARCHMENT))
	return n


func _guild() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-16,0),Vector2(16,0),Vector2(16,-50),Vector2(-16,-50)]), EmpireTheme.COPPER))
	n.add_child(_poly(PackedVector2Array([Vector2(16,-50),Vector2(38,-44),Vector2(16,-38)]), EmpireTheme.GOLD))
	return n
