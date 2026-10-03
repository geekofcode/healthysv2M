# 18.12 — Stabilisation et publication HEALTH’YS

## État et portée

Le dépôt prépare les builds et la distribution, sans envoyer de binaire aux stores.
Les identifiants `com.example.healthysv2`, les icônes Flutter et les URL d'exemple
doivent être remplacés avant distribution. Aucun certificat, compte développeur,
keystore de production ni credential Firebase/APNs/LiveKit n'est fourni.

La CI vérifie Flutter, le contrat OpenAPI, l'APK debug, un AAB release signé avec
une **clé éphémère réservée aux tests**, et un build iOS release **sans signature**.
Ces deux builds release utilisent `prod.example.json` : ils vérifient la compilation,
pas une connexion au backend réel. Ils ne sont pas distribuables.

## Stabilisation livrée

- Dio : délais bornés, absence de redirections avec bearer, destinations de même
  origine, erreurs présentées avec des textes contrôlés FR/EN et référence bornée.
- Après 401, seul GET/HEAD/OPTIONS est rejoué automatiquement et une seule fois.
  Une mutation n'est pas répétée sans opt-in explicite. Après une coupure, vérifier
  son résultat serveur avant de tenter à nouveau une réservation ou un envoi.
- Une panne de refresh conserve la session pour une nouvelle tentative ; un grant
  invalide expire la session. Les réponses d'un ancien compte sont supprimées.
- Tokens OIDC conservés dans le stockage sécurisé, bundles validés et supprimés
  s'ils sont corrompus ; diagnostics des tokens OIDC et LiveKit expurgés. Les tokens
  LiveKit restent en mémoire. Aucune donnée médicale n'est persistée pour un mode
  hors ligne : les écrans affichent une erreur récupérable et proposent une reprise.
- Thème système/clair/sombre et langue système/français/anglais sauvegardés par
  environnement. La langue du système non prise en charge revient à l'anglais.
  Les dates/heures suivent les localisations Material et le fuseau de l'appareil.
  Les diagnostics médicaux et textes libres du serveur ne sont pas traduits.
- Les demandes caméra/micro iOS sont localisées FR/EN selon la langue native de
  l'application, indépendamment du choix interne Flutter. Les médias sont éteints
  par défaut ; arrière-plan, logout et retrait d'admission coupent les médias.
- Palettes de thème réutilisées lors des changements de session/push, sans recalcul.
  Listes paginées, rendu paresseux, polling d'attente limité aux routes visibles,
  LiveKit adaptive stream/dynacast et fermeture bornée des ressources sont conservés.
  La compilation release applique les optimisations de Flutter. Aucun gain de
  latence, mémoire ou batterie n'est annoncé sans mesure sur appareil.

## Vérification reproductible

```sh
flutter pub get --enforce-lockfile
./tool/generate_api.sh --check
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
python3 -m unittest discover -s tool/tests -v
# Dans packages/healthys_api : dart analyze puis dart test.
# Backend associé, Java 21 : ./mvnw verify
```

La CI utilise la version Flutter épinglée dans `.github/workflows/flutter.yml`.
Le backend doit inclure V17 (push), V18 (nettoyage LiveKit) et les contrats mobiles.
Configurer LiveKit avec `room.auto_create: false`. Un JWT déjà délivré conserve sa
validité jusqu'à sa courte expiration tant que la salle active existe ; ce n'est
pas une révocation instantanée côté fournisseur. Une panne LiveKit peut retarder
la fermeture distante jusqu'au nettoyage serveur.

## Identité et configuration de production

1. Réserver l'identifiant Android et le Bundle ID iOS définitifs sur les comptes
   de l'organisation. Modifier `applicationId` dans `android/app/build.gradle.kts`
   et `PRODUCT_BUNDLE_IDENTIFIER` des configurations Runner dans Xcode. Conserver
   le namespace/Kotlin existant est possible : il n'est pas l'identifiant store.
