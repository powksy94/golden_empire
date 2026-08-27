extends Node
## Autoload "SaveManager" — persistance locale (user://save.json) + synchronisation
## Firestore. Règle 6.3.4 : le jeu reste jouable hors connexion ; le cloud est
## une réplique, le local une sauvegarde de secours.
##
## Stratégie :
##  - sauvegarde locale toutes les LOCAL_INTERVAL s si dirty, et à la mise en pause
##  - push Firestore toutes les CLOUD_INTERVAL s si dirty et connecté
##  - à l'ouverture, le serveur (onAppOpen) fait autorité sur economy + generators

const SAVE_PATH := "user://save.json"
const LOCAL_INTERVAL := 5.0
const CLOUD_INTERVAL := 30.0

var _local_timer := 0.0
var _cloud_timer := 0.0
var _cloud_push_in_flight := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not GameState.is_ready():
		return
	_local_timer += delta
	_cloud_timer += delta
	if _local_timer >= LOCAL_INTERVAL:
		_local_timer = 0.0
		if GameState.dirty:
			save_local()
	if _cloud_timer >= CLOUD_INTERVAL:
		_cloud_timer = 0.0
		push_to_cloud()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if GameState.is_ready():
				request_save(true)


## Force une sauvegarde (locale + cloud si possible).
func request_save(immediate_cloud: bool = false) -> void:
	GameState.touch_last_active()
	save_local()
	if immediate_cloud:
		push_to_cloud()


# ------------------------------------------------------------------ local

func save_local() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: écriture impossible " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(GameState.data.to_dict()))
	GameState.dirty = false


## Retourne true si une sauvegarde locale existait.
func load_local() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		GameState.load_from_dict(d, false)
		return true
	return false


# ------------------------------------------------------------------ cloud

## Pousse economy/profile/settings/generators vers Firestore en un seul commit.
## Les champs protégés (gems, purchases) ne sont jamais écrits par le client ;
## totalGoldEarned est vérifié monotone par les Security Rules.
func push_to_cloud() -> void:
	if _cloud_push_in_flight or not FirebaseClient.is_signed_in():
		return
	_cloud_push_in_flight = true
	GameState.touch_last_active()
	var data := GameState.data
	var user_path := FirebaseClient.user_doc_path()

	var writes := [{
		"path": user_path,
		"fields": {
			"economy": {
				"gold": float(data.economy["gold"]),
				"totalGoldEarned": float(data.economy["totalGoldEarned"]),
				"prestigeCurrency": float(data.economy["prestigeCurrency"]),
				"prestigeMultiplier": float(data.economy["prestigeMultiplier"]),
				"lastActiveTimestamp": int(data.economy["lastActiveTimestamp"]),
			},
			"profile": {"lastSeenAt": int(data.profile["lastSeenAt"])},
			"settings": data.settings,
			"boosts": data.boosts,
		},
		"mask": [
			"economy.gold", "economy.totalGoldEarned", "economy.prestigeCurrency",
			"economy.prestigeMultiplier", "economy.lastActiveTimestamp",
			"profile.lastSeenAt", "settings", "boosts",
		],
	}]
	for gen_id in data.generators:
		writes.append({
			"path": "%s/generators/%s" % [user_path, gen_id],
			"fields": {
				"level": int(data.generators[gen_id].get("level", 0)),
				"unlockedAt": int(data.generators[gen_id].get("unlockedAt", 0)),
			},
		})

	var res := await FirebaseClient.firestore_commit(writes)
	_cloud_push_in_flight = false
	if not res.ok:
		push_warning("SaveManager: sync cloud échouée (%s) — réessai au prochain tick" % res.error)
