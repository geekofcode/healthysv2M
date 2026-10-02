# Génération du client OpenAPI

Prérequis : Java 17+, Python 3, curl et Flutter (avec `dart` dans PATH).

```sh
./tool/generate_api.sh
./tool/generate_api.sh --check
```

OpenAPI Generator **7.17.0** est téléchargé depuis Maven Central, vérifié par
SHA-256, puis génère un package `dart-dio` avec sérialisation JSON.
Les fichiers générés et le lockfile du package sont versionnés. Ne pas modifier
manuellement `packages/healthys_api/lib` ; modifier le contrat et régénérer.
Le mode `--check`, utilisé par CI, échoue si la génération change les fichiers.

## Contrat de démarrage

`openapi/healthys-bootstrap.yaml` contient uniquement les schémas `ErrorResponse`
et `FieldViolation`, dérivés des records Java du backend `geekofcode/healthysv2`,
commit `8ff6b420b818f2bb00353969599814ee074aa1e5`, fichiers :

- `src/main/java/org/novasos/healthysv2/shared/api/error/ErrorResponse.java`
- `src/main/java/org/novasos/healthysv2/shared/api/error/FieldViolation.java`

Le dépôt backend ne fournit pas d'export OpenAPI versionné. Ce sous-ensemble
n'expose donc **aucun endpoint métier** et ne remplace pas le contrat complet.
Avant les prochains modules mobiles, exporter `/v3/api-docs` depuis une instance
backend autorisée, vérifier le fichier puis le versionner dans `openapi/` :

```sh
OPENAPI_SPEC=openapi/healthys.yaml ./tool/generate_api.sh
```

Ne pas exporter de jetons, données patients ou secrets dans le contrat.
Si le contrat complet devient la référence, remplacer le chemin par défaut dans
`generate_api.sh` pour que CI vérifie le même fichier.

Le Dio partagé est configuré avec un base URL terminant par `/api/v1/`. Lors
du remplacement par l'export Spring, normaliser les chemins du contrat pour
qu'ils soient relatifs à ce préfixe (par exemple `/patients` plutôt que
`/api/v1/patients`), puis vérifier l'URL finale dans un test de transport.
