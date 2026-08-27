class_name PlayerData
extends RefCounted
## Miroir local du document Firestore `users/{userId}`.
## Convention : tous les timestamps sont des entiers en millisecondes epoch UTC
## (même convention côté Cloud Functions), jamais des dates locales.

var profile: Dictionary = {
	"createdAt": 0,
	"lastSeenAt": 0,
	"deviceId": "",
	"streakCount": 0,
	"lastStreakClaimAt": 0,
	"vipActive": false,
	"vipExpiresAt": 0,
	"adsRemoved": false,
	"noAdsUntil": 0,
	"offlineCapSeconds": 0,   # 0 = valeur par défaut Remote Config
}

var economy: Dictionary = {
	"gold": 0.0,
	"gems": 0,
	"totalGoldEarned": 0.0,   # JAMAIS décrémenté (règle 6.3.5)
	"prestigeCurrency": 0.0,
	"prestigeMultiplier": 1.0,
	"lastActiveTimestamp": 0,
}

## generatorId -> { "level": int, "unlockedAt": int }
var generators: Dictionary = {}

## Boosts temporaires actifs : [{ "mult": float, "expiresAt": int }]
var boosts: Array = []

var settings: Dictionary = {
	"notificationsEnabled": false,
	"fcmToken": "",
}


func to_dict() -> Dictionary:
	return {
		"profile": profile.duplicate(true),
		"economy": economy.duplicate(true),
		"generators": generators.duplicate(true),
		"boosts": boosts.duplicate(true),
		"settings": settings.duplicate(true),
	}


static func from_dict(d: Dictionary) -> PlayerData:
	var p := PlayerData.new()
	p.merge(d)
	return p


## Fusionne un snapshot (partiel ou complet) dans les données courantes.
func merge(d: Dictionary) -> void:
	if d.has("profile"):
		profile.merge(d["profile"], true)
	if d.has("economy"):
		economy.merge(d["economy"], true)
	if d.has("generators"):
		generators = d["generators"].duplicate(true)
	if d.has("boosts"):
		boosts = d["boosts"].duplicate(true)
	if d.has("settings"):
		settings.merge(d["settings"], true)


func level_of(generator_id: String) -> int:
	return int(generators.get(generator_id, {}).get("level", 0))


func levels() -> Dictionary:
	var out := {}
	for id in generators:
		out[id] = int(generators[id].get("level", 0))
	return out
