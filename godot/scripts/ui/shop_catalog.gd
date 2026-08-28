class_name ShopCatalog
extends RefCounted
## Traduit les entrées du catalogue Remote Config (boosters, produits IAP) en
## texte d'affichage pour ShopScreen. Pur formatage — aucune construction de
## nœud ici (cf. ShopRow pour le widget, ShopScreen pour l'assemblage).

## true si le booster a un effet réellement appliqué (achat fonctionnel).
## Ex. "offline_mult" n'est pas encore appliqué côté serveur, cf. TODO dans
## Economy.buy_booster — affiché comme "bientôt disponible" tant que non branché.
static func booster_is_functional(b: Dictionary) -> bool:
	return b.has("mult")


static func booster_name(b: Dictionary) -> String:
	return "Boost production x%s" % NumberFormat.short(float(b.get("mult", 1.0)))


static func booster_meta(b: Dictionary) -> String:
	var duration := NumberFormat.duration(int(b.get("seconds", 0)))
	return "Pendant %s — %d gemmes" % [duration, int(b.get("gem_cost", 0))]


static func product_name(p: Dictionary) -> String:
	match str(p.get("type", "")):
		"gems":
			return "%d gemmes" % int(p.get("gems", 0))
		"remove_ads":
			return "Retirer les publicités"
		"vip":
			return "VIP — %d jours" % int(p.get("duration_days", 30))
		"bundle":
			return "Pack de démarrage"
		"offline_cap":
			return "Cap hors-ligne étendu"
		_:
			return "Produit"


static func product_meta(p: Dictionary) -> String:
	match str(p.get("type", "")):
		"gems":
			return "Pack de gemmes"
		"remove_ads":
			return "Achat unique"
		"vip":
			return "Bonus de production, cap hors-ligne étendu"
		"bundle":
			return "%d gemmes + boost + sans pub" % int(p.get("gems", 0))
		"offline_cap":
			return NumberFormat.duration(int(p.get("cap_seconds", 0)))
		_:
			return ""
