class_name GameScreen
extends Control
## Composition de l'écran de jeu : en-tête, bouton de frappe, sélecteur de
## mode d'achat, registre des générateurs, pied de page. Se tient à jour seule
## via les signaux de GameState / Economy / Config ; main.gd ne fait que lui
## relayer des messages de statut pendant la séquence de boot.

var _header: HeaderPanel
var _diorama: DioramaView
var _tap_btn: TapButton
var _buy_mode: BuyModeSelector
var _list: VBoxContainer
var _footer: FooterPanel
var _shop: ShopScreen
var _gen_rows: Dictionary = {}   # id -> GeneratorRow


static func create() -> GameScreen:
	var s := GameScreen.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s._build()
	return s


func _ready() -> void:
	GameState.gold_changed.connect(func(_g): _refresh())
	GameState.gems_changed.connect(func(_g): _refresh())
	Economy.production_changed.connect(func(_p): _refresh())
	Economy.tapped.connect(func(_amount): _diorama.pulse())
	Config.config_updated.connect(_on_config_updated)
	Economy.prestiged.connect(func(c, m): set_status("Prestige ! +%d pts de prestige — multiplicateur x%.2f" % [int(c), m]))


func _on_config_updated() -> void:
	_rebuild_generator_rows()
	_diorama.rebuild()


func set_status(text: String) -> void:
	_header.set_status(text)


func _build() -> void:
	var background := ColorRect.new()
	background.color = EmpireTheme.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	_header = HeaderPanel.create()
	root.add_child(_header)

	_diorama = DioramaView.create()
	root.add_child(_diorama)

	_tap_btn = TapButton.create()
	root.add_child(_tap_btn)

	_buy_mode = BuyModeSelector.create()
	_buy_mode.mode_changed.connect(func(_m): _refresh())
	root.add_child(_buy_mode)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(_list)
	root.add_child(scroll)

	_footer = FooterPanel.create()
	root.add_child(_footer)

	_rebuild_generator_rows()

	_shop = ShopScreen.create()
	_footer.open_shop_requested.connect(func(): _shop.open())
	add_child(_shop)


func _rebuild_generator_rows() -> void:
	for c in _list.get_children():
		c.queue_free()
	_gen_rows.clear()
	var i := 0
	for def in Config.get_generators():
		var row := GeneratorRow.create(def, i % 2 == 1)
		_list.add_child(row)
		_gen_rows[def.id] = row
		i += 1
	_refresh()


func _refresh() -> void:
	_header.refresh()
	_diorama.refresh()
	_tap_btn.refresh()
	for id in _gen_rows:
		var def := Config.get_generator(id)
		var row: GeneratorRow = _gen_rows[id]
		row.refresh(def, _buy_mode.mode)
	_footer.refresh()
