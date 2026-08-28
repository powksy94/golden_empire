class_name ShopScreen
extends Control
## Écran boutique, superposé à GameScreen (masqué par défaut). Assemble
## ShopHeader + une liste de ShopRow peuplée via ShopCatalog ; n'implémente
## lui-même ni le formatage (ShopCatalog) ni le rendu d'une ligne (ShopRow).

signal closed

var _header: ShopHeader
var _list: VBoxContainer
var _booster_rows: Dictionary = {}   # id -> ShopRow


static func create() -> ShopScreen:
	var s := ShopScreen.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.visible = false
	s._build()
	return s


func _ready() -> void:
	GameState.gems_changed.connect(func(_g): refresh())
	Config.config_updated.connect(_rebuild)


func open() -> void:
	visible = true
	refresh()


func _build() -> void:
	var background := ColorRect.new()
	background.color = EmpireTheme.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_header = ShopHeader.create()
	_header.close_pressed.connect(func():
		visible = false
		closed.emit()
	)
	root.add_child(_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)

	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_booster_rows.clear()

	var i := 0
	i = _add_section(i, "Boosters (gemmes)")
	var boosters := Config.get_boosters()
	for id in boosters:
		var row := ShopRow.create(i % 2 == 1)
		_configure_booster_row(row, id, boosters[id])
		_list.add_child(row)
		_booster_rows[id] = row
		i += 1

	if OS.is_debug_build():
		i = _add_section(i, "Debug")
		var debug_row := ShopRow.create(i % 2 == 1)
		debug_row.set_content("Gemmes de test", "Ne fonctionne qu'en build debug", "+100 gemmes",
			func(): GameState.add_gems_debug(100))
		_list.add_child(debug_row)
		i += 1

	i = _add_section(i, "Achats (bientôt disponibles)")
	var products := Config.get_products()
	for id in products:
		var row := ShopRow.create(i % 2 == 1)
		row.set_content(ShopCatalog.product_name(products[id]), ShopCatalog.product_meta(products[id]), "Bientôt disponible", Callable())
		_list.add_child(row)
		i += 1

	refresh()


func _add_section(i: int, text: String) -> int:
	var l := Label.new()
	l.theme_type_variation = "Section"
	l.text = text
	_list.add_child(l)
	return i + 1


func _configure_booster_row(row: ShopRow, id: String, b: Dictionary) -> void:
	if not ShopCatalog.booster_is_functional(b):
		row.set_content(id, "Bientôt disponible", "—", Callable())
		return
	row.set_content(ShopCatalog.booster_name(b), ShopCatalog.booster_meta(b), "Acheter",
		func(): Economy.buy_booster(id), int(b.get("gem_cost", 0)))


func refresh() -> void:
	var gems := int(GameState.data.economy["gems"])
	_header.set_gems(gems)
	for id in _booster_rows:
		(_booster_rows[id] as ShopRow).refresh_afford(gems)
