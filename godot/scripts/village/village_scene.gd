class_name VillageScene
extends Control
## Écran principal : assemble VillageBackdrop (ciel/sol/collines), VillageDecor
## (arbres/nuages) et VillageBuildings (les 7 générateurs), gère le texte
## d'accroche et le tap. Toucher un bâtiment qu'on possède (niveau >= 1)
## frappe une pièce ; le décor ou un bâtiment pas encore acheté ne rapportent
## rien. Coordonnées dans l'espace de conception 1080x1920.

const DESIGN_WIDTH := 1080.0
const DESIGN_HEIGHT := 1920.0
const GROUND_TOP := 700.0        # ligne d'horizon : ciel au-dessus, sol en dessous
const GROUND_Y := 1500.0         # ligne de base de la rangée avant — garde une marge sous le pied de page HUD
const PRODUCTION_POP_INTERVAL := 3.0

var _manifest: SpriteManifest
var _buildings: VillageBuildings
var _fx_layer: Node2D
var _hint: Label
var _pop_timer: float = 0.0


static func create() -> VillageScene:
	var v := VillageScene.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v._manifest = SpriteManifest.load_default()
	v._build()
	return v


func _build() -> void:
	add_child(VillageBackdrop.create(_manifest))

	var world := Node2D.new()
	add_child(world)
	world.add_child(VillageDecor.create())
	_buildings = VillageBuildings.create(_manifest)
	world.add_child(_buildings)
	_fx_layer = Node2D.new()
	world.add_child(_fx_layer)

	_hint = Label.new()
	_hint.theme_type_variation = "RowMeta"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.position = Vector2(0, GROUND_TOP + 24)   # juste sous l'horizon, loin du pied de page HUD
	_hint.size = Vector2(DESIGN_WIDTH, 40)
	add_child(_hint)

	refresh()


## Reconstruit les bâtiments (ex. changement de Remote Config).
func rebuild() -> void:
	_buildings.rebuild()


func refresh() -> void:
	_buildings.refresh()
	_hint.text = "Touchez un bâtiment possédé — +%s or par frappe" % NumberFormat.short(Economy.tap_gold_amount())


## Toucher un bâtiment qu'on possède (niveau >= 1) frappe une pièce ; toucher
## le décor ou un bâtiment pas encore acheté ne rapporte rien. Seul
## l'événement souris est traité : sur mobile, Godot émule la souris depuis
## le tactile (paramètre par défaut), traiter aussi InputEventScreenTouch
## compterait deux frappes.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var target := _buildings.owned_building_at(event.position)
	if target == null:
		return
	var amount := Economy.tap()
	_pop(target.position + Vector2(0, target.top_y() * target.scale.y - 10), amount)
	accept_event()


## Pièces qui s'élèvent des bâtiments actifs, au rythme de leur production.
func _process(delta: float) -> void:
	if not GameState.is_ready():
		return
	_pop_timer += delta
	if _pop_timer < PRODUCTION_POP_INTERVAL:
		return
	_pop_timer = 0.0
	var mult := Economy.global_multiplier()
	for def in Config.get_generators():
		var level := GameState.data.level_of(def.id)
		var b := _buildings.get_building(def.id)
		if level <= 0 or b == null:
			continue
		var pps := EconomyFormulas.production_per_sec({def.id: level}, [def], mult)
		_pop(b.position + Vector2(0, b.top_y() * b.scale.y - 10), pps * PRODUCTION_POP_INTERVAL)


func _pop(pos: Vector2, amount: float) -> void:
	CoinPop.spawn(_fx_layer, pos, "+%s" % NumberFormat.short(amount), _manifest.coin_texture(), _manifest.pixel_scale)
