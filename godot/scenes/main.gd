extends Control
## Scène racine : séquence de démarrage uniquement. La composition de l'UI est
## déléguée à GameScreen (scripts/ui/game_screen.gd) — voir README § UI.
##
## Séquence de boot :
##   1. charge la sauvegarde locale (jouable immédiatement, même hors-ligne)
##   2. auth anonyme Firebase
##   3. appel Cloud Function `onAppOpen` -> Remote Config + snapshot serveur + gains offline
##   4. si 2/3 échouent : mode hors-ligne, resync au prochain lancement

var _screen: GameScreen


func _ready() -> void:
	theme = EmpireTheme.build()
	_screen = GameScreen.create()
	add_child(_screen)
	await _boot()


func _boot() -> void:
	_screen.set_status("Chargement local…")
	var had_local := SaveManager.load_local()
	if not had_local:
		GameState.data.profile["createdAt"] = GameState.now_ms()
		GameState.data.profile["deviceId"] = OS.get_unique_id()
	GameState.load_from_dict({}, true)   # marque l'état prêt -> la production démarre

	if not FirebaseClient.is_configured():
		_screen.set_status("Mode hors-ligne (Firebase non configuré)")
		return

	_screen.set_status("Connexion…")
	if not await FirebaseClient.sign_in_anonymously():
		_screen.set_status("Hors-ligne — resync au prochain lancement")
		return

	_screen.set_status("Synchronisation…")
	var res := await FirebaseClient.call_function("onAppOpen", {
		"clientTime": GameState.now_ms(),
		"deviceId": GameState.data.profile.get("deviceId", ""),
		"configVersion": Config.get_int("config_version", 0),
	})
	if not res.ok:
		_screen.set_status("Serveur injoignable — jeu en local")
		return

	var d: Dictionary = res.data
	if d.has("config"):
		Config.apply(d["config"])
	if d.has("state"):
		GameState.apply_server_snapshot(d["state"])
	var gains := float(d.get("offlineGains", 0.0))
	var away := int(d.get("secondsAway", 0))
	if gains > 0.0:
		_screen.set_status("Bon retour ! +%s or pendant %s" % [NumberFormat.short(gains), NumberFormat.duration(away)])
	else:
		_screen.set_status("Connecté — uid %s" % FirebaseClient.uid.left(6))
