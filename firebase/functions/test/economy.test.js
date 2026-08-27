"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const eco = require("../src/economy");
const config = require("../../remote_config/defaults.json");

test("generatorCost suit coût_base × croissance^n", () => {
  assert.equal(eco.generatorCost(10, 1.15, 0), 10);
  assert.ok(Math.abs(eco.generatorCost(10, 1.15, 2) - 13.225) < 1e-9);
});

test("bulkCost == somme des coûts unitaires", () => {
  let sum = 0;
  for (let i = 3; i < 8; i++) sum += eco.generatorCost(100, 1.16, i);
  assert.ok(Math.abs(eco.bulkCost(100, 1.16, 3, 5) - sum) < 1e-6);
});

test("offlineGains respecte le cap et le facteur", () => {
  assert.equal(eco.offlineGains(10, 100000, 0.5, 28800), 10 * 28800 * 0.5);
  assert.equal(eco.offlineGains(10, -5, 0.5, 28800), 0);
});

test("prestige : sqrt(total/seuil) arrondi à l'entier inférieur", () => {
  assert.equal(eco.prestigeCurrency(999999, 1e6), 0);
  assert.equal(eco.prestigeCurrency(1e6, 1e6), 1);
  assert.equal(eco.prestigeCurrency(4e6, 1e6), 2);
  assert.equal(eco.prestigeMultiplier(5, 0.02), 1.1);
});

test("globalMultiplier combine prestige, VIP et boosts actifs", () => {
  const now = 1_000_000;
  const m = eco.globalMultiplier(
    { prestigeMultiplier: 1.1 },
    { vipActive: true, vipExpiresAt: now + 1 },
    [{ mult: 2, expiresAt: now + 1 }, { mult: 3, expiresAt: now - 1 }],
    { vip_production_bonus: 0.5 },
    now
  );
  assert.ok(Math.abs(m - 1.1 * 1.5 * 2) < 1e-9);
});

// Simulation grossière "joueur actif glouton" : achète toujours le générateur au
// meilleur ratio prod/coût. Sert de garde-fou sur la cible GDD (prestige en 15-20 min).
test("tuning : premier prestige atteignable en moins de 25 min de jeu actif (garde-fou, cible GDD 15-20)", () => {
  const defs = config.generators;
  const levels = {};
  let gold = 0, total = 0, t = 0;
  const dt = 1;
  while (total < config.prestige_threshold && t < 3600) {
    let best = null, bestRatio = 0;
    for (const d of defs) {
      if (total < d.unlock_at) continue;
      const cost = eco.generatorCost(d.base_cost, d.growth, levels[d.id] || 0);
      const ratio = d.base_production / cost;
      if (cost <= gold && ratio > bestRatio) { best = d; bestRatio = ratio; }
    }
    if (best) {
      gold -= eco.generatorCost(best.base_cost, best.growth, levels[best.id] || 0);
      levels[best.id] = (levels[best.id] || 0) + 1;
      continue; // peut acheter plusieurs fois par seconde
    }
    const pps = eco.productionPerSec(levels, defs, 1);
    if (pps === 0) { gold += 1; total += 1; } // "tap" manuel de départ : 1 or/s
    gold += pps * dt; total += pps * dt; t += dt;
  }
  console.log(`  → premier prestige à ${Math.round(t / 60)} min (niveaux: ${JSON.stringify(levels)})`);
  assert.ok(t < 25 * 60, `premier prestige trop tardif : ${t}s`);
});
