"use strict";
/**
 * Point d'entrée Cloud Functions — Empire d'Or.
 * Toutes les fonctions sont des `onCall` v2 (auth Firebase requise) et vivent
 * dans la même région que déclarée dans godot/config/firebase_settings.json.
 */
const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");

admin.initializeApp();
// maxInstances bas volontairement en phase de test (aucun utilisateur réel) :
// limite le coût d'un bug (boucle, pic de requêtes) pendant que le plan Blaze
// n'a pas encore de budget/alertes configurés. À remonter avant le soft launch.
setGlobalOptions({ region: "europe-west1", maxInstances: 2 });

exports.onAppOpen = require("./src/onAppOpen").onAppOpen;
exports.validatePurchase = require("./src/validatePurchase").validatePurchase;
