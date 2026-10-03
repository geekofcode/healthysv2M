# Affichage adaptatif mobile et tablette

L'interface utilise la largeur réellement disponible, pas le modèle de téléphone
ou l'orientation. La taille du texte augmente l'espace minimal nécessaire :
une tablette peut donc revenir à une seule colonne pour garder un contenu lisible.

## Navigation et master-detail

| Espace disponible | Comportement |
| --- | --- |
| Écran étroit | Liste puis détail ; retour à la liste, historique de navigation mobile |
| Écran large | Navigation latérale et liste/détail côte à côte ; sélection visible et retour à la liste |
| Texte agrandi | Réduction du nombre de colonnes et retour au mode à un panneau si nécessaire |

Le split nécessite au moins 720 pixels logiques utilisables à texte normal, après
déduction de la navigation latérale (96 pixels). Le seuil augmente avec le texte.
La largeur du volet liste est bornée ; le détail reçoit l'espace restant.
Chaque volet défile indépendamment. Aucune sélection n'est imposée automatiquement.

Le master-detail couvre rendez-vous, consultations, documents, laboratoire,
prescriptions, carnet mère-enfant, messagerie et notifications. Les documents
d'une consultation gardent leur filtre lorsque leur aperçu est ouvert sur tablette.
Les filtres, la pagination et le défilement de la liste sont conservés lors de
la sélection d'un détail et du redimensionnement dans le même module.

Les détails restent de véritables routes : les destinations des notifications et
les liens profonds utilisent les mêmes écrans protégés. Un détail ouvert directement
permet de revenir à sa liste sans exiger un historique préalable. Le changement
de sélection réinitialise les états propres au détail précédent.

## Contenus et ressources

- Tableau de bord et dossier : sections sur deux colonnes seulement si chacune
  reste lisible ; champs longs sur plusieurs lignes et texte libre inchangé.
- Formulaires : choix longs et menus étendus, actions/pagination pouvant revenir
  à la ligne au lieu de déborder.
- Messagerie : largeur de lecture bornée, composition défilable au-dessus du
  clavier, pièces jointes contraintes, reconnexion accessible avec texte agrandi.
  La connexion de la liste est suspendue lorsqu'elle est masquée sur mobile.
- Téléconsultation : espace dédié à l'appel, sans liste médicale à côté. Vidéo
  principale et aperçu local côte à côte lorsque l'espace le permet ; aperçu
  compact sinon. La rotation seule ne demande aucune permission ni capture.
- Les guards, l'isolation patient, le nettoyage des fichiers et les interruptions
  caméra/micro restent actifs. Le passage en arrière-plan coupe toujours les médias.

## Vérification

Les tests widget couvrent les contraintes mobiles/tablettes (320, 390, 768,
1100/1200 et 1280 pixels), le texte jusqu'à 200 %, le clavier, le retour depuis
un lien profond et la conservation d'état lors du redimensionnement.
La CI vérifie aussi les parcours existants et compile Android et iOS.

Avant distribution, compléter la recette physique :

1. Téléphone et tablette, portrait/paysage et écran partagé ; sélectionner deux
   éléments successifs puis revenir à la liste et vérifier filtre/page/scroll.
2. Activer texte agrandi et thème sombre ; parcourir les libellés longs, formulaires
   et paginations, avec clavier affiché et navigation système retour.
3. Depuis une notification ou un lien profond, ouvrir un détail puis sa liste ;
   déconnecter le compte et vérifier l'absence de données de l'ancien patient.
4. Envoyer un message et des pièces jointes sur tablette/mobile ; vérifier la
   lecture uniquement dans la conversation réellement visible.
5. Pendant un appel de test, tourner/redimensionner puis changer de route ou passer
   en arrière-plan : capture interrompue selon les règles de session existantes.

Les tests injectent le serveur et les médias ; ils ne remplacent pas la recette
FCM/APNs/LiveKit réelle sur appareils configurés.
