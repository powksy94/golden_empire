class_name PlaceholderShapes
extends RefCounted
## Silhouettes géométriques de secours (Polygon2D), utilisées quand le manifest
## de sprites ne fournit pas de texture. Le jeu reste jouable et testable sans
## aucun asset externe. Chaque forme a son "sol" en y=0 et s'étend vers le haut.

const SCALE := 1.6   # les formes ont été dessinées pour un bandeau de 200 px


static func building(tier: int) -> Node2D:
	var n: Node2D
	match tier:
		1: n = _hut()
		2: n = _farm()
		3: n = _mine()
		4: n = _caravan()
		5: n = _bank()
		6: n = _port()
		_: n = _guild()
	n.scale = Vector2(SCALE, SCALE)
	return n


static func worker() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-6,-26),Vector2(6,-26),Vector2(6,0),Vector2(-6,0)]), EmpireTheme.PARCHMENT))
	n.add_child(_poly(_circle_points(Vector2(0,-32), 7), EmpireTheme.GOLD))
	n.scale = Vector2(SCALE, SCALE)
	return n


static func coin() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(_circle_points(Vector2.ZERO, 12), EmpireTheme.GOLD))
	n.add_child(_poly(_circle_points(Vector2.ZERO, 7), EmpireTheme.GOLD_DIM))
	return n


## Arbre de décor vu de profil (tronc + feuillage) — pas un asset externe, donc
## pas de risque de mauvaise perspective comme une tuile vue du dessus posée
## debout. `variant` choisit rond (feuillu) ou pointu (conifère).
static func tree(variant: int = 0) -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-4,0),Vector2(4,0),Vector2(3,-26),Vector2(-3,-26)]), Color("4a3a28")))
	if variant == 0:
		n.add_child(_poly(_circle_points(Vector2(0,-46), 22), EmpireTheme.SAGE))
	else:
		n.add_child(_poly(PackedVector2Array([Vector2(-20,-24),Vector2(20,-24),Vector2(0,-64)]), Color("3a5a44")))
	return n


## Nuage de décor (quelques disques qui se chevauchent) — pour casser la
## platitude d'un dégradé de ciel uni, sans dépendre d'une image externe.
static func cloud() -> Node2D:
	var n := Node2D.new()
	var color := Color(1.0, 1.0, 1.0, 0.5)
	var puffs := [
		{"pos": Vector2(-34, 4), "r": 16.0},
		{"pos": Vector2(-10, -6), "r": 22.0},
		{"pos": Vector2(16, -3), "r": 20.0},
		{"pos": Vector2(38, 5), "r": 14.0},
		{"pos": Vector2(4, 8), "r": 18.0},
	]
	for p in puffs:
		n.add_child(_poly(_circle_points(p["pos"], p["r"]), color))
	return n


static func _poly(points: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	return p


static func _circle_points(center: Vector2, radius: float, segments: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


static func _hut() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-20,0),Vector2(20,0),Vector2(20,-24),Vector2(-20,-24)]), EmpireTheme.PARCHMENT))
	n.add_child(_poly(PackedVector2Array([Vector2(-24,-24),Vector2(24,-24),Vector2(0,-44)]), EmpireTheme.GOLD_DIM))
	return n


static func _farm() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-26,0),Vector2(26,0),Vector2(26,-30),Vector2(-26,-30)]), EmpireTheme.GOLD_DIM))
	n.add_child(_poly(PackedVector2Array([Vector2(-30,-30),Vector2(30,-30),Vector2(0,-52)]), EmpireTheme.COPPER))
	return n


static func _mine() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-34,0),Vector2(34,0),Vector2(0,-56)]), EmpireTheme.LOCKED))
	n.add_child(_poly(PackedVector2Array([Vector2(-10,0),Vector2(10,0),Vector2(10,-18),Vector2(-10,-18)]), EmpireTheme.BG))
	n.add_child(_poly(PackedVector2Array([Vector2(4,-30),Vector2(12,-26),Vector2(6,-18)]), EmpireTheme.GOLD))
	return n


static func _caravan() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-28,-8),Vector2(24,-8),Vector2(30,-30),Vector2(-22,-30)]), EmpireTheme.COPPER))
	n.add_child(_poly(_circle_points(Vector2(-16,0), 8), EmpireTheme.PANEL))
	n.add_child(_poly(_circle_points(Vector2(16,0), 8), EmpireTheme.PANEL))
	return n


static func _bank() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-32,0),Vector2(32,0),Vector2(32,-36),Vector2(-32,-36)]), EmpireTheme.GOLD_DIM))
	n.add_child(_poly(PackedVector2Array([Vector2(-36,-36),Vector2(36,-36),Vector2(0,-56)]), EmpireTheme.GOLD))
	for x in [-20, 0, 20]:
		n.add_child(_poly(PackedVector2Array([Vector2(x-4,0),Vector2(x+4,0),Vector2(x+4,-36),Vector2(x-4,-36)]), EmpireTheme.PANEL))
	return n


static func _port() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-32,0),Vector2(32,0),Vector2(22,-16),Vector2(-22,-16)]), EmpireTheme.SAGE))
	n.add_child(_poly(PackedVector2Array([Vector2(0,-16),Vector2(0,-56),Vector2(24,-16)]), EmpireTheme.PARCHMENT))
	return n


static func _guild() -> Node2D:
	var n := Node2D.new()
	n.add_child(_poly(PackedVector2Array([Vector2(-16,0),Vector2(16,0),Vector2(16,-50),Vector2(-16,-50)]), EmpireTheme.COPPER))
	n.add_child(_poly(PackedVector2Array([Vector2(16,-50),Vector2(38,-44),Vector2(16,-38)]), EmpireTheme.GOLD))
	return n
