"use strict";
/**
 * Point d'entrée Cloud Functions — Empire d'Or.
 * Toutes les fonctions sont des `onCall` v2 (auth Firebase requise) et vivent
 * dans la même région que déclarée dans godot/config/firebase_settings.json.
 */
const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");

admin.initializeApp();
setGlobalOptions({ region: "europe-west1", maxInstances: 10 });

exports.onAppOpen = require("./src/onAppOpen").onAppOpen;
exports.validatePurchase = require("./src/validatePurchase").validatePurchase;
