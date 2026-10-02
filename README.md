# HEALTH’YS mobile — socle 18.1

Application Flutter Android/iOS. Architecture par fonctionnalité, Riverpod pour injection/état, GoRouter pour navigation et Dio pour HTTP. Le thème Material 3 reprend le vert `#087f5b` du frontend HEALTH’YS et suit le mode clair/sombre du système. Interface initiale FR/EN selon la langue du téléphone, anglais par défaut.

## Démarrer

Installer la version Flutter stable épinglée dans `.github/workflows/flutter.yml` (Dart >= 3.12.2), puis :

```bash
flutter pub get
flutter run --dart-define-from-file=config/dev.json
```

`config/dev.json` cible `http://10.0.2.2:8080/api/v1` (émulateur Android). Pour un appareil physique ou iOS, créer `config/dev.local.json` avec une URL accessible depuis l'appareil puis utiliser ce fichier. Sur iOS, utiliser HTTPS (par exemple un tunnel de développement) : aucune exception ATS globale n'est ajoutée. Android autorise HTTP uniquement dans le manifeste debug.

Pour la production :

```bash
cp config/prod.example.json config/prod.json
# Remplacer api.example.com par l'URL réelle du backend.
flutter build appbundle --dart-define-from-file=config/prod.json
flutter build ipa --dart-define-from-file=config/prod.json
```

`APP_ENV` accepte `dev` ou `prod`. Production : URL explicite HTTPS terminant par `/api/v1`, sans identifiants, query ni fragment. Une configuration invalide bloque le démarrage. Un build release exige `APP_ENV=prod`. Les fichiers dart-define sont intégrés au binaire : **aucun secret** ne doit y figurer. Les clés de signature Android et l'équipe Apple doivent être configurées avant publication ; le projet conserve les identifiants `com.example.healthysv2` du dépôt initial pour ce socle. La signature Android release initiale reste celle de développement.

## Organisation

- `lib/app/` : application, routing et thème.
- `lib/core/config/` : configuration immuable injectée au démarrage.
- `lib/core/network/` : Dio partagé, bearer token, délais, corrélation et normalisation des erreurs.
- `lib/core/storage/` : interface injectable de stockage des tokens et implémentation secure storage.
- `lib/core/errors/` : erreurs typées et présentation réutilisable.
- `lib/core/api/` : client OpenAPI injecté avec le même Dio.
- `lib/features/<feature>/presentation/` : écrans, puis `application/`, `domain/` et `data/` à ajouter selon les besoins métier.
- `packages/healthys_api/` : client généré, à régénérer plutôt qu'éditer.

Les futurs repositories utilisent le client injecté ; les providers d'état exposent `AsyncValue` à la présentation. Ne pas créer de Dio par écran. Routes initiales : `/` et `/settings`, avec une page de secours pour une route inconnue. Les écrans métier et l'authentification Keycloak appartiennent aux étapes suivantes.

## HTTP et erreurs

Le token est lu au moment de chaque requête. Le stockage utilise Keychain sur iOS et le stockage sécurisé Android ; les sauvegardes Android sont désactivées. `TokenStore.clear()` efface la session. Le socle n'implémente ni connexion, ni rafraîchissement de token. Les appels hors origine API sont rejetés ; aucun journal de requêtes ou de données médicales n'est activé.

Les erreurs réseau, timeout, validation, 401, 403, serveur et annulation sont typées. Le format backend `ErrorResponse` est normalisé et conserve la corrélation et les violations de champs. Les futurs écrans doivent utiliser la présentation d'erreurs commune. Un 401 est remis à la couche métier ; aucune redirection vers un écran de connexion fictif.

## OpenAPI

Voir [tool/README.md](tool/README.md). Le dépôt backend ne contient actuellement aucun export du contrat complet : le contrat de démarrage décrit uniquement les erreurs existantes. Il ne fournit pas encore de méthodes métier. Exporter le contrat réel avant la première intégration :

```bash
curl --fail https://BACKEND/v3/api-docs -o openapi/healthys.json
OPENAPI_SPEC=openapi/healthys.json bash tool/generate_api.sh
flutter pub get
```

La version du générateur et son SHA-256 sont épinglés. Les sources générées et leur sérialisation sont versionnées.

## Vérification

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build bundle --target-platform=linux-x64 --dart-define-from-file=config/dev.json
```

La CI vérifie également le package généré, la reproductibilité OpenAPI et la compilation APK debug. Les tests couvrent la configuration, le transport HTTP, les erreurs, le stockage et la navigation. Une compilation bundle vérifie le code Dart ; les builds APK/iOS demandent respectivement Android SDK et macOS/Xcode.
