"use strict";
/**
 * Formules économiques PURES — miroir exact de godot/scripts/economy_formulas.gd.
 * ⚠ Toute modification doit être répercutée côté GDScript, et inversement.
 * Référence : GDD section 3.
 */

/** 3.1 — coût(n) = coût_base × taux_croissance^n */
function generatorCost(baseCost, growth, level) {
  return baseCost * Math.pow(growth, level);
}

/** Coût cumulé de `count` niveaux à partir de `level` (somme géométrique). */
function bulkCost(baseCost, growth, level, count) {
  if (count <= 0) return 0;
  if (Math.abs(growth - 1) < 1e-9) return baseCost * count;
  return (baseCost * Math.pow(growth, level) * (Math.pow(growth, count) - 1)) / (growth - 1);
}

/** 3.2 — production/sec = Σ(niveau_i × prod_base_i) × multiplicateur_global */
function productionPerSec(levels, generatorDefs, globalMultiplier) {
  let total = 0;
  for (const def of generatorDefs) {
    total += (levels[def.id] || 0) * def.base_production;
  }
  return total * globalMultiplier;
}

/** 3.3 — gains_offline = pps × min(temps_absent, cap) × facteur_offline (AUTORITÉ SERVEUR) */
function offlineGains(pps, secondsAway, offlineFactor, capSeconds) {
  const t = Math.min(Math.max(secondsAway, 0), capSeconds);
  return pps * t * offlineFactor;
}

/** 3.4 — monnaie_prestige = floor(√(or_total_gagné / seuil)) */
function prestigeCurrency(totalGoldEarned, threshold) {
  if (threshold <= 0 || totalGoldEarned <= 0) return 0;
  return Math.floor(Math.sqrt(totalGoldEarned / threshold));
}

/** 3.4 — multiplicateur_permanent = 1 + monnaie_prestige × per_point */
function prestigeMultiplier(prestigeCurrencyValue, perPoint) {
  return 1 + prestigeCurrencyValue * perPoint;
}

/**
 * Multiplicateur global (règle 3.2) : prestige × VIP × boosts temporaires actifs.
 * Doit rester aligné avec Economy.global_multiplier() côté Godot.
 */
function globalMultiplier(economy, profile, boosts, config, nowMs) {
  let m = economy.prestigeMultiplier || 1;
  if (profile.vipActive && (profile.vipExpiresAt || 0) > nowMs) {
    m *= 1 + (config.vip_production_bonus || 0);
  }
  for (const b of boosts || []) {
    if ((b.expiresAt || 0) > nowMs) m *= b.mult || 1;
  }
  return m;
}

module.exports = {
  generatorCost,
  bulkCost,
  productionPerSec,
  offlineGains,
  prestigeCurrency,
  prestigeMultiplier,
  globalMultiplier,
};
