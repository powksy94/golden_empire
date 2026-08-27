class_name BuyModeSelector
extends HBoxContainer
## Sélecteur global x1/x10/MAX affiché au-dessus du registre de générateurs.
## Émet `mode_changed` pour que GameScreen redessine les lignes avec le bon
## nombre de niveaux à acheter.

signal mode_changed(mode: int)

var mode: int = BuyMode.ONE

var _group := ButtonGroup.new()


static func create() -> BuyModeSelector:
	var s := BuyModeSelector.new()
	s._build()
	return s


func _build() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	_add_option(BuyMode.ONE, "x1")
	_add_option(BuyMode.TEN, "x10")
	_add_option(BuyMode.MAX, "MAX")


func _add_option(value: int, label: String) -> void:
	var btn := Button.new()
	btn.theme_type_variation = "QuietButton"
	btn.toggle_mode = true
	btn.button_group = _group
	btn.text = label
	btn.button_pressed = value == mode
	btn.toggled.connect(func(is_pressed: bool):
		if is_pressed:
			mode = value
			mode_changed.emit(mode)
	)
	add_child(btn)
