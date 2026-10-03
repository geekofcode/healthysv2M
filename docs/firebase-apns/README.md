# Configurer les notifications HEALTH’YS — Firebase et APNs

Le code 18.10 est intégré, mais le push reste désactivé dans les configurations versionnées. Cette procédure active les services externes ; elle ne crée pas automatiquement de projet Firebase, de compte Apple ou de clé privée.

## 1. Préparer les environnements

Créer un projet Firebase de développement et un projet de production, puis enregistrer dans chacun une application Android et une application iOS. Utiliser les identifiants réellement présents dans `android/app/build.gradle.kts` (`applicationId`) et dans Xcode (`Runner` → Build Settings → Product Bundle Identifier). Le projet initial utilise `com.example.healthysv2` ; choisir les identifiants définitifs avant la publication et les reporter dans les projets natifs et Firebase.

Un fichier de configuration Android ne remplace pas celui d’iOS. Les identifiants Firebase App ID sont différents pour les deux applications, même lorsqu’elles appartiennent au même projet.

## 2. Configurer Android

1. Firebase Console → Project settings → General → Your apps : ajouter ou sélectionner l’application Android avec le bon `applicationId`.
2. Télécharger `google-services.json` et le copier dans `android/app/google-services.json`. Il est ignoré par Git ; le fournir aussi à la machine qui produit le build.
3. Le projet applique automatiquement le plugin Google Services lorsque ce fichier existe. Ces ressources permettent l’initialisation native avant Dart, nécessaire lorsque Android réveille l’application fermée.
4. Utiliser un appareil Android disposant de Google Play Services, ou un émulateur avec une image Google Play. Autoriser les notifications lorsqu’on utilise l’action d’activation dans HEALTH’YS ; Android 13 et versions suivantes demandent une permission système.

Le canal natif s’appelle `healthys_notifications`. Un canal ou l’application peut être désactivé dans les réglages Android, indépendamment de la préférence du compte HEALTH’YS. Les empreintes de signature SHA ne sont pas nécessaires pour FCM seul ; les ajouter si d’autres fonctionnalités Firebase les exigent.

## 3. Configurer Apple et APNs

1. Dans Apple Developer → Certificates, Identifiers & Profiles, enregistrer l’App ID correspondant exactement au bundle ID et activer Push Notifications.
2. Créer une clé d’authentification APNs avec les autorisations et l’environnement nécessaires à l’application. Télécharger le fichier privé `.p8`, conserver son Key ID et le Team ID Apple. Garder cette clé dans un coffre de secrets ; elle ne doit jamais entrer dans l’application mobile ni le dépôt.
3. Firebase Console → Project settings → Cloud Messaging → configuration de l’application iOS → APNs authentication key : importer la clé `.p8`, le Key ID et le Team ID. Vérifier les environnements développement/production proposés par Firebase et le périmètre de la clé Apple.
4. Dans Firebase → General, enregistrer l’application iOS avec le bundle ID exact. Télécharger `GoogleService-Info.plist` et le placer dans `ios/Runner/GoogleService-Info.plist` (ignoré par Git). Le build copie le fichier dans le bundle ; l’AppDelegate initialise Firebase avant Flutter.
5. Ouvrir le projet iOS dans Xcode et sélectionner Runner → Signing & Capabilities. Choisir l’équipe Apple et un profil de signature compatible avec Push Notifications. Vérifier Push Notifications et Background Modes → Remote notifications ; activer aussi Background fetch si le parcours Firebase utilisé en dépend.
6. Le projet fournit `aps-environment=development` en Debug et `production` en Release/Profile. Vérifier que le provisioning profile correspond à cet environnement. La cible minimale est iOS 15.

Conserver le swizzling Firebase : ne pas ajouter `FirebaseAppDelegateProxyEnabled=false`. L’auto-initialisation Messaging est désactivée jusqu’à l’activation utilisateur. Sur iOS, un token APNs doit être disponible avant de récupérer le token FCM ; si l’enregistrement échoue au premier essai, attendre la connexion APNs puis réessayer depuis les préférences.

Valider APNs sur un iPhone/iPad signé avec le bon profil. Les simulateurs ne remplacent pas la validation d’une distribution réelle/TestFlight.

## 4. Renseigner le build Flutter

Créer des fichiers locaux distincts pour l’environnement et la plateforme, par exemple `config/dev.android.local.json` et `config/dev.ios.local.json`, en copiant `config/dev.json`. Conserver les paramètres API/OIDC existants et renseigner :

| Paramètre Dart | Valeur à utiliser |
| --- | --- |
| `PUSH_ENABLED` | `true` |
| `FIREBASE_API_KEY` | Android : `current_key` ; iOS : `API_KEY` |
| `FIREBASE_APP_ID` | Android : `mobilesdk_app_id` ; iOS : `GOOGLE_APP_ID` |
| `FIREBASE_MESSAGING_SENDER_ID` | Android : `project_number` ; iOS : `GCM_SENDER_ID` |
| `FIREBASE_PROJECT_ID` | `project_id` Android / `PROJECT_ID` iOS |
| `FIREBASE_IOS_BUNDLE_ID` | Bundle ID iOS ; vide pour Android |

Les valeurs doivent provenir du même fichier natif installé au build. Les configurations Firebase mobiles contiennent des identifiants publics, pas une clé de compte de service. Les fichiers Dart sont intégrés au binaire : aucun secret serveur ne doit y figurer.

```bash
flutter pub get --enforce-lockfile
flutter run --dart-define-from-file=config/dev.android.local.json
# Pour iOS, depuis macOS avec Xcode et l’appareil sélectionné :
flutter run --dart-define-from-file=config/dev.ios.local.json
```

