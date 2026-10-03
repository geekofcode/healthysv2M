# HEALTH’YS mobile — socle et parcours patient 18.1–18.12

Application Flutter Android/iOS. Architecture par fonctionnalité, Riverpod pour injection/état, GoRouter pour navigation et Dio pour HTTP. Le thème Material 3 reprend le vert `#087f5b` du frontend HEALTH’YS. Mode système/clair/sombre et langue système/français/anglais sont sélectionnables et persistés dans les paramètres.

## Stabilisation et publication (18.12)

Le [guide Android/iOS et stores](docs/mobile-release/README.md) détaille la signature, les identifiants, la prévalidation, la recette réseau/offline, la sécurité des tokens, les mesures de performance et les configurations Play Console/App Store Connect. La CI compile Android debug/release et iOS release sans signature ; elle ne distribue aucun build aux stores. Les credentials fournisseurs et essais sur appareils doivent être finalisés avant distribution.

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

`APP_ENV` accepte `dev` ou `prod`. Production : URL explicite HTTPS terminant par `/api/v1`, sans identifiants, query ni fragment. Une configuration invalide bloque le démarrage. Un build release exige `APP_ENV=prod`. Les fichiers dart-define sont intégrés au binaire : **aucun secret** ne doit y figurer. Android release exige `android/key.properties` et une clé dédiée : aucun fallback debug. Les identifiants `com.example.healthysv2` doivent être remplacés et l'équipe Apple configurée avant publication ; utiliser `tool/check_release.py` selon le guide.

## Organisation

- `lib/app/` : application, routing et thème.
- `lib/core/config/` : configuration immuable injectée au démarrage.
- `lib/core/network/` : Dio partagé, bearer token, délais, corrélation et normalisation des erreurs.
- `lib/core/storage/` : interface injectable de stockage des tokens et implémentation secure storage.
- `lib/core/errors/` : erreurs typées et présentation réutilisable.
- `lib/core/api/` : client OpenAPI injecté avec le même Dio.
- `lib/features/<feature>/presentation/` : écrans, puis `application/`, `domain/` et `data/` à ajouter selon les besoins métier.
- `packages/healthys_api/` : client généré, à régénérer plutôt qu'éditer.

Les futurs repositories utilisent le client injecté ; les providers d'état exposent `AsyncValue` à la présentation. Ne pas créer de Dio par écran. Routes : `/login`, `/`, `/settings`, `/profile`, `/medical-record` et les routes `/appointments`. Toutes sauf `/login` sont protégées. La restauration initiale affiche un chargement ; les changements de session actualisent les guards sans recréer le router. Les destinations de retour sont limitées aux routes locales connues.

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

La CI vérifie également le package généré, la reproductibilité OpenAPI, les tests de prévalidation stores, l'APK debug, l'AAB release signé avec une clé de test éphémère et le build iOS release sans signature sur macOS. Les tests couvrent la configuration, le transport HTTP, les erreurs, le stockage, les préférences et la navigation. Ces builds utilisent des fournisseurs injectés ou une configuration d'exemple ; la recette native et la distribution exigent les credentials réels et des appareils physiques.

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

## Accueil et profil patient (18.3)

Le dashboard et le profil affichent les données du patient connecté : identité, contacts, adresses lisibles, assurances (dates et statut de couverture), alertes actives et allergies actives. Les informations manquantes, le dossier non associé (404), les permissions insuffisantes (403), le chargement et les pannes réseau ont des états dédiés, avec rafraîchissement ou nouvelle tentative explicite.

Le repository utilise le Dio partagé pour `GET /api/v1/patients/me/dashboard`. Déployer le changement backend 18.3 avant d'utiliser ces écrans. Le serveur résout exclusivement le patient depuis le sujet JWT et exige le rôle `PATIENT` ; aucun identifiant patient n'est envoyé par le mobile. Ce parcours est en lecture seule, sans création automatique de patient. Le contrat métier est typé manuellement tant que l'export OpenAPI complet n'est pas disponible.

