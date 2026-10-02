# HEALTH’YS mobile — socle 18.1 et authentification 18.2

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

Les futurs repositories utilisent le client injecté ; les providers d'état exposent `AsyncValue` à la présentation. Ne pas créer de Dio par écran. Routes : `/login`, `/`, `/settings` et `/profile`. Les trois dernières sont protégées. La restauration initiale affiche un chargement ; les changements de session actualisent les guards sans recréer le router. Les destinations de retour sont limitées aux routes locales connues.

## HTTP et erreurs

Le token est lu au moment de chaque requête. Le stockage utilise Keychain sur iOS et le stockage sécurisé Android ; les sauvegardes Android sont désactivées. `TokenStore.clear()` efface la session. La session est isolée par issuer, client et URL API. Les appels hors origine API sont rejetés ; aucun journal de requêtes ou de données médicales n'est activé.

Les erreurs réseau, timeout, validation, 401, 403, serveur et annulation sont typées. Le format backend `ErrorResponse` est normalisé et conserve la corrélation et les violations de champs. Les futurs écrans doivent utiliser la présentation d'erreurs commune. Un 401 déclenche un renouvellement et au maximum un rejeu. Un second 401 ferme la session. Les corps en streaming et multipart ne sont pas rejoués automatiquement.

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

## Authentification mobile (18.2)

Le navigateur système ouvre Keycloak via `flutter_appauth` : Authorization Code + PKCE S256, client public sans secret, scopes `openid profile email`. L'app ne collecte aucun mot de passe. La connexion demande `prompt=login` pour que l'utilisateur confirme ses identifiants même si une ancienne session navigateur existe.

Configuration alignée sur le realm versionné dans le backend :

| Variable | Valeur initiale |
| --- | --- |
| `OIDC_ISSUER` | `https://keycloak.wouri.tv/realms/healthys` |
| `OIDC_CLIENT_ID` | `healthys-mobile-apps` |
| `OIDC_REDIRECT_URI` | `healthys://oauth/callback` |
| `OIDC_POST_LOGOUT_REDIRECT_URI` | `healthys://oauth/callback` |

Le callback est enregistré dans Android et iOS. Changer son schéma exige aussi de modifier ces fichiers natifs et le client Keycloak ; la configuration rejette les callbacks incompatibles. Flutter ne doit pas intercepter ce callback : deep linking Flutter désactivé, AppAuth le traite. Le cache URL iOS est désactivé pour éviter la conservation de réponses OAuth sur disque.

Dans Keycloak, vérifier le client public, Standard Flow activé, PKCE S256, Direct Access Grants désactivé et audience `healthys-backend-apps`. Vérifier aussi **Valid redirect URIs** et **Valid post logout redirect URIs** avec `healthys://oauth/callback`. Le dépôt backend déclare déjà le callback de connexion ; l'instance déployée doit autoriser aussi celui de déconnexion. L'app ne modifie pas le realm distant.

Access token, refresh token, ID token et expiration sont stockés de manière sécurisée. Le refresh s'effectue 60 secondes avant expiration ou à la prochaine requête après reprise de l'application. Les renouvellements concurrents partagent la même opération ; la rotation du refresh token est persistée. Un refresh révoqué (`invalid_grant`) impose une nouvelle connexion. Une panne réseau conserve la session et permet de réessayer. Les réponses d'une ancienne session sont rejetées après déconnexion ou changement d'utilisateur.

Le profil utilise le véritable endpoint backend **`GET /api/v1/persons/me`**, qui retourne `PersonResponse` (pas `/api/v1/me`). Un 404 signale qu'il faut associer l'identité HEALTH’YS au compte Keycloak. Le profil reste en mémoire et n'est pas stocké sur disque. Les guards contrôlent la session ; les permissions métier restent contrôlées par le backend.

La déconnexion supprime la session locale, puis appelle le endpoint OIDC de fin de session avec `id_token_hint`. Une indisponibilité Keycloak est signalée tout en maintenant l'utilisateur déconnecté localement. Une erreur de suppression du stockage affiche une action de nouvelle tentative.

Biométrie différée : aucun verrou biométrique local n'est activé pour cette étape. Les parcours navigateur/retour natif, la rotation réelle des tokens et Keychain doivent être validés sur Android/iOS avec le realm déployé ; les tests automatisés utilisent des clients OIDC et profil injectés.
