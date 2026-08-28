"use strict";
/**
 * Lecture de Remote Config côté serveur (Admin SDK) avec cache mémoire.
 * Les valeurs Remote Config sont des chaînes ; on les re-type en JSON quand possible,
 * pour obtenir la même forme que godot/config/remote_config_defaults.json.
 */
const admin = require("firebase-admin");
// Doit vivre sous functions/ (cf. build_template.js) : Cloud Functions ne
// déploie que ce dossier, un chemin qui en sort casse en production tout en
// fonctionnant en local (repo entier présent sur disque).
const localDefaults = require("../remote_config/defaults.json");

const CACHE_TTL_MS = 5 * 60 * 1000;
let cache = { loadedAt: 0, values: null };

function parseValue(raw) {
  if (typeof raw !== "string") return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return raw;
  }
}

async function loadConfig() {
  const now = Date.now();
  if (cache.values && now - cache.loadedAt < CACHE_TTL_MS) return cache.values;

  const values = { ...localDefaults };
  try {
    const template = await admin.remoteConfig().getTemplate();
    for (const [key, param] of Object.entries(template.parameters || {})) {
      if (param.defaultValue && "value" in param.defaultValue) {
        values[key] = parseValue(param.defaultValue.value);
      }
    }
  } catch (err) {
    console.warn("Remote Config indisponible, fallback sur defaults.json :", err.message);
  }
  cache = { loadedAt: now, values };
  return values;
}

module.exports = { loadConfig };