Les données restent en mémoire. La déconnexion ou le changement d'utilisateur annule le chargement et retire les données ; une réponse tardive ne les restaure pas. La navigation vers `/medical-record` ouvre le dossier médical décrit ci-dessous. La modification du profil ne fait pas partie de cette étape.

Les tests 18.3 couvrent le contrat, les dates de couverture inclusives, le nettoyage de session, les erreurs, le rafraîchissement et la navigation protégée. Les parcours natifs et les données réelles restent à valider avec le backend déployé.

## Dossier médical patient (18.4)

`/medical-record` charge `GET /api/v1/patients/me/medical-record` avec le Dio et la session partagés. Il affiche le groupe sanguin, les alertes actives, les allergies avec leur statut (y compris les allergies résolues), les maladies chroniques avec le code/libellé du catalogue, les antécédents médicaux, chirurgicaux et familiaux, les handicaps, le profil d'urgence et ses paramètres de visibilité, ainsi que les contacts d'urgence.

Le parcours reste en lecture seule. Les notes privées des professionnels sont exclues du contrat. Le profil d'urgence affiche sa configuration existante : aucun accès public, QR code ou modification de partage n'est ajouté. Les collections vides signifient qu'aucune information n'est enregistrée, pas une absence clinique confirmée. Les dates et libellés absents sont signalés.

Déployer le backend des étapes 18.3–18.4 avant ces écrans. Le endpoint exige le rôle PATIENT, résout l'identité depuis JWT.sub et audite la lecture. Le mobile vérifie également la concordance avec la personne authentifiée. Les données ne sont pas persistées ; les chargements sont annulés et les réponses tardives ignorées lors d'une déconnexion ou d'un changement de compte. Les erreurs 403/404, les pannes et les échecs de rafraîchissement affichent une nouvelle tentative sans conserver de données anciennes à l'écran.

## Rendez-vous et agenda patient (18.5)

L'agenda présente les rendez-vous à venir et passés, avec pagination, détail nommé de l'établissement et du professionnel, horaires dans le fuseau du téléphone, motif et statut. La création propose les établissements où le patient est enregistré et les professionnels affectés, puis des créneaux réels de 30 minutes pour la date choisie. L'annulation et la replanification demandent une confirmation et respectent les actions autorisées par le serveur.

Le mobile utilise les endpoints `patients/me/appointments` (liste/détail/création), `booking-options`, `availability`, puis les actions `cancel` et `reschedule`. Le patient est déduit exclusivement du compte connecté. Les données et chargements sont liés à la session, sans cache disque. Les actions ne sont ni rejouées automatiquement après 401, ni réessayées après une erreur réseau ; le token peut être renouvelé pour une prochaine action explicite. En cas de résultat incertain, consulter l'agenda avant de renouveler l'action.

Déployer le backend 18.5 avant ces écrans. Il contrôle la propriété du rendez-vous, l'enregistrement dans l'établissement, l'affectation du professionnel et le créneau au moment de la réservation. Les anciennes routes sont également protégées contre les accès à un autre patient. Les créneaux affichés peuvent être pris entre la recherche et la confirmation : un conflit impose d'actualiser les disponibilités.

## Consultations et documents médicaux (18.6)

L'historique paginé présente les consultations terminées. Le détail affiche les diagnostics et notes explicitement partagés avec le patient. Les documents sont accessibles depuis le dossier médical ou filtrés par consultation, avec visualisation PDF/image/texte et enregistrement à la demande via le sélecteur natif.

Les endpoints authentifiés sont `GET /api/v1/patients/me/consultations`, `/consultations/{id}`, `/documents`, `/documents/{id}` et `/documents/{id}/content`. Déployer le backend 18.6 et sa migration V16 : les notes, diagnostics et documents existants restent privés par défaut. Les professionnels autorisés publient ou retirent le partage via `PATCH /api/v1/consultations/{id}/notes/{noteId}/patient-visibility`, `/diagnoses/{diagnosisId}/patient-visibility` ou `/api/v1/documents/{id}/patient-visibility`, avec `{patientVisible:true|false}`.

