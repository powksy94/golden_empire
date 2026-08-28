#!/usr/bin/env node
"use strict";
/**
 * Génère remoteconfig.template.json (format Firebase CLI) à partir de la source
 * unique godot/config/remote_config_defaults.json, et copie cette dernière en
 * functions/remote_config/defaults.json pour le fallback des Cloud Functions.
 *
 * ⚠ Le fallback DOIT vivre sous functions/ : Cloud Functions ne déploie que le
 * contenu de ce dossier (cf. "source": "functions" dans firebase.json), donc un
 * require() qui en sort (ex. "../../remote_config/...") casse au déploiement
 * réel tout en fonctionnant en local/émulateur (repo entier présent sur disque).
 *
 * Usage : node remote_config/build_template.js && firebase deploy --only remoteconfig,functions
 */
const fs = require("fs");
const path = require("path");

const SRC = path.resolve(__dirname, "../../godot/config/remote_config_defaults.json");
const OUT_TEMPLATE = path.resolve(__dirname, "remoteconfig.template.json");
const OUT_DEFAULTS = path.resolve(__dirname, "../functions/remote_config/defaults.json");

const DESCRIPTIONS = {
  config_version: "Version de la balance (incrémenter à chaque changement)",
  generators: "Grille des générateurs (GDD 3.5) — tableau JSON",
  prestige_threshold: "Seuil de prestige (GDD 3.4)",
  prestige_mult_per_point: "Multiplicateur permanent par point de prestige",
  offline_factor_default: "Facteur offline par défaut (GDD 3.3)",
  offline_factor_vip: "Facteur offline VIP",
  offline_cap_seconds_default: "Cap offline par défaut (8h)",
  offline_cap_seconds_extended: "Cap offline après achat (24h)",
  offline_cap_seconds_vip: "Cap offline VIP",
  vip_production_bonus: "Bonus de production VIP (0.5 = +50%)",
  vip_daily_gems: "Gemmes quotidiennes VIP",
  starting_gems: "Gemmes offertes à la création du compte",
  products: "Catalogue produits IAP (GDD 4.2) — objet JSON",
  boosters: "Boosters achetables en gemmes — objet JSON",
};

const src = JSON.parse(fs.readFileSync(SRC, "utf8"));
const parameters = {};
for (const [key, value] of Object.entries(src)) {
  parameters[key] = {
    defaultValue: { value: typeof value === "string" ? value : JSON.stringify(value) },
    valueType: typeof value === "object" ? "JSON" : typeof value === "number" ? "NUMBER" : "STRING",
    description: DESCRIPTIONS[key] || "",
  };
}

const template = {
  conditions: [],
  parameters,
  parameterGroups: {},
  version: { description: `Balance v${src.config_version}` },
};

fs.writeFileSync(OUT_TEMPLATE, JSON.stringify(template, null, 2) + "\n");
fs.mkdirSync(path.dirname(OUT_DEFAULTS), { recursive: true });
fs.writeFileSync(OUT_DEFAULTS, JSON.stringify(src, null, 2) + "\n");
console.log(`✔ ${path.relative(process.cwd(), OUT_TEMPLATE)}`);
console.log(`✔ ${path.relative(process.cwd(), OUT_DEFAULTS)}`);
