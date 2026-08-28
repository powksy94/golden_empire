class_name FooterPanel
extends VBoxContainer
## Pied de page : bouton de prestige + son indice, et actions utilitaires
## (boutique, sauvegarde manuelle, cheat de debug).

signal open_shop_requested

var _prestige_btn: Button
var _prestige_hint: Label


static func create() -> FooterPanel:
	var f := FooterPanel.new()
	f._build()
	return f


func _build() -> void:
	add_theme_constant_override("separation", 6)

	_prestige_btn = Button.new()
	_prestige_btn.theme_type_variation = "PrimaryButton"
	_prestige_btn.custom_minimum_size = Vector2(0, 64)
	_prestige_btn.pressed.connect(func(): Economy.do_prestige())
	add_child(_prestige_btn)

	_prestige_hint = Label.new()
	_prestige_hint.theme_type_variation = "RowMeta"
	_prestige_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prestige_hint.text = "Réinitialise l'or et les générateurs contre un multiplicateur permanent."
	add_child(_prestige_hint)

	var utility_row := HBoxContainer.new()
	utility_row.alignment = BoxContainer.ALIGNMENT_CENTER
	utility_row.add_theme_constant_override("separation", 16)
	add_child(utility_row)

	var shop_btn := Button.new()
	shop_btn.theme_type_variation = "QuietButton"
	shop_btn.text = "Boutique"
	shop_btn.pressed.connect(func(): open_shop_requested.emit())
	utility_row.add_child(shop_btn)

	var save_btn := Button.new()
	save_btn.theme_type_variation = "QuietButton"
	save_btn.text = "Sauvegarder maintenant"
	save_btn.pressed.connect(func(): SaveManager.request_save(true))
	utility_row.add_child(save_btn)

	# DEBUG UNIQUEMENT — masqué automatiquement hors build debug.
	if OS.is_debug_build():
		var cheat_btn := Button.new()
		cheat_btn.theme_type_variation = "QuietButton"
		cheat_btn.text = "[DEBUG] +1000 or"
		cheat_btn.pressed.connect(func(): GameState.add_gold(1000.0))
		utility_row.add_child(cheat_btn)


func refresh() -> void:
	var pending := Economy.pending_prestige()
	if Economy.can_prestige():
		_prestige_btn.text = "Prestige — gagner %d points" % int(pending)
		_prestige_hint.text = "Multiplicateur permanent : x%.2f → x%.2f" % [
			GameState.data.economy["prestigeMultiplier"],
			EconomyFormulas.prestige_multiplier(Economy.prestige_currency_if_now(), Config.get_float("prestige_mult_per_point", 0.02)),
		]
	else:
		_prestige_btn.text = "Prestige indisponible"
		_prestige_hint.text = "Continuez à jouer pour débloquer un premier prestige."
	_prestige_btn.disabled = not Economy.can_prestige()
