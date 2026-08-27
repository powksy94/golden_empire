extends Node
## Autoload "Economy" — logique de jeu runtime : tick de production, achats,
## prestige, boosts. Utilise EconomyFormulas (pures) + Config + GameState.

signal production_changed(pps: float)
signal prestiged(prestige_currency: float, multiplier: float)
signal boosts_changed
signal tapped(amount: float)

var production_per_sec: float = 0.0


func _ready() -> void:
	Config.config_updated.connect(recompute)
	GameState.state_loaded.connect(recompute)
	GameState.generator_changed.connect(func(_id, _lvl): recompute())
	GameState.profile_changed.connect(recompute)


func _process(delta: float) -> void:
	if not GameState.is_ready():
		return
	_expire_boosts()
	if production_per_sec > 0.0:
		GameState.add_gold(production_per_sec * delta)


# ------------------------------------------------------------------ multiplicateur

## Levier commun à TOUS les boosts (règle 3.2) : prestige × VIP × boosts temporaires.
func global_multiplier() -> float:
	var m: float = float(GameState.data.economy["prestigeMultiplier"])
	if _is_vip_active():
		m *= 1.0 + Config.get_float("vip_production_bonus", 0.0)
	for b in GameState.data.boosts:
		m *= float(b.get("mult", 1.0))
	return m


func _is_vip_active() -> bool:
	var p := GameState.data.profile
	return bool(p.get("vipActive", false)) and int(p.get("vipExpiresAt", 0)) > GameState.now_ms()


func recompute() -> void:
	production_per_sec = EconomyFormulas.production_per_sec(
		GameState.data.levels(), Config.get_generators(), global_multiplier())
	production_changed.emit(production_per_sec)


# ------------------------------------------------------------------ générateurs

func is_unlocked(id: String) -> bool:
	var def := Config.get_generator(id)
	if def == null:
		return false
	return float(GameState.data.economy["totalGoldEarned"]) >= def.unlock_at


func cost_of(id: String, count: int = 1) -> float:
	var def := Config.get_generator(id)
	if def == null:
		return INF
	return EconomyFormulas.bulk_cost(def.base_cost, def.growth, GameState.data.level_of(id), count)


func max_affordable(id: String) -> int:
	var def := Config.get_generator(id)
	if def == null:
		return 0
	return EconomyFormulas.max_affordable(
		def.base_cost, def.growth, GameState.data.level_of(id), float(GameState.data.economy["gold"]))


func can_buy(id: String, count: int = 1) -> bool:
	return is_unlocked(id) and float(GameState.data.economy["gold"]) >= cost_of(id, count)


func buy(id: String, count: int = 1) -> bool:
	if not can_buy(id, count):
		return false
	if not GameState.spend_gold(cost_of(id, count)):
		return false
	GameState.set_generator_level(id, GameState.data.level_of(id) + count)
	return true


# ------------------------------------------------------------------ tap-to-earn

## Montant d'or gagné par un tap manuel (bouton "Frapper une pièce").
## Passe par le multiplicateur global, comme la production passive : le
## prestige rend aussi le tap plus rentable, cohérent avec la règle 3.2.
func tap_gold_amount() -> float:
	return Config.get_float("tap_gold_amount", 1.0) * global_multiplier()


## Effectue un tap : crédite l'or et renvoie le montant gagné (pour l'UI/feedback).
func tap() -> float:
	var amount := tap_gold_amount()
	GameState.add_gold(amount)
	tapped.emit(amount)
	return amount


# ------------------------------------------------------------------ prestige

## Monnaie de prestige qui serait possédée après un prestige maintenant.
func prestige_currency_if_now() -> float:
	return EconomyFormulas.prestige_currency(
		float(GameState.data.economy["totalGoldEarned"]), Config.get_float("prestige_threshold", 1e6))


## Gain net du prestige (différence avec ce que le joueur possède déjà).
func pending_prestige() -> float:
	return prestige_currency_if_now() - float(GameState.data.economy["prestigeCurrency"])


func can_prestige() -> bool:
	return pending_prestige() >= 1.0


func do_prestige() -> bool:
	if not can_prestige():
		return false
	var new_currency := prestige_currency_if_now()
	var new_mult := EconomyFormulas.prestige_multiplier(new_currency, Config.get_float("prestige_mult_per_point", 0.02))
	GameState.reset_for_prestige(new_currency, new_mult)
	prestiged.emit(new_currency, new_mult)
	SaveManager.request_save(true)
	return true


# ------------------------------------------------------------------ boosts / boosters (gemmes)

func add_temporary_boost(mult: float, seconds: float, source: String = "") -> void:
	GameState.data.boosts.append({
		"mult": mult,
		"expiresAt": GameState.now_ms() + int(seconds * 1000.0),
		"source": source,
	})
	GameState.dirty = true
	boosts_changed.emit()
	recompute()


## Achat d'un booster en gemmes (catalogue Remote Config "boosters").
func buy_booster(booster_id: String) -> bool:
	var b := Config.get_booster(booster_id)
	if b.is_empty():
		return false
	if not GameState.spend_gems(int(b.get("gem_cost", 0))):
		return false
	if b.has("mult"):
		add_temporary_boost(float(b["mult"]), float(b.get("seconds", 0)), booster_id)
	# TODO: "offline_mult" -> stocker dans profile pour que onAppOpen l'applique côté serveur.
	return true


func _expire_boosts() -> void:
	var now := GameState.now_ms()
	var before := GameState.data.boosts.size()
	GameState.data.boosts = GameState.data.boosts.filter(func(b): return int(b.get("expiresAt", 0)) > now)
	if GameState.data.boosts.size() != before:
		boosts_changed.emit()
		recompute()
