extends Node
## Autoload "Config" — source unique de vérité pour toute la balance économique.
## Chargement : valeurs par défaut locales (res://config/remote_config_defaults.json)
## puis écrasement par les valeurs Remote Config renvoyées par le serveur (onAppOpen).
## AUCUNE valeur de balance ne doit être écrite en dur ailleurs dans le code.

signal config_updated

const DEFAULTS_PATH := "res://config/remote_config_defaults.json"

var _values: Dictionary = {}
var _generator_defs: Array[GeneratorDef] = []
var _generator_index: Dictionary = {}   # id -> GeneratorDef


func _ready() -> void:
	_load_defaults()


func _load_defaults() -> void:
	var file := FileAccess.open(DEFAULTS_PATH, FileAccess.READ)
	if file == null:
		push_error("Config: impossible de lire %s" % DEFAULTS_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		apply(parsed)
	else:
		push_error("Config: JSON invalide dans %s" % DEFAULTS_PATH)


## Applique un dictionnaire de valeurs (partiel ou complet) par-dessus l'existant.
func apply(remote: Dictionary) -> void:
	for key in remote:
		_values[key] = remote[key]
	_rebuild_generators()
	config_updated.emit()


func _rebuild_generators() -> void:
	_generator_defs.clear()
	_generator_index.clear()
	var raw_list = _values.get("generators", [])
	if not (raw_list is Array):
		push_error("Config: 'generators' devrait être un tableau JSON, reçu %s" % typeof(raw_list))
		return
	for raw in raw_list:
		if not (raw is Dictionary):
			push_warning("Config: entrée de générateur ignorée (pas un objet JSON valide) : %s" % str(raw))
			continue
		var def := GeneratorDef.from_dict(raw)
		if def == null:
			push_warning("Config: GeneratorDef.from_dict a échoué pour : %s" % JSON.stringify(raw))
			continue
		_generator_defs.append(def)
		_generator_index[def.id] = def
	_generator_defs.sort_custom(func(a, b): return a.tier < b.tier)


func get_value(key: String, default = null):
	return _values.get(key, default)


func get_float(key: String, default: float = 0.0) -> float:
	return float(_values.get(key, default))


func get_int(key: String, default: int = 0) -> int:
	return int(_values.get(key, default))


func get_generators() -> Array[GeneratorDef]:
	return _generator_defs


func get_generator(id: String) -> GeneratorDef:
	return _generator_index.get(id)


func get_product(product_id: String) -> Dictionary:
	return _values.get("products", {}).get(product_id, {})


func get_booster(booster_id: String) -> Dictionary:
	return _values.get("boosters", {}).get(booster_id, {})
