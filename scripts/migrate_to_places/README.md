# Migration vers les catégories dynamiques

Script **one-shot** qui fait passer Kin Experience des 6 collections en dur
(`sites`, `restaurants`, `hotels`, `events`, `business`, `shopping`) à une
collection unique `places` + une collection `categories` configurable depuis
l'admin.

## Garanties

- **Non destructif** — les 6 collections d'origine ne sont pas touchées.
  Retour arrière = supprimer `places` et `categories`.
- **Idempotent** — les ids de documents sont conservés. Rejouer le script
  réécrit les mêmes documents, sans doublons.
- **Liens préservés** — les ids étant les mêmes, les liens de partage et les
  notifications déjà envoyées continuent de fonctionner.

## Préparation

```bash
cd scripts/migrate_to_places
npm install
```

Placez `serviceAccountKey.json` dans ce dossier :
Console Firebase → Paramètres → Comptes de service → Générer une nouvelle clé.

> ⚠️ Ce fichier donne un accès total à la base. Ne le committez jamais.

## Déroulé conseillé

```bash
# 1. Simuler : rien n'est écrit, on vérifie les totaux
node migrate.js --dry-run

# 2. Migrer (ajoutez --favorites pour convertir aussi les favoris)
node migrate.js --favorites

# 3. Créer les index (les listes restent vides tant qu'ils se construisent)
cd ../..
firebase deploy --only firestore:indexes

# 4. Vérifier l'app : accueil, catégories, recherche, carte, favoris

# 5. Publier les règles — À FAIRE EN DERNIER
firebase deploy --only firestore:rules
```

L'étape 5 est la dernière car les règles ferment l'écriture sur les anciennes
collections et exigent que `places` soit peuplée.

> ⚠️ `firebase deploy --only firestore:rules` **écrase** les règles
> actuellement en console. Relisez [`firestore.rules`](../../firestore.rules)
> avant de lancer.

## Ce que fait le script

**`categories`** — crée les 6 catégories historiques avec leurs libellés fr/en,
icônes et textes de bouton (« Réserver » pour les hôtels, « Acheter un billet »
pour les événements…), qui étaient codés en dur dans `detail_screen.dart`.

**`places`** — copie chaque lieu en ajoutant `categoryKey` et en normalisant :

| Champ | Traitement |
|---|---|
| `latitude` / `longitude` | lus à plat, ou depuis le GeoPoint `location` si absents |
| `location` | (re)construit comme GeoPoint — porte les requêtes géo |
| `meta.*` | remonté à la racine (forme des brouillons publiés) |
| `isDraft` | forcé à `true`/`false` explicite, jamais absent |
| `updatedAt` | garanti présent — il porte le tri de toutes les listes |
| `communities` | déplacé dans `extras` |

**`favorites`** (option `--favorites`) — reclé `hotels_abc123` → `abc123` et
remplace `category` par `categoryKey`. Sans cette étape, les favoris existants
disparaissent de l'app.

## Points d'attention

**`isDraft` explicite.** Les requêtes publiques filtrent `isDraft == false`.
Une requête d'égalité Firestore ignore les documents où le champ n'existe
pas — d'où le champ posé systématiquement. Au passage, cela corrige une fuite :
les brouillons s'affichaient dans l'app publique.

**Documents réparés.** Les lieux publiés via le workflow brouillons étaient
écrits en `location` + `meta` alors que l'app lisait `latitude`/`rating` à plat.
Ils ressortaient avec une position et une note à zéro. La normalisation les
répare.

**Collections orphelines.** Le script signale si `entreprises`, `shoppings` ou
`restos` contiennent des documents. Les Cloud Functions écoutaient
`entreprises`/`shoppings` alors que le client lisait `business`/`shopping` :
des données ont pu s'y égarer. Le script ne les migre pas — à vérifier à la
main.

## Après vérification

Une fois l'app validée en production, les anciennes collections peuvent être
supprimées, ainsi que leur bloc dans `firestore.rules`.
