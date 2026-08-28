class_name DioramaView
extends PanelContainer
## Bandeau visuel au-dessus du registre : une silhouette (GeneratorActor) par
## type de générateur, alignées sur un emplacement fixe par palier — un
## emplacement verrouillé reste réservé, juste très atténué (le village se
## "révèle" au fil de la progression plutôt que de changer de mise en page).

const STAGE_HEIGHT := 200.0
const SLOT_WIDTH := 130.0
const STAGE_WIDTH := 1024.0   # largeur utile de l'écran (1080 - marges de main.gd)

var _canvas: Control
var _stage: Node2D
var _actors: Dictionary = {}   # id -> GeneratorActor


static func create() -> DioramaView:
	var d := DioramaView.new()
	d._build()
	return d


func _build() -> void:
	theme_type_variation = "HeaderPanel"

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(0, STAGE_HEIGHT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	_stage = Node2D.new()
	_canvas.add_child(_stage)

	rebuild()


func rebuild() -> void:
	for c in _stage.get_children():
		c.queue_free()
	_actors.clear()

	var defs := Config.get_generators()
	var start_x := (STAGE_WIDTH - defs.size() * SLOT_WIDTH) * 0.5 + SLOT_WIDTH * 0.5
	var i := 0
	for def in defs:
		var actor := GeneratorActor.create(def)
		actor.position = Vector2(start_x + i * SLOT_WIDTH, STAGE_HEIGHT - 30)
		_stage.add_child(actor)
		_actors[def.id] = actor
		i += 1

	refresh()


func refresh() -> void:
	for id in _actors:
		var actor: GeneratorActor = _actors[id]
		var unlocked := Economy.is_unlocked(id)
		actor.set_locked(not unlocked)
		if unlocked:
			actor.set_level(GameState.data.level_of(id))


## Petit retour visuel sur tap (cf. Economy.tapped) : un léger "thump" sur
## tout le diorama, sans dépendre d'un asset ou d'un système de particules.
func pulse() -> void:
	var t := create_tween()
	t.tween_property(_stage, "scale", Vector2(1.05, 1.05), 0.05)
	t.tween_property(_stage, "scale", Vector2(1, 1), 0.15)
