"use strict";
/**
 * onAppOpen — appelée à chaque ouverture de l'app.
 * Règle 6.3.1 : le calcul des gains hors-ligne se fait ICI, jamais côté client
 * (l'horloge serveur fait foi, l'horloge client n'est qu'un signal anti-triche).
 *
 * Entrée  : { clientTime?: number, deviceId?: string, configVersion?: number }
 * Sortie  : { serverTime, secondsAway, offlineGains, state, config }
 *   - state  : snapshot autoritaire { profile, economy, generators, boosts, settings }
 *   - config : valeurs Remote Config typées (même forme que remote_config_defaults.json)
 */
const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { loadConfig } = require("./config");
const eco = require("./economy");

const db = admin.firestore;

function defaultUserDoc(nowMs, deviceId, config) {
  return {
    profile: {
      createdAt: nowMs,
      lastSeenAt: nowMs,
      deviceId: deviceId || "",
      streakCount: 0,
      lastStreakClaimAt: 0,
      vipActive: false,
      vipExpiresAt: 0,
      adsRemoved: false,
      noAdsUntil: 0,
      offlineCapSeconds: 0,
    },
    economy: {
      gold: 0,
      gems: config.starting_gems || 0,
      totalGoldEarned: 0,
      prestigeCurrency: 0,
      prestigeMultiplier: 1,
      lastActiveTimestamp: nowMs,
    },
    boosts: [],
    settings: { notificationsEnabled: false, fcmToken: "" },
  };
}

/** Facteur et cap offline effectifs pour ce joueur (VIP > achat cap étendu > défaut). */
function offlineParams(profile, config, nowMs) {
  const vip = profile.vipActive && (profile.vipExpiresAt || 0) > nowMs;
  if (vip) {
    return { factor: config.offline_factor_vip, cap: config.offline_cap_seconds_vip };
  }
  return {
    factor: config.offline_factor_default,
    cap: profile.offlineCapSeconds > 0 ? profile.offlineCapSeconds : config.offline_cap_seconds_default,
  };
}

exports.onAppOpen = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Auth requise.");

  const { clientTime, deviceId } = request.data || {};
  const config = await loadConfig();
  const nowMs = Date.now();
  const userRef = db().collection("users").doc(uid);
  const gensRef = userRef.collection("generators");

  const result = await db().runTransaction(async (tx) => {
    const [userSnap, gensSnap] = await Promise.all([tx.get(userRef), tx.get(gensRef)]);

    // Premier lancement : création du document (le client n'a pas le droit de créer).
    if (!userSnap.exists) {
      const doc = defaultUserDoc(nowMs, deviceId, config);
      tx.set(userRef, doc);
      return { doc, generators: {}, secondsAway: 0, gains: 0 };
    }

    const doc = userSnap.data();
    const generators = {};
    const levels = {};
    gensSnap.forEach((g) => {
      generators[g.id] = g.data();
      levels[g.id] = g.data().level || 0;
    });

    const lastActive = doc.economy?.lastActiveTimestamp || nowMs;
    const secondsAway = Math.max(0, (nowMs - lastActive) / 1000);

    const mult = eco.globalMultiplier(doc.economy, doc.profile, doc.boosts, config, nowMs);
    const pps = eco.productionPerSec(levels, config.generators, mult);
    const { factor, cap } = offlineParams(doc.profile, config, nowMs);
    const gains = eco.offlineGains(pps, secondsAway, factor, cap);

    // Boosts expirés purgés côté serveur.
    const boosts = (doc.boosts || []).filter((b) => (b.expiresAt || 0) > nowMs);

    const update = {
      "economy.gold": db.FieldValue.increment(gains),
      "economy.totalGoldEarned": db.FieldValue.increment(gains),
      "economy.lastActiveTimestamp": nowMs,
      "profile.lastSeenAt": nowMs,
      boosts,
    };
    if (deviceId && doc.profile?.deviceId !== deviceId) update["profile.deviceId"] = deviceId;
    tx.update(userRef, update);

    // Applique localement pour renvoyer le snapshot sans relire.
    doc.economy.gold = (doc.economy.gold || 0) + gains;
    doc.economy.totalGoldEarned = (doc.economy.totalGoldEarned || 0) + gains;
    doc.economy.lastActiveTimestamp = nowMs;
    doc.profile.lastSeenAt = nowMs;
    doc.boosts = boosts;

    return { doc, generators, secondsAway, gains };
  });

  // Signal anti-triche (analyse ultérieure) : dérive horloge client/serveur.
  if (typeof clientTime === "number") {
    const driftSec = Math.abs(nowMs - clientTime) / 1000;
    if (driftSec > 300) console.warn(`clock drift ${Math.round(driftSec)}s for uid=${uid}`);
  }

  return {
    serverTime: nowMs,
    secondsAway: Math.round(result.secondsAway),
    offlineGains: result.gains,
    state: {
      profile: result.doc.profile,
      economy: result.doc.economy,
      generators: result.generators,
      boosts: result.doc.boosts,
      settings: result.doc.settings,
    },
    config,
  };
});
