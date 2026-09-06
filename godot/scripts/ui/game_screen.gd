class_name GameScreen
extends Control
## Composition de l'écran de jeu : la scène village en fond (VillageScene),
## un HUD par-dessus (en-tête en haut, pied de page en bas, le milieu laisse
## passer les touches vers la scène), et deux overlays masqués par défaut
## (registre d'achat, boutique). Se tient à jour seule via les signaux de
## GameState / Economy / Config ; main.gd ne fait que lui relayer des messages
## de statut pendant la séquence de boot.

var _village: VillageScene
var _header: HeaderPanel
var _footer: FooterPanel
var _ledger: LedgerPanel
var _shop: ShopScreen


static func create() -> GameScreen:
	var s := GameScreen.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s._build()
	return s


func _ready() -> void:
	GameState.gold_changed.connect(func(_g): _refresh())
	GameState.gems_changed.connect(func(_g): _refresh())
	Economy.production_changed.connect(func(_p): _refresh())
	Config.config_updated.connect(func(): _village.rebuild())
	Economy.prestiged.connect(func(c, m): set_status("Prestige ! +%d pts de prestige — multiplicateur x%.2f" % [int(c), m]))


func set_status(text: String) -> void:
	_header.set_status(text)


func _build() -> void:
	_village = VillageScene.create()
	add_child(_village)

	# HUD : seuls l'en-tête et le pied de page interceptent les touches ; le
	# reste (conteneurs, espace central) les laisse passer à la scène.
	var hud := MarginContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_constant_override("margin_left", 28)
	hud.add_theme_constant_override("margin_right", 28)
	hud.add_theme_constant_override("margin_top", 24)
	hud.add_theme_constant_override("margin_bottom", 24)
	add_child(hud)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(col)

	_header = HeaderPanel.create()
	_header.theme_type_variation = "HudPanel"
	col.add_child(_header)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	var footer_panel := PanelContainer.new()
	footer_panel.theme_type_variation = "HudPanel"
	_footer = FooterPanel.create()
	footer_panel.add_child(_footer)
	col.add_child(footer_panel)

	_ledger = LedgerPanel.create()
	_footer.open_ledger_requested.connect(func(): _ledger.open())
	add_child(_ledger)

	_shop = ShopScreen.create()
	_footer.open_shop_requested.connect(func(): _shop.open())
	add_child(_shop)

	_refresh()


func _refresh() -> void:
	_header.refresh()
	_village.refresh()
	_footer.refresh()