Seuls les documents actifs partagés du patient connecté sont accessibles. Aucune clé de stockage ni URL publique n'est exposée. Le transport contrôle le type, la signature et la taille (25 Mio maximum). Les données en mémoire et les téléchargements sont liés à la session. Le lecteur PDF utilise un fichier temporaire privé supprimé à sa fermeture ; les restes éventuels sont nettoyés au démarrage. Les fichiers enregistrés volontairement dans un emplacement choisi par l'utilisateur y restent disponibles.

Le sélecteur de fichiers impose iOS 14 minimum ; l’intégration Firebase 18.10 relève la cible du projet à **iOS 15**. La CI compile Android ; la visualisation PDF et le sélecteur natif doivent aussi être validés sur appareils Android/iOS avec le backend déployé.

## Laboratoire et prescriptions (18.7)

Les routes protégées `/lab-results` et `/prescriptions` présentent les données du patient connecté avec pagination, rafraîchissement et détail. Le laboratoire affiche uniquement les résultats finalisés (`FINAL`) disposant d'une validation : examen, paramètre, valeur, unité, bornes de référence, interprétation et indicateur d'anomalie fournis par le laboratoire. L'application ne calcule aucun diagnostic à partir des valeurs et n'affiche pas les notes internes du laboratoire.

Les prescriptions affichent le prescripteur, l'établissement, les médicaments (nom, forme et dosage), la posologie, fréquence, voie, durée et instructions, les quantités prescrites/délivrées/restantes, le statut et l'expiration. Le détail présente les dispensations avec date, pharmacie, statut et quantités. Une prescription annulée ou délivrée conserve son statut historique ; une prescription active ou partiellement délivrée dépassant sa date limite est indiquée comme expirée.

Déployer le backend 18.7 : `GET /api/v1/patients/me/lab-results`, `/lab-results/{id}`, `/prescriptions`, `/prescriptions/{id}`. L'identité est résolue exclusivement depuis le compte Keycloak. Les données restent en mémoire, les chargements sont annulés et les réponses tardives rejetées lorsque la session change. Les parcours sont en lecture seule ; les opérations métier de prescription, validation et dispensation restent réservées aux professionnels.

## Carnet mère-enfant (18.8)

Le carnet présente les grossesses et visites prénatales, la naissance, les carnets d'enfants liés, les vaccinations et l'historique de croissance. Les mesures conservent les unités enregistrées (kg, cm, mmHg, battements/minute) et les données absentes sont indiquées. Les dates civiles (naissance, échéance prévue, prochaine dose) sont affichées sans conversion de fuseau ; les dates/heures de visite et de mesure utilisent le fuseau du téléphone. Aucun percentile ni interprétation clinique n'est calculé.

Déployer le backend 18.8 : listes paginées et détails `GET /api/v1/patients/me/maternal-child/pregnancies`, `/pregnancies/{id}`, `/children`, `/children/{childPatientId}`. La mère consulte ses grossesses et les enfants liés à son patient dans le carnet existant ; un enfant connecté consulte son propre carnet, sans dossier de grossesse de sa mère. Aucun rôle de parent ni nouveau lien n'est créé automatiquement. Les notes internes, risques commentés et observations privées sont exclus des réponses patient.

Les écrans sont en lecture seule, avec navigation protégée, rafraîchissement et erreurs contrôlées. Les données restent en mémoire ; une déconnexion ou un changement de compte annule les chargements et retire le contenu. Les vaccinations distinguent les statuts et échéances fournis par le serveur ; une collection vide indique l'absence de données enregistrées.

## Messagerie temps réel (18.9)

La messagerie patient propose les conversations paginées, l’historique des messages, l’envoi de texte et les pièces jointes PDF, JPEG, PNG ou texte (25 Mio maximum). La lecture et les compteurs de messages non lus sont synchronisés avec le serveur. Les fichiers partagés passent par des endpoints authentifiés de conversation ; aucune URL de stockage publique n’est utilisée.

