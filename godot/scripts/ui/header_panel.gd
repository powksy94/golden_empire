class_name HeaderPanel
extends PanelContainer
## En-tête du registre : titre, statut de connexion/boot, or, gemmes, prod/s.

var _status: Label
var _gold: Label
var _gems: Label
var _pps: Label


static func create() -> HeaderPanel:
	var h := HeaderPanel.new()
	h._build()
	return h


func _build() -> void:
	theme_type_variation = "HeaderPanel"

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = "EMPIRE D'OR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_status = Label.new()
	_status.theme_type_variation = "RowMeta"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = "…"
	col.add_child(_status)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 36)
	col.add_child(stats)

	_gold = _stat_label(stats, "0", EmpireTheme.GOLD)
	_gems = _stat_label(stats, "0 gemmes", EmpireTheme.COPPER)

	_pps = Label.new()
	_pps.theme_type_variation = "RowMeta"
	_pps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_pps)


func _stat_label(parent: Node, text: String, color: Color) -> Label:
	var l := Label.new()
	l.theme_type_variation = "Section"
	l.add_theme_color_override("font_color", color)
	l.text = text
	parent.add_child(l)
	return l


func set_status(text: String) -> void:
	_status.text = text
	print("[Main] ", text)


func refresh() -> void:
	var e := GameState.data.economy
	_gold.text = "%s or" % NumberFormat.short(float(e["gold"]))
	_gems.text = "%d gemmes" % int(e["gems"])
	_pps.text = "%s or/s — multiplicateur x%.2f" % [NumberFormat.short(Economy.production_per_sec), Economy.global_multiplier()]
