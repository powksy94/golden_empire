class_name OverlayHeader
extends PanelContainer
## En-tête d'un écran en overlay (boutique, registre) : titre, une info à
## droite (solde de gemmes, or…) et un bouton de fermeture.

signal close_pressed

var _info: Label


static func create(title_text: String) -> OverlayHeader:
	var h := OverlayHeader.new()
	h._build(title_text)
	return h


func _build(title_text: String) -> void:
	theme_type_variation = "HeaderPanel"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	_info = Label.new()
	_info.theme_type_variation = "Section"
	_info.add_theme_color_override("font_color", EmpireTheme.COPPER)
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_info)

	var close_btn := Button.new()
	close_btn.theme_type_variation = "QuietButton"
	close_btn.text = "Fermer"
	close_btn.pressed.connect(func(): close_pressed.emit())
	row.add_child(close_btn)


func set_info(text: String) -> void:
	_info.text = text
