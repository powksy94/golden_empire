class_name ShopRow
extends PanelContainer
## Une ligne de boutique générique : nom, sous-texte, bouton d'action.
## Réutilisée par ShopScreen pour les boosters (achat en gemmes, fonctionnel)
## et le catalogue IAP (affichage seul pour l'instant).

var _name_label: Label
var _meta_label: Label
var _action_button: Button
var _on_press: Callable
var _gem_cost: int = -1   # >= 0 : bouton sensible au solde via refresh_afford()


static func create(alt_row: bool) -> ShopRow:
	var row := ShopRow.new()
	row._build(alt_row)
	return row


func _build(alt_row: bool) -> void:
	theme_type_variation = "RowPanelAlt" if alt_row else "RowPanel"

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

	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(200, 0)
	_action_button.pressed.connect(func():
		if _on_press.is_valid():
			_on_press.call()
	)
	h.add_child(_action_button)


## `on_press` invalide (Callable() par défaut) rend le bouton en permanence
## désactivé — utilisé pour le catalogue IAP tant qu'aucun achat réel n'est
## possible (pas de plugin StoreKit/Play Billing, cf. README § Non couvert).
## `gem_cost` >= 0 relie en plus l'état du bouton au solde via refresh_afford().
func set_content(name_text: String, meta_text: String, button_text: String, on_press: Callable, gem_cost: int = -1) -> void:
	_name_label.text = name_text
	_meta_label.text = meta_text
	_action_button.text = button_text
	_on_press = on_press
	_gem_cost = gem_cost
	_action_button.disabled = not on_press.is_valid()


func refresh_afford(gems: int) -> void:
	if _gem_cost >= 0 and _on_press.is_valid():
		_action_button.disabled = gems < _gem_cost
