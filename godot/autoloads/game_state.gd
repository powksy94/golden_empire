extends Node
## Autoload "GameState" — détient l'état joueur (PlayerData) et notifie les changements.
## C'est le SEUL endroit qui mute `data` ; Economy et SaveManager passent par ici.

signal state_loaded
signal gold_changed(gold: float)
signal gems_changed(gems: int)
signal generator_changed(id: String, level: int)
signal profile_changed

var data: PlayerData = PlayerData.new()
var dirty: bool = false          # true si des changements locaux attendent une sauvegarde
var _ready_flag: bool = false


func is_ready() -> bool:
	return _ready_flag


func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


## Charge un état complet (depuis le disque ou le serveur).
func load_from_dict(d: Dictionary, mark_ready: bool = true) -> void:
	data.merge(d)
	if mark_ready:
		_ready_flag = true
	state_loaded.emit()
	gold_changed.emit(data.economy["gold"])
	gems_changed.emit(int(data.economy["gems"]))


## Applique le snapshot serveur renvoyé par onAppOpen (le serveur fait autorité).
func apply_server_snapshot(snapshot: Dictionary) -> void:
	load_from_dict(snapshot, true)
	dirty = false


func add_gold(amount: float) -> void:
	if amount <= 0.0:
		return
	data.economy["gold"] += amount
	data.economy["totalGoldEarned"] += amount   # cumulatif à vie, jamais décrémenté
	dirty = true
	gold_changed.emit(data.economy["gold"])


func spend_gold(amount: float) -> bool:
	if amount > data.economy["gold"]:
		return false
	data.economy["gold"] -= amount
	dirty = true
	gold_changed.emit(data.economy["gold"])
	return true


## Les gemmes ne sont JAMAIS créditées côté client : seul le serveur (validatePurchase)
## les augmente. Le client peut uniquement les dépenser (boosters).
func spend_gems(amount: int) -> bool:
	if amount > int(data.economy["gems"]):
		return false
	data.economy["gems"] = int(data.economy["gems"]) - amount
	dirty = true
	gems_changed.emit(int(data.economy["gems"]))
	return true


func set_generator_level(id: String, level: int) -> void:
	if not data.generators.has(id):
		data.generators[id] = {"level": 0, "unlockedAt": now_ms()}
	data.generators[id]["level"] = level
	dirty = true
	generator_changed.emit(id, level)


func reset_for_prestige(new_prestige_currency: float, new_multiplier: float) -> void:
	data.economy["gold"] = 0.0
	data.economy["prestigeCurrency"] = new_prestige_currency
	data.economy["prestigeMultiplier"] = new_multiplier
	data.generators.clear()
	dirty = true
	gold_changed.emit(0.0)
	state_loaded.emit()


func touch_last_active() -> void:
	data.economy["lastActiveTimestamp"] = now_ms()
	data.profile["lastSeenAt"] = data.economy["lastActiveTimestamp"]
	dirty = true
