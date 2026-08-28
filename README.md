# Empire d'Or — Fondations (Godot 4 + Firebase)

Base technique du GDD "Empire d'Or". Aucun art, aucune UI finale : des systèmes, une économie et une structure de données prêts pour l'itération avec Claude Code.

```
empire_dor/
├── godot/                         Projet Godot 4.x (ouvrir ce dossier dans l'éditeur)
│   ├── project.godot              Autoloads déclarés ici (ordre significatif)
│   ├── autoloads/
│   │   ├── config.gd              Balance économique : defaults locaux + override Remote Config
│   │   ├── firebase_client.gd     Auth anonyme, Cloud Functions callable, Firestore (REST)
│   │   ├── game_state.gd          État joueur (PlayerData) — seul endroit qui mute les données
│   │   ├── economy.gd             Tick de production, achats, prestige, boosts
│   │   └── save_manager.gd        Sauvegarde locale + sync Firestore (jouable hors-ligne)
│   ├── scripts/
│   │   ├── economy_formulas.gd    Formules PURES (miroir de functions/src/economy.js)
│   │   ├── firestore_codec.gd     Dictionary <-> valeurs typées REST Firestore
│   │   ├── number_format.gd       1.2M, 3.4B…
│   │   ├── models/                GeneratorDef, PlayerData (miroir du doc Firestore)
│   │   └── ui/                    Composants UI (1 responsabilité par fichier, cf. § UI)
│   ├── scenes/main.tscn + main.gd Séquence de boot uniquement — l'UI est dans scripts/ui/
│   └── config/
│       ├── remote_config_defaults.json   ⭐ SOURCE UNIQUE de la balance (grille 3.5, produits…)
│       └── firebase_settings.example.json
└── firebase/
    ├── firebase.json, firestore.rules, firestore.indexes.json
    ├── functions/
    │   ├── index.js
    │   ├── src/economy.js         Formules PURES (miroir de economy_formulas.gd)
    │   ├── src/config.js          Lecture Remote Config (Admin SDK) + cache + fallback
    │   ├── src/onAppOpen.js       ⭐ Gains offline côté serveur, création du doc user, snapshot
    │   ├── src/validatePurchase.js ⭐ Vérif. store -> crédit gemmes/VIP, idempotent
    │   └── test/economy.test.js   Tests des formules + simulation de tuning
    └── remote_config/
        ├── build_template.js      Génère le template Firebase depuis remote_config_defaults.json
        ├── remoteconfig.template.json   (généré)
        └── defaults.json                (généré — fallback des Functions)
```

## Mise en route

