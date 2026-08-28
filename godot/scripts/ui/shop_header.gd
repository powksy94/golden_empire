class_name ShopHeader
extends PanelContainer
## En-tête de l'écran boutique : titre, solde de gemmes, bouton de fermeture.

signal close_pressed

var _gems_label: Label


static func create() -> ShopHeader:
	var h := ShopHeader.new()
	h._build()
	return h


func _build() -> void:
	theme_type_variation = "HeaderPanel"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = "BOUTIQUE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	_gems_label = Label.new()
	_gems_label.theme_type_variation = "Section"
	_gems_label.add_theme_color_override("font_color", EmpireTheme.COPPER)
	_gems_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_gems_label)

	var close_btn := Button.new()
	close_btn.theme_type_variation = "QuietButton"
	close_btn.text = "Fermer"
	close_btn.pressed.connect(func(): close_pressed.emit())
	row.add_child(close_btn)


func set_gems(amount: int) -> void:
	_gems_label.text = "%d gemmes" % amount
