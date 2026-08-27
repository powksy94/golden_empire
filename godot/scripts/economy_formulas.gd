class_name EconomyFormulas
extends RefCounted
## Formules économiques PURES (sans état). Référence : GDD section 3.
##
## ⚠ Ce fichier est le miroir exact de `firebase/functions/src/economy.js`.
##    Toute modification ici doit être répercutée côté serveur, et inversement.
##
## Précision : float Godot = double 64 bits (~1e308). Suffisant pour les 7 paliers
## initiaux ; un système "BigNumber" sera nécessaire si la progression dépasse ~1e300.


## 3.1 — coût(n) = coût_base × taux_croissance^n
static func generator_cost(base_cost: float, growth: float, level: int) -> float:
	return base_cost * pow(growth, level)


## Coût cumulé pour acheter `count` niveaux à partir de `level` (somme géométrique).
static func bulk_cost(base_cost: float, growth: float, level: int, count: int) -> float:
	if count <= 0:
		return 0.0
	if is_equal_approx(growth, 1.0):
		return base_cost * count
	return base_cost * pow(growth, level) * (pow(growth, count) - 1.0) / (growth - 1.0)


## Nombre maximal de niveaux achetables avec `gold` (inverse de bulk_cost).
static func max_affordable(base_cost: float, growth: float, level: int, gold: float) -> int:
	if gold <= 0.0 or base_cost <= 0.0:
		return 0
	if is_equal_approx(growth, 1.0):
		return int(floor(gold / base_cost))
	var first: float = base_cost * pow(growth, level)
	var n: float = floor(log(gold * (growth - 1.0) / first + 1.0) / log(growth))
	return maxi(0, int(n))


## 3.2 — production/sec = Σ(niveau_i × prod_base_i) × multiplicateur_global
static func production_per_sec(levels: Dictionary, defs: Array, global_multiplier: float) -> float:
	var total := 0.0
	for def in defs:
		total += float(levels.get(def.id, 0)) * def.base_production
	return total * global_multiplier


## 3.3 — gains_offline = production/sec × min(temps_absent, cap) × facteur_offline
## NOTE : côté client, cette fonction sert UNIQUEMENT à l'affichage/prévision.
## La valeur créditée est toujours celle calculée par la Cloud Function `onAppOpen`.
static func offline_gains(pps: float, seconds_away: float, offline_factor: float, cap_seconds: float) -> float:
	var t := clampf(seconds_away, 0.0, cap_seconds)
	return pps * t * offline_factor


## 3.4 — monnaie_prestige = floor(√(or_total_gagné / seuil_prestige))
## Valeur ABSOLUE dérivée de totalGoldEarned (qui ne baisse jamais) : le prestige
## fixe prestigeCurrency à cette valeur, et le "gain" d'un prestige est la différence.
static func prestige_currency(total_gold_earned: float, threshold: float) -> float:
	if threshold <= 0.0 or total_gold_earned <= 0.0:
		return 0.0
	return floor(sqrt(total_gold_earned / threshold))


## 3.4 — multiplicateur_permanent = 1 + monnaie_prestige × per_point (0.02 par défaut)
static func prestige_multiplier(prestige_currency_value: float, per_point: float) -> float:
	return 1.0 + prestige_currency_value * per_point