**Godot**
1. Ouvrir `godot/` dans Godot 4.3+.
2. Copier `config/firebase_settings.example.json` → `config/firebase_settings.json` et renseigner `project_id`, `api_key` (clé Web du projet Firebase), `functions_region`.
3. Lancer : sans `firebase_settings.json`, le jeu tourne en mode 100 % local (utile pour itérer sur l'économie).

**Firebase**
```bash
cd firebase
cp .firebaserc.example .firebaserc          # renseigner l'id projet
cd functions && npm install && npm test     # tests des formules
cd .. && node remote_config/build_template.js
firebase deploy --only firestore:rules,remoteconfig,functions
```
Activer dans la console : Authentication → Anonyme ; Firestore ; Remote Config.
Pour `validatePurchase` Android : lier le compte de service des Functions à la Play Console (API access) et définir le paramètre `ANDROID_PACKAGE_NAME`.

## Flux de démarrage (main.gd)

1. `SaveManager.load_local()` → jouable immédiatement, même hors connexion.
2. `FirebaseClient.sign_in_anonymously()` (refresh token en cache → uid stable).
3. `onAppOpen` → renvoie **config Remote Config typée + snapshot serveur + gains offline**. Le serveur fait autorité sur `economy` et `generators`.
4. Pendant la session : sauvegarde locale toutes les 5 s si dirty, push Firestore toutes les 30 s et à la mise en pause.

## Conventions à respecter (pour les itérations suivantes)

| Règle | Implémentation |
|---|---|
| Aucune valeur de balance en dur | Tout passe par `Config.get_*()` ; la source est `remote_config_defaults.json`, déployée via `build_template.js` |
| Offline calculé serveur (6.3.1) | `onAppOpen` uniquement ; `EconomyFormulas.offline_gains` côté client ne sert qu'à l'affichage |
| Achats validés serveur (6.3.2) | `validatePurchase` ; les Security Rules interdisent au client de modifier `economy.gems`, `profile.vip*`, `purchases/*` |
| `totalGoldEarned` monotone (6.3.5) | Rule `totalGoldMonotonic()` + jamais décrémenté dans `GameState` |
| Formules en double | `economy_formulas.gd` ⇔ `economy.js` — modifier les deux, tests dans `functions/test` |
| Timestamps | Entiers **ms epoch UTC** partout (Godot et JS), jamais `timestampValue` Firestore |
| Multiplicateur unique (3.2) | Tous les boosts passent par `Economy.global_multiplier()` / `eco.globalMultiplier()` |

## Choix d'implémentation à connaître

- **Prestige** : `prestigeCurrency = floor(√(totalGoldEarned / seuil))` est une valeur *absolue* dérivée du compteur à vie ; le gain d'un prestige est la différence avec la valeur possédée. Simple, sans état intermédiaire, compatible avec un futur leaderboard.
- **Firestore via REST** plutôt qu'un plugin natif : zéro dépendance, testable sur desktop. Le push (FCM) nécessitera un plugin natif Android/iOS — champ `settings.fcmToken` déjà prévu.
- **Firestore rules** : le client peut écrire `gold`/`totalGoldEarned`/`generators` (jeu actif). C'est un compromis V1, mais `level` (generators) et `boosts` sont bornés par les rules (valeurs sanity, pas de balance) pour empêcher une injection directe qui gonflerait les gains hors-ligne calculés par `onAppOpen`. Une vraie plausibilité de `gold` vs temps écoulé reste la prochaine étape logique côté serveur.
- **Précision** : `float` Godot / `Number` JS = double 64 bits, suffisant pour les 7 paliers. Prévoir un BigNumber au-delà de ~1e300.
- **Simulation de tuning** (`npm test`) : avec un joueur glouton et 1 or/s de "tap" initial, le premier prestige tombe à **~21 min**, un peu au-dessus de la cible 15-20 min. À trancher en playtest (ex. un Paysan offert au départ, ou `prestige_threshold` légèrement abaissé). Le test sert de garde-fou (< 25 min) à chaque changement de grille.

## UI — identité "registre de guilde"

Système de design dans `godot/scripts/ui/empire_theme.gd` (aucune couleur/police en dur ailleurs) :

- **Palette** : encre profonde (`#151009`) et or vieilli (`#e8b93a`), accent cuivre (`#c97b3d`) pour le prestige. Filets fins en séparateurs plutôt que des cartes à coins arrondis — esprit livre de comptes, pas app mobile générique.
- **Typo** : Cinzel (display, capitales à empattements) pour les titres et gros montants ; Spectral (serif de corps) pour le reste. Polices dans `godot/assets/fonts/` (Google Fonts, licence OFL).
- **Composants** (1 responsabilité par fichier, sur le modèle de `generator_row.gd`) :
  - `scripts/ui/game_screen.gd` — assemble l'écran et réagit seul aux signaux GameState/Economy/Config.
  - `scripts/ui/header_panel.gd` — titre, statut de boot, or, gemmes, production/s.
  - `scripts/ui/generator_row.gd` — une ligne de registre par générateur (verrouillé/déverrouillé, achat selon le mode courant).
  - `scripts/ui/buy_mode.gd` + `buy_mode_selector.gd` — sélecteur x1/x10/MAX partagé par toutes les lignes.
  - `scripts/ui/tap_button.gd` — bouton "Frapper une pièce" + retour visuel du gain.
  - `scripts/ui/footer_panel.gd` — bouton de prestige + utilitaires (boutique, sauvegarde manuelle, cheat debug).
  - `scripts/ui/shop_screen.gd` — écran boutique superposé (overlay masqué par défaut, ouvert depuis le pied de page).
  - `scripts/ui/shop_header.gd` — titre, solde de gemmes, bouton de fermeture de la boutique.
  - `scripts/ui/shop_row.gd` — ligne générique (nom, sous-texte, bouton d'action), réutilisée pour boosters et catalogue IAP.
  - `scripts/ui/shop_catalog.gd` — pur formatage : traduit un booster/produit Remote Config en texte d'affichage (aucune construction de nœud).
  - `scenes/main.gd` ne fait plus que la séquence de boot et instancie `GameScreen`.
- Le bouton `[DEBUG] +1000 or` (footer) et `[DEBUG] +100 gemmes` (boutique), visibles seulement en build debug via `OS.is_debug_build()`, permettent de tester la boucle et les boosters sans attendre un vrai moyen d'obtenir gemmes/or.

Boucle principale (achat en masse x1/x10/MAX, prestige, tap) vérifiée visuellement dans l'éditeur. L'écran boutique est neuf et n'a pas encore été vu à l'écran — à valider avec F5.

## Non couvert (à itérer avec Claude Code)

- Validation iOS (`verifyIos`) : squelette + TODO avec `@apple/app-store-server-library`.
- Acknowledge/consume des achats Google Play, abonnements VIP via `subscriptionsv2`.
- Intégration StoreKit / Play Billing côté Godot (plugins natifs).
- Notifications (FCM + fonction planifiée pour les déclencheurs de la section 5).
- Streak quotidien, gemmes VIP quotidiennes, `offline_mult` des boosters (champ prévu, logique serveur à écrire — affiché "bientôt disponible" dans `shop_screen.gd` en attendant).
- Achat réel des produits IAP (gemmes, VIP, retrait pub, pack de démarrage) : catalogue affiché dans l'écran boutique, mais bouton désactivé tant que StoreKit/Play Billing ne sont pas intégrés côté Godot.
- Stratégie de merge local/serveur si l'app est tuée avant le dernier push Firestore.