Pour la production, copier `config/prod.example.json` vers un fichier local adapté à la plateforme, configurer les URL HTTPS réelles et utiliser les fichiers natifs du projet Firebase de production. Remplacer les configurations natives avant chaque build d’un autre environnement, puis nettoyer/recompiler si nécessaire. Ne pas distribuer un binaire mélangeant projet dev et API prod.

## 5. Configurer l’API Java

1. Déployer le backend incluant la migration V17.
2. Dans Google Cloud/Firebase, activer Firebase Cloud Messaging API (HTTP v1) sur le projet cible.
3. Créer un compte de service dédié à l’envoi et lui attribuer le rôle Firebase Cloud Messaging API Admin (`roles/firebasecloudmessaging.admin`) sur ce projet, ou une politique équivalente limitée à l’envoi.
4. Fournir son fichier JSON privé au serveur. Ce fichier n’est ni `google-services.json`, ni `GoogleService-Info.plist`. Le placer hors du dépôt et des images Docker, accessible en lecture uniquement au processus backend.
5. Définir dans l’environnement du backend :

```dotenv
PUSH_ENABLED=true
FCM_PROJECT_ID=identifiant-du-projet-firebase
FCM_SERVICE_ACCOUNT_FILE=/run/secrets/healthys-fcm.json
PUSH_POLL_INTERVAL_MS=10000
```

Avec Docker Compose, le chemin est celui **dans le conteneur**. Ajouter un override local, par exemple :

```yaml
services:
  backend:
    volumes:
      - /chemin-prive/healthys-fcm.json:/run/secrets/healthys-fcm.json:ro
```

Le `.env` backend est déjà transmis au service par le Compose existant. Monter le secret avant le démarrage : une configuration activée sans fichier valide doit échouer au démarrage. Le serveur doit pouvoir joindre les services OAuth Google et `fcm.googleapis.com` en HTTPS. L’APNs `.p8` reste dans Firebase ; l’API HEALTH’YS envoie aussi les notifications Apple via FCM.

## 6. Vérifier le parcours complet

1. Ouvrir l’application, se connecter avec un patient associé à un compte Keycloak, puis Paramètres → Préférences de notification → Activer sur cet appareil.
2. Accepter la permission système. Vérifier que l’état indique un appareil enregistré et que le push du compte est activé. Un refus de permission et un échec d’enregistrement sont des états différents.
3. Depuis un compte professionnel autorisé, créer une notification via `POST /api/v1/notifications` pour le **person ID** du patient. Exemple de corps sans contenu médical :

```json
{
  "type": "HEALTHYS_TEST",
  "title": "Vérification HEALTH’YS",
  "body": "Votre configuration de notification fonctionne.",
  "recipientPersonIds": ["UUID-PERSON-DU-PATIENT"],
  "resourceType": "APPOINTMENT",
  "resourceId": "UUID-RDV-DU-MEME-PATIENT",
  "priority": "NORMAL"
}
```

4. Vérifier successivement le premier plan (bannière générique), l’arrière-plan et le lancement après fermeture normale. L’écran verrouillé doit afficher uniquement HEALTH’YS et un texte générique. L’appui doit ouvrir une destination autorisée après récupération authentifiée de la notification.
5. Tester permission refusée, push désactivé, heures de silence UTC, notification lue/expirée, perte de réseau, logout et changement de compte. Un patient différent ne doit pas accéder au contenu du premier patient.
6. Refaire la vérification sur Android release et iOS TestFlight/production. Un arrêt forcé Android depuis les réglages, ou une fermeture forcée iOS, peut limiter la réception jusqu’à la réouverture : distinguer ce cas d’une fermeture normale.

Une notification envoyée uniquement depuis la console Firebase vérifie le transport, mais pas l’autorisation ni la navigation HEALTH’YS. Le payload de l’API contient `notificationId` ; cet ID doit exister pour le destinataire. Les URL arbitraires du payload sont ignorées.

## Diagnostic

| Symptôme | Vérification |
| --- | --- |
| Push indisponible | `PUSH_ENABLED`, paramètres Dart, plateforme prise en charge et fichiers natifs |
| Permission refusée | Réglages du système et canal Android ; réessayer explicitement |
| Permission accordée mais inscription échouée | API accessible, lien Keycloak, token APNs/FCM disponible et bonne configuration Firebase |
| Android fonctionne, iOS échoue | Bundle ID, clé APNs, Team/Key ID, provisioning et environnement APNs |
| Envoi serveur en échec | Projet, IAM, secret monté, accès réseau, état du device et préférence push |
| Aucun envoi pendant une plage | Heures silencieuses explicitement en UTC ; lecture ou expiration éventuelle |
| Appui sans ouverture du dossier | Session absente/expirée, notification non autorisée, expirée ou type de ressource inconnu |

`SENT` dans les livraisons signifie que FCM a accepté la requête, pas que l’appareil l’a affichée. Les reprises transitoires sont limitées ; un token `UNREGISTERED` est désactivé. La révocation hors ligne reste en attente jusqu’au retour du réseau. Ne pas journaliser les tokens FCM, les capacités de révocation, les clés privées ou les JWT.

## Références

- [Configuration FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
- [Envoi HTTP v1 et comptes de service](https://firebase.google.com/docs/cloud-messaging/send/v1-api)
- [Authentification APNs Apple](https://developer.apple.com/help/account/capabilities/communicate-with-apns-using-authentication-tokens/)