La connexion WebSocket utilise STOMP 1.2 sur `/ws`, dérivé de la même origine et du même préfixe de déploiement que `API_BASE_URL`. En production, HTTPS implique WSS. Le reverse proxy doit transmettre l’upgrade WebSocket. Le token est envoyé dans le frame CONNECT, sans paramètre d’URL. Les événements déclenchent une resynchronisation REST ; la reprise après une coupure relit les données, sans rejouer automatiquement les envois.

La fermeture d’un écran, la mise en arrière-plan et la fin de session arrêtent les connexions et chargements concernés. Les messages restent en mémoire ; aucun historique ni brouillon n’est persisté. Une erreur d’envoi peut signifier que le serveur a reçu le message : actualiser l’historique avant de renvoyer. Les aperçus utilisent le lecteur de documents existant et ses fichiers temporaires privés.

Déployer les changements API 18.9 avant ces écrans. Les contrôles serveur limitent chaque conversation et chaque pièce jointe aux participants actifs. Les tests automatisés valident les contrats, le codec et les transitions de connexion ; les parcours natifs de sélection de fichier et la connexion au serveur déployé doivent également être vérifiés sur Android/iOS.

La création d’une conversation sélectionne un professionnel nommé parmi les relations de soins actives du patient (`conversations/recipients`). L’annuaire n’expose pas tous les utilisateurs. Le statut de lecture d’un message envoyé repose sur les accusés des autres participants, et non sur la lecture par l’expéditeur lui-même.

## Notifications push et préférences (18.10)

Procédure complète : [Configurer Firebase/APNs et vérifier les notifications](docs/firebase-apns/README.md).

La cloche de l’accueil ouvre l’historique paginé, le filtre non-lu, la lecture et les détails. Les paramètres permettent d’activer les notifications sur l’appareil, de les désactiver et de modifier les préférences in-app. L’application distingue une permission refusée, une configuration indisponible et un échec d’enregistrement. Les préférences existantes de courriel/SMS et les heures de silence sont conservées ; les horaires affichés sont UTC. Ces préférences ne mettent pas en place de fournisseur courriel/SMS.

Le push est **désactivé par défaut** (`PUSH_ENABLED=false`). Pour un build connecté, enregistrer les applications Android/iOS dans Firebase avec leurs véritables identifiants, puis fournir les fichiers publics de configuration `android/app/google-services.json` et `ios/Runner/GoogleService-Info.plist` (ignorés par Git). Le build Android applique le plugin Google Services lorsque le fichier existe ; le build iOS copie le plist et configure Firebase avant le démarrage Flutter, ce qui permet l’initialisation native lorsque le système réveille l’application.

