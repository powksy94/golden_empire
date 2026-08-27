class_name GeneratorRow
extends PanelContainer
## Une ligne de "registre" pour un générateur : nom, niveau, production, coût,
## bouton d'achat. Construite entièrement en code (pas de .tscn dédié) pour
## rester simple à faire évoluer pendant la phase de placeholders.
##
## Le nombre de niveaux achetés par clic suit le BuyMode global (x1/x10/MAX),
## transmis par GameScreen à chaque refresh().

var generator_id: String
var _name_label: Label
var _meta_label: Label
var _buy_button: Button
var _alt_row: bool
var _pending_count: int = 1


static func create(def: GeneratorDef, alt_row: bool) -> GeneratorRow:
	var row := GeneratorRow.new()
	row.generator_id = def.id
	row._alt_row = alt_row
	row._build(def)
	return row


func _build(def: GeneratorDef) -> void:
	theme_type_variation = "RowPanelAlt" if _alt_row else "RowPanel"

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	add_child(h)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	h.add_child(text_col)

	_name_label = Label.new()
	_name_label.theme_type_variation = "RowName"
	text_col.add_child(_name_label)

	_meta_label = Label.new()
	_meta_label.theme_type_variation = "RowMeta"
	text_col.add_child(_meta_label)

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(220, 0)
	_buy_button.pressed.connect(func(): Economy.buy(generator_id, _pending_count))
	h.add_child(_buy_button)


func refresh(def: GeneratorDef, buy_mode: int = BuyMode.ONE) -> void:
	var unlocked := Economy.is_unlocked(generator_id)
	var level := GameState.data.level_of(generator_id)

	if not unlocked:
		theme_type_variation = "RowPanelLocked"
		_name_label.text = def.name
		_name_label.modulate = Color(1, 1, 1, 0.35)
		_meta_label.text = "Débloque à %s or cumulé" % NumberFormat.short(def.unlock_at)
		_buy_button.text = "Verrouillé"
		_buy_button.disabled = true
		return

	theme_type_variation = "RowPanelAlt" if _alt_row else "RowPanel"
	_name_label.modulate = Color(1, 1, 1, 1)
	_name_label.text = "%s — niv. %d" % [def.name, level]
	_meta_label.text = "%s or/s par niveau" % NumberFormat.short(def.base_production)

	_pending_count = _resolve_count(buy_mode)
	_buy_button.text = "Acheter x%d — %s" % [_pending_count, NumberFormat.short(Economy.cost_of(generator_id, _pending_count))]
	_buy_button.disabled = not Economy.can_buy(generator_id, _pending_count)


## Nombre de niveaux à acheter pour le mode donné. En mode MAX, retombe sur 1
## si rien n'est abordable (affiche le prochain palier, désactivé).
func _resolve_count(buy_mode: int) -> int:
	match buy_mode:
		BuyMode.TEN:
			return 10
		BuyMode.MAX:
			return maxi(1, Economy.max_affordable(generator_id))
		_:
			return 1
