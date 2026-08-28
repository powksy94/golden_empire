"use strict";
/**
 * validatePurchase — Règle 6.3.2 : aucun crédit de gemmes sans vérification
 * du purchaseToken auprès de Google / Apple. Idempotente (un token = un crédit).
 *
 * Entrée : { platform: "android" | "ios", productId: string, purchaseToken: string,
 *            packageName?: string }
 * Sortie : { status: "credited" | "already_credited", granted: {...}, economy, profile }
 *
 * Android : Google Play Developer API (androidpublisher v3). Le compte de service
 *           des Functions doit être lié à la Play Console (Setup > API access).
 * iOS     : App Store Server API — À IMPLÉMENTER (squelette + TODO ci-dessous).
 */
const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineString } = require("firebase-functions/params");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { google } = require("googleapis");
const { loadConfig } = require("./config");

const db = getFirestore();
const ANDROID_PACKAGE = defineString("ANDROID_PACKAGE_NAME", { default: "com.powksy.goldenempire" });

// ------------------------------------------------------------ vérification stores

async function verifyAndroid(packageName, productId, token) {
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const publisher = google.androidpublisher({ version: "v3", auth });
  const res = await publisher.purchases.products.get({ packageName, productId, token });
  const p = res.data;
  // purchaseState: 0 = purchased, 1 = canceled, 2 = pending
  if (p.purchaseState !== 0) return { valid: false, reason: `purchaseState=${p.purchaseState}` };
  // TODO: pour les abonnements (VIP) utiliser purchases.subscriptionsv2.get
  // TODO: acknowledge / consume côté serveur ou client selon le type de produit
  return { valid: true, orderId: p.orderId, priceMicros: null, currency: null };
}

// eslint-disable-next-line no-unused-vars
async function verifyIos(productId, signedTransaction) {
  // TODO: App Store Server API — vérifier le JWS (signedTransactionInfo) avec la
  // librairie officielle `@apple/app-store-server-library`, contrôler bundleId,
  // productId, et l'environnement (Sandbox/Production).
  throw new HttpsError("unimplemented", "Validation iOS non implémentée (phase fondations).");
}

// ------------------------------------------------------------ application du produit

/** Traduit un produit du catalogue Remote Config en mutations Firestore. */
function grantProduct(product, doc, nowMs) {
  const update = {};
  const granted = {};
  const gems = product.gems || 0;
  if (gems > 0) {
    update["economy.gems"] = FieldValue.increment(gems);
    granted.gems = gems;
  }
  switch (product.type) {
    case "gems":
      break;
    case "remove_ads":
      update["profile.adsRemoved"] = true;
      granted.adsRemoved = true;
      break;
    case "bundle": {
      if (product.boost_mult && product.boost_seconds) {
        const boost = { mult: product.boost_mult, expiresAt: nowMs + product.boost_seconds * 1000, source: "starter_pack" };
        update.boosts = [...(doc.boosts || []), boost];
        granted.boost = boost;
      }
      if (product.no_ads_seconds) {
        const until = Math.max(doc.profile?.noAdsUntil || 0, nowMs) + product.no_ads_seconds * 1000;
        update["profile.noAdsUntil"] = until;
        granted.noAdsUntil = until;
      }
      break;
    }
    case "vip": {
      const base = Math.max(doc.profile?.vipExpiresAt || 0, nowMs);
      const expires = base + (product.duration_days || 30) * 86400 * 1000;
      update["profile.vipActive"] = true;
      update["profile.vipExpiresAt"] = expires;
      granted.vipExpiresAt = expires;
      break;
    }
    case "offline_cap":
      update["profile.offlineCapSeconds"] = product.cap_seconds;
      granted.offlineCapSeconds = product.cap_seconds;
      break;
    default:
      throw new HttpsError("failed-precondition", `Type de produit inconnu : ${product.type}`);
  }
  return { update, granted };
}

// ------------------------------------------------------------ fonction

exports.validatePurchase = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Auth requise.");

  const { platform, productId, purchaseToken, packageName } = request.data || {};
  if (!platform || !productId || !purchaseToken) {
    throw new HttpsError("invalid-argument", "platform, productId et purchaseToken requis.");
  }

  const config = await loadConfig();
  const product = config.products?.[productId];
  if (!product) throw new HttpsError("not-found", `Produit inconnu : ${productId}`);

  // Idempotence : l'id de transaction est un hash du token (jamais le token brut en clé).
  const txId = crypto.createHash("sha256").update(`${platform}:${purchaseToken}`).digest("hex");
  const userRef = db.collection("users").doc(uid);
  const purchaseRef = userRef.collection("purchases").doc(txId);

  const existing = await purchaseRef.get();
  if (existing.exists) {
    return { status: "already_credited", granted: existing.data().granted || {} };
  }

  // Vérification auprès du store AVANT tout crédit.
  let verification;
  if (platform === "android") {
    verification = await verifyAndroid(packageName || ANDROID_PACKAGE.value(), productId, purchaseToken);
  } else if (platform === "ios") {
    verification = await verifyIos(productId, purchaseToken);
  } else {
    throw new HttpsError("invalid-argument", "platform doit être android ou ios.");
  }
  if (!verification.valid) {
    throw new HttpsError("permission-denied", `Achat invalide : ${verification.reason}`);
  }

  const nowMs = Date.now();
  const outcome = await db.runTransaction(async (tx) => {
    const [userSnap, purchaseSnap] = await Promise.all([tx.get(userRef), tx.get(purchaseRef)]);
    if (purchaseSnap.exists) return { status: "already_credited", granted: purchaseSnap.data().granted };
    if (!userSnap.exists) throw new HttpsError("failed-precondition", "Utilisateur inexistant (appeler onAppOpen d'abord).");

    const doc = userSnap.data();
    const { update, granted } = grantProduct(product, doc, nowMs);
    tx.update(userRef, update);
    tx.set(purchaseRef, {
      productId,
      platform,
      orderId: verification.orderId || null,
      price: verification.priceMicros ? verification.priceMicros / 1e6 : null,
      currency: verification.currency || null,
      purchaseToken, // conservé pour audit / remboursements ; jamais renvoyé au client
      validatedAt: nowMs,
      granted,
    });
    return { status: "credited", granted };
  });

  const fresh = await userRef.get();
  const d = fresh.data();
  return { ...outcome, economy: d.economy, profile: d.profile };
});
