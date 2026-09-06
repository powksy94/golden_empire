class_name GeneratorBuilding
extends Node2D
## Un bâtiment du village = un type de générateur : sprite (ou silhouette de
## secours), état verrouillé (entièrement masqué mais l'emplacement reste
## réservé — un fantôme translucide fonctionnait avec de simples silhouettes,
## mais rendait les illustrations détaillées illisibles/confuses), badge de
## niveau, et ses ouvriers qui vont et viennent — un de plus tous les
## WORKERS_PER_LEVEL niveaux, plafonné. Le sol est en y=0.

const MAX_WORKERS := 4
const WORKERS_PER_LEVEL := 10
const WORKER_HALF_RANGE := 60.0
# Masqué le temps de trouver un personnage au même niveau de détail que les
# bâtiments (illustrations IA) — le sprite pixel art Kenney (16px) rendait à
# côté d'eux méconnaissable ("c'est quoi le sprite bleu ?"). La logique de
# niveau/déblocage des ouvriers reste intacte, prête pour un futur asset.
const SHOW_WORKERS := false

var generator_id: String
var _tier: int
var _manifest: SpriteManifest
var _visual: Node2D
var _badge: Label
var _workers: Node2D
var _level: int = -1


static func create(def: GeneratorDef, manifest: SpriteManifest) -> GeneratorBuilding:
	var b := GeneratorBuilding.new()
	b.generator_id = def.id
	b._tier = def.tier
	b._manifest = manifest
	b._build()
	return b


func _build() -> void:
	var tex := _manifest.building_texture(generator_id)
	if tex:
		var s := Sprite2D.new()
		s.texture = tex
		# Illustrations peintes (IA), pas des tuiles pixel art : filtrage lisse,
		# pas de crénelage NEAREST.
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var target_height: float = _manifest.building_height(generator_id)
		var factor: float = target_height / tex.get_height() if target_height > 0.0 else _manifest.pixel_scale
		s.scale = Vector2(factor, factor)
		s.offset = Vector2(0, -tex.get_height() * 0.5)   # sprite centré -> base au sol
		_visual = s
	else:
		_visual = PlaceholderShapes.building(_tier)
	add_child(_visual)

	_workers = Node2D.new()
	_workers.position.y = 6   # un poil devant le bâtiment
	add_child(_workers)

	_badge = Label.new()
	_badge.theme_type_variation = "RowMeta"
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.custom_minimum_size = Vector2(120, 0)
	_badge.position = Vector2(-60, 14)
	add_child(_badge)

	set_locked(true)


## Hauteur du visuel (échelle réellement appliquée, cf. _build), pour placer
## les pièces au-dessus du toit.
func top_y() -> float:
	if _visual is Sprite2D:
		var sp := _visual as Sprite2D
		return -sp.texture.get_height() * sp.scale.y
	return -56.0 * PlaceholderShapes.SCALE


## Largeur du visuel (échelle réellement appliquée), pour espacer les
## bâtiments dans village_scene.gd sans qu'ils se chevauchent.
func visual_width() -> float:
	if _visual is Sprite2D:
		var sp := _visual as Sprite2D
		return sp.texture.get_width() * sp.scale.x
	return 68.0 * PlaceholderShapes.SCALE


## Rectangle occupé par le bâtiment dans l'espace du parent (_buildings_layer),
## pour détecter un tap sur CE bâtiment précis (cf. VillageScene._gui_input) —
## un peu élargi (MARGIN) pour rester facile à toucher au doigt sur mobile.
const TAP_MARGIN := 16.0

func screen_rect() -> Rect2:
	var w := visual_width() * scale.x
	var h := -top_y() * scale.y
	return Rect2(
		position.x - w * 0.5 - TAP_MARGIN, position.y - h - TAP_MARGIN,
		w + TAP_MARGIN * 2.0, h + TAP_MARGIN * 2.0)


func set_locked(locked: bool) -> void:
	_visual.visible = not locked
	_badge.visible = not locked
	_workers.visible = not locked


func set_level(level: int) -> void:
	if level == _level:
		return
	_level = level
	_badge.text = "niv. %d" % level
	_sync_workers(level)


func _sync_workers(level: int) -> void:
	var target := 0
	if SHOW_WORKERS and level > 0:
		target = clampi(1 + int(level / float(WORKERS_PER_LEVEL)), 1, MAX_WORKERS)
	while _workers.get_child_count() > target:
		var c := _workers.get_child(_workers.get_child_count() - 1)
		_workers.remove_child(c)
		c.queue_free()
	while _workers.get_child_count() < target:
		_workers.add_child(WorkerActor.create(
			_manifest.worker_frames(generator_id), _manifest.worker_fps(generator_id),
			_manifest.pixel_scale, WORKER_HALF_RANGE))
