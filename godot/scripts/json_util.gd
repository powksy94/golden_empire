class_name JsonUtil
extends RefCounted
## Conversions défensives pour du JSON externe (Remote Config, snapshot serveur,
## manifest de sprites). `Dictionary.get(key, default)` ne protège PAS contre
## une valeur explicitement `null` (seulement une clé absente) : ces helpers
## traitent null ET type inattendu comme "utiliser le défaut", sans exploser.


static func num(d: Dictionary, key: String, default: float) -> float:
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
			push_warning("JsonUtil: valeur inattendue pour '%s' (%s), défaut utilisé" % [key, v])
			return default


static func text(d: Dictionary, key: String, default: String) -> String:
	if not d.has(key) or d[key] == null:
		return default
	return str(d[key])


static func integer(d: Dictionary, key: String, default: int) -> int:
	return int(num(d, key, float(default)))


## [x, y] JSON -> Vector2, sinon défaut.
static func vec2(v, default: Vector2) -> Vector2:
	if v is Array and v.size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return default
