class_name EmpireTheme
extends RefCounted
## Système de design "Empire d'Or" — identité de registre de guilde marchande :
## encre profonde, or vieilli, filets fins au lieu de cartes à coins arrondis.
## Palette et typo décrites dans README.md § UI. Construit un seul Theme
## réutilisé par toute l'interface (aucune couleur/police en dur ailleurs).

# ---------------------------------------------------------------- palette
const BG := Color("151009")            # fond — encre presque noire
const PANEL := Color("1f1712")         # panneaux, en-tête
const PANEL_ALT := Color("241b14")     # alternance de lignes du registre
const GOLD := Color("e8b93a")          # or vieilli — montants, accent principal
const GOLD_DIM := Color("8a6f2c")      # or atténué — filets, bordures
const COPPER := Color("c97b3d")        # cuivre — prestige, rareté
const SAGE := Color("5b7b6b")          # vert sauge éteint — succès discret
const PARCHMENT := Color("8a7a63")     # beige-parchemin — texte secondaire
const TEXT := Color("ede3d0")          # texte principal, chaud sur fond sombre
const LOCKED := Color("4a4038")        # texte/éléments verrouillés

# ---------------------------------------------------------------- polices
const FONT_DISPLAY_PATH := "res://assets/fonts/Cinzel-Bold.ttf"     # titres, montants
const FONT_BODY_PATH := "res://assets/fonts/SpectralRegular.ttf"    # texte courant
const FONT_BODY_SEMIBOLD_PATH := "res://assets/fonts/SpectralSemiBold.ttf"  # boutons, noms

# Variations de type "theme_type" utilisées dans l'UI :
#   "Title"     — grand nombre / titre d'écran (Cinzel)
#   "Section"   — sous-titre de section (Cinzel, plus petit)
#   "RowName"   — nom de générateur (Spectral SemiBold)
#   "RowMeta"   — sous-texte de ligne (Spectral, atténué)
#   par défaut  — corps de texte (Spectral)


static func build() -> Theme:
	var theme := Theme.new()

	var display_base: FontFile = load(FONT_DISPLAY_PATH)
	var body: FontFile = load(FONT_BODY_PATH)
	var body_semibold: FontFile = load(FONT_BODY_SEMIBOLD_PATH)

	var display_title := FontVariation.new()
	display_title.base_font = display_base
	display_title.set_variation_opentype({"wght": 700})
	display_title.spacing_glyph = 3   # léger espacement des capitales, façon sceau gravé

	var display_section := FontVariation.new()
	display_section.base_font = display_base
	display_section.set_variation_opentype({"wght": 600})
	display_section.spacing_glyph = 2

	theme.default_font = body
	theme.default_font_size = 30

	theme.set_font("font", "Title", display_title)
	theme.set_font_size("font_size", "Title", 68)
	theme.set_color("font_color", "Title", GOLD)

	theme.set_font("font", "Section", display_section)
	theme.set_font_size("font_size", "Section", 30)
	theme.set_color("font_color", "Section", COPPER)

	theme.set_font("font", "RowName", body_semibold)
	theme.set_font_size("font_size", "RowName", 32)
	theme.set_color("font_color", "RowName", TEXT)

	theme.set_font("font", "RowMeta", body)
	theme.set_font_size("font_size", "RowMeta", 24)
	theme.set_color("font_color", "RowMeta", PARCHMENT)

	theme.set_color("font_color", "Label", TEXT)

	_style_buttons(theme, body_semibold)
	_style_panels(theme)
	_style_scroll(theme)

	return theme


static func _flat(bg: Color, border_bottom: int = 0, border_color: Color = GOLD_DIM) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.border_width_bottom = border_bottom
	sb.border_color = border_color
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


static func _style_buttons(theme: Theme, font: FontFile) -> void:
	theme.set_font("font", "Button", font)
	theme.set_font_size("font_size", "Button", 28)

	var normal := _flat(Color("2a2015"), 2, GOLD_DIM)
	var hover := _flat(Color("332612"), 2, GOLD)
	var pressed := _flat(Color("1a140c"), 2, GOLD)
	var disabled := _flat(Color("1c1712"), 1, Color("3a332a"))

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_color", "Button", GOLD)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", LOCKED)

	# Bouton principal (prestige) — cuivre, plus affirmé.
	var primary_normal := _flat(Color("3a2410"), 3, COPPER)
	var primary_hover := _flat(Color("482c12"), 3, Color("e0985a"))
	var primary_disabled := _flat(Color("241a10"), 1, Color("4a3a28"))
	theme.set_stylebox("normal", "PrimaryButton", primary_normal)
	theme.set_stylebox("hover", "PrimaryButton", primary_hover)
	theme.set_stylebox("pressed", "PrimaryButton", primary_normal)
	theme.set_stylebox("disabled", "PrimaryButton", primary_disabled)
	theme.set_font("font", "PrimaryButton", font)
	theme.set_font_size("font_size", "PrimaryButton", 30)
	theme.set_color("font_color", "PrimaryButton", COPPER)
	theme.set_color("font_hover_color", "PrimaryButton", Color("f0a868"))
	theme.set_color("font_disabled_color", "PrimaryButton", LOCKED)

	# Bouton d'action fréquente (tap) — or, distinct du cuivre réservé au prestige.
	var tap_normal := _flat(Color("332612"), 3, GOLD)
	var tap_hover := _flat(Color("40300f"), 3, Color("f5cc55"))
	var tap_pressed := _flat(Color("241a0c"), 3, GOLD)
	theme.set_stylebox("normal", "TapButton", tap_normal)
	theme.set_stylebox("hover", "TapButton", tap_hover)
	theme.set_stylebox("pressed", "TapButton", tap_pressed)
	theme.set_font("font", "TapButton", font)
	theme.set_font_size("font_size", "TapButton", 32)
	theme.set_color("font_color", "TapButton", GOLD)
	theme.set_color("font_hover_color", "TapButton", Color("f5cc55"))
	theme.set_color("font_pressed_color", "TapButton", Color.WHITE)

	# Bouton discret (debug, sauvegarde) — presque invisible, texte parchemin.
	var quiet_normal := _flat(Color.TRANSPARENT, 1, Color("3a332a"))
	var quiet_hover := _flat(Color("1c1712"), 1, PARCHMENT)
	theme.set_stylebox("normal", "QuietButton", quiet_normal)
	theme.set_stylebox("hover", "QuietButton", quiet_hover)
	theme.set_stylebox("pressed", "QuietButton", quiet_hover)
	theme.set_font("font", "QuietButton", font)
	theme.set_font_size("font_size", "QuietButton", 20)
	theme.set_color("font_color", "QuietButton", PARCHMENT)
	theme.set_color("font_hover_color", "QuietButton", TEXT)


static func _style_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", _flat(PANEL))

	var header := _flat(PANEL)
	header.border_width_bottom = 2
	header.border_color = GOLD_DIM
	header.content_margin_top = 28
	header.content_margin_bottom = 20
	theme.set_stylebox("panel", "HeaderPanel", header)

	theme.set_stylebox("panel", "RowPanel", _flat(PANEL, 1, Color("332a1c")))
	theme.set_stylebox("panel", "RowPanelAlt", _flat(PANEL_ALT, 1, Color("332a1c")))
	theme.set_stylebox("panel", "RowPanelLocked", _flat(Color("18120c"), 1, Color("2a241c")))


static func _style_scroll(theme: Theme) -> void:
	var empty := StyleBoxEmpty.new()
	theme.set_stylebox("panel", "ScrollContainer", empty)
