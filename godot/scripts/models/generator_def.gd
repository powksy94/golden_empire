class_name GeneratorDef
extends RefCounted
## Définition statique d'un générateur, issue de Remote Config (jamais en dur dans le code).

var id: String
var tier: int
var name: String        # nom affiché (FR pour l'instant — la vraie i18n est hors scope, cf. GDD §7)
var name_key: String     # clé de traduction pour une future localisation
var base_cost: float
var growth: float
var base_production: float
var unlock_at: float


## Conversion défensive en float : traite les clés absentes ET les valeurs null
## comme "utiliser le défaut" (Dictionary.get() ne le fait que pour les clés absentes),
## et n'explose jamais si la valeur est d'un type inattendu (string, bool, etc.).
static func _num(d: Dictionary, key: String, default: float) -> float:
	if not d.has(key) or d[key] == null:
		return default
	var v = d[key]
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			return float(v)
		TYPE_STRING:
			return float(v) if v.is_valid_float() else default
		TYPE_BOOL:
			return 1.0 if v else 0.0
		_:
			push_warning("GeneratorDef: valeur inattendue pour '%s' (%s), défaut utilisé" % [key, v])
			return default


static func _str(d: Dictionary, key: String, default: String) -> String:
	if not d.has(key) or d[key] == null:
		return default
	return str(d[key])


static func _int(d: Dictionary, key: String, default: int) -> int:
	return int(_num(d, key, float(default)))


static func from_dict(d: Dictionary) -> GeneratorDef:
	var g := GeneratorDef.new()
	g.id = _str(d, "id", "")
	g.tier = _int(d, "tier", 0)
	g.name_key = _str(d, "name_key", g.id)
	g.name = _str(d, "name", g.name_key)
	g.base_cost = _num(d, "base_cost", 0.0)
	g.growth = _num(d, "growth", 1.15)
	g.base_production = _num(d, "base_production", 0.0)
	g.unlock_at = _num(d, "unlock_at", 0.0)
	return g
