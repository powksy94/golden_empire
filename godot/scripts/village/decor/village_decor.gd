class_name VillageDecor
extends Node2D
## Décor purement esthétique de la scène village (arbres, nuages) — ne
## participe à aucune logique de jeu, jamais reconstruit après coup. Formes
## procédurales (`PlaceholderShapes`) : les tuiles vue-du-dessus du pack Kenney
## rendaient mal posées debout dans une scène de profil.

# Positions fixes pour ne pas "sauter" à chaque lancement.
const TREES := [
	{"variant": 0, "x": 60.0, "y": 1230.0, "scale": 2.2},
	{"variant": 1, "x": 260.0, "y": 1780.0, "scale": 2.6},
	{"variant": 1, "x": 540.0, "y": 1200.0, "scale": 2.2},
	{"variant": 0, "x": 800.0, "y": 1800.0, "scale": 2.6},
	{"variant": 0, "x": 1020.0, "y": 1250.0, "scale": 2.2},
	{"variant": 1, "x": 950.0, "y": 1780.0, "scale": 2.4},
]

const CLOUDS := [
	{"x": 160.0, "y": 220.0, "scale": 1.6},
	{"x": 620.0, "y": 160.0, "scale": 2.0},
	{"x": 900.0, "y": 320.0, "scale": 1.4},
	{"x": 360.0, "y": 420.0, "scale": 1.2},
]


static func create() -> VillageDecor:
	var d := VillageDecor.new()
	d._build()
	return d


func _build() -> void:
	for c in CLOUDS:
		var cl := PlaceholderShapes.cloud()
		cl.scale = Vector2(c["scale"], c["scale"])
		cl.position = Vector2(c["x"], c["y"])
		add_child(cl)

	for t in TREES:
		var tr := PlaceholderShapes.tree(int(t["variant"]))
		tr.scale = Vector2(t["scale"], t["scale"])
		tr.position = Vector2(t["x"], t["y"])
		add_child(tr)
