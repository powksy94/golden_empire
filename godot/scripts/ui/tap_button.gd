class_name TapButton
extends Button
## Bouton "Frapper une pièce" (tap-to-earn) : affiche le gain par tap, avec un
## bref retour visuel ("+X or !") après chaque frappe.

var _flash_until_ms: int = 0


static func create() -> TapButton:
	var b := TapButton.new()
	b._build()
	return b


func _build() -> void:
	theme_type_variation = "TapButton"
	custom_minimum_size = Vector2(0, 88)
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var amount := Economy.tap()
	_flash(amount)


## Le libellé affiche brièvement le gain, puis revient au libellé standard
## (sans être écrasé par un refresh() entre-temps).
func _flash(amount: float) -> void:
	text = "+%s or !" % NumberFormat.short(amount)
	_flash_until_ms = GameState.now_ms() + 350
	var t := get_tree().create_timer(0.35)
	t.timeout.connect(func():
		if is_instance_valid(self):
			refresh()
	)


func refresh() -> void:
	if GameState.now_ms() < _flash_until_ms:
		return
	text = "Frapper une pièce — +%s" % NumberFormat.short(Economy.tap_gold_amount())
