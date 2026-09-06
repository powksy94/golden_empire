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

**Émulateurs** (aucun projet réel requis, testé et fonctionnel) :
```bash
cd firebase && firebase emulators:start --only functions,firestore,auth --project demo-empire-dor
```
UI sur http://127.0.0.1:4000. `onAppOpen` et `validatePurchase` sont appelables en HTTP direct via
`http://127.0.0.1:5001/demo-empire-dor/europe-west1/<nom>` avec un idToken obtenu via
`POST http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`.

**Sécuriser le plan Blaze avant tout déploiement réel** (obligatoire pour les Cloud Functions v2) :
1. Google Cloud Console → Facturation → Budgets et alertes : créer un budget symbolique (ex. 5 €) avec alertes à 50/90/100 %. **À faire par toi** (console web, pas d'accès depuis ici).
2. `maxInstances` des Cloud Functions volontairement bas (`2`, cf. `index.js`) tant qu'il n'y a aucun utilisateur réel — à remonter avant le soft launch.
3. Firebase App Check — **pas encore actionnable** : nécessite un SDK natif par plateforme (Play Integrity / App Attest) pour générer un token valide, or Godot n'a pas de SDK Firebase officiel (`FirebaseClient` est en REST pur, cf. § Choix d'implémentation). L'activer sans ce plugin natif bloquerait le jeu entier. À revoir en même temps que StoreKit/Play Billing (Non couvert).
4. Security Rules : déjà verrouillées à `isOwner(userId)` (aucun accès anonyme non authentifié), cf. `firestore.rules`.

**Piège rencontré au premier déploiement réel** — après `firebase deploy`, les deux fonctions
répondaient `401 Unauthorized` malgré un déploiement "réussi". Cause : les Cloud Functions v2
(2nd Gen, basées sur Cloud Run) ont **deux surfaces IAM distinctes**, et `firebase deploy` n'a
posé le binding public sur **aucune des deux** cette fois-ci (bindings vides à la vérification) :
- `roles/run.invoker` sur le service Cloud Run sous-jacent (`gcloud run services
  add-iam-policy-binding <nom-minuscule> --member=allUsers --role=roles/run.invoker`)
- `roles/cloudfunctions.invoker` sur la ressource Cloud Function elle-même (`gcloud functions
  add-invoker-policy-binding <NomFonction> --region=... --member=allUsers`)

