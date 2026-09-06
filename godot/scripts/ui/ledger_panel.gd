class_name LedgerPanel
extends Control
## Registre des générateurs en overlay (masqué par défaut, ouvert depuis le pied
## de page) : sélecteur x1/x10/MAX + une GeneratorRow par générateur. Se tient
## à jour seul via les signaux, mais seulement quand il est visible.

signal closed

var _header: OverlayHeader
var _buy_mode: BuyModeSelector
var _list: VBoxContainer
var _rows: Dictionary = {}   # id -> GeneratorRow


static func create() -> LedgerPanel:
	var p := LedgerPanel.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	p._build()
	return p


func _ready() -> void:
	GameState.gold_changed.connect(_on_state_changed)
	Economy.production_changed.connect(_on_state_changed)
	Config.config_updated.connect(_rebuild)


func _on_state_changed(_value) -> void:
	if visible:
		refresh()


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

	_header = OverlayHeader.create("REGISTRE")
	_header.close_pressed.connect(func():
		visible = false
		closed.emit()
	)
	root.add_child(_header)

	_buy_mode = BuyModeSelector.create()
	_buy_mode.mode_changed.connect(func(_m): refresh())
	root.add_child(_buy_mode)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	var i := 0
	for def in Config.get_generators():
		var row := GeneratorRow.create(def, i % 2 == 1)
		_list.add_child(row)
		_rows[def.id] = row
		i += 1
	refresh()


func refresh() -> void:
	_header.set_info("%s or" % NumberFormat.short(float(GameState.data.economy["gold"])))
	for id in _rows:
		(_rows[id] as GeneratorRow).refresh(Config.get_generator(id), _buy_mode.mode)
