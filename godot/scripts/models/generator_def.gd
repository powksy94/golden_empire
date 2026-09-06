class_name GeneratorDef
extends RefCounted
## Définition statique d'un générateur, issue de Remote Config (jamais en dur dans le code).
## Parsing défensif via JsonUtil (clé absente, null ou type inattendu -> défaut).

var id: String
var tier: int
var name: String        # nom affiché (FR pour l'instant — la vraie i18n est hors scope, cf. GDD §7)
var name_key: String     # clé de traduction pour une future localisation
var base_cost: float
var growth: float
var base_production: float
var unlock_at: float


static func from_dict(d: Dictionary) -> GeneratorDef:
	var g := GeneratorDef.new()
	g.id = JsonUtil.text(d, "id", "")
	g.tier = JsonUtil.integer(d, "tier", 0)
	g.name_key = JsonUtil.text(d, "name_key", g.id)
	g.name = JsonUtil.text(d, "name", g.name_key)
	g.base_cost = JsonUtil.num(d, "base_cost", 0.0)
	g.growth = JsonUtil.num(d, "growth", 1.15)
	g.base_production = JsonUtil.num(d, "base_production", 0.0)
	g.unlock_at = JsonUtil.num(d, "unlock_at", 0.0)
	return g