2. Enregistrer ces applications dans Firebase. Suivre le
   [README Firebase/APNs](../firebase-apns/README.md), avec des fichiers natifs
   et dart-defines propres à chaque plateforme. Réenregistrer les empreintes de
   certificats nécessaires aux intégrations réellement utilisées.
3. Créer `config/prod.android.local.json` et `config/prod.ios.local.json` depuis
   `config/prod.example.json` : API HTTPS réelle, issuer/client public Keycloak,
   IDs Firebase cohérents si push activé. Aucun client secret OIDC, clé LiveKit,
   token ou compte de service dans ces fichiers, qui sont intégrés au binaire.
4. Keycloak : client public natif, Authorization Code + PKCE, callback exact
   `healthys://oauth/callback`, logout callback identique ; vérifier `/me` et le
   lien personne/compte. Vérifier les règles réseau du serveur et WSS LiveKit.
5. Incrémenter `version: x.y.z+N` dans `pubspec.yaml` pour chaque build distribué.
   Remplacer les icônes et écrans de lancement par les assets définitifs HEALTH’YS.

## Android — signature et Google Play

Le SDK de compilation est 37, requis par `permission_handler_android` ; min/target
suivent Flutter. Installer la plateforme correspondante et accepter les licences.

Créer une clé d'upload conservée hors du dépôt et sauvegardée de manière sûre.
Pour les commandes et paramètres de génération, suivre le guide officiel Flutter
ci-dessous. Écrire `android/key.properties` (ignoré par Git) :

```properties
storeFile=/chemin/absolu/upload-keystore.jks
storePassword=VALEUR_LOCALE
keyAlias=upload
keyPassword=VALEUR_LOCALE
```

Les valeurs ne doivent pas apparaître dans les logs. Les builds release échouent
si ces quatre paramètres manquent ; aucun fallback vers la clé debug n'existe.
La CI génère une clé temporaire pour compiler, la détruit et ne l'utilise jamais
pour une publication. Ne jamais distribuer un AAB de cette CI.

```sh
python3 tool/check_release.py --platform android --config config/prod.android.local.json
flutter build appbundle --release --dart-define-from-file=config/prod.android.local.json
```

Après prévalidation réussie : vérifier le certificat de l'AAB dans Android Studio
ou avec `jarsigner -verify -verbose -certs`, puis charger le build dans la piste
interne de Play Console. Activer Play App Signing, vérifier l'upload key, les pays,
la classification, les coordonnées support, la politique de confidentialité et
les captures FR/EN. Remplir Data safety et la déclaration Health apps selon les
traitements réellement déployés ; ne pas déclarer « aucune donnée » pour une app
qui transmet les dossiers, messages ou identifiants au backend.

## iOS — Xcode, signature et App Store Connect

Utiliser un Mac et un Xcode compatibles avec la version Flutter de CI et avec
les exigences Apple en vigueur au moment du dépôt. Minimum iOS : 15.0.
Flutter utilise SPM où les plugins le permettent et CocoaPods en fallback.
Le Podfile active caméra/micro dans ce fallback ; en SPM, les clés Info.plist
sélectionnent ces permissions. Ne pas retirer les descriptions d'usage.

```sh
flutter pub get --enforce-lockfile
flutter build ios --release --no-codesign --dart-define-from-file=config/prod.ios.local.json
open ios/Runner.xcworkspace
```

Dans Runner : sélectionner l'équipe de l'organisation (`DEVELOPMENT_TEAM`), le
Bundle ID enregistré et la signature/provisioning appropriés pour Release.
Activer Push Notifications, vérifier l'entitlement APNs de distribution et
le certificat/profil ; suivre le README Firebase/APNs. L'équipe doit apparaître
dans le projet pour que le script de prévalidation puisse la vérifier.

```sh
python3 tool/check_release.py --platform ios --config config/prod.ios.local.json
flutter build ipa --release --dart-define-from-file=config/prod.ios.local.json
```

