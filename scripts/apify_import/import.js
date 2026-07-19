/**
 * import.js
 * Récupère les données depuis un dataset Apify et les importe dans Firestore.
 *
 * Usage :
 *   node import.js restaurants          → importe dans la collection "restaurants"
 *   node import.js hotels               → importe dans la collection "hotels"
 *   node import.js restaurants --dry-run → affiche les données sans écrire dans Firestore
 *
 * Prérequis :
 *   - Copier .env.example en .env et remplir les variables
 *   - Placer le fichier serviceAccount.json dans ce dossier
 *   - npm install
 */

require('dotenv').config();
const axios = require('axios');
const admin = require('firebase-admin');
const { mapApifyItem } = require('./mapper');

// ─── Arguments CLI ────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const category = args[0]; // "restaurants" ou "hotels"
const isDryRun = args.includes('--dry-run');

const VALID_CATEGORIES = ['restaurants', 'hotels'];

if (!category || !VALID_CATEGORIES.includes(category)) {
  console.error(`❌  Catégorie invalide. Utilise : node import.js [${VALID_CATEGORIES.join('|')}]`);
  process.exit(1);
}

// ─── Config ───────────────────────────────────────────────────────────────────
const APIFY_TOKEN = process.env.APIFY_TOKEN;
const APIFY_DATASET_ID = process.env.APIFY_DATASET_ID;
const SERVICE_ACCOUNT_PATH = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './serviceAccount.json';

if (!APIFY_TOKEN || !APIFY_DATASET_ID) {
  console.error('❌  APIFY_TOKEN ou APIFY_DATASET_ID manquant dans le fichier .env');
  process.exit(1);
}

// ─── Init Firebase ────────────────────────────────────────────────────────────
let db;
if (!isDryRun) {
  const serviceAccount = require(require('path').resolve(SERVICE_ACCOUNT_PATH));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  db = admin.firestore();
  console.log('✅  Firebase initialisé');
}

// ─── Fetch Apify Dataset ──────────────────────────────────────────────────────
async function fetchApifyDataset() {
  const url = `https://api.apify.com/v2/datasets/${APIFY_DATASET_ID}/items`;
  console.log(`\n📥  Récupération du dataset Apify (${APIFY_DATASET_ID})...`);

  const response = await axios.get(url, {
    params: {
      token: APIFY_TOKEN,
      format: 'json',
      clean: true,
    },
  });

  const items = response.data;
  console.log(`✅  ${items.length} items récupérés depuis Apify`);
  return items;
}

// ─── Import vers Firestore ────────────────────────────────────────────────────
async function importToFirestore(items, collectionName) {
  const collectionRef = db.collection(collectionName);

  // Écriture par batch (max 500 ops par batch Firestore)
  const BATCH_SIZE = 400;
  let totalImported = 0;
  let totalSkipped = 0;

  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const chunk = items.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const mapped of chunk) {
      // Vérifie les champs obligatoires
      if (!mapped.nom || mapped.latitude === 0 || mapped.longitude === 0) {
        console.warn(`⚠️   Item ignoré (données manquantes) : ${mapped.nom || 'Sans nom'}`);
        totalSkipped++;
        continue;
      }

      // Utilise placeId Apify comme ID Firestore pour éviter les doublons
      const docId = mapped._apifyId
        ? mapped._apifyId.replace(/[^a-zA-Z0-9_-]/g, '_')
        : collectionRef.doc().id;

      const docRef = collectionRef.doc(docId);
      batch.set(docRef, mapped, { merge: true }); // merge: true → met à jour si existe déjà
      totalImported++;
    }

    await batch.commit();
    console.log(`   Batch ${Math.floor(i / BATCH_SIZE) + 1} : ${chunk.length} items écrits`);
  }

  return { totalImported, totalSkipped };
}

// ─── Dry Run Preview ──────────────────────────────────────────────────────────
function previewItems(items) {
  console.log('\n📋  APERÇU (dry-run — aucune écriture en base) :\n');
  items.slice(0, 5).forEach((item, idx) => {
    console.log(`--- Item ${idx + 1} ---`);
    console.log(`  nom        : ${item.nom}`);
    console.log(`  rating     : ${item.rating}`);
    console.log(`  adresse    : ${item.address}`);
    console.log(`  phone      : ${item.phone}`);
    console.log(`  coords     : ${item.latitude}, ${item.longitude}`);
    console.log(`  photos     : ${item.photos.length} photo(s)`);
    console.log(`  prixRange  : ${item.prixRange}`);
    console.log(`  amenities  : ${item.amenities.join(', ') || 'aucun'}`);
    console.log(`  schedule   : ${item.schedule || 'non renseigné'}`);
    console.log('');
  });
  if (items.length > 5) {
    console.log(`... et ${items.length - 5} autres items.`);
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n🚀  Import Apify → Firestore`);
  console.log(`   Catégorie  : ${category}`);
  console.log(`   Mode       : ${isDryRun ? 'DRY RUN (preview)' : 'PRODUCTION'}`);
  console.log('');

  try {
    // 1. Récupère les données brutes Apify
    const rawItems = await fetchApifyDataset();

    // 2. Mappe vers le format Firestore
    console.log('\n🔄  Transformation des données...');
    const mappedItems = rawItems.map((item) => mapApifyItem(item, { isFeatured: false }));
    console.log(`✅  ${mappedItems.length} items transformés`);

    if (isDryRun) {
      // 3a. Dry run : affiche un aperçu
      previewItems(mappedItems);
      console.log('ℹ️   Dry run terminé. Relance sans --dry-run pour importer.');
    } else {
      // 3b. Production : écrit dans Firestore
      console.log(`\n📤  Écriture dans Firestore (collection: ${category})...`);
      const { totalImported, totalSkipped } = await importToFirestore(mappedItems, category);

      console.log('\n✅  Import terminé !');
      console.log(`   Importés : ${totalImported}`);
      console.log(`   Ignorés  : ${totalSkipped}`);
    }
  } catch (err) {
    console.error('\n❌  Erreur lors de l\'import :', err.message);
    if (err.response) {
      console.error('   Réponse API :', err.response.status, err.response.data);
    }
    process.exit(1);
  }
}

main();