Dans le fichier dart-define correspondant, définir `PUSH_ENABLED=true`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID` et, pour iOS, `FIREBASE_IOS_BUNDLE_ID`. Les valeurs doivent correspondre aux fichiers natifs du même environnement et de la même plateforme ; l’App ID Firebase Android diffère de celui d’iOS. Aucun compte de service ni clé APNs privée ne doit figurer dans ces fichiers.

Android utilise le canal `healthys_notifications` et demande la permission système par une action explicite. Sur iOS, activer Push Notifications pour l’App ID et la signature, conserver le swizzling Firebase, puis déposer la clé d’authentification APNs dans Firebase. Le projet cible iOS 15 et fournit les entitlements APNs (`development` en Debug, `production` en Release/Profile). Le token APNs doit être disponible avant la récupération du token FCM. La configuration native seule ne déclenche pas de demande de permission ; l’auto-initialisation FCM est désactivée jusqu’à l’activation par l’utilisateur.

Déployer le backend 18.10 et sa migration V17 : enregistrement/rotation du token d’appareil, révocation et envoi FCM HTTP v1. L’UUID d’installation et la capacité de révocation sont conservés dans le stockage sécurisé. Une déconnexion ou expiration supprime le token local et tente la révocation serveur ; si le réseau manque, la révocation reste en attente et doit réussir avant un nouvel enregistrement. Une révocation hors ligne ne peut pas être confirmée immédiatement au serveur.

Les alertes sur écran verrouillé contiennent seulement un texte générique HEALTH’YS et une référence de notification. En premier plan, une bannière générique et les compteurs sont actualisés. Après un appui, y compris au démarrage à froid, l’application vérifie la session et récupère la notification auprès du serveur avant d’ouvrir une route patient autorisée. Les URL contenues dans un payload sont ignorées. Les tests automatisés injectent Firebase et le serveur ; la CI compile Android. La réception réelle FCM/APNs, les permissions et les ouvertures à froid doivent être validées sur des appareils configurés ; aucun certificat ni compte Firebase/APNs n’est créé automatiquement.

## Téléconsultation mobile (18.11)

L’accueil et le détail d’un rendez-vous donnent accès aux téléconsultations paginées. La salle d’attente affiche le professionnel, l’horaire et le statut, puis se resynchronise tant que l’écran est visible. Le patient entre explicitement dans la salle d’attente ; le professionnel démarre la séance et admet le patient. Le serveur fournit `canJoin`, sans déduire l’admission depuis un identifiant local.

Les permissions caméra/microphone sont demandées uniquement lorsqu’un média choisi est activé. Les deux médias sont désactivés par défaut, y compris dans la salle d’attente. L’appel LiveKit affiche les vidéos distante et locale, avec contrôles caméra, microphone et changement de caméra. Un refus de permission permet de consulter les réglages ou de rejoindre sans publier le média refusé. Aucun enregistrement n’est ajouté.

La perte de réseau affiche une reconnexion limitée ; une interruption prolongée impose de rejoindre à nouveau. La mise en arrière-plan, le masquage de la route, la sortie de l’écran et la fin de session ferment les médias. Le retour au premier plan ne rallume pas automatiquement caméra/microphone : rejoindre explicitement après une nouvelle vérification serveur. Quitter l’appel ferme la connexion locale et marque la sortie du patient, sans terminer la consultation pour le professionnel. Après cette sortie, une nouvelle admission est nécessaire.

Déployer le backend 18.11 et sa migration V18. Le mobile utilise `GET /api/v1/video-sessions/page` et `/{id}`, puis `POST /{id}/waiting-room`, `/{id}/token` et `/{id}/leave`. Les mutations ne sont pas rejouées après un résultat incertain. Les jetons LiveKit restent en mémoire, ne sont pas journalisés et ne contiennent aucun secret de signature serveur. Production : le serveur doit retourner une URL `wss://` valide, avec un certificat reconnu et une connectivité RTC/TURN adaptée aux réseaux mobiles.

Configurer `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` et `LIVEKIT_TOKEN_TTL_MINUTES` côté backend uniquement. La durée par défaut est 5 minutes (1 à 15 autorisées). Sur le serveur LiveKit, désactiver impérativement la création automatique des salles :

```yaml
room:
  auto_create: false
```

HEALTH’YS crée la salle explicitement avant le démarrage et avant un jeton autorisé d’une séance active. La fermeture clinique bloque immédiatement les nouveaux jetons ; la suppression de la salle LiveKit est mise en file après le commit serveur (intervalle normal 10 secondes, reprises bornées). Une panne du fournisseur peut retarder la fermeture distante : surveiller les tâches de nettoyage en échec côté backend. Sans `auto_create: false`, un ancien jeton encore valide pourrait recréer une salle supprimée. Quitter une séance active ne révoque pas immédiatement un jeton LiveKit déjà émis ; sa validité est courte et le client le détruit à la fermeture.

La CI vérifie les contrôleurs avec un SDK média injecté et compile l’APK Android. Tester sur Android et iOS physiques avec le serveur LiveKit configuré : admission depuis le web, caméra avant/arrière, micro et audio distant, refus de permissions, Wi-Fi/réseau mobile, appel téléphonique entrant, arrière-plan, écran masqué, fin professionnelle et expiration de session. Le build iOS nécessite macOS/Xcode. Voir la [configuration Flutter LiveKit](https://docs.livekit.io/transport/sdk-platforms/flutter/) et le [déploiement LiveKit](https://docs.livekit.io/transport/self-hosting/).
