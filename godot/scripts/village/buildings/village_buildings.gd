class_name VillageBuildings
extends Node2D
## Les 7 bâtiments (un par générateur), répartis sur deux rangées avec
## profondeur (y-sort + échelle), leur mise en page dynamique (largeur réelle
## des sprites, pas des colonnes fixes) et le hit-test de tap. Le décor
## (arbres/nuages/collines) est ailleurs (VillageDecor/VillageBackdrop) —
## cette classe ne gère QUE les générateurs.

const BACK_ROW_DY := -280.0      # rangée arrière : plus haut sur le sol (profondeur)
const BACK_ROW_SCALE := 0.78
const ROW_GAP := 24.0            # espace entre deux bâtiments d'une même rangée

var _manifest: SpriteManifest
var _buildings: Dictionary = {}   # id -> GeneratorBuilding


static func create(manifest: SpriteManifest) -> VillageBuildings:
	var b := VillageBuildings.new()
	b.y_sort_enabled = true
	b._manifest = manifest
	b.rebuild()
	return b


## Bâtiment d'un générateur donné, ou null si inconnu.
func get_building(id: String) -> GeneratorBuilding:
	return _buildings.get(id)


## Le bâtiment possédé (niveau >= 1) dont le rectangle contient ce point (dans
## l'espace local de ce nœud), ou null si le point tombe sur le décor / un
## bâtiment verrouillé ou pas encore acheté.
func owned_building_at(point: Vector2) -> GeneratorBuilding:
	for id in _buildings:
		if GameState.data.level_of(id) <= 0:
			continue
		var b: GeneratorBuilding = _buildings[id]
		if b.screen_rect().has_point(point):
			return b
	return null


## Reconstruit les 7 bâtiments (ex. après un changement de Remote Config qui
## modifierait la liste de générateurs).
func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_buildings.clear()

	var back_row: Array[GeneratorBuilding] = []
	var front_row: Array[GeneratorBuilding] = []
	var i := 0
	for def in Config.get_generators():
		var b := GeneratorBuilding.create(def, _manifest)
		add_child(b)
		_buildings[def.id] = b
		if i % 2 == 0:
			b.scale = Vector2(BACK_ROW_SCALE, BACK_ROW_SCALE)
			back_row.append(b)
		else:
			front_row.append(b)
		i += 1

	_layout_row(back_row, VillageScene.GROUND_Y + BACK_ROW_DY)
	_layout_row(front_row, VillageScene.GROUND_Y)

	refresh()


## Centre une rangée de bâtiments côte à côte, espacés selon leur largeur
## réelle à l'écran (variable d'un sprite à l'autre) — évite tout
## chevauchement quels que soient les gabarits des sprites du manifest.
func _layout_row(row: Array[GeneratorBuilding], y: float) -> void:
	var widths: Array[float] = []
	for b in row:
		widths.append(b.visual_width() * b.scale.x)
	var total := 0.0
	for w in widths:
		total += w
	total += ROW_GAP * maxf(row.size() - 1, 0.0)

	var x := (VillageScene.DESIGN_WIDTH - total) * 0.5
	for j in row.size():
		x += widths[j] * 0.5
		row[j].position = Vector2(x, y)
		x += widths[j] * 0.5 + ROW_GAP


## Met à jour l'état verrouillé/niveau de chaque bâtiment (appelé à chaque
## changement d'or/production).
func refresh() -> void:
	for id in _buildings:
		var b: GeneratorBuilding = _buildings[id]
		var unlocked := Economy.is_unlocked(id)
		b.set_locked(not unlocked)
		if unlocked:
			b.set_level(GameState.data.level_of(id))
