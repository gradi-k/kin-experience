# Import Apify → Firestore (Kin Experience)

Script Node.js pour importer les données du **Google Places Crawler** (Apify) dans Firestore, au format des modèles `Resto` et `Hotel` de l'application.

## Prérequis

- Node.js 18+
- Un compte [Apify](https://apify.com) avec un dataset généré
- Un projet Firebase avec un **compte de service** (Service Account)

## Installation

```bash
cd scripts/apify_import
npm install
```

## Configuration

1. Copie le fichier d'exemple :
   ```bash
   cp .env.example .env
   ```

2. Remplis le fichier `.env` :
   ```
   APIFY_TOKEN=ton_token_apify
   APIFY_DATASET_ID=id_du_dataset_apify
   FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccount.json
   ```

3. Télécharge ton **Service Account Firebase** :
   - Firebase Console → Paramètres du projet → Comptes de service
   - Clique sur "Générer une nouvelle clé privée"
   - Renomme le fichier téléchargé en `serviceAccount.json`
   - Place-le dans ce dossier (`scripts/apify_import/`)

   > ⚠️ Ne commite JAMAIS `serviceAccount.json` ni `.env` dans git !

## Trouver l'ID de ton dataset Apify

Sur Apify, après un run de l'actor :
1. Va dans **Storage → Datasets**
2. Clique sur ton dataset
3. L'ID est dans l'URL : `https://console.apify.com/storage/datasets/[DATASET_ID]`

## Utilisation

### Aperçu sans écrire (dry-run)
```bash
node import.js restaurants --dry-run
```

### Importer les restaurants
```bash
node import.js restaurants
```

### Importer les hôtels
```bash
node import.js hotels
```

Ou via npm :
```bash
npm run import:restaurants
npm run import:hotels
npm run preview
```

## Comportement

- Les données Apify sont **transformées** vers le format Firestore de l'app
- L'ID Firestore de chaque document = `placeId` Google Maps → **pas de doublons** en cas de re-import
- Les items sans nom ou sans coordonnées GPS sont ignorés
- `merge: true` → si un document existe déjà, il est **mis à jour** (pas écrasé)
- `distanceKm` est laissé à `null` (calculé côté Flutter)
- `isFeatured` est `false` par défaut (à activer manuellement sur les lieux choisis)

## Correspondance des champs

| Apify | Firestore (app) |
|---|---|
| `title` | `nom` |
| `description` / `categoryName` | `description` |
| `totalScore` | `rating` |
| `location.lat` | `latitude` |
| `location.lng` | `longitude` |
| `imageUrls[]` | `photos` (max 5) |
| `price` | `prixRange` |
| `address` | `address` |
| `phone` | `phone` |
| `website` | `website` |
| `openingHours[]` | `schedule` |
| `reviewsCount` | `reviewCount` |
| `socialMedia.facebook` | `facebookUrl` |
| `socialMedia.instagram` | `instagramUrl` |
| `additionalInfo` | `amenities` |