Sans `gcloud` installé, ces deux appels peuvent aussi se faire en REST directement sur
`run.googleapis.com/v2/.../services/<service>:setIamPolicy` et
`cloudfunctions.googleapis.com/v2/.../functions/<Fonction>:setIamPolicy`. Si un futur déploiement
répète le problème, vérifier ces deux policies AVANT de chercher ailleurs.

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
- **Écran principal = scène village** (`scripts/village/`, sous-dossiers par catégorie — Godot résout les classes par `class_name`, pas par chemin, donc l'arborescence est libre), style idle game : bâtiments sur deux rangées, pièces qui montent, ciel/sol en dégradé avec collines et nuages. **Toucher un bâtiment qu'on possède (niveau ≥ 1) frappe une pièce** — toucher le décor, le ciel, ou un bâtiment verrouillé/pas encore acheté ne rapporte rien (test de collision AABB via `GeneratorBuilding.screen_rect()`). Le HUD (en-tête, pied de page) est par-dessus ; registre d'achat et boutique sont des overlays.
  - `village_scene.gd` (racine) — assemble les composants ci-dessous, gère le tap et les pièces émises par la production. Ne construit lui-même ni le fond, ni le décor, ni les bâtiments.
  - `backdrop/village_backdrop.gd` — dégradé ciel→sol unique (pas deux blocs de couleur juxtaposés) + collines lointaines (`Polygon2D`) à l'horizon.
  - `decor/village_decor.gd` — arbres et nuages procéduraux, purement esthétique.
  - `buildings/village_buildings.gd` — les 7 `GeneratorBuilding`, répartis sur deux rangées **positionnées dynamiquement** (`_layout_row` centre chaque rangée selon la largeur réelle des sprites — nécessaire depuis les illustrations IA, bien plus larges que les anciennes tuiles 32px), et le hit-test de tap (`owned_building_at`).
  - `buildings/generator_building.gd` — un bâtiment = un générateur : sprite ou silhouette, **entièrement masqué si verrouillé** (pas un fantôme translucide : lisible avec de simples silhouettes, ça devenait un fouillis confus avec des illustrations détaillées), badge de niveau, `screen_rect()` pour le hit-test de tap. Les ouvriers (`SHOW_WORKERS`) sont désactivés pour l'instant — le sprite pixel art Kenney (16px) était méconnaissable à côté des bâtiments IA détaillés ; la logique de déblocage reste prête pour un futur asset assorti.
  - `actors/worker_actor.gd` — personnage `AnimatedSprite2D` qui va et vient (ou silhouette sautillante sans asset) ; actuellement inutilisé (`SHOW_WORKERS = false`, cf. ci-dessus).
  - `fx/coin_pop.gd` — « +X or » qui s'élève et s'estompe.
  - `sprite_manifest.gd` (racine, utilisé par tous les composants ci-dessus) — lit `assets/sprites/manifest.json` (format documenté en tête de fichier) : par générateur, une texture de bâtiment (`texture` + `region` optionnelle sur une planche, ou `height` pour une taille de conception explicite — voir plus bas) et des frames d'ouvrier (`frames` [col,row] sur une planche, ou `files`), plus `coin` et `background.sky/ground`. **Toute entrée absente retombe sur `placeholder_shapes.gd`** : le jeu tourne sans aucun asset.
  - `placeholder_shapes.gd` (racine, utilisé par tous les composants ci-dessus) — silhouettes `Polygon2D` de secours (bâtiments, arbres, nuages).
  - **Bâtiments** (`assets/sprites/village/building_*.png`) : illustrations générées par IA (une par palier), détourées et recadrées avec [rembg](https://github.com/danielgatis/rembg) (modèle `isnet-general-use`) à partir des sources dans `assets/sprites/2D-pack/*.jpg` (celles-ci n'ont jamais de vraie transparence — les générateurs d'images grand public simulent juste un damier visuellement, il faut toujours détourer après coup). Chaque entrée du manifest précise `"height"` (pixels de conception, indépendant de la résolution source) plutôt que le `pixel_scale` global : ces illustrations peintes haute résolution n'ont rien à voir avec des tuiles pixel art, `building_texture()`/`building_height()` dans `sprite_manifest.gd` + `generator_building.gd` calculent l'échelle en conséquence, filtrage `LINEAR` (pas `NEAREST`) pour rester net sans crénelage. Les hauteurs cibles sont choisies pour respecter **deux** contraintes (souvent oublié) : tenir sous la ligne d'horizon ET tenir en largeur cumulée par rangée (4 bâtiments dans 1080px).
  - **⚠️ `assets/sprites/2D-pack/cloud.webp` porte un filigrane Shutterstock** (aperçu non-licencié) — ne jamais l'utiliser dans le jeu, même détouré. Le ciel utilise des nuages procéduraux (`PlaceholderShapes.cloud`) à la place ; si un vrai pack de nuages CC0/licencié est trouvé, l'intégrer comme les bâtiments (détourage + manifest).
  - **Décor** : `coin.png`/`ground.png` (inutilisé depuis le passage au dégradé procédural) restent des tuiles du pack Kenney "Tiny Town" (CC0, `assets/sprites/Tiles/`, licence dans `assets/sprites/License.txt`). Les arbres et nuages sont désormais procéduraux (`PlaceholderShapes.tree/cloud`) : les tuiles Kenney sont vues du dessus (juste un rond de feuillage sans tronc), ce qui rendait mal posées debout dans une scène de profil.
  - Pour changer un bâtiment : régénérer un visuel (garder le même angle trois-quarts et un éclairage plat pour rester cohérent avec les autres, cf. le prompt utilisé en session), le détourer (`rembg` ou équivalent), le recadrer à son contenu réel, et ajuster `height` dans le manifest **en vérifiant les deux contraintes ci-dessus**.
- **Composants UI** (`scripts/ui/`, 1 responsabilité par fichier, sur le modèle de `generator_row.gd`) :
  - `game_screen.gd` — compose scène + HUD + overlays, réagit seul aux signaux GameState/Economy/Config.
  - `header_panel.gd` — titre, statut de boot, or, gemmes, production/s (variation `HudPanel`, translucide, par-dessus la scène).
  - `footer_panel.gd` — bouton Registre (action principale), prestige + utilitaires (boutique, sauvegarde manuelle, cheat debug).
  - `ledger_panel.gd` — registre d'achat en overlay : sélecteur x1/x10/MAX + une `GeneratorRow` par générateur.
  - `generator_row.gd` — une ligne de registre par générateur (verrouillé/déverrouillé, achat selon le mode courant).
  - `buy_mode.gd` + `buy_mode_selector.gd` — sélecteur x1/x10/MAX partagé par toutes les lignes.
  - `overlay_header.gd` — en-tête générique d'overlay (titre, info à droite, bouton Fermer), utilisé par registre et boutique.
  - `shop_screen.gd` — écran boutique en overlay.
  - `shop_row.gd` — ligne générique (nom, sous-texte, bouton d'action), réutilisée pour boosters et catalogue IAP.
  - `shop_catalog.gd` — pur formatage : traduit un booster/produit Remote Config en texte d'affichage (aucune construction de nœud).
  - `scenes/main.gd` ne fait plus que la séquence de boot et instancie `GameScreen`.
- `scripts/json_util.gd` — conversions JSON défensives (null, type inattendu → défaut), utilisées par `GeneratorDef` et `SpriteManifest`.
- Le bouton `[DEBUG] +1000 or` (footer) et `[DEBUG] +100 gemmes` (boutique), visibles seulement en build debug via `OS.is_debug_build()`, permettent de tester la boucle et les boosters sans attendre un vrai moyen d'obtenir gemmes/or.

Boucle principale (achat en masse x1/x10/MAX, prestige, boutique) vérifiée visuellement dans l'éditeur. La scène village et le registre en overlay sont neufs et n'ont pas encore été vus à l'écran — à valider avec F5.

## Non couvert (à itérer avec Claude Code)

- Validation iOS (`verifyIos`) : squelette + TODO avec `@apple/app-store-server-library`.
- Acknowledge/consume des achats Google Play, abonnements VIP via `subscriptionsv2`.
- Intégration StoreKit / Play Billing côté Godot (plugins natifs).
- Notifications (FCM + fonction planifiée pour les déclencheurs de la section 5).
- Streak quotidien, gemmes VIP quotidiennes, `offline_mult` des boosters (champ prévu, logique serveur à écrire — affiché "bientôt disponible" dans `shop_screen.gd` en attendant).
- Achat réel des produits IAP (gemmes, VIP, retrait pub, pack de démarrage) : catalogue affiché dans l'écran boutique, mais bouton désactivé tant que StoreKit/Play Billing ne sont pas intégrés côté Godot.
- Sprites du village : les 7 bâtiments sont des illustrations dédiées (cf. § UI), mais **aucun personnage/ouvrier n'est affiché** (`GeneratorBuilding.SHOW_WORKERS = false`) — le sprite Kenney (16px) détonnait trop à côté ; il faudra soit générer un personnage au même style que les bâtiments (avec walk-cycle si possible), soit en commander un dédié. Le chariot (caravane) est en vue de profil pur, les 4 autres bâtiments en trois-quarts isométrique : légère incohérence d'angle à arbitrer si on régénère encore des assets.
- Stratégie de merge local/serveur si l'app est tuée avant le dernier push Firestore.