Vérifier l'archive dans Xcode Organizer : signature, entitlement APNs,
localisations, permissions et rapport agrégé des privacy manifests des SDK.
Documenter les raisons des required-reason APIs réellement utilisées avant envoi.
Compléter App Privacy dans App Store Connect, puis distribuer via TestFlight.
L'archive IPA signée et son export App Store nécessitent les certificats/profils
de l'organisation ; un build `--no-codesign` ne les valide pas.

## Prévalidation et ce qu'elle ne prouve pas

`tool/check_release.py` refuse les URL d'exemple/non HTTPS, callbacks incohérents,
champs secrets, identifiants natifs exemples, signature Android absente et équipe
Apple absente. Avec push activé, il compare JSON/plist Firebase aux identifiants
et dart-defines. Il ne contacte pas Firebase, Keycloak ou les stores ; il ne
vérifie ni la validité cryptographique des certificats ni le statut des comptes.
Il ne remplace pas un test end-to-end ni la revue des déclarations stores.

## Recette sur appareils et performance

Avant distribution interne, avec deux comptes patients et un soignant de test :

| Parcours | Vérification attendue |
| --- | --- |
| Login/refresh/logout | Restauration, expiration, refresh interrompu, aucun token dans logs/crash report ; ancien compte jamais visible après changement |
| Réseau | Mode avion au lancement/en consultation/en upload, timeout et 5xx : erreur claire, reprise explicite, aucune mutation doublée |
| Documents | Téléchargement autorisé, annulation, limites fichiers ; suppression des fichiers temporaires ; logout pendant lecture |
| Push | Permission refusée puis activée, token rotation, foreground/background/app fermée, APNs TestFlight et destination autorisée |
| Téléconsultation | Admission, médias éteints, permissions refusées, audio seul/vidéo, retrait d'admission, session finie, arrière-plan, réseau interrompu, reprise et sortie |
| Thème/langue | Système/clair/sombre et FR/EN ; relancement, gros texte, contraste, clavier, petit écran et navigation conservée |
| Isolation | Liens/documents/salles d'un autre patient refusés ; compte désactivé ; source RDV annulée |

Mesurer sur un Android et un iPhone physiques avec `flutter run --profile`
et la configuration réelle de test : démarrage, scroll d'historiques paginés,
mémoire avant/après PDF et appel, absence de caméra/micro après interruption,
réseau/batterie en arrière-plan. Utiliser DevTools pour les frames/mémoire,
Android Studio profiler et Instruments pour le natif. Ne pas profiler en debug.
Consigner l'appareil, la version, le scénario et les mesures dans la release.
Pour la taille Android : `flutter build apk --release --target-platform android-arm64
--analyze-size --dart-define-from-file=config/prod.android.local.json`.

## Points à finaliser dans les comptes stores

- Identité/signature, marque et icônes définitives, URLs publiques support et
  confidentialité, déclarations santé/privacy, screenshots FR/EN, review notes.
- Fournir à la review un compte et un scénario de démonstration sans données
  médicales réelles ni secrets intégrés dans le binaire.
- Déterminer le parcours de demande de suppression de compte et la conservation
  nécessaire du dossier médical. Il n'est pas implémenté par ce module : vérifier
  les exigences applicables Apple/Google avant soumission, particulièrement si
  l'inscription est proposée par le service. Ne pas simuler une suppression locale.
- Respecter les validations des fournisseurs et les essais sur appareils. Le
  carnet mère-enfant ne détermine pas à lui seul le public cible déclaré.
- Tester d'abord piste interne/TestFlight ; la mise en production et la soumission
  sont des actions distinctes non réalisées ici.

## Références officielles

- [Flutter Android](https://docs.flutter.dev/deployment/android)
- [Flutter iOS](https://docs.flutter.dev/deployment/ios)
- [Flutter SPM](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)
- [permission_handler iOS](https://pub.dev/packages/permission_handler)
- [Flutter performance](https://docs.flutter.dev/perf)
- [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple suppression de compte](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Google Health apps](https://support.google.com/googleplay/android-developer/answer/14738291)
- [Google Data safety](https://support.google.com/googleplay/android-developer/answer/10787469